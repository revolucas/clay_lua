local js = require("js")
local C = js.global.clayLuaCanvas2D
local M = {}

-- lua-interop wraps JavaScript functions as callable objects and consumes the
-- first Lua call argument as `this`. Use method-call syntax even though these
-- JavaScript callbacks are arrows, so every renderer argument reaches them.

local function number(value, fallback)
    return tonumber(value) or fallback or 0
end

function M.beginFrame(width, height, pixelRatio)
    C:beginFrame(width, height, pixelRatio)
end

function M.fillRect(x, y, w, h, r, g, b, a, tl, tr, bl, br)
    C:fillRect(x, y, w, h, r, g, b, a, tl or 0, tr or 0, bl or 0, br or 0)
end

function M.strokeRect(x, y, w, h, r, g, b, a, tl, tr, bl, br,
    left, right, top, bottom)
    C:strokeRect(x, y, w, h, r, g, b, a,
        tl or 0, tr or 0, bl or 0, br or 0,
        left or 0, right or 0, top or 0, bottom or 0)
end

function M.pushClip(x, y, w, h)
    C:pushClip(x, y, w, h)
end

function M.popClip()
    C:popClip()
end

local function textMetrics(text, fontId, fontSize, letterSpacing, lineHeight, skipTags)
    fontId = number(fontId, 1)
    fontSize = math.max(1, number(fontSize, 16))
    letterSpacing = number(letterSpacing, 0)
    local width = C:measureText(
        text or "", fontId, fontSize, letterSpacing, skipTags and 1 or 0)
    local height = number(lineHeight, 0)
    if height <= 0 then height = fontSize * 1.25 end
    local lineCount = select(2, tostring(text or ""):gsub("\n", "")) + 1
    height = height * lineCount
    return width, height
end

function M.measureText(text, fontId, fontSize, letterSpacing, lineHeight,
        wrapMode, textAlignment, r, g, b, a)
    if type(fontId) == "table" then
        return M.measureTextConfig(text, fontId, fontSize)
    end
    return textMetrics(text, fontId, fontSize, letterSpacing, lineHeight, false)
end

function M.measureTextConfig(text, config, skipTags)
    config = config or {}
    return textMetrics(text, config.fontId, config.fontSize,
        config.letterSpacing, config.lineHeight, skipTags)
end

function M.drawText(x, y, text, r, g, b, a, fontId, fontSize, letterSpacing, lineHeight)
    if text and text ~= "" then
        C:drawText(text, x, y, r, g, b, a,
            fontId or 1, fontSize or 16, letterSpacing or 0, lineHeight or 0)
    end
end

local function colorArgs(color, fallback)
    color = color or fallback or { r = 255, g = 255, b = 255, a = 255 }
    return number(color.r, 255), number(color.g, 255), number(color.b, 255), number(color.a, 255)
end

local function drawCurve(x, y, edge, zoom)
    if not edge then return end
    local x0, y0, x1, y1 = number(edge.x0), number(edge.y0), number(edge.x1), number(edge.y1)
    local bend = math.max(28 * zoom, math.abs(x1 - x0) * 0.48)
    local direction = x1 >= x0 and 1 or -1
    local c1x, c2x = x0 + bend * direction, x1 - bend * direction
    local r, g, b, a = colorArgs(edge.color)
    C:drawBezier(x, y, x0, y0, c1x, y0, c2x, y1, x1, y1,
        edge.width or 2.2 * zoom, r, g, b, a)
end

local function drawNodeCanvas(x, y, w, h, payload)
    local zoom = number(payload.zoom, 1)
    local step = math.max(12, number(payload.gridSize, 32) * zoom)
    local r, g, b, a = colorArgs(payload.gridColor, { r = 86, g = 103, b = 132, a = 46 })
    C:drawGrid(x, y, w, h, step,
        number(payload.panX) % step, number(payload.panY) % step, r, g, b, a)
    for i = 1, #(payload.wires or {}) do
        drawCurve(x, y, payload.wires[i], zoom)
    end
    drawCurve(x, y, payload.pending, zoom)
    local selection = payload.selectionRect
    if selection then
        r, g, b, a = colorArgs(selection.color)
        local thickness = number(selection.width, 1.5)
        C:strokeRect(x + selection.x, y + selection.y,
            selection.w, selection.h, r, g, b, a, 0, 0, 0, 0,
            thickness, thickness, thickness, thickness)
    end
end

function M.drawCustom(x, y, w, h, payload)
    if type(payload) ~= "table" then return end
    if payload.kind == "clay_node_editor_canvas" then
        drawNodeCanvas(x, y, w, h, payload)
    elseif payload.kind == "clay_canvas2d_color_picker" then
        local kind = payload.part == "sv" and 1 or payload.part == "hue" and 2 or 3
        C:colorPicker(x, y, w, h, kind,
            number(payload.hue), number(payload.saturation), number(payload.value), number(payload.alpha, 1))
    end
end

function M.drawCommands(clay, dt, width, height, pixelRatio)
    M.beginFrame(width, height, pixelRatio)
    local clipDepth = 0
    for command, x, y, w, h, r, g, b, a, tl, tr, bl, br,
        left, right, top, bottom, text, fontId, fontSize, letterSpacing,
        lineHeight, payload, clipHorizontal, clipVertical in clay.endLayoutFast(dt) do
        if command == clay.RENDER_RECTANGLE then
            M.fillRect(x, y, w, h, r, g, b, a, tl, tr, bl, br)
        elseif command == clay.RENDER_BORDER then
            M.strokeRect(x, y, w, h, r, g, b, a, tl, tr, bl, br,
                left, right, top, bottom)
        elseif command == clay.RENDER_TEXT then
            M.drawText(x, y, text, r, g, b, a, fontId, fontSize, letterSpacing, lineHeight)
        elseif command == clay.RENDER_SCISSOR_START then
            if not clipHorizontal then x, w = 0, width end
            if not clipVertical then y, h = 0, height end
            M.pushClip(x, y, w, h)
            clipDepth = clipDepth + 1
        elseif command == clay.RENDER_SCISSOR_END then
            if clipDepth > 0 then
                M.popClip()
                clipDepth = clipDepth - 1
            end
        elseif command == clay.RENDER_CUSTOM then
            M.drawCustom(x, y, w, h, payload)
        elseif command == clay.RENDER_IMAGE then
            -- BGFX texture handles have no meaning to Canvas2D. Browser-only
            -- components should use Canvas2D custom render payloads instead.
        end
    end
    while clipDepth > 0 do
        M.popClip()
        clipDepth = clipDepth - 1
    end
end

return M
