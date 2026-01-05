local glfw = require("ffi.ffi_glfw")

_cb_state = _cb_state or {}

local function C(c) return c.r, c.g, c.b, c.a end

-- Default colors
local CB_DEFAULT = {
  box_base = { r=40,  g=40,  b=40,  a=160 },
  box_hov  = { r=60,  g=60,  b=60,  a=200 },
  box_act  = { r=80,  g=80,  b=80,  a=220 },
  box_dis  = { r=30,  g=30,  b=30,  a=100 },
  border   = { r=255, g=255, b=255, a=64  },
  fill     = { r=120, g=190, b=255, a=220 },
  label    = { r=230, g=230, b=240, a=255 },
  fillBorder = { r=255, g=255, b=255, a=90 },
}

-- checkbox(elid, label, defaultChecked, opts)
function checkbox(elid, label, defaultChecked, opts)
  -- input (read once here)
  glfw.GetCursorPos(device.win, mouse_x, mouse_y)
  local down = glfw.GetMouseButton(device.win, glfw.MOUSE_BUTTON_LEFT) == glfw.PRESS

  -- config
  local size     = (opts and opts.size)     or 18
  local gap      = (opts and opts.gap)      or 8
  local fontId   = (opts and opts.fontId)   or 1
  local fontSize = (opts and opts.fontSize) or 16
  local disabled = (opts and opts.disabled) or false

  local colors = opts and opts.colors
  local box = colors and colors.box

  local c_box_base = (box and box.base) or CB_DEFAULT.box_base
  local c_box_hov  = (box and box.hov ) or CB_DEFAULT.box_hov
  local c_box_act  = (box and box.act ) or CB_DEFAULT.box_act
  local c_box_dis  = (box and box.dis ) or CB_DEFAULT.box_dis

  local c_border   = (colors and colors.border) or CB_DEFAULT.border
  local c_fill     = (colors and colors.fill)   or CB_DEFAULT.fill
  local c_label    = (colors and colors.label)  or CB_DEFAULT.label

  -- per-id state
  local key = elid.id
  local st = _cb_state[key]
  if not st then
    st = { downLast=false, pressed=false, value = not not defaultChecked }
    _cb_state[key] = st
  end

  -- hover (pointerOver is last-frame; that's fine)
  local hovered = (not disabled) and clay.pointerOver(elid) or false

  -- press/release
  local toggled = false
  if (not st.downLast) and down and hovered and (not disabled) then
    st.pressed = true
  elseif st.pressed and (not down) and st.downLast then
    st.value = not st.value
    toggled = true
    st.pressed = false
  elseif not down then
    st.pressed = false
  end
  st.downLast = down

  -- visuals
  local boxCol = disabled and c_box_dis or (st.pressed and c_box_act or (hovered and c_box_hov or c_box_base))

  -- root row
  clay.element(elid)
    :layoutDirection(clay.LEFT_TO_RIGHT)
    :childAlignment(clay.ALIGN_X_LEFT, clay.ALIGN_Y_CENTER)
    :width(clay.SIZING_FIT)
    :height(clay.SIZING_FIXED, size)
    :childGap(gap)
    :children(function()

      -- box
      clay.element(clay.id("cb-box", key))
        :width(clay.SIZING_FIXED, size)
        :height(clay.SIZING_FIXED, size)
        :childAlignment(clay.ALIGN_X_CENTER, clay.ALIGN_Y_CENTER)
        :backgroundColor(C(boxCol))
        :borderColor(C(c_border))
        :borderWidth(1)
        :children(function()
          if st.value then
            local pad = math.max(3, math.floor(size * 0.2))
            local fillSize = math.max(1, size - pad * 2)

            clay.element(clay.id("cb-fill", key))
              :width(clay.SIZING_FIXED, fillSize)
              :height(clay.SIZING_FIXED, fillSize)
              :backgroundColor(C(c_fill))
              :borderColor(C(CB_DEFAULT.fillBorder))
              :borderWidth(1)
              :close()
          end
        end)

      if label ~= nil then
        clay.text(label)
          :fontId(fontId)
          :fontSize(fontSize)
          :textColor(C(c_label))
          :done()
      end
    end)

  return st.value, toggled
end
