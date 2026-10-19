local ffi = require("ffi")
local bit = require("bit")
local rgfw = require("ffi.ffi_rgfw")
local _window = nil
local _title = "Clay Lua"
local scroll_delta_x, scroll_delta_y = 0, 0
local event = ffi.new("ClayRGFWEvent[1]")
local value_x, value_y = ffi.new("int[1]"), ffi.new("int[1]")
local size_w, size_h = ffi.new("int[1]"), ffi.new("int[1]")
local pos_x, pos_y = ffi.new("int[1]"), ffi.new("int[1]")

local M = {}

-- Input constants use the familiar cross-platform key values expected by the
-- UI components; the native wrapper translates them to RGFW's key enum.
M.PRESS, M.RELEASE, M.REPEAT = 1, 0, 2
M.MOUSE_BUTTON_LEFT, M.MOUSE_BUTTON_RIGHT, M.MOUSE_BUTTON_MIDDLE = 0, 1, 2
M.KEY_UNKNOWN = -1
M.KEY_SPACE = 32
M.KEY_APOSTROPHE, M.KEY_COMMA, M.KEY_MINUS, M.KEY_PERIOD, M.KEY_SLASH = 39, 44, 45, 46, 47
M.KEY_0, M.KEY_1, M.KEY_2, M.KEY_3, M.KEY_4 = 48, 49, 50, 51, 52
M.KEY_5, M.KEY_6, M.KEY_7, M.KEY_8, M.KEY_9 = 53, 54, 55, 56, 57
M.KEY_SEMICOLON, M.KEY_EQUAL = 59, 61
for code = 65, 90 do M["KEY_" .. string.char(code)] = code end
M.KEY_LEFT_BRACKET, M.KEY_BACKSLASH, M.KEY_RIGHT_BRACKET, M.KEY_GRAVE_ACCENT = 91, 92, 93, 96
M.KEY_ESCAPE, M.KEY_ENTER, M.KEY_TAB, M.KEY_BACKSPACE = 256, 257, 258, 259
M.KEY_INSERT, M.KEY_DELETE = 260, 261
M.KEY_RIGHT, M.KEY_LEFT, M.KEY_DOWN, M.KEY_UP = 262, 263, 264, 265
M.KEY_PAGE_UP, M.KEY_PAGE_DOWN, M.KEY_HOME, M.KEY_END = 266, 267, 268, 269
M.KEY_CAPS_LOCK, M.KEY_SCROLL_LOCK, M.KEY_NUM_LOCK = 280, 281, 282
M.KEY_PRINT_SCREEN, M.KEY_PAUSE = 283, 284
for n = 1, 25 do M["KEY_F" .. n] = 289 + n end
M.KEY_KP_0 = 320
for n = 1, 9 do M["KEY_KP_" .. n] = 320 + n end
M.KEY_KP_DECIMAL, M.KEY_KP_DIVIDE, M.KEY_KP_MULTIPLY = 330, 331, 332
M.KEY_KP_SUBTRACT, M.KEY_KP_ADD, M.KEY_KP_ENTER, M.KEY_KP_EQUAL = 333, 334, 335, 336
M.KEY_LEFT_SHIFT, M.KEY_LEFT_CONTROL, M.KEY_LEFT_ALT, M.KEY_LEFT_SUPER = 340, 341, 342, 343
M.KEY_RIGHT_SHIFT, M.KEY_RIGHT_CONTROL, M.KEY_RIGHT_ALT, M.KEY_RIGHT_SUPER = 344, 345, 346, 347
M.KEY_MENU = 348
M.MOD_SHIFT, M.MOD_CONTROL, M.MOD_ALT, M.MOD_SUPER = 0x0001, 0x0002, 0x0004, 0x0008
M.MOD_CAPS_LOCK, M.MOD_NUM_LOCK = 0x0010, 0x0020

local function dispatch_event(e)
    local kind = tonumber(e.type)
    if kind == 1 then
        M.callback_send("window_position", tonumber(e.a), tonumber(e.b))
    elseif kind == 2 then
        local w, h = tonumber(e.a), tonumber(e.b)
        M.callback_send("window_size", w, h)
        M.callback_send("window_framebuffer_size", w, h)
    elseif kind == 3 then
        M.callback_send("window_close")
    elseif kind == 4 then
        M.callback_send("window_refresh")
    elseif kind == 5 then
        M.callback_send("window_focus", tonumber(e.a) ~= 0)
    elseif kind == 6 then
        M.callback_send("window_iconify", tonumber(e.a) ~= 0)
    elseif kind == 7 then
        M.callback_send("window_maximized", tonumber(e.a) ~= 0)
    elseif kind == 8 then
        M.callback_send("window_iconify", false)
        M.callback_send("window_maximized", false)
    elseif kind == 9 then
        M.callback_send("window_content_scale", tonumber(e.x), tonumber(e.y))
    elseif kind == 10 then
        local key, scancode = tonumber(e.a), tonumber(e.b)
        local action, mods = tonumber(e.c), tonumber(e.d)
        M.callback_send("window_set_key", key, scancode, action, mods)
        local codepoint = tonumber(e.codepoint)
        if action ~= M.RELEASE and codepoint >= 32 and codepoint ~= 127
            and bit.band(mods, bit.bor(M.MOD_CONTROL, M.MOD_ALT, M.MOD_SUPER)) == 0 then
            M.callback_send("window_set_char", codepoint)
            M.callback_send("window_set_char_mods", codepoint, mods)
        end
    elseif kind == 11 then
        M.callback_send("mouse_button", tonumber(e.a), tonumber(e.b), tonumber(e.c))
    elseif kind == 12 then
        M.callback_send("mouse_position", tonumber(e.x), tonumber(e.y))
    elseif kind == 13 then
        M.callback_send("mouse_enter", tonumber(e.a) ~= 0)
    elseif kind == 14 then
        local dx, dy = tonumber(e.x), tonumber(e.y)
        scroll_delta_x = scroll_delta_x + dx
        scroll_delta_y = scroll_delta_y + dy
        M.callback_send("mouse_scroll", scroll_delta_x, scroll_delta_y, dx, dy)
    elseif kind == 15 then
        local paths = {}
        for i = 0, tonumber(e.count) - 1 do
            paths[#paths + 1] = ffi.string(e.paths[i])
        end
        M.callback_send("file_drop", paths, #paths)
    end
end

function M.create(config)
    config = config or {}
    local x = tonumber(config.x or config[1]) or 0
    local y = tonumber(config.y or config[2]) or 0
    local width = tonumber(config.width or config[3]) or 800
    local height = tonumber(config.height or config[4]) or 600
    local fullscreen = config.fullscreen == true or config[5] == true
    local centered = config.center ~= false
    _title = config.title or "Clay Lua"

    _window = rgfw.clay_rgfw_create(_title, x, y, width, height, fullscreen and 1 or 0, centered and 1 or 0)
    if _window == nil or _window == ffi.NULL then
        error("RGFW window creation failed")
    end

    M.callback_send("window_creation", _window, width, height)
    return _window
end

function M.update(dt)
    while rgfw.clay_rgfw_next_event(_window, event) ~= 0 do
        dispatch_event(event[0])
    end
    M.callback_send("window_update", _window, dt)
    scroll_delta_x, scroll_delta_y = 0, 0
end

function M.title(str)
    if str ~= nil then
        _title = tostring(str)
        rgfw.clay_rgfw_set_title(_window, _title)
    end
    return _title
end

function M.size(w, h)
    rgfw.clay_rgfw_get_size(_window, size_w, size_h)
    local current_w, current_h = tonumber(size_w[0]), tonumber(size_h[0])
    if w ~= nil or h ~= nil then
        w = tonumber(w) or current_w
        h = tonumber(h) or current_h
        rgfw.clay_rgfw_set_size(_window, w, h)
        return w, h
    end
    return current_w, current_h
end

function M.position(x, y)
    rgfw.clay_rgfw_get_position(_window, pos_x, pos_y)
    local current_x, current_y = tonumber(pos_x[0]), tonumber(pos_y[0])
    if x ~= nil or y ~= nil then
        x = tonumber(x) or current_x
        y = tonumber(y) or current_y
        rgfw.clay_rgfw_set_position(_window, x, y)
        return x, y
    end
    return current_x, current_y
end

function M.framebufferSize()
    rgfw.clay_rgfw_get_size(_window, size_w, size_h)
    return tonumber(size_w[0]), tonumber(size_h[0])
end

function M.mousePosition()
    rgfw.clay_rgfw_mouse_position(_window, value_x, value_y)
    return tonumber(value_x[0]), tonumber(value_y[0])
end

function M.keyDown(key)
    return rgfw.clay_rgfw_key_down(_window, tonumber(key)) ~= 0
end

function M.mouseButtonDown(button)
    return rgfw.clay_rgfw_mouse_down(_window, tonumber(button)) ~= 0
end

function M.clipboardText()
    local text = rgfw.clay_rgfw_clipboard_get()
    return (text ~= nil and text ~= ffi.NULL) and ffi.string(text) or ""
end

function M.setClipboardText(text)
    text = tostring(text or "")
    rgfw.clay_rgfw_clipboard_set(text, #text)
end

function M.nativeHandles()
    local nwh, ndt, handle_type = ffi.new("void *[1]"), ffi.new("void *[1]"), ffi.new("int[1]")
    if rgfw.clay_rgfw_platform_data(_window, nwh, ndt, handle_type) == 0 then
        error("RGFW did not provide native window handles for BGFX")
    end
    return nwh[0], ndt[0], tonumber(handle_type[0])
end

function M.show()
    rgfw.clay_rgfw_show(_window)
    M.callback_send("window_show", _window)
end

function M.hide()
    M.callback_send("window_hide", _window)
    rgfw.clay_rgfw_hide(_window)
end

function M.time()
    return rgfw.clay_rgfw_time()
end

function M.shouldClose()
    return rgfw.clay_rgfw_should_close(_window) ~= 0
end

function M.setShouldClose(should_close)
    rgfw.clay_rgfw_set_should_close(_window, should_close and 1 or 0)
end

function M.destroy()
    if _window ~= nil and _window ~= ffi.NULL then
        M.callback_send("window_destroy", _window)
        rgfw.clay_rgfw_close(_window)
        _window = nil
    end
end

M.callbacks = {}
-- Create a callback that will execute lowest priority order first
function M.callback_register(name, func_or_userdata, prior)
    if not (M.callbacks) then
        return -- intentionally removed all callbacks
    end
    assert(func_or_userdata ~= nil)
    if not (M.callbacks[name]) then
        M.callbacks[name] = {}
    end

    if (type(func_or_userdata) == "function") then
        M.callbacks[name][func_or_userdata] = {["functor"] = function(...)
                func_or_userdata(...)
            end, ["prior"] = prior or 0}
    elseif (func_or_userdata[name]) then
        M.callbacks[name][func_or_userdata] = {["functor"] = function(...)
                func_or_userdata[name](func_or_userdata, ...)
            end, ["prior"] = prior or 0}
    end
end

function M.callback_remove(name, func_or_userdata)
    if (M.callbacks and M.callbacks[name]) then
        M.callbacks[name][func_or_userdata] = nil
    end
end

local function order(t, a, b)
    return t[a].prior > t[b].prior
end

local function spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do
        keys[#keys + 1] = k
    end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys
    if order then
        table.sort(
            keys,
            function(a, b)
                return order(t, a, b)
            end
        )
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

-- Execute all registered functors for a specific event name
function M.callback_send(name, ...)
    if (M.callbacks and M.callbacks[name]) then
        for func_or_userdata, v in spairs(M.callbacks[name], order) do
            if (v.functor) then
                v.functor(...)
            end
        end
    end
end

return M
