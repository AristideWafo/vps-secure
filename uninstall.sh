#!/usr/bin/env bash
#
# uninstall.sh — convenience alias for `install.sh --uninstall`.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/install.sh" --uninstall
