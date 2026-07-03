alias be='bundle exec'
alias g='git status -sb'
alias ll='ls -la'

# lg: lazygit. Inside Zellij, float it in the current pane's repo (cwd-aware);
# outside Zellij, just run lazygit. Works in bash and zsh.
lg() {
  if [ -n "${ZELLIJ:-}" ]; then
    zellij run --floating --close-on-exit --name lazygit -- lazygit "$@"
  else
    lazygit "$@"
  fi
}

# zsh only (bash skips this): autoload every function file in the dotfiles
# zsh/functions dir, so adding a new file there needs no registration step.
# Names resolve lazily against $fpath, which ~/.zshrc sets to this same dir.
if [ -n "${ZSH_VERSION:-}" ]; then
  autoload -Uz $DOTFILES/zsh/functions/*(.:t)
fi
