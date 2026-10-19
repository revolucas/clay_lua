-- component/radio.lua (new builder API, no per-call default table churn)
local window = require("window")
local theme = require("theme")

_radio_group = _radio_group or {} -- per-group selected value
_radio_btn   = _radio_btn   or {} -- per-button press state

local function C(c) return c.r, c.g, c.b, c.a end
local TRANSPARENT = { r=0, g=0, b=0, a=0 }

-- defaults (allocated once)
local RADIO_DEFAULT = {
  disabled  = false,
  allowNone = false,
}

-- radio(elid, label, groupKey, myValue, defaultSelected, opts)
-- opts (all optional; read-only):
--   opts.size, opts.gap, opts.fontId, opts.fontSize, opts.disabled
--   opts.colors: { ringBase, ringHov, ringAct, ringDis, border, dot, label, dotBorder }
--   opts.allowNone: true to allow deselecting all by clicking selected
--   opts.transitionDuration: indicator and color transition time in seconds (0 disables)
function radio(elid, label, groupKey, myValue, defaultSelected, opts)
  -- input (read once)
  local down = (window.mouseButtonDown(window.MOUSE_BUTTON_LEFT))

  -- config
  local def      = RADIO_DEFAULT
  local defaults = theme.defaults.radio
  local size     = (opts and opts.size)     or defaults.size
  local gap      = (opts and opts.gap)      or theme.spacing.controlGap
  local fontId   = (opts and opts.fontId)   or defaults.fontId
  local fontSize = (opts and opts.fontSize) or theme.type.body
  local disabled = (opts and opts.disabled) or def.disabled
  local allowNone= (opts and opts.allowNone)or def.allowNone
  local transitionDuration = opts and opts.transitionDuration
  if transitionDuration == nil then transitionDuration = theme.motion.standard end
  assert(type(transitionDuration) == "number" and transitionDuration >= 0,
    "radio: transitionDuration must be a non-negative number")

  -- colors (no allocations)
  local dc   = theme.colors.radio
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
  local dotSize = math.max(6, math.floor(size * 0.55))
  local dotColor = selected and dotCol or TRANSPARENT
  local dotBorderColor = selected and dotBorder or TRANSPARENT

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
      local ringBuilder = clay.element(ringId)
        :width(clay.SIZING_FIXED, size)
        :height(clay.SIZING_FIXED, size)
        :childAlignment(clay.ALIGN_X_CENTER, clay.ALIGN_Y_CENTER)
        :backgroundColor(C(ringCol))
        :borderColor(C(border))
        :borderWidth(1)
        :cornerRadius(-1, -1, -1, -1) -- circle
      if transitionDuration > 0 then
        ringBuilder:transition(transitionDuration, "backgroundColor")
      end
      ringBuilder:children(function()
        -- Keep the dot in the tree while unselected so selection can fade in
        -- and out without relying on element enter/exit transitions.
        local dotBuilder = clay.element(dotId)
          :width(clay.SIZING_FIXED, dotSize)
          :height(clay.SIZING_FIXED, dotSize)
          :backgroundColor(C(dotColor))
          :borderColor(C(dotBorderColor))
          :borderWidth(1)
          :cornerRadius(-1, -1, -1, -1)
        if transitionDuration > 0 then
          dotBuilder:transition(transitionDuration, "backgroundColor", "borderColor")
        end
        dotBuilder:close()
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
