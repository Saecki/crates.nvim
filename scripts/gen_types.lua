#!/bin/sh
_=[[
exec lua "$0" "$@"
]]

local config = require("lua.crates.config.init")

---@param lines string[]
---@param schema SchemaElement[]
---@param type_name string
---@param user boolean
local function gen_config_types(lines, schema, type_name, user)
    local prefix = user and "crates.User" or ""
    table.insert(lines, string.format("---@class %s%s", prefix, type_name))

    ---@param s SchemaElement
    local function skip(s)
        return s.deprecated or s.hidden and user
    end

    for _, s in ipairs(schema) do
        if not skip(s) then
            local vis = user and "public " or ""
            local opt = user and "?" or ""
            local type = s.type.emmylua_annotation
            if s.type.config_type == "section" then
                type = prefix .. type
            end
            table.insert(lines, string.format("---@field %s%s%s %s", vis, s.name, opt, type))
        end
    end
    table.insert(lines, "")

    for _, s in ipairs(schema) do
        if not skip(s) and s.type.config_type == "section" then
            gen_config_types(lines, s.fields, s.type.emmylua_annotation, user)
        end
    end
end

local function gen_types()
    local lines = {}
    gen_config_types(lines, config.schema, "Config", false)
    table.insert(lines, "")
    gen_config_types(lines, config.schema, "Config", true)

    local text = table.concat(lines, "\n")
    local outfile = io.open("lua/crates/config/types.lua", "w")
    ---@cast outfile -nil
    outfile:write(text)
    outfile:close()
end

gen_types()
