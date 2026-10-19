local clay = require("clay")
local window = require("window")
local theme = require("theme")

-- State is per table id. Keep it across frames: callers normally rebuild the
-- Clay layout every frame, while sort order, selection, and resized columns
-- belong to the table rather than to one layout pass.
local _tbl_state = _tbl_state or {}

local TABLE_DEFAULT = {
  overscan = 2,
  doubleClickTime = 0.35,
}

local function C(c)
  return c.r, c.g, c.b, c.a
end

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function clear_array(t)
  for i = #t, 1, -1 do t[i] = nil end
end

local function clear_map(t)
  for k in pairs(t) do t[k] = nil end
end

local function normalize_direction(direction)
  if direction == "descending" or direction == "desc" or direction == -1 then
    return "desc"
  end
  return "asc"
end

local function column_key(column, index)
  if type(column) == "table" then
    if column.id ~= nil then return column.id end
    if column.field ~= nil then return column.field end
    if column.key ~= nil then return column.key end
  end
  return index
end

local function row_key(row, index, getRowKey)
  local key
  if getRowKey then
    key = getRowKey(row, index)
  elseif type(row) == "table" then
    key = row.key
    if key == nil then key = row.id end
  end
  if key == nil then key = index end
  return key
end

local function get_column_value(column, row, sourceIndex)
  if type(column) ~= "table" then
    if type(row) == "table" then return row[sourceIndex] end
    return row
  end
  if column.getValue then return column.getValue(row, sourceIndex) end
  if column.value and type(column.value) == "function" then
    return column.value(row, sourceIndex)
  end
  if column.accessor and type(column.accessor) == "function" then
    return column.accessor(row, sourceIndex)
  end
  local field = column.field or column.id
  if type(row) == "table" then
    if field ~= nil then return row[field] end
    return row[column.index or 1]
  end
  return row
end

local function find_column(columns, key)
  if key == nil then return nil end
  for i, column in ipairs(columns) do
    if column_key(column, i) == key then return column, i end
  end
  return nil
end

local function column_is_editable(column)
  return column.editable == true or column.editor == "text"
      or column.editor == "number"
end

local function begin_cell_edit(st, entry, column, columnIndex)
  if st.editing or not column_is_editable(column) then return false end
  st.editSequence = st.editSequence + 1
  local key = column_key(column, columnIndex)
  local value = get_column_value(column, entry.row, entry.sourceIndex)
  local editName = st.ids.editCell .. ":" .. tostring(entry.key) .. ":"
      .. tostring(key) .. ":" .. tostring(st.editSequence)
  st.editing = {
    id = clay.id(editName, 0, false),
    rowKey = entry.key,
    columnKey = key,
    columnIndex = columnIndex,
    sourceIndex = entry.sourceIndex,
    originalValue = value,
    text = value == nil and "" or tostring(value),
    error = nil,
    hasFocus = false,
  }
  return true
end

local function edit_result_value(st, row, column, sourceIndex)
  local editing = st.editing
  local value = editing.text

  if column.parse then
    local parsed, message = column.parse(value, row, sourceIndex)
    if message ~= nil then return false, tostring(message) end
    value = parsed
  elseif column.editor == "number" then
    value = tonumber(value)
    if value == nil then return false, "Enter a valid number" end
  end

  if column.validate then
    local result, detail = column.validate(value, row, editing.originalValue, sourceIndex)
    if result == false then return false, tostring(detail or "Invalid value") end
    if result ~= nil and result ~= true then value = result
    elseif result == true and detail ~= nil then value = detail end
  end
  return true, value
end

local function commit_cell_edit(st, opts)
  local editing = st.editing
  if not editing then return false end

  local row = st.rowsByKey[editing.rowKey]
  local sourceIndex = st.sourceIndexByKey[editing.rowKey] or editing.sourceIndex
  local column, columnIndex = find_column(st.cache.columns, editing.columnKey)
  if not row or not column then
    st.editing = nil
    return false
  end

  local valid, value = edit_result_value(st, row, column, sourceIndex)
  if not valid then
    editing.error = value
    return false
  end

  local oldValue = get_column_value(column, row, sourceIndex)
  if opts.onCellCommit then
    local result, detail = opts.onCellCommit(row, column, value, oldValue,
        editing.rowKey, sourceIndex)
    if result == false then
      editing.error = tostring(detail or "Change rejected")
      return false
    end
    if result ~= nil and result ~= true then value = result
    elseif result == true and detail ~= nil then value = detail end
  end

  if value ~= oldValue then
    if column.setValue then
      local result, detail = column.setValue(row, value, sourceIndex)
      if result == false then
        editing.error = tostring(detail or "Could not update value")
        return false
      end
    else
      local field = column.field or column.id
      local customGetter = column.getValue
          or type(column.value) == "function"
          or type(column.accessor) == "function"
      if customGetter then
        if not opts.onCellCommit then
          editing.error = "Provide setValue or onCellCommit for this column"
          return false
        end
      elseif type(row) == "table" and field ~= nil then
        row[field] = value
      elseif not opts.onCellCommit then
        editing.error = "Provide setValue or onCellCommit for this column"
        return false
      end
    end
  end

  st.cacheDirty = true
  st.editing = nil
  return true
end

local function cancel_cell_edit(st)
  st.editing = nil
end

local function tsv_escape(value)
  if value == nil then return "" end
  local text = tostring(value)
  if text:find('[\t\r\n"]') then
    return '"' .. text:gsub('"', '""') .. '"'
  end
  return text
end

local function copy_selected_rows(st, opts, columns)
  local lines = {}
  local visibleColumns = {}
  for i, column in ipairs(columns) do
    if column.hidden ~= true then
      visibleColumns[#visibleColumns + 1] = { column = column, index = i }
    end
  end

  if opts.copyHeaders then
    local header = {}
    for i, item in ipairs(visibleColumns) do
      local column = item.column
      header[i] = tsv_escape(column.title or column.label or column.name
          or column_key(column, item.index))
    end
    lines[#lines + 1] = table.concat(header, "\t")
  end

  for _, entry in ipairs(st.viewRows) do
    if st.selectedKeys[entry.key] then
      local values = {}
      for i, item in ipairs(visibleColumns) do
        local column = item.column
        local value
        if column.copyValue then value = column.copyValue(entry.row, entry.sourceIndex)
        else value = get_column_value(column, entry.row, entry.sourceIndex) end
        if column.format then value = column.format(value, entry.row, entry.sourceIndex) end
        values[i] = tsv_escape(value)
      end
      lines[#lines + 1] = table.concat(values, "\t")
    end
  end

  if #lines > 0 then window.setClipboardText(table.concat(lines, "\n")) end
end

local function ensure_state(rootKey)
  local st = _tbl_state[rootKey]
  if st then return st end

  local prefix = "TableView" .. tostring(rootKey)
  st = {
    idPrefix = prefix,
    ids = {
      header = prefix .. "Header",
      headerCell = prefix .. "HeaderCell",
      resizeHandle = prefix .. "ResizeHandle",
      row = prefix .. "Row",
      cell = prefix .. "Cell",
      topSpacer = prefix .. "TopSpacer",
      bottomSpacer = prefix .. "BottomSpacer",
      empty = prefix .. "Empty",
      editCell = prefix .. "EditCell",
      body = prefix .. "BodyViewport",
      bodyContent = prefix .. "BodyContent",
      horizontal = prefix .. "HorizontalViewport",
      content = prefix .. "Content",
    },

    widths = {},
    selectedKeys = {},
    selectedRows = {},
    selectedKeyList = {},
    resultRows = {},
    viewRows = {},
    visibleRows = {},
    rowsByKey = {},
    sourceIndexByKey = {},
    viewIndexByKey = {},
    keyDown = {},
    lastLeftDown = false,
    lastRightDown = false,
    focused = false,
    primaryColumnKey = nil,
    editSequence = 0,
    editing = nil,
    sortColumn = nil,
    sortDirection = "asc",
    selectionDirty = false,

    -- Reused result object: tableview is called once per frame in most apps.
    api = {},
  }

  st.api.clearSelection = function()
    local changed = next(st.selectedKeys) ~= nil or st.primaryKey ~= nil
    clear_map(st.selectedKeys)
    st.primaryKey = nil
    st.anchorKey = nil
    if changed then
      st.selectionDirty = true
      st.selectionReason = "programmatic"
    end
  end

  st.api.setSort = function(key, direction)
    st.sortColumn = key
    st.sortDirection = direction and normalize_direction(direction) or "asc"
    st.cacheDirty = true
  end

  st.api.setColumnWidth = function(key, width)
    if type(width) ~= "number" then return end
    st.widths[key] = math.max(1, width)
  end

  _tbl_state[rootKey] = st
  return st
end

local function make_id(st, name, index)
  -- Input is queried before the root builder opens, while elements are
  -- declared several levels below it. Keep these IDs independent of whichever
  -- parent happens to be open at query time; the table root is already baked
  -- into the ID prefix.
  return clay.id(st.ids[name], index or 0, false)
end

local function column_width(st, column, index, opts)
  local key = column_key(column, index)
  local width = st.widths[key]
  if width == nil and opts.columnWidths then width = opts.columnWidths[key] end
  if width == nil and type(column) == "table" then width = column.width end
  local minWidth = type(column) == "table" and tonumber(column.minWidth) or nil
  minWidth = minWidth or tonumber(opts.minColumnWidth) or theme.defaults.tableview.minColumnWidth
  local maxWidth = type(column) == "table" and tonumber(column.maxWidth) or nil
  maxWidth = maxWidth or math.huge
  return clamp(tonumber(width) or 100, minWidth, math.max(minWidth, maxWidth))
end

local function control_down()
  return window.keyDown(window.KEY_LEFT_CONTROL)
      or window.keyDown(window.KEY_RIGHT_CONTROL)
end

local function shift_down()
  return window.keyDown(window.KEY_LEFT_SHIFT)
      or window.keyDown(window.KEY_RIGHT_SHIFT)
end

local function key_went_down(st, key)
  local down = window.keyDown(key)
  local pressed = down and not st.keyDown[key]
  st.keyDown[key] = down
  return pressed
end

local function process_cell_edit_keys(st, opts, columns)
  local f2 = key_went_down(st, window.KEY_F2)

  if st.editing then
    local enter = key_went_down(st, window.KEY_ENTER)
    local escape = key_went_down(st, window.KEY_ESCAPE)
    if escape then
      cancel_cell_edit(st)
    elseif enter then
      commit_cell_edit(st, opts)
    end
    return
  end

  if not (st.focused and f2 and st.primaryKey ~= nil and st.primaryColumnKey ~= nil) then
    return
  end

  local viewIndex = st.viewIndexByKey[st.primaryKey]
  local entry = viewIndex and st.viewRows[viewIndex]
  local column, columnIndex = find_column(columns, st.primaryColumnKey)
  if entry and column then begin_cell_edit(st, entry, column, columnIndex) end
end

local function make_filter_column_set(filterColumns)
  if type(filterColumns) ~= "table" then return nil end
  local set = {}
  for k, v in pairs(filterColumns) do
    if type(k) == "number" then
      set[v] = true
    elseif v then
      set[k] = true
    end
  end
  return set
end

local function value_matches(value, query)
  if value == nil then return false end
  return string.find(string.lower(tostring(value)), query, 1, true) ~= nil
end

local function row_matches(row, sourceIndex, columns, opts, query, filterFn, filterColumnSet)
  if filterFn and not filterFn(row, sourceIndex, query) then return false end
  if query == "" then return true end

  for ci, column in ipairs(columns) do
    local key = column_key(column, ci)
    if column.hidden ~= true and column.filterable ~= false
        and (not filterColumnSet or filterColumnSet[key]) then
      local value
      if column.filterValue then value = column.filterValue(row, sourceIndex)
      else value = get_column_value(column, row, sourceIndex) end
      if value_matches(value, query) then return true end
    end
  end

  return false
end

local function compare_values(a, b, column, rowA, rowB, sourceA, sourceB)
  if column.compare then
    local result = column.compare(a, b, rowA, rowB, sourceA, sourceB)
    if type(result) == "boolean" then
      if result then return -1 end
      local reverse = column.compare(b, a, rowB, rowA, sourceB, sourceA)
      return reverse and 1 or 0
    end
    return tonumber(result) or 0
  end

  if a == b then return 0 end
  if type(a) == "number" and type(b) == "number" then
    return a < b and -1 or 1
  end
  if type(a) == "boolean" and type(b) == "boolean" then
    return a and 1 or -1
  end

  a, b = string.lower(tostring(a)), string.lower(tostring(b))
  if a == b then return 0 end
  return a < b and -1 or 1
end

local function rebuild_view(st, model, columns, opts, query, filterFn)
  local rows = model.rows
  local dataVersion = opts.dataVersion
  if dataVersion == nil then dataVersion = model.version end

  local cache = st.cache
  local cacheMatches = cache
      and not st.cacheDirty
      and cache.rows == rows
      and cache.columns == columns
      and cache.rowCount == #rows
      and cache.dataVersion == dataVersion
      and cache.query == query
      and cache.filterFn == filterFn
      and cache.filterColumns == opts.filterColumns
      and cache.getRowKey == opts.getRowKey
      and cache.sortColumn == st.sortColumn
      and cache.sortDirection == st.sortDirection
  if cacheMatches then return false end

  local viewRows = st.viewRows
  clear_array(viewRows)
  clear_map(st.rowsByKey)
  clear_map(st.sourceIndexByKey)
  clear_map(st.viewIndexByKey)

  local filterColumnSet = make_filter_column_set(opts.filterColumns)
  local viewCount = 0
  for sourceIndex, row in ipairs(rows) do
    local key = row_key(row, sourceIndex, opts.getRowKey)
    if st.rowsByKey[key] ~= nil then
      error("tableview: duplicate row key " .. tostring(key))
    end
    st.rowsByKey[key] = row
    st.sourceIndexByKey[key] = sourceIndex

    if row_matches(row, sourceIndex, columns, opts, query, filterFn, filterColumnSet) then
      viewCount = viewCount + 1
      local entry = viewRows[viewCount] or {}
      entry.row = row
      entry.key = key
      entry.sourceIndex = sourceIndex
      entry.originalIndex = sourceIndex
      viewRows[viewCount] = entry
    end
  end

  local sortColumn = find_column(columns, st.sortColumn)
  if sortColumn and sortColumn.sortable ~= false and opts.sortable ~= false then
    for i = 1, viewCount do
      local entry = viewRows[i]
      if sortColumn.sortValue then
        entry.sortValue = sortColumn.sortValue(entry.row, entry.sourceIndex)
      else
        entry.sortValue = get_column_value(sortColumn, entry.row, entry.sourceIndex)
      end
    end
    table.sort(viewRows, function(a, b)
      local av, bv = a.sortValue, b.sortValue

      -- Keep missing values at the bottom in either direction.
      if av == nil and bv ~= nil then return false end
      if bv == nil and av ~= nil then return true end
      if av == nil and bv == nil then return a.originalIndex < b.originalIndex end

      local cmp = compare_values(av, bv, sortColumn, a.row, b.row, a.sourceIndex, b.sourceIndex)
      if cmp == 0 then return a.originalIndex < b.originalIndex end
      if st.sortDirection == "desc" then return cmp > 0 end
      return cmp < 0
    end)
  end

  for i = 1, viewCount do
    local entry = viewRows[i]
    st.viewIndexByKey[entry.key] = i
    st.resultRows[i] = entry.row
  end
  for i = viewCount + 1, #st.resultRows do st.resultRows[i] = nil end
  st.selectionResultDirty = true

  -- Prune removed rows, but preserve selected rows hidden only by the filter.
  for key in pairs(st.selectedKeys) do
    if st.rowsByKey[key] == nil then
      st.selectedKeys[key] = nil
      st.selectionDirty = true
      st.selectionReason = "data-change"
    end
  end
  if st.primaryKey ~= nil and st.rowsByKey[st.primaryKey] == nil then
    st.primaryKey = nil
    st.selectionDirty = true
    st.selectionReason = "data-change"
  end
  if st.anchorKey ~= nil and st.rowsByKey[st.anchorKey] == nil then
    st.anchorKey = nil
  end

  st.cache = {
    rows = rows,
    columns = columns,
    rowCount = #rows,
    dataVersion = dataVersion,
    query = query,
    filterFn = filterFn,
    filterColumns = opts.filterColumns,
    getRowKey = opts.getRowKey,
    sortColumn = st.sortColumn,
    sortDirection = st.sortDirection,
  }
  st.cacheDirty = false
  return true
end

local function choose_primary(st)
  if st.primaryKey ~= nil and st.selectedKeys[st.primaryKey] then return end
  st.primaryKey = nil
  for i = 1, #st.viewRows do
    local key = st.viewRows[i].key
    if st.selectedKeys[key] then
      st.primaryKey = key
      return
    end
  end
end

local function select_index(st, index, mode, extendRange, toggle)
  local entry = st.viewRows[index]
  if not entry or mode == "none" then return false end

  local key = entry.key
  local changed = false

  if mode ~= "multiple" then
    for oldKey in pairs(st.selectedKeys) do
      if oldKey ~= key then
        st.selectedKeys[oldKey] = nil
        changed = true
      end
    end
    if not st.selectedKeys[key] then
      st.selectedKeys[key] = true
      changed = true
    end
    st.primaryKey = key
    st.anchorKey = key
  elseif extendRange and st.anchorKey ~= nil and st.viewIndexByKey[st.anchorKey] then
    if not toggle then
      for oldKey in pairs(st.selectedKeys) do
        st.selectedKeys[oldKey] = nil
        changed = true
      end
    end
    local anchorIndex = st.viewIndexByKey[st.anchorKey]
    local first = math.min(anchorIndex, index)
    local last = math.max(anchorIndex, index)
    for i = first, last do
      local rangeKey = st.viewRows[i].key
      if not st.selectedKeys[rangeKey] then
        st.selectedKeys[rangeKey] = true
        changed = true
      end
    end
    st.primaryKey = key
  elseif toggle then
    if st.selectedKeys[key] then
      st.selectedKeys[key] = nil
      changed = true
    else
      st.selectedKeys[key] = true
      changed = true
    end
    st.primaryKey = st.selectedKeys[key] and key or nil
    st.anchorKey = key
    choose_primary(st)
  else
    local alreadyOnlyThisKey = st.selectedKeys[key] == true
    if alreadyOnlyThisKey then
      for oldKey in pairs(st.selectedKeys) do
        if oldKey ~= key then alreadyOnlyThisKey = false; break end
      end
    end
    if not alreadyOnlyThisKey then
      for oldKey in pairs(st.selectedKeys) do st.selectedKeys[oldKey] = nil end
      st.selectedKeys[key] = true
      changed = true
    end
    st.primaryKey = key
    st.anchorKey = key
  end

  if changed then
    st.selectionDirty = true
    st.selectionReason = "select"
    st.focused = true
  end
  return changed
end

local function fill_selection_result(st)
  clear_array(st.selectedRows)
  clear_array(st.selectedKeyList)
  local seen = {}

  -- Visible selected rows follow the current sort order.
  for i = 1, #st.viewRows do
    local entry = st.viewRows[i]
    if st.selectedKeys[entry.key] then
      st.selectedRows[#st.selectedRows + 1] = entry.row
      st.selectedKeyList[#st.selectedKeyList + 1] = entry.key
      seen[entry.key] = true
    end
  end

  -- Keep selections outside the current filter in the result as well.
  for i = 1, #st.cache.rows do
    local row = st.cache.rows[i]
    local key = row_key(row, i, st.cache.getRowKey)
    if st.selectedKeys[key] and not seen[key] then
      st.selectedRows[#st.selectedRows + 1] = row
      st.selectedKeyList[#st.selectedKeyList + 1] = key
      seen[key] = true
    end
  end
end

local function invoke_selection_changed(st, opts)
  if not st.selectionDirty and not st.selectionResultDirty then return end
  fill_selection_result(st)
  if st.selectionDirty and opts.onSelectionChanged then
    opts.onSelectionChanged(st.selectedRows, st.selectedKeyList, {
      reason = st.selectionReason or "select",
      key = st.primaryKey,
      row = st.primaryKey ~= nil and st.rowsByKey[st.primaryKey] or nil,
      index = st.primaryKey ~= nil and st.viewIndexByKey[st.primaryKey] or nil,
      sourceIndex = st.primaryKey ~= nil and st.sourceIndexByKey[st.primaryKey] or nil,
    })
  end
  st.selectionDirty = false
  st.selectionReason = nil
  st.selectionResultDirty = false
end

local function process_sort_options(st, opts)
  local sort = opts.sort
  local externalColumn = opts.sortColumn or opts.sortBy or (sort and sort.column)
  local externalDirection = opts.sortDirection or opts.sortOrder or (sort and sort.direction)
  local direction = externalDirection and normalize_direction(externalDirection) or "asc"

  if not st.externalSortInitialized
      or externalColumn ~= st.externalSortColumn
      or externalDirection ~= st.externalSortDirection then
    st.sortColumn = externalColumn
    st.sortDirection = direction
    st.cacheDirty = true
    st.externalSortInitialized = true
    st.externalSortColumn = externalColumn
    st.externalSortDirection = externalDirection
  end
end

local function process_header_input(st, columns, opts, leftPressed, leftReleased, leftDown, mouseX)
  if st.resize and opts.resizableColumns == false then st.resize = nil end

  if st.resize then
    local resize = st.resize
    local minWidth = tonumber(resize.column.minWidth)
        or tonumber(opts.minColumnWidth) or theme.defaults.tableview.minColumnWidth
    local maxWidth = tonumber(resize.column.maxWidth) or math.huge
    maxWidth = math.max(minWidth, maxWidth)
    local width = clamp(resize.startWidth + mouseX - resize.startX, minWidth, maxWidth)
    st.widths[resize.key] = width
    if leftReleased then
      if opts.onColumnResize then opts.onColumnResize(resize.column, width) end
      st.resize = nil
    elseif not leftDown then
      st.resize = nil
    end
    return
  end

  if leftPressed then
    for ci, column in ipairs(columns) do
      if column.hidden ~= true then
        local key = column_key(column, ci)
        local canResize = opts.resizableColumns ~= false and column.resizable ~= false
        local handleId = make_id(st, "resizeHandle", ci)
        if canResize and clay.pointerOver(handleId) then
          local width = column_width(st, column, ci, opts)
          st.widths[key] = width
          st.resize = {
            key = key,
            column = column,
            startX = mouseX,
            startWidth = width,
          }
          return
        end

        local headerId = make_id(st, "headerCell", ci)
        if clay.pointerOver(headerId) then
          st.pressedHeader = { key = key, column = column, index = ci }
          return
        end
      end
    end
  end

  if leftReleased and st.pressedHeader then
    local pressed = st.pressedHeader
    st.pressedHeader = nil
    local headerId = make_id(st, "headerCell", pressed.index)
    if clay.pointerOver(headerId)
        and opts.sortable ~= false
        and pressed.column.sortable ~= false then
      if st.sortColumn == pressed.key then
        st.sortDirection = st.sortDirection == "asc" and "desc" or "asc"
      else
        st.sortColumn = pressed.key
        st.sortDirection = "asc"
      end
      st.cacheDirty = true
      if opts.onSortChanged then
        opts.onSortChanged(st.sortColumn, st.sortDirection, pressed.column)
      end
    end
  end
end

local function draw_keyboard_selection(st, opts, mode)
  local up = key_went_down(st, window.KEY_UP)
  local down = key_went_down(st, window.KEY_DOWN)
  local pageUp = key_went_down(st, window.KEY_PAGE_UP)
  local pageDown = key_went_down(st, window.KEY_PAGE_DOWN)
  local home = key_went_down(st, window.KEY_HOME)
  local finish = key_went_down(st, window.KEY_END)
  local enter = key_went_down(st, window.KEY_ENTER)
  local selectAll = key_went_down(st, window.KEY_A)
  local copy = key_went_down(st, window.KEY_C)

  if st.editing or not st.focused then return nil end
  if copy and control_down() then copy_selected_rows(st, opts, st.cache.columns) end
  if opts.keyboardNavigation == false then return nil end

  local count = #st.viewRows
  if count == 0 then return nil end
  local current = st.primaryKey and st.viewIndexByKey[st.primaryKey] or nil
  local target = current

  if mode == "multiple" and selectAll and control_down() then
    local changed = false
    for i = 1, count do
      local key = st.viewRows[i].key
      if not st.selectedKeys[key] then
        st.selectedKeys[key] = true
        changed = true
      end
    end
    if changed then
      st.primaryKey = st.viewRows[current or 1].key
      st.selectionDirty = true
      st.selectionReason = "select-all"
    end
  elseif up or down or pageUp or pageDown or home or finish then
    if not target then target = 1 end
    if home then target = 1
    elseif finish then target = count
    elseif up then target = target - 1
    elseif down then target = target + 1
    elseif pageUp then target = target - 10
    elseif pageDown then target = target + 10 end
    target = clamp(target, 1, count)
    select_index(st, target, mode, shift_down(), control_down())
  elseif enter and current then
    local entry = st.viewRows[current]
    return { kind = "activate", entry = entry, index = current }
  end

  return nil
end

local function get_viewport_data(viewportId)
  if not viewportId then return nil end
  local data = clay.getScrollContainerData(viewportId)
  if not data or not data.found then return nil end
  return data
end

local function visible_range(st, opts, internalScroll, bodyId, rowHeight, headerHeight, rootId, tableHeight)
  local viewportId = internalScroll and bodyId or opts.viewport_id
  local data = get_viewport_data(viewportId)
  local viewHeight, scrollY

  if data then
    local dimensions = data.scrollContainerDimensions or data.dimensions
    viewHeight = dimensions and dimensions.height or nil
    scrollY = data.scrollPosition and math.max(0, -(data.scrollPosition.y or 0)) or 0
    if not internalScroll then
      -- In a shared page viewport, use this table's screen position instead
      -- of the page-wide scroll offset so preceding content is not virtualized
      -- as if it were part of this table.
      local tableBox = clay.getElementData(rootId)
      local viewportBox = clay.getElementData(viewportId)
      if tableBox and tableBox.found and viewportBox and viewportBox.found then
        scrollY = math.max(0, viewportBox.y - tableBox.y - headerHeight)
      else
        scrollY = math.max(0, scrollY - headerHeight)
      end
    end
  elseif internalScroll then
    viewHeight = math.max(1, (tableHeight or headerHeight + rowHeight) - headerHeight)
    scrollY = 0
  elseif opts.viewportHeight then
    viewHeight = math.max(1, opts.viewportHeight - headerHeight)
    scrollY = 0
  end

  local count = #st.viewRows
  if not viewHeight then return 1, count, nil end

  local first = math.max(1, math.floor(scrollY / rowHeight) + 1)
  local onScreen = math.ceil(viewHeight / rowHeight)
  local overscan = math.max(0, math.floor(opts.overscan or TABLE_DEFAULT.overscan))
  first = math.max(1, first - overscan)
  local last = math.min(count, first + onScreen + overscan * 2 - 1)
  return first, last, viewHeight
end

local function keep_primary_visible(st, bodyId, rowHeight)
  local index = st.primaryKey ~= nil and st.viewIndexByKey[st.primaryKey] or nil
  if not index then return end

  local data = get_viewport_data(bodyId)
  if not data then return end
  local viewportHeight = data.scrollContainerDimensions
      and data.scrollContainerDimensions.height
  if not viewportHeight or viewportHeight <= 0 then return end

  local scrollY = data.scrollPosition and -(data.scrollPosition.y or 0) or 0
  local rowTop = (index - 1) * rowHeight
  local nextScrollY = scrollY
  if rowTop < scrollY then
    nextScrollY = rowTop
  elseif rowTop + rowHeight > scrollY + viewportHeight then
    nextScrollY = rowTop + rowHeight - viewportHeight
  end

  if nextScrollY ~= scrollY then
    local scrollX = data.scrollPosition and (data.scrollPosition.x or 0) or 0
    clay.setScrollOffset(bodyId, scrollX, -math.max(0, nextScrollY))
  end
end

local function draw_header(st, columns, opts, fontId, fontSize, headerHeight, contentWidth, colors)
  local headerId = make_id(st, "header")
  clay.element(headerId)
    :layoutDirection(clay.LEFT_TO_RIGHT)
    :width(clay.SIZING_FIXED, contentWidth)
    :height(clay.SIZING_FIXED, headerHeight)
    :childGap(0)
    :childAlignment(clay.ALIGN_X_LEFT, clay.ALIGN_Y_CENTER)
    :backgroundColor(C(colors.header))
    :borderColor(C(colors.grid))
    :borderWidth(0, 0, 0, 1)
    :children(function()
      for ci, column in ipairs(columns) do
        if column.hidden ~= true then
          local key = column_key(column, ci)
          local width = column_width(st, column, ci, opts)
          local headerId = make_id(st, "headerCell", ci)
          local resizeId = make_id(st, "resizeHandle", ci)
          local hovered = clay.pointerOver(headerId)
          local canSort = opts.sortable ~= false and column.sortable ~= false
          local canResize = opts.resizableColumns ~= false and column.resizable ~= false
          local title = column.title or column.label or column.name or tostring(key)
          local indicator = ""
          if st.sortColumn == key then
            indicator = st.sortDirection == "desc" and "  ↓" or "  ↑"
          end

          clay.element(headerId)
            :layoutDirection(clay.LEFT_TO_RIGHT)
            :width(clay.SIZING_FIXED, width)
            :height(clay.SIZING_GROW)
            :childGap(0)
            :childAlignment(clay.ALIGN_X_LEFT, clay.ALIGN_Y_CENTER)
            :padding(theme.defaults.tableview.headerPadL, 0, theme.defaults.tableview.headerPadR, 0)
            :backgroundColor(C(hovered and canSort and colors.headerHover or colors.header))
            :borderColor(C(colors.grid))
            :borderWidth(0, 0, 1, 0)
            :children(function()
              if column.headerRenderer then
                column.headerRenderer(column, st.sortColumn == key and st.sortDirection or nil)
              else
                clay.text(tostring(title) .. indicator)
                  :fontId(fontId)
                  :fontSize(fontSize)
                  :textColor(C(st.sortColumn == key and colors.headerSort or colors.headerText))
                  :wrapMode(clay.TEXT_WRAP_NONE)
                  :done()
              end

              if canResize then
                clay.element(make_id(st, "empty", ci))
                  :width(clay.SIZING_GROW)
                  :height(clay.SIZING_FIXED, 1)
                  :close()

                local resizing = st.resize and st.resize.key == key
                local resizeHovered = clay.pointerOver(resizeId)
                clay.element(resizeId)
                  :width(clay.SIZING_FIXED, theme.defaults.tableview.resizeHandleWidth)
                  :height(clay.SIZING_GROW)
                  :backgroundColor(C((resizing or resizeHovered) and colors.resizeHover or colors.resize))
                  :pointerCaptureMode(clay.POINTER_CAPTURE_MODE_CAPTURE)
                  :close()
              end
            end)
        end
      end
    end)
end

local function draw_rows(st, columns, opts, firstIndex, lastIndex, rowHeight, contentWidth, fontId, fontSize, colors)
  local total = #st.viewRows
  local clicked = nil
  local releasedCell = nil
  local contexted = nil
  local leftPressed = not st.lastLeftDown and window.mouseButtonDown(window.MOUSE_BUTTON_LEFT)
  local leftDown = window.mouseButtonDown(window.MOUSE_BUTTON_LEFT)
  local leftReleased = st.lastLeftDown and not leftDown
  local rightDown = window.mouseButtonDown(window.MOUSE_BUTTON_RIGHT)
  local rightPressed = not st.lastRightDown and rightDown
  local rightReleased = st.lastRightDown and not rightDown
  local mouseX, mouseY = window.mousePosition()

  if firstIndex > 1 then
    clay.element(make_id(st, "topSpacer"))
      :width(clay.SIZING_FIXED, contentWidth)
      :height(clay.SIZING_FIXED, (firstIndex - 1) * rowHeight)
      :close()
  end

  if total == 0 then
    clay.element(make_id(st, "empty"))
      :width(clay.SIZING_FIXED, contentWidth)
      :height(clay.SIZING_FIXED, rowHeight)
      :childAlignment(clay.ALIGN_X_CENTER, clay.ALIGN_Y_CENTER)
      :children(function()
        clay.text(opts.emptyText or "No rows")
          :fontId(fontId)
          :fontSize(fontSize)
          :textColor(C(colors.emptyText))
          :done()
      end)
  else
    for viewIndex = firstIndex, lastIndex do
      local entry = st.viewRows[viewIndex]
      local row = entry.row
      local isSelected = st.selectedKeys[entry.key] == true
      local rowId = make_id(st, "row", viewIndex)
      local hovered = clay.pointerOver(rowId)
      local zebra = opts.zebra ~= false and (viewIndex % 2 == 0) and colors.rowAlt or nil
      local background = isSelected and colors.rowSelBg
          or (hovered and colors.rowHover)
          or zebra

      if leftPressed and hovered then
        st.pressedRowKey = entry.key
        st.pressedRowIndex = viewIndex
      end
      if rightPressed and hovered then
        st.pressedRightRowKey = entry.key
        st.pressedRightRowIndex = viewIndex
      end

      clay.element(rowId)
        :layoutDirection(clay.LEFT_TO_RIGHT)
        :width(clay.SIZING_FIXED, contentWidth)
        :height(clay.SIZING_FIXED, rowHeight)
        :childGap(0)
        :childAlignment(clay.ALIGN_X_LEFT, clay.ALIGN_Y_CENTER)
        :backgroundColor(background and background.r or 0,
            background and background.g or 0,
            background and background.b or 0,
            background and background.a or 0)
        :children(function()
          for ci, column in ipairs(columns) do
            if column.hidden ~= true then
              local width = column_width(st, column, ci, opts)
              local cellIndex = (viewIndex * 1000) + ci
              local cellId = make_id(st, "cell", cellIndex)
              local key = column_key(column, ci)
              local cellHovered = clay.pointerOver(cellId)
              if leftPressed and cellHovered then
                st.pressedCell = { rowKey = entry.key, columnKey = key, columnIndex = ci }
              end
              if leftReleased and cellHovered and st.pressedCell
                  and st.pressedCell.rowKey == entry.key
                  and st.pressedCell.columnKey == key then
                releasedCell = { column = column, columnKey = key, columnIndex = ci }
              end
              local editingCell = st.editing and st.editing.rowKey == entry.key
                  and st.editing.columnKey == key
              local primaryCell = st.focused and st.primaryKey == entry.key
                  and st.primaryColumnKey == key
              local xAlign = clay.ALIGN_X_LEFT
              if column.align == "center" then xAlign = clay.ALIGN_X_CENTER
              elseif column.align == "right" then xAlign = clay.ALIGN_X_RIGHT end

              clay.element(cellId)
                :layoutDirection(clay.LEFT_TO_RIGHT)
                :width(clay.SIZING_FIXED, width)
                :height(clay.SIZING_GROW)
                :childAlignment(xAlign, clay.ALIGN_Y_CENTER)
                :padding(theme.defaults.tableview.cellPadL, 0, theme.defaults.tableview.cellPadR, 0)
                :borderColor(C(primaryCell and (colors.cellFocus or colors.headerSort) or colors.grid))
                :borderWidth(primaryCell and 1 or 0, primaryCell and 1 or 0,
                    primaryCell and 1 or 0, 1)
                :children(function()
                  if editingCell then
                    local editColors
                    if st.editing.error then
                      editColors = {
                        border = { r = 255, g = 96, b = 96, a = 255 },
                        bg = { r = 65, g = 30, b = 35, a = 255 },
                        bgAct = { r = 75, g = 34, b = 40, a = 255 },
                      }
                    end
                    local editedText, _, focused = clay.edit(st.editing.id,
                        st.editing.text, {
                          width = math.max(1, width - theme.defaults.tableview.cellPadL - theme.defaults.tableview.cellPadR),
                          height = rowHeight,
                          pad = theme.defaults.edit.padding,
                          fontId = fontId,
                          fontSize = fontSize,
                          maxChars = column.maxChars or 2000,
                          filter = column.inputFilter,
                          colors = editColors,
                          focusOnCreate = true,
                        })
                    st.editing.text = editedText
                    if focused then
                      st.editing.hasFocus = true
                      st.editing.lostFocus = false
                    elseif st.editing.hasFocus then
                      st.editing.lostFocus = true
                    end
                  else
                    local renderer = column.cellRenderer or opts.cellRenderer
                    if renderer then
                      renderer(column, row, viewIndex, ci, entry.sourceIndex, isSelected, cellId)
                    else
                      local value = get_column_value(column, row, entry.sourceIndex)
                      if column.format then value = column.format(value, row, entry.sourceIndex) end
                      clay.text(value == nil and "" or tostring(value))
                        :fontId(fontId)
                        :fontSize(fontSize)
                        :textColor(C(isSelected and colors.rowSelTxt or colors.rowText))
                        :wrapMode(clay.TEXT_WRAP_NONE)
                        :done()
                    end
                  end
                end)
            end
          end
        end)

      if leftReleased and st.pressedRowKey == entry.key and hovered then
        clicked = { entry = entry, index = viewIndex, cell = releasedCell }
      end
      if rightReleased and st.pressedRightRowKey == entry.key and hovered then
        contexted = { entry = entry, index = viewIndex }
      end
    end
  end

  if total > lastIndex then
    clay.element(make_id(st, "bottomSpacer"))
      :width(clay.SIZING_FIXED, contentWidth)
      :height(clay.SIZING_FIXED, (total - lastIndex) * rowHeight)
      :close()
  end

  if leftReleased then
    st.pressedRowKey = nil
    st.pressedRowIndex = nil
    st.pressedCell = nil
  end
  if rightReleased then
    st.pressedRightRowKey = nil
    st.pressedRightRowIndex = nil
  end

  if clicked then
    local entry, index = clicked.entry, clicked.index
    local mode = opts.selectionMode or "single"
    local ctrl = control_down()
    local shift = shift_down()
    select_index(st, index, mode, shift, ctrl)
    st.focused = true
    if clicked.cell then st.primaryColumnKey = clicked.cell.columnKey end

    if opts.onRowClick then
      opts.onRowClick(entry.row, index, entry.key, entry.sourceIndex)
    end
    local now = window.time()
    local doubleClick = st.lastClickKey == entry.key
        and now - (st.lastClickTime or 0) <= (opts.doubleClickTime or TABLE_DEFAULT.doubleClickTime)
    local sameCellDoubleClick = doubleClick and clicked.cell
        and st.lastClickColumnKey == clicked.cell.columnKey
    if doubleClick then
      local editStarted = false
      if sameCellDoubleClick and clicked.cell.column.editOnDoubleClick ~= false then
        editStarted = begin_cell_edit(st, entry, clicked.cell.column, clicked.cell.columnIndex)
      end
      -- An invalid editor can remain open after a failed click-away commit.
      -- Do not activate/open another row while that edit still needs fixing.
      if not editStarted and not st.editing and opts.onDoubleClick then
        opts.onDoubleClick(entry.row, index, entry.key, entry.sourceIndex)
      elseif not editStarted and not st.editing and not opts.onDoubleClick and opts.onActivate then
        opts.onActivate(entry.row, index, entry.key, entry.sourceIndex)
      end
      st.lastClickKey = nil
      st.lastClickColumnKey = nil
      st.lastClickTime = 0
    else
      st.lastClickKey = entry.key
      st.lastClickColumnKey = clicked.cell and clicked.cell.columnKey or nil
      st.lastClickTime = now
    end

    st.clickedIndex = index
    st.clickedRow = entry.row
    st.clickedKey = entry.key
  end

  if st.editing and st.editing.lostFocus then
    st.editing.lostFocus = false
    commit_cell_edit(st, opts)
  end

  if contexted and opts.onContextMenu then
    local entry, index = contexted.entry, contexted.index
    opts.onContextMenu(entry.row, index, entry.key, entry.sourceIndex, mouseX, mouseY)
  end
end

-- tableview(elid, model, opts) -> reusable result/API table
-- model = { columns = {...}, rows = {...}, version = optionalRevision }
--
-- Column fields: id/field, title, width, minWidth, maxWidth, hidden,
-- sortable, resizable, filterable, align, getValue/accessor, sortValue,
-- compare (boolean less-than or -1/0/1), filterValue, format,
-- headerRenderer, cellRenderer, editable/editor ("text" or "number"),
-- inputFilter, parse, validate, setValue, copyValue.
-- editable=true defaults to a text editor. parse(raw,row,sourceIndex) may
-- return value[, error]; validate(value,row,oldValue,sourceIndex) may return
-- false,error to reject or a replacement value. setValue(row,value,index) is
-- needed for custom getters; onCellCommit(row,column,value,old,key,index) may
-- reject with false,error or return a replacement value.
--
-- Options: rowHeight, headerHeight, height, viewport_id, dataVersion,
-- filter/filterFn/filterColumns, getRowKey, sortColumn/sortDirection,
-- selectionMode = "single" | "multiple" | "none", cellRenderer,
-- onSelectionChanged, onRowClick, onActivate, onDoubleClick, onContextMenu,
-- onCellCommit, onSortChanged, onColumnResize, copyHeaders. Select a row cell
-- then press F2 to edit it; double-click an editable cell to edit unless
-- editOnDoubleClick=false. Enter commits, Escape cancels, and clicking away
-- commits. Text cells support the edit widget's Ctrl+V paste. Ctrl+C copies
-- selected visible rows as TSV, optionally including headers.
-- onActivate runs for Enter, or for row double-click when no onDoubleClick
-- callback is supplied. onRowClick is the single-click callback. The returned
-- api.rows is the sorted/filtered row list; api.entries includes row keys and
-- source indexes, while api.visibleRows contains just the rendered window.
-- api.editingCell exposes the current edit draft and any validation error.
-- Attach clay.scrollbar(api.horizontalViewportId, api.contentId, wheelX,
-- { horizontal = true }) when a visible horizontal scrollbar is desired.
--
-- Supplying height creates a fixed-header vertical viewport. The table also
-- clips horizontally, keeping the header and rows aligned while scrolling.
-- Otherwise viewport_id may point at an external scroll container for
-- virtualization. Increment model.version or pass dataVersion when mutating
-- rows/columns in place so cached sorting/filtering is refreshed. Keep row
-- keys unique and stable when reordering data.
function tableview(elid, model, opts)
  opts = opts or {}
  model = model or {}
  local columns = assert(model.columns, "tableview: model.columns required")
  local rows = assert(model.rows, "tableview: model.rows required")
  local rootKey = elid.id
  local st = ensure_state(rootKey)

  local rowHeight = math.max(1, tonumber(opts.rowHeight) or (theme.spacing.controlHeight - 8))
  local headerHeight = math.max(1, tonumber(opts.headerHeight) or theme.spacing.controlHeight)
  local requestedHeight = tonumber(opts.height)
  local tableHeight = requestedHeight and math.max(headerHeight + 1, requestedHeight) or nil
  local fontId = opts.fontId or theme.defaults.tableview.fontId
  local fontSize = opts.fontSize or theme.type.small
  local selectionMode = opts.selectionMode or "single"
  if selectionMode ~= "multiple" and selectionMode ~= "none" then selectionMode = "single" end

  for i, column in ipairs(columns) do
    assert(type(column) == "table", "tableview: column " .. i .. " must be a table")
  end

  local defaults = theme.colors.tableview
  local colors = opts.colors or defaults
  local resolvedColors = st.colors or {}
  st.colors = resolvedColors
  resolvedColors.bg = colors.bg or defaults.bg
  resolvedColors.header = colors.header or defaults.header
  resolvedColors.headerText = colors.headerText or defaults.headerText
  resolvedColors.headerHover = colors.headerHover or defaults.headerHover
  resolvedColors.headerSort = colors.headerSort or defaults.headerSort
  resolvedColors.resize = colors.resize or defaults.resize
  resolvedColors.resizeHover = colors.resizeHover or defaults.resizeHover
  resolvedColors.rowAlt = colors.rowAlt or defaults.rowAlt
  resolvedColors.rowHover = colors.rowHover or defaults.rowHover
  resolvedColors.rowSelBg = colors.rowSelBg or defaults.rowSelBg
  resolvedColors.rowText = colors.rowText or defaults.rowText
  resolvedColors.rowSelTxt = colors.rowSelTxt or defaults.rowSelTxt
  resolvedColors.grid = colors.grid or defaults.grid
  resolvedColors.emptyText = colors.emptyText or defaults.emptyText

  process_sort_options(st, opts)

  local leftDown = window.mouseButtonDown(window.MOUSE_BUTTON_LEFT)
  local leftPressed = leftDown and not st.lastLeftDown
  local leftReleased = not leftDown and st.lastLeftDown
  local mouseX = window.mousePosition()

  if leftPressed and not clay.pointerOver(elid) then st.focused = false end
  process_header_input(st, columns, opts, leftPressed, leftReleased, leftDown, mouseX)

  local filterOpt = opts.filter
  local query = type(filterOpt) == "string" and string.lower(filterOpt) or ""
  local filterFn = opts.filterFn or opts.rowFilter
  if not filterFn and type(filterOpt) == "function" then filterFn = filterOpt end
  local oldPrimaryKey = st.primaryKey
  local oldPrimaryIndex = oldPrimaryKey ~= nil and st.viewIndexByKey[oldPrimaryKey] or nil
  local viewChanged = rebuild_view(st, model, columns, opts, query, filterFn)
  if st.editing and st.viewIndexByKey[st.editing.rowKey] == nil then
    if not commit_cell_edit(st, opts) then cancel_cell_edit(st) end
  end

  local internalScroll = tableHeight ~= nil
  local bodyId = opts.body_viewport_id or make_id(st, "body")
  local bodyContentId = opts.body_content_id or make_id(st, "bodyContent")
  local horizontalId = opts.horizontal_viewport_id or make_id(st, "horizontal")
  local contentId = opts.content_id or make_id(st, "content")

  local contentWidth = 0
  for ci, column in ipairs(columns) do
    if column.hidden ~= true then
      contentWidth = contentWidth + column_width(st, column, ci, opts)
    end
  end
  local rootData = clay.getElementData(elid)
  if rootData and rootData.found then contentWidth = math.max(contentWidth, rootData.width) end
  contentWidth = math.max(1, contentWidth)

  local bodyHeight = internalScroll and math.max(1, tableHeight - headerHeight) or nil
  local rowsContentHeight = math.max(rowHeight, #st.viewRows * rowHeight)
  local contentHeight = internalScroll and tableHeight or (headerHeight + rowsContentHeight)

  process_cell_edit_keys(st, opts, columns)
  local keyboardEvent = draw_keyboard_selection(st, opts, selectionMode)
  if keyboardEvent and keyboardEvent.kind == "activate" then
    local entry, index = keyboardEvent.entry, keyboardEvent.index
    if opts.onActivate then opts.onActivate(entry.row, index, entry.key, entry.sourceIndex) end
  end
  local primaryIndex = st.primaryKey ~= nil and st.viewIndexByKey[st.primaryKey] or nil
  if internalScroll and (st.primaryKey ~= oldPrimaryKey
      or (viewChanged and primaryIndex ~= oldPrimaryIndex)) then
    keep_primary_visible(st, bodyId, rowHeight)
  end

  local firstIndex, lastIndex = visible_range(st, opts, internalScroll, bodyId,
      rowHeight, headerHeight, elid, tableHeight)

  local root = clay.element(elid)
    :layoutDirection(clay.TOP_TO_BOTTOM)
    :width(clay.SIZING_GROW)
    :childGap(0)
    :backgroundColor(C(resolvedColors.bg))
  if tableHeight ~= nil then
    root:height(clay.SIZING_FIXED, tableHeight)
  else
    root:height(clay.SIZING_FIT)
  end

  root:children(function()
    local horizontal = clay.element(horizontalId)
      :layoutDirection(clay.TOP_TO_BOTTOM)
      :width(clay.SIZING_GROW)
      :childGap(0)
      :clip(true, false)
    if tableHeight then horizontal:height(clay.SIZING_GROW)
    else horizontal:height(clay.SIZING_FIT) end

    horizontal:children(function()
      clay.element(contentId)
        :layoutDirection(clay.TOP_TO_BOTTOM)
        :width(clay.SIZING_FIXED, contentWidth)
        :height(clay.SIZING_FIXED, contentHeight)
        :childGap(0)
        :children(function()
          draw_header(st, columns, opts, fontId, fontSize, headerHeight, contentWidth, resolvedColors)

          if internalScroll then
            clay.element(bodyId)
              :layoutDirection(clay.TOP_TO_BOTTOM)
              :width(clay.SIZING_FIXED, contentWidth)
              :height(clay.SIZING_FIXED, bodyHeight)
              :clip(false, true)
              :children(function()
                clay.element(bodyContentId)
                  :layoutDirection(clay.TOP_TO_BOTTOM)
                  :width(clay.SIZING_FIXED, contentWidth)
                  :height(clay.SIZING_FIXED, rowsContentHeight)
                  :children(function()
                    draw_rows(st, columns, opts, firstIndex, lastIndex,
                        rowHeight, contentWidth, fontId, fontSize, resolvedColors)
                  end)
              end)
          else
            clay.element(bodyContentId)
              :layoutDirection(clay.TOP_TO_BOTTOM)
              :width(clay.SIZING_FIXED, contentWidth)
              :height(clay.SIZING_FIXED, rowsContentHeight)
              :children(function()
                draw_rows(st, columns, opts, firstIndex, lastIndex,
                    rowHeight, contentWidth, fontId, fontSize, resolvedColors)
              end)
          end
        end)
    end)
  end)

  invoke_selection_changed(st, opts)
  st.lastLeftDown = leftDown
  st.lastRightDown = window.mouseButtonDown(window.MOUSE_BUTTON_RIGHT)

  local api = st.api
  api.rowCount = #rows
  api.filteredCount = #st.viewRows
  api.visibleCount = math.max(0, lastIndex - firstIndex + 1)
  clear_array(st.visibleRows)
  for i = firstIndex, lastIndex do
    local entry = st.viewRows[i]
    if entry then st.visibleRows[#st.visibleRows + 1] = entry.row end
  end
  api.rows = st.resultRows
  api.entries = st.viewRows
  api.visibleRows = st.visibleRows
  api.selectedRows = st.selectedRows
  api.selectedKeys = st.selectedKeyList
  api.selectedKey = st.primaryKey
  api.selectedRow = st.primaryKey ~= nil and st.rowsByKey[st.primaryKey] or nil
  api.selectedIndex = st.primaryKey ~= nil and st.viewIndexByKey[st.primaryKey] or nil
  api.selectedSourceIndex = st.primaryKey ~= nil and st.sourceIndexByKey[st.primaryKey] or nil
  api.primaryColumnKey = st.primaryColumnKey
  api.editingCell = st.editing
  api.sortColumn = st.sortColumn
  api.sortDirection = st.sortColumn ~= nil and st.sortDirection or nil
  api.columnWidths = st.widths
  api.bodyViewportId = internalScroll and bodyId or opts.viewport_id
  api.bodyContentId = bodyContentId
  api.horizontalViewportId = horizontalId
  api.contentId = contentId
  api.clickedIndex = st.clickedIndex
  api.clickedRow = st.clickedRow
  api.clickedKey = st.clickedKey
  st.clickedIndex, st.clickedRow, st.clickedKey = nil, nil, nil
  return api
end
