local semver = require("crates.semver")
local state = require("crates.state")
local time = require("crates.time")
local DateTime = time.DateTime
local types = require("crates.types")
local ApiFeatures = types.ApiFeatures
local ApiDependencyKind = types.ApiDependencyKind

local M = {
    ---@type table<string,CrateJob>
    crate_jobs = {},
    ---@type table<string,SearchJob>
    search_jobs = {},
    ---@type QueuedCrateJob[]
    crate_queue = {},
    ---@type QueuedSearchJob[]
    search_queue = {},
    ---@type integer
    num_requests = 0,
}

---@class Job
---@field handle uv.uv_process_t|nil
---@field was_cancelled boolean|nil

---@class CrateJob
---@field job Job
---@field callbacks fun(crate: ApiCrate|nil, cancelled: boolean)[]

---@class SearchJob
---@field job Job
---@field callbacks fun(search: ApiCrateSummary[]?, cancelled: boolean)[]

---@class QueuedCrateJob
---@field name string
---@field crate_callbacks fun(crate: ApiCrate|nil, cancelled: boolean)[]

---@class QueuedSearchJob
---@field name string
---@field callbacks fun(search: ApiCrateSummary[]?, cancelled: boolean)[]

local SIGTERM = 15
local API_ENDPOINT = "https://crates.io/api/v1"
local SPARSE_INDEX_ENDPOINT = "https://index.crates.io"
---@type string
local USERAGENT = vim.fn.shellescape("crates.nvim (https://github.com/saecki/crates.nvim)")

local DEPENDENCY_KIND_MAP = {
    ["normal"] = ApiDependencyKind.NORMAL,
    ["build"] = ApiDependencyKind.BUILD,
    ["dev"] = ApiDependencyKind.DEV,
}

---@class vim.json.DecodeOpts
---@class DecodeOpts
---@field luanil Luanil

---@class Luanil
---@field object boolean
---@field array boolean

---@type vim.json.DecodeOpts
local JSON_DECODE_OPTS = { luanil = { object = true, array = true } }


---comment
---@param json_str string
---@return table|nil
local function parse_json(json_str)
    ---@type any
    local json = vim.json.decode(json_str, JSON_DECODE_OPTS)
    if json and type(json) == "table" then
        return json
    end
end

---@param url string
---@param on_exit fun(data: string|nil, cancelled: boolean)
---@return Job|nil
local function start_job(url, on_exit)
    ---@type Job
    local job = {}
    ---@type uv.uv_pipe_t
    local stdout = vim.loop.new_pipe()

    ---@type string|nil
    local stdout_str = nil

    local opts = {
        args = { unpack(state.cfg.curl_args), "-A", USERAGENT, url },
        stdio = { nil, stdout, nil },
    }
    local handle, _pid
    ---@param code integer
    ---@param _signal integer
    ---@type uv.uv_process_t, integer
    handle, _pid = vim.loop.spawn("curl", opts, function(code, _signal)
        handle:close()

        local success = code == 0

        ---@type uv.uv_check_t
        local check = vim.loop.new_check()
        check:start(function()
            if not stdout:is_closing() then
                return
            end
            check:stop()

            vim.schedule(function()
                local data = success and stdout_str or nil
                on_exit(data, job.was_cancelled)
            end)
        end)
    end)

    if not handle then
        return nil
    end

    local accum = {}
    stdout:read_start(function(err, data)
        if err then
            stdout:read_stop()
            stdout:close()
            return
        end

        if data ~= nil then
            table.insert(accum, data)
        else
            stdout_str = table.concat(accum)
            stdout:read_stop()
            stdout:close()
        end
    end)

    job.handle = handle
    return job
end

---@param job Job
local function cancel_job(job)
    if job.handle then
        job.handle:kill(SIGTERM)
    end
end

---@param name string
---@param callbacks fun(crate: ApiCrate|nil, cancelled: boolean)[]
local function enqueue_crate_job(name, callbacks)
    for _, j in ipairs(M.crate_queue) do
        if j.name == name then
            vim.list_extend(j.crate_callbacks, callbacks)
            return
        end
    end

    table.insert(M.crate_queue, {
        name = name,
        crate_callbacks = callbacks,
    })
end

---@param name string
---@param callbacks fun(search: ApiCrateSummary[]?, cancelled: boolean)[]
local function enqueue_search_job(name, callbacks)
    for _, j in ipairs(M.search_queue) do
        if j.name == name then
            vim.list_extend(j.callbacks, callbacks)
            return
        end
    end

    table.insert(M.search_queue, {
        name = name,
        callbacks = callbacks,
    })
end

---@param json_str string
---@return ApiCrateSummary[]?
function M.parse_search(json_str)
    local json = parse_json(json_str)
    if not (json and json.crates) then
        return
    end

    ---@type ApiCrateSummary[]
    local search = {}
    ---@diagnostic disable-next-line: no-unknown
    for _, c in ipairs(json.crates) do
        ---@type ApiCrateSummary
        local result = {
            name = c.name,
            description = c.description,
            newest_version = c.newest_version,
        }
        table.insert(search, result)
    end

    return search
end

---@param name string
---@param callbacks fun(search: ApiCrateSummary[]?, cancelled: boolean)[]
local function fetch_search(name, callbacks)
    local existing = M.search_jobs[name]
    if existing then
        vim.list_extend(existing.callbacks, callbacks)
        return
    end

    if M.num_requests >= state.cfg.max_parallel_requests then
        enqueue_search_job(name, callbacks)
        return
    end

    local url = string.format(
        "%s/crates?q=%s&per_page=%s",
        API_ENDPOINT,
        name,
        state.cfg.completion.crates.max_results
    )

    ---@param json_str string?
    ---@param cancelled boolean
    local function on_exit(json_str, cancelled)
        ---@type ApiCrateSummary[]?
        local search
        if not cancelled and json_str then
            local ok, s = pcall(M.parse_search, json_str)
            if ok then
                search = s
            end
        end
        for _, c in ipairs(callbacks) do
            c(search, cancelled)
        end

        M.search_jobs[name] = nil
        M.num_requests = M.num_requests - 1

        M.run_queued_jobs()
    end

    local job = start_job(url, on_exit)
    if job then
        M.num_requests = M.num_requests + 1
        M.search_jobs[name] = {
            job = job,
            callbacks = callbacks,
        }
    else
        for _, c in ipairs(callbacks) do
            c(nil, false)
        end
    end
end

---@param name string
---@return ApiCrateSummary[]?, boolean
function M.fetch_search(name)
    ---@param resolve fun(search: ApiCrateSummary[]?, cancelled: boolean)
    return coroutine.yield(function(resolve)
        fetch_search(name, { resolve })
    end)
end

---@param json_str string
---@return ApiCrate|nil
function M.parse_crate(json_str)
    local lines = vim.split(json_str, '\n', { trimempty = true })

    ---@type ApiCrate
    local crate = {
        -- name = c.id,
        -- description = assert(c.description),
        -- created = assert(DateTime.parse_rfc_3339(c.created_at)),
        -- updated = assert(DateTime.parse_rfc_3339(c.updated_at)),
        -- downloads = assert(c.downloads),
        -- homepage = c.homepage,
        -- documentation = c.documentation,
        -- repository = c.repository,
        -- categories = {},
        -- keywords = {},
        versions = {},
    }

    -- ---@diagnostic disable-next-line: no-unknown
    -- for _, ct_id in ipairs(c.categories) do
    --     ---@diagnostic disable-next-line: no-unknown
    --     for _, ct in ipairs(json.categories) do
    --         if ct.id == ct_id then
    --             table.insert(crate.categories, ct.category)
    --         end
    --     end
    -- end
    --
    -- ---@diagnostic disable-next-line: no-unknown
    -- for _, kw_id in ipairs(c.keywords) do
    --     ---@diagnostic disable-next-line: no-unknown
    --     for _, kw in ipairs(json.keywords) do
    --         if kw.id == kw_id then
    --             table.insert(crate.keywords, kw.keyword)
    --         end
    --     end
    -- end

    for _, line in ipairs(lines) do
        local ok, json = pcall(parse_json, line)
        if ok and json and json.name and json.vers then
            crate.name = json.name

            ---@type ApiVersion
            local version = {
                num = json.vers,
                deps = {},
                features = ApiFeatures.new({}),
                yanked = json.yanked,
                parsed = semver.parse_version(json.vers),
                -- created = assert(DateTime.parse_rfc_3339(v.created_at)),
            }

            -- TODO: handle `features2` syntaxes
            --      - explicit `dep:<crate_name>`
            --      - weak dependencies `pkg?/feat`
            ---@diagnostic disable-next-line: no-unknown
            for n, m in pairs(json.features) do
                table.sort(m)
                version.features:insert({
                    name = n,
                    members = m,
                })
            end

            ---@diagnostic disable-next-line: no-unknown
            for _, d in ipairs(json.deps) do
                if d.name then
                    ---@type ApiDependency
                    local dependency = {
                        name = d.name,
                        package = d.package,
                        opt = d.optional or false,
                        kind = DEPENDENCY_KIND_MAP[d.kind],
                        vers = {
                            text = d.req,
                            reqs = semver.parse_requirements(d.req),
                        },
                    }
                    table.insert(version.deps, dependency)

                    if dependency.opt and not version.features.map[dependency.name] then
                        version.features:insert({
                            name = dependency.name,
                            members = {},
                        })
                    end
                end
            end

            -- sort features alphabetically
            version.features:sort()

            -- add missing default feature
            if not version.features.list[1] or not (version.features.list[1].name == "default") then
                version.features:insert({
                    name = "default",
                    members = {},
                })
            end

            table.insert(crate.versions, 1, version)
        end
    end

    if not crate.name then
        return nil
    end

    return crate
end

---@param name string
---@param callbacks fun(crate: ApiCrate|nil, cancelled: boolean)[]
local function fetch_crate(name, callbacks)
    local existing = M.crate_jobs[name]
    if existing then
        vim.list_extend(existing.callbacks, callbacks)
        return
    end

    if M.num_requests >= state.cfg.max_parallel_requests then
        enqueue_crate_job(name, callbacks)
        return
    end

    ---@type string
    local url
    if #name == 1 then
        url = string.format("%s/1/%s", SPARSE_INDEX_ENDPOINT, name)
    elseif #name == 2 then
        url = string.format("%s/2/%s", SPARSE_INDEX_ENDPOINT, name)
    elseif #name == 3 then
        url = string.format("%s/3/%s/%s", SPARSE_INDEX_ENDPOINT, string.sub(name, 1, 1), name)
    else
        url = string.format("%s/%s/%s/%s", SPARSE_INDEX_ENDPOINT, string.sub(name, 1, 2), string.sub(name, 3, 4), name)
    end

    ---@param json_str string|nil
    ---@param cancelled boolean
    local function on_exit(json_str, cancelled)
        ---@type ApiCrate|nil
        local crate
        if not cancelled and json_str then
            local ok, c = pcall(M.parse_crate, json_str)
            if ok then
                crate = c
            end
        end
        for _, c in ipairs(callbacks) do
            c(crate, cancelled)
        end

        M.crate_jobs[name] = nil
        M.num_requests = M.num_requests - 1

        M.run_queued_jobs()
    end

    local job = start_job(url, on_exit)
    if job then
        M.num_requests = M.num_requests + 1
        M.crate_jobs[name] = {
            job = job,
            callbacks = callbacks,
        }
    else
        for _, c in ipairs(callbacks) do
            c(nil, false)
        end
    end
end

---@param name string
---@return ApiCrate|nil, boolean
function M.fetch_crate(name)
    ---@param resolve fun(crate: ApiCrate|nil, cancelled: boolean)
    return coroutine.yield(function(resolve)
        fetch_crate(name, { resolve })
    end)
end

---@param name string
---@return boolean
function M.is_fetching_crate(name)
    return M.crate_jobs[name] ~= nil
end

---@param name string
---@return boolean
function M.is_fetching_search(name)
    return M.search_jobs[name] ~= nil
end

---@param name string
---@param callback fun(crate: ApiCrate|nil, cancelled: boolean)
local function add_crate_callback(name, callback)
    table.insert(
        M.crate_jobs[name].callbacks,
        callback
    )
end

---@param name string
---@return ApiCrate|nil, boolean
function M.await_crate(name)
    ---@param resolve fun(crate: ApiCrate|nil, cancelled: boolean)
    return coroutine.yield(function(resolve)
        add_crate_callback(name, resolve)
    end)
end

---@param name string
---@param callback fun(deps: ApiCrateSummary[]?, cancelled: boolean)
local function add_search_callback(name, callback)
    table.insert(
        M.search_jobs[name].callbacks,
        callback
    )
end

---@param name string
---@return ApiCrateSummary[]?, boolean
function M.await_search(name)
    ---@param resolve fun(crate: ApiCrateSummary[]?, cancelled: boolean)
    return coroutine.yield(function(resolve)
        add_search_callback(name, resolve)
    end)
end

function M.run_queued_jobs()
    -- Prioritise crate searches
    if #M.search_queue > 0 then
        local job = table.remove(M.search_queue, 1)
        fetch_search(job.name, job.search_callbacks)
        return
    end

    if #M.crate_queue == 0 then
        return
    end

    local job = table.remove(M.crate_queue, 1)
    fetch_crate(job.name, job.crate_callbacks)
end

function M.cancel_jobs()
    for _, r in pairs(M.crate_jobs) do
        cancel_job(r.job)
    end
    for _, r in pairs(M.search_jobs) do
        cancel_job(r.job)
    end

    M.crate_jobs = {}
    M.search_jobs = {}
end

function M.cancel_search_jobs()
    for _, r in pairs(M.search_jobs) do
        cancel_job(r.job)
    end
    M.search_jobs = {}
end

return M
