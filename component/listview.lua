local window = require("window")
local theme = require("theme")
local utf8 = require("utf8")
local ComponentBuilder = require("component.builder")

-- Virtualized List / Tree View for Clay

local _lv_state = _lv_state or {} -- [rootId] -> state
local _lv_stack = _lv_stack or {} -- open/close stack (optional)
local MAX_TRANSITIONED_ROWS = 96
local EMPTY_COLORS = {}

local function now_ms() return window.time() * 1000.0 end

local function default_get_key(item, idx)
    if type(item) == "string" then return idx end
    if type(item) == "table" then return item.key or item.id or item.text or idx end
    return idx
end

local function default_get_children(item)
    return type(item) == "table" and item.children or nil
end

local function default_get_label(item, key)
    if type(item) == "string" then return item end
    if type(item) == "table" then
        return item.text or item.label or item.name or tostring(key)
    end
    return tostring(item)
end

local function ensure_state(rootId)
    local st = _lv_state[rootId]
    if not st then
        st = {
            expanded = {},
            selectedKey = nil,
            selectedKeys = {},
            anchorKey = nil,
            lastClickT = 0,
            lastClickKey = nil,
            lastDown = false,
            pressedRowKey = nil,
            pressedTriangleKey = nil,

            -- stable mapping from arbitrary key -> small int (for clay.id offset)
            _key_to_int = {},
            _next_int = 1,

            -- reusable flatten buffer
            _flat = {},
        }
        _lv_state[rootId] = st
    end
    st.selectedKeys = st.selectedKeys or {}
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

local function flatten_level(list, st, getKey, getChildren, out, count, depth)
    if type(list) ~= "table" then return count end
    for i = 1, #list do
        local item = list[i]
        local key = getKey(item, i)
        local children = getChildren(item, key)
        local hasChildren = type(children) == "table" and #children > 0

        count = count + 1
        local entry = out[count]
        if not entry then entry = {}; out[count] = entry end
        entry.key = key
        entry.item = item
        entry.depth = depth
        entry.hasChildren = hasChildren

        if hasChildren and st.expanded[key] then
            count = flatten_level(children, st, getKey, getChildren, out, count, depth + 1)
        end
    end
    return count
end

local function flatten_visible(items, st, getKey, getChildren, out)
    out = out or st._flat
    local n = flatten_level(items, st, getKey, getChildren, out, 0, 0)

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

    -- config
    local componentDefaults = theme.defaults.listview
    local rowH     = opts.rowHeight or componentDefaults.rowHeight
    local indent   = opts.indent or componentDefaults.indent
    local fontId   = opts.fontId or componentDefaults.fontId
    local fontSize = opts.fontSize or theme.type.body
    local zebra    = (opts.zebra ~= false)
    local transitionDuration = opts.transitionDuration or 0
    local getKey   = opts.getKey or default_get_key
    local getChildren = opts.getChildren or default_get_children
    local getLabel = opts.getLabel or default_get_label
    local getIcon  = opts.getIcon
    local multiSelect = opts.multiSelect == true

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
    if opts.expanded and opts.expanded ~= st.expanded then
        st.expanded = opts.expanded
    end
    if opts.selectedKey ~= nil and opts.selectedKey ~= st.selectedKey then
        st.selectedKey = opts.selectedKey
        for key in pairs(st.selectedKeys) do st.selectedKeys[key] = nil end
        st.selectedKeys[opts.selectedKey] = true
    end
    local was_down = st.lastDown
    local released = (was_down and not down)
    if down and not was_down then
        st.pressedRowKey = nil
        st.pressedTriangleKey = nil
    end

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
    local visible, total = flatten_visible(opts.items, st, getKey, getChildren, st._flat)

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
    local clickedItem = nil
    local retainedFollowup = false

    for i = firstIdx, lastIdx do
        local v = visible[i]
        local kid = key_to_int(st, v.key) -- stable int for ids
        local row_is_sel
        if multiSelect then
            row_is_sel = st.selectedKeys[v.key] == true
        else
            row_is_sel = st.selectedKey ~= nil and st.selectedKey == v.key
        end

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
                    st.pressedTriangleKey = v.key
                end
                if released and st.pressedTriangleKey == v.key and clay.pointerOver(tri_id) then
                    st.expanded[v.key] = not st.expanded[v.key]
                    retainedFollowup = true
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

                clay.text(tostring(getLabel(v.item, v.key)))
                    :fontId(fontId)
                    :fontSize(fontSize)
                    :textColor(row_is_sel and c_selTxt or c_text)
                    :done()

            clay.close()

            -- ROW press tracking (click on release)
            if clay.pointerOver(row_id) and down and not was_down then
                st.pressedRowKey = v.key
            end
            if released and st.pressedRowKey == v.key and clay.pointerOver(row_id) then
                clickedKey = v.key
                clickedItem = v.item
            end

        clay.close() -- row
    end

    if viewH and lastIdx < total then
        clay.element(clay.id("LVBotSpacer", 2, true))
            :wGrow()
            :h((total - lastIdx) * rowH)
            :close()
    end

    -- Click resolution happens after row elements were declared. Retained roots
    -- need one follow-up build to display the changed selection/expansion.
    -- click resolution (single vs double)
    if clickedKey ~= nil then
        retainedFollowup = true
        local t = now_ms()
        local activated = st.lastClickKey == clickedKey and (t - (st.lastClickT or 0) < 350)
        if activated then
            if opts.onActivate then opts.onActivate(clickedKey, clickedItem) end
        else
            if multiSelect then
                local ctrl = window.keyDown(window.KEY_LEFT_CONTROL)
                    or window.keyDown(window.KEY_RIGHT_CONTROL)
                local shift = window.keyDown(window.KEY_LEFT_SHIFT)
                    or window.keyDown(window.KEY_RIGHT_SHIFT)
                if shift and st.anchorKey ~= nil then
                    for key in pairs(st.selectedKeys) do st.selectedKeys[key] = nil end
                    local anchorIndex, targetIndex
                    for i = 1, total do
                        if visible[i].key == st.anchorKey then anchorIndex = i end
                        if visible[i].key == clickedKey then targetIndex = i end
                    end
                    if anchorIndex and targetIndex then
                        local first = math.min(anchorIndex, targetIndex)
                        local last = math.max(anchorIndex, targetIndex)
                        for i = first, last do st.selectedKeys[visible[i].key] = true end
                    else
                        st.selectedKeys[clickedKey] = true
                    end
                elseif ctrl then
                    st.selectedKeys[clickedKey] = st.selectedKeys[clickedKey] and nil or true
                    st.anchorKey = clickedKey
                else
                    for key in pairs(st.selectedKeys) do st.selectedKeys[key] = nil end
                    st.selectedKeys[clickedKey] = true
                    st.anchorKey = clickedKey
                end
            else
                for key in pairs(st.selectedKeys) do st.selectedKeys[key] = nil end
                st.selectedKeys[clickedKey] = true
                st.anchorKey = clickedKey
            end
            st.selectedKey = clickedKey
            if opts.onSelect then opts.onSelect(clickedKey, clickedItem, st.selectedKeys) end
        end
        st.lastClickKey, st.lastClickT = clickedKey, t
    end

    -- Persist per-list mouse state. Keeping this on the component state avoids
    -- one listview consuming another listview's press/release pair.
    st.lastDown = down
    if released then
        st.pressedRowKey = nil
        st.pressedTriangleKey = nil
    end
    if retainedFollowup and clay._invalidateCurrentRetainedRoot then
        clay._invalidateCurrentRetainedRoot()
    end

    return st.selectedKey, st.expanded, total, rowH
end

local function render_treeview(elid, items, builder)
    rawset(builder, "_items", items)
    local selectedKey, expanded, total, rowHeight = listview_draw(elid, builder)
    local state = ensure_state(elid.id)
    clay.close()
    rawset(builder, "_items", nil)
    return selectedKey, expanded, state.selectedKeys, total, rowHeight
end

ComponentBuilder.register("treeview", function(builder)
    return render_treeview(rawget(builder, "_id"), rawget(builder, "_arg1"), builder)
end)

function treeview(id, items)
    return ComponentBuilder.new("treeview", id, items)
end

-- Public APIs (same surface)
ComponentBuilder.register("listview", function(builder)
    if rawget(builder, "_arg1") ~= nil then
        rawset(builder, "_items", rawget(builder, "_arg1"))
    end
    local selectedKey, expanded, total, rowHeight =
        listview_draw(rawget(builder, "_id"), builder)
    clay.close()
    rawset(builder, "_items", nil)
    return selectedKey, expanded, total, rowHeight
end)

function listview(id, items)
    return ComponentBuilder.new("listview", id, items)
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
