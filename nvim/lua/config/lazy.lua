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

-- Auto-import every spec in lua/plugins, but skip macOS AppleDouble "._*"
-- sidecar files. They appear because this repo lives on an exFAT/FUSE drive
-- that can't store extended attributes, so lazy would otherwise try to execute
-- "._telescope.lua" as Lua and fail. Moving the repo to internal (APFS) storage
-- would make this guard unnecessary.
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
  -- colorscheme used while installing plugins
  install = { colorscheme = { "habamax" } },
  -- automatically check for plugin updates
  checker = { enabled = true },
})

