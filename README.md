# crates.nvim
[![CI](https://github.com/saecki/crates.nvim/actions/workflows/CI.yml/badge.svg)](https://github.com/saecki/crates.nvim/actions/workflows/CI.yml)
![LOC](https://tokei.rs/b1/github/saecki/crates.nvim?category=code)

A neovim plugin that helps managing crates.io dependencies.

This project is still in it's infancy, so you might encounter some bugs.
Feel free to open issues.

## Features
- Complete crate versions and features
- Completion sources for:
    - [nvim-cmp](https://github.com/hrsh7th/nvim-cmp)
    - [coq.nvim](https://github.com/ms-jpq/coq_nvim)
- [null-ls.nvim](https://github.com/jose-elias-alvarez/null-ls.nvim) code actions
- Update crates to newest compatible version
- Upgrade crates to newest version
- Respect existing version requirements and update them in an elegant way (`smart_insert`)
- Automatically load when opening a `Cargo.toml` file (`autoload`)
- Live update while editing (`autoupdate`)
- Show version and upgrade candidates
    - Indicate if compatible version is a pre-release or yanked
    - Indicate if no version is compatible
- Open floating window with crate versions
    - Select a version by pressing enter (`popup.keys.select`)
- Open floating window with crate features
    - Navigate the feature hierarchy
    - Enable/disable features
    - Indicate if a feature is enabled directly or transitively
- Open floating window with crate dependencies
    - Navigate the dependency hierarchy
    - Indicate if a dependency is optional

![image](https://user-images.githubusercontent.com/43008152/134776663-aae0d50a-ee6e-4539-a766-8cccc629c21a.png)

### Popup
![image](https://user-images.githubusercontent.com/43008152/134776682-c995b48a-cad5-43d4-80e8-ee3637a5a78a.png)

### Completion
![image](https://user-images.githubusercontent.com/43008152/134776687-c1359967-4b96-460b-b5f2-2d80b6a09208.png)

## Setup

### Installation
To use with neovim 0.6 or to stay on a stable release.

[__vim-plug__](https://github.com/junegunn/vim-plug)
```
Plug 'nvim-lua/plenary.nvim'
Plug 'saecki/crates.nvim', { 'tag': 'v0.2.1' }

lua require('crates').setup()
```

[__packer.nvim__](https://github.com/wbthomason/packer.nvim)
```lua
use {
    'saecki/crates.nvim',
    tag = 'v0.2.1',
    requires = { 'nvim-lua/plenary.nvim' },
    config = function()
        require('crates').setup()
    end,
}
```

If you're feeling adventurous and want to use the newest features.

[__vim-plug__](https://github.com/junegunn/vim-plug)
```
Plug 'nvim-lua/plenary.nvim'
Plug 'saecki/crates.nvim'

lua require('crates').setup()
```

[__packer.nvim__](https://github.com/wbthomason/packer.nvim)
```lua
use {
    'saecki/crates.nvim',
    requires = { 'nvim-lua/plenary.nvim' },
    config = function()
        require('crates').setup()
    end,
}
```

For lazy loading.
```lua
use {
    'saecki/crates.nvim',
    event = { "BufRead Cargo.toml" },
    requires = { { 'nvim-lua/plenary.nvim' } },
    config = function()
        require('crates').setup()
    end,
}
```

### [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) source
Just add it to your list of sources.
```lua
require('cmp').setup {
    ...
    sources = {
        { name = "path" },
        { name = "buffer" },
        { name = "nvim_lsp" },
        ...
        { name = "crates" },
    },
}
```

Or add it lazily.
```viml
autocmd FileType toml lua require('cmp').setup.buffer { sources = { { name = 'crates' } } }
```

### [coq.nvim](https://github.com/ms-jpq/coq_nvim) source
Enable it in the setup, and optionally change the display name.
```lua
require('crates').setup {
    ...
    src = {
        ...
        coq = {
            enabled = true,
            name = "crates.nvim",
        },
    },
}
```

### [null-ls.nvim](https://github.com/jose-elias-alvarez/null-ls.nvim) source
Enable it in the setup, and optionally change the display name.
```lua
local null_ls = require('null-ls')
require('crates').setup {
    ...
    null_ls = {
        enabled = true,
        name = "crates.nvim",
    },
}
```

## Config

For more information about the type of some fields see [`teal/crates/config.tl`](teal/crates/config.tl).

__Default__

The icons in the default configuration require a patched font.<br>
Any [Nerd Font](https://www.nerdfonts.com/font-downloads) should work.
```lua
require('crates').setup {
    smart_insert = true,
    insert_closing_quote = true,
    avoid_prerelease = true,
    autoload = true,
    autoupdate = true,
    loading_indicator = true,
    date_format = "%Y-%m-%d",
    notification_title = "Crates",
    disable_invalid_feature_diagnostic = false,
    text = {
        loading = "   Loading",
        version = "   %s",
        prerelease = "   %s",
        yanked = "   %s",
        nomatch = "   No match",
        upgrade = "   %s",
        error = "   Error fetching crate",
    },
    highlight = {
        loading = "CratesNvimLoading",
        version = "CratesNvimVersion",
        prerelease = "CratesNvimPreRelease",
        yanked = "CratesNvimYanked",
        nomatch = "CratesNvimNoMatch",
        upgrade = "CratesNvimUpgrade",
        error = "CratesNvimError",
    },
    popup = {
        autofocus = false,
        copy_register = '"',
        style = "minimal",
        border = "none",
        show_version_date = false,
        show_dependency_version = true,
        max_height = 30,
        min_width = 20,
        text = {
            title = "  %s ",
            pill_left = "",
            pill_right = "",
            created_label = " created        ",
            created = "%s",
            updated_label = " updated        ",
            updated = "%s",
            downloads_label = " downloads      ",
            downloads = "%s",
            homepage_label = " homepage       ",
            homepage = "%s",
            repository_label = " repository     ",
            repository = "%s",
            documentation_label = " documentation  ",
            documentation = "%s",
            crates_io_label = " crates.io      ",
            crates_io = "%s",
            categories_label = " categories     ",
            keywords_label = " keywords       ",
            version = "   %s ",
            prerelease = "  %s ",
            yanked = "  %s ",
            version_date = " %s ",
            feature = "   %s ",
            enabled = "  %s ",
            transitive = "  %s ",
            dependency = "   %s ",
            optional = "  %s ",
            dependency_version = " %s ",
            loading = " ",
        },
        highlight = {
            title = "CratesNvimPopupTitle",
            pill_text = "CratesNvimPopupPillText",
            pill_border = "CratesNvimPopupPillBorder",
            description = "CratesNvimPopupDescription",
            created_label = "CratesNvimPopupLabel",
            created = "CratesNvimPopupValue",
            updated_label = "CratesNvimPopupLabel",
            updated = "CratesNvimPopupValue",
            downloads_label = "CratesNvimPopupLabel",
            downloads = "CratesNvimPopupValue",
            homepage_label = "CratesNvimPopupLabel",
            homepage = "CratesNvimPopupUrl",
            repository_label = "CratesNvimPopupLabel",
            repository = "CratesNvimPopupUrl",
            documentation_label = "CratesNvimPopupLabel",
            documentation = "CratesNvimPopupUrl",
            crates_io_label = "CratesNvimPopupLabel",
            crates_io = "CratesNvimPopupUrl",
            categories_label = "CratesNvimPopupLabel",
            keywords_label = "CratesNvimPopupLabel",
            version = "CratesNvimPopupVersion",
            prerelease = "CratesNvimPopupPreRelease",
            yanked = "CratesNvimPopupYanked",
            version_date = "CratesNvimPopupVersionDate",
            feature = "CratesNvimPopupFeature",
            enabled = "CratesNvimPopupEnabled",
            transitive = "CratesNvimPopupTransitive",
            dependency = "CratesNvimPopupDependency",
            optional = "CratesNvimPopupOptional",
            dependency_version = "CratesNvimPopupDependencyVersion",
            loading = "CratesNvimPopupLoading",
        },
        keys = {
            hide = { "q", "<esc>" },
            open_url = { "<cr>" },
            select = { "<cr>" },
            select_alt = { "s" },
            toggle_feature = { "<cr>" },
            copy_value = { "yy" },
            goto_item = { "gd", "K", "<C-LeftMouse>" },
            jump_forward = { "<c-i>" },
            jump_back = { "<c-o>", "<C-RightMouse>" },
        },
    },
    src = {
        insert_closing_quote = true,
        text = {
            prerelease = "  pre-release ",
            yanked = "  yanked ",
        },
        coq = {
            enabled = false,
            name = "Crates",
        },
    },
    null_ls = {
        enabled = false,
        name = "Crates",
    },
}
```

__Plain text__

Replace these fields if you don't have a patched font.
```lua
require('crates').setup {
    text = {
        loading = "  Loading...",
        version = "  %s",
        prerelease = "  %s",
        yanked = "  %s yanked",
        nomatch = "  Not found",
        upgrade = "  %s",
        error = "  Error fetching crate",
    },
    popup = {
        text = {
            title = " # %s ",
            version = " %s ",
            prerelease = " %s ",
            yanked = " %s yanked ",
            feature = "   %s ",
            enabled = " * %s ",
            transitive = " ~ %s ",
        },
    },
    cmp = {
        text = {
            prerelease = " pre-release ",
            yanked = " yanked ",
        },
    },
}
```

### Functions
```lua
-- Setup config and auto commands.
require('crates').setup(cfg: Config)

-- Disable UI elements (virtual text and diagnostics).
require('crates').hide()
-- Enable UI elements (virtual text and diagnostics).
require('crates').show()
-- Enable or disable UI elements (virtual text and diagnostics).
require('crates').toggle()
-- Update data. Optionally specify which `buf` to update.
require('crates').update(buf: integer|nil)
-- Reload data (clears cache). Optionally specify which `buf` to reload.
require('crates').reload(buf: integer|nil)

-- Upgrade the crate on the current line.
-- If the `alt` flag is passed as true, the opposite of the `smart_insert` config
-- option will be used to insert the version.
require('crates').upgrade_crate(alt: boolean|nil)
-- Upgrade the crates on the lines visually selected.
-- See `crates.upgrade_crate()`.
require('crates').upgrade_crates(alt: boolean|nil)
-- Upgrade all crates in the buffer.
-- See `crates.upgrade_crate()`.
require('crates').upgrade_all_crates(alt: boolean|nil)

-- Update the crate on the current line.
-- See `crates.upgrade_crate()`.
require('crates').update_crate(alt: boolean|nil)
-- Update the crates on the lines visually selected.
-- See `crates.upgrade_crate()`.
require('crates').update_crates(alt: boolean|nil)
-- Update all crates in the buffer.
-- See `crates.upgrade_crate()`.
require('crates').update_all_crates(alt: boolean|nil)

-- Open the homepage of the crate on the current line.
require('crates').open_homepage()
-- Open the repository page of the crate on the current line.
require('crates').open_repository()
-- Open the `docs.rs` page of the crate on the current line.
require('crates').open_documentation()
-- Open the `crates.io` page of the crate on the current line.
require('crates').open_crates_io()

-- Show/hide popup with all versions, all features or details about one feature.
-- If `popup.autofocus` is disabled calling this again will focus the popup.
require('crates').show_popup()
-- Same as `crates.show_popup()` but always show versions.
require('crates').show_versions_popup()
-- Same as `crates.show_popup()` but always show features or features details.
require('crates').show_features_popup()
-- Same as `crates.show_popup()` but always show depedencies.
require('crates').show_dependencies_popup()
-- Focus the popup (jump into the floating window).
-- Optionally specify the line to jump to, inside the popup.
require('crates').focus_popup(line: integer|nil)
-- Hide the popup.
require('crates').hide_popup()
```

### Key mappings
Some examples of key mappings.
```vim
nnoremap <silent> <leader>ct :lua require('crates').toggle()<cr>
nnoremap <silent> <leader>cr :lua require('crates').reload()<cr>

nnoremap <silent> <leader>cv :lua require('crates').show_versions_popup()<cr>
nnoremap <silent> <leader>cf :lua require('crates').show_features_popup()<cr>

nnoremap <silent> <leader>cu :lua require('crates').update_crate()<cr>
vnoremap <silent> <leader>cu :lua require('crates').update_crates()<cr>
nnoremap <silent> <leader>ca :lua require('crates').update_all_crates()<cr>
nnoremap <silent> <leader>cU :lua require('crates').upgrade_crate()<cr>
vnoremap <silent> <leader>cU :lua require('crates').upgrade_crates()<cr>
nnoremap <silent> <leader>cA :lua require('crates').upgrade_all_crates()<cr>

nnoremap <silent> <leader>cD :lua require('crates').open_docs_rs()<cr>
nnoremap <silent> <leader>cC :lua require('crates').open_crates_io()<cr>
```

### Show appropriate documentation in `Cargo.toml`
How you might integrate `show_popup` into your `init.vim`.
```vim
nnoremap <silent> K :call <SID>show_documentation()<cr>
function! s:show_documentation()
    if (index(['vim','help'], &filetype) >= 0)
        execute 'h '.expand('<cword>')
    elseif (index(['man'], &filetype) >= 0)
        execute 'Man '.expand('<cword>')
    elseif (expand('%:t') == 'Cargo.toml')
        lua require('crates').show_popup()
    else
        lua vim.lsp.buf.hover()
    endif
endfunction
```

How you might integrate `show_popup` into your `init.lua`.
```lua
vim.api.nvim_set_keymap('n', 'K', ':lua show_documentation()', { noremap = true, silent = true })
function show_documentation()
    local filetype = vim.bo.filetype
    if vim.tbl_contains({ 'vim','help' }, filetype) then
        vim.cmd('h '..vim.fn.expand('<cword>'))
    elseif vim.tbl_contains({ 'man' }, filetype) then
        vim.cmd('Man '..vim.fn.expand('<cword>'))
    elseif vim.fn.expand('%:t') == 'Cargo.toml' then
        require('crates').show_popup()
    else
        vim.lsp.buf.hover()
    end
end
```

## TODO
- info popup with crate description, downloads, and urls

## Related projects
- [simrat39/rust-tools.nvim](https://github.com/simrat39/rust-tools.nvim)
- [mhinz/vim-crates](https://github.com/mhinz/vim-crates)
- [shift-d/crates.nvim](https://github.com/shift-d/crates.nvim)
- [kahgeh/ls-crates.nvim](https://github.com/kahgeh/ls-crates.nvim)
