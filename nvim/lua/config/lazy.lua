-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Auto-import every spec in lua/plugins, skipping any macOS AppleDouble "._*"
-- sidecar files. The repo now lives on internal APFS storage so these normally
-- won't appear, but skipping them is cheap insurance against ever reading the
-- config from an exFAT/FUSE drive, which manufactures "._telescope.lua" files
-- that lazy would otherwise try to execute as Lua.
local plugins_spec = {}
for name, kind in vim.fs.dir(vim.fn.stdpath("config") .. "/lua/plugins") do
  if name:sub(1, 2) ~= "._" then
    if kind == "directory" then
      plugins_spec[#plugins_spec + 1] = { import = "plugins." .. name }
    elseif name:sub(-4) == ".lua" then
      plugins_spec[#plugins_spec + 1] = { import = "plugins." .. name:sub(1, -5) }
    end
  end
end

-- Setup lazy.nvim
require("lazy").setup({
  spec = plugins_spec,
  -- No plugins here use luarocks, so disable it and skip the hererocks/lua5.1
  -- bootstrap (clears the :checkhealth luarocks errors). Flip to enabled = true
  -- if you ever add a plugin that requires rocks.
  rocks = { enabled = false },
  -- colorscheme used while installing plugins
  install = { colorscheme = { "habamax" } },
  -- automatically check for plugin updates
  checker = { enabled = true },
})

