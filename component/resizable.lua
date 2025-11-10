-- component/resizer.lua
local glfw = require("ffi.ffi_glfw")

local _resz_state = _resz_state or {} -- keyed by parent id[1]

-- resizable(parent_id, width, height, opts) -> newW, newH, changed, active
-- opts = {
--   minW=64, minH=32, maxW=nil, maxH=nil,
--   grip=16, inset=2, zIndex=10000,
--   snapW=0, snapH=0,         -- snap to grid if > 0
--   showGrip=false,           -- draw tiny visual
--   gripColor={r=255,g=255,b=255,a=48},
-- }
function resizable(parent_id, width, height, opts)
    opts = opts or {}
    local minW = opts.minW or 64
    local minH = opts.minH or 32
    local maxW = opts.maxW
    local maxH = opts.maxH
    local grip = opts.grip or 16
    local inset = opts.inset or 2
    local zIndex = opts.zIndex or 10000
    local snapW = opts.snapW or 0
    local snapH = opts.snapH or 0
    local showGrip = opts.showGrip == true
    local gripColor = opts.gripColor or {r = 255, g = 255, b = 255, a = 48}
    local glyph = opts.gripGlyph or "◢" -- U+25E2
    local glyphScale = opts.glyphScale or 0.9
    local glyphColor = opts.glyphColor or {r = 255, g = 255, b = 255, a = 90}

    local function clamp(x, a, b)
        if a and x < a then
            x = a
        end
        if b and x > b then
            x = b
        end
        return x
    end
    local function snap(v, s)
        if not s or s == 0 then
            return v
        end
        return math.floor(v / s + 0.5) * s
    end

    -- hit target (floating child attached to parent's bottom-right)
    local gripId = clay.id("resizer-grip", parent_id.id)
    clay.createElement(
        gripId,
        {
            floating = {
                parentId = parent_id.id,
                attachTo = clay.ATTACH_TO_ELEMENT_WITH_ID,
                attachPoints = {element = clay.ATTACH_POINT_RIGHT_BOTTOM, parent = clay.ATTACH_POINT_RIGHT_BOTTOM},
                -- keep the hit area inset so it stays inside the parent
                offset = {x = 0, y = 0},
                zIndex = zIndex,
                clipTo = clay.CLIP_TO_ATTACHED_PARENT,
                pointerCaptureMode = POINTER_CAPTURE_MODE_CAPTURE
            },
            layout = {
                sizing = {width = clay.sizingFixed(grip), height = clay.sizingFixed(grip)},
                childAlignment = {x = clay.ALIGN_X_RIGHT, y = clay.ALIGN_Y_CENTER}
            }
        },
        function()
            if showGrip then
                -- Size the glyph to fit the square “grip” nicely
                local fs = math.max(8, math.floor(grip * glyphScale))
                clay.createTextElement(
                    glyph,
                    {
                        fontId = 0,
                        fontSize = fs,
                        textColor = glyphColor
                    }
                )
            end
        end
    )

    -- mouse input
    glfw.GetCursorPos(device.win, mouse_x, mouse_y)
    local mx, my = mouse_x[0], mouse_y[0]
    local down = (glfw.GetMouseButton(device.win, glfw.MOUSE_BUTTON_LEFT) == glfw.PRESS)

    local st = _resz_state[parent_id.id]
    if not st then
        st = {active = false, lastDown = false, sx = 0, sy = 0, sw = width, sh = height}
        _resz_state[parent_id.id] = st
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
        local w = clamp(st.sw + dx, minW, maxW)
        local h = clamp(st.sh + dy, minH, maxH)
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
