-- Syntax highlighting, filetype detection, and folding for *.prr review files.
return {
  "danobi/prr",
  config = function()
    local prr_highlights = {
      prrAdded = "Function",
      prrRemoved = "Keyword",
      prrFile = "Special",
      prrHeader = "Directory",
      prrIndex = "Special",
      prrChunk = "Special",
      prrChunkH = "Special",
      prrTagName = "Special",
      prrResult = "Special",
    }

    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("Prr", { clear = true }),
      pattern = "prr",
      callback = function()
        for group, target in pairs(prr_highlights) do
          vim.api.nvim_set_hl(0, group, { link = target })
        end
      end,
    })
  end,
}
