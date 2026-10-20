# Included by GNU Make from the lua-ffi-wasm checkout. The upstream Files.mk
# supplies the Lua 5.4 and luaffifb source lists; this file adds libffi and Clay
# while deliberately leaving SDL/cimgui out of the browser runtime.

WEB_ROOT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
WEB_REPO_ROOT := $(abspath $(WEB_ROOT)/..)
WEB_BUILD := $(WEB_ROOT)/build
WEB_DIST := $(WEB_ROOT)/dist
WEB_OUTPUT := $(WEB_DIST)/lua-5.4.7-with-ffi.js
BGFX_ROOT ?= $(WEB_REPO_ROOT)/../bgfx
BGFX_WASM_LIB_DIR := $(BGFX_ROOT)/.build/wasm/bin
BGFX_WASM_LIBS := $(BGFX_WASM_LIB_DIR)/bgfxRelease.a \
	$(BGFX_WASM_LIB_DIR)/bimgRelease.a \
	$(BGFX_WASM_LIB_DIR)/bxRelease.a

include Files.mk

LIBFFI_SRCS := \
	libffi/src/prep_cif.c \
	libffi/src/types.c \
	libffi/src/raw_api.c \
	libffi/src/java_raw_api.c \
	libffi/src/closures.c \
	libffi/src/tramp.c \
	libffi/src/debug.c \
	libffi/src/wasm/ffi.c

WEB_SRCS := $(LUA_SRCS) $(LUAFFIFB_SRCS) $(LIBFFI_SRCS) \
	$(WEB_REPO_ROOT)/src/clay_lua_bindings/clay_lua_bindings.c \
	$(WEB_REPO_ROOT)/src/stb/stb_image_wrapper.c \
	$(WEB_REPO_ROOT)/src/stb/stb_rect_pack_wrapper.c \
	$(WEB_REPO_ROOT)/src/stb/stb_truetype_wrapper.c \
	$(WEB_ROOT)/clay_module.c \
	$(WEB_ROOT)/bgfx_ffi.c \
	$(WEB_ROOT)/canvas2d_ffi.c

WEB_LUA_ASSETS := $(wildcard $(WEB_REPO_ROOT)/ffi/*.lua) \
	$(wildcard $(WEB_REPO_ROOT)/component/*.lua) \
	$(wildcard $(WEB_REPO_ROOT)/demo/*.lua) \
	$(wildcard $(WEB_REPO_ROOT)/font/*) \
	$(WEB_REPO_ROOT)/theme.lua \
	$(WEB_REPO_ROOT)/clay_retained.lua \
	$(WEB_REPO_ROOT)/font_manager.lua \
	$(WEB_REPO_ROOT)/shader_manager.lua \
	$(WEB_ROOT)/app.lua \
	$(WEB_ROOT)/window.lua \
	$(WEB_ROOT)/canvas2d.lua \
	$(WEB_ROOT)/bit.lua

WEB_INCLUDE_FLAGS := \
	-I$(CURDIR) \
	-I$(BGFX_ROOT)/include \
	-I$(BGFX_ROOT)/../bx/include \
	-I$(CURDIR)/lua \
	-I$(CURDIR)/luaffifb \
	-I$(CURDIR)/libffi/src/wasm/include \
	-I$(CURDIR)/libffi/src/wasm \
	-I$(CURDIR)/libffi/include

WEB_CFLAGS := -O3 -g2 -fPIC -Wall -Wextra -DLUA_COMPAT_5_3 -D__WASM__ \
	-DCALL_WITH_LIBFFI $(WEB_INCLUDE_FLAGS)

WEB_LDFLAGS := -O3 -g2 --no-entry -sWASM=1 -sMAIN_MODULE=1 \
	-sMODULARIZE=1 -sEXPORT_ES6=1 -sALLOW_TABLE_GROWTH=1 \
	-sALLOW_MEMORY_GROWTH=1 -sMAXIMUM_MEMORY=2GB -sFILESYSTEM=1 \
	-sMAX_WEBGL_VERSION=2 -sGL_ENABLE_GET_PROC_ADDRESS=1 \
	-sEXPORT_ALL=1 -sENVIRONMENT=web \
	--preload-file $(WEB_REPO_ROOT)/font@/font \
	--preload-file $(WEB_REPO_ROOT)/ffi@/ffi \
	--preload-file $(WEB_REPO_ROOT)/component@/component \
	--preload-file $(WEB_REPO_ROOT)/demo@/demo \
	--preload-file $(WEB_REPO_ROOT)/theme.lua@/theme.lua \
	--preload-file $(WEB_REPO_ROOT)/clay_retained.lua@/clay_retained.lua \
	--preload-file $(WEB_ROOT)/window.lua@/web/window.lua \
	--preload-file $(WEB_ROOT)/canvas2d.lua@/web/canvas2d.lua \
	--preload-file $(WEB_ROOT)/bit.lua@/web/bit.lua \
	--preload-file $(WEB_REPO_ROOT)/font_manager.lua@/font_manager.lua \
	--preload-file $(WEB_REPO_ROOT)/shader_manager.lua@/shader_manager.lua \
	--preload-file $(WEB_ROOT)/shaders@/shaders \
	-sEXPORTED_RUNTIME_METHODS='["FS","stringToNewUTF8","addFunction"]' \
	-sEXPORTED_FUNCTIONS='["_malloc","_free","_clay_lua_register","_bgfx_get_interface",\
		"_clay_bgfx_ffi_copy",\
		"_clay_canvas2d_ffi_begin_frame","_clay_canvas2d_ffi_fill_rect",\
		"_clay_canvas2d_ffi_stroke_rect","_clay_canvas2d_ffi_push_clip",\
		"_clay_canvas2d_ffi_pop_clip","_clay_canvas2d_ffi_measure_text",\
		"_clay_canvas2d_ffi_draw_text","_clay_canvas2d_ffi_draw_grid",\
		"_clay_canvas2d_ffi_draw_bezier","_clay_canvas2d_ffi_color_picker",\
		"_clay_bgfx_ffi_create_texture_2d","_clay_bgfx_ffi_create_texture_3d",\
		"_clay_bgfx_ffi_create_texture_cube","_clay_bgfx_ffi_create_uniform",\
		"_clay_bgfx_ffi_create_shader","_clay_bgfx_ffi_create_program",\
		"_clay_bgfx_ffi_create_vertex_layout","_clay_bgfx_ffi_create_vertex_buffer",\
		"_clay_bgfx_ffi_create_index_buffer","_clay_bgfx_ffi_destroy_texture",\
		"_clay_bgfx_ffi_update_texture_2d","_clay_bgfx_ffi_destroy_uniform",\
		"_clay_bgfx_ffi_set_uniform","_clay_bgfx_ffi_set_texture",\
		"_clay_bgfx_ffi_set_debug","_clay_bgfx_ffi_set_state",\
		"_clay_bgfx_ffi_set_index_buffer",\
		"_clay_bgfx_ffi_set_vertex_buffer","_clay_bgfx_ffi_set_transient_buffers",\
		"_clay_bgfx_ffi_submit",\
		"_clay_bgfx_ffi_destroy_program","_clay_bgfx_ffi_destroy_vertex_buffer",\
		"_clay_bgfx_ffi_destroy_index_buffer","_clay_bgfx_ffi_destroy_vertex_layout"]'

.PHONY: all
all: $(WEB_OUTPUT)

$(WEB_OUTPUT): $(WEB_SRCS) $(WEB_REPO_ROOT)/src/clay/clay.h $(BGFX_WASM_LIBS) \
	$(WEB_LUA_ASSETS) \
	$(WEB_ROOT)/shaders/clay.vs.bin $(WEB_ROOT)/shaders/clay.fs.bin | $(WEB_DIST)
	rm -rf "$(WEB_BUILD)/wasm-objects"
	mkdir -p "$(WEB_BUILD)/wasm-objects"
	set -e; index=0; for source in $(WEB_SRCS); do \
		emcc $(WEB_CFLAGS) -c "$$source" -o "$(WEB_BUILD)/wasm-objects/$$index.o"; \
		index=$$((index + 1)); \
	done
	em++ "$(WEB_BUILD)"/wasm-objects/*.o $(BGFX_WASM_LIBS) -o "$@" $(WEB_LDFLAGS)

$(WEB_DIST):
	mkdir -p "$@"
