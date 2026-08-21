# Setup

Deploy everything with the installer:

```sh
cd ~/dotfiles && ./install.sh
```

`install.sh` is idempotent (it backs up anything it replaces). It:

- **renders** Zellij configs/layouts and the Ghostty config to `~/.config`
  (placeholders like `__HOME__` are substituted at install time — Zellij doesn't
  expand env vars in layout `cwd`),
- **symlinks** the gh-dash config and the `prr-review` wrapper (`~/.local/bin`),
- **renders** `~/.config/prr/config.toml` with a token from `gh auth token`
  (chmod 600; the repo only stores a placeholder, never a real token),
- runs `claude/install.sh` to symlink Claude config.

After deploying, restart Zellij fresh so config/layout changes load:

```sh
zellij delete-session main
```

## Prerequisites

- **Zellij**, **Ghostty**, **neovim** (the configs assume `nvim` as `$EDITOR`).
- **`~/.local/bin` on `PATH`** — otherwise the `prr-review` symlink won't resolve.
- Source `bash_aliases` from your shell startup file (see [Shell aliases](#shell-aliases)).

### PR triage flow (gh-dash + prr)

`Alt g` floats [gh-dash](https://gh-dash.dev) in the focused pane's repo (bound
in `zellij/config.kdl`). To make it work:

```sh
gh extension install dlvhdr/gh-dash   # the dashboard
cargo install prr                     # editor-native PR reviews
gh auth status                        # must be authenticated
```

In gh-dash: `R` opens an inline review via prr (in `nvim`), `a` runs a Claude
first-pass over the diff, `A` requests Copilot as reviewer, `v` approves.

Caveats to verify on first use:

- The token from `gh auth token` may lack the `repo` scope prr needs to *submit*
  reviews — if a submit fails, put a PAT with `repo` scope in
  `~/.config/prr/config.toml`.
- The `a` keybind pipes `gh pr diff … | claude -p "…"`; confirm the non-interactive
  flag against current Claude Code docs.

# Neovim finder (Telescope)

Leader is `<Space>`:

- `<Space>ff` — find files by name
- `<Space>fg` — live grep across file contents (needs `ripgrep`)

Both search recursively from nvim's working dir, so launch nvim at a parent dir
to reach every repo under it. Also `<Space>fb` (buffers), `<Space>fh` (help).

# Shell aliases

`bash_aliases` (aliases plus the `lg` lazygit helper) is **not** symlinked or
sourced by `install.sh`. Source it yourself from your shell's startup file so the
aliases are available:

```sh
# in ~/.bashrc or ~/.zshrc
[ -f ~/dotfiles/bash_aliases ] && . ~/dotfiles/bash_aliases
```

Adjust the path to wherever this repo lives. The `lg` function is shell-agnostic
(works in bash and zsh): inside Zellij it floats lazygit in the current pane's
repo; outside Zellij it runs lazygit directly.

# Manage SSH keys with Mac OS

## Store a passphrase in the Mac OS Keychain.

In MacOS 12.0 Monterey and newer, enter the following command:

`ssh-add --apple-use-keychain ~/.ssh/[your-private-key-file]`

## Configure `ssh-agent` to always use Keychain (in MacOS Sierra and later).

1. If you haven't already, complete Step 1 above to store the passphrase in the keychain.
2. If you haven't already, create an *~/.ssh/config* file.
   In other words, in the *.ssh* directory in your home dir (*~/*), make a file called *config*.
3. In the *~/.ssh/config* file from the previous step, add the following lines:

 ```sh
 Host *
   UseKeychain yes
   AddKeysToAgent yes
   IdentityFile ~/.ssh/[your-private-key-file]
```

The next time you make an SSH request, SSH will try the private keys specified in *~/.ssh/config*,
and then look for the passphrase in Keychain.

