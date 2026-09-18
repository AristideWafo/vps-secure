#!/usr/bin/env bash
#
# install.sh — installs (or uninstalls) the vpssecure CLI.
# Works both from a cloned repo (./install.sh) and standalone (curl | bash),
# in which case it clones the repo first.
#
# Usage:
#   ./install.sh              install / update
#   ./install.sh --uninstall  remove the vpssecure command (alias: -u, remove, uninstall)
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

do_install() {
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
}

do_uninstall() {
  local link="${BIN_DIR}/vpssecure"

  if [[ -L "$link" ]]; then
    rm -f "$link"
    ok "Removed ${link}"
  elif [[ -e "$link" ]]; then
    warn "${link} exists but isn't a symlink vpssecure manages — leaving it alone."
  else
    log "${link} not found, nothing to unlink."
  fi

  # Only offer to delete the checkout if it's the standalone clone we made
  # ourselves (~/.vpssecure by default). Never touch a repo the user cloned
  # and is running this script from directly — that's their working copy.
  if [[ "$SCRIPT_DIR" != "$INSTALL_HOME" && -d "$INSTALL_HOME/.git" ]]; then
    read -r -p "Also delete the cloned repo at ${INSTALL_HOME}? [y/N] " CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
      rm -rf "$INSTALL_HOME"
      ok "Removed ${INSTALL_HOME}"
    else
      log "Left ${INSTALL_HOME} in place."
    fi
  fi

  echo
  log "Not touched (remove manually if you want them gone too):"
  echo "    - Ansible collections installed via requirements.yml"
  echo "    - Any inventories/<env>/ directories you created (they hold real host data)"
  ok "vpssecure uninstalled."
}

case "${1:-}" in
  ""|install)
    do_install
    ;;
  --uninstall|-u|uninstall|remove)
    do_uninstall
    ;;
  *)
    err "Unknown argument: $1"
    echo "Usage: $0 [--uninstall]"
    exit 1
    ;;
esac
