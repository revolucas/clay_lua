# Clay Lua (LuaJIT + BGFX + GLFW)

A LuaJIT renderer + UI demo for [Clay], running on BGFX and GLFW via FFI.  
Includes demo pages (corner radius, long lists, text alignment, floating inventory, UI controls, etc.).

## Features
- Clay UI elements and scrolling with pointer integration
- Text measurement and Rich Text parsing via `font_manager` and stb truetype
- BGFX rendering path (rectangle, rounded corners, borders, text, images)
- Demo pages: Home, Corner Radius, Long List, Text Alignment, Floating Inventory, UI Controls

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/1f31e1ad-6288-4f06-9d14-a02c7765e85a" />

## Project Layout (selected)
- `main.lua` — entry point; sets up window, bgfx, Clay, loads shaders, and runs the main loop.
- `window.lua` — GLFW window creation + callback plumbing exposed to Lua.  
- `font_manager.lua` — text measuring utilities for Clay.
- `demo/` — demo page modules loaded dynamically by the app’s body.
- `component/` — UI components (checkbox, radio, slider, scrollbar, color picker, edit, property, listview, resizable).
- `clay/` — Clay C header (vendored).
- `shader/` — precompiled BGFX shaders (`clay.vs.bin`, `clay.fs.bin`).

## Build & Run

### Requirements
- LuaJIT 2.1 (runtime + dev headers)
- BGFX shared library for your OS
- GLFW shared library

### Quick start
- **Linux:** `./run.sh`  
- **Windows:** `run.bat`  
(*These run `luajit main.lua` from the repo root.*)

#### Linux example
Run `make`

