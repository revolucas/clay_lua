# Building clay_lua

## Linux quick start

Clone the project with its bindings submodule, then install LuaJIT and the
native build tools:

```bash
git clone --recurse-submodules https://github.com/revolucas/clay_lua.git
cd clay_lua
sudo apt-get update
sudo apt-get install --yes build-essential pkg-config luajit \
  libluajit-5.1-dev libx11-dev libxrandr-dev libxcursor-dev \
  libxi-dev libxinerama-dev libxext-dev
make linux
make test
```

`make linux` builds the Clay Lua binding, RGFW adapter, and stb modules into
`bin/linux64/`. `make test` builds the binding and runs the native floating
clip regression and the Lua retained UI regression. The test target needs only
LuaJIT and a C compiler; it does not build or launch BGFX.

The full native demo also needs BGFX and Shaderc shared libraries built from
the API revision expected by this checkout. Stage them with:

```bash
make bgfx-runtime-linux BGFX_RUNTIME_ROOT=/path/to/bgfx-bin
```

`BGFX_RUNTIME_ROOT` must contain the matching Linux BGFX and Shaderc shared
libraries under `linux64/`. To stage both Linux and Windows runtime files, use
`make bgfx-runtime BGFX_RUNTIME_ROOT=/path/to/bgfx-bin`; Windows files must be
under `x64/`. These runtime binaries are not committed to the repository.

## Configuration

Linux LuaJIT is found with `pkg-config luajit`. For a custom LuaJIT build,
override `LUAJIT_ROOT`, `LJ_INC`, and/or `LJ_LIB`:

```bash
make linux LUAJIT_ROOT=/path/to/luajit
```

Windows cross-compilation is optional and needs MinGW-w64 plus a Windows
LuaJIT import library/runtime. Point `LUAJIT_ROOT` at its source/build tree, or
point `TECHNETIUM_MINGW_STAGE` at a compatible staged LuaJIT package, then run:

```bash
make win64 CC_WIN64=x86_64-w64-mingw32-gcc \
  TECHNETIUM_MINGW_STAGE=/path/to/win64-mingw-stage
```

`BGFX_RUNTIME_ROOT` must also be supplied to `make bgfx-runtime-win64` when
staging the matching Windows BGFX and Shaderc DLLs. Linux builds use the RGFW X11
backend and need X11, XRandR, XCursor, Xi, Xinerama, and Xext development
headers. Windows builds place the RGFW adapter at `bin/x64/librgfw.dll`.

Shader source is in `shader/src/`, with shared includes in `shader/include/`.
Builds put generated libraries and runtime files in `bin/`; binary outputs are
ignored by Git.

## Release packages

The release script builds and tests the Linux libraries, cross-builds the
Windows libraries, stages the matching BGFX and Shaderc runtimes, and writes
Linux `.tar.gz`, Windows `.zip`, and checksum files under `release-artifacts/`.
It requires the BGFX, bx, and bimg source checkouts for their upstream license
files and a MinGW LuaJIT stage for Windows:

```bash
BGFX_ROOT=/path/to/bgfx \
BX_ROOT=/path/to/bx \
BIMG_ROOT=/path/to/bimg \
BGFX_RUNTIME_ROOT=/path/to/bgfx-bin \
TECHNETIUM_MINGW_STAGE=/path/to/win64-mingw-stage \
./tools/package-release.sh v0.1.0
```

The Linux archive bundles LuaJIT, BGFX, Shaderc, the app libraries, and fonts.
It needs X11 runtime libraries, `libstdc++6`, and a working Vulkan or OpenGL
driver. The Windows archive bundles LuaJIT and the runtime DLLs. Launch either
package with `run.sh` or `run.bat` from its extracted directory. License files
for packaged runtimes are included in each archive.

## Browser build (Lua 5.4 + FFI-Wasm)

The browser build uses a pinned Lua 5.4.7 + luaffifb/libffi runtime and builds
the Clay app into Wasm. Canvas2D is the default; choose BGFX WebGL2 from the
renderer menu or open `http://localhost:8000/?renderer=bgfx`. Canvas2D draws
the demo's shapes, text, clipping, node graph, and color picker. BGFX texture
handles are backend-specific and are not drawn by Canvas2D. Frame CPU time and
requestAnimationFrame FPS appear at the bottom right.

Canvas2D is the recommended browser renderer at this stage. BGFX WebGL2 runs,
but some text in controls and retained pages can still render as blocky glyphs;
that backend remains experimental for the full demo.

Requirements: Emscripten (`emcc`, `em++`, `emconfigure`, `emmake`), GNU Make,
Autoconf, Libtool, BGFX, bx, and bimg source checkouts. Set `BGFX_ROOT`,
`BX_ROOT`, and `BIMG_ROOT` if those sources are not in sibling directories.
The first build fetches the pinned `lua-ffi-wasm` revision and its Lua,
luaffifb, and libffi submodules into ignored `web/vendor/`. To intentionally
upgrade that runtime, set `LUA_FFI_WASM_REF` to a commit hash. To reuse an
existing checkout, set `LUA_FFI_WASM_ROOT`.

```bash
make web
make web-serve
```

The server listens on `http://localhost:8000/` by default; set `PORT` to use a
different port. Build artifacts go to `web/dist/` and `web/build/`.
