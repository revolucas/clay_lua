local window = require("window")
local theme = require("theme")
local ComponentBuilder = require("component.builder")

local browserStates = {}
local EMPTY_SCROLL_OPTIONS = {}

local function C(color)
  return color.r, color.g, color.b, color.a
end

local function default_key(item, index)
  if type(item) == "table" then
    return item.key or item.id or item.name or item.label or index
  end
  return item
end

local function default_label(item)
  if type(item) == "table" then
    return tostring(item.label or item.name or item.text or item.id or item.key or "")
  end
  return tostring(item)
end

local function default_category(item)
  return type(item) == "table" and item.category or nil
end

local function default_description(item)
  return type(item) == "table" and item.description or nil
end

local function ensure_state(rootId)
  local state = browserStates[rootId]
  if not state then
    state = {
      query = "",
      visible = {},
      searchParts = {},
      keyToInt = {},
      nextInt = 1,
      lastDown = false,
      pressedKey = nil,
      pressedTileId = nil,
      lastClickKey = nil,
      lastClickTime = 0,
    }
    browserStates[rootId] = state
  end
  state.searchParts = state.searchParts or {}
  return state
end

local function key_to_int(state, key)
  local value = state.keyToInt[key]
  if value then return value end
  value = state.nextInt
  state.nextInt = value + 1
  state.keyToInt[key] = value
  return value
end

local function lower(value)
  return tostring(value or ""):lower()
end

local function append_search_text(parts, value)
  if value == nil then return end
  if type(value) == "table" then
    for i = 1, #value do
      parts[#parts + 1] = lower(value[i])
    end
  else
    parts[#parts + 1] = lower(value)
  end
end

local function item_matches(item, index, key, query, getLabel, getCategory,
    getDescription, filter, parts)
  if filter and not filter(item, query, index, key) then return false end
  if query == "" then return true end

  for i = #parts, 1, -1 do parts[i] = nil end
  append_search_text(parts, getLabel(item, key))
  append_search_text(parts, getCategory(item, key))
  append_search_text(parts, getDescription(item, key))
  if type(item) == "table" then append_search_text(parts, item.tags) end
  local searchText = table.concat(parts, " ")
  return searchText:find(query, 1, true) ~= nil
end

local function draw_asset_tile(state, item, itemKey, selected, defaults, colors,
    fontId, fontSize, tileHeight, previewHeight, labelHeight, categoryHeight,
    getLabel, getCategory, getIcon, getThumbnail, getColor)
  local keyInt = key_to_int(state, itemKey)
  local tileId = clay.id("AssetBrowserTile", keyInt, true)
  local previewId = clay.id("AssetBrowserPreview", keyInt, true)
  local labelId = clay.id("AssetBrowserLabel", keyInt, true)
  local categoryId = clay.id("AssetBrowserCategory", keyInt, true)
  local hovered = clay.pointerOver(tileId)
  local tileColor = selected and (colors.selected or theme.colors.assetBrowser.selected)
      or (hovered and (colors.hover or theme.colors.assetBrowser.hover)
      or (colors.tile or theme.colors.assetBrowser.tile))
  local borderColor = selected and (colors.selectedBorder or theme.colors.accent)
      or (colors.border or theme.colors.borderSubtle)

  clay.element(tileId)
    :layoutDirection(clay.TOP_TO_BOTTOM)
    :width(clay.SIZING_GROW)
    :height(clay.SIZING_FIXED, tileHeight)
    :padding(defaults.padding)
    :childGap(4)
    :backgroundColor(C(tileColor))
    :borderColor(C(borderColor))
    :borderWidth(selected and 2 or 1)
    :open()

    local thumbnail = getThumbnail and getThumbnail(item, itemKey)
        or (type(item) == "table" and (item.thumbnail or item.image) or nil)
    local itemColor = getColor and getColor(item, itemKey)
        or (type(item) == "table" and item.color or nil)
    local icon = getIcon and getIcon(item, itemKey)
        or (type(item) == "table" and item.icon or nil)
    local previewColor = colors.preview or theme.colors.surface
    if itemColor and type(itemColor) == "table" and itemColor.r then
      previewColor = itemColor
    end

    local preview = clay.element(previewId)
      :width(clay.SIZING_GROW)
      :height(clay.SIZING_FIXED, previewHeight)
      :backgroundColor(C(previewColor))
      :childAlignment(clay.ALIGN_X_CENTER, clay.ALIGN_Y_CENTER)
    if thumbnail ~= nil then preview:imageData(thumbnail) end
    preview:open()
    if thumbnail == nil and icon ~= nil and icon ~= "" then
      clay.text(tostring(icon))
        :fontId(fontId)
        :fontSize(math.floor(math.min(28, fontSize * 1.6) + 0.5))
        :textColor(C(colors.icon or theme.colors.assetBrowser.icon))
        :done()
    end
    clay.close()

    clay.element(labelId)
      :width(clay.SIZING_GROW)
      :height(clay.SIZING_FIXED, labelHeight)
      :childAlignment(clay.ALIGN_X_LEFT, clay.ALIGN_Y_CENTER)
      :open()
      clay.text(tostring(getLabel(item, itemKey)))
        :fontId(fontId)
        :fontSize(fontSize)
        :textColor(C(selected and theme.colors.selectionText or colors.text or theme.colors.text))
        :wrapMode(clay.TEXT_WRAP_NONE)
        :done()
    clay.close()

    local category = getCategory(item, itemKey)
    if category ~= nil and tostring(category) ~= "" then
      clay.element(categoryId)
        :width(clay.SIZING_GROW)
        :height(clay.SIZING_FIXED, categoryHeight)
        :childAlignment(clay.ALIGN_X_LEFT, clay.ALIGN_Y_CENTER)
        :open()
        clay.text(tostring(category))
          :fontId(fontId)
          :fontSize(math.max(10, fontSize - 2))
          :textColor(C(colors.muted or theme.colors.textMuted))
          :wrapMode(clay.TEXT_WRAP_NONE)
          :done()
      clay.close()
    end
  clay.close()

  if clay.pointerOver(tileId) and window.mouseButtonDown(window.MOUSE_BUTTON_LEFT)
      and not state.lastDown then
    state.pressedKey = itemKey
    state.pressedTileId = tileId
  end
  return tileId
end

local function render_asset_browser(elid, items, opts)
  assert(type(items) == "table", "asset_browser: items must be an array")
  local state = ensure_state(elid.id)
  local defaults = theme.defaults.assetBrowser
  local colors = opts.colors or theme.colors.assetBrowser
  local getKey = opts.getKey or default_key
  local getLabel = opts.getLabel or default_label
  local getCategory = opts.getCategory or default_category
  local getDescription = opts.getDescription or default_description
  local getIcon = opts.getIcon
  local getThumbnail = opts.getThumbnail
  local getColor = opts.getColor
  local filter = opts.filter
  assert(filter == nil or type(filter) == "function",
    "asset_browser: filter must be a predicate function")
  local query
  local visible = state.visible
  local visibleCount = 0

  local selectedKey = opts.selectedKey
  if selectedKey == nil then selectedKey = state.selectedKey end
  if opts.selectedKey ~= nil then state.selectedKey = opts.selectedKey end
  local width = opts.width or defaults.width
  local height = opts.height or defaults.height
  local fontId = opts.fontId or defaults.fontId
  local fontSize = opts.fontSize or theme.type.small
  local tileHeight = opts.tileHeight or defaults.tileHeight
  local tileWidth = opts.tileWidth or defaults.tileWidth
  local gap = opts.gap or defaults.gap
  local padding = opts.pad or defaults.padding
  local searchHeight = opts.searchHeight or defaults.searchHeight
  local searchable = opts.searchable ~= false

  local root = clay.element(elid)
    :layoutDirection(clay.TOP_TO_BOTTOM)
    :width(clay.SIZING_FIXED, width)
    :height(clay.SIZING_FIXED, height)
    :padding(padding)
    :childGap(gap)
    :backgroundColor(C(colors.background or theme.colors.assetBrowser.background))
    :borderColor(C(colors.border or theme.colors.border))
    :borderWidth(1)
  root:open()

  local headerId = clay.id("AssetBrowserHeader", 1, true)
  clay.element(headerId)
    :layoutDirection(clay.LEFT_TO_RIGHT)
    :width(clay.SIZING_GROW)
    :height(clay.SIZING_FIXED, searchHeight)
    :childGap(gap)
    :childAlignment(clay.ALIGN_X_LEFT, clay.ALIGN_Y_CENTER)
    :open()
    if searchable then
      clay.text("Search")
        :fontId(fontId)
        :fontSize(fontSize)
        :textColor(C(colors.muted or theme.colors.textMuted))
        :done()
      local editedQuery = clay.edit(clay.id("AssetBrowserSearch", 1, true), state.query)
        :width(math.max(96, width - 184))
        :height(searchHeight)
        :filter("no_newlines")
        :maxChars(128)
        :draw()
      state.query = editedQuery or ""
    end

    query = state.query:lower()
    for i = 1, #items do
      local item = items[i]
      local itemKey = getKey(item, i)
      if itemKey == nil then itemKey = i end
      if item_matches(item, i, itemKey, query, getLabel, getCategory,
          getDescription, filter, state.searchParts) then
        visibleCount = visibleCount + 1
        local entry = visible[visibleCount]
        if not entry then entry = {}; visible[visibleCount] = entry end
        entry.item, entry.key, entry.index = item, itemKey, i
      end
    end
    for i = visibleCount + 1, #visible do visible[i] = nil end

    clay.element()
      :width(clay.SIZING_GROW)
      :height(1)
      :close()
    clay.text(tostring(visibleCount) .. " assets")
      :fontId(fontId)
      :fontSize(fontSize)
      :textColor(C(colors.muted or theme.colors.textMuted))
      :done()
  clay.close()

  local viewportId = clay.id("AssetBrowserViewport", 1, true)
  local contentId = clay.id("AssetBrowserContent", 1, true)
  local viewportHeight = math.max(80, height - searchHeight - padding * 2 - gap - 2)
  local viewport = clay.element(viewportId)
    :layoutDirection(clay.TOP_TO_BOTTOM)
    :width(clay.SIZING_GROW)
    :height(clay.SIZING_FIXED, viewportHeight)
    :scrollable(true, false)
    :backgroundColor(C(colors.viewport or theme.colors.assetBrowser.viewport))
    :open()

  local viewData = clay.getScrollContainerData(viewportId)
  local viewHeight, scrollY
  if viewData and viewData.found and viewData.dimensions then
    viewHeight = viewData.dimensions.height
    scrollY = math.max(0, -(viewData.scrollPosition and viewData.scrollPosition.y or 0))
  end

  local columns = opts.columns or defaults.columns
  if not columns then
    local viewBox = clay.getElementData(viewportId)
    local availableWidth = viewBox and viewBox.width or width - padding * 2
    columns = math.max(1, math.floor((availableWidth + gap) / (tileWidth + gap)))
  end
  columns = math.max(1, math.floor(columns))
  local totalRows = math.ceil(visibleCount / columns)
  local tileBlockHeight = tileHeight + gap
  local firstRow, lastRow = 1, totalRows
  if viewHeight and tileBlockHeight > 0 then
    firstRow = math.max(1, math.floor(scrollY / tileBlockHeight) + 1)
    local visibleRows = math.ceil(viewHeight / tileBlockHeight) + 2
    lastRow = math.min(totalRows, firstRow + visibleRows - 1)
  end

  local content = clay.element(contentId)
    :layoutDirection(clay.TOP_TO_BOTTOM)
    :width(clay.SIZING_GROW)
    :height(clay.SIZING_FIT)
    :childGap(gap)
    :padding(padding)
    :open()

  if visibleCount == 0 then
    clay.element(clay.id("AssetBrowserEmpty", 1, true))
      :layoutDirection(clay.LEFT_TO_RIGHT)
      :width(clay.SIZING_GROW)
      :height(clay.SIZING_FIXED, tileHeight)
      :childAlignment(clay.ALIGN_X_CENTER, clay.ALIGN_Y_CENTER)
      :open()
      clay.text(opts.emptyText or "No matching assets")
        :fontId(fontId)
        :fontSize(fontSize)
        :textColor(C(colors.muted or theme.colors.textMuted))
        :done()
    clay.close()
  else
    if firstRow > 1 then
      clay.element(clay.id("AssetBrowserTopSpacer", 1, true))
        :width(clay.SIZING_GROW)
        :height(clay.SIZING_FIXED, math.max(0, (firstRow - 1) * tileBlockHeight - gap))
        :close()
    end

    for rowIndex = firstRow, lastRow do
      clay.element(clay.id("AssetBrowserRow", rowIndex, true))
        :layoutDirection(clay.LEFT_TO_RIGHT)
        :width(clay.SIZING_GROW)
        :height(clay.SIZING_FIXED, tileHeight)
        :childGap(gap)
        :open()
        for columnIndex = 1, columns do
          local itemIndex = (rowIndex - 1) * columns + columnIndex
          local entry = visible[itemIndex]
          if entry then
            draw_asset_tile(state, entry.item, entry.key, entry.key == selectedKey,
              defaults, colors, fontId, fontSize, tileHeight,
              math.max(24, tileHeight - defaults.padding * 2 - 42), 20, 14,
              getLabel, getCategory, getIcon, getThumbnail, getColor)
          else
            clay.element()
              :width(clay.SIZING_GROW)
              :height(clay.SIZING_FIXED, tileHeight)
              :close()
          end
        end
      clay.close()
    end

    if lastRow < totalRows then
      clay.element(clay.id("AssetBrowserBottomSpacer", 2, true))
        :width(clay.SIZING_GROW)
        :height(clay.SIZING_FIXED, math.max(0, (totalRows - lastRow) * tileBlockHeight - gap))
        :close()
    end
  end

  clay.close() -- content
  clay.close() -- viewport
  local wheel = device and device.scroll and device.scroll.y or 0
  clay.scrollbar(viewportId, contentId, wheel, EMPTY_SCROLL_OPTIONS)
  clay.close() -- browser root

  local down = window.mouseButtonDown(window.MOUSE_BUTTON_LEFT)
  local released = state.lastDown and not down
  local changed = false
  if released and state.pressedKey ~= nil then
    local itemEntry
    for i = 1, visibleCount do
      local entry = visible[i]
      if entry.key == state.pressedKey then itemEntry = entry; break end
    end
    local tileId = state.pressedTileId
    if itemEntry and tileId and clay.pointerOver(tileId) then
      local now = window.time()
      local activated = state.lastClickKey == state.pressedKey
          and now - (state.lastClickTime or 0) < 0.35
      changed = selectedKey ~= state.pressedKey
      selectedKey = state.pressedKey
      state.selectedKey = selectedKey
      if changed and opts.onSelect then opts.onSelect(selectedKey, itemEntry.item) end
      if activated and opts.onActivate then opts.onActivate(selectedKey, itemEntry.item) end
      state.lastClickKey, state.lastClickTime = selectedKey, now
      if (changed or activated) and clay._invalidateCurrentRetainedRoot then
        clay._invalidateCurrentRetainedRoot()
      end
    end
  end
  if not down then
    state.pressedKey = nil
    state.pressedTileId = nil
  end
  state.lastDown = down

  local selectedItem
  for i = 1, #items do
    local item = items[i]
    local key = getKey(item, i)
    if key == nil then key = i end
    if key == selectedKey then selectedItem = item; break end
  end
  return selectedKey, selectedItem, visibleCount, state.query, changed
end

ComponentBuilder.register("asset_browser", function(builder)
  return render_asset_browser(rawget(builder, "_id"), rawget(builder, "_arg1"), builder)
end)

function asset_browser(id, items)
  return ComponentBuilder.new("asset_browser", id, items)
end
