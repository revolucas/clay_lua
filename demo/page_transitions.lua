local window = require("window")

local selectedRenderer = "vulkan"
local renderers = {
  { label="Vulkan", value="vulkan" },
  { label="Direct3D 11", value="d3d11" },
  { label="OpenGL", value="opengl" },
  { label="Metal", value="metal" },
  { label="WebGPU", value="webgpu" },
}

local resourceRows = {
  { key="textures", text="Textures" },
  { key="meshes", text="Meshes" },
  { key="materials", text="Materials" },
  { key="audio", text="Audio" },
}

local cardExpanded = false
local cardWasDown = false
local cardPressed = false
local function C(c) return c.r, c.g, c.b, c.a end

function layout()
  clay.text("Transitions")
    :fontId(1):fontSize(22)
    :textColor(C(theme.colors.text))
    :done()

  clay.text("Clay animates changed properties on elements that keep a stable ID and stay in the layout each frame. These examples use the builder transition handler.")
    :fontId(1):fontSize(14)
    :textColor(C(theme.colors.textMuted))
    :done()

  clay.text("Builder transition: size and color")
    :fontId(1):fontSize(17)
    :textColor(C(COLOR_WHITE))
    :done()

  local cardId = clay.id("TransitionResizeCard")
  local down = window.mouseButtonDown(window.MOUSE_BUTTON_LEFT)
  local hovered = clay.pointerOver(cardId)
  if down and not cardWasDown and hovered then
    cardPressed = true
  elseif not down and cardWasDown then
    if cardPressed and hovered then cardExpanded = not cardExpanded end
    cardPressed = false
  end

  clay.element(cardId)
    :col()
    :width(clay.SIZING_FIXED, cardExpanded and 390 or 270)
    :height(clay.SIZING_FIXED, cardExpanded and 112 or 76)
    :padding(12)
    :childGap(5)
    :bg(cardExpanded and {r=47,g=83,b=112,a=255} or {r=43,g=53,b=72,a=255})
    :borderColor(255, 255, 255, 56)
    :borderWidth(1)
    :transition(0.24, "width", "height", "backgroundColor")
    :open()
  clay.text(cardExpanded and "Expanded state" or "Compact state")
    :fontId(1):fontSize(17)
    :textColor(C(COLOR_WHITE))
    :done()
  clay.text("Click to animate size and color.")
    :fontId(1):fontSize(14)
    :textColor(C(theme.colors.textMuted))
    :done()
  clay.close()
  cardWasDown = down

  clay.text("Checkbox and radio: eased indicator states")
    :fontId(1):fontSize(17)
    :textColor(C(COLOR_WHITE))
    :done()

  clay.text("Toggle the check or radio choice. Their markers fade, and the rings ease on hover.")
    :fontId(1):fontSize(14)
    :textColor(C(theme.colors.textMuted))
    :done()

  clay.checkbox(clay.id("TransitionCheckbox"), "Enable the example", false)
    :transition(0.32)
    :draw()

  clay.element(clay.id("TransitionRadioRow"))
    :row()
    :width(clay.SIZING_FIT)
    :height(clay.SIZING_FIT)
    :childGap(18)
    :open()
  clay.radio(clay.id("TransitionRadioGentle"), "Gentle",
    "TransitionRadioGroup", "gentle", true)
    :transition(0.32)
    :draw()
  clay.radio(clay.id("TransitionRadioBold"), "Bold",
    "TransitionRadioGroup", "bold", false)
    :transition(0.32)
    :draw()
  clay.close()

  clay.text("Dropdown: animated popup height and hover/selection colors")
    :fontId(1):fontSize(17)
    :textColor(C(COLOR_WHITE))
    :done()

  local changed = false
  selectedRenderer, changed = clay.dropdown(
    clay.id("TransitionRendererDropdown"), renderers, selectedRenderer)
    :width(270)
    :transition(0.18)
    :draw()

  clay.text("Selected renderer: " .. tostring(selectedRenderer) .. (changed and " (changed)" or ""))
    :fontId(1):fontSize(14)
    :textColor(C(theme.colors.textMuted))
    :done()

  clay.text("List view: opt-in row color transitions")
    :fontId(1):fontSize(17)
    :textColor(C(COLOR_WHITE))
    :done()

  local selectedResource = clay.listview(clay.id("TransitionResourceList"), resourceRows)
    :rowHeight(30)
    :zebra(false)
    :transition(0.16)
    :colors(theme.colors.listview)
    :draw()

  clay.text("Selected resource: " .. tostring(selectedResource or "none"))
    :fontId(1):fontSize(14)
    :textColor(C(theme.colors.textMuted))
    :done()
end
