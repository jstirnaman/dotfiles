-- Fuzzy finder. find_files opens any file by name; live_grep jumps to any line
-- by its text — both search recursively from nvim's cwd, so launching nvim at a
-- parent dir lets you reach every repo under it. live_grep needs ripgrep (`rg`).
return {
  "nvim-telescope/telescope.nvim",
  branch = "0.1.x",
  dependencies = { "nvim-lua/plenary.nvim" },
  keys = {
    { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files" },
    { "<leader>fg", "<cmd>Telescope live_grep<cr>",  desc = "Live grep" },
    { "<leader>fb", "<cmd>Telescope buffers<cr>",    desc = "Buffers" },
    { "<leader>fh", "<cmd>Telescope help_tags<cr>",  desc = "Help tags" },
  },
}
