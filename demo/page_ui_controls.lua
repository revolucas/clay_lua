local utf8 = require("utf8")

-- https://github.com/microsoft/vscode-codicons/blob/main/src/template/mapping.json
ICO_FOLDER  = utf8.char(0xEA83) -- codicon-folder
ICO_FILE    = utf8.char(0xEA7B) -- codicon-file
ICO_MEDIA   = utf8.char(60138) -- codicon-file-media


local some_text = "This is a text edit"
local val = 50
local gain = 0.5
local panelW, panelH = 280, 180
local picked = {r = 255, g = 0, b = 0, a = 255}

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
	
function layout(dt)
    -- CHECKBOX
    clay.checkbox(clay.id("demo_checkbox1"), "Do you exist?", false, nil)

    -- RADIO
    clay.createTextElement(
        "What is your favorite fruit?",
        {fontId = 1, fontSize = 22, textColor = {r = 230, g = 230, b = 240, a = 255}}
    )
    clay.createElement(
        clay.id("RadioGroup1"),
        {
            layout = {
                layoutDirection = clay.LEFT_TO_RIGHT,
                sizing = {width = clay.sizingFit(), height = clay.sizingFit()},
                childGap = 10,
                childAlignment = {x = clay.ALIGN_X_LEFT}
            }
        },
        function()
            -- exactly one of these can be selected
            local v1 = clay.radio(clay.id("fruit-apple"), "Apple", "RadioGroup1", 1, true, nil) -- default selected first run
            local v2 = clay.radio(clay.id("fruit-banana"), "Banana", "RadioGroup1", 2, false, nil)
            local v3 = clay.radio(clay.id("fruit-cherry"), "Cherry", "RadioGroup1", 3, false, nil)
        end
    )

    -- RADIO (allow-none)
    clay.createTextElement(
        "What is your favorite game?",
        {fontId = 1, fontSize = 22, textColor = {r = 230, g = 230, b = 240, a = 255}}
    )
    clay.createElement(
        clay.id("RadioGroup2"),
        {
            layout = {
                layoutDirection = clay.LEFT_TO_RIGHT,
                sizing = {width = clay.sizingFit(), height = clay.sizingFit()},
                childGap = 10,
                childAlignment = {x = clay.ALIGN_X_LEFT}
            }
        },
        function()
            -- exactly one of these can be selected
            local cfg = {allowNone = true}
            local v1 = clay.radio(clay.id("game-fallout"), "Fallout", "RadioGroup2", 1, false, cfg) -- default selected first run
            local v2 = clay.radio(clay.id("game-fallout2"), "Fallout 2", "RadioGroup2", 2, false, cfg)
            local v3 = clay.radio(clay.id("game-fallout3"), "Fallout 3", "RadioGroup2", 3, false, cfg)
        end
    )

    local edited = false
    some_text, edited = clay.edit(clay.id("editbox1"), some_text, {filter = "ascii", maxChars = 50})

    -- SLIDER
    clay.createElement(
        clay.id("Group1"),
        {
            layout = {
                layoutDirection = clay.LEFT_TO_RIGHT,
                sizing = {width = clay.sizingFit(), height = clay.sizingFit()},
                childGap = 10,
                childAlignment = {x = clay.ALIGN_X_LEFT}
            }
        },
        function()
            local changed = false
            -- 0..100 int slider with ticks
            val, changed =
                clay.slider(
                clay.id("vol"),
                val,
                {
                    min = 0,
                    max = 100,
                    step = 5,
                    tickCount = 6,
                    width = 220,
                    height = 28,
                    pad = 0
                }
            )

            clay.createTextElement(
                tostring(val),
                {fontId = 1, fontSize = 16, textColor = {r = 230, g = 230, b = 240, a = 255}}
            )
        end
    )
	-- LISTVIEW

	clay.listview(clay.id("ProjectTree"), {
	  items = nodes,
	  viewport_id = clay.id("ScrollViewport"),  -- enables row virtualization
	  rowHeight = 22,
	  indent = 16,
	  zebra = true,
	  onActivate = function(key) print("activate:", key) end,
	  getIcon = function(item) return item.icon end, -- optional; can be omitted if icon is stored on items
	})
	
    -- PROPERTY
    -- float property with custom formatter
    gain, _ =
        clay.property(
        clay.id("prop-gain"),
        "Gain",
        gain,
        {
            min = 0.0,
            max = 1.0,
            step = 0.1,
            width = 180,
            height = 32,
            buttonW = 28,
            cornerRadius = 10,
            format = function(v)
                return string.format("Gain: %.3f", v)
            end
        }
    )

    -- COLOR PICKER
    clay.createTextElement(
        "Color Picker",
        {fontId = 1, fontSize = 22, textColor = {r = 230, g = 230, b = 240, a = 255}}
    )

    local changed = false
    picked, changed =
        clay.color_picker(
        clay.id("myColorPicker"),
        picked,
        {
            width = 260,
            height = 180,
            pad = 6,
            showAlpha = true, -- set false to hide alpha bar
            matrixSteps = 22, -- SV grid resolution
            hueSteps = 48,
            alphaSteps = 48,
            barWidth = 18,
            colors = {
                border = {r = 255, g = 255, b = 255, a = 36},
                bg = {r = 25, g = 25, b = 28, a = 160}
            }
        }
    )

    -- use `picked` (r,g,b,a 0..255) for whatever (e.g., preview swatch / theme update)
    clay.createElement(
        clay.id("test-swatch"),
        {
            layout = {sizing = {width = clay.sizingFixed(100), height = clay.sizingFixed(50)}, childAlignment = {x = clay.ALIGN_X_CENTER, y = clay.ALIGN_Y_CENTER}},
            backgroundColor = picked
        }, function()
			clay.createTextElement(string.format("#%02X%02X%02X%02X", picked.r, picked.g, picked.b, picked.a), {fontId = 0, fontSize = 16, textColor = {r = 230, g = 230, b = 240, a = 255}})
        end
    )

    -- RESIZABLE
    local panelId = clay.id("demo-resize-panel")
    clay.createElement(
        panelId,
        {
            layout = {
                sizing = {
                    width = clay.sizingFixed(panelW),
                    height = clay.sizingFixed(panelH)
                },
                childAlignment = {x = clay.ALIGN_X_CENTER, y = clay.ALIGN_Y_CENTER},
                padding = clay.paddingAll(12)
            },
            backgroundColor = {r = 30, g = 46, b = 75, a = 255},
            border = {color = COLOR_WHITE_32, width = {left = 1, right = 1, top = 1, bottom = 1}},
            cornerRadius = {topLeft = 8, topRight = 8, bottomLeft = 8, bottomRight = 8}
        },
        function()
            clay.createTextElement("Drag my bottom-right corner", {fontId = 1, fontSize = 16, textColor = COLOR_WHITE})
        end
    )

    -- make it resizable (invisible grip)
    panelW, panelH =
        clay.resizable(
        panelId,
        panelW,
        panelH,
        {
            minW = 140,
            minH = 80,
            snapW = 0,
            snapH = 0, -- e.g. set 64 for grid snapping
            showGrip = true -- set true to show a triangle grip
        }
    )
end
