#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Locate luajit.exe
LUAJIT_EXE="$SCRIPT_DIR/bin/x64/luajit.exe"
BIN_DIR="$SCRIPT_DIR/bin/x64"

# Convert to Windows-style paths for the Windows process
WIN_LUAJIT="$(winepath -w "$LUAJIT_EXE")"
WIN_MAIN="$(winepath -w "$SCRIPT_DIR/main.lua")"
WIN_BIN_DIR="$(winepath -w "$BIN_DIR")"

WINEPATH="$WIN_BIN_DIR" wine "$WIN_LUAJIT" "$WIN_MAIN"

if [[ -z "${PS1:-}" ]]; then
  echo; echo "Exited. Press Enter to close this window."
  read -r
fi

