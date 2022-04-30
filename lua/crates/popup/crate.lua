local M = {CrateContext = {}, }












local CrateContext = M.CrateContext
local popup = require("crates.popup.common")
local HighlightText = popup.HighlightText
local WinOpts = popup.WinOpts
local state = require("crates.state")
local types = require("crates.types")
local Crate = types.Crate
local util = require("crates.util")

local function copy_value(ctx, line)
   local function copy(value)
      vim.fn.setreg(state.cfg.popup.copy_register, value)
   end

   local index = popup.item_index(line)
   if ctx.created_index == index then
      copy(ctx.crate.created:display(state.cfg.date_format))
   elseif ctx.downloads_index == index then
      copy(ctx.crate.downloads)
   elseif ctx.homepage_index == index then
      copy(ctx.crate.homepage)
   elseif ctx.repo_index == index then
      copy(ctx.crate.repository)
   elseif ctx.docs_index == index then
      copy(ctx.crate.documentation or util.docs_rs_url(ctx.crate.name))
   elseif ctx.crates_io_index == index then
      copy(util.crates_io_url(ctx.crate.name))
   end
end

local function open_url(ctx, line)
   local index = popup.item_index(line)
   if ctx.homepage_index == index then
      util.open_url(ctx.crate.homepage)
   elseif ctx.repo_index == index then
      util.open_url(ctx.crate.repository)
   elseif ctx.docs_index == index then
      util.open_url(ctx.crate.documentation or util.docs_rs_url(ctx.crate.name))
   elseif ctx.crates_io_index == index then
      util.open_url(util.crates_io_url(ctx.crate.name))
   end
end

local function pill_hl_text(items)
   local hl_text = {}
   for i, kw in ipairs(items) do
      if i ~= 1 then
         table.insert(hl_text, { text = " ", hl = "None" })
      end
      table.insert(hl_text, {
         text = state.cfg.popup.text.pill_left,
         hl = state.cfg.popup.highlight.pill_border,
      })
      table.insert(hl_text, {
         text = kw,
         hl = state.cfg.popup.highlight.pill_text,
      })
      table.insert(hl_text, {
         text = state.cfg.popup.text.pill_right,
         hl = state.cfg.popup.highlight.pill_border,
      })
   end
   return hl_text
end

function M.open(crate, opts)
   popup.type = "crate"

   local title = string.format(state.cfg.popup.text.title, crate.name)
   local text = state.cfg.popup.text
   local highlight = state.cfg.popup.highlight
   local info_text = {}
   local ctx = {
      crate = crate,
   }

   if crate.description then
      local desc = crate.description:gsub("\r", "\n")
      local lines = vim.split(desc, "\n")
      for _, l in ipairs(lines) do
         if l ~= "" then
            table.insert(info_text, { {
               text = string.format(text.description, l),
               hl = highlight.description,
            }, })
         end
      end
   end
   table.insert(info_text, { { text = "", hl = "None" } })

   if crate.created then
      table.insert(info_text, {
         {
            text = text.created_label,
            hl = highlight.created_label,
         }, {
            text = string.format(text.created, crate.created:display(state.cfg.date_format)),
            hl = highlight.created,
         },
      })
      ctx.created_index = #info_text
   end

   if crate.updated then
      table.insert(info_text, {
         {
            text = text.updated_label,
            hl = highlight.updated_label,
         }, {
            text = string.format(text.updated, crate.updated:display(state.cfg.date_format)),
            hl = highlight.updated,
         },
      })
      ctx.updated_index = #info_text
   end

   if crate.downloads then
      table.insert(info_text, {
         {
            text = text.downloads_label,
            hl = highlight.downloads_label,
         }, {
            text = string.format(text.downloads, crate.downloads),
            hl = highlight.downloads,
         },
      })
      ctx.downloads_index = #info_text
   end

   if crate.homepage then
      table.insert(info_text, {
         {
            text = text.homepage_label,
            hl = highlight.homepage_label,
         }, {
            text = string.format(text.homepage, crate.homepage),
            hl = highlight.homepage,
         },
      })
      ctx.homepage_index = #info_text
   end

   if crate.repository then
      table.insert(info_text, {
         {
            text = text.repository_label,
            hl = highlight.repository_label,
         }, {
            text = string.format(text.repository, crate.repository),
            hl = highlight.repository,
         },
      })
      ctx.repo_index = #info_text
   end

   table.insert(info_text, {
      {
         text = text.documentation_label,
         hl = highlight.documentation_label,
      }, {
         text = string.format(text.documentation, crate.documentation or util.docs_rs_url(crate.name)),
         hl = highlight.documentation,
      },
   })
   ctx.docs_index = #info_text

   table.insert(info_text, {
      {
         text = text.crates_io_label,
         hl = highlight.crates_io_label,
      }, {
         text = string.format(text.crates_io, util.crates_io_url(crate.name)),
         hl = highlight.crates_io,
      },
   })
   ctx.crates_io_index = #info_text

   if next(crate.categories) then
      local hl_text = { {
         text = text.categories_label,
         hl = highlight.categories_label,
      }, }
      vim.list_extend(hl_text, pill_hl_text(crate.categories))
      table.insert(info_text, hl_text)
   end

   if next(crate.keywords) then
      local hl_text = { {
         text = text.keywords_label,
         hl = highlight.keywords_label,
      }, }
      vim.list_extend(hl_text, pill_hl_text(crate.categories))
      table.insert(info_text, hl_text)
   end

   local content_width = 0
   for _, v in ipairs(info_text) do
      local w = 0
      for _, t in ipairs(v) do
         w = w + vim.fn.strdisplaywidth(t.text)
      end
      content_width = math.max(w, content_width)
   end

   local width = popup.win_width(title, content_width)
   local height = popup.win_height(info_text)
   popup.open_win(width, height, title, info_text, opts, function(_win, buf)
      for _, k in ipairs(state.cfg.popup.keys.copy_value) do
         vim.api.nvim_buf_set_keymap(buf, "n", k, "", {
            callback = function()
               local line = util.cursor_pos()
               copy_value(ctx, line)
            end,
            noremap = true,
            silent = true,
            desc = "Copy value",
         })
      end

      for _, k in ipairs(state.cfg.popup.keys.open_url) do
         vim.api.nvim_buf_set_keymap(buf, "n", k, "", {
            callback = function()
               local line = util.cursor_pos()
               open_url(ctx, line)
            end,
            noremap = true,
            silent = true,
            desc = "Open url",
         })
      end
   end)
end

return M
