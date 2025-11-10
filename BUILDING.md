# Building clay_lua

## TL;DR
```bash
# Linux shared object
make            # outputs: bin/clay_lua.so

# Cross-compile Windows DLL (needs MinGW-w64)
make win64 CC=x86_64-w64-mingw32-gcc  # outputs: bin/clay_lua.dll
```

## Requirements
- Linux: gcc, make
- Windows cross (optional): `mingw-w64`

## Notes
- Sources are in `src/`:
  - `src/clay_lua_bindings/clay_lua_bindings.c`
  - `src/stb/stb_*_wrapper.c` (your wrappers over vendored stb headers)
- Outputs go to `bin/` (kept in git with `.gitkeep`, contents ignored).
