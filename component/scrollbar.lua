local glfw = require("ffi.ffi_glfw")

_state = _state or {}

-- scrollbar(viewport_id, content_id, wheel, opts)
-- opts:
--   horizontal, trackW=10, minThumb=24, wheelStep=40, zIndex=1000
--   colorTrack, colorThumb, wheelX
function scrollbar(viewport_id, content_id, wheel, opts)
    -- mouse
    glfw.GetCursorPos(device.win, mouse_x, mouse_y)
    local mx, my = mouse_x[0], mouse_y[0]
    local down = glfw.GetMouseButton(device.win, glfw.MOUSE_BUTTON_LEFT) == glfw.PRESS

    -- opts
    local H = (opts and opts.horizontal) == true
    local trackW = (opts and opts.trackW) or 10
    local minThumbOpt = (opts and opts.minThumb) or 24
    local wheelStep = (opts and opts.wheelStep) or 40
    local zIndex = (opts and opts.zIndex) or 1000
    local colorTrack = opts and opts.colorTrack
    local colorThumb = opts and opts.colorThumb
    local wheelUse = H and ((opts and opts.wheelX) or wheel) or wheel

    -- element boxes (for track placement)
    local viewBox = clay.getElementData(viewport_id)
    local contentBox = clay.getElementData(content_id)
    if not (viewBox.found and contentBox.found) then
        return
    end
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
        -- fallback to element boxes if needed
        viewLen = H and viewW or viewH
        contentLen = H and contentBox.width or contentBox.height
    end

    local maxScroll = math.max(0, contentLen - viewLen) -- no hacks needed
    if maxScroll <= 0.5 then
        return
    end

    -- current absolute scroll (0..maxScroll)
    local function read_abs()
        local s = scd or clay.getScrollContainerData(viewport_id)
        if s and s.found and s.scrollPosition then
            local spx, spy = s.scrollPosition.x or 0, s.scrollPosition.y or 0
            return H and math.max(0, -spx) or math.max(0, -spy)
        end
        -- very old fallback
        return H and math.max(0, math.min(maxScroll, -(contentBox.x or 0))) or
            math.max(0, math.min(maxScroll, -(contentBox.y or 0)))
    end

    -- thumb sizing (proportional, clamped)
    local thumbLen = math.max(minThumbOpt, (viewLen * viewLen) / math.max(1, contentLen))
    local trackLen = viewLen
    local effLen = math.max(1, trackLen - thumbLen)

    -- mapping helpers: abs (0..maxScroll) ↔ thumbPos (0..effLen)
    local function abs_to_thumbPos(abs_)
        if maxScroll <= 0 then
            return 0
        end
        return (math.max(0, math.min(maxScroll, abs_)) / maxScroll) * effLen
    end
    local function thumbPos_to_abs(tp)
        if effLen <= 0 then
            return 0
        end
        return (math.max(0, math.min(effLen, tp)) / effLen) * maxScroll
    end

    local abs = read_abs()
    local thumbPos = abs_to_thumbPos(abs)

    -- track rect (window space)
    local trackX, trackY, trackWpx, trackHpx
    if H then
        trackX, trackY = viewX, (viewY + viewH - trackW - 4)
        trackWpx, trackHpx = viewW, trackW
    else
        trackX, trackY = (viewX + viewW - trackW - 4), viewY
        trackWpx, trackHpx = trackW, viewH
    end
    local overTrack = (mx >= trackX and mx <= trackX + trackWpx and my >= trackY and my <= trackY + trackHpx)

    -- per-viewport+axis state
    local key = viewport_id.id * 2 + (H and 1 or 0)
    local st = _state[key] or {dragging = false, downLast = false, anchor = 0}
    _state[key] = st

    -- thumb rect (window space) for hit-testing
    local thumbWinX, thumbWinY, thumbWinW, thumbWinH
    if H then
        thumbWinX, thumbWinY, thumbWinW, thumbWinH = trackX + thumbPos, trackY, thumbLen, trackHpx
    else
        thumbWinX, thumbWinY, thumbWinW, thumbWinH = trackX, trackY + thumbPos, trackWpx, thumbLen
    end
    local overThumb =
        (mx >= thumbWinX and mx <= thumbWinX + thumbWinW and my >= thumbWinY and my <= thumbWinY + thumbWinH)

    -- start/stop drag with anchored grab point inside the thumb
    if (not st.downLast) and down and overThumb then
        st.dragging = true
        st.anchor = H and (mx - (trackX + thumbPos)) or (my - (trackY + thumbPos)) -- 0..thumbLen
        if st.anchor < 0 then
            st.anchor = 0
        end
        if st.anchor > thumbLen then
            st.anchor = thumbLen
        end
    elseif st.dragging and (not down) and st.downLast then
        st.dragging = false
        -- snap to container's exact max if we basically reached the end
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
            -- read back authoritative value
            local s2 = clay.getScrollContainerData(viewport_id)
            local ax = (s2 and s2.scrollPosition and -(s2.scrollPosition.x or 0)) or 0
            local ay = (s2 and s2.scrollPosition and -(s2.scrollPosition.y or 0)) or 0
            abs = H and math.max(0, ax) or math.max(0, ay)
            thumbPos = abs_to_thumbPos(abs)
        end
    end
    st.downLast = down

    -- DRAG UPDATE: let Clay clamp, then read back
    if st.dragging then
        local cur = H and mx or my
        local start = H and trackX or trackY
        local newPos = (cur - start) - (st.anchor or 0)
        if newPos < 0 then
            newPos = 0
        end
        if newPos > effLen then
            newPos = effLen
        end

        -- convert thumb → desired abs (no pre-clamp)
        local desiredAbs = thumbPos_to_abs(newPos)

        -- push to Clay; Clay clamps using its inner viewport (padding etc.)
        local s0 = clay.getScrollContainerData(viewport_id)
        local curAbsX = (s0 and s0.scrollPosition and math.max(0, -(s0.scrollPosition.x or 0))) or 0
        local curAbsY = (s0 and s0.scrollPosition and math.max(0, -(s0.scrollPosition.y or 0))) or 0
        if H then
            clay.setScrollContainerPosition(viewport_id, -desiredAbs, -curAbsY)
        else
            clay.setScrollContainerPosition(viewport_id, -curAbsX, -desiredAbs)
        end

        -- read back Clay’s clamped value so our thumb matches exactly
        local s1 = clay.getScrollContainerData(viewport_id)
        local ax = (s1 and s1.scrollPosition and -(s1.scrollPosition.x or 0)) or 0
        local ay = (s1 and s1.scrollPosition and -(s1.scrollPosition.y or 0)) or 0
        abs = H and math.max(0, ax) or math.max(0, ay)
        thumbPos = abs_to_thumbPos(abs)

        device.scrolling_override = true
    else
        device.scrolling_override = false
    end

    -- Wheel when over the track (use Clay clamp + readback too)
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

    -- ids per axis so they don't clash
    local scroll_id = clay.id("ScrollBarTrack", key)
    local thumb_id = clay.id("ScrollBarThumb", key)

    -- draw floating track with spacer-thumb
    clay.createElement(
        scroll_id,
        {
            floating = {
                attachTo = clay.ATTACH_TO_ROOT,
                attachPoints = {element = clay.ATTACH_POINT_LEFT_TOP, parent = clay.ATTACH_POINT_LEFT_TOP},
                offset = {x = trackX, y = trackY},
                zIndex = zIndex,
                pointerCaptureMode = clay.POINTER_CAPTURE_MODE_CAPTURE,
                clipTo = clay.CLIP_TO_NONE
            },
            layout = H and
                {
                    layoutDirection = clay.LEFT_TO_RIGHT,
                    sizing = {width = clay.sizingFixed(viewW), height = clay.sizingFixed(trackW)},
                    childGap = 0
                } or
                {
                    layoutDirection = clay.TOP_TO_BOTTOM,
                    sizing = {width = clay.sizingFixed(trackW), height = clay.sizingFixed(viewH)},
                    childGap = 0
                },
            backgroundColor = colorTrack or
                {r = 80, g = 80, b = 80, a = (overTrack or (_state[key] and _state[key].dragging)) and 80 or 64}
        },
        function()
            if H then
                clay.createElement(
                    clay.id("SBLeftSpacer", key),
                    {
                        layout = {
                            sizing = {width = clay.sizingFixed(math.floor(thumbPos + 0.5)), height = clay.sizingGrow()}
                        }
                    }
                )
                clay.createElement(
                    thumb_id,
                    {
                        layout = {
                            sizing = {width = clay.sizingFixed(math.floor(thumbLen + 0.5)), height = clay.sizingGrow()}
                        },
                        backgroundColor = colorThumb or
                            (_state[key].dragging and {r = 200, g = 200, b = 200, a = 200} or
                                {r = 180, g = 180, b = 180, a = 140}),
                        border = {
                            color = {r = 255, g = 255, b = 255, a = 64},
                            width = {left = 1, right = 1, top = 1, bottom = 1}
                        }
                    }
                )
                clay.createElement(
                    clay.id("SBRightSpacer", key),
                    {layout = {sizing = {width = clay.sizingGrow(), height = clay.sizingGrow()}}}
                )
            else
                clay.createElement(
                    clay.id("SBTopSpacer", key),
                    {
                        layout = {
                            sizing = {width = clay.sizingGrow(), height = clay.sizingFixed(math.floor(thumbPos + 0.5))}
                        }
                    }
                )
                clay.createElement(
                    thumb_id,
                    {
                        layout = {
                            sizing = {width = clay.sizingGrow(), height = clay.sizingFixed(math.floor(thumbLen + 0.5))}
                        },
                        backgroundColor = colorThumb or
                            (_state[key].dragging and {r = 200, g = 200, b = 200, a = 200} or
                                {r = 180, g = 180, b = 180, a = 140}),
                        border = {
                            color = {r = 255, g = 255, b = 255, a = 64},
                            width = {left = 1, right = 1, top = 1, bottom = 1}
                        }
                    }
                )
                clay.createElement(
                    clay.id("SBBotSpacer", key),
                    {layout = {sizing = {width = clay.sizingGrow(), height = clay.sizingGrow()}}}
                )
            end
        end
    )
end
