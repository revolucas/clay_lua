#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-}"
if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$ ]]; then
	echo "Usage: $0 vMAJOR.MINOR.PATCH[-PRERELEASE]" >&2
	exit 2
fi

if [[ -n "$(git -C "$ROOT" status --porcelain)" ]]; then
	echo "Release packages must be built from a clean, committed tree" >&2
	exit 1
fi

BGFX_ROOT="${BGFX_ROOT:-$ROOT/../bgfx}"
BX_ROOT="${BX_ROOT:-$ROOT/../bx}"
BIMG_ROOT="${BIMG_ROOT:-$ROOT/../bimg}"
BGFX_RUNTIME_ROOT="${BGFX_RUNTIME_ROOT:-}"
TECHNETIUM_MINGW_STAGE="${TECHNETIUM_MINGW_STAGE:-}"
LUAJIT="${LUAJIT:-luajit}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT/release-artifacts}"

for path in "$BGFX_ROOT" "$BX_ROOT" "$BIMG_ROOT"; do
	if [[ ! -d "$path" ]]; then
		echo "Required source directory not found: $path" >&2
		exit 1
	fi
done
if [[ -z "$BGFX_RUNTIME_ROOT" || ! -d "$BGFX_RUNTIME_ROOT" ]]; then
	echo "Set BGFX_RUNTIME_ROOT to the bin directory containing matching BGFX and Shaderc runtimes" >&2
	exit 1
fi
if [[ -z "$TECHNETIUM_MINGW_STAGE" || ! -d "$TECHNETIUM_MINGW_STAGE" ]]; then
	echo "Set TECHNETIUM_MINGW_STAGE to a Windows LuaJIT MinGW stage" >&2
	exit 1
fi
if ! command -v "$LUAJIT" >/dev/null 2>&1; then
	echo "LuaJIT executable not found: $LUAJIT" >&2
	exit 1
fi

LUAJIT_BIN="$(command -v "$LUAJIT")"
LUAJIT_LIB_DIR="${LJ_LIB:-}"
if [[ -z "$LUAJIT_LIB_DIR" ]]; then
	if [[ -n "${LUAJIT_ROOT:-}" && -d "$LUAJIT_ROOT/src" ]]; then
		LUAJIT_LIB_DIR="$LUAJIT_ROOT/src"
	else
		LUAJIT_LIB_DIR="$(pkg-config --variable=libdir luajit 2>/dev/null || true)"
	fi
fi
LUAJIT_SHARED=""
if [[ -n "$LUAJIT_LIB_DIR" ]]; then
	for candidate in "$LUAJIT_LIB_DIR"/libluajit-5.1.so.*; do
		if [[ -f "$candidate" ]]; then LUAJIT_SHARED="$candidate"; fi
	done
fi
if [[ -z "$LUAJIT_SHARED" ]]; then
	echo "Could not find libluajit-5.1.so in $LUAJIT_LIB_DIR" >&2
	exit 1
fi

MAKE_ARGS=("LUAJIT=$LUAJIT" "BGFX_RUNTIME_ROOT=$BGFX_RUNTIME_ROOT")
[[ -n "${LUAJIT_ROOT:-}" ]] && MAKE_ARGS+=("LUAJIT_ROOT=$LUAJIT_ROOT")
[[ -n "${LJ_INC:-}" ]] && MAKE_ARGS+=("LJ_INC=$LJ_INC")
[[ -n "${LJ_LIB:-}" ]] && MAKE_ARGS+=("LJ_LIB=$LJ_LIB")
[[ -n "${CC_WIN64:-}" ]] && MAKE_ARGS+=("CC_WIN64=$CC_WIN64")

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
COMMIT="$(git -C "$ROOT" rev-parse HEAD)"
LINUX_NAME="clay_lua-${VERSION}-linux-x86_64"
WINDOWS_NAME="clay_lua-${VERSION}-windows-x86_64"
LINUX_PACKAGE="$WORK/$LINUX_NAME"
WINDOWS_PACKAGE="$WORK/$WINDOWS_NAME"
OUT_DIR="$OUTPUT_ROOT/$VERSION"

make -C "$ROOT" -B linux "${MAKE_ARGS[@]}"
make -C "$ROOT" -B test "${MAKE_ARGS[@]}"
make -C "$ROOT" bgfx-runtime-linux "BGFX_RUNTIME_ROOT=$BGFX_RUNTIME_ROOT"
make -C "$ROOT" -B win64 "${MAKE_ARGS[@]}" "TECHNETIUM_MINGW_STAGE=$TECHNETIUM_MINGW_STAGE"
make -C "$ROOT" bgfx-runtime-win64 "BGFX_RUNTIME_ROOT=$BGFX_RUNTIME_ROOT"

prepare_package() {
	local destination="$1"
	mkdir -p "$destination"
	git -C "$ROOT" archive --format=tar HEAD | tar -xf - -C "$destination"
	mkdir -p "$destination/src/clay_lua_bindings" "$destination/licenses/upstream"
	cp "$ROOT/src/clay_lua_bindings/LICENSE" "$destination/src/clay_lua_bindings/LICENSE"
	copy_upstream_licenses bgfx "$BGFX_ROOT" "$destination/licenses/upstream/bgfx"
	copy_upstream_licenses bx "$BX_ROOT" "$destination/licenses/upstream/bx"
	copy_upstream_licenses bimg "$BIMG_ROOT" "$destination/licenses/upstream/bimg"
	cat > "$destination/RELEASE-INFO.txt" <<EOF
Clay Lua $VERSION
Source commit: $COMMIT

Extract the package and launch the demo with ./run.sh on Linux or run.bat on
Windows. The package includes the matching BGFX and Shaderc runtime libraries.
See README.md and THIRD_PARTY_NOTICES.md for setup and licensing details.
EOF
}

copy_upstream_licenses() {
	local name="$1"
	local source="$2"
	local destination="$3"
	local file relative
	mkdir -p "$destination"
	while IFS= read -r -d '' file; do
		relative="${file#"$source"/}"
		mkdir -p "$destination/$(dirname "$relative")"
		cp -p "$file" "$destination/$relative"
	done < <(find "$source" -type d \( -name .git -o -name .build \) -prune -o -type f \( \
		-iname LICENSE -o -iname 'LICENSE.*' -o -iname COPYING -o \
		-iname 'COPYING.*' -o -iname COPYRIGHT \) -print0)
	if [[ ! -s "$destination/LICENSE" ]]; then
		echo "Could not collect $name license from $source" >&2
		exit 1
	fi
}

copy_required() {
	local source="$1"
	local destination="$2"
	if [[ ! -f "$source" ]]; then
		echo "Required release file missing: $source" >&2
		exit 1
	fi
	cp -p "$source" "$destination/"
}

prepare_package "$LINUX_PACKAGE"
LINUX_BIN="$LINUX_PACKAGE/bin/linux64"
mkdir -p "$LINUX_BIN" "$LINUX_PACKAGE/licenses"
cp -a "$ROOT/third_party_licenses/." "$LINUX_PACKAGE/licenses/"
for file in clay.so librgfw.so libstb_image.so libstb_rect_pack.so \
	libstb_truetype.so bgfx-shared-libRelease.so \
	libbgfx-shared-libRelease.so shaderc_sharedRelease.so; do
	copy_required "$ROOT/bin/linux64/$file" "$LINUX_BIN"
done
for file in "$ROOT"/bin/linux64/clay.*.bin "$ROOT"/bin/linux64/clay.*.key; do
	[[ -f "$file" ]] && cp -p "$file" "$LINUX_BIN/"
done
cp -p "$LUAJIT_BIN" "$LINUX_BIN/luajit"
cp -L "$LUAJIT_SHARED" "$LINUX_BIN/libluajit.so"
ln -sfn libluajit.so "$LINUX_BIN/libluajit-5.1.so.2"

prepare_package "$WINDOWS_PACKAGE"
WINDOWS_BIN="$WINDOWS_PACKAGE/bin/x64"
mkdir -p "$WINDOWS_BIN" "$WINDOWS_PACKAGE/licenses"
cp -a "$ROOT/third_party_licenses/." "$WINDOWS_PACKAGE/licenses/"
for file in clay.dll librgfw.dll libstb_image.dll libstb_rect_pack.dll \
	libstb_truetype.dll bgfx-shared-libRelease.dll shaderc_sharedRelease.dll \
	D3DCompiler_47.dll lua51.dll luajit.exe libgcc_s_seh-1.dll; do
	copy_required "$ROOT/bin/x64/$file" "$WINDOWS_BIN"
done

(
	cd "$LINUX_PACKAGE"
	export LD_LIBRARY_PATH="$LINUX_BIN${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
	./bin/linux64/luajit -e 'package.cpath="bin/linux64/?.so;"..package.cpath; require("clay"); require("ffi.ffi_bgfx"); require("ffi.ffi_shaderc"); require("ffi.ffi_rgfw"); require("ffi.ffi_stb_image"); require("ffi.ffi_stb_rect_pack"); require("ffi.ffi_stb_truetype")'
)

mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR/$LINUX_NAME.tar.gz" "$OUT_DIR/$WINDOWS_NAME.zip" "$OUT_DIR/SHA256SUMS.txt"
SOURCE_DATE_EPOCH="$(git -C "$ROOT" show -s --format=%ct HEAD)"
tar --sort=name --mtime="@$SOURCE_DATE_EPOCH" --owner=0 --group=0 \
	--numeric-owner -cf - -C "$WORK" "$LINUX_NAME" | gzip -n > "$OUT_DIR/$LINUX_NAME.tar.gz"
(
	cd "$WORK"
	zip -X -q -r "$OUT_DIR/$WINDOWS_NAME.zip" "$WINDOWS_NAME"
)
(
	cd "$OUT_DIR"
	sha256sum "$LINUX_NAME.tar.gz" "$WINDOWS_NAME.zip" > SHA256SUMS.txt
)

echo "Created release archives in $OUT_DIR:"
ls -lh "$OUT_DIR/$LINUX_NAME.tar.gz" "$OUT_DIR/$WINDOWS_NAME.zip" "$OUT_DIR/SHA256SUMS.txt"
