-- component/property.lua (new builder API, no per-call default table churn)
local glfw = require("ffi.ffi_glfw")

local _prop_state = _prop_state or {} -- [id] -> { active=false, focused=false, lastDown=false, repeatT=0, dragStartX=0, dragStartV=0 }
local _prop_keys  = _prop_keys  or {} -- key edge table

local function C(c) return c.r, c.g, c.b, c.a end

-- defaults
local PROP_DEFAULT = {
  min         = 0,
  max         = 1,
  step        = 0,
  pageStep    = nil, -- computed if nil
  width       = 220,
  height      = 28,
  pad         = 6,   -- horizontal padding inside center
  buttonW     = 28,
  cornerRadius= 8,
  fontId      = 0,
  fontSize    = 16,
  arrowFontId = 0,
  arrowSize   = 20,
  colors = {
    bg     = { r=30,  g=30,  b=35,  a=140 },
    bgHov  = { r=40,  g=40,  b=48,  a=160 },
    bgAct  = { r=55,  g=55,  b=65,  a=190 },
    text   = { r=235, g=235, b=245, a=255 },
    btn    = { r=70,  g=70,  b=85,  a=170 },
    btnHov = { r=85,  g=85,  b=110, a=200 },
    btnAct = { r=110, g=110, b=150, a=220 },
  }
}

local function clamp(x, a, b)
  if x < a then return a end
  if x > b then return b end
  return x
end
local function lerp(a, b, t) return a + (b - a) * t end
local function unlerp(a, b, x) return (b == a) and 0 or (x - a) / (b - a) end
local function snap_step(x, step)
  if not step or step == 0 then return x end
  return math.floor(x / step + 0.5) * step
end

local function key_edge(win, key, keyTable)
  local cur  = (glfw.GetKey(win, key) == glfw.PRESS)
  local last = keyTable[key] or false
  keyTable[key] = cur
  return (cur and not last), cur
end

-- property(elid, label, value, opts) -> newValue, changed, focused
-- opts:
-- { min, max, step, pageStep, width, height, pad, buttonW, cornerRadius,
--   format=function(v)->string OR format="%.2f",
--   fontId, fontSize, arrowFontId, arrowSize,
--   colors={ bg,bgHov,bgAct,text,btn,btnHov,btnAct } }
function property(elid, label, value, opts)
  local def = PROP_DEFAULT
  local dcol = def.colors
  local col = opts and opts.colors

  local minv = (opts and opts.min) or def.min
  local maxv = (opts and opts.max) or def.max
  if maxv == minv then maxv = minv + 1 end

  local step  = (opts and opts.step) or def.step
  local pageStep = (opts and (opts.pageStep ~= nil) and opts.pageStep) or def.pageStep
  if pageStep == nil then
    pageStep = (step > 0 and step * 10 or (maxv - minv) * 0.1)
  end

  local width   = (opts and opts.width)   or def.width
  local height  = (opts and opts.height)  or def.height
  local pad     = (opts and opts.pad)     or def.pad
  local buttonW = (opts and opts.buttonW) or def.buttonW
  local radius  = (opts and opts.cornerRadius) or def.cornerRadius

  local fontId      = (opts and opts.fontId)      or def.fontId
  local fontSize    = (opts and opts.fontSize)    or def.fontSize
  local arrowFontId = (opts and opts.arrowFontId) or def.arrowFontId
  local arrowSize   = (opts and opts.arrowSize)   or def.arrowSize

  local c_bg     = (col and col.bg)     or dcol.bg
  local c_bgHov  = (col and col.bgHov)  or dcol.bgHov
  local c_bgAct  = (col and col.bgAct)  or dcol.bgAct
  local c_text   = (col and col.text)   or dcol.text
  local c_btn    = (col and col.btn)    or dcol.btn
  local c_btnHov = (col and col.btnHov) or dcol.btnHov
  local c_btnAct = (col and col.btnAct) or dcol.btnAct

  -- input (read once)
  glfw.GetCursorPos(device.win, mouse_x, mouse_y)
  local mx, my = mouse_x[0], mouse_y[0]
  local down   = (glfw.GetMouseButton(device.win, glfw.MOUSE_BUTTON_LEFT) == glfw.PRESS)
  local nowT   = glfw.GetTime and glfw.GetTime() or 0

  -- state
  local key = elid.id
  local st = _prop_state[key]
  if not st then
    st = {
      active=false, focused=false, lastDown=false, repeatT=0,
      dragStartX=0, dragStartV=value
    }
    _prop_state[key] = st
  end

  -- normalize & snap current
  local n = clamp(unlerp(minv, maxv, value), 0, 1)
  if step > 0 then
    value = snap_step(lerp(minv, maxv, n), step)
    n = clamp(unlerp(minv, maxv, value), 0, 1)
  end

  local changed = false

  -- SUB-IDS
  local leftId   = clay.id("prop-left",   key, true)
  local centerId = clay.id("prop-center", key, true)
  local rightId  = clay.id("prop-right",  key, true)

  -- Visuals
  clay.element(elid)
    :layoutDirection(clay.LEFT_TO_RIGHT)
    :width(clay.SIZING_FIXED, width)
    :height(clay.SIZING_FIXED, height)
    :childAlignment(clay.ALIGN_X_CENTER, clay.ALIGN_Y_CENTER)
    :childGap(0)
    :backgroundColor(C(c_bg))
    :cornerRadius(radius, radius, radius, radius)
    :children(function()
      -- LEFT
      local hovL = clay.pointerOver(leftId)
      local colL = (down and hovL) and c_btnAct or (hovL and c_btnHov or c_btn)

      clay.element(leftId)
        :width(clay.SIZING_FIXED, buttonW)
        :height(clay.SIZING_FIXED, height)
        :childAlignment(clay.ALIGN_X_CENTER, clay.ALIGN_Y_CENTER)
        :backgroundColor(C(colL))
        :cornerRadius(radius, 0, radius, 0)
        :children(function()
          clay.text("◂")
            :fontId(arrowFontId)
            :fontSize(arrowSize)
            :textColor(C(c_text))
            :done()
        end)

      -- CENTER
      local hovC = clay.pointerOver(centerId)
      local bgC  = st.active and c_bgAct or (hovC and c_bgHov or c_bg)

      clay.element(centerId)
        :layoutDirection(clay.TOP_TO_BOTTOM)
        :width(clay.SIZING_GROW)
        :height(clay.SIZING_FIXED, height)
        :childAlignment(clay.ALIGN_X_CENTER, clay.ALIGN_Y_CENTER)
        :padding(pad, 0, pad, 0) -- horizontal only
        :backgroundColor(C(bgC))
        :children(function()
          local text
          if type(opts and opts.format) == "function" then
            text = (opts.format)(value)
          elseif type(opts and opts.format) == "string" then
            local ok, s = pcall(string.format, opts.format, value)
            text = ok and s or tostring(value)
          else
            text = string.format("%s: %s", label or "Property", tostring(value))
          end

          clay.text(text)
            :fontId(fontId)
            :fontSize(fontSize)
            :textColor(C(c_text))
            :done()
        end)

      -- RIGHT
      local hovR = clay.pointerOver(rightId)
      local colR = (down and hovR) and c_btnAct or (hovR and c_btnHov or c_btn)

      clay.element(rightId)
        :width(clay.SIZING_FIXED, buttonW)
        :height(clay.SIZING_FIXED, height)
        :childAlignment(clay.ALIGN_X_CENTER, clay.ALIGN_Y_CENTER)
        :backgroundColor(C(colR))
        :cornerRadius(0, radius, 0, radius)
        :children(function()
          clay.text("▸")
            :fontId(arrowFontId)
            :fontSize(arrowSize)
            :textColor(C(c_text))
            :done()
        end)
    end)

  local hoveredRoot = clay.pointerOver(elid)
  local hovL = clay.pointerOver(leftId)
  local hovC = clay.pointerOver(centerId)
  local hovR = clay.pointerOver(rightId)

  local function handle_repeat(startedNow)
    local firstDelay, repeatRate = 0.40, 0.06
    if startedNow then
      st.repeatT = nowT + firstDelay
      return true
    elseif down and nowT >= st.repeatT then
      st.repeatT = nowT + repeatRate
      return true
    end
    return false
  end

  if down and not st.lastDown then
    if hovL then
      st.focused = true
      if handle_repeat(true) then
        value = clamp(value - (step > 0 and step or 1), minv, maxv)
        if step > 0 then value = snap_step(value, step) end
        changed = true
      end
    elseif hovR then
      st.focused = true
      if handle_repeat(true) then
        value = clamp(value + (step > 0 and step or 1), minv, maxv)
        if step > 0 then value = snap_step(value, step) end
        changed = true
      end
    elseif hovC then
      st.active, st.focused = true, true
      st.dragStartX = mx
      st.dragStartV = value

      local cb = clay.getElementData(centerId)
      if cb.found and cb.width > 0 then
        local pos = clamp((mx - cb.x - pad) / math.max(1, (cb.width - pad * 2)), 0, 1)
        local v = lerp(minv, maxv, pos)
        if step > 0 then v = snap_step(v, step) end
        if v ~= value then value, changed = v, true end
      end
    else
      st.focused = hoveredRoot
    end

  elseif down and st.lastDown then
    if hovL and handle_repeat(false) then
      value = clamp(value - (step > 0 and step or 1), minv, maxv)
      if step > 0 then value = snap_step(value, step) end
      changed = true
    elseif hovR and handle_repeat(false) then
      value = clamp(value + (step > 0 and step or 1), minv, maxv)
      if step > 0 then value = snap_step(value, step) end
      changed = true
    end

    if st.active then
      local cb = clay.getElementData(centerId)
      if cb.found and cb.width > 0 then
        local pos = clamp((mx - cb.x - pad) / math.max(1, (cb.width - pad * 2)), 0, 1)
        local v = lerp(minv, maxv, pos)
        if step > 0 then v = snap_step(v, step) end
        if v ~= value then value, changed = v, true end
      end
    end

  elseif (not down) and st.lastDown then
    st.active = false
  end

  -- keyboard (when focused)
  if st.focused then
    local shift =
      (glfw.GetKey(device.win, glfw.KEY_LEFT_SHIFT) == glfw.PRESS) or
      (glfw.GetKey(device.win, glfw.KEY_RIGHT_SHIFT) == glfw.PRESS)

    local deltaSmall = (step > 0 and step or (maxv - minv) * 0.01)
    local deltaBig   = pageStep

    if select(1, key_edge(device.win, glfw.KEY_LEFT, _prop_keys)) then
      value = clamp(value - (shift and deltaBig or deltaSmall), minv, maxv)
      if step > 0 then value = snap_step(value, step) end
      changed = true
    end
    if select(1, key_edge(device.win, glfw.KEY_RIGHT, _prop_keys)) then
      value = clamp(value + (shift and deltaBig or deltaSmall), minv, maxv)
      if step > 0 then value = snap_step(value, step) end
      changed = true
    end
    if select(1, key_edge(device.win, glfw.KEY_HOME, _prop_keys)) then
      value, changed = minv, true
    end
    if select(1, key_edge(device.win, glfw.KEY_END, _prop_keys)) then
      value, changed = maxv, true
    end
    if select(1, key_edge(device.win, glfw.KEY_PAGE_DOWN, _prop_keys)) then
      value = clamp(value - deltaBig, minv, maxv)
      if step > 0 then value = snap_step(value, step) end
      changed = true
    end
    if select(1, key_edge(device.win, glfw.KEY_PAGE_UP, _prop_keys)) then
      value = clamp(value + deltaBig, minv, maxv)
      if step > 0 then value = snap_step(value, step) end
      changed = true
    end
  end

  st.lastDown = down

  -- final clamp & snap
  value = clamp(value, minv, maxv)
  if step > 0 then value = snap_step(value, step) end

  return value, changed, st.focused
end
