# --- config: where LuaJIT lives (sibling repo) ---
LUAJIT_ROOT ?= ../luajit
LJ_INC      := $(LUAJIT_ROOT)/src
LJ_LIB      := $(LUAJIT_ROOT)/src

MODULE      ?= clay
SRC_DIR     := src
STB_DIR     := $(SRC_DIR)/stb
BIN_DIR     := bin
RUNTIME_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
MINGW_PREFIX ?= x86_64-w64-mingw32
CC_WIN64 ?= $(MINGW_PREFIX)-gcc

# -------- Sources --------
SRCS_CLAY := \
  $(SRC_DIR)/clay_lua_bindings/clay_lua_bindings.c

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

# Default target builds both OS-specific things if on Linux
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
    STB_SOLIBS := $(addprefix $(LIN_SUBDIR)/lib,$(addsuffix .$(SOEXT),$(STB_NAMES)))

    .PHONY: linux
    linux: $(CLAY_SO) $(STB_SOLIBS)

    # clay module (without stb sources)
    $(CLAY_SO): $(SRCS_CLAY) | $(LIN_SUBDIR)
	$(CC) $(CFLAGS) $(SHARED) -o $@ $(SRCS_CLAY) $(LDFLAGS)
	@[ -f $(LJ_LIB)/libluajit.so ] && cp -n $(LJ_LIB)/libluajit.so* $(LIN_SUBDIR)/ 2>/dev/null || true
	@find "$(LJ_LIB)" -maxdepth 1 -type f -name 'luajit*' -perm -111 -exec cp -n '{}' "$(LIN_SUBDIR)/" \; 2>/dev/null || true

    # pattern rule to build each stb .so
    # $* is the base name: stb_image / stb_rect_pack / stb_truetype
    $(LIN_SUBDIR)/lib%.$(SOEXT): $($*_src) | $(LIN_SUBDIR)
	$(CC) $(CFLAGS) $(SHARED) -o $@ $($*_src) $(LDFLAGS)

endif

# Detect a usable import lib and matching -l flag
LUAJIT_IMPLIB := $(firstword \
  $(wildcard $(LJ_LIB)/libluajit-5.1.dll.a) \
  $(wildcard $(LJ_LIB)/liblua51.dll.a) \
  $(wildcard $(LJ_LIB)/lua51.lib))

# choose the correct -l name for the found import lib
ifeq ($(findstring libluajit-5.1.dll.a,$(notdir $(LUAJIT_IMPLIB))),libluajit-5.1.dll.a)
  LUAJIT_LFLAG := -lluajit-5.1
else
  LUAJIT_LFLAG := -llua51
endif

WIN_DLL_CLAY := $(WIN_SUBDIR)/$(MODULE).dll
WIN_DLL_STBS := $(addprefix $(WIN_SUBDIR)/lib,$(addsuffix .dll,$(STB_NAMES)))

.PHONY: win64
win64: $(WIN_DLL_CLAY) $(WIN_DLL_STBS)

$(WIN_SUBDIR)/%.dll: CC := $(CC_WIN64)
$(WIN_SUBDIR)/%.dll: CFLAGS := -O2 -Isrc -I$(LJ_INC) -DWIN32
$(WIN_SUBDIR)/%.dll: LDFLAGS := -L$(LJ_LIB) $(LUAJIT_LFLAG) -Wl,--enable-auto-import -static-libgcc

# clay dll (fail early if no import lib is present)
$(WIN_DLL_CLAY): $(SRCS_CLAY) $(LUAJIT_IMPLIB) | $(WIN_SUBDIR)
	$(CC) $(CFLAGS) -shared -o $@ $(SRCS_CLAY) $(LDFLAGS)
	@cp -n $(LJ_LIB)/lua51.dll $(WIN_SUBDIR)/ 2>/dev/null || true
	@cp -n $(LJ_LIB)/luajit.exe $(WIN_SUBDIR)/ 2>/dev/null || true

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
	$(RM) -f $(LIN_SUBDIR)/libstb_image.so $(LIN_SUBDIR)/libstb_rect_pack.so $(LIN_SUBDIR)/libstb_truetype.so
	$(RM) -f $(WIN_SUBDIR)/libstb_image.dll $(WIN_SUBDIR)/libstb_rect_pack.dll $(WIN_SUBDIR)/libstb_truetype.dll
	$(RM) -f $(BIN_DIR)/*/*.o 2>/dev/null || true
	$(RM) -f $(RUNTIME_DIR)/libluajit.so $(RUNTIME_DIR)/libluajit.so.* 2>/dev/null || true
	$(RM) -f $(RUNTIME_DIR)/libluajit*.dylib 2>/dev/null || true
	$(RM) -f $(RUNTIME_DIR)/lua51.dll 2>/dev/null || true
	@find "$(RUNTIME_DIR)" -maxdepth 1 -type f -name 'luajit*' -perm -111 -exec rm -f '{}' \; 2>/dev/null || true

veryclean: clean
	@true

