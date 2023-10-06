local M = {}











local CrateScope = M.CrateScope
local SectionScope = M.SectionScope
local edit = require("crates.edit")
local semver = require("crates.semver")
local state = require("crates.state")
local toml = require("crates.toml")
local types = require("crates.types")
local Crate = types.Crate
local CrateInfo = types.CrateInfo
local Dependency = types.Dependency
local Diagnostic = types.Diagnostic
local DiagnosticKind = types.DiagnosticKind
local Version = types.Version
local util = require("crates.util")

local function section_diagnostic(
   section,
   kind,
   severity,
   scope,
   data)

   local d = Diagnostic.new({
      lnum = section.lines.s,
      end_lnum = section.lines.e - 1,
      col = 0,
      end_col = 999,
      severity = severity,
      kind = kind,
      data = data,
   })

   if scope == "header" then
      d.end_lnum = d.lnum + 1
   end

   return d
end

local function crate_diagnostic(
   crate,
   kind,
   severity,
   scope,
   data)

   local d = Diagnostic.new({
      lnum = crate.lines.s,
      end_lnum = crate.lines.e - 1,
      col = 0,
      end_col = 999,
      severity = severity,
      kind = kind,
      data = data,
   })

   if not scope then
      return d
   end

   if scope == "vers" then
      if crate.vers then
         d.lnum = crate.vers.line
         d.end_lnum = crate.vers.line
         d.col = crate.vers.col.s
         d.end_col = crate.vers.col.e
      end
   elseif scope == "def" then
      if crate.def then
         d.lnum = crate.def.line
         d.end_lnum = crate.def.line
         d.col = crate.def.col.s
         d.end_col = crate.def.col.e
      end
   elseif scope == "feat" then
      if crate.feat then
         d.lnum = crate.feat.line
         d.end_lnum = crate.feat.line
         d.col = crate.feat.col.s
         d.end_col = crate.feat.col.e
      end
   end

   return d
end

local function feat_diagnostic(
   crate,
   feat,
   kind,
   severity,
   data)

   return Diagnostic.new({
      lnum = crate.feat.line,
      end_lnum = crate.feat.line,
      col = crate.feat.col.s + feat.col.s,
      end_col = crate.feat.col.s + feat.col.e,
      severity = severity,
      kind = kind,
      data = data,
   })
end

function M.process_crates(sections, crates)
   local diagnostics = {}
   local s_cache = {}
   local cache = {}

   for _, s in ipairs(sections) do
      local key = s.text:gsub("%s+", "")

      if s.workspace and s.kind ~= "default" then
         table.insert(diagnostics, section_diagnostic(
         s,
         "workspace_section_not_default",
         vim.diagnostic.severity.WARN))

      elseif s.workspace and s.target ~= nil then
         table.insert(diagnostics, section_diagnostic(
         s,
         "workspace_section_has_target",
         vim.diagnostic.severity.ERROR))

      elseif s.invalid then
         table.insert(diagnostics, section_diagnostic(
         s,
         "section_invalid",
         vim.diagnostic.severity.WARN))

      elseif s_cache[key] then
         table.insert(diagnostics, section_diagnostic(
         s_cache[key],
         "section_dup_orig",
         vim.diagnostic.severity.HINT,
         "header",
         { lines = s_cache[key].lines }))

         table.insert(diagnostics, section_diagnostic(
         s,
         "section_dup",
         vim.diagnostic.severity.ERROR))

      else
         s_cache[key] = s
      end
   end

   for _, c in ipairs(crates) do
      local key = c:cache_key()
      if c.section.invalid then
         goto continue
      end

      if cache[key] then
         table.insert(diagnostics, crate_diagnostic(
         cache[key],
         "crate_dup_orig",
         vim.diagnostic.severity.HINT))

         table.insert(diagnostics, crate_diagnostic(
         c,
         "crate_dup",
         vim.diagnostic.severity.ERROR))

      else
         cache[key] = c

         if c.def then
            if c.def.text ~= "false" and c.def.text ~= "true" then
               table.insert(diagnostics, crate_diagnostic(
               c,
               "def_invalid",
               vim.diagnostic.severity.ERROR,
               "def"))

            end
         end

         local feats = {}
         for _, f in ipairs(c:feats()) do
            local orig = feats[f.name]
            if orig then
               table.insert(diagnostics, feat_diagnostic(
               c,
               feats[f.name],
               "feat_dup_orig",
               vim.diagnostic.severity.HINT,
               { feat = orig }))

               table.insert(diagnostics, feat_diagnostic(
               c,
               f,
               "feat_dup",
               vim.diagnostic.severity.WARN,
               { feat = f }))

            else
               feats[f.name] = f
            end
         end
      end

      ::continue::
   end

   return cache, diagnostics
end

function M.process_api_crate(crate, api_crate)
   local avoid_pre = state.cfg.avoid_prerelease and not crate:vers_is_pre()
   local versions = api_crate and api_crate.versions
   local newest, newest_pre, newest_yanked = util.get_newest(versions, avoid_pre, nil)
   newest = newest or newest_pre or newest_yanked

   local info = {
      lines = crate.lines,
      vers_line = crate.vers and crate.vers.line or crate.lines.s,
   }
   local diagnostics = {}

   if crate.dep_kind == "registry" then
      if api_crate then
         if api_crate.name ~= crate:package() then
            table.insert(diagnostics, crate_diagnostic(
            crate,
            "crate_name_case",
            vim.diagnostic.severity.ERROR,
            nil,
            { crate = crate, crate_name = api_crate.name }))

         end
      end

      if newest then
         if semver.matches_requirements(newest.parsed, crate:vers_reqs()) then

            info.vers_match = newest
            info.match_kind = "version"

            if crate.vers and crate.vers.text ~= edit.version_text(crate, newest.parsed) then
               info.vers_update = newest
            end
         else

            local match, match_pre, match_yanked = util.get_newest(versions, avoid_pre, crate:vers_reqs())
            info.vers_match = match or match_pre or match_yanked
            info.vers_upgrade = newest

            if info.vers_match then
               if crate.vers and crate.vers.text ~= edit.version_text(crate, info.vers_match.parsed) then
                  info.vers_update = info.vers_match
               end
            end

            if state.cfg.enable_update_available_warning then
               table.insert(diagnostics, crate_diagnostic(
               crate,
               "vers_upgrade",
               vim.diagnostic.severity.WARN,
               "vers"))

            end

            if match then

               info.match_kind = "version"
            elseif match_pre then

               info.match_kind = "prerelease"
               table.insert(diagnostics, crate_diagnostic(
               crate,
               "vers_pre",
               vim.diagnostic.severity.WARN,
               "vers"))

            elseif match_yanked then

               info.match_kind = "yanked"
               table.insert(diagnostics, crate_diagnostic(
               crate,
               "vers_yanked",
               vim.diagnostic.severity.ERROR,
               "vers"))

            else

               info.match_kind = "nomatch"
               local kind = "vers_nomatch"
               if not crate.vers then
                  kind = "crate_novers"
               end
               table.insert(diagnostics, crate_diagnostic(
               crate,
               kind,
               vim.diagnostic.severity.ERROR,
               "vers"))

            end
         end
      else
         table.insert(diagnostics, crate_diagnostic(
         crate,
         "crate_error_fetching",
         vim.diagnostic.severity.ERROR,
         "vers"))

      end
   end

   return info, diagnostics
end

function M.process_crate_deps(crate, version, deps)
   if crate.path or crate.git then
      return {}
   end

   local diagnostics = {}

   local valid_feats = {}
   for _, f in ipairs(version.features) do
      table.insert(valid_feats, f.name)
   end
   for _, d in ipairs(deps) do
      if d.opt then
         table.insert(valid_feats, d.name)
      end
   end

   if not state.cfg.disable_invalid_feature_diagnostic then
      for _, f in ipairs(crate:feats()) do
         if not vim.tbl_contains(valid_feats, f.name) then
            table.insert(diagnostics, feat_diagnostic(
            crate,
            f,
            "feat_invalid",
            vim.diagnostic.severity.ERROR,
            { feat = f }))

         end
      end
   end

   return diagnostics
end

return M
