local cache = {}

local glfw = require("ffi.ffi_glfw")

local page_selected = 1
local pages = { "Home", "Corner Radius", "Long List", "Text Alignment", "Floating Inventory", "UI Controls"}
local page_paths = {
	"demo/page_home.lua", 
	"demo/page_corner_radius.lua", 
	"demo/page_longlist.lua", 
	"demo/page_text_alignment.lua", 
	"demo/page_floating_inventory.lua",
	"demo/page_ui_controls.lua"
}

-- Mouse click edge detection (so clicks only fire once per press)
local prevMouseDown = false
local function mouseClicked(nowDown)
    local clicked = (not prevMouseDown) and nowDown
    prevMouseDown = nowDown
    return clicked
end

local function SidebarItemComponent(label, i, mouse_down)
    local sidebar_id = clay.id("SidebarItem", i)

    local active  = page_selected == i
    local hovered = clay.pointerOver(sidebar_id)

    local col = hovered and COLOR_SIDEBAR_BG_HOV or COLOR_SIDEBAR_BG_BASE
    if active then col = COLOR_SIDEBAR_BG_ACT end

    clay.createElement(sidebar_id, {
        layout = {
            sizing = { width = clay.sizingGrow(), height = clay.sizingFixed(44) },
            childAlignment = { y = clay.ALIGN_Y_CENTER },
            padding = clay.paddingAll(12)
        },
        backgroundColor = col,
        border = {
            color = COLOR_WHITE_24,
            width = { left=0, right=0, top=1, bottom=1 }
        }
    }, function()
        if clay.hovered() and mouseClicked(mouse_down) then
            page_selected = i
        end

        clay.createTextElement(label, { fontId=1, fontSize=16, textColor = COLOR_WHITE })
    end)
end

function layout(dt)
    glfw.GetCursorPos(device.win, mouse_x, mouse_y)
    local mx, my = mouse_x[0], mouse_y[0]
    local down = glfw.GetMouseButton(device.win, glfw.MOUSE_BUTTON_LEFT) == glfw.PRESS

    clay.setLayoutDimensions(device.width, device.height)
    clay.setPointerState(mx, my, down)
	
	-- Only feed the global scroll integrator when NOT driving via a scrollbar
	if device.scrolling_override ~= true then
		local dx, dy = -device.scroll.x, -device.scroll.y
		clay.updateScrollContainers(true, dx, dy, dt)
	end
				
    clay.beginLayout()
    
local function C(c) return c.r, c.g, c.b, c.a end

clay.element("Root")
  :layoutDirection(clay.TOP_TO_BOTTOM)
  :width(clay.SIZING_FIXED, device.width)
  :height(clay.SIZING_FIXED, device.height)
  :backgroundColor(C(COLOR_ROOT_BG))
  :children(function()

    clay.element("Header")
      :width(clay.SIZING_GROW)
      :height(clay.SIZING_FIXED, 48)
      :padding(12)
      :backgroundColor(C(COLOR_HEADER_BG))
      :borderColor(C(COLOR_WHITE_45))
      :borderWidth(0, 0, 0, 1) -- l,t,r,b
      :children(function()
        clay.text("[shadow][b]Clay Demo:\t[color=#ffA0A0]LuaJIT 2.1[/color] + [color=#A0A0ff]BGFX[/color] + [color=#00ff00]GLFW[/color][/b][/shadow]")
          :fontId(1)
          :fontSize(16)
          :textColor(C(COLOR_WHITE))
          :done()
      end)

    clay.element("MainRow")
      :layoutDirection(clay.LEFT_TO_RIGHT)
      :width(clay.SIZING_GROW)
      :height(clay.SIZING_GROW)
      :childGap(0)
      :children(function()

        clay.element("Sidebar")
          :layoutDirection(clay.TOP_TO_BOTTOM)
          :width(clay.SIZING_FIXED, 220)
          :height(clay.SIZING_GROW)
          :padding(12)
          :childGap(8)
          :backgroundColor(C(COLOR_SIDEBAR_BG_BASE))
          :borderColor(C(COLOR_WHITE_32))
          :borderWidth(0, 0, 1, 0) -- l,t,r,b
          :children(function()
            for i, label in ipairs(pages) do
              SidebarItemComponent("[shadow][b]" .. label .. "[/b][/shadow]", i, down)
            end
          end)

        clay.element("Content")
          :width(clay.SIZING_GROW)
          :height(clay.SIZING_GROW)
          :padding(8)
          :layoutDirection(clay.TOP_TO_BOTTOM)
          :backgroundColor(C(COLOR_CONTENT_BG))
          :children(function()

            clay.text("Page: " .. pages[page_selected])
              :fontId(1)
              :fontSize(16)
              :textColor(240, 240, 255, 255)
              :done()

            -- leaf element => explicit close
            clay.element("Spacer")
              :width(clay.SIZING_GROW)
              :height(clay.SIZING_FIXED, 2)
              :close()

            clay.element("ScrollViewport")
              :width(clay.SIZING_FIT)         -- matches clay.sizingFit()
              :height(clay.SIZING_GROW)
              :padding(16, 16, 16, 0)         -- L,T,R,B
              :borderColor(C(COLOR_WHITE_24))
              :borderWidth(0, 1, 0, 0)        -- top border only
              :clip(false, true)              -- horizontal, vertical
              :children(function()

                clay.element("ScrollContent")
                  :width(clay.SIZING_FIT)
                  :height(clay.SIZING_FIT)
                  :layoutDirection(clay.TOP_TO_BOTTOM)
                  :padding(0)
                  :childGap(12)
                  :children(function()
                    local page_env = loadScript(page_paths[page_selected])
                    if page_env and page_env.layout then
                      page_env.layout(dt)
                    end
                  end)

                local viewport_id = clay.id("ScrollViewport")
                local content_id  = clay.id("ScrollContent")
                clay.scrollbar(viewport_id, content_id, device.scroll.y, nil)
              end)
          end)
      end)
  end)

end
