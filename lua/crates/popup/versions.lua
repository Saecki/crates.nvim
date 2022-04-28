local M = {VersContext = {}, }







local VersContext = M.VersContext
local popup = require("crates.popup.common")
local HighlightText = popup.HighlightText
local WinOpts = popup.WinOpts
local state = require("crates.state")
local toml = require("crates.toml")
local types = require("crates.types")
local Range = types.Range
local Version = types.Version
local util = require("crates.util")

local function select_version(ctx, line, alt)
   local index = popup.item_index(line)
   local crate = ctx.crate
   local version = ctx.versions[index]
   if not version then return end

   local line_range
   line_range = util.set_version(ctx.buf, crate, version.parsed, alt)


   for l in line_range:iter() do
      local text = vim.api.nvim_buf_get_lines(ctx.buf, l, l + 1, false)[1]
      text = toml.trim_comments(text)
      if crate.syntax == "table" then
         local c = toml.parse_crate_table_vers(text)
         if c and c.vers then
            crate.vers.line = l
            crate.vers.col = c.vers.col
            crate.vers.decl_col = c.vers.decl_col
            crate.vers.quote = c.vers.quote
         end
      elseif crate.syntax == "plain" or crate.syntax == "inline_table" then
         local c = toml.parse_crate(text)
         if c and c.vers then
            crate.vers.line = l
            crate.vers.col = c.vers.col
            crate.vers.decl_col = c.vers.decl_col
            crate.vers.quote = c.vers.quote
         end
      end
   end
end

local function copy_version(versions, line)
   local index = popup.item_index(line)
   local version = versions[index]
   if not version then return end

   vim.fn.setreg(state.cfg.popup.copy_register, version.num)
end

function M.open(crate, versions, opts)
   popup.type = "versions"

   local title = string.format(state.cfg.popup.text.title, crate.name)
   local vers_width = 0
   local versions_text = {}

   for _, v in ipairs(versions) do
      local text, hl
      if v.yanked then
         text = string.format(state.cfg.popup.text.yanked, v.num)
         hl = state.cfg.popup.highlight.yanked
      elseif v.parsed.pre then
         text = string.format(state.cfg.popup.text.prerelease, v.num)
         hl = state.cfg.popup.highlight.prerelease
      else
         text = string.format(state.cfg.popup.text.version, v.num)
         hl = state.cfg.popup.highlight.version
      end

      table.insert(versions_text, { text = text, hl = hl })
      vers_width = math.max(vim.fn.strdisplaywidth(text), vers_width)
   end

   local date_width = 0
   if state.cfg.popup.show_version_date then
      for i, v in ipairs(versions_text) do
         local diff = vers_width - vim.fn.strdisplaywidth(v.text)
         local date = versions[i].created:display(state.cfg.date_format)
         v.text = v.text .. string.rep(" ", diff)
         v.suffix = string.format(state.cfg.popup.text.version_date, date)
         v.suffix_hl = state.cfg.popup.highlight.version_date

         date_width = math.max(vim.fn.strdisplaywidth(v.suffix), date_width)
      end
   end

   local width = popup.win_width(title, vers_width + date_width)
   local height = popup.win_height(versions)
   popup.open_win(width, height, title, versions_text, opts, function(_win, buf)
      local ctx = {
         buf = util.current_buf(),
         crate = crate,
         versions = versions,
      }
      for _, k in ipairs(state.cfg.popup.keys.select) do
         vim.api.nvim_buf_set_keymap(buf, "n", k, "", {
            callback = function()
               local line = util.cursor_pos()
               select_version(ctx, line)
            end,
            noremap = true,
            silent = true,
            desc = "Select version",
         })
      end

      for _, k in ipairs(state.cfg.popup.keys.select_alt) do
         vim.api.nvim_buf_set_keymap(buf, "n", k, "", {
            callback = function()
               local line = util.cursor_pos()
               select_version(ctx, line, true)
            end,
            noremap = true,
            silent = true,
            desc = "Select version alt",
         })
      end

      for _, k in ipairs(state.cfg.popup.keys.copy_version) do
         vim.api.nvim_buf_set_keymap(buf, "n", k, "", {
            callback = function()
               local line = util.cursor_pos()
               copy_version(versions, line)
            end,
            noremap = true,
            silent = true,
            desc = "Copy version",
         })
      end
   end)
end

return M
