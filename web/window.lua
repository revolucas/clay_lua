-- Browser-backed subset of window.lua used by the shared demo/components.
local M = {
  PRESS = 1, RELEASE = 0, REPEAT = 2,
  MOUSE_BUTTON_LEFT = 0, MOUSE_BUTTON_RIGHT = 1, MOUSE_BUTTON_MIDDLE = 2,
  KEY_UNKNOWN = -1,
  KEY_SPACE = 32,
  KEY_APOSTROPHE = 39, KEY_COMMA = 44, KEY_MINUS = 45, KEY_PERIOD = 46, KEY_SLASH = 47,
  KEY_SEMICOLON = 59, KEY_EQUAL = 61,
  KEY_ESCAPE = 256, KEY_ENTER = 257, KEY_TAB = 258, KEY_BACKSPACE = 259,
  KEY_INSERT = 260, KEY_DELETE = 261,
  KEY_RIGHT = 262, KEY_LEFT = 263, KEY_DOWN = 264, KEY_UP = 265,
  KEY_PAGE_UP = 266, KEY_PAGE_DOWN = 267, KEY_HOME = 268, KEY_END = 269,
  KEY_CAPS_LOCK = 280, KEY_SCROLL_LOCK = 281, KEY_NUM_LOCK = 282,
  KEY_PRINT_SCREEN = 283, KEY_PAUSE = 284,
  KEY_KP_0 = 320, KEY_KP_DECIMAL = 330, KEY_KP_DIVIDE = 331,
  KEY_KP_MULTIPLY = 332, KEY_KP_SUBTRACT = 333, KEY_KP_ADD = 334,
  KEY_KP_ENTER = 335, KEY_KP_EQUAL = 336,
  KEY_LEFT_SHIFT = 340, KEY_LEFT_CONTROL = 341, KEY_LEFT_ALT = 342, KEY_LEFT_SUPER = 343,
  KEY_RIGHT_SHIFT = 344, KEY_RIGHT_CONTROL = 345, KEY_RIGHT_ALT = 346, KEY_RIGHT_SUPER = 347,
  KEY_MENU = 348,
  MOD_SHIFT = 0x0001, MOD_CONTROL = 0x0002, MOD_ALT = 0x0004, MOD_SUPER = 0x0008,
  MOD_CAPS_LOCK = 0x0010, MOD_NUM_LOCK = 0x0020,
  callbacks = {},
}

for code = 48, 57 do M["KEY_" .. string.char(code)] = code end
for code = 65, 90 do M["KEY_" .. string.char(code)] = code end
M.KEY_LEFT_BRACKET, M.KEY_BACKSLASH = 91, 92
M.KEY_RIGHT_BRACKET, M.KEY_GRAVE_ACCENT = 93, 96
for n = 1, 25 do M["KEY_F" .. n] = 289 + n end
for n = 1, 9 do M["KEY_KP_" .. n] = 320 + n end

local keys, buttons = {}, {}
local mouse_x, mouse_y, current_time = -1, -1, 0
local scroll_x, scroll_y, clipboard = 0, 0, ""

local function ordered_callbacks(event)
  local list = {}
  for key, entry in pairs(M.callbacks[event] or {}) do
    list[#list + 1] = { key = key, entry = entry }
  end
  table.sort(list, function(a, b)
    if a.entry.prior == b.entry.prior then return tostring(a.key) < tostring(b.key) end
    return a.entry.prior > b.entry.prior
  end)
  return list
end

function M.callback_register(name, func_or_userdata, prior)
  assert(func_or_userdata ~= nil, "callback must not be nil")
  local list = M.callbacks[name]
  if not list then list = {}; M.callbacks[name] = list end
  local callback
  if type(func_or_userdata) == "function" then
    callback = function(...) func_or_userdata(...) end
  elseif type(func_or_userdata[name]) == "function" then
    callback = function(...) func_or_userdata[name](func_or_userdata, ...) end
  end
  if callback then list[func_or_userdata] = { functor = callback, prior = prior or 0 } end
end

function M.callback_remove(name, func_or_userdata)
  if M.callbacks[name] then M.callbacks[name][func_or_userdata] = nil end
end

function M.callback_send(name, ...)
  for _, item in ipairs(ordered_callbacks(name)) do item.entry.functor(...) end
end

function M.mousePosition() return mouse_x, mouse_y end
function M.mouseButtonDown(button) return buttons[tonumber(button)] == true end
function M.keyDown(key) return keys[tonumber(key)] == true end
function M.time() return current_time end
function M.clipboardText() return clipboard end
function M.setClipboardText(text) clipboard = tostring(text or "") end
function M.shouldClose() return false end
function M.update(dt) M.callback_send("window_update", M, dt or 0) end

function M._setFrameInput(x, y, button_mask, wheel_x, wheel_y, dt)
  mouse_x, mouse_y = tonumber(x) or -1, tonumber(y) or -1
  button_mask = tonumber(button_mask) or 0
  buttons[M.MOUSE_BUTTON_LEFT] = (button_mask & 1) ~= 0
  buttons[M.MOUSE_BUTTON_RIGHT] = (button_mask & 2) ~= 0
  buttons[M.MOUSE_BUTTON_MIDDLE] = (button_mask & 4) ~= 0
  scroll_x, scroll_y = tonumber(wheel_x) or 0, tonumber(wheel_y) or 0
  current_time = current_time + math.max(0, tonumber(dt) or 0)
end

function M._scroll() return scroll_x, scroll_y end

function M._keyEvent(key, down, repeated, mods)
  key = tonumber(key)
  if not key then return end
  keys[key] = down == true
  local action = not down and M.RELEASE or (repeated and M.REPEAT or M.PRESS)
  M.callback_send("window_set_key", key, key, action, tonumber(mods) or 0)
end

function M._inputText(text)
  text = tostring(text or "")
  for _, codepoint in utf8.codes(text) do
    M.callback_send("window_set_char", codepoint)
    M.callback_send("window_set_char_mods", codepoint, 0)
  end
end

function M._setClipboardText(text) clipboard = tostring(text or "") end

function M._releaseAllKeys()
  for key, down in pairs(keys) do
    if down then M._keyEvent(key, false, false, 0) end
  end
  buttons[M.MOUSE_BUTTON_LEFT] = false
  buttons[M.MOUSE_BUTTON_RIGHT] = false
  buttons[M.MOUSE_BUTTON_MIDDLE] = false
end

return M
