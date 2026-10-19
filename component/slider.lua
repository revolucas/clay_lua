-- component/slider.lua (new builder API + no per-call default table churn)
local window = require("window")
local theme = require("theme")

local _slider_state = _slider_state or {} -- [id] -> { active, focused, lastDown }
local _slider_keys  = _slider_keys  or {} -- key edge table

local function C(c) return c.r, c.g, c.b, c.a end

-- defaults (allocated once)
local SLIDER_DEFAULT = {
  min = 0,
  max = 1,
  step = 0,
  pageStep = nil, -- computed if nil
  disabled = false,

  trackThickness = nil,       -- computed from height if nil
  thumbThickness = nil,       -- computed from height if nil

}

local function clamp(x,a,b) if x<a then return a elseif x>b then return b else return x end end
local function lerp(a,b,t) return a + (b-a)*t end
local function unlerp(a,b,x) return (b==a) and 0 or (x-a)/(b-a) end
local function snap_step(x, step)
  if not step or step == 0 then return x end
  return math.floor(x/step + 0.5) * step
end

local function key_edge(win, key, keyTable)
  local cur  = (window.keyDown(key))
  local last = keyTable[key] or false
  keyTable[key] = cur
  return (cur and not last), cur
end

function slider(elid, value, opts)
  local def = SLIDER_DEFAULT
  local dcol = theme.colors.slider
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

  local componentDefaults = theme.defaults.slider
  local width  = (opts and opts.width)  or componentDefaults.width
  local height = (opts and opts.height) or componentDefaults.height
  local pad    = (opts and opts.pad)    or componentDefaults.padding
  local disabled = ((opts and opts.disabled) or def.disabled) == true

  local trackThickness = (opts and opts.trackThickness) or def.trackThickness
  if not trackThickness then trackThickness = math.max(6, math.floor(height * 0.30)) end
  local thumbThickness = (opts and opts.thumbThickness) or def.thumbThickness
  if not thumbThickness then thumbThickness = math.max(6, math.floor(height * 0.60)) end
  local thumbCornerRad = (opts and opts.thumbCornerRadius) or theme.radius.control

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
  local mx, my = window.mousePosition()
  local down = (window.mouseButtonDown(window.MOUSE_BUTTON_LEFT))
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
        (window.keyDown(window.KEY_LEFT_SHIFT)) or
        (window.keyDown(window.KEY_RIGHT_SHIFT))

      local deltaSmall = (step > 0 and step or (maxv - minv) * 0.01)
      local deltaBig = pageStep

      if select(1, key_edge(device.win, window.KEY_RIGHT, _slider_keys)) then
        value = clamp(value + (shift and deltaBig or deltaSmall), minv, maxv)
        changed = true
      end
      if select(1, key_edge(device.win, window.KEY_LEFT, _slider_keys)) then
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
