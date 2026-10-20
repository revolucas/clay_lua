local function C(c) return c.r, c.g, c.b, c.a end

local ROW_COUNT = 5000
local ROW_HEIGHT = 24
local VIEW_HEIGHT = 420
local OVERSCAN = 4

local function visible_rows(viewport_id)
    local first = 1
    local visible_count = math.ceil(VIEW_HEIGHT / ROW_HEIGHT)
    local data = clay.getScrollContainerData(viewport_id)
    if data and data.found then
        local dimensions = data.scrollContainerDimensions or data.dimensions
        local view_height = dimensions and dimensions.height or VIEW_HEIGHT
        local scroll_y = data.scrollPosition and math.max(0, -(data.scrollPosition.y or 0)) or 0
        first = math.max(1, math.floor(scroll_y / ROW_HEIGHT) + 1 - OVERSCAN)
        visible_count = math.ceil(view_height / ROW_HEIGHT) + OVERSCAN * 2
    end
    local last = math.min(ROW_COUNT, first + visible_count - 1)
    return first, last
end

function layout(dt)
    clay.text("Virtualized list")
        :fontId(1):fontSize(theme.type.heading)
        :textColor(C(theme.colors.textStrong))
        :done()

    clay.text("5,000 rows; only the visible rows are built and drawn.")
        :fontId(1):fontSize(theme.type.small)
        :textColor(C(theme.colors.textMuted))
        :done()

    local viewport_id = clay.id("LongListViewport")
    local content_id = clay.id("LongListContent")
    local first, last = visible_rows(viewport_id)

    clay.element(viewport_id)
        :width(clay.SIZING_GROW)
        :height(clay.SIZING_FIXED, VIEW_HEIGHT)
        :backgroundColor(C(theme.colors.surface))
        :borderColor(C(theme.colors.border))
        :borderWidth(1)
        :clip(false, true)
        :open()
    clay.element(content_id)
        :width(clay.SIZING_GROW)
        :height(clay.SIZING_FIXED, ROW_COUNT * ROW_HEIGHT)
        :layoutDirection(clay.TOP_TO_BOTTOM)
        :open()
    local top_height = (first - 1) * ROW_HEIGHT
    if top_height > 0 then
        clay.element("LongListTopSpacer")
            :width(clay.SIZING_GROW)
            :height(clay.SIZING_FIXED, top_height)
            :close()
    end

    for i = first, last do
        local row_color = (i % 2 == 0)
            and theme.colors.surfaceRaised or theme.colors.surface
        clay.element(clay.id("LongListRow", i))
            :width(clay.SIZING_GROW)
            :height(clay.SIZING_FIXED, ROW_HEIGHT)
            :padding(8, 0, 8, 0)
            :backgroundColor(C(row_color))
            :borderColor(C(theme.colors.borderSubtle))
            :borderWidth(0, 0, 0, 1)
            :childAlignment(clay.ALIGN_X_LEFT, clay.ALIGN_Y_CENTER)
            :open()
        clay.text(("Item #%04d"):format(i))
            :fontId(1):fontSize(theme.type.body)
            :textColor(C(theme.colors.text))
            :done()
        clay.close()
    end

    local bottom_height = (ROW_COUNT - last) * ROW_HEIGHT
    if bottom_height > 0 then
        clay.element("LongListBottomSpacer")
            :width(clay.SIZING_GROW)
            :height(clay.SIZING_FIXED, bottom_height)
            :close()
    end
    clay.close() -- content
    clay.scrollbar(viewport_id, content_id, 0, nil)
    clay.close() -- viewport
end
