# Clay Lua (LuaJIT + BGFX + RGFW)

A LuaJIT renderer + UI demo for [Clay], running on BGFX with RGFW window and input handling.
Includes demo pages (corner radius, long lists, text alignment, floating inventory, UI controls, node editor, and transitions).

A demonstration of [clay_lua_bindings](https://github.com/revolucas/clay_lua_bindings)
## Features
- Clay UI elements and scrolling with pointer integration
- Clay ease-out transitions through the fluent builder API
- Text measurement and Rich Text parsing via `font_manager` and stb truetype
- BGFX rendering path (rectangle, rounded corners, borders, text, images)
- Demo pages: Home, Corner Radius, Long List, Text Alignment, Floating Inventory, UI Controls, Node Editor, Transitions
- Node editor with draggable typed-pin nodes, curved links, panning, zoom, and batched BGFX wire rendering

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/1f31e1ad-6288-4f06-9d14-a02c7765e85a" />

## Node editor

`clay.node_editor(id, options)` draws draggable nodes with typed input/output pins. Ctrl-click or Shift-click to select several nodes, or drag on empty canvas to marquee-select. Drag a selected node to move the whole selection. Delete/Backspace removes selected nodes and their links; click a wire and press Delete/Backspace, or right-click it, to unlink it. Ctrl+Z / Ctrl+Y undo and redo, F fits the graph, the middle mouse button pans, and the wheel zooms.

A node can also host regular Clay content. Build it with `clay.node(id, options)`, add pins, then open its body, declare children, and close it. The body callback receives `(node, zoom, contentWidth)` and can use any Clay component or builder, including custom drawing; `contentHeight` reserves body space. Clicks inside body content go to its widgets instead of dragging the node; set `contentInteractive=false` to keep click-drag behavior there.

```lua
local input = clay.node("input", { value=2.5 })
  :title("Input")
  :position(24, 40)
  :output("value", "Value", "number")
  :open()
  :children(function(node, zoom, contentWidth)
    node.value = clay.property(clay.id("input-value"), "Value", node.value, {
      min=0, max=20, step=0.5, width=contentWidth, height=28 * zoom,
    })
  end, 34)
  :close()
```

```lua
local nodes = {
  { id="source", title="Source", x=32, y=40,
    outputs={{ id="value", label="Value", type="number" }} },
  { id="display", title="Display", x=280, y=100,
    inputs={{ id="value", label="Value", type="number" }} },
}
local links = {}

clay.node_editor("example", {
  nodes=nodes,
  links=links,
  onConnect=function(link) links[#links + 1] = link end,
})
```

Each link uses `fromNode`, `fromPin`, `toNode`, and `toPin`. Node positions are stored in `x` and `y`; `onNodeMoved(id, x, y, node)` can persist moves into an application-owned model. `onDisconnect(link, index)` and `onDeleteNode(id, node, index)` can own removals when the graph is backed by an immutable model; without them, the component edits the node and link arrays directly.

By default, connecting to an occupied input replaces its link. Set `inputLinkPolicy` to `"multiple"` or `"reject"` to change that behavior. An input pin can override the policy with `allowMultipleLinks`; either end can also declare `maxLinks`. The returned editor object has `selectedNodes`, `selectedNode`, `selectedLink`, `canUndo`, `canRedo`, and `undo()`, `redo()`, and `fitView()` methods. Mutable node/link tables are included in history automatically. Applications that keep an immutable graph model can use `onHistoryRestore(snapshot, direction)` to apply undo/redo snapshots to their model.

## Transitions and dropdowns

Use `:transition(duration, property, ...)` on stable elements that remain declared
each frame. Checkboxes and radio buttons ease their indicator and hover colors
by default (0.18 seconds); set `transitionDuration = 0` to disable it. The
dropdown animates its clipped popup height and row colors. `listview` can animate
hover and selection colors with an opt-in `transitionDuration` (defaults to
`0`, which avoids transition state for lists that do not need it).

```lua
local options = {
  { label="Vulkan", value="vulkan" },
  { label="OpenGL", value="opengl" },
}
local selected = "vulkan"
local changed
selected, changed = clay.dropdown(clay.id("renderer"), options, selected, {
  width = 260,
  transitionDuration = 0.18,
})

clay.listview(clay.id("resources"), {
  items = resources,
  transitionDuration = 0.16,
})
```

`clay.dropdown(id, items, selectedValue, options)` returns the selected value
and a `changed` boolean. Items may be strings or tables with `label`/`text` and
`value`/`id`/`key` fields. Its popup floats below the control, follows the
attached parent's clipping rectangle, and does not reflow sibling layout. The
popup stays in the layout at zero height while closed, but its rows are only
declared while open so they cannot leak outside the closed popup's clip.
Row-color transitions are enabled for up to 96 dropdown entries or visible
listview rows per component, limiting how much transition state each widget can
consume.
Larger sets still work with immediate row-color feedback; use `viewport_id` with
large listviews so only visible rows are declared.

## Themes

`require("theme")` provides reusable color, spacing, radius, type, motion, and
component-default tokens. The demo's header dropdown switches the active
palette across the shell, controls, tables, lists, and node editor. Palettes
are switched by reference;
token tables are reused rather than copied each frame.

```lua
local theme = require("theme")
clay.theme = theme -- required by the native builder's :style() method

theme.set("graphite") -- "indigo", "graphite", or "paper"

-- Built-in component defaults are theme tokens; widget options override them.
local editHeight = theme.defaults.edit.height
local compactCheckboxSize = theme.defaults.checkbox.size

clay.element("Navigation")
  :style("compact") -- scope applies through this element's children
  :children(function()
    clay.element("NavigationRow")
      :height(clay.SIZING_FIXED, theme.spacing.navItemHeight)
      :padding(theme.spacing.navItemPadding)
      :backgroundColor(theme.colors.sidebar)
      :close()
  end)
```

The builder closes the style scope automatically, including for nested elements.
Aliases are reusable partial overlays and can be added with
`theme.define("alias", { colors = { accent = ... }, spacing = { ... }, defaults = { edit = { height = 30 } } })`.
Nested aliases can override one component token while inheriting the rest from
the active palette. The built-in `compact` and `relaxed` aliases adjust widget
dimensions and spacing together. Component options such as
`edit(..., { height = 40 })` override theme defaults. Add another selectable
palette with `theme.defineTheme(name, palette, displayName)`; it is added to the
shared dropdown options list.

## Project Layout (selected)
- `main.lua` — entry point; sets up window, bgfx, Clay, loads shaders, and runs the main loop.
- `window.lua` — RGFW window, input, clipboard, and callback API exposed to Lua.
- `src/rgfw/` — vendored RGFW 1.8.1 and the small native adapter used by LuaJIT.
- `font_manager.lua` — text measuring utilities for Clay.
- `demo/` — demo page modules loaded dynamically by the app’s body.
- `component/` — UI components (checkbox, radio, slider, scrollbar, color picker, edit, property, dropdown, listview, tableview, node editor, resizable).
- `clay/` — Clay C header (vendored).
- `shader/` — precompiled BGFX shaders (`clay.vs.bin`, `clay.fs.bin`).

## Fonts and rich text

`font_manager.id(alias_or_path)` returns a font id. Built-in fonts are registered
by name, and a font file under `font/` can be resolved by its file name without
the extension. `font_manager.addFont(path, alias)` registers a custom font and
returns its id. Rich text can then select it with `[font=alias]` or
`[font=id]`.

Rich text style tags use nested scopes, so closing a tag restores the previous
style even when the same tag is nested:

```text
[color=#E8C45AFF]Gold [b]bold[/b][/color]
[shadow strength=0.6;color=#000000A0;x=1;y=2]Shadow[/shadow]
[outline size=1;color=#202020FF]Outlined[/outline]
```

The font manager also supports `[size=px]`, `[font=...]`, `[kerning=off]`,
`[i]`, `[strike]`, `[br]`, `[cp=0x...]`, and `[u+XXXX]`. Text runs that use
different fonts are rendered with their own atlas textures, and mixed font
sizes share a line baseline.

## Build & Run

### Requirements
- LuaJIT 2.1 (runtime + dev headers)
- BGFX shared library for your OS
- Linux X11 development libraries for building RGFW (`libX11`, `libXrandr`, `libXcursor`, `libXi`, `libXinerama`, `libXext`)

### Quick start
- **Linux:** `./run.sh`  
- **Windows:** `run.bat`  
(*These run `luajit main.lua` from the repo root.*)

#### Linux example
Run `make linux bgfx-runtime`
