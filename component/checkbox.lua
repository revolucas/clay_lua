local window = require("window")
local theme = require("theme")
local ComponentBuilder = require("component.builder")

_cb_state = _cb_state or {}

local function C(c) return c.r, c.g, c.b, c.a end
local TRANSPARENT = { r=0, g=0, b=0, a=0 }

-- Default colors
-- checkbox(id, label, defaultChecked): configure fluently, then call :draw().
-- :transition(duration) controls indicator easing; use 0 to disable it.
local function render_checkbox(elid, label, defaultChecked, opts)
  -- input (read once here)
  local mx, my = window.mousePosition()
  local down = window.mouseButtonDown(window.MOUSE_BUTTON_LEFT)

  -- config
  local componentDefaults = theme.defaults.checkbox
  local size     = (opts and opts.size)     or componentDefaults.size
  local gap      = (opts and opts.gap)      or theme.spacing.controlGap
  local fontId   = (opts and opts.fontId)   or componentDefaults.fontId
  local fontSize = (opts and opts.fontSize) or theme.type.body
  local disabled = (opts and opts.disabled) or false
  local transitionDuration = opts and opts.transitionDuration
  if transitionDuration == nil then transitionDuration = theme.motion.standard end
  assert(type(transitionDuration) == "number" and transitionDuration >= 0,
    "checkbox: transitionDuration must be a non-negative number")

  local colors = opts and opts.colors
  local box = colors and colors.box

  local colorDefaults = theme.colors.checkbox
  local c_box_base = (box and box.base) or colorDefaults.box_base
  local c_box_hov  = (box and box.hov ) or colorDefaults.box_hov
  local c_box_act  = (box and box.act ) or colorDefaults.box_act
  local c_box_dis  = (box and box.dis ) or colorDefaults.box_dis

  local c_border   = (colors and colors.border) or colorDefaults.border
  local c_fill     = (colors and colors.fill)   or colorDefaults.fill
  local c_fillBorder = (colors and colors.fillBorder) or colorDefaults.fillBorder
  local c_label    = (colors and colors.label)  or colorDefaults.label

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
  local indicatorColor = st.value and c_fill or TRANSPARENT
  local indicatorBorder = st.value and c_fillBorder or TRANSPARENT
  local fillSize = math.max(1, size - math.max(3, math.floor(size * 0.2)) * 2)
  local boxId = clay.id("cb-box", key, true)
  local fillId = clay.id("cb-fill", key, true)

  -- root row
  clay.element(elid)
    :layoutDirection(clay.LEFT_TO_RIGHT)
    :childAlignment(clay.ALIGN_X_LEFT, clay.ALIGN_Y_CENTER)
    :width(clay.SIZING_FIT)
    :height(clay.SIZING_FIXED, size)
    :childGap(gap)
    :open()

  -- box
  local boxBuilder = clay.element(boxId)
    :width(clay.SIZING_FIXED, size)
    :height(clay.SIZING_FIXED, size)
    :childAlignment(clay.ALIGN_X_CENTER, clay.ALIGN_Y_CENTER)
    :backgroundColor(C(boxCol))
    :borderColor(C(c_border))
    :borderWidth(1)
  if transitionDuration > 0 then
    boxBuilder:transition(transitionDuration, "backgroundColor")
  end
  boxBuilder:open()

  -- Keep the indicator in the tree while unchecked so its color can
  -- transition smoothly in both directions.
  local fillBuilder = clay.element(fillId)
    :width(clay.SIZING_FIXED, fillSize)
    :height(clay.SIZING_FIXED, fillSize)
    :backgroundColor(C(indicatorColor))
    :borderColor(C(indicatorBorder))
    :borderWidth(1)
  if transitionDuration > 0 then
    fillBuilder:transition(transitionDuration, "backgroundColor", "borderColor")
  end
  fillBuilder:close()
  clay.close() -- checkbox box

  if label ~= nil then
    clay.text(label)
      :fontId(fontId)
      :fontSize(fontSize)
      :textColor(C(c_label))
      :done()
  end
  clay.close() -- checkbox row

  return st.value, toggled
end

ComponentBuilder.register("checkbox", function(builder)
  return render_checkbox(rawget(builder, "_id"), rawget(builder, "_arg1"),
    rawget(builder, "_arg2"), builder)
end)

function checkbox(elid, label, defaultChecked)
  return ComponentBuilder.new("checkbox", elid, label, defaultChecked)
end
