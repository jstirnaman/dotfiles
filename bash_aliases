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
