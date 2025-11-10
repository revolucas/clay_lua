local glfw = require("ffi.ffi_glfw")
local utf8 = require("utf8")

-- Virtualized List / Tree View for Clay (builder-friendly)
-- Clicks occur on mouse *release*; hover highlight covers only the text/icon area.
-- Supports both one-shot and open/close usage patterns.
--
-- Patterns:
--   clay.listview(clay.id("MyTree"), { items = nodes, viewport_id = clay.id("ScrollViewport") })
--   local api = clay.listview_open(clay.id("MyTree"), { items = nodes }); clay.listview_close()
--
-- Items: strings or tables { text, key, icon?, children? }

local _lv_state = _lv_state or {} -- [rootKey] -> { expanded={}, selectedKey, lastClickT, lastClickKey }
local _lv_stack = _lv_stack or {} -- open/close context stack

-- transient mouse bookkeeping for release-based clicks
local _lv_mouse_was_down = _lv_mouse_was_down or false
local _lv_pressed_row_key = _lv_pressed_row_key or nil
local _lv_pressed_tri_key = _lv_pressed_tri_key or nil

local function now_ms() return glfw.GetTime() * 1000.0 end

local function default_get_key(item, idx)
    if type(item) == "string" then return idx end
    if type(item) == "table" then return item.key or item.id or item.text or idx end
    return idx
end

local function flatten_visible(items, st, getKey, indent, depth, out)
    depth = depth or 0
    out = out or {}
    for i, it in ipairs(items or {}) do
        local key = getKey(it, i)
        local hasChildren = (type(it) == "table" and type(it.children) == "table" and #it.children > 0)
        table.insert(out, { key=key, item=it, depth=depth, hasChildren=hasChildren })
        if hasChildren and st.expanded[key] then
            flatten_visible(it.children, st, getKey, indent, depth+1, out)
        end
    end
    return out
end

local function ensure_state(rootKey)
    local st = _lv_state[rootKey]
    if not st then
        st = { expanded = {}, selectedKey = nil, lastClickT = 0, lastClickKey = nil }
        _lv_state[rootKey] = st
    end
    return st
end

local function draw_triangle(opened)
    return opened and utf8.char(60127) or utf8.char(60124) --opened and "▼" or "▶"
end

-- core drawing implementation; returns API table describing current state
local function listview_draw(elid, opts)
    assert(opts and opts.items, "listview: opts.items is required")
    local items = opts.items

    -- mouse states
    local down = glfw.GetMouseButton(device.win, glfw.MOUSE_BUTTON_LEFT) == glfw.PRESS
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
    local c_bg     = col.bg     or {r=0,g=0,b=0,a=0}
    local c_bgAlt  = col.bgAlt  or {r=255,g=255,b=255,a=6}
    local c_hov    = col.hover  or {r=255,g=255,b=255,a=18}
    local c_text   = col.text   or {r=230,g=230,b=240,a=255}
    local c_selBg  = col.selBg  or {r=0,g=0,b=0,a=20}
    local c_selTxt = col.selText or {r=255,g=255,b=255,a=255}
    local c_guide  = col.guide  or {r=255,g=255,b=255,a=28}

    local rootKey  = elid.id
    local st       = ensure_state(rootKey)

    -- Resolve scroll virtualization context
    local viewH, scrollY = nil, 0
    if opts.viewport_id then
        local scd = clay.getScrollContainerData(opts.viewport_id)
        if scd and scd.found and scd.scrollPosition and scd.scrollPosition.y and scd.dimensions then
            viewH = scd.dimensions.height
            scrollY = math.max(0, -scd.scrollPosition.y)
        end
    end

    -- flatten according to expansion
    local visible = flatten_visible(items, st, getKey, indent, 0)
    local total   = #visible
    local totalH  = total * rowH

    -- visible range (virtualization) — if no viewport supplied, draw all
    local firstIdx, lastIdx = 1, total
    if viewH then
        firstIdx = math.max(1, math.floor(scrollY / rowH))
        local onScreen = math.ceil(viewH / rowH) + 2
        lastIdx  = math.min(total, firstIdx + onScreen)
    end

    clay.configure({
        layout = {
            layoutDirection = clay.TOP_TO_BOTTOM,
            sizing = { width = clay.sizingGrow(), height = clay.sizingFit() },
            childGap = 0
        },
        backgroundColor = c_bg
    })

    if viewH and firstIdx > 1 then
        clay.createElement(clay.id("LVTopSpacer", rootKey), {
            layout = { sizing = { width = clay.sizingGrow(), height = clay.sizingFixed((firstIdx-1)*rowH) } }
        })
    end

    local clickedKey = nil

    for i = firstIdx, lastIdx do
        local v = visible[i]
        local yAlt = (zebra and (i % 2 == 0)) and c_bgAlt or nil
        local row_id = clay.id("Row" .. v.key, rootKey)
        local row_is_sel = (st.selectedKey ~= nil and st.selectedKey == v.key)
        local triW = math.floor(fontSize*0.9)

        clay.createElement(row_id, {
            layout = {
                layoutDirection = clay.LEFT_TO_RIGHT,
                sizing = { width = clay.sizingGrow(), height = clay.sizingFixed(rowH) },
                childGap = 8,
                padding = clay.paddingLTRB(8 + v.depth*indent, 0, 8, 0),
                childAlignment = { x = clay.ALIGN_X_LEFT, y = clay.ALIGN_Y_CENTER }
            },
            backgroundColor = row_is_sel and c_selBg or yAlt
        }, function()
            -- (1) Triangle container (nested hitbox)
            local tri_id
            if v.hasChildren then
                tri_id = clay.id("Tri" .. v.key, rootKey)
                clay.createElement(tri_id, {
                    layout = {
                        sizing = { width = clay.sizingFixed(triW), height = clay.sizingFixed(rowH) },
                        childAlignment = { x = clay.ALIGN_X_CENTER, y = clay.ALIGN_Y_CENTER }
                    }
                }, function()
                    clay.createTextElement(draw_triangle(st.expanded[v.key] == true), {fontId=fontId, fontSize=fontSize, textColor=c_text})
                end)
                -- press tracking
                if clay.pointerOver(tri_id) and down and not was_down then
                    _lv_pressed_tri_key = v.key
                end
                if released and _lv_pressed_tri_key == v.key and clay.pointerOver(tri_id) then
                    st.expanded[v.key] = not st.expanded[v.key]
                end
            else
                clay.createElement(clay.id("TriSpacer" .. v.key, rootKey), {
                    layout = { sizing = { width = clay.sizingFixed(triW), height = clay.sizingFixed(rowH) } }
                })
            end

            -- (2) Content container (icon + label). Hover background applied here
            local content_id = clay.id("Content" .. v.key, rootKey)
            clay.createElement(content_id, {
                layout = {
                    layoutDirection = clay.LEFT_TO_RIGHT,
                    sizing = { width = clay.sizingGrow(), height = clay.sizingFixed(rowH) },
                    childGap = 8,
                    childAlignment = { x = clay.ALIGN_X_LEFT, y = clay.ALIGN_Y_CENTER }
                },
                backgroundColor = clay.pointerOver(content_id) and c_hov or nil
            }, function()
                if getIcon then
                    local icon = getIcon(v.item)
                    if icon and icon ~= "" then
                        clay.createTextElement(icon, {fontId=fontId, fontSize=fontSize, textColor=c_text})
                    end
                end
                local label = (type(v.item)=="string") and v.item or (v.item.text or tostring(v.key))
                clay.createTextElement(label, {fontId=fontId, fontSize=fontSize, textColor=(row_is_sel and c_selTxt or c_text)})
            end)

            -- (3) Row press tracking (click on release)
            if clay.pointerOver(row_id) and down and not was_down then
                _lv_pressed_row_key = v.key
            end
            if released and _lv_pressed_row_key == v.key and clay.pointerOver(row_id) then
                clickedKey = v.key
            end
        end)
    end

    if viewH and lastIdx < total then
        clay.createElement(clay.id("LVBotSpacer", rootKey), {
            layout = { sizing = { width = clay.sizingGrow(), height = clay.sizingFixed((total-lastIdx)*rowH) } }
        })
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

    -- persist mouse state for next frame
    _lv_mouse_was_down = down
    _lv_pressed_row_key = (released and nil) or _lv_pressed_row_key
    _lv_pressed_tri_key = (released and nil) or _lv_pressed_tri_key

    return st.selectedKey, st.expanded, total, rowH
end

-- High-level APIs (builder-friendly)
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
    table.insert(_lv_stack, api)
    return api
end

function listview_close()
    clay.close()
    _lv_stack[#_lv_stack] = nil
end
