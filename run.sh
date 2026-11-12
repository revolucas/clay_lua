#!/usr/bin/env sh
# Always run from the app root so relative asset paths work.
APP_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) || exit 1
cd -- "$APP_DIR" || exit 1

# Prefer the libraries bundled with the release package, including LuaJIT,
# BGFX, and Shaderc. Keep any caller-provided paths available as fallbacks.
export LD_LIBRARY_PATH="$APP_DIR/bin/linux64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# prefer a repo-local luajit if present, else use PATH
LUABIN="./bin/linux64/luajit"
[ -x "$LUABIN" ] || LUABIN="${LUAJIT:-luajit}"

exec "$LUABIN" ./main.lua "$@"
