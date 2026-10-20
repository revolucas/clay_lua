# Clay Lua (LuaJIT + BGFX + RGFW)

A LuaJIT renderer + UI demo for [Clay], running on BGFX with RGFW window and input handling.
Includes demo pages (corner radius, long lists, text alignment, floating inventory, UI controls, node editor, transitions, retained UI, and editor widgets).

A demonstration of [clay_lua_bindings](https://github.com/revolucas/clay_lua_bindings)

An optional browser build uses Lua 5.4 with the `lua-ffi-wasm` FFI layer. It
includes BGFX/WebGL2 and Canvas2D renderers; see
[BUILDING.md](BUILDING.md#web-lua-54-ffi-wasm-bgfx) for build instructions.

## Features
- Clay UI elements and scrolling with pointer integration
- Clay ease-out transitions through the fluent builder API
- Mixed immediate and opt-in retained UI roots with automatic IDs, state dependencies, and cached BGFX geometry
- Text measurement and Rich Text parsing via `font_manager` and stb truetype
- BGFX rendering path (rectangle, rounded corners, borders, text, images)
- Browser Canvas2D rendering path for Clay geometry, rich text, clipping, and node editor primitives
- Demo pages: Home, Corner Radius, Long List, Text Alignment, Floating Inventory, UI Controls, Node Editor, Transitions, Retained UI
- Node editor with draggable typed-pin nodes, curved links, panning, zoom, and batched BGFX wire rendering

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/1f31e1ad-6288-4f06-9d14-a02c7765e85a" />

## Node editor

`clay.node_editor(id, options)` draws draggable nodes with typed input/output pins. Ctrl-click or Shift-click to select several nodes, or drag on empty canvas to marquee-select. Drag a selected node to move the whole selection. Delete/Backspace removes selected nodes and their links; click a wire and press Delete/Backspace, or right-click it, to unlink it. Ctrl+Z / Ctrl+Y undo and redo, F fits the graph, the middle mouse button pans, and the wheel zooms.

A node can also host regular Clay content. Build it with `clay.node(id, options)`, add pins, then set its body renderer with `:content(fn, contentHeight)`. The callback receives `(node, zoom, contentWidth)` and can use any Clay component or builder, including custom drawing. Clicks inside body content go to its widgets instead of dragging the node; set `contentInteractive=false` to keep click-drag behavior there.

```lua
local input = clay.node("input", { value=2.5 })
  :title("Input")
  :position(24, 40)
  :output("value", "Value", "number")
  :open()
  :content(function(node, zoom, contentWidth)
    node.value = clay.property(clay.id("input-value"), "Value", node.value)
      :range(0, 20)
      :step(0.5)
      :width(contentWidth)
      :height(28 * zoom)
      :draw()
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

## Component builders

Checkbox, radio, edit, slider, property, and dropdown return a small builder.
Chain configuration methods and call `:draw()` to emit the Clay elements and
receive the component's updated value. This avoids allocating a separate options
table for each control.

```lua
local gain, changed = clay.property(clay.id("gain"), "Gain", gain)
  :range(0, 1)
  :step(0.1)
  :width(180)
  :format(function(value) return string.format("Gain: %.2f", value) end)
  :draw()

local name, edited = clay.edit(clay.id("name"), name)
  :filter("ascii")
  :maxChars(64)
  :draw()
```

Shared methods include `:width()`, `:height()`, `:size()`, `:padding()`,
`:gap()`, `:fontId()`, `:fontSize()`, `:disabled()`, `:colors()`, and
`:transition()`.
Use `:size(value)` for checkbox/radio indicators and `:size(width, height)` as
shorthand for dimensions. Radio adds `:allowNone()`; edit adds `:filter()`,
`:maxChars()`, and `:focusOnCreate()`; slider and property add `:range()`,
`:step()`, and `:pageStep()`; property also adds `:format()`, `:buttonWidth()`,
and arrow styling;
dropdown adds `:rowHeight()`, `:maxRows()`, `:placeholder()`, and `:zIndex()`.

## Editor components

`treeview` reuses the virtualized list engine for a keyed hierarchy. It returns
the selected key, expanded-key table, selected-key set, visible row count, and
row height. Put large trees in a clipped Clay scroll container and pass its id
to `:viewport(id)` to limit row declarations to the visible range. Use
`:expanded(table)` to provide an initial or application-owned expansion set.

`asset_browser` provides search, a virtualized thumbnail grid, selection, and
double-click activation. Items can use `key`, `name`, `category`, `description`,
`tags`, BGFX image data in `thumbnail`/`image`, `color`, and `icon` fields;
callbacks can adapt an existing asset model without copying it. Its `:draw()` returns the selected key,
selected item, visible item count, current search text, and a selection-change
flag.

`inspector` is a layout helper for Clay controls, rather than a fixed property
schema. Add sections and rows, then put any existing control in a row:

```lua
local selectedKey, expanded = clay.treeview(clay.id("scene-tree"), scene)
  :rowHeight(26)
  :expanded(openFolders)
  :onSelect(function(key) selectedKey = key end)
  :draw()

local assetKey, asset = clay.asset_browser(clay.id("assets"), assets)
  :width(360)
  :height(320)
  :columns(3)
  :onSelect(function(key, item) selectedAsset = item end)
  :draw()

clay.inspector(clay.id("asset-inspector"), function(ui)
  ui:section("Asset")
    :value("Name", asset and asset.name)
    :value("Path", asset and asset.path)
    :row("Roughness", function()
      roughness = clay.slider(clay.id("roughness"), roughness)
        :range(0, 1)
        :step(0.01)
        :draw()
    end)
end)
  :width(420)
  :draw()
```

The `Editor Widgets` demo page combines these components in a small scene and
asset editing workflow.

## Transitions and dropdowns

Use `:transition(duration, property, ...)` on stable elements that remain declared
each frame. Checkboxes and radio buttons ease their indicator and hover colors
by default (0.18 seconds); call `:transition(0)` to disable it. The
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
selected, changed = clay.dropdown(clay.id("renderer"), options, selected)
  :width(260)
  :transition(0.18)
  :draw()

clay.listview(clay.id("resources"), {
  items = resources,
  transitionDuration = 0.16,
})
```

`:draw()` returns the selected value and a `changed` boolean. Items may be
strings or tables with `label`/`text` and
`value`/`id`/`key` fields. The popup floats below the control and follows its
parent's clipping rectangle without reflowing sibling layout. Long menus show up
to eight rows by default and scroll; use `:maxRows()` to change that limit. While
closed, the popup stays at zero height; popup rows are declared only while open
to respect its clip.
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
  :open()
clay.element("NavigationRow")
  :height(clay.SIZING_FIXED, theme.spacing.navItemHeight)
  :padding(theme.spacing.navItemPadding)
  :backgroundColor(theme.colors.sidebar)
  :close()
clay.close() -- Navigation
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

## Retained roots

Keep the existing immediate `beginLayout()` / `endLayoutFast()` loop for UI that
changes every frame. Use `clay.retained(options, build)` for panels or other
subtrees whose layout changes less often. Clean roots reuse their previous Clay
layout and render packets while the immediate builder continues as usual.

```lua
local count = clay.state(0)

local panel = clay.retained({ alias = "counter", layer = 10 }, function()
  clay.element():alias("panel")
    :width(clay.SIZING_FIXED, 260)
    :height(clay.SIZING_FIT)
    :open()
  clay.text("Count: " .. count:get()):fontSize(20):done()
  clay.element():alias("increment")
    :width(clay.SIZING_FIXED, 140)
    :height(clay.SIZING_FIXED, 36)
    :open()
  clay.text("Increment"):done()
  clay.close()
  clay.close()
end)

panel:on("increment", "click", function()
  count:set(count:get() + 1)
end)
```

Elements without explicit IDs receive automatic hierarchical IDs, including
top-level roots. `:alias(name)` gives an element a root-local name for
`panel:get(name):id()`, `:bounds()`, `:pointerOver()`, and event registration.
Use `clay.keyed(key, function() ... end)` around repeated items whose order can
change; their IDs then follow the key rather than the current list position.
Explicit `clay.id(...)` and string IDs remain supported.

`clay.state(value)` provides `:get()`, `:set(value)`, `:update(fn)`, and
`:touch()`. A retained build subscribes to every state it reads. Multiple writes
before the next layout coalesce into one root rebuild. Table observation is
shallow: after changing a table in place, call `state:touch()` to invalidate
dependents. A state's value is not copied.

Roots stay mounted while hidden. `:show()`, `:hide()`, `:invalidate()`, and
`:destroy()` control their lifecycle; destroying a root releases its Clay context
and cached packet resources. `:update(fn)` runs once per visible frame with
`(root, dt, input)` but does not rebuild unless it changes observed state or
calls `root:invalidate()`. `input:consume()` prevents the immediate UI beneath
the root from receiving the pointer event.

Built-in components that poll pointer input wake their retained root during
pointer movement, clicks, and active drags, then return to cached replay when
interaction stops. Keyboard-driven components track key events and wake only
roots that contain them. Custom components that poll keyboard state can call
`clay._trackRetainedKeyboardInput()` while building their root.

Retained roots use numeric layers. Layer 0 roots draw after the immediate UI;
negative layers draw beneath it. At the same layer, roots keep their registration
order. The topmost hit root receives pointer events. Floating anchors stay within
their own root; place cross-root overlays with a layer and explicit position.
Resize, theme changes, active Clay scrolling, and active Clay transitions
invalidate affected roots automatically. Call `clay.resourcesChanged()` after
reloading resources used by retained commands, or `root:invalidate()` to rebuild
one root. Custom commands can update mutable payloads in `root:update`; set
`volatile = true` when a custom command's packet itself must be recreated each
frame.

The retained demo page shows an interactive cached counter next to live immediate
content, with build, layout, update, and packet replay counters.

## Project Layout (selected)
- `main.lua` — entry point; sets up window, bgfx, Clay, loads shaders, and runs the main loop.
- `window.lua` — RGFW window, input, clipboard, and callback API exposed to Lua.
- `src/rgfw/` — vendored RGFW 1.8.1 and the small native adapter used by LuaJIT.
- `font_manager.lua` — text measuring utilities for Clay.
- `demo/` — demo page modules loaded dynamically by the app’s body.
- `component/` — UI components (checkbox, radio, slider, scrollbar, color picker, edit, property, dropdown, listview/treeview, inspector, asset browser, tableview, node editor, resizable).
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
