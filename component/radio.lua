-- component/radio.lua (new builder API, no per-call default table churn)
local glfw = require("ffi.ffi_glfw")

_radio_group = _radio_group or {} -- per-group selected value
_radio_btn   = _radio_btn   or {} -- per-button press state

local function C(c) return c.r, c.g, c.b, c.a end

-- defaults (allocated once)
local RADIO_DEFAULT = {
  size      = 20,
  gap       = 8,
  fontId    = 1,
  fontSize  = 16,
  disabled  = false,
  allowNone = false,
  colors = {
    ringBase  = { r=40,  g=40,  b=40,  a=160 },
    ringHov   = { r=60,  g=60,  b=60,  a=200 },
    ringAct   = { r=80,  g=80,  b=80,  a=220 },
    ringDis   = { r=30,  g=30,  b=30,  a=100 },
    border    = { r=255, g=255, b=255, a=64  },
    dot       = { r=120, g=190, b=255, a=220 },
    label     = { r=230, g=230, b=240, a=255 },
    dotBorder = { r=255, g=255, b=255, a=90  },
  }
}

-- radio(elid, label, groupKey, myValue, defaultSelected, opts)
-- opts (all optional; read-only):
--   opts.size, opts.gap, opts.fontId, opts.fontSize, opts.disabled
--   opts.colors: { ringBase, ringHov, ringAct, ringDis, border, dot, label, dotBorder }
--   opts.allowNone: true to allow deselecting all by clicking selected
function radio(elid, label, groupKey, myValue, defaultSelected, opts)
  -- input (read once)
  local down = (glfw.GetMouseButton(device.win, glfw.MOUSE_BUTTON_LEFT) == glfw.PRESS)

  -- config
  local def      = RADIO_DEFAULT
  local size     = (opts and opts.size)     or def.size
  local gap      = (opts and opts.gap)      or def.gap
  local fontId   = (opts and opts.fontId)   or def.fontId
  local fontSize = (opts and opts.fontSize) or def.fontSize
  local disabled = (opts and opts.disabled) or def.disabled
  local allowNone= (opts and opts.allowNone)or def.allowNone

  -- colors (no allocations)
  local dc   = def.colors
  local col  = opts and opts.colors
  local ringBase  = (col and col.ringBase)  or dc.ringBase
  local ringHov   = (col and col.ringHov)   or dc.ringHov
  local ringAct   = (col and col.ringAct)   or dc.ringAct
  local ringDis   = (col and col.ringDis)   or dc.ringDis
  local border    = (col and col.border)    or dc.border
  local dotCol    = (col and col.dot)       or dc.dot
  local labelCol  = (col and col.label)     or dc.label
  local dotBorder = (col and col.dotBorder) or dc.dotBorder

  -- group init
  local gsel = _radio_group[groupKey]
  if gsel == nil and defaultSelected then
    gsel = myValue
    _radio_group[groupKey] = gsel
  end
  local selected = (gsel ~= nil and gsel == myValue)

  -- per-button state
  local key = elid.id
  local st = _radio_btn[key]
  if not st then
    st = { downLast=false, pressed=false }
    _radio_btn[key] = st
  end

  local hovered = (not disabled) and clay.pointerOver(elid) or false

  -- press/release
  local changed = false
  if (not st.downLast) and down and hovered and (not disabled) then
    st.pressed = true
  elseif st.pressed and (not down) and st.downLast then
    st.pressed = false

    local before = _radio_group[groupKey]
    if selected then
      if allowNone then _radio_group[groupKey] = nil end
    else
      _radio_group[groupKey] = myValue
    end

    changed  = (_radio_group[groupKey] ~= before)
    selected = (_radio_group[groupKey] == myValue)
  elseif not down then
    st.pressed = false
  end
  st.downLast = down

  -- visuals
  local ringCol = disabled and ringDis or (st.pressed and ringAct or (hovered and ringHov or ringBase))

  -- ids
  local ringId = clay.id("radio-ring", key, true)
  local dotId  = clay.id("radio-dot",  key, true)

  -- layout: [ring][gap][label]
  clay.element(elid)
    :layoutDirection(clay.LEFT_TO_RIGHT)
    :childAlignment(clay.ALIGN_X_LEFT, clay.ALIGN_Y_CENTER)
    :width(clay.SIZING_FIT)
    :height(clay.SIZING_FIXED, size)
    :childGap(gap)
    :children(function()
      clay.element(ringId)
        :width(clay.SIZING_FIXED, size)
        :height(clay.SIZING_FIXED, size)
        :childAlignment(clay.ALIGN_X_CENTER, clay.ALIGN_Y_CENTER)
        :backgroundColor(C(ringCol))
        :borderColor(C(border))
        :borderWidth(1)
        :cornerRadius(-1, -1, -1, -1) -- circle
        :children(function()
          if selected then
            local dot = math.max(6, math.floor(size * 0.55))
            clay.element(dotId)
              :width(clay.SIZING_FIXED, dot)
              :height(clay.SIZING_FIXED, dot)
              :backgroundColor(C(dotCol))
              :borderColor(C(dotBorder))
              :borderWidth(1)
              :cornerRadius(-1, -1, -1, -1)
              :close()
          end
        end)

      if label ~= nil then
        clay.text(label)
          :fontId(fontId)
          :fontSize(fontSize)
          :textColor(C(labelCol))
          :done()
      end
    end)

  return selected, changed
end
