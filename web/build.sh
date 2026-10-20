#!/usr/bin/env bash
set -euo pipefail

WEB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_REPO_ROOT="$(cd "$WEB_DIR/.." && pwd)"
LUA_FFI_WASM_ROOT="${LUA_FFI_WASM_ROOT:-$WEB_DIR/vendor/lua-ffi-wasm}"
BGFX_ROOT="${BGFX_ROOT:-$(cd "$WEB_REPO_ROOT/../bgfx" 2>/dev/null && pwd || true)}"
BX_ROOT="${BX_ROOT:-${BGFX_ROOT:+$BGFX_ROOT/../bx}}"
BIMG_ROOT="${BIMG_ROOT:-${BGFX_ROOT:+$BGFX_ROOT/../bimg}}"

if ! command -v emcc >/dev/null 2>&1; then
	EMSDK_ROOT="${EMSDK:-$WEB_REPO_ROOT/../emsdk}"
	if [[ -f "$EMSDK_ROOT/emsdk_env.sh" ]]; then
		# shellcheck disable=SC1091
		source "$EMSDK_ROOT/emsdk_env.sh" >/dev/null 2>&1
	fi
fi

AUTOTOOLS_ROOT="${AUTOTOOLS_ROOT:-$WEB_REPO_ROOT/../autotools-local}"
if [[ -d "$AUTOTOOLS_ROOT/usr/bin" ]]; then
	PATH="$AUTOTOOLS_ROOT/usr/bin:$AUTOTOOLS_ROOT/bin:$PATH"
	export PATH
fi

for tool in git make emcc em++ emconfigure emmake autoreconf libtoolize; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		printf 'Missing required web build tool: %s\n' "$tool" >&2
		exit 1
	fi
done

if [[ -z "$BGFX_ROOT" || ! -f "$BGFX_ROOT/scripts/genie.lua" ]]; then
	cat >&2 <<'EOF'
BGFX source was not found. Set BGFX_ROOT to the BGFX checkout used by the
project, with its sibling bx and bimg checkouts, then rerun make web.
EOF
	exit 1
fi
if [[ ! -d "$BX_ROOT" || ! -d "$BIMG_ROOT" ]]; then
	printf 'BGFX dependencies not found: BX_ROOT=%s BIMG_ROOT=%s\n' "$BX_ROOT" "$BIMG_ROOT" >&2
	exit 1
fi

# BGFX's GENie target uses this variable to select Emscripten's C/C++ tools.
export EMSCRIPTEN="${EMSCRIPTEN:-$(dirname "$(command -v emcc)")}"
BGFX_PROJECT_DIR="$BGFX_ROOT/.build/projects/gmake-wasm"
GENIE="$BX_ROOT/tools/bin/linux/genie"
if [[ ! -f "$BGFX_PROJECT_DIR/bgfx.make" ]]; then
	if [[ ! -x "$GENIE" ]]; then
		printf 'Could not find BGFX GENie executable: %s\n' "$GENIE" >&2
		exit 1
	fi
	(
		cd "$BGFX_ROOT"
		BX_DIR="$BX_ROOT" BIMG_DIR="$BIMG_ROOT" "$GENIE" --gcc=wasm gmake
	)
fi

# Build only the renderer libraries, without BGFX's example applications.
for library in bx bimg bgfx; do
	# The unqualified GENie Release target is wasm32. Release64 emits wasm64
	# objects, which cannot be linked into the browser's standard wasm32 module.
	emmake make -C "$BGFX_PROJECT_DIR" -f "$library.make" config=release -j"${WEB_BGFX_JOBS:-4}"
done

# Shaderc is a host compiler. Compile the ESSL 300 shaders before linking the
# browser runtime, then package the resulting binaries in the Emscripten FS.
HOST_LUAJIT="${WEB_HOST_LUAJIT:-$WEB_REPO_ROOT/bin/linux64/luajit}"
if [[ ! -x "$HOST_LUAJIT" ]]; then
	if command -v luajit >/dev/null 2>&1; then
		HOST_LUAJIT="$(command -v luajit)"
	else
		printf 'Host LuaJIT is required to compile BGFX WebGL shaders: %s\n' "$HOST_LUAJIT" >&2
		exit 1
	fi
fi
mkdir -p "$WEB_REPO_ROOT/bin/web" "$WEB_DIR/shaders"
"$HOST_LUAJIT" "$WEB_DIR/compile_shaders.lua" "$WEB_REPO_ROOT" "$WEB_DIR/shaders"

if [[ ! -d "$LUA_FFI_WASM_ROOT/.git" ]]; then
	mkdir -p "$(dirname "$LUA_FFI_WASM_ROOT")"
	git clone --depth 1 --branch master \
		https://github.com/thenumbernine/lua-ffi-wasm.git "$LUA_FFI_WASM_ROOT"
fi

# Only fetch Lua, luaffifb, and libffi. The upstream checkout also has SDL and
# cimgui submodules; this target has no SDL or cimgui build dependency.
git -C "$LUA_FFI_WASM_ROOT" submodule update --init --depth 1 lua luaffifb libffi

# lua-ffi-wasm's README calls out this include directory for luaffifb builds.
mkdir -p "$LUA_FFI_WASM_ROOT/lua5.4"
cp "$LUA_FFI_WASM_ROOT"/lua/{lauxlib.h,luaconf.h,lua.h,lualib.h} \
	"$LUA_FFI_WASM_ROOT/lua5.4/"

LIBFFI_ROOT="$LUA_FFI_WASM_ROOT/libffi"
LIBFFI_CONFIG_DIR="$LIBFFI_ROOT/src/wasm"

if [[ ! -f "$LIBFFI_CONFIG_DIR/Makefile" ]]; then
	# Recent libtool releases no longer ship LT_SYS_SYMBOL_USCORE from the
	# default libtool macro set, but this libffi checkout still calls it.
	# The compatibility definition pins the WASM answer to "no".
	cp "$WEB_DIR/libffi-wasm-compat.m4" "$LIBFFI_ROOT/m4/"
	(
		cd "$LIBFFI_ROOT"
		emconfigure autoreconf -v -i
	)
	(
		cd "$LIBFFI_CONFIG_DIR"
		emconfigure ../../configure
	)
fi

# lua-ffi-wasm documents these fixes for its WASM libffi headers/configuration.
if [[ ! -f "$LIBFFI_CONFIG_DIR/include/ffitarget.h" ]]; then
	printf 'libffi did not generate %s/include/ffitarget.h\n' "$LIBFFI_CONFIG_DIR" >&2
	exit 1
fi
cp "$LIBFFI_ROOT/src/wasm/ffitarget.h" "$LIBFFI_CONFIG_DIR/include/ffitarget.h"
if ! grep -q '^#define FFI_TARGET_HAS_COMPLEX_TYPE' "$LIBFFI_CONFIG_DIR/include/ffitarget.h"; then
	printf '\n#define FFI_TARGET_HAS_COMPLEX_TYPE\n' >> "$LIBFFI_CONFIG_DIR/include/ffitarget.h"
fi
while IFS= read -r config; do
	sed -i -E 's/^#define FFI_EXEC_STATIC_TRAMP .*/#undef FFI_EXEC_STATIC_TRAMP/' "$config"
done < <(find "$LIBFFI_ROOT/src" -name fficonfig.h -type f -print)

mkdir -p "$WEB_DIR/dist" "$WEB_DIR/build"
BGFX_ROOT="$BGFX_ROOT" emmake make -C "$LUA_FFI_WASM_ROOT" -f "$WEB_DIR/wasm.mk" all

if [[ ! -f "$LUA_FFI_WASM_ROOT/lua-interop/lua-interop.js" ]]; then
	printf 'lua-ffi-wasm checkout is missing lua-interop/lua-interop.js\n' >&2
	exit 1
fi
cp "$LUA_FFI_WASM_ROOT/lua-interop/lua-interop.js" "$WEB_DIR/dist/lua-interop.js"
cp "$WEB_DIR/index.html" "$WEB_DIR/dist/index.html"
cp "$WEB_DIR/host.js" "$WEB_DIR/dist/host.js"
cp "$WEB_DIR/app.lua" "$WEB_DIR/dist/app.lua"
rm -rf "$WEB_DIR/dist/fonts"
cp -a "$WEB_REPO_ROOT/font" "$WEB_DIR/dist/fonts"

printf '\nWeb build written to %s\n' "$WEB_DIR/dist"
