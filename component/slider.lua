-- component/slider.lua (new builder API + no per-call default table churn)
local glfw = require("ffi.ffi_glfw")

local _slider_state = _slider_state or {} -- [id] -> { active, focused, lastDown }
local _slider_keys  = _slider_keys  or {} -- key edge table

local function C(c) return c.r, c.g, c.b, c.a end

-- defaults (allocated once)
local SLIDER_DEFAULT = {
  min = 0,
  max = 1,
  step = 0,
  pageStep = nil, -- computed if nil
  width = 200,
  height = 24,
  pad = 0,
  disabled = false,

  trackThickness = nil,       -- computed from height if nil
  thumbThickness = nil,       -- computed from height if nil
  thumbCornerRadius = 8,

  colors = {
    bg       = { r=30,  g=30,  b=35,  a=0   },
    bgHov    = { r=40,  g=40,  b=48,  a=0   },
    bgAct    = { r=55,  g=55,  b=65,  a=0   },
    bgborder = { r=255, g=255, b=255, a=0   },
    border   = { r=255, g=255, b=255, a=50  },
    track    = { r=90,  g=90,  b=100, a=140 },
    thumb    = { r=120, g=170, b=255, a=255 },
    fill     = { r=120, g=170, b=255, a=180 },
    disable  = { r=120, g=120, b=120, a=90  },
  }
}

local function clamp(x,a,b) if x<a then return a elseif x>b then return b else return x end end
local function lerp(a,b,t) return a + (b-a)*t end
local function unlerp(a,b,x) return (b==a) and 0 or (x-a)/(b-a) end
local function snap_step(x, step)
  if not step or step == 0 then return x end
  return math.floor(x/step + 0.5) * step
end

local function key_edge(win, key, keyTable)
  local cur  = (glfw.GetKey(win, key) == glfw.PRESS)
  local last = keyTable[key] or false
  keyTable[key] = cur
  return (cur and not last), cur
end

function slider(elid, value, opts)
  local def = SLIDER_DEFAULT
  local dcol = def.colors
  local col = opts and opts.colors

  -- opts
  local minv = (opts and opts.min) or def.min
  local maxv = (opts and opts.max) or def.max
  if maxv == minv then maxv = minv + 1 end

  local step = (opts and opts.step) or def.step
  local pageStep = (opts and (opts.pageStep ~= nil) and opts.pageStep) or def.pageStep
  if pageStep == nil then
    pageStep = (step > 0 and step * 10 or (maxv - minv) * 0.1)
  end

  local width  = (opts and opts.width)  or def.width
  local height = (opts and opts.height) or def.height
  local pad    = (opts and opts.pad)    or def.pad
  local disabled = ((opts and opts.disabled) or def.disabled) == true

  local trackThickness = (opts and opts.trackThickness) or def.trackThickness
  if not trackThickness then trackThickness = math.max(6, math.floor(height * 0.30)) end
  local thumbThickness = (opts and opts.thumbThickness) or def.thumbThickness
  if not thumbThickness then thumbThickness = math.max(6, math.floor(height * 0.60)) end
  local thumbCornerRad = (opts and opts.thumbCornerRadius) or def.thumbCornerRadius

  local c_bg      = (col and col.bg)      or dcol.bg
  local c_bgHov   = (col and col.bgHov)   or dcol.bgHov
  local c_bgAct   = (col and col.bgAct)   or dcol.bgAct
  local c_bgborder= (col and col.bgborder)or dcol.bgborder
  local c_border  = (col and col.border)  or dcol.border
  local c_track   = (col and col.track)   or dcol.track
  local c_thumb   = (col and col.thumb)   or dcol.thumb
  local c_fill    = (col and col.fill)    or dcol.fill
  local c_disable = (col and col.disable) or dcol.disable

  -- state
  local key = elid.id
  local st = _slider_state[key]
  if not st then
    st = { active=false, focused=false, lastDown=false }
    _slider_state[key] = st
  end

  -- stable ids
  local railId  = clay.id("rail",  key, true)
  local trkId   = clay.id("trk",   key, true)
  local fillId  = clay.id("fill",  key, true)
  local spLId   = clay.id("spacer-left", key, true)
  local thumbId = clay.id("thumb", key, true)

  -- normalize value -> n in [0,1]
  local n = clamp(unlerp(minv, maxv, value), 0, 1)
  if step and step > 0 then
    local snapped = snap_step(lerp(minv, maxv, n), step)
    n = clamp(unlerp(minv, maxv, snapped), 0, 1)
    value = lerp(minv, maxv, n)
  end

  -- input
  glfw.GetCursorPos(device.win, mouse_x, mouse_y)
  local mx, my = mouse_x[0], mouse_y[0]
  local down = (glfw.GetMouseButton(device.win, glfw.MOUSE_BUTTON_LEFT) == glfw.PRESS)
  local hovered = clay.pointerOver(elid)

  local changed = false

  -- mouse interactions (uses trk box)
  if not disabled then
    if (not st.lastDown) and down and hovered then
      st.active, st.focused = true, true
      local tb = clay.getElementData(trkId)
      if tb.found and tb.width and tb.width > 0 then
        local pos = (mx - tb.x) / tb.width
        n = clamp(pos, 0, 1)
        value = lerp(minv, maxv, n)
        if step > 0 then
          value = snap_step(value, step)
          n = clamp(unlerp(minv, maxv, value), 0, 1)
        end
        changed = true
      end

    elseif st.active and down then
      local tb = clay.getElementData(trkId)
      if tb.found and tb.width and tb.width > 0 then
        local pos = clamp((mx - tb.x) / tb.width, 0, 1)
        if pos ~= n then
          n = pos
          value = lerp(minv, maxv, n)
          if step > 0 then
            value = snap_step(value, step)
            n = clamp(unlerp(minv, maxv, value), 0, 1)
          end
          changed = true
        end
      end

    elseif st.active and (not down) then
      st.active = false
    end

    -- keyboard nudges
    if st.focused then
      local shift =
        (glfw.GetKey(device.win, glfw.KEY_LEFT_SHIFT) == glfw.PRESS) or
        (glfw.GetKey(device.win, glfw.KEY_RIGHT_SHIFT) == glfw.PRESS)

      local deltaSmall = (step > 0 and step or (maxv - minv) * 0.01)
      local deltaBig = pageStep

      if select(1, key_edge(device.win, glfw.KEY_RIGHT, _slider_keys)) then
        value = clamp(value + (shift and deltaBig or deltaSmall), minv, maxv)
        changed = true
      end
      if select(1, key_edge(device.win, glfw.KEY_LEFT, _slider_keys)) then
        value = clamp(value - (shift and deltaBig or deltaSmall), minv, maxv)
        changed = true
      end

      if changed then
        if step > 0 then value = snap_step(value, step) end
        n = clamp(unlerp(minv, maxv, value), 0, 1)
      end
    end
  end

  st.lastDown = down
  local active = st.active

  -- visuals
  local innerW = width  - pad * 2
  local innerH = height - pad * 2

  local bgCol = disabled and c_bg or (active and c_bgAct or (hovered and c_bgHov or c_bg))
  local trackCol = disabled and c_disable or c_track
  local fillCol  = disabled and c_disable or c_fill
  local thumbCol = disabled and c_disable or c_thumb

  local fillW = math.floor(innerW * n + 0.5)
  local padThumb = fillW - thumbThickness / 2

  clay.element(elid)
    :layoutDirection(clay.LEFT_TO_RIGHT)
    :childAlignment(clay.ALIGN_X_LEFT, clay.ALIGN_Y_CENTER)
    :width(clay.SIZING_FIXED, width)
    :height(clay.SIZING_FIXED, height)
    :padding(pad)
    :childGap(0)
    :backgroundColor(C(bgCol))
    :borderColor(C(c_bgborder))
    :borderWidth(1)
    :children(function()
      clay.element(railId)
        :layoutDirection(clay.LEFT_TO_RIGHT)
        :childAlignment(clay.ALIGN_X_LEFT, clay.ALIGN_Y_CENTER)
        :width(clay.SIZING_FIXED, innerW)
        :height(clay.SIZING_FIXED, innerH)
        :childGap(0)
        :children(function()
          clay.element(trkId)
            :width(clay.SIZING_FIXED, innerW)
            :height(clay.SIZING_FIXED, trackThickness)
            :backgroundColor(C(trackCol))
            :children(function()
              clay.element(fillId)
                :layoutDirection(clay.LEFT_TO_RIGHT)
                :childAlignment(clay.ALIGN_X_LEFT, clay.ALIGN_Y_CENTER)
                :width(clay.SIZING_FIXED, fillW)
                :height(clay.SIZING_FIXED, trackThickness)
                :backgroundColor(C(fillCol))
                :children(function()
                  clay.element(spLId)
                    :width(clay.SIZING_FIXED, padThumb)
                    :height(clay.SIZING_FIXED, trackThickness)
                    :close()

                  clay.element(thumbId)
                    :width(clay.SIZING_FIXED, thumbThickness)
                    :height(clay.SIZING_FIXED, thumbThickness)
                    :backgroundColor(C(thumbCol))
                    :borderColor(C(c_border))
                    :borderWidth(1)
                    :cornerRadius(thumbCornerRad, thumbCornerRad, thumbCornerRad, thumbCornerRad)
                    :close()
                end)
            end)
        end)
    end)

  return value, changed, active
end
