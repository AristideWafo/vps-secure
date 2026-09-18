#!/usr/bin/env bash
#
# install.sh — installs the vpssecure CLI into your PATH.
# Works both from a cloned repo (./install.sh) and standalone (curl | bash),
# in which case it clones the repo first.
#
set -euo pipefail

REPO_URL="${VPSSECURE_REPO_URL:-https://github.com/AristideWafo/vps-secure.git}"
INSTALL_HOME="${VPSSECURE_HOME:-$HOME/.vpssecure}"
BIN_DIR="${VPSSECURE_BIN_DIR:-$HOME/.local/bin}"

log()  { echo "==> $*"; }
ok()   { echo "✓ $*"; }
warn() { echo "! $*" >&2; }
err()  { echo "✗ $*" >&2; }

require_bin() {
  command -v "$1" >/dev/null 2>&1
}

# Resolve where the repo actually lives: either this script sits inside an
# already-cloned repo (has bin/vpssecure next to it), or we need to clone one.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "${SCRIPT_DIR}/bin/vpssecure" ]]; then
  REPO_DIR="$SCRIPT_DIR"
  log "Using existing checkout at ${REPO_DIR}"
else
  require_bin git || { err "git is required to install vpssecure. Install it and re-run."; exit 1; }
  REPO_DIR="$INSTALL_HOME"
  if [[ -d "$REPO_DIR/.git" ]]; then
    log "Updating existing install at ${REPO_DIR}"
    git -C "$REPO_DIR" pull --ff-only
  else
    log "Cloning ${REPO_URL} to ${REPO_DIR}"
    git clone --depth 1 "$REPO_URL" "$REPO_DIR"
  fi
fi

chmod +x "${REPO_DIR}/bin/vpssecure"

mkdir -p "$BIN_DIR"
ln -sf "${REPO_DIR}/bin/vpssecure" "${BIN_DIR}/vpssecure"
ok "Linked ${BIN_DIR}/vpssecure -> ${REPO_DIR}/bin/vpssecure"

# Dependencies check — never auto-installs system packages, only reports.
MISSING=()
require_bin ansible-playbook || MISSING+=("ansible (pip install ansible)")
require_bin ansible || MISSING+=("ansible")

if [[ ${#MISSING[@]} -gt 0 ]]; then
  warn "Missing dependencies:"
  printf '    - %s\n' "${MISSING[@]}"
else
  if require_bin ansible-galaxy && [[ -f "${REPO_DIR}/requirements.yml" ]]; then
    log "Installing required Ansible collections"
    if ansible-galaxy collection install -r "${REPO_DIR}/requirements.yml" >/dev/null 2>&1; then
      ok "Collections installed"
    else
      warn "Could not install Ansible collections automatically. Run manually:"
      echo "    ansible-galaxy collection install -r ${REPO_DIR}/requirements.yml"
    fi
  fi
fi

case ":$PATH:" in
  *":${BIN_DIR}:"*) ;;
  *) warn "${BIN_DIR} is not in your PATH. Add this to your shell profile:"
     echo "    export PATH=\"${BIN_DIR}:\$PATH\"" ;;
esac

ok "vpssecure installed. Run 'vpssecure' to start."
