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
  { id="name", title="Name", width=220 },
  { id="size", title="Size", width=80 },
  { id="kind", title="Type", width=80 },
}

local rows = {
  { name="main.lua",   size="4 KB", kind="Lua"    },
  { name="window.lua", size="3 KB", kind="Lua"    },
  { name="assets",     size="-",    kind="Folder" },
}

function layout(dt)
  -- CHECKBOX (already "new style" API)
  clay.checkbox(clay.id("demo_checkbox1"), "Do you exist?", false, nil)

  -- RADIO
  clay.text("What is your favorite fruit?")
    :fontId(1):fontSize(22)
    :textColor(230, 230, 240, 255)
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
    :textColor(230, 230, 240, 255)
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
        :textColor(230, 230, 240, 255)
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
    :textColor(230, 230, 240, 255)
    :done()

  local changed = false
  picked, changed = clay.color_picker(clay.id("myColorPicker"), picked, {
    width = 260, height = 180, pad = 6,
    showAlpha = true,
    matrixSteps = 22, hueSteps = 48, alphaSteps = 48,
    barWidth = 18,
    colors = {
      border = { r = 255, g = 255, b = 255, a = 36 },
      bg     = { r = 25,  g = 25,  b = 28,  a = 160 },
    }
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
        :textColor(230, 230, 240, 255)
        :done()
    end)

  -- TABLEVIEW (widget API)
  local api = clay.tableview(
    clay.id("FileTable"),
    { columns = columns, rows = rows },
    {
      viewport_id = clay.id("ScrollViewport"),
      onActivate = function(row, idx)
        print("Activated row", idx, row.name)
      end,
      cellRenderer = function(col, row, r, c)
        if col.id == "name" and row.kind == "Folder" then
          clay.createTextElement(ICO_FOLDER .. " " .. row.name, { fontId=1, fontSize=14 })
        else
          clay.createTextElement(tostring(row[col.id] or ""), { fontId=1, fontSize=14 })
        end
      end,
    }
  )

  -- RESIZABLE panel element
  local panelId = clay.id("demo-resize-panel")
  clay.element(panelId)
    :width(clay.SIZING_FIXED, panelW)
    :height(clay.SIZING_FIXED, panelH)
    :childAlignment(clay.ALIGN_X_CENTER, clay.ALIGN_Y_CENTER)
    :padding(12)
    :backgroundColor(30, 46, 75, 255)
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
