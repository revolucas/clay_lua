#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Locate luajit.exe
LUAJIT_EXE="$SCRIPT_DIR/bin/x64/luajit.exe"

# Convert to Windows-style paths for the Windows process
WIN_LUAJIT="$(winepath -w "$LUAJIT_EXE")"
WIN_MAIN="$(winepath -w "$SCRIPT_DIR/main.lua")"

wine "$WIN_LUAJIT" "$WIN_MAIN"

if [[ -z "${PS1:-}" ]]; then
  echo; echo "Exited. Press Enter to close this window."
  read -r
fi
