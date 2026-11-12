# Third-party notices

This repository includes or builds with third-party software and assets. Their
respective licenses apply to those parts:

- Clay Lua: [MIT License](LICENSE).
- `clay_lua_bindings`: [MIT License](src/clay_lua_bindings/LICENSE).
- Clay: [license](src/clay/LICENSE.md).
- RGFW: [license](src/rgfw/LICENSE).
- stb libraries: [license](src/stb/LICENSE).
- LuaJIT, BGFX, Shaderc, bx, and bimg are included in native release packages; their
  license texts are in [third_party_licenses](third_party_licenses/).
- The packages include BGFX, bx, and bimg runtime dependencies. The release
  archives also include applicable upstream license files harvested from those
  source checkouts under `licenses/upstream/`.
- The Windows package includes MinGW's `libgcc` runtime. Its GPL and Runtime
  Library Exception notices are in `third_party_licenses/`.
- The Windows package includes Microsoft's `D3DCompiler_47.dll`, a
  redistributable Windows SDK component; see Microsoft's
  [packaging guidance](https://learn.microsoft.com/en-us/gaming/gdk/docs/features/common/packaging/packaging-framework-packages).
- DejaVu Serif font (`font/DejaVuSerif.ttf`): see
  [font/LICENSE-DejaVu.txt](font/LICENSE-DejaVu.txt).
- VS Code Codicons font (`font/codicon.ttf`): Microsoft, VS Code Codicons,
  licensed under [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).
  Project: [microsoft/vscode-codicons](https://github.com/microsoft/vscode-codicons).
- The browser build fetches [lua-ffi-wasm](https://github.com/thenumbernine/lua-ffi-wasm)
  and its Lua, luaffifb, and libffi submodules. Their upstream license files
  are included in the fetched source checkout under `web/vendor/`.
