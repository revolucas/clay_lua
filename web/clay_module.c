#include "lua.h"
#include "lauxlib.h"
#include <bgfx/c99/bgfx.h>

int luaopen_clay(lua_State *L);

/* Register Clay in a Lua state created by lua-interop's Lua 5.4 runtime. */
int clay_lua_register(lua_State *L) {
	/* Keep the BGFX C API linked so lua-ffi-wasm can resolve it through dlsym. */
	(void)bgfx_get_interface(BGFX_API_VERSION);
	luaL_requiref(L, "clay", luaopen_clay, 1);
	lua_pop(L, 1);
	return 0;
}
