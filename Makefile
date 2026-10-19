# --- config: where LuaJIT lives (sibling repo) ---
LUAJIT_ROOT ?= ../luajit
LJ_INC      := $(LUAJIT_ROOT)/src
LJ_LIB      := $(LUAJIT_ROOT)/src

MODULE      ?= clay
SRC_DIR     := src
STB_DIR     := $(SRC_DIR)/stb
RGFW_DIR    := $(SRC_DIR)/rgfw
BIN_DIR     := bin
RUNTIME_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
MINGW_PREFIX ?= x86_64-w64-mingw32
CC_WIN64 ?= $(MINGW_PREFIX)-gcc
BGFX_RUNTIME_ROOT ?= ../../Projects/Game Engines/Technetium/bin
TECHNETIUM_MINGW_STAGE ?= ../../Projects/Game Engines/Technetium/build/linux-mingw/stage/win64-mingw

empty :=
space := $(empty) $(empty)
escape_spaces = $(subst $(space),\$(space),$(1))
TECHNETIUM_MINGW_STAGE_ESCAPED := $(call escape_spaces,$(TECHNETIUM_MINGW_STAGE))

# -------- Sources --------
SRCS_CLAY := \
  $(SRC_DIR)/clay_lua_bindings/clay_lua_bindings.c
CLAY_HEADERS := $(SRC_DIR)/clay/clay.h
SRCS_RGFW := $(RGFW_DIR)/rgfw_wrapper.c
RGFW_LINUX_LIBS ?= -lX11 -lXrandr -lXcursor -lXi -lXinerama -lXext -ldl -pthread -lm

# map stb logical names -> sources
STB_NAMES := stb_image stb_rect_pack stb_truetype
stb_image_src      := $(STB_DIR)/stb_image_wrapper.c
stb_rect_pack_src  := $(STB_DIR)/stb_rect_pack_wrapper.c
stb_truetype_src   := $(STB_DIR)/stb_truetype_wrapper.c

CFLAGS_COMMON := -O2 -fPIC -Isrc -I$(LJ_INC)
LDFLAGS_COMMON := -L$(LJ_LIB)
UNAME_S := $(shell uname -s)

# -------- Directories --------
LIN_SUBDIR := $(BIN_DIR)/linux64
WIN_SUBDIR := $(BIN_DIR)/x64

# Linux is the default; Windows binaries use the explicit win64 target.
.PHONY: all
all: linux

# -------- Linux (default) --------
ifeq ($(UNAME_S),Linux)
    SOEXT := so
    SHARED := -shared
    CC ?= gcc

    CFLAGS  := $(CFLAGS_COMMON)
    # rpath points from bin/linux64/ up two levels to repo root where libluajit*.so sits
    LDFLAGS := $(LDFLAGS_COMMON) -lluajit-5.1 -ldl -lm -pthread -Wl,-rpath,'$$ORIGIN/../../'

    CLAY_SO := $(LIN_SUBDIR)/$(MODULE).$(SOEXT)
    RGFW_SO := $(LIN_SUBDIR)/librgfw.$(SOEXT)
    STB_SOLIBS := $(addprefix $(LIN_SUBDIR)/lib,$(addsuffix .$(SOEXT),$(STB_NAMES)))

    .PHONY: linux
    linux: $(CLAY_SO) $(STB_SOLIBS) $(RGFW_SO)

    # clay module (without stb sources)
    $(CLAY_SO): $(SRCS_CLAY) $(CLAY_HEADERS) | $(LIN_SUBDIR)
	$(CC) $(CFLAGS) $(SHARED) -o $@ $(SRCS_CLAY) $(LDFLAGS)
	@[ -f $(LJ_LIB)/libluajit.so ] && cp -n $(LJ_LIB)/libluajit.so* $(LIN_SUBDIR)/ 2>/dev/null || true
	@find "$(LJ_LIB)" -maxdepth 1 -type f -name 'luajit*' -perm -111 -exec cp -n '{}' "$(LIN_SUBDIR)/" \; 2>/dev/null || true

    # pattern rule to build each stb .so
    # $* is the base name: stb_image / stb_rect_pack / stb_truetype
    $(LIN_SUBDIR)/lib%.$(SOEXT): $($*_src) | $(LIN_SUBDIR)
	$(CC) $(CFLAGS) $(SHARED) -o $@ $($*_src) $(LDFLAGS)

    $(RGFW_SO): $(SRCS_RGFW) $(RGFW_DIR)/RGFW.h | $(LIN_SUBDIR)
	$(CC) -O2 -fPIC -I$(RGFW_DIR) -shared -o $@ $(SRCS_RGFW) $(RGFW_LINUX_LIBS)

endif

# Prefer the LuaJIT import library in the usual source tree. Technetium's
# MinGW target builds and stages the same LuaJIT fork when that file is absent.
LUAJIT_IMPLIB_LOCAL := $(firstword \
  $(wildcard $(LJ_LIB)/libluajit-5.1.dll.a) \
  $(wildcard $(LJ_LIB)/liblua51.dll.a) \
  $(wildcard $(LJ_LIB)/lua51.lib))

TECHNETIUM_LUAJIT_IMPLIB := $(wildcard $(TECHNETIUM_MINGW_STAGE_ESCAPED)/lib/libluajit-5.1.dll.a)
ifeq ($(strip $(LUAJIT_IMPLIB_LOCAL)),)
  LUAJIT_IMPLIB := $(call escape_spaces,$(TECHNETIUM_LUAJIT_IMPLIB))
else
  LUAJIT_IMPLIB := $(LUAJIT_IMPLIB_LOCAL)
endif

ifeq ($(strip $(LUAJIT_IMPLIB_LOCAL)),)
  LUAJIT_RUNTIME_DIR := $(TECHNETIUM_MINGW_STAGE_ESCAPED)/bin
else
  LUAJIT_RUNTIME_DIR := $(LJ_LIB)
endif
LUAJIT_RUNTIME_DLL := $(LUAJIT_RUNTIME_DIR)/lua51.dll
LUAJIT_RUNTIME_EXE := $(LUAJIT_RUNTIME_DIR)/luajit.exe

ifneq ($(filter win64,$(MAKECMDGOALS)),)
ifeq ($(strip $(LUAJIT_IMPLIB)),)
$(error No LuaJIT Windows import library found. Build it with Technetium: cmake --preset linux-mingw && cmake --build build/linux-mingw --target technetium-luajit)
endif
endif

WIN_DLL_CLAY := $(WIN_SUBDIR)/$(MODULE).dll
WIN_DLL_RGFW := $(WIN_SUBDIR)/librgfw.dll
WIN_DLL_STBS := $(addprefix $(WIN_SUBDIR)/lib,$(addsuffix .dll,$(STB_NAMES)))

.PHONY: win64
win64: $(WIN_DLL_CLAY) $(WIN_DLL_STBS) $(WIN_DLL_RGFW)

# Stage the bgfx and Shaderc pair built from the same API revision.
.PHONY: bgfx-runtime
bgfx-runtime: | $(LIN_SUBDIR) $(WIN_SUBDIR)
	test -f "$(BGFX_RUNTIME_ROOT)/linux64/bgfx-shared-libRelease.so"
	test -f "$(BGFX_RUNTIME_ROOT)/linux64/shaderc_sharedRelease.so"
	test -f "$(BGFX_RUNTIME_ROOT)/x64/bgfx-shared-libRelease.dll"
	test -f "$(BGFX_RUNTIME_ROOT)/x64/shaderc_sharedRelease.dll"
	test -f "$(BGFX_RUNTIME_ROOT)/x64/D3DCompiler_47.dll"
	cp -f "$(BGFX_RUNTIME_ROOT)/linux64/bgfx-shared-libRelease.so" "$(LIN_SUBDIR)/"
	cp -f "$(BGFX_RUNTIME_ROOT)/linux64/bgfx-shared-libRelease.so" "$(LIN_SUBDIR)/libbgfx-shared-libRelease.so"
	cp -f "$(BGFX_RUNTIME_ROOT)/linux64/shaderc_sharedRelease.so" "$(LIN_SUBDIR)/"
	cp -f "$(BGFX_RUNTIME_ROOT)/x64/bgfx-shared-libRelease.dll" "$(WIN_SUBDIR)/"
	cp -f "$(BGFX_RUNTIME_ROOT)/x64/shaderc_sharedRelease.dll" "$(WIN_SUBDIR)/"
	cp -f "$(BGFX_RUNTIME_ROOT)/x64/D3DCompiler_47.dll" "$(WIN_SUBDIR)/"

$(WIN_SUBDIR)/%.dll: CC := $(CC_WIN64)
$(WIN_SUBDIR)/%.dll: CFLAGS := -O2 -Isrc -I$(LJ_INC) -DWIN32
$(WIN_SUBDIR)/%.dll: LDFLAGS := $(LUAJIT_IMPLIB) -Wl,--enable-auto-import -static-libgcc

$(WIN_DLL_RGFW): $(SRCS_RGFW) $(RGFW_DIR)/RGFW.h | $(WIN_SUBDIR)
	$(CC_WIN64) -O2 -I$(RGFW_DIR) -shared -o $@ $(SRCS_RGFW) -lgdi32 -luser32 -lshell32 -lwinmm -static-libgcc

# clay dll (fail early if no import lib is present)
$(WIN_DLL_CLAY): $(SRCS_CLAY) $(CLAY_HEADERS) $(LUAJIT_IMPLIB) | $(WIN_SUBDIR)
	$(CC) $(CFLAGS) -shared -o $@ $(SRCS_CLAY) $(LDFLAGS)
	@cp -f $(LUAJIT_RUNTIME_DLL) $(WIN_SUBDIR)/ 2>/dev/null || true
	@cp -f $(LUAJIT_RUNTIME_EXE) $(WIN_SUBDIR)/ 2>/dev/null || true

# stb dlls (one per source)
$(WIN_SUBDIR)/libstb_image.dll:      $(stb_image_src)     | $(WIN_SUBDIR)
	$(CC) $(CFLAGS) -shared -o $@ $(stb_image_src) $(LDFLAGS)

$(WIN_SUBDIR)/libstb_rect_pack.dll:  $(stb_rect_pack_src) | $(WIN_SUBDIR)
	$(CC) $(CFLAGS) -shared -o $@ $(stb_rect_pack_src) $(LDFLAGS)

$(WIN_SUBDIR)/libstb_truetype.dll:   $(stb_truetype_src)  | $(WIN_SUBDIR)
	$(CC) $(CFLAGS) -shared -o $@ $(stb_truetype_src) $(LDFLAGS)

# -------- Dirs --------
$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(LIN_SUBDIR): | $(BIN_DIR)
	mkdir -p $(LIN_SUBDIR)

$(WIN_SUBDIR): | $(BIN_DIR)
	mkdir -p $(WIN_SUBDIR)

# -------- Cleaning --------
.PHONY: clean veryclean
clean:
	$(RM) -f $(LIN_SUBDIR)/$(MODULE).so $(WIN_SUBDIR)/$(MODULE).dll
	$(RM) -f $(LIN_SUBDIR)/librgfw.so $(WIN_SUBDIR)/librgfw.dll
	$(RM) -f $(LIN_SUBDIR)/libstb_image.so $(LIN_SUBDIR)/libstb_rect_pack.so $(LIN_SUBDIR)/libstb_truetype.so
	$(RM) -f $(WIN_SUBDIR)/libstb_image.dll $(WIN_SUBDIR)/libstb_rect_pack.dll $(WIN_SUBDIR)/libstb_truetype.dll
	$(RM) -f $(BIN_DIR)/*/*.o 2>/dev/null || true
	$(RM) -f $(RUNTIME_DIR)/libluajit.so $(RUNTIME_DIR)/libluajit.so.* 2>/dev/null || true
	$(RM) -f $(RUNTIME_DIR)/libluajit*.dylib 2>/dev/null || true
	$(RM) -f $(RUNTIME_DIR)/lua51.dll 2>/dev/null || true
	@find "$(RUNTIME_DIR)" -maxdepth 1 -type f -name 'luajit*' -perm -111 -exec rm -f '{}' \; 2>/dev/null || true

veryclean: clean
	@true
