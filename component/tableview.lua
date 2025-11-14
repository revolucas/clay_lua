local clay = require("clay")
local glfw = require("ffi.ffi_glfw")

local _tbl_state         = _tbl_state         or {} -- [rootKey] -> { selectedRow }
local _tbl_mouse_was_down = _tbl_mouse_was_down or false
local _tbl_pressed_row    = _tbl_pressed_row    or {}

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
--   rowHeight    = 22,
--   headerHeight = 24,
--   fontId       = 1,
--   fontSize     = 14,
--   viewport_id  = clay.id("ScrollViewport"), -- for virtualization, optional
--   colors       = { ... },
--   cellRenderer = function(colDef, row, rowIndex, colIndex) ... end,
--   onActivate   = function(row, rowIndex) end,
-- }
function tableview(elid, model, opts)
    opts  = opts or {}
    local cols = assert(model.columns, "tableview: model.columns required")
    local rows = assert(model.rows,    "tableview: model.rows required")

    local rowH     = opts.rowHeight    or 22
    local headerH  = opts.headerHeight or 24
    local fontId   = opts.fontId       or 1
    local fontSize = opts.fontSize     or 14
    local viewport_id = opts.viewport_id

    local col      = opts.colors or {}
    local c_bg     = col.bg      or {r=0,g=0,b=0,a=0}
    local c_header = col.header  or {r=34,g=37,b=45,a=255}
    local c_headerText = col.headerText or {r=210,g=210,b=220,a=255}
    local c_rowBgAlt   = col.rowAlt    or {r=255,g=255,b=255,a=6}
    local c_rowHover   = col.rowHover  or {r=255,g=255,b=255,a=18}
    local c_rowSelBg   = col.rowSelBg  or {r=60,g=90,b=140,a=180}
    local c_rowText    = col.rowText   or {r=230,g=230,b=240,a=255}
    local c_rowSelTxt  = col.rowSelTxt or {r=255,g=255,b=255,a=255}

    -- mouse state (release-based clicks like listview)
    local down     = glfw.GetMouseButton(device.win, glfw.MOUSE_BUTTON_LEFT) == glfw.PRESS
    local was_down = _tbl_mouse_was_down
    local released = (was_down and not down)
    _tbl_mouse_was_down = down

    local rootKey  = elid.id
    local st       = ensure_state(rootKey)

    -- virtualization via scroll container, same pattern as listview.lua
    local viewH, scrollY = nil, 0
    if viewport_id then
        local scd = clay.getScrollContainerData(viewport_id)
        if scd and scd.found and scd.scrollPosition and scd.dimensions then
            viewH   = scd.dimensions.height
            scrollY = math.max(0, -scd.scrollPosition.y)
        end
    end

    local total   = #rows
    local totalH  = headerH + total * rowH

    local firstIdx, lastIdx = 1, total
    if viewH then
        -- skip header height when figuring row range
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

    -- ROOT
    clay.createElement(elid, {
        layout = {
            layoutDirection = clay.TOP_TO_BOTTOM,
            sizing = { width = clay.sizingGrow(), height = clay.sizingFit() },
            childGap = 0,
        },
        backgroundColor = c_bg,
    }, function()

        ----------------------------------------------------------------
        -- HEADER ROW
        ----------------------------------------------------------------
        clay.createElement(clay.id("TableHeader", rootKey), {
            layout = {
                layoutDirection = clay.LEFT_TO_RIGHT,
                sizing = { width = clay.sizingGrow(), height = clay.sizingFixed(headerH) },
                childGap = 0,
                childAlignment = { x = clay.ALIGN_X_LEFT, y = clay.ALIGN_Y_CENTER },
                padding = clay.paddingLTRB(6, 0, 6, 0),
            },
            backgroundColor = c_header,
        }, function()
            for ci, colDef in ipairs(cols) do
                local w = (colDef.width or 100)
                local title = colDef.title or colDef.label or colDef.id or tostring(colDef)
                clay.createElement(clay.id("Th"..ci, rootKey), {
                    layout = {
                        sizing = { width = clay.sizingFixed(w), height = clay.sizingGrow() },
                        childAlignment = { x = clay.ALIGN_X_LEFT, y = clay.ALIGN_Y_CENTER },
                        padding = clay.paddingLTRB(4, 0, 4, 0),
                    },
                }, function()
                    clay.createTextElement(title, {
                        fontId = fontId, fontSize = fontSize,
                        textColor = c_headerText
                    })
                end)
            end
        end)

        ----------------------------------------------------------------
        -- TOP SPACER FOR VIRTUALIZATION
        ----------------------------------------------------------------
        if viewH and firstIdx > 1 then
            local skipped = (firstIdx - 1) * rowH
            clay.createElement(clay.id("TblTopSpacer", rootKey), {
                layout = {
                    sizing = { width = clay.sizingGrow(), height = clay.sizingFixed(skipped) },
                }
            })
        end

        ----------------------------------------------------------------
        -- ROWS
        ----------------------------------------------------------------
        for ri = firstIdx, lastIdx do
            local row = rows[ri]
            local row_id = clay.id("Row"..ri, rootKey)
            local is_sel = (st.selectedRow == ri)
            local zebra  = ((ri % 2) == 0) and c_rowBgAlt or nil

            -- press tracking per root
            if clay.pointerOver(row_id) and down and not was_down then
                _tbl_pressed_row[rootKey] = ri
            end
            if released and _tbl_pressed_row[rootKey] == ri and clay.pointerOver(row_id) then
                clickedRow = ri
                st.selectedRow = ri
            end

            clay.createElement(row_id, {
                layout = {
                    layoutDirection = clay.LEFT_TO_RIGHT,
                    sizing = { width = clay.sizingGrow(), height = clay.sizingFixed(rowH) },
                    childGap = 0,
                    childAlignment = { x = clay.ALIGN_X_LEFT, y = clay.ALIGN_Y_CENTER },
                    padding = clay.paddingLTRB(6, 0, 6, 0),
                },
                backgroundColor =
                    (is_sel and c_rowSelBg)
                    or (clay.pointerOver(row_id) and c_rowHover or zebra),
            }, function()
                for ci, colDef in ipairs(cols) do
                    local w = (colDef.width or 100)
                    local cellId = clay.id("Cell"..ri.."_"..ci, rootKey)

                    clay.createElement(cellId, {
                        layout = {
                            sizing = { width = clay.sizingFixed(w), height = clay.sizingGrow() },
                            childAlignment = { x = clay.ALIGN_X_LEFT, y = clay.ALIGN_Y_CENTER },
                            padding = clay.paddingLTRB(4, 0, 4, 0),
                        },
                    }, function()
                        if opts.cellRenderer then
                            opts.cellRenderer(colDef, row, ri, ci)
                        else
                            -- default text cell mapping: row[col.id] → row[ci] → ""
                            local text
                            if type(row) == "table" and type(colDef) == "table" and colDef.id and row[colDef.id] ~= nil then
                                text = tostring(row[colDef.id])
                            elseif type(row) == "table" then
                                text = tostring(row[ci] or "")
                            else
                                text = tostring(row)
                            end

                            clay.createTextElement(text, {
                                fontId   = fontId,
                                fontSize = fontSize,
                                textColor = (is_sel and c_rowSelTxt or c_rowText)
                            })
                        end
                    end)
                end
            end)
        end

        ----------------------------------------------------------------
        -- BOTTOM SPACER FOR VIRTUALIZATION
        ----------------------------------------------------------------
        if viewH and lastIdx < total then
            local remaining = (total - lastIdx) * rowH
            clay.createElement(clay.id("TblBotSpacer", rootKey), {
                layout = {
                    sizing = { width = clay.sizingGrow(), height = clay.sizingFixed(remaining) },
                }
            })
        end
    end)

    -- activation callback
    if clickedRow and opts.onActivate then
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
