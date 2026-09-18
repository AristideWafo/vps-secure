#!/usr/bin/env bash
#
# run.sh — installs vpssecure (via install.sh) then launches it immediately.
# Convenience entry point for a fresh clone/download: ./run.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"${SCRIPT_DIR}/install.sh"

exec "${SCRIPT_DIR}/bin/vpssecure" "$@"
