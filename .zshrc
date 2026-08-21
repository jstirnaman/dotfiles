source ~/.profile

set -a
source ~/.env.kapa-external-api-key
set +a
   
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-_HOME_/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-_HOME_/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ============================================================================
# ZELLIJ PERSISTENT SESSION SETUP
# ============================================================================
# Removed: custom pane_record/pane_restore (bin/zellij-pane-state.sh) keyed
# cwd/branch state by $ZELLIJ_PANE_ID, a small integer zellij reuses across
# different sessions — new panes silently inherited stale cwd from unrelated
# sessions' pane 0/1/2, clobbering layout-defined `cwd=`. Zellij's own
# session_serialization (see zellij/config.kdl) already does this correctly,
# scoped per session, restoring cwd/branch on `zellij attach`.

# ============================================================================
# AUTO-LAUNCH ZELLIJ (optional but recommended)
# ============================================================================
# If not already in Zellij, attach to persistent "main" session
# If session doesn't exist, create it with the workstreams layout

# The following is configured in Ghostty. Only configure in one or the other.
# if [[ -z "$ZELLIJ" ]]; then
#  zellij attach -c "main" -l workstreams || zellij --session main --layout workstreams
# fi

# If you come from bash you might have to change your $PATH.
# export PATH=_HOME_/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="_HOME_/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
#ZSH_THEME="robbyrussell"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(dotenv git jsontools macos node python rust virtualenv) 

# source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
export PATH="$PATH:_HOME_/.influxdb/"
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

source ~/jstirnaman/dotfiles/bash_aliases

# ─── fzf shell integration ────────────────────────────────────────────
# Keybindings: Ctrl-R (history), Ctrl-T (file finder), Alt-C (cd)
# Plus ** tab completion (e.g. `vim **<TAB>`)
# Requires fzf >= 0.48.0; for older versions, source the scripts directly.
source <(fzf --zsh)

# Optional: customize defaults
# export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --border"
# export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"
# export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
# export FZF_ALT_C_COMMAND="fd --type d --hidden --follow --exclude .git"

# ─── Ghostty shell integration (manual fallback) ─────────────────────
# Ghostty's `shell-integration = detect` handles this automatically.
# Only uncomment if auto-detection ever fails:
# if [[ -n $GHOSTTY_RESOURCES_DIR ]]; then
#   source "$GHOSTTY_RESOURCES_DIR/shell-integration/zsh/ghostty-integration"
# fi

# ─── hx + fzf: fuzzy file picker ─────────────────────────────────────
# Usage:
#   hxf           - pick file(s) to open in Helix
#   hxf src/      - pick from a specific directory
#   hxf -q "main" - start with a query pre-filled
function hxf() {
  local dir=""
  local query=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -q|--query) query="$2"; shift 2 ;;
      *)          dir="$1"; shift ;;
    esac
  done

  local fzf_cmd="fzf --multi --preview 'bat --color=always --style=numbers --line-range=:200 {} 2>/dev/null || head -200 {}'"
  [[ -n "$query" ]] && fzf_cmd+=" --query='$query'"

  local selected
  if [[ -n "$dir" ]]; then
    selected=$(find "$dir" -type f 2>/dev/null | eval "$fzf_cmd")
  else
    selected=$(eval "$fzf_cmd")
  fi

  [[ -n "$selected" ]] && hx ${(f)selected}
}

# ─── hx + fzf: grep then open at line ────────────────────────────────
# Usage:
#   hxg "pattern"       - ripgrep for pattern, pick match, open at line
#   hxg "pattern" src/  - search in a specific directory
function hxg() {
  local pattern="$1"
  local dir="${2:-.}"

  if [[ -z "$pattern" ]]; then
    echo "Usage: hxg <pattern> [directory]"
    return 1
  fi

  local selected
  selected=$(rg --color=always --line-number --no-heading "$pattern" "$dir" \
    | fzf --ansi --delimiter=: \
          --preview 'bat --color=always --style=numbers --highlight-line={2} {1} 2>/dev/null || head -200 {1}' \
          --preview-window '+{2}-10')

  if [[ -n "$selected" ]]; then
    local file=$(echo "$selected" | cut -d: -f1)
    local line=$(echo "$selected" | cut -d: -f2)
    hx "$file:$line"
  fi
}
# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=(_HOME_/.docker/completions $fpath)
autoload -Uz compinit
fpath=($DOTFILES/zsh/functions $fpath)
autoload -Uz wt wtcd
compinit
# End of Docker CLI completions

# Initialize Zoxide. Keep it at the end of this file
eval "$(zoxide init zsh)"
