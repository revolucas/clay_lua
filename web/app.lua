package.path = "/?.lua;/?/init.lua;/ffi/?.lua;" .. package.path
package.preload.bit = function() return dofile("/web/bit.lua") end
package.preload.window = function() return dofile("/web/window.lua") end
package.preload.canvas2d = function() return dofile("/web/canvas2d.lua") end
_G.unpack = _G.unpack or table.unpack

local ffi = require("ffi")
local clay = require("clay")
local theme = require("theme")
local bgfx = require("ffi.ffi_bgfx")
local shader_manager = require("shader_manager")
local font_manager = require("font_manager")
local bgfxMeasureText = font_manager.measureText
local bgfxMeasureTextConfig = font_manager.measureTextConfig
local window = require("window")
local canvas2d = require("canvas2d")
local retained_runtime = require("clay_retained")
require("ffi.ffi_math")

theme.syncGlobals()
clay.theme = theme

local device = {
    isWeb = true,
    width = 1,
    height = 1,
    view_id = 0,
    renderer = "bgfx",
    win = {},
    scroll = { x = 0, y = 0 },
}
_G.ffi, _G.clay, _G.theme, _G.bgfx, _G.window, _G.device = ffi, clay, theme, bgfx, window, device
_G.cache = {}

local script_cache = {}
local function loadScript(filename)
    if script_cache[filename] then return script_cache[filename] end
    local file, open_error = io.open(filename, "rb")
    if not file then
        print("[web] could not load " .. filename .. ": " .. tostring(open_error))
        return nil
    end
    local source = file:read("*a")
    file:close()
    local env = setmetatable({}, { __index = _G })
    local chunk, load_error = load(source, "@" .. filename, "t", env)
    if not chunk then
        print("[web] could not compile " .. filename .. ": " .. tostring(load_error))
        return nil
    end
    local ok, result = xpcall(chunk, debug.traceback)
    if not ok then
        print("[web] failed loading " .. filename .. ":\n" .. tostring(result))
        return nil
    end
    script_cache[filename] = env
    print("Loaded script: " .. filename)
    return env
end
_G.loadScript = loadScript

function web_key_event(key, down, repeated, mods)
    window._keyEvent(key, down, repeated, mods)
end

function web_input_codepoint(codepoint)
    window.callback_send("window_set_char", tonumber(codepoint) or 0)
end

function web_set_clipboard_text(text)
    window._setClipboardText(text)
end

function web_release_keys()
    window._releaseAllKeys()
end

local function install_components()
    clay.scrollbar = loadScript("component/scrollbar.lua").scrollbar
    clay.checkbox = loadScript("component/checkbox.lua").checkbox
    clay.radio = loadScript("component/radio.lua").radio
    clay.edit = loadScript("component/edit.lua").edit
    clay.slider = loadScript("component/slider.lua").slider
    clay.property = loadScript("component/property.lua").property
    clay.resizable = loadScript("component/resizable.lua").resizable
    clay.color_picker = loadScript("component/color_picker.lua").color_picker
    clay.dropdown = loadScript("component/dropdown.lua").dropdown
    clay.inspector = loadScript("component/inspector.lua").inspector
    local list = loadScript("component/listview.lua")
    clay.listview, clay.treeview = list.listview, list.treeview
    clay.listview_open, clay.listview_close = list.listview_open, list.listview_close
    clay.tableview = loadScript("component/tableview.lua").tableview
    local node = loadScript("component/node_editor.lua")
    clay.node_editor, clay.node = node.node_editor, node.node
end

local demo

ffi.cdef[[
typedef struct {
    float x, y;
    float u, v;
    uint8_t r, g, b, a;
} Vertex;
]]

local canvas_selector = ffi.new("char[7]")
ffi.copy(canvas_selector, "#scene")

local view_id = 0
local width, height, pixel_width, pixel_height, pixel_ratio = 1, 1, 1, 1, 1
local pointer_x, pointer_y = -1, -1
local clay_memory, clay_context
local shader, white_texture, sampler
local transform_uniform, params_uniform, corner_uniform
local border_uniform, border_color_uniform
local vertex_layout = ffi.new("bgfx_vertex_layout_t[1]")
local swap_chain = ffi.new("bgfx_swap_chain_t[1]")
local vertex_scratch = ffi.new("bgfx_transient_vertex_buffer_t[1]")
local index_scratch = ffi.new("bgfx_transient_index_buffer_t[1]")
local uniform_scratch = ffi.new("float[4]")
local clip_stack = {}
local measurementRenderer

local function update_text_measurement_backend()
    if measurementRenderer == device.renderer then return end
    if device.renderer == "canvas2d" then
        font_manager.measureText = canvas2d.measureText
        font_manager.measureTextConfig = canvas2d.measureTextConfig
    else
        font_manager.measureText = bgfxMeasureText
        font_manager.measureTextConfig = bgfxMeasureTextConfig
    end
    measurementRenderer = device.renderer
    if clay_context and clay.setMeasureTextFunction then
        clay.setMeasureTextFunction(font_manager.measureText)
    end
end

local function set_uniform(handle, x, y, z, w)
    uniform_scratch[0], uniform_scratch[1], uniform_scratch[2], uniform_scratch[3] = x, y, z, w
    bgfx.bgfx_set_uniform(handle, uniform_scratch, 1)
end

local function set_default_shape_uniforms()
    set_uniform(corner_uniform, 0, 0, 0, 0)
    set_uniform(border_uniform, 0, 0, 0, 0)
    set_uniform(border_color_uniform, 0, 0, 0, 0)
    set_uniform(params_uniform, 0, 0, 0, 0)
end

local function push_clip(x, y, w, h)
    x, y = math.floor(x or 0), math.floor(y or 0)
    w, h = math.max(0, math.floor(w or 0)), math.max(0, math.floor(h or 0))
    local x1, y1 = math.min(width, x + w), math.min(height, y + h)
    x, y = math.min(width, math.max(0, x)), math.min(height, math.max(0, y))
    local parent = clip_stack[#clip_stack]
    if parent then
        x, y = math.max(x, parent.x), math.max(y, parent.y)
        x1, y1 = math.min(x1, parent.x + parent.w), math.min(y1, parent.y + parent.h)
    end
    local clip = { x = x, y = y, w = math.max(0, x1 - x), h = math.max(0, y1 - y) }
    clip_stack[#clip_stack + 1] = clip
    bgfx.bgfx_set_scissor(
        math.floor(clip.x * pixel_ratio), math.floor(clip.y * pixel_ratio),
        math.floor(clip.w * pixel_ratio), math.floor(clip.h * pixel_ratio))
end

local function pop_clip()
    clip_stack[#clip_stack] = nil
    local clip = clip_stack[#clip_stack]
    if clip then
        bgfx.bgfx_set_scissor(
            math.floor(clip.x * pixel_ratio), math.floor(clip.y * pixel_ratio),
            math.floor(clip.w * pixel_ratio), math.floor(clip.h * pixel_ratio))
    else
        bgfx.bgfx_set_scissor(0, 0, 0, 0)
    end
end

local function apply_clip()
    local clip = clip_stack[#clip_stack]
    if clip then
        bgfx.bgfx_set_scissor(
            math.floor(clip.x * pixel_ratio), math.floor(clip.y * pixel_ratio),
            math.floor(clip.w * pixel_ratio), math.floor(clip.h * pixel_ratio))
    end
end

local function submit_mesh(vertices, indices, vertex_count, index_count, texture, blend_state)
    if not vertices or not indices or vertex_count <= 0 or index_count <= 0 then return end
    if ffi.arch == "wasm" then
        if not bgfx.bgfx_set_transient_buffers(vertex_layout, vertices, vertex_count, indices, index_count) then
            return
        end
    else
        if bgfx.bgfx_get_avail_transient_vertex_buffer(vertex_count, vertex_layout) < vertex_count
            or bgfx.bgfx_get_avail_transient_index_buffer(index_count, false) < index_count then
            return
        end
        bgfx.bgfx_alloc_transient_vertex_buffer(vertex_scratch, vertex_count, vertex_layout)
        bgfx.bgfx_alloc_transient_index_buffer(index_scratch, index_count, false)
        ffi.copy(vertex_scratch[0].data, vertices, ffi.sizeof("Vertex") * vertex_count)
        ffi.copy(index_scratch[0].data, indices, ffi.sizeof("uint16_t") * index_count)
        bgfx.bgfx_set_transient_vertex_buffer(0, vertex_scratch, 0, vertex_count)
        bgfx.bgfx_set_transient_index_buffer(index_scratch, 0, index_count)
    end
    bgfx.bgfx_set_texture(0, sampler, texture or white_texture, 0xffffffff)
    set_uniform(transform_uniform, 1, 1, 0, 0)
    apply_clip()
    bgfx.bgfx_set_state(blend_state, 0)
    bgfx.bgfx_submit(view_id, shader, 0, bgfx.BGFX_DISCARD_ALL)
end

local rectangle_vertices = ffi.new("Vertex[4]")
local rectangle_indices = ffi.new("uint16_t[6]", { 0, 1, 2, 0, 2, 3 })

local function set_quad(x, y, w, h, r, g, b, a)
    r, g, b, a = math.floor(r or 255), math.floor(g or 255), math.floor(b or 255), math.floor(a or 255)
    rectangle_vertices[0] = { x, y, 0, 0, r, g, b, a }
    rectangle_vertices[1] = { x + w, y, 1, 0, r, g, b, a }
    rectangle_vertices[2] = { x + w, y + h, 1, 1, r, g, b, a }
    rectangle_vertices[3] = { x, y + h, 0, 1, r, g, b, a }
end

local state_msaa = bgfx.BGFX_STATE_MSAA
local alpha_state = bgfx.BGFX_STATE_WRITE_RGB + bgfx.BGFX_STATE_WRITE_A
    + bgfx.BGFX_STATE_BLEND_ALPHA + state_msaa
local text_state = bgfx.BGFX_STATE_WRITE_RGB + bgfx.BGFX_STATE_WRITE_A
    + bgfx.BGFX_STATE_BLEND_FUNC_SEPARATE(
        bgfx.BGFX_STATE_BLEND_ONE,
        bgfx.BGFX_STATE_BLEND_INV_SRC_ALPHA,
        bgfx.BGFX_STATE_BLEND_ONE,
        bgfx.BGFX_STATE_BLEND_INV_SRC_ALPHA) + state_msaa

local function draw_rectangle(x, y, w, h, r, g, b, a, tl, tr, bl, br)
    if w <= 0 or h <= 0 then return end
    set_quad(x, y, w, h, r, g, b, a)
    set_default_shape_uniforms()
    set_uniform(border_color_uniform, r / 255, g / 255, b / 255, a / 255)
    set_uniform(corner_uniform, tl or 0, tr or 0, br or 0, bl or 0)
    set_uniform(params_uniform, 1.25, 1 / w, 1 / h, 0)
    submit_mesh(rectangle_vertices, rectangle_indices, 4, 6, white_texture, alpha_state)
end

local function draw_border(x, y, w, h, r, g, b, a, tl, tr, bl, br, left, right, top, bottom)
    if w <= 0 or h <= 0 then return end
    set_quad(x, y, w, h, r, g, b, a)
    local rounded = (tl or 0) > 0 or (tr or 0) > 0 or (bl or 0) > 0 or (br or 0) > 0
    set_uniform(corner_uniform, tl or 0, tr or 0, br or 0, bl or 0)
    set_uniform(border_uniform, left or 0, right or 0, top or 0, bottom or 0)
    set_uniform(border_color_uniform, r / 255, g / 255, b / 255, a / 255)
    set_uniform(params_uniform, 1.25, 1 / w, 1 / h, rounded and 1 or 2)
    submit_mesh(rectangle_vertices, rectangle_indices, 4, 6, white_texture, alpha_state)
end

local function draw_text(x, y, text, r, g, b, a, font_id, font_size)
    if not text or text == "" then return end
    local font = font_manager.load(font_id or 0, math.max(1, font_size or 16))
    local vertices, indices, vertex_count, index_count, decorations, batches =
        font_manager.generateTextVertices(font, text, x, y, r, g, b, a)
    if not batches or #batches == 0 then
        if vertex_count > 0 and index_count > 0 then
            submit_mesh(vertices, indices, vertex_count, index_count, font.texture, text_state)
        end
        return
    end
    for i = 1, #batches do
        local batch = batches[i]
        submit_mesh(batch.vertices, batch.indices, batch.vertCount, batch.idxCount, batch.texture, text_state)
    end
    if decorations and #decorations > 0 then
        for i = 1, #decorations do
            local item = decorations[i]
            set_quad(item.x1, item.y - item.h * 0.5, item.x2 - item.x1, item.h,
                item.color.r, item.color.g, item.color.b, item.color.a)
            set_default_shape_uniforms()
            submit_mesh(rectangle_vertices, rectangle_indices, 4, 6, white_texture, alpha_state)
        end
    end
end

local function draw_node_editor_canvas(x, y, w, h, payload)
    if type(payload) ~= "table" then return end
    local wires, pending = payload.wires or {}, payload.pending
    local selection = payload.selectionRect
    local zoom = tonumber(payload.zoom) or 1
    local grid_step = math.max(12, (tonumber(payload.gridSize) or 32) * zoom)
    local capacity = math.min(16000,
        math.ceil(w / grid_step) + math.ceil(h / grid_step) + 2
        + (#wires + (pending and 1 or 0)) * 16 + (selection and 4 or 0))
    if capacity < 1 then return end

    local vertices = ffi.new("Vertex[?]", capacity * 4)
    local indices = ffi.new("uint16_t[?]", capacity * 6)
    local vertex_count, index_count, segment_count = 0, 0, 0
    local normal_limit = selection and capacity >= 4 and capacity - 4 or capacity
    local selection_pass = false

    local function emit_segment(x0, y0, x1, y1, thickness, color)
        local limit = selection_pass and capacity or normal_limit
        if segment_count >= limit then return false end
        local dx, dy = x1 - x0, y1 - y0
        local length = math.sqrt(dx * dx + dy * dy)
        if length < 0.001 then return true end
        local half = (thickness or 1) * 0.5
        local nx, ny = -dy / length * half, dx / length * half
        local r = math.max(0, math.min(255, (color and color.r) or 255))
        local g = math.max(0, math.min(255, (color and color.g) or 255))
        local b = math.max(0, math.min(255, (color and color.b) or 255))
        local a = math.max(0, math.min(255, (color and color.a) or 255))
        local v, i = vertex_count, index_count
        vertices[v + 0] = { x + x0 + nx, y + y0 + ny, 0.5, 0.5, r, g, b, a }
        vertices[v + 1] = { x + x0 - nx, y + y0 - ny, 0.5, 0.5, r, g, b, a }
        vertices[v + 2] = { x + x1 - nx, y + y1 - ny, 0.5, 0.5, r, g, b, a }
        vertices[v + 3] = { x + x1 + nx, y + y1 + ny, 0.5, 0.5, r, g, b, a }
        indices[i + 0], indices[i + 1], indices[i + 2] = v, v + 1, v + 2
        indices[i + 3], indices[i + 4], indices[i + 5] = v, v + 2, v + 3
        vertex_count, index_count, segment_count = v + 4, i + 6, segment_count + 1
        return true
    end

    local grid_color = payload.gridColor or { r = 86, g = 103, b = 132, a = 46 }
    local grid_x = (payload.panX or 0) % grid_step
    local grid_y = (payload.panY or 0) % grid_step
    while grid_x < w and segment_count < normal_limit do
        emit_segment(grid_x, 0, grid_x, h, 1, grid_color)
        grid_x = grid_x + grid_step
    end
    while grid_y < h and segment_count < normal_limit do
        emit_segment(0, grid_y, w, grid_y, 1, grid_color)
        grid_y = grid_y + grid_step
    end

    local function emit_curve(edge)
        local x0, y0, x1, y1 = edge.x0, edge.y0, edge.x1, edge.y1
        local bend = math.max(28 * zoom, math.abs(x1 - x0) * 0.48)
        local direction = x1 >= x0 and 1 or -1
        local c1x, c2x = x0 + bend * direction, x1 - bend * direction
        local last_x, last_y = x0, y0
        local color = edge.color or { r = 180, g = 191, b = 211, a = 235 }
        for step = 1, 16 do
            local t, inv = step / 16, 1 - step / 16
            local px = inv^3 * x0 + 3 * inv^2 * t * c1x + 3 * inv * t^2 * c2x + t^3 * x1
            local py = inv^3 * y0 + 3 * inv^2 * t * y0 + 3 * inv * t^2 * y1 + t^3 * y1
            if not emit_segment(last_x, last_y, px, py, edge.width or 2.2 * zoom, color) then return false end
            last_x, last_y = px, py
        end
        return true
    end

    for i = 1, #wires do if not emit_curve(wires[i]) then break end end
    if pending and segment_count < normal_limit then emit_curve(pending) end
    if selection and capacity - segment_count >= 4 then
        selection_pass = true
        local x0, y0 = selection.x, selection.y
        local x1, y1 = x0 + selection.w, y0 + selection.h
        local color, thickness = selection.color, selection.width or 1.5
        emit_segment(x0, y0, x1, y0, thickness, color)
        emit_segment(x1, y0, x1, y1, thickness, color)
        emit_segment(x1, y1, x0, y1, thickness, color)
        emit_segment(x0, y1, x0, y0, thickness, color)
    end
    submit_mesh(vertices, indices, vertex_count, index_count, white_texture, alpha_state)
end

local function setup_view()
    bgfx.bgfx_set_view_rect(view_id, 0, 0, pixel_width, pixel_height, 0, 1)
    bgfx.bgfx_set_view_clear(view_id, bgfx.BGFX_CLEAR_COLOR, 0x111a2aff, 1, 0)
    local view = ffi.new("mat4_t"):identity()
    local projection = ffi.new("mat4_t"):from_ortho(
        0, width, height, 0, 0, 100, 0, bgfx.bgfx_get_caps().homogeneousDepth, false)
    bgfx.bgfx_set_view_transform(view_id, view, projection)
end

local function initialize()
    if device.renderer == "bgfx" then
        local init = ffi.new("bgfx_init_t[1]")
        bgfx.bgfx_init_ctor(init)
        init[0].type = bgfx.BGFX_RENDERER_TYPE_OPENGLES
        init[0].swapChain.nwh = ffi.cast("void *", canvas_selector)
        init[0].swapChain.width = pixel_width
        init[0].swapChain.height = pixel_height
        init[0].swapChain.formatColor = bgfx.BGFX_TEXTURE_FORMAT_RGBA8
        init[0].reset = bgfx.BGFX_RESET_VSYNC
        if not bgfx.bgfx_init(init[0]) then error("BGFX could not create a WebGL2 context") end

        swap_chain[0] = init[0].swapChain
        bgfx.bgfx_vertex_layout_begin(vertex_layout, bgfx.bgfx_get_renderer_type())
        bgfx.bgfx_vertex_layout_add(vertex_layout, bgfx.BGFX_ATTRIB_POSITION, 2,
            bgfx.BGFX_ATTRIB_TYPE_FLOAT, false, false)
        bgfx.bgfx_vertex_layout_add(vertex_layout, bgfx.BGFX_ATTRIB_TEXCOORD0, 2,
            bgfx.BGFX_ATTRIB_TYPE_FLOAT, false, false)
        bgfx.bgfx_vertex_layout_add(vertex_layout, bgfx.BGFX_ATTRIB_COLOR0, 4,
            bgfx.BGFX_ATTRIB_TYPE_UINT8, true, false)
        bgfx.bgfx_vertex_layout_end(vertex_layout)

        local white = ffi.new("uint32_t[1]", 0xffffffff)
        white_texture = bgfx.bgfx_create_texture_2d(1, 1, false, 1,
            bgfx.BGFX_TEXTURE_FORMAT_RGBA8, 0, bgfx.bgfx_copy(white, 4))
        sampler = bgfx.bgfx_create_uniform("s_texColor", bgfx.BGFX_UNIFORM_TYPE_SAMPLER, 1)
        transform_uniform = bgfx.bgfx_create_uniform("u_transform2D", bgfx.BGFX_UNIFORM_TYPE_VEC4, 1)
        params_uniform = bgfx.bgfx_create_uniform("u_rcParams", bgfx.BGFX_UNIFORM_TYPE_VEC4, 1)
        corner_uniform = bgfx.bgfx_create_uniform("u_rcCorner", bgfx.BGFX_UNIFORM_TYPE_VEC4, 1)
        border_uniform = bgfx.bgfx_create_uniform("u_rcBorder", bgfx.BGFX_UNIFORM_TYPE_VEC4, 1)
        border_color_uniform = bgfx.bgfx_create_uniform("u_borderColor", bgfx.BGFX_UNIFORM_TYPE_VEC4, 1)
        shader = shader_manager.load_clay_program(".")
    end

    local memory
    memory, clay_context = clay.initialize(clay.minMemorySize(), width, height)
    clay_memory = memory
    if not clay_context then error("Could not initialize Clay") end
    clay.setMeasureTextFunction(font_manager.measureText)
    retained_runtime.install(clay, width, height)
    window.callback_register("window_set_key", function()
        if clay._invalidateRetainedKeyboardInput then clay._invalidateRetainedKeyboardInput() end
    end)
    window.callback_register("window_set_char", function()
        if clay._invalidateRetainedKeyboardInput then clay._invalidateRetainedKeyboardInput() end
    end)

    install_components()
    demo = loadScript("demo/body.lua")
    if not demo or type(demo.layout) ~= "function" then error("Could not load the Clay demo body") end

    if device.renderer == "bgfx" then
        local name = bgfx.bgfx_get_renderer_name(bgfx.bgfx_get_renderer_type())
        print("renderer:", name ~= nil and ffi.string(name) or "unknown")
        setup_view()
    else
        print("renderer: Canvas2D")
    end
end

local function render_commands(dt)
    if device.renderer == "canvas2d" then
        canvas2d.drawCommands(clay, dt, width, height, pixel_ratio)
        return
    end
    clip_stack = {}
    set_uniform(transform_uniform, 1, 1, 0, 0)
    for command, x, y, w, h, r, g, b, a, tl, tr, bl, br,
        left, right, top, bottom, text, font_id, font_size, letter_spacing,
        line_height, payload, clip_horizontal, clip_vertical in clay.endLayoutFast(dt) do
        if command == clay.RENDER_RECTANGLE then
            draw_rectangle(x, y, w, h, r, g, b, a, tl, tr, bl, br)
        elseif command == clay.RENDER_BORDER then
            draw_border(x, y, w, h, r, g, b, a, tl, tr, bl, br, left, right, top, bottom)
        elseif command == clay.RENDER_TEXT then
            draw_text(x, y, text, r, g, b, a, font_id, font_size)
        elseif command == clay.RENDER_IMAGE then
            if payload ~= nil then
                set_quad(x, y, w, h, 255, 255, 255, 255)
                set_default_shape_uniforms()
                local texture = ffi.new("bgfx_texture_handle_t", tonumber(payload))
                submit_mesh(rectangle_vertices, rectangle_indices, 4, 6, texture, alpha_state)
            end
        elseif command == clay.RENDER_CUSTOM and type(payload) == "table"
            and payload.kind == "clay_node_editor_canvas" then
            draw_node_editor_canvas(x, y, w, h, payload)
        elseif command == clay.RENDER_SCISSOR_START then
            if not clip_horizontal then x, w = 0, width end
            if not clip_vertical then y, h = 0, height end
            push_clip(x, y, w, h)
        elseif command == clay.RENDER_SCISSOR_END then
            pop_clip()
        end
    end
    while #clip_stack > 0 do pop_clip() end
    bgfx.bgfx_frame(0)
end

function web_frame(dt, viewport_width, viewport_height, mouse_x, mouse_y, mouse_buttons,
    scroll_x, scroll_y, requested_pixel_ratio, requested_renderer)
    device.renderer = tonumber(requested_renderer) == 1 and "canvas2d" or "bgfx"
    update_text_measurement_backend()
    width, height = math.max(1, viewport_width), math.max(1, viewport_height)
    pixel_ratio = math.max(1, requested_pixel_ratio or 1)
    pixel_width, pixel_height = math.max(1, math.floor(width * pixel_ratio + 0.5)),
        math.max(1, math.floor(height * pixel_ratio + 0.5))
    pointer_x, pointer_y = mouse_x or -1, mouse_y or -1
    device.width, device.height = width, height
    device.scroll.x, device.scroll.y = scroll_x or 0, scroll_y or 0
    window._setFrameInput(pointer_x, pointer_y, mouse_buttons or 0,
        device.scroll.x, device.scroll.y, dt or 0)
    window.update(dt or 0)

    if not clay_context then
        initialize()
    elseif device.renderer == "bgfx" and
        (swap_chain[0].width ~= pixel_width or swap_chain[0].height ~= pixel_height) then
        swap_chain[0].width, swap_chain[0].height = pixel_width, pixel_height
        bgfx.bgfx_reset(bgfx.BGFX_RESET_VSYNC, swap_chain)
        setup_view()
    end

    clay.setLayoutDimensions(width, height)
    if device.renderer == "bgfx" then
        bgfx.bgfx_set_view_rect(view_id, 0, 0, pixel_width, pixel_height, 0, 1)
        local view = ffi.new("mat4_t"):identity()
        local projection = ffi.new("mat4_t"):from_ortho(
            0, width, height, 0, 0, 100, 0, bgfx.bgfx_get_caps().homogeneousDepth, false)
        bgfx.bgfx_set_view_transform(view_id, view, projection)
        bgfx.bgfx_touch(view_id)
    end

    if demo and demo.layout then demo.layout(dt or 0) end
    render_commands(dt or 0)
    device.scroll.x, device.scroll.y = 0, 0
end
