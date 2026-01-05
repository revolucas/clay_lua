-- component/scrollbar.lua (new builder API + no per-call default table churn)
local glfw = require("ffi.ffi_glfw")

_state = _state or {}

local function C(c) return c.r, c.g, c.b, c.a end

-- defaults (allocated once)
local SB_DEFAULT = {
  horizontal = false,
  trackW     = 10,
  minThumb   = 24,
  wheelStep  = 40,
  zIndex     = 1000,
  wheelX     = false,

  -- colors (tables allocated once)
  colorTrackBase = { r=80,  g=80,  b=80,  a=64  },
  colorTrackHot  = { r=80,  g=80,  b=80,  a=80  },
  thumbBase      = { r=180, g=180, b=180, a=140 },
  thumbDrag      = { r=200, g=200, b=200, a=200 },
  thumbBorder    = { r=255, g=255, b=255, a=64  },

  -- layout tweak
  margin = 4, -- matches your old "- 4"
}

-- scratch ids to reduce string churn
local function id_track(key) return clay.id("ScrollBarTrack", key, true) end
local function id_thumb(key) return clay.id("ScrollBarThumb", key, true) end
local function id_sp0(key)    return clay.id("SBSpacer0", key, true) end
local function id_sp1(key)    return clay.id("SBSpacer1", key, true) end

-- reusable rect check
local function in_rect(mx, my, x, y, w, h)
  return (mx >= x and mx <= x + w and my >= y and my <= y + h)
end

-- scrollbar(viewport_id, content_id, wheel, opts)
-- opts:
--   horizontal, trackW, minThumb, wheelStep, zIndex, wheelX
--   colorTrack, colorThumb
function scrollbar(viewport_id, content_id, wheel, opts)
  -- mouse
  glfw.GetCursorPos(device.win, mouse_x, mouse_y)
  local mx, my = mouse_x[0], mouse_y[0]
  local down = (glfw.GetMouseButton(device.win, glfw.MOUSE_BUTTON_LEFT) == glfw.PRESS)

  -- opts (no new default tables)
  local def = SB_DEFAULT
  local H = ((opts and opts.horizontal) or def.horizontal) == true
  local trackW = (opts and opts.trackW) or def.trackW
  local minThumbOpt = (opts and opts.minThumb) or def.minThumb
  local wheelStep = (opts and opts.wheelStep) or def.wheelStep
  local zIndex = (opts and opts.zIndex) or def.zIndex
  local wheelUse = H and (((opts and opts.wheelX) or def.wheelX) and wheel or wheel) or wheel

  local colorTrack = opts and opts.colorTrack -- optional override (table)
  local colorThumb = opts and opts.colorThumb -- optional override (table)

  -- element boxes (for track placement)
  local viewBox = clay.getElementData(viewport_id)
  local contentBox = clay.getElementData(content_id)
  if not (viewBox.found and contentBox.found) then return end

  local viewX, viewY, viewW, viewH = viewBox.x, viewBox.y, viewBox.width, viewBox.height

  -- AUTHORITATIVE sizes from Clay
  local scd = clay.getScrollContainerData(viewport_id)
  local viewLen, contentLen
  if scd and scd.found then
    if H then
      viewLen = scd.scrollContainerDimensions.width or viewW
      contentLen = scd.contentDimensions.width or contentBox.width
    else
      viewLen = scd.scrollContainerDimensions.height or viewH
      contentLen = scd.contentDimensions.height or contentBox.height
    end
  else
    viewLen = H and viewW or viewH
    contentLen = H and contentBox.width or contentBox.height
  end

  local maxScroll = math.max(0, contentLen - viewLen)
  if maxScroll <= 0.5 then return end

  -- read absolute scroll 0..maxScroll
  local function read_abs()
    local s = scd or clay.getScrollContainerData(viewport_id)
    if s and s.found and s.scrollPosition then
      local spx, spy = s.scrollPosition.x or 0, s.scrollPosition.y or 0
      return H and math.max(0, -spx) or math.max(0, -spy)
    end
    return H and math.max(0, math.min(maxScroll, -(contentBox.x or 0))) or
               math.max(0, math.min(maxScroll, -(contentBox.y or 0)))
  end

  -- thumb sizing
  local thumbLen = math.max(minThumbOpt, (viewLen * viewLen) / math.max(1, contentLen))
  local trackLen = viewLen
  local effLen = math.max(1, trackLen - thumbLen)

  local function abs_to_thumbPos(abs_)
    return (math.max(0, math.min(maxScroll, abs_)) / maxScroll) * effLen
  end
  local function thumbPos_to_abs(tp)
    return (math.max(0, math.min(effLen, tp)) / effLen) * maxScroll
  end

  local abs = read_abs()
  local thumbPos = abs_to_thumbPos(abs)

  -- track rect in window space
  local margin = def.margin
  local trackX, trackY, trackWpx, trackHpx
  if H then
    trackX, trackY = viewX, (viewY + viewH - trackW - margin)
    trackWpx, trackHpx = viewW, trackW
  else
    trackX, trackY = (viewX + viewW - trackW - margin), viewY
    trackWpx, trackHpx = trackW, viewH
  end

  local overTrack = in_rect(mx, my, trackX, trackY, trackWpx, trackHpx)

  -- per-viewport+axis state
  local key = viewport_id.id * 2 + (H and 1 or 0)
  local st = _state[key]
  if not st then
    st = { dragging=false, downLast=false, anchor=0 }
    _state[key] = st
  end

  -- thumb rect (window space)
  local thumbWinX, thumbWinY, thumbWinW, thumbWinH
  if H then
    thumbWinX, thumbWinY, thumbWinW, thumbWinH = trackX + thumbPos, trackY, thumbLen, trackHpx
  else
    thumbWinX, thumbWinY, thumbWinW, thumbWinH = trackX, trackY + thumbPos, trackWpx, thumbLen
  end
  local overThumb = in_rect(mx, my, thumbWinX, thumbWinY, thumbWinW, thumbWinH)

  -- start/stop drag
  if (not st.downLast) and down and overThumb then
    st.dragging = true
    st.anchor = H and (mx - (trackX + thumbPos)) or (my - (trackY + thumbPos))
    if st.anchor < 0 then st.anchor = 0 end
    if st.anchor > thumbLen then st.anchor = thumbLen end

  elseif st.dragging and (not down) and st.downLast then
    st.dragging = false

    -- snap to exact max if basically at end
    abs = read_abs()
    if (maxScroll - abs) <= 1.0 then
      local s = clay.getScrollContainerData(viewport_id)
      local curAbsX = (s and s.scrollPosition and math.max(0, -(s.scrollPosition.x or 0))) or 0
      local curAbsY = (s and s.scrollPosition and math.max(0, -(s.scrollPosition.y or 0))) or 0
      if H then
        clay.setScrollContainerPosition(viewport_id, -maxScroll, -curAbsY)
      else
        clay.setScrollContainerPosition(viewport_id, -curAbsX, -maxScroll)
      end
      local s2 = clay.getScrollContainerData(viewport_id)
      local ax = (s2 and s2.scrollPosition and -(s2.scrollPosition.x or 0)) or 0
      local ay = (s2 and s2.scrollPosition and -(s2.scrollPosition.y or 0)) or 0
      abs = H and math.max(0, ax) or math.max(0, ay)
      thumbPos = abs_to_thumbPos(abs)
    end
  end
  st.downLast = down

  -- DRAG UPDATE (Clay clamps, then read back)
  if st.dragging then
    local cur = H and mx or my
    local start = H and trackX or trackY
    local newPos = (cur - start) - (st.anchor or 0)
    if newPos < 0 then newPos = 0 end
    if newPos > effLen then newPos = effLen end

    local desiredAbs = thumbPos_to_abs(newPos)

    local s0 = clay.getScrollContainerData(viewport_id)
    local curAbsX = (s0 and s0.scrollPosition and math.max(0, -(s0.scrollPosition.x or 0))) or 0
    local curAbsY = (s0 and s0.scrollPosition and math.max(0, -(s0.scrollPosition.y or 0))) or 0
    if H then
      clay.setScrollContainerPosition(viewport_id, -desiredAbs, -curAbsY)
    else
      clay.setScrollContainerPosition(viewport_id, -curAbsX, -desiredAbs)
    end

    local s1 = clay.getScrollContainerData(viewport_id)
    local ax = (s1 and s1.scrollPosition and -(s1.scrollPosition.x or 0)) or 0
    local ay = (s1 and s1.scrollPosition and -(s1.scrollPosition.y or 0)) or 0
    abs = H and math.max(0, ax) or math.max(0, ay)
    thumbPos = abs_to_thumbPos(abs)

    device.scrolling_override = true
  else
    device.scrolling_override = false
  end

  -- wheel over track
  if wheelUse ~= 0 and overTrack then
    local targetAbs = math.max(0, math.min(maxScroll, abs - wheelUse * wheelStep))
    local s0 = clay.getScrollContainerData(viewport_id)
    local curAbsX = (s0 and s0.scrollPosition and math.max(0, -(s0.scrollPosition.x or 0))) or 0
    local curAbsY = (s0 and s0.scrollPosition and math.max(0, -(s0.scrollPosition.y or 0))) or 0
    if H then
      clay.setScrollContainerPosition(viewport_id, -targetAbs, -curAbsY)
    else
      clay.setScrollContainerPosition(viewport_id, -curAbsX, -targetAbs)
    end
    local s1 = clay.getScrollContainerData(viewport_id)
    local ax = (s1 and s1.scrollPosition and -(s1.scrollPosition.x or 0)) or 0
    local ay = (s1 and s1.scrollPosition and -(s1.scrollPosition.y or 0)) or 0
    abs = H and math.max(0, ax) or math.max(0, ay)
    thumbPos = abs_to_thumbPos(abs)
  end

  -- ids
  local scroll_id = id_track(key)
  local thumb_id  = id_thumb(key)
  local sp0_id    = id_sp0(key)
  local sp1_id    = id_sp1(key)

  -- colors (avoid allocating hover variants)
  local trackCol =
    colorTrack or ((overTrack or st.dragging) and def.colorTrackHot or def.colorTrackBase)
  local thumbCol =
    colorThumb or (st.dragging and def.thumbDrag or def.thumbBase)

  -- draw attached-to-root track using builder attach chain
  clay.element(scroll_id)
    :parentId(0) -- root
    :attachTo(clay.ATTACH_TO_ROOT)
    :attachPoints(clay.ATTACH_POINT_LEFT_TOP, clay.ATTACH_POINT_LEFT_TOP)
    :offset(trackX, trackY)
    :zIndex(zIndex)
    :pointerCaptureMode(clay.POINTER_CAPTURE_MODE_CAPTURE)
    :clipTo(clay.CLIP_TO_NONE)
    :layoutDirection(H and clay.LEFT_TO_RIGHT or clay.TOP_TO_BOTTOM)
    :width(clay.SIZING_FIXED, H and viewW or trackW)
    :height(clay.SIZING_FIXED, H and trackW or viewH)
    :childGap(0)
    :backgroundColor(C(trackCol))
    :children(function()
      local lead = math.floor(thumbPos + 0.5)
      local tlen = math.floor(thumbLen + 0.5)

      if H then
        clay.element(sp0_id)
          :width(clay.SIZING_FIXED, lead)
          :height(clay.SIZING_GROW)
          :close()

        clay.element(thumb_id)
          :width(clay.SIZING_FIXED, tlen)
          :height(clay.SIZING_GROW)
          :backgroundColor(C(thumbCol))
          :borderColor(C(def.thumbBorder))
          :borderWidth(1)
          :close()

        clay.element(sp1_id)
          :width(clay.SIZING_GROW)
          :height(clay.SIZING_GROW)
          :close()
      else
        clay.element(sp0_id)
          :width(clay.SIZING_GROW)
          :height(clay.SIZING_FIXED, lead)
          :close()

        clay.element(thumb_id)
          :width(clay.SIZING_GROW)
          :height(clay.SIZING_FIXED, tlen)
          :backgroundColor(C(thumbCol))
          :borderColor(C(def.thumbBorder))
          :borderWidth(1)
          :close()

        clay.element(sp1_id)
          :width(clay.SIZING_GROW)
          :height(clay.SIZING_GROW)
          :close()
      end
    end)
end
