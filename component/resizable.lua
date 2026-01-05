-- component/resizer.lua (new builder API + no per-call default table churn)
local glfw = require("ffi.ffi_glfw")

local _resz_state = _resz_state or {} -- keyed by parent id

local function C(c) return c.r, c.g, c.b, c.a end

-- defaults (allocated once)
local RESIZE_DEFAULT = {
  minW = 64,  minH = 32,
  maxW = nil, maxH = nil,
  grip = 16,
  inset = 2,
  zIndex = 10000,
  snapW = 0, snapH = 0,

  showGrip = false, -- draw glyph (and optional bg)
  gripColor = { r=255, g=255, b=255, a=48 },

  gripGlyph = "◢", -- U+25E2
  glyphScale = 0.9,
  glyphColor = { r=255, g=255, b=255, a=90 },
  glyphFontId = 0,
}

local COLOR_NONE = { r=0, g=0, b=0, a=0 }

local function clamp_opt(x, a, b)
  if a and x < a then x = a end
  if b and x > b then x = b end
  return x
end

local function snap(v, s)
  if not s or s == 0 then return v end
  return math.floor(v / s + 0.5) * s
end

-- resizable(parent_id, width, height, opts) -> newW, newH, changed, active
-- opts = {
--   minW=64, minH=32, maxW=nil, maxH=nil,
--   grip=16, inset=2, zIndex=10000,
--   snapW=0, snapH=0,
--   showGrip=false,
--   gripColor={r=255,g=255,b=255,a=48},
--   gripGlyph="◢", glyphScale=0.9, glyphColor=..., glyphFontId=0,
-- }
function resizable(parent_id, width, height, opts)
  local def = RESIZE_DEFAULT

  local minW = (opts and opts.minW) or def.minW
  local minH = (opts and opts.minH) or def.minH
  local maxW = (opts and opts.maxW) or def.maxW
  local maxH = (opts and opts.maxH) or def.maxH

  local grip  = (opts and opts.grip)  or def.grip
  local inset = (opts and opts.inset) or def.inset
  local z     = (opts and opts.zIndex)or def.zIndex

  local snapW = (opts and opts.snapW) or def.snapW
  local snapH = (opts and opts.snapH) or def.snapH

  local showGrip = ((opts and opts.showGrip) or def.showGrip) == true
  local gripColor  = (opts and opts.gripColor)  or def.gripColor
  local glyph      = (opts and opts.gripGlyph)  or def.gripGlyph
  local glyphScale = (opts and opts.glyphScale) or def.glyphScale
  local glyphColor = (opts and opts.glyphColor) or def.glyphColor
  local glyphFontId= (opts and opts.glyphFontId)or def.glyphFontId

  -- stable id
  local gripId = clay.id("resizer-grip", parent_id.id, true)

  -- hit target (attached to parent's bottom-right)
  clay.element(gripId)
    :parentId(parent_id.id)
    :attachTo(clay.ATTACH_TO_ELEMENT_WITH_ID)
    :attachPoints(clay.ATTACH_POINT_RIGHT_BOTTOM, clay.ATTACH_POINT_RIGHT_BOTTOM)
    :offset(-inset, -inset) -- keep inside the parent
    -- optional: enlarge hit area if you want (uncomment and tune)
    -- :expand(0, 0)
    :zIndex(z)
    :clipTo(clay.CLIP_TO_ATTACHED_PARENT)
    :pointerCaptureMode(clay.POINTER_CAPTURE_MODE_CAPTURE)
    :width(clay.SIZING_FIXED, grip)
    :height(clay.SIZING_FIXED, grip)
    :childAlignment(clay.ALIGN_X_RIGHT, clay.ALIGN_Y_CENTER)
    :backgroundColor(C(showGrip and gripColor or COLOR_NONE))
    :children(function()
      if showGrip then
        local fs = math.max(8, math.floor(grip * glyphScale))
        clay.text(glyph)
          :fontId(glyphFontId)
          :fontSize(fs)
          :textColor(C(glyphColor))
          :done()
      end
    end)

  -- mouse input
  glfw.GetCursorPos(device.win, mouse_x, mouse_y)
  local mx, my = mouse_x[0], mouse_y[0]
  local down = (glfw.GetMouseButton(device.win, glfw.MOUSE_BUTTON_LEFT) == glfw.PRESS)

  -- state
  local pid = parent_id.id
  local st = _resz_state[pid]
  if not st then
    st = { active=false, lastDown=false, sx=0, sy=0, sw=width, sh=height }
    _resz_state[pid] = st
  end

  local over = clay.pointerOver(gripId)
  local changed = false

  if down and not st.lastDown and over then
    -- start drag
    st.active = true
    st.sx, st.sy = mx, my
    st.sw, st.sh = width, height

  elseif st.active and down then
    -- drag
    local dx, dy = mx - st.sx, my - st.sy
    local w = clamp_opt(st.sw + dx, minW, maxW)
    local h = clamp_opt(st.sh + dy, minH, maxH)
    w = snap(w, snapW)
    h = snap(h, snapH)

    if w ~= width or h ~= height then
      width, height, changed = w, h, true
    end

  elseif (not down) and st.lastDown then
    -- end drag
    st.active = false
  end

  st.lastDown = down
  return width, height, changed, st.active
end
