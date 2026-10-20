local cache = {}

local window = require("window")
local theme = require("theme")

local function C(c) return c.r, c.g, c.b, c.a end

local page_selected = 1
local pages = { "Home", "Corner Radius", "Long List", "Text Alignment", "Floating Inventory", "UI Controls", "Node Editor", "Transitions", "Retained UI", "Editor Widgets"}
local page_paths = {
	"demo/page_home.lua", 
	"demo/page_corner_radius.lua", 
	"demo/page_longlist.lua", 
	"demo/page_text_alignment.lua", 
	"demo/page_floating_inventory.lua",
	"demo/page_ui_controls.lua",
	"demo/page_node_editor.lua",
	"demo/page_transitions.lua",
	"demo/page_retained.lua",
	"demo/page_editor_widgets.lua"
}
local pendingTheme = nil
local activePageIndex, activePageEnv = nil, nil
local previousPageSelection = page_selected

-- Mouse click edge detection (so clicks only fire once per press)
local prevMouseDown = false
local function mouseClicked(nowDown)
    local clicked = (not prevMouseDown) and nowDown
    prevMouseDown = nowDown
    return clicked
end

local function SidebarItemComponent(label, i, mouse_clicked)
    local sidebar_id = clay.id("SidebarItem", i)

    local active  = page_selected == i
    local hovered = clay.pointerOver(sidebar_id)

    local colors = theme.colors
    local col = hovered and colors.sidebarHover or colors.sidebar
    if active then col = colors.sidebarActive end

    clay.element(sidebar_id)
        :width(clay.SIZING_GROW)
        :height(clay.SIZING_FIXED, theme.spacing.navItemHeight)
        :childAlignment(clay.ALIGN_X_LEFT, clay.ALIGN_Y_CENTER)
        :padding(theme.spacing.navItemPadding)
        :backgroundColor(col.r, col.g, col.b, col.a)
        :borderColor(C(colors.borderSubtle))
        :borderWidth(0, 1, 0, 1)
        :open()
    if hovered and mouse_clicked then
        page_selected = i
    end

    clay.text(label)
        :fontId(1)
        :fontSize(16)
        :textColor(C(colors.text))
        :done()
    clay.close()
end

function layout(dt)
    theme.resetScopes()
    if pendingTheme then
        theme.set(pendingTheme)
        pendingTheme = nil
    end
    local mx, my = window.mousePosition()
    local down = window.mouseButtonDown(window.MOUSE_BUTTON_LEFT)
    local clicked = mouseClicked(down)

    clay.setLayoutDimensions(device.width, device.height)
    clay.setPointerState(mx, my, down)

    -- ScrollViewport is shared by all pages. Clear its old offset when opening
    -- Node Editor so a previous page's scroll position can't hide its top.
    if page_selected ~= previousPageSelection then
        if pages[page_selected] == "Node Editor" then
            clay.setScrollOffset(clay.id("ScrollViewport"), 0, 0)
        end
        previousPageSelection = page_selected
    end
	
	-- Route scroll input through Clay so retained roots can receive wheel events.
	-- The Node Editor converts the retained root's scroll delta into graph zoom.
	if device.scrolling_override ~= true then
		local dx, dy = -device.scroll.x, -device.scroll.y
		local nodeEditorOwnsWheel = pages[page_selected] == "Node Editor"
		-- Controls that query pointerOver claim their hit targets automatically;
		-- Clay drag-scroll stays enabled only over unclaimed content.
		clay.updateScrollContainers(not nodeEditorOwnsWheel, dx, dy, dt, nodeEditorOwnsWheel)
	end
				
	clay.beginLayout(dt)
clay.element("Root")
  :layoutDirection(clay.TOP_TO_BOTTOM)
  :width(clay.SIZING_FIXED, device.width)
  :height(clay.SIZING_FIXED, device.height)
  :backgroundColor(C(theme.colors.root))
  :open()

clay.element("Header")
  :row()
  :width(clay.SIZING_GROW)
  :height(clay.SIZING_FIXED, 60)
  :padding(12)
  :childGap(12)
  :childAlignment(clay.ALIGN_X_LEFT, clay.ALIGN_Y_CENTER)
  :backgroundColor(C(theme.colors.header))
  :borderColor(C(theme.colors.borderStrong))
  :borderWidth(0, 0, 0, 1) -- l,t,r,b
  :open()
local runtimeLabel
if device.isWeb then
    local backendLabel = device.renderer == "canvas2d" and "Canvas2D" or "BGFX WebGL2"
    runtimeLabel = "[color=#A0A0A0]Lua 5.4[/color] + [color=#A0A0ff]" .. backendLabel .. "[/color]"
else
    runtimeLabel = "[color=#ffA0A0]LuaJIT 2.1[/color] + [color=#A0A0ff]BGFX[/color] + [color=#00ff00]RGFW[/color]"
end
clay.text("[shadow][b]Clay Demo:\t" .. runtimeLabel .. "[/b][/shadow]")
  :fontId(1)
  :fontSize(theme.type.body)
  :textColor(C(theme.colors.text))
  :done()

clay.element("HeaderThemeSpacer")
  :wGrow()
  :h(1)
  :close()

clay.text("Theme")
  :fontId(1)
  :fontSize(theme.type.small)
  :textColor(C(theme.colors.textMuted))
  :done()

local selectedTheme, changed = clay.dropdown(
  clay.id("ThemeSelector"), theme.options, theme.currentName)
  :width(190)
  :rowHeight(theme.spacing.controlHeight)
  :fontSize(theme.type.small)
  :draw()
if changed then
  pendingTheme = selectedTheme
end
clay.close() -- Header

clay.element("MainRow")
  :layoutDirection(clay.LEFT_TO_RIGHT)
  :width(clay.SIZING_GROW)
  :height(clay.SIZING_GROW)
  :childGap(0)
  :open()

clay.element("Sidebar")
  :layoutDirection(clay.TOP_TO_BOTTOM)
  :width(clay.SIZING_FIXED, 220)
  :height(clay.SIZING_GROW)
  :padding(theme.spacing.panelPadding)
  :childGap(theme.spacing.controlGap)
  :backgroundColor(C(theme.colors.sidebar))
  :borderColor(C(theme.colors.border))
  :borderWidth(0, 0, 1, 0) -- l,t,r,b
  :style("compact")
  :open()
for i, label in ipairs(pages) do
  SidebarItemComponent("[shadow][b]" .. label .. "[/b][/shadow]", i, clicked)
end
clay.close() -- Sidebar

clay.element("Content")
  :width(clay.SIZING_GROW)
  :height(clay.SIZING_GROW)
  :padding(theme.spacing.controlGap)
  :layoutDirection(clay.TOP_TO_BOTTOM)
  :backgroundColor(C(theme.colors.content))
  :open()

clay.text("Page: " .. pages[page_selected])
  :fontId(1)
  :fontSize(16)
  :textColor(C(theme.colors.text))
  :done()

-- leaf element => explicit close
clay.element("Spacer")
  :width(clay.SIZING_GROW)
  :height(clay.SIZING_FIXED, 2)
  :close()

clay.element("ScrollViewport")
  :width(clay.SIZING_FIT)         -- fit the content width
  :height(clay.SIZING_GROW)
  :padding(theme.spacing.panelPadding, theme.spacing.panelPadding, theme.spacing.panelPadding, 0) -- L,T,R,B
  :borderColor(C(theme.colors.borderSubtle))
  :borderWidth(0, 1, 0, 0)        -- top border only
  :clip(false, true)              -- horizontal, vertical
  :open()

clay.element("ScrollContent")
  :width(clay.SIZING_FIT)
  :height(clay.SIZING_FIT)
  :layoutDirection(clay.TOP_TO_BOTTOM)
  :padding(0)
  :childGap(12)
  :open()
local page_env = loadScript(page_paths[page_selected])
if page_env and page_env.layout then
  if activePageIndex ~= page_selected then
    if activePageEnv and activePageEnv.onHide then activePageEnv.onHide() end
    activePageIndex, activePageEnv = page_selected, page_env
    if activePageEnv.onShow then activePageEnv.onShow() end
  end
  page_env.layout(dt)
end
clay.close() -- ScrollContent

local viewport_id = clay.id("ScrollViewport")
local content_id  = clay.id("ScrollContent")
clay.scrollbar(viewport_id, content_id, device.scroll.y, nil)
clay.close() -- ScrollViewport
clay.close() -- Content
clay.close() -- MainRow
clay.close() -- Root

end
