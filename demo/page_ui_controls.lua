local utf8 = require("utf8")

-- https://github.com/microsoft/vscode-codicons/blob/main/src/template/mapping.json
ICO_FOLDER  = utf8.char(0xEA83) -- codicon-folder
ICO_FILE    = utf8.char(0xEA7B) -- codicon-file
ICO_MEDIA   = utf8.char(60138)  -- codicon-file-media

local function C(c) return c.r, c.g, c.b, c.a end

local some_text = "This is a text edit"
local val = 50
local gain = 0.5
local panelW, panelH = 280, 180
local picked = { r = 255, g = 0, b = 0, a = 255 }
local tableFilter = ""
local selectedFileCount = 0
local function fileRowKey(row) return row.id end

local nodes = {
  { text="src", key="dir:src", icon=ICO_FOLDER, children={
    { text="main.lua",    key="file:src/main.lua",    icon=ICO_FILE },
    { text="window.lua",  key="file:src/window.lua",  icon=ICO_FILE },
    { text="ui", key="dir:src/ui", icon=ICO_FOLDER, children={
      { text="checkbox.lua", key="file:src/ui/checkbox.lua", icon=ICO_FILE },
      { text="slider.lua",   key="file:src/ui/slider.lua",   icon=ICO_FILE },
    }},
  }},
  { text="assets", key="dir:assets", icon=ICO_FOLDER, children={
    { text="logo.png", key="file:assets/logo.png", icon=ICO_MEDIA },
  }},
}

local columns = {
  { id="name", title="Name", width=220, minWidth=120, editable=true, editOnDoubleClick=false },
  { id="size", title="Size", width=90, align="right",
    getValue=function(row) return row.sizeBytes end,
    filterValue=function(row) return math.floor(row.sizeBytes / 1024) .. " KB" end,
    format=function(sizeBytes) return math.floor(sizeBytes / 1024) .. " KB" end },
  { id="kind", title="Type", width=90 },
}

local rows = {
  { id="file:main.lua",   name="main.lua",   sizeBytes=4096, kind="Lua" },
  { id="file:window.lua", name="window.lua", sizeBytes=3072, kind="Lua" },
  { id="dir:assets",      name="assets",     sizeBytes=0,    kind="Folder" },
}
local tableFilterColumns = { "name", "kind" }

function layout(dt)
  -- CHECKBOX (already "new style" API)
  clay.checkbox(clay.id("demo_checkbox1"), "Do you exist?", false, nil)

  -- RADIO
  clay.text("What is your favorite fruit?")
    :fontId(1):fontSize(22)
    :textColor(C(theme.colors.text))
    :done()

  clay.element("RadioGroup1")
    :layoutDirection(clay.LEFT_TO_RIGHT)
    :width(clay.SIZING_FIT)
    :height(clay.SIZING_FIT)
    :childGap(10)
    :childAlignment(clay.ALIGN_X_LEFT, clay.ALIGN_Y_TOP)
    :children(function()
      local v1 = clay.radio(clay.id("fruit-apple"),  "Apple",  "RadioGroup1", 1, true,  nil)
      local v2 = clay.radio(clay.id("fruit-banana"), "Banana", "RadioGroup1", 2, false, nil)
      local v3 = clay.radio(clay.id("fruit-cherry"), "Cherry", "RadioGroup1", 3, false, nil)
    end)

  -- RADIO (allow-none)
  clay.text("What is your favorite game?")
    :fontId(1):fontSize(22)
    :textColor(C(theme.colors.text))
    :done()

  clay.element("RadioGroup2")
    :layoutDirection(clay.LEFT_TO_RIGHT)
    :width(clay.SIZING_FIT)
    :height(clay.SIZING_FIT)
    :childGap(10)
    :childAlignment(clay.ALIGN_X_LEFT, clay.ALIGN_Y_TOP)
    :children(function()
      local cfg = { allowNone = true } -- widget config table is fine; this isn't per-element churn
      local v1 = clay.radio(clay.id("game-fallout"),  "Fallout",   "RadioGroup2", 1, false, cfg)
      local v2 = clay.radio(clay.id("game-fallout2"), "Fallout 2", "RadioGroup2", 2, false, cfg)
      local v3 = clay.radio(clay.id("game-fallout3"), "Fallout 3", "RadioGroup2", 3, false, cfg)
    end)

  local edited = false
  some_text, edited = clay.edit(clay.id("editbox1"), some_text, { filter = "ascii", maxChars = 50 })

  -- SLIDER
  clay.element("Group1")
    :layoutDirection(clay.LEFT_TO_RIGHT)
    :width(clay.SIZING_FIT)
    :height(clay.SIZING_FIT)
    :childGap(10)
    :childAlignment(clay.ALIGN_X_LEFT, clay.ALIGN_Y_TOP)
    :children(function()
      local changed = false
      val, changed = clay.slider(clay.id("vol"), val, {
        min = 0, max = 100, step = 5, tickCount = 6,
        width = 220, height = 28, pad = 0
      })

      clay.text(tostring(val))
        :fontId(1):fontSize(16)
        :textColor(C(theme.colors.text))
        :done()
    end)

  -- LISTVIEW (widget API)
  clay.listview(clay.id("ProjectTree"), {
    items = nodes,
    viewport_id = clay.id("ScrollViewport"),
    rowHeight = 22,
    indent = 16,
    zebra = true,
    onActivate = function(key) print("activate:", key) end,
    getIcon = function(item) return item.icon end,
  })

  -- PROPERTY (widget API)
  gain, _ = clay.property(clay.id("prop-gain"), "Gain", gain, {
    min = 0.0, max = 1.0, step = 0.1,
    width = 180, height = 32, buttonW = 28,
    cornerRadius = 10,
    format = function(v) return string.format("Gain: %.3f", v) end
  })

  -- COLOR PICKER
  clay.text("Color Picker")
    :fontId(1):fontSize(22)
    :textColor(C(theme.colors.text))
    :done()

  local changed = false
  picked, changed = clay.color_picker(clay.id("myColorPicker"), picked, {
    width = 260, height = 180, pad = 6,
    showAlpha = true,
    matrixSteps = 22, hueSteps = 48, alphaSteps = 48,
    barWidth = 18,
  })

  -- swatch (element builder)
  clay.element("test-swatch")
    :width(clay.SIZING_FIXED, 100)
    :height(clay.SIZING_FIXED, 50)
    :childAlignment(clay.ALIGN_X_CENTER, clay.ALIGN_Y_CENTER)
    :backgroundColor(picked.r, picked.g, picked.b, picked.a)
    :children(function()
      clay.text(string.format("#%02X%02X%02X%02X", picked.r, picked.g, picked.b, picked.a))
        :fontId(0):fontSize(16)
        :textColor(C(theme.colors.text))
        :done()
    end)

  -- TABLEVIEW (widget API)
  clay.text("Files — click headers to sort, drag dividers to resize, Ctrl-click to select, F2 to rename")
    :fontId(1):fontSize(14)
    :textColor(C(theme.colors.textMuted))
    :done()

  clay.text("Filter files by name or type:")
    :fontId(1):fontSize(12)
    :textColor(C(theme.colors.textMuted))
    :done()

  tableFilter = clay.edit(clay.id("table-filter"), tableFilter, {
    width = 260,
    filter = "ascii",
    maxChars = 64,
  })

  local api = clay.tableview(
    clay.id("FileTable"),
    { columns = columns, rows = rows },
    {
      height = 220,
      filter = tableFilter,
      filterColumns = tableFilterColumns,
      selectionMode = "multiple",
      copyHeaders = true,
      getRowKey = fileRowKey,
      onSelectionChanged = function(selectedRows)
        selectedFileCount = #selectedRows
      end,
      onActivate = function(row, idx)
        print("Activated row", idx, row.name)
      end,
      onDoubleClick = function(row)
        print("Open row", row.name)
      end,
      cellRenderer = function(col, row, r, c)
        if col.id == "name" and row.kind == "Folder" then
          clay.text(ICO_FOLDER .. " " .. row.name):fontId(1):fontSize(14):done()
        elseif col.id == "size" then
          clay.text(math.floor(row.sizeBytes / 1024) .. " KB"):fontId(1):fontSize(14):done()
        else
          clay.text(tostring(row[col.id] or "")):fontId(1):fontSize(14):done()
        end
      end,
    }
  )
  clay.text(string.format("%d of %d files selected · %d match the filter",
      selectedFileCount, api.rowCount, api.filteredCount))
    :fontId(1):fontSize(12)
    :textColor(C(theme.colors.textMuted))
    :done()

  -- RESIZABLE panel element
  local panelId = clay.id("demo-resize-panel")
  clay.element(panelId)
    :width(clay.SIZING_FIXED, panelW)
    :height(clay.SIZING_FIXED, panelH)
    :childAlignment(clay.ALIGN_X_CENTER, clay.ALIGN_Y_CENTER)
    :padding(12)
    :backgroundColor(C(theme.colors.surface))
    :borderColor(C(COLOR_WHITE_32))
    :borderWidth(1)
    :cornerRadius(8)
    :children(function()
      clay.text("Drag my bottom-right corner")
        :fontId(1):fontSize(16)
        :textColor(C(COLOR_WHITE))
        :done()
    end)

  -- make it resizable (invisible grip)
  panelW, panelH = clay.resizable(panelId, panelW, panelH, {
    minW = 140,
    minH = 80,
    snapW = 0,
    snapH = 0,
    showGrip = true,
  })
end
