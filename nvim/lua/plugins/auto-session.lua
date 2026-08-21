-- Session persistence. Auto-saves the session (open buffers, splits, cursor)
-- for the current directory, and restores it when you reopen nvim in that same
-- dir. This is the "reopen workspace" piece: launch nvim at a project's parent
-- dir and pick up exactly where you left off.
return {
  "rmagatti/auto-session",
  lazy = false, -- must load at startup so it can restore the session
  init = function()
    -- What gets captured in a session (auto-session's recommended set).
    vim.o.sessionoptions =
      "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"
  end,
  opts = {
    -- Never auto-save a session in these dirs (too generic to be a "project").
    suppressed_dirs = { "~/", "~/Downloads", "/tmp" },
  },
}
