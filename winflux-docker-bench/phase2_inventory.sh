#!/usr/bin/env bash
# Phase 2 inventory: clone your docs repos and catalog their compose files.
# Run INSIDE WSL2 Ubuntu on the host. Idempotent.
#
# Configure via environment (defaults are placeholders):
#   ORG    GitHub org/owner to clone from        (default: your-org)
#   REPOS  space-separated repo names to clone    (default: repo-one repo-two)
#   WIN_WORKSPACE  optional Windows path (via /mnt/c/...) to mirror the report into
#
# Usage:
#   ORG=your-org REPOS="repo-one repo-two" \
#     bash "$(wslpath 'C:\Users\youruser\dotfiles\winflux-docker-bench')/phase2_inventory.sh"
#
# Output:
#   ~/src/$ORG/{repos...}                cloned/updated
#   ~/phase2-inventory-<timestamp>.md    compose file catalog
#   ...also mirrored to $WIN_WORKSPACE if that dir exists.

set -euo pipefail

ORG="${ORG:-your-org}"
read -ra REPOS <<< "${REPOS:-repo-one repo-two}"

WORKDIR="$HOME/src/$ORG"
TS="$(date +%Y%m%d-%H%M%S)"
REPORT="$HOME/phase2-inventory-$TS.md"
WIN_WORKSPACE="${WIN_WORKSPACE:-}"

echo "=== Phase 2 inventory ==="
echo "Org:         $ORG"
echo "Repos:       ${REPOS[*]}"
echo "Working dir: $WORKDIR"
echo "Report:      $REPORT"
echo ""

# ----------------------------------------------------------------------------
# 0. Prereq check + auto-install missing tools
# ----------------------------------------------------------------------------
need_apt=()
need_yq=0
need_gh=0

if ! command -v git >/dev/null 2>&1; then need_apt+=(git); fi
if ! command -v jq  >/dev/null 2>&1; then need_apt+=(jq);  fi
if ! command -v gh  >/dev/null 2>&1; then need_gh=1;        fi
if ! command -v yq  >/dev/null 2>&1; then need_yq=1;        fi

if (( ${#need_apt[@]} > 0 )); then
    echo "Installing via apt (sudo): ${need_apt[*]}"
    sudo apt-get update -y
    sudo apt-get install -y "${need_apt[@]}"
fi

if (( need_gh == 1 )); then
    echo "Installing GitHub CLI from cli.github.com ..."
    sudo mkdir -p -m 755 /etc/apt/keyrings
    tmp_key=$(mktemp)
    wget -qO "$tmp_key" https://cli.github.com/packages/githubcli-archive-keyring.gpg
    sudo cp "$tmp_key" /etc/apt/keyrings/githubcli-archive-keyring.gpg
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    arch=$(dpkg --print-architecture)
    echo "deb [arch=$arch signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo apt-get update -y
    sudo apt-get install -y gh
fi

if (( need_yq == 1 )); then
    echo "Installing yq to ~/.local/bin ..."
    mkdir -p "$HOME/.local/bin"
    curl -fsSL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
         -o "$HOME/.local/bin/yq"
    chmod +x "$HOME/.local/bin/yq"
    export PATH="$HOME/.local/bin:$PATH"
    if ! grep -q '.local/bin' "$HOME/.bashrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    fi
fi

# Re-verify
for cmd in git gh yq jq; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "OK   $cmd  $(command -v "$cmd")"
    else
        echo "MISS $cmd (install failed)"
        exit 1
    fi
done

# Docker is optional for inventory, required for Phase 2.3
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    echo "OK   docker engine reachable"
else
    echo "WARN docker engine not reachable from WSL. For Phase 2.3, enable"
    echo "     Docker Desktop > Settings > Resources > WSL Integration for Ubuntu-24.04."
fi

# ----------------------------------------------------------------------------
# 1. gh auth check
# ----------------------------------------------------------------------------
if ! gh auth status >/dev/null 2>&1; then
    echo ""
    echo "gh is not authenticated. Run interactively, choose HTTPS for the"
    echo "git protocol, then re-run this script:"
    echo ""
    echo "    gh auth login"
    echo ""
    exit 1
fi
echo "OK   gh authenticated"

# Ensure gh uses HTTPS for git (avoids SSH-key chicken-and-egg for cloning)
gh config set git_protocol https >/dev/null 2>&1 || true
gh auth setup-git >/dev/null 2>&1 || true

# ----------------------------------------------------------------------------
# 2. Clone / update repos (plain HTTPS git clone; gh creds via git helper)
# ----------------------------------------------------------------------------
mkdir -p "$WORKDIR"
cd "$WORKDIR"

for repo in "${REPOS[@]}"; do
    if [[ -d "$repo/.git" ]]; then
        echo ""
        echo "Updating $repo ..."
        git -C "$repo" fetch --quiet || true
        git -C "$repo" pull --ff-only || echo "  (non-fast-forward; left $repo alone)"
    else
        echo ""
        echo "Cloning $ORG/$repo over HTTPS ..."
        git clone "https://github.com/$ORG/$repo.git"
    fi
done

# ----------------------------------------------------------------------------
# 3. Find compose files
# ----------------------------------------------------------------------------
echo ""
echo "Locating compose files under $WORKDIR ..."
mapfile -t composes < <(
    find "$WORKDIR" -type f \( \
            -name 'compose.yml'           -o -name 'compose.yaml' \
         -o -name 'docker-compose.yml'    -o -name 'docker-compose.yaml' \
         -o -name 'compose.*.yml'         -o -name 'compose.*.yaml' \
         -o -name 'docker-compose.*.yml'  -o -name 'docker-compose.*.yaml' \
        \) | sort
)
echo "Found ${#composes[@]} compose file(s)."

# ----------------------------------------------------------------------------
# 4. Build the markdown report
# ----------------------------------------------------------------------------
summarize_one_compose() {
    local f=$1
    local rel=${f#$WORKDIR/}

    printf '\n---\n\n## `%s`\n\n' "$rel"

    if ! yq -e '.services' "$f" >/dev/null 2>&1; then
        printf '_No `services` key found; showing first 40 lines._\n\n'
        printf '```yaml\n'
        head -n 40 "$f"
        printf '```\n\n'
        return
    fi

    printf '| Service | Image | Ports | Volumes | Env keys |\n'
    printf '|---|---|---|---|---|\n'

    # Service names
    local services
    services=$(yq '.services | keys | .[]' "$f")

    while IFS= read -r svc; do
        [[ -z $svc ]] && continue
        local img ports vols envk
        img=$(yq    -r ".services[\"$svc\"].image // \"(build)\"" "$f")
        ports=$(yq  -o=json ".services[\"$svc\"].ports   // []" "$f" | jq -c .)
        vols=$(yq   -o=json ".services[\"$svc\"].volumes // []" "$f" | jq -c .)
        envk=$(yq   -o=json ".services[\"$svc\"].environment // {}" "$f" \
               | jq -c '
                   if type=="object" then keys
                   elif type=="array" then map(split("=")[0])
                   else [] end')
        printf '| `%s` | `%s` | `%s` | `%s` | `%s` |\n' \
            "$svc" "$img" "$ports" "$vols" "$envk"
    done <<< "$services"
    printf '\n'
}

{
    printf '# Phase 2 compose inventory - %s\n\n' "$(date -Iseconds)"
    printf 'Repos under `%s`:\n' "$WORKDIR"
    for repo in "${REPOS[@]}"; do
        if [[ -d "$WORKDIR/$repo" ]]; then
            sha=$(git -C "$WORKDIR/$repo" rev-parse --short HEAD 2>/dev/null || echo '?')
            branch=$(git -C "$WORKDIR/$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')
            printf -- '- `%s` (branch: %s, HEAD: %s)\n' "$repo" "$branch" "$sha"
        fi
    done
    printf '\nCompose files: %s\n' "${#composes[@]}"
    for f in "${composes[@]}"; do
        summarize_one_compose "$f"
    done
} > "$REPORT"

# ----------------------------------------------------------------------------
# 5. Mirror report into the workspace folder (optional)
# ----------------------------------------------------------------------------
if [[ -n "$WIN_WORKSPACE" && -d $WIN_WORKSPACE ]]; then
    cp "$REPORT" "$WIN_WORKSPACE/"
    echo ""
    echo "Mirrored report to: $WIN_WORKSPACE/$(basename "$REPORT")"
fi

echo ""
echo "=== Done ==="
echo "Linux report:   $REPORT"
echo "Compose count:  ${#composes[@]}"
echo ""
echo "Next: review the report, then bring up the smallest stack (Core) per Phase 2.3."
