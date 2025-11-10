#!/usr/bin/env sh
# always run from the repo root (script location)
cd -- "$(dirname -- "$0")" || exit 1

# prefer a repo-local luajit if present, else use PATH
LUABIN="./bin/linux64/luajit"
[ -x "$LUABIN" ] || LUABIN="${LUAJIT:-luajit}"

exec "$LUABIN" ./main.lua "$@"

