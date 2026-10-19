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
