local window = require("window")
local theme = require("theme")
local utf8 = require("utf8")

-- Virtualized List / Tree View for Clay

local _lv_state = _lv_state or {} -- [rootId] -> state
local _lv_stack = _lv_stack or {} -- open/close stack (optional)
local MAX_TRANSITIONED_ROWS = 96
local EMPTY_COLORS = {}

-- transient mouse bookkeeping for release-based clicks
local _lv_mouse_was_down      = _lv_mouse_was_down or false
local _lv_pressed_row_key     = _lv_pressed_row_key or nil
local _lv_pressed_tri_key     = _lv_pressed_tri_key or nil

local function now_ms() return window.time() * 1000.0 end

local function default_get_key(item, idx)
    if type(item) == "string" then return idx end
    if type(item) == "table" then return item.key or item.id or item.text or idx end
    return idx
end

local function ensure_state(rootId)
    local st = _lv_state[rootId]
    if not st then
        st = {
            expanded = {},
            selectedKey = nil,
            lastClickT = 0,
            lastClickKey = nil,

            -- stable mapping from arbitrary key -> small int (for clay.id offset)
            _key_to_int = {},
            _next_int = 1,

            -- reusable flatten buffer
            _flat = {},
        }
        _lv_state[rootId] = st
    end
    return st
end

local function key_to_int(st, key)
    local v = st._key_to_int[key]
    if v ~= nil then return v end
    v = st._next_int
    st._next_int = v + 1
    st._key_to_int[key] = v
    return v
end

local function flatten_visible(items, st, getKey, out)
    out = out or st._flat
    local n = 0

    local function rec(list, depth)
        for i, it in ipairs(list or {}) do
            local key = getKey(it, i)
            local hasChildren = (type(it) == "table" and type(it.children) == "table" and #it.children > 0)

            n = n + 1
            local e = out[n]
            if not e then e = {}; out[n] = e end
            e.key = key
            e.item = it
            e.depth = depth
            e.hasChildren = hasChildren

            if hasChildren and st.expanded[key] then
                rec(it.children, depth + 1)
            end
        end
    end

    rec(items, 0)

    -- trim tail
    for i = n + 1, #out do out[i] = nil end
    return out, n
end

local function draw_triangle(opened)
    -- using codicon-ish glyphs you had
    return opened and utf8.char(60127) or utf8.char(60124)
end

-- core drawing implementation; returns (selectedKey, expandedTable, totalRows, rowH)
local function listview_draw(elid, opts)
    assert(opts and opts.items, "listview: opts.items is required")

    -- mouse states
    local down     = (window.mouseButtonDown(window.MOUSE_BUTTON_LEFT))
    local was_down = _lv_mouse_was_down
    local released = (was_down and not down)

    -- config
    local componentDefaults = theme.defaults.listview
    local rowH     = opts.rowHeight or componentDefaults.rowHeight
    local indent   = opts.indent or componentDefaults.indent
    local fontId   = opts.fontId or componentDefaults.fontId
    local fontSize = opts.fontSize or theme.type.body
    local zebra    = (opts.zebra ~= false)
    local transitionDuration = opts.transitionDuration or 0
    local getKey   = opts.getKey or default_get_key
    local getIcon  = opts.getIcon

    local col = opts.colors or EMPTY_COLORS
    local defaults = theme.colors.listview
    local c_bg     = col.bg      or defaults.bg
    local c_bgAlt  = col.bgAlt   or defaults.bgAlt
    local c_hov    = col.hover   or defaults.hover
    local c_text   = col.text    or defaults.text
    local c_selBg  = col.selBg   or defaults.selBg
    local c_selTxt = col.selText or defaults.selText

    local rootId = elid.id
    local st = ensure_state(rootId)

    -- Resolve scroll virtualization context
    local viewH, scrollY = nil, 0
    if opts.viewport_id then
        local scd = clay.getScrollContainerData(opts.viewport_id)
        if scd and scd.found and scd.scrollPosition and scd.scrollPosition.y and scd.dimensions then
            viewH = scd.dimensions.height
            scrollY = math.max(0, -scd.scrollPosition.y)
        end
    end

    -- flatten according to expansion (reuses st._flat)
    local visible, total = flatten_visible(opts.items, st, getKey, st._flat)

    -- visible range (virtualization)
    local firstIdx, lastIdx = 1, total
    if viewH then
        firstIdx = math.max(1, math.floor(scrollY / rowH) + 1) -- +1 fixes off-by-one
        local onScreen = math.ceil(viewH / rowH) + 2
        lastIdx  = math.min(total, firstIdx + onScreen - 1)
    end
    -- Keep one list below half of Clay's fixed transition-state pool.
    local animateRows = transitionDuration > 0 and (lastIdx - firstIdx + 1) <= MAX_TRANSITIONED_ROWS

    local triW      = math.floor(fontSize * 0.9)

    clay.element(elid)
        :col()
        :wGrow()
        :hFit()
        :bg(c_bg)
        :open()

    if viewH and firstIdx > 1 then
        clay.element(clay.id("LVTopSpacer", 1, true))
            :wGrow()
            :h((firstIdx - 1) * rowH)
            :close()
    end

    local clickedKey = nil

    for i = firstIdx, lastIdx do
        local v = visible[i]
        local kid = key_to_int(st, v.key) -- stable int for ids
        local row_is_sel = (st.selectedKey ~= nil and st.selectedKey == v.key)

        -- zebra
        local yAlt = (zebra and (i % 2 == 0)) and c_bgAlt or nil

        local row_id     = clay.id("LVRow", kid, true)
        local tri_id     = clay.id("LVTri", kid, true)
        local trisp_id   = clay.id("LVTriSpacer", kid, true)
        local content_id = clay.id("LVContent", kid, true)
        local row_is_hovered = clay.pointerOver(row_id)
        local row_bg = row_is_sel and c_selBg or yAlt
        if transitionDuration > 0 and row_is_hovered and not row_is_sel then
            row_bg = c_hov
        end

        -- ROW
        local row_builder = clay.element(row_id)
            :row()
            :wGrow()
            :h(rowH)
            :gap(theme.spacing.controlGap)
            :padding(componentDefaults.paddingX + (v.depth * indent), 0, componentDefaults.paddingX, 0)
            :alignLC()
            :bg(row_bg)
        if animateRows then
            row_builder:transition(transitionDuration, "backgroundColor")
        end
        row_builder:open()

            -- TRIANGLE OR SPACER
            if v.hasChildren then
                clay.element(tri_id)
                    :w(triW)
                    :h(rowH)
                    :alignCC()
                    :open()
                    clay.text(draw_triangle(st.expanded[v.key] == true))
                        :fontId(fontId)
                        :fontSize(fontSize)
                        :textColor(c_text)
                        :done()
                clay.close()

                if clay.pointerOver(tri_id) and down and not was_down then
                    _lv_pressed_tri_key = v.key
                end
                if released and _lv_pressed_tri_key == v.key and clay.pointerOver(tri_id) then
                    st.expanded[v.key] = not st.expanded[v.key]
                end
            else
                clay.element(trisp_id)
                    :w(triW)
                    :h(rowH)
                    :close()
            end

            -- Without transitions, keep the legacy hover highlight on content.
            local content_bg
            if transitionDuration <= 0 and clay.pointerOver(content_id) then
                content_bg = c_hov
            end
            local content_builder = clay.element(content_id)
                :row()
                :wGrow()
                :h(rowH)
                :gap(theme.spacing.controlGap)
                :alignLC()
                :bg(content_bg)
            content_builder:open()

                if getIcon then
                    local icon = getIcon(v.item)
                    if icon and icon ~= "" then
                        clay.text(icon)
                            :fontId(fontId)
                            :fontSize(fontSize)
                            :textColor(c_text)
                            :done()
                    end
                end

                local label = (type(v.item) == "string") and v.item or (v.item.text or tostring(v.key))
                clay.text(label)
                    :fontId(fontId)
                    :fontSize(fontSize)
                    :textColor(row_is_sel and c_selTxt or c_text)
                    :done()

            clay.close()

            -- ROW press tracking (click on release)
            if clay.pointerOver(row_id) and down and not was_down then
                _lv_pressed_row_key = v.key
            end
            if released and _lv_pressed_row_key == v.key and clay.pointerOver(row_id) then
                clickedKey = v.key
            end

        clay.close() -- row
    end

    if viewH and lastIdx < total then
        clay.element(clay.id("LVBotSpacer", 2, true))
            :wGrow()
            :h((total - lastIdx) * rowH)
            :close()
    end

    -- click resolution (single vs double)
    if clickedKey ~= nil then
        local t = now_ms()
        if st.lastClickKey == clickedKey and (t - (st.lastClickT or 0) < 350) then
            if opts.onActivate then opts.onActivate(clickedKey) end
        else
            st.selectedKey = clickedKey
        end
        st.lastClickKey, st.lastClickT = clickedKey, t
    end

    -- persist mouse state
    _lv_mouse_was_down = down
    _lv_pressed_row_key = (released and nil) or _lv_pressed_row_key
    _lv_pressed_tri_key = (released and nil) or _lv_pressed_tri_key

    return st.selectedKey, st.expanded, total, rowH
end

-- Public APIs (same surface)
function listview(id, opts, children_fn)
    local api = listview_draw(id, opts)
    if children_fn then children_fn(api) end
    clay.close()
    return api
end

function listview_open(id, opts)
    local api = listview_draw(id, opts)
    _lv_stack[#_lv_stack + 1] = api
    return api
end

function listview_close()
    clay.close()
    _lv_stack[#_lv_stack] = nil
end
