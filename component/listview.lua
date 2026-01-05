local glfw = require("ffi.ffi_glfw")
local utf8 = require("utf8")

-- Virtualized List / Tree View for Clay

local _lv_state = _lv_state or {} -- [rootId] -> state
local _lv_stack = _lv_stack or {} -- open/close stack (optional)

-- transient mouse bookkeeping for release-based clicks
local _lv_mouse_was_down      = _lv_mouse_was_down or false
local _lv_pressed_row_key     = _lv_pressed_row_key or nil
local _lv_pressed_tri_key     = _lv_pressed_tri_key or nil

local function now_ms() return glfw.GetTime() * 1000.0 end

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
    local down     = (glfw.GetMouseButton(device.win, glfw.MOUSE_BUTTON_LEFT) == glfw.PRESS)
    local was_down = _lv_mouse_was_down
    local released = (was_down and not down)

    -- config
    local rowH     = opts.rowHeight or 22
    local indent   = opts.indent or 16
    local fontId   = opts.fontId or 0
    local fontSize = opts.fontSize or 16
    local zebra    = (opts.zebra ~= false)
    local getKey   = opts.getKey or default_get_key
    local getIcon  = opts.getIcon

    local col      = opts.colors or {}
    local c_bg     = col.bg      or {r=0,g=0,b=0,a=0}
    local c_bgAlt  = col.bgAlt   or {r=255,g=255,b=255,a=6}
    local c_hov    = col.hover   or {r=255,g=255,b=255,a=18}
    local c_text   = col.text    or {r=230,g=230,b=240,a=255}
    local c_selBg  = col.selBg   or {r=0,g=0,b=0,a=20}
    local c_selTxt = col.selText or {r=255,g=255,b=255,a=255}

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

    -- Prebuild/reuse sizing objects where possible
    local szGrowW   = clay.sizingGrow()
    local szFitH    = clay.sizingFit()
    local szRowH    = clay.sizingFixed(rowH)
    local triW      = math.floor(fontSize * 0.9)
    local szTriW    = clay.sizingFixed(triW)

    -- Root config (we are already inside clay.open(elid) from listview/listview_open)
    clay.configure({
        layout = {
            layoutDirection = clay.TOP_TO_BOTTOM,
            sizing = { width = szGrowW, height = szFitH },
            childGap = 0
        },
        backgroundColor = c_bg
    })

    -- spacer config tables (mutated)
    local spacerCfg = {
        layout = { sizing = { width = szGrowW, height = clay.sizingFixed(0) } }
    }

    if viewH and firstIdx > 1 then
        spacerCfg.layout.sizing.height = clay.sizingFixed((firstIdx - 1) * rowH)
        clay.open(clay.id("LVTopSpacer", 1, true))
        clay.configure(spacerCfg)
        clay.close()
    end

    -- row/tri/content configs (tables reused per-iteration; only mutate a few fields)
    local rowPadding = { left = 8, right = 8, top = 0, bottom = 0 }

    local rowCfg = {
        layout = {
            layoutDirection = clay.LEFT_TO_RIGHT,
            sizing = { width = szGrowW, height = szRowH },
            childGap = 8,
            padding = rowPadding,
            childAlignment = { x = clay.ALIGN_X_LEFT, y = clay.ALIGN_Y_CENTER }
        },
        backgroundColor = nil,
    }

    local triCfg = {
        layout = {
            sizing = { width = szTriW, height = szRowH },
            childAlignment = { x = clay.ALIGN_X_CENTER, y = clay.ALIGN_Y_CENTER }
        }
    }

    local triSpacerCfg = {
        layout = { sizing = { width = szTriW, height = szRowH } }
    }

    local contentCfg = {
        layout = {
            layoutDirection = clay.LEFT_TO_RIGHT,
            sizing = { width = szGrowW, height = szRowH },
            childGap = 8,
            childAlignment = { x = clay.ALIGN_X_LEFT, y = clay.ALIGN_Y_CENTER }
        },
        backgroundColor = nil,
    }

    local clickedKey = nil

    for i = firstIdx, lastIdx do
        local v = visible[i]
        local kid = key_to_int(st, v.key) -- stable int for ids
        local row_is_sel = (st.selectedKey ~= nil and st.selectedKey == v.key)

        -- zebra
        local yAlt = (zebra and (i % 2 == 0)) and c_bgAlt or nil
        rowCfg.backgroundColor = row_is_sel and c_selBg or yAlt

        -- indent (mutate padding left)
        rowPadding.left = 8 + (v.depth * indent)

        local row_id     = clay.id("LVRow", kid, true)
        local tri_id     = clay.id("LVTri", kid, true)
        local trisp_id   = clay.id("LVTriSpacer", kid, true)
        local content_id = clay.id("LVContent", kid, true)

        -- ROW
        clay.open(row_id)
        clay.configure(rowCfg)

            -- TRIANGLE OR SPACER
            if v.hasChildren then
                clay.open(tri_id)
                clay.configure(triCfg)
                    clay.createTextElement(draw_triangle(st.expanded[v.key] == true), {fontId=fontId, fontSize=fontSize, textColor=c_text})
                clay.close()

                if clay.pointerOver(tri_id) and down and not was_down then
                    _lv_pressed_tri_key = v.key
                end
                if released and _lv_pressed_tri_key == v.key and clay.pointerOver(tri_id) then
                    st.expanded[v.key] = not st.expanded[v.key]
                end
            else
                clay.open(trisp_id)
                clay.configure(triSpacerCfg)
                clay.close()
            end

            -- CONTENT (hover background only on this region)
            contentCfg.backgroundColor = clay.pointerOver(content_id) and c_hov or nil

            clay.open(content_id)
            clay.configure(contentCfg)

                if getIcon then
                    local icon = getIcon(v.item)
                    if icon and icon ~= "" then
                        clay.createTextElement(icon, {fontId=fontId, fontSize=fontSize, textColor=c_text})
                    end
                end

                local label = (type(v.item) == "string") and v.item or (v.item.text or tostring(v.key))
                clay.createTextElement(label, {
                    fontId=fontId,
                    fontSize=fontSize,
                    textColor=(row_is_sel and c_selTxt or c_text)
                })

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
        spacerCfg.layout.sizing.height = clay.sizingFixed((total - lastIdx) * rowH)
        clay.open(clay.id("LVBotSpacer", 2, true))
        clay.configure(spacerCfg)
        clay.close()
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
    clay.open(id)
    local api = listview_draw(id, opts)
    if children_fn then children_fn(api) end
    clay.close()
    return api
end

function listview_open(id, opts)
    clay.open(id)
    local api = listview_draw(id, opts)
    _lv_stack[#_lv_stack + 1] = api
    return api
end

function listview_close()
    clay.close()
    _lv_stack[#_lv_stack] = nil
end
