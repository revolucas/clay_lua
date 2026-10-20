# Building clay_lua

## TL;DR
```bash
# Linux shared libraries and runtime binaries (including the RGFW adapter)
make linux bgfx-runtime

# Build/stage Technetium's MinGW LuaJIT import library and runtime once
cmake --preset linux-mingw
cmake --build build/linux-mingw --target technetium-luajit

# Cross-compile Windows DLLs (needs MinGW-w64)
make win64 bgfx-runtime CC_WIN64=x86_64-w64-mingw32-gcc
```

## Requirements
- Linux: gcc, make, and the X11 development libraries used by RGFW
- Windows cross (optional): `mingw-w64`

## Notes
- Sources are in `src/`:
  - `src/clay_lua_bindings/clay_lua_bindings.c`
  - `src/stb/stb_*_wrapper.c` (your wrappers over vendored stb headers)
- Clay and stb outputs go to `bin/linux64/` and `bin/x64/`.
- The RGFW adapter is built from the vendored RGFW 1.8.1 source and does not need LuaJIT headers.
- Linux builds use RGFW's X11 backend and need X11, XRandR, XCursor, Xi, Xinerama, and Xext development libraries.
- Windows builds cross-compile the RGFW adapter into `bin/x64/librgfw.dll`.
- `bgfx-runtime` stages the matching API 166 bgfx and Shaderc shared libraries
  from `BGFX_RUNTIME_ROOT` (default: `../../Projects/Game Engines/Technetium/bin`).
  Set `BGFX_RUNTIME_ROOT` to another bgfx bin root built from the same source.
- Windows linking uses the import library produced by Technetium's
  `technetium-luajit` target (`build/linux-mingw/stage/win64-mingw/lib`) and
  stages its matching `lua51.dll`. A local LuaJIT import library in
  `$(LUAJIT_ROOT)/src` takes precedence. Set `TECHNETIUM_MINGW_STAGE` to the
  corresponding `stage/win64-mingw` directory if Technetium uses a different
  build location.
- Runtime shader sources are in `shader/src/`; shared bgfx shader includes are
  in `shader/include/`. Clay recompiles them for the active renderer and caches
  bytecode under the platform's `bin/` directory.
- Outputs go to `bin/` (kept in git with `.gitkeep`, contents ignored).

## Web (Lua 5.4 + FFI-Wasm + BGFX)

The browser build uses the `lua-ffi-wasm` Lua 5.4.7 + luaffifb/libffi runtime
and compiles Clay, BGFX, Canvas2D bridges, and the stb helpers into one Wasm
module. Canvas2D is the default; choose BGFX WebGL2 from the renderer menu or
open `http://localhost:8000/?renderer=bgfx`. Canvas2D draws Clay's
render commands with the browser's 2D canvas and does not initialize a WebGL
context. Both paths use the same Lua app and Clay layout. Frame CPU time and
requestAnimationFrame FPS appear at the bottom right for quick comparison.

The Canvas2D path currently covers the demo's rectangles, borders, rich text,
clipping, node graph wires/grid, and color picker. BGFX texture handles are
backend-specific and are not drawn by Canvas2D. A small C adapter keeps BGFX
handle, transient-buffer, and 64-bit state/texture-flag calls on the C side of
the Lua FFI boundary.

Requirements: Emscripten (`emcc`, `em++`, `emconfigure`, `emmake`), GNU Make,
Autoconf, Libtool, and the project's BGFX, bx, and bimg source checkouts. By
default the build finds those checkouts as siblings of `clay_lua`. Set
`BGFX_ROOT`, `BX_ROOT`, and `BIMG_ROOT` if they are elsewhere. The web target
builds the BGFX Wasm libraries and compiles the WebGL shader pair with the
host LuaJIT and shaderc runtime before linking Lua. Build and serve the demo:

```bash
make web
make web-serve
```

The first build checks out `thenumbernine/lua-ffi-wasm` and its submodules into
the ignored `web/vendor/` directory. To use an existing checkout, set
`LUA_FFI_WASM_ROOT=/path/to/lua-ffi-wasm` before running `make web`. The demo is
served at `http://localhost:8000/` by default; set `PORT` to choose another
port. Build artifacts go to `web/dist/`.
