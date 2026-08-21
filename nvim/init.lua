require("config.lazy")

-- Copy a visual selection to the system clipboard.
vim.keymap.set("v", "<leader>y", '"+y', { desc = "Yank to system clipboard" })
