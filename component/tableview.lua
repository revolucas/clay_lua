-- component/tableview.lua
local clay = require("clay")
local glfw = require("ffi.ffi_glfw")

local _tbl_state          = _tbl_state          or {} -- [rootKey] -> { selectedRow }
local _tbl_mouse_was_down = _tbl_mouse_was_down or false
local _tbl_pressed_row    = _tbl_pressed_row    or {}

local function C(c) return c.r, c.g, c.b, c.a end

-- defaults
local TABLE_DEFAULT = {
  rowHeight    = 22,
  headerHeight = 24,
  fontId       = 1,
  fontSize     = 14,
  viewport_id  = nil,

  colors = {
    bg         = { r=0,   g=0,   b=0,   a=0   },
    header     = { r=34,  g=37,  b=45,  a=255 },
    headerText = { r=210, g=210, b=220, a=255 },
    rowAlt     = { r=255, g=255, b=255, a=6   },
    rowHover   = { r=255, g=255, b=255, a=18  },
    rowSelBg   = { r=60,  g=90,  b=140, a=180 },
    rowText    = { r=230, g=230, b=240, a=255 },
    rowSelTxt  = { r=255, g=255, b=255, a=255 },
  },

  headerPadL = 6,
  headerPadR = 6,
  cellPadL   = 4,
  cellPadR   = 4,
}

local function ensure_state(rootKey)
  local st = _tbl_state[rootKey]
  if not st then
    st = { selectedRow = nil }
    _tbl_state[rootKey] = st
  end
  return st
end

-- tableview(elid, model, opts) -> api
-- model = { columns = {...}, rows = {...} }
-- opts = {
--   rowHeight, headerHeight, fontId, fontSize, viewport_id,
--   colors = { ... },
--   cellRenderer = function(colDef, row, rowIndex, colIndex) ... end,
--   onActivate   = function(row, rowIndex) end,
-- }
function tableview(elid, model, opts)
  local cols = assert(model.columns, "tableview: model.columns required")
  local rows = assert(model.rows,    "tableview: model.rows required")

  local def = TABLE_DEFAULT

  local rowH     = (opts and opts.rowHeight)    or def.rowHeight
  local headerH  = (opts and opts.headerHeight) or def.headerHeight
  local fontId   = (opts and opts.fontId)       or def.fontId
  local fontSize = (opts and opts.fontSize)     or def.fontSize
  local viewport_id = (opts and opts.viewport_id) or def.viewport_id

  local dcol = def.colors
  local col  = (opts and opts.colors) or nil

  local c_bg         = (col and col.bg)         or dcol.bg
  local c_header     = (col and col.header)     or dcol.header
  local c_headerText = (col and col.headerText) or dcol.headerText
  local c_rowBgAlt   = (col and col.rowAlt)     or dcol.rowAlt
  local c_rowHover   = (col and col.rowHover)   or dcol.rowHover
  local c_rowSelBg   = (col and col.rowSelBg)   or dcol.rowSelBg
  local c_rowText    = (col and col.rowText)    or dcol.rowText
  local c_rowSelTxt  = (col and col.rowSelTxt)  or dcol.rowSelTxt

  -- mouse state (release-based)
  local down     = (glfw.GetMouseButton(device.win, glfw.MOUSE_BUTTON_LEFT) == glfw.PRESS)
  local was_down = _tbl_mouse_was_down
  local released = (was_down and not down)
  _tbl_mouse_was_down = down

  local rootKey = elid.id
  local st = ensure_state(rootKey)

  -- virtualization via scroll container
  local viewH, scrollY = nil, 0
  if viewport_id then
    local scd = clay.getScrollContainerData(viewport_id)
    if scd and scd.found and scd.scrollPosition and scd.dimensions then
      viewH   = scd.dimensions.height
      scrollY = math.max(0, -scd.scrollPosition.y)
    end
  end

  local total  = #rows
  local firstIdx, lastIdx = 1, total
  if viewH then
    local rowsVisible = math.max(0, viewH - headerH)
    local rowOffset   = math.max(0, scrollY - headerH)

    if rowOffset < 0 then
      firstIdx = 1
    else
      firstIdx = math.max(1, math.floor(rowOffset / rowH) + 1)
    end

    local onScreen = math.ceil(rowsVisible / rowH) + 2
    lastIdx = math.min(total, firstIdx + onScreen)
  end

  local clickedRow = nil

  -- ids (stable)
  local headerId = clay.id("TableHeader", rootKey, true)
  local topSpacerId = clay.id("TblTopSpacer", rootKey, true)
  local botSpacerId = clay.id("TblBotSpacer", rootKey, true)

  -- ROOT
  clay.element(elid)
    :layoutDirection(clay.TOP_TO_BOTTOM)
    :width(clay.SIZING_GROW)
    :height(clay.SIZING_FIT)
    :childGap(0)
    :backgroundColor(C(c_bg))
    :children(function()
      ----------------------------------------------------------------
      -- HEADER ROW
      ----------------------------------------------------------------
      clay.element(headerId)
        :layoutDirection(clay.LEFT_TO_RIGHT)
        :width(clay.SIZING_GROW)
        :height(clay.SIZING_FIXED, headerH)
        :childGap(0)
        :childAlignment(clay.ALIGN_X_LEFT, clay.ALIGN_Y_CENTER)
        :padding(def.headerPadL, 0, def.headerPadR, 0)
        :backgroundColor(C(c_header))
        :children(function()
          for ci, colDef in ipairs(cols) do
            local w = (colDef.width or 100)
            local title = colDef.title or colDef.label or colDef.id or tostring(colDef)
            local thId = clay.id("Th", rootKey * 100000 + ci, true)

            clay.element(thId)
              :width(clay.SIZING_FIXED, w)
              :height(clay.SIZING_GROW)
              :childAlignment(clay.ALIGN_X_LEFT, clay.ALIGN_Y_CENTER)
              :padding(def.cellPadL, 0, def.cellPadR, 0)
              :children(function()
                clay.text(title)
                  :fontId(fontId)
                  :fontSize(fontSize)
                  :textColor(C(c_headerText))
                  :done()
              end)
          end
        end)

      ----------------------------------------------------------------
      -- TOP SPACER
      ----------------------------------------------------------------
      if viewH and firstIdx > 1 then
        local skipped = (firstIdx - 1) * rowH
        clay.element(topSpacerId)
          :width(clay.SIZING_GROW)
          :height(clay.SIZING_FIXED, skipped)
          :close()
      end

      ----------------------------------------------------------------
      -- ROWS
      ----------------------------------------------------------------
      for ri = firstIdx, lastIdx do
        local row = rows[ri]
        local rowId = clay.id("Row", rootKey * 100000 + ri, true)

        local is_sel = (st.selectedRow == ri)
        local zebra  = ((ri % 2) == 0) and c_rowBgAlt or nil

        -- click tracking
        if clay.pointerOver(rowId) and down and not was_down then
          _tbl_pressed_row[rootKey] = ri
        end
        if released and _tbl_pressed_row[rootKey] == ri and clay.pointerOver(rowId) then
          clickedRow = ri
          st.selectedRow = ri
        end

        local bg =
          (is_sel and c_rowSelBg)
          or (clay.pointerOver(rowId) and c_rowHover)
          or zebra

        clay.element(rowId)
          :layoutDirection(clay.LEFT_TO_RIGHT)
          :width(clay.SIZING_GROW)
          :height(clay.SIZING_FIXED, rowH)
          :childGap(0)
          :childAlignment(clay.ALIGN_X_LEFT, clay.ALIGN_Y_CENTER)
          :padding(def.headerPadL, 0, def.headerPadR, 0)
          :backgroundColor(bg and C(bg) or 0,0,0,0)
          :children(function()
            for ci, colDef in ipairs(cols) do
              local w = (colDef.width or 100)
              local cellKey = (rootKey * 1000000) + (ri * 1000) + ci
              local cellId = clay.id("Cell", cellKey, true)

              clay.element(cellId)
                :width(clay.SIZING_FIXED, w)
                :height(clay.SIZING_GROW)
                :childAlignment(clay.ALIGN_X_LEFT, clay.ALIGN_Y_CENTER)
                :padding(def.cellPadL, 0, def.cellPadR, 0)
                :children(function()
                  if opts and opts.cellRenderer then
                    opts.cellRenderer(colDef, row, ri, ci)
                  else
                    local text
                    if type(row) == "table" and type(colDef) == "table" and colDef.id and row[colDef.id] ~= nil then
                      text = tostring(row[colDef.id])
                    elseif type(row) == "table" then
                      text = tostring(row[ci] or "")
                    else
                      text = tostring(row)
                    end

                    clay.text(text)
                      :fontId(fontId)
                      :fontSize(fontSize)
                      :textColor(C(is_sel and c_rowSelTxt or c_rowText))
                      :done()
                  end
                end)
            end
          end)
      end

      ----------------------------------------------------------------
      -- BOTTOM SPACER
      ----------------------------------------------------------------
      if viewH and lastIdx < total then
        local remaining = (total - lastIdx) * rowH
        clay.element(botSpacerId)
          :width(clay.SIZING_GROW)
          :height(clay.SIZING_FIXED, remaining)
          :close()
      end
    end)

  -- activation callback
  if clickedRow and opts and opts.onActivate then
    opts.onActivate(rows[clickedRow], clickedRow)
  end

  return {
    selectedIndex = st.selectedRow,
    selectedRow   = st.selectedRow and rows[st.selectedRow] or nil,
    clickedIndex  = clickedRow,
    clickedRow    = clickedRow and rows[clickedRow] or nil,
    rowCount      = total,
  }
end
