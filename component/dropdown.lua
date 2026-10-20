local window = require("window")
local theme = require("theme")
local ComponentBuilder = require("component.builder")

local _dropdown_state = _dropdown_state or {}
local EMPTY_OPTIONS = {}
-- Keep this component below half of Clay's fixed transition-state pool.
local MAX_ANIMATED_ROWS = 96

local function C(c) return c.r, c.g, c.b, c.a end

local DEFAULTS = {
  placeholder = "Select an option",
  zIndex = 1100,
  maxRows = 8,
}

local SCROLLBAR_OPTIONS = {}

local function item_label(item)
  if type(item) == "table" then
    return tostring(item.label or item.text or item.name or item.value or item.id or "")
  end
  return tostring(item)
end

local function item_value(item, index)
  if type(item) == "table" then
    local value = item.value
    if value == nil then value = item.id end
    if value == nil then value = item.key end
    if value == nil then value = item.label or item.text or item.name end
    if value ~= nil then return value end
  end
  return item
end

-- dropdown(id, items, selectedValue): configure fluently, then :draw() for
-- selectedValue, changed.
-- Items may be strings or records with label/text and value/id/key fields.
local function render_dropdown(elid, items, selectedValue, opts)
  assert(elid and elid.id, "dropdown: id must come from clay.id()")
  assert(type(items) == "table", "dropdown: items must be a table")

  local options = opts or EMPTY_OPTIONS
  local userColors = options.colors
  local colors = theme.colors.dropdown
  local c_button = (userColors and userColors.button) or colors.button
  local c_buttonHover = (userColors and userColors.buttonHover) or colors.buttonHover
  local c_popup = (userColors and userColors.popup) or colors.popup
  local c_row = (userColors and userColors.row) or colors.row
  local c_rowHover = (userColors and userColors.rowHover) or colors.rowHover
  local c_rowSelected = (userColors and userColors.rowSelected) or colors.rowSelected
  local c_border = (userColors and userColors.border) or colors.border
  local c_text = (userColors and userColors.text) or colors.text
  local componentDefaults = theme.defaults.dropdown
  local width = options.width or componentDefaults.width
  local zIndex = options.zIndex ~= nil and options.zIndex or DEFAULTS.zIndex
  local rowHeight = options.rowHeight or theme.spacing.controlHeight
  local maxRows = options.maxRows or componentDefaults.maxRows or DEFAULTS.maxRows
  assert(type(maxRows) == "number" and maxRows >= 1, "dropdown: maxRows must be at least 1")
  maxRows = math.floor(maxRows)
  local fontId = options.fontId or componentDefaults.fontId
  local fontSize = options.fontSize or theme.type.body
  local duration = options.transitionDuration
  if duration == nil then duration = theme.motion.standard end
  assert(type(duration) == "number" and duration >= 0, "dropdown: transitionDuration must be a non-negative number")
  local placeholder = options.placeholder or DEFAULTS.placeholder

  local key = elid.id
  local state = _dropdown_state[key]
  if not state then
    state = { open = false, wasDown = false, pressedButton = false, pressedIndex = nil }
    _dropdown_state[key] = state
  end

  local down = window.mouseButtonDown(window.MOUSE_BUTTON_LEFT)
  local pressed = down and not state.wasDown
  local released = not down and state.wasDown
  local changed = false
  local buttonId

  clay.element(elid)
    :col()
    :width(clay.SIZING_FIXED, width)
    :height(clay.SIZING_FIT)
    :open()

  buttonId = clay.id("DropdownButton", 1, true)
  local buttonHovered = clay.pointerOver(buttonId)

  if pressed then
    state.pressedButton = buttonHovered
    state.pressedIndex = nil
  elseif released then
    if state.pressedButton and buttonHovered then
      state.open = not state.open
    end
    state.pressedButton = false
  end

  local popupId = clay.id("DropdownPopup", 1, true)
  local viewportId = clay.id("DropdownViewport", 1, true)
  local contentId = clay.id("DropdownContent", 1, true)
  local scrollbarKey = viewportId.id * 2
  local scrollbarTrackId = clay.id("ScrollBarTrack", scrollbarKey, true)
  local scrollbarThumbId = clay.id("ScrollBarThumb", scrollbarKey, true)
  local needsScrollbar = #items > maxRows
  local rowIds = state.rowIds
  if state.open then
    if not rowIds then
      rowIds = {}
      state.rowIds = rowIds
    end
    for i = 1, #items do
      if not rowIds[i] then rowIds[i] = clay.id("DropdownItem", i, true) end
    end
    for i = #items + 1, #rowIds do rowIds[i] = nil end
  end

  local scrollbarHovered = state.open and needsScrollbar and (
    clay.pointerOver(scrollbarTrackId) or clay.pointerOver(scrollbarThumbId))
  local popupHovered = clay.pointerOver(popupId)
    or clay.pointerOver(viewportId)
    or clay.pointerOver(contentId)
    or scrollbarHovered
  if state.open and rowIds then
    for i = 1, #items do
      if clay.pointerOver(rowIds[i]) then popupHovered = true; break end
    end
  end
  if state.open and released and not buttonHovered and not popupHovered then
    state.open = false
  end

  local buttonColor = buttonHovered and c_buttonHover or c_button
  local buttonBuilder = clay.element(buttonId)
    :row()
    :wGrow()
    :h(rowHeight)
    :padding(componentDefaults.paddingX, 0)
    :gap(theme.spacing.controlGap)
    :alignLC()
    :bg(buttonColor)
    :borderColor(C(c_border))
    :borderWidth(1)
  if duration > 0 then
    buttonBuilder:transition(duration, "backgroundColor")
  end
  buttonBuilder:open()

    local label = placeholder
    for i, item in ipairs(items) do
      if item_value(item, i) == selectedValue then
        label = item_label(item)
        break
      end
    end

    clay.element(clay.id("DropdownLabel", 1, true))
      :wGrow()
      :h(rowHeight)
      :alignLC()
      :open()
      clay.text(label)
        :fontId(fontId)
        :fontSize(fontSize)
        :textColor(C(c_text))
        :done()
    clay.close()

    clay.text(state.open and "▴" or "▾")
      :fontId(fontId)
      :fontSize(fontSize)
      :textColor(C(c_text))
      :done()
  clay.close()

  local popupBuilder = clay.element(popupId)
  if state.open then
    for i, item in ipairs(items) do
      local hovered = not scrollbarHovered and clay.pointerOver(rowIds[i])
      local value = item_value(item, i)
      if pressed and hovered then
        state.pressedIndex = i
      elseif released and state.pressedIndex == i and hovered then
        if selectedValue ~= value then
          selectedValue = value
          changed = true
        end
        state.open = false
      end
    end
  end

  local visibleRows = math.min(#items, maxRows)
  local popupHeight = state.open and (visibleRows * rowHeight) or 0
  local animateRows = duration > 0 and state.open and #items <= MAX_ANIMATED_ROWS
  popupBuilder
    :floating()
      :parent()
      :attach("lt", "lb")
      :clipToParent(true)
      :zIndex(zIndex)
      :done()
    :col()
    :width(clay.SIZING_FIXED, width)
    :h(popupHeight)
    :clip(false, true)
    :bg(C(c_popup))
    :borderColor(C(c_border))
    :borderWidth(1)
  if duration > 0 then
    popupBuilder:transition(duration, "height")
  end
  popupBuilder:open()

    -- Keep the zero-height popup element in the tree so its height can
    -- transition, but don't create row elements while closed. Depending on
    -- renderer/clipping behavior, children of a zero-height floating element
    -- can still appear outside the clipped area.
    if state.open then
      local scrollbarDefaults = theme.defaults.scrollbar
      local scrollbarTrackWidth = scrollbarDefaults.trackWidth
      local rowWidth = needsScrollbar
        and math.max(1, width - scrollbarTrackWidth - scrollbarDefaults.margin - 4)
        or nil

      clay.element(viewportId)
        :col()
        :wGrow()
        :height(clay.SIZING_FIXED, popupHeight)
        :scrollable(true, false)
        :open()

      clay.element(contentId)
        :col()
        :wGrow()
        :height(clay.SIZING_FIT)
        :open()

      for i, item in ipairs(items) do
        local rowId = rowIds[i]
        local hovered = not scrollbarHovered and clay.pointerOver(rowId)
        local value = item_value(item, i)
        local isSelected = value == selectedValue

        local rowColor = isSelected and c_rowSelected or (hovered and c_rowHover or c_row)
        local rowBuilder = clay.element(rowId):row()
        if rowWidth then
          rowBuilder:width(clay.SIZING_FIXED, rowWidth):clip(true, false)
        else
          rowBuilder:wGrow()
        end
        rowBuilder
          :h(rowHeight)
          :padding(componentDefaults.paddingX, 0)
          :alignLC()
          :bg(rowColor)
        if animateRows then
          rowBuilder:transition(duration, "backgroundColor")
        end
        rowBuilder:open()
          clay.text(item_label(item))
            :fontId(fontId)
            :fontSize(fontSize)
            :textColor(C(c_text))
            :done()
        clay.close()
      end

      clay.close() -- content
      clay.close() -- viewport

    end

  clay.close()
  if state.open and needsScrollbar then
    local scrollbarDefaults = theme.defaults.scrollbar
    SCROLLBAR_OPTIONS.trackW = scrollbarDefaults.trackWidth
    SCROLLBAR_OPTIONS.zIndex = zIndex + 1
    local wheel = popupHovered and device and device.scroll and device.scroll.y or 0
    clay.scrollbar(viewportId, contentId, wheel, SCROLLBAR_OPTIONS)
  end
  clay.close()

  if released then state.pressedIndex = nil end
  state.wasDown = down
  if changed and clay._invalidateCurrentRetainedRoot then
    clay._invalidateCurrentRetainedRoot()
  end
  return selectedValue, changed
end

ComponentBuilder.register("dropdown", function(builder)
  return render_dropdown(rawget(builder, "_id"), rawget(builder, "_arg1"),
    rawget(builder, "_arg2"), builder)
end)

function dropdown(elid, items, selectedValue)
  return ComponentBuilder.new("dropdown", elid, items, selectedValue)
end

return { dropdown = dropdown }
