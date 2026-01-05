local window = require("window")

local function C(c) return c.r, c.g, c.b, c.a end

local radi  = 0
local radii = 1
local last_time = 0

function layout(dt)
  clay.text("Corner Radius")
    :fontId(1):fontSize(16)
    :textColor(220, 220, 240, 255)
    :done()

  clay.text("Shader-driven radius rounding")
    :fontId(1):fontSize(16)
    :textColor(C(COLOR_WHITE))
    :textAlignment(clay.TEXT_ALIGN_CENTER)
    :done()

  -- leaf elements => explicit :close()

  clay.element("round_box")
    :width(clay.SIZING_FIXED, 50)
    :height(clay.SIZING_FIXED, 50)
    :layoutDirection(clay.TOP_TO_BOTTOM)
    :backgroundColor(255, 0, 0, 255)
    :borderColor(C(COLOR_WHITE))
    :borderWidth(1)
    :cornerRadius(8)
    :close()

  clay.element("round_circle1")
    :width(clay.SIZING_FIXED, 50)
    :height(clay.SIZING_FIXED, 50)
    :layoutDirection(clay.TOP_TO_BOTTOM)
    :childAlignment(clay.ALIGN_X_CENTER, clay.ALIGN_Y_CENTER)
    :backgroundColor(255, 0, 0, 255)
    :cornerRadius(radi)
    :children(function()
      clay.text(tostring(radi))
        :fontId(1):fontSize(16)
        :textColor(220, 220, 240, 255)
        :textAlignment(clay.TEXT_ALIGN_CENTER)
        :done()
    end)

  clay.element("round_circle2")
    :width(clay.SIZING_FIXED, 50)
    :height(clay.SIZING_FIXED, 50)
    :layoutDirection(clay.TOP_TO_BOTTOM)
    :backgroundColor(255, 0, 0, 255)
    :borderColor(C(COLOR_WHITE))
    :borderWidth(1)
    :cornerRadius(radi)
    :close()

  clay.element("real_circle")
    :width(clay.SIZING_FIXED, 50)
    :height(clay.SIZING_FIXED, 50)
    :layoutDirection(clay.TOP_TO_BOTTOM)
    :backgroundColor(255, 0, 0, 255)
    :borderColor(C(COLOR_WHITE))
    :borderWidth(1)
    :cornerRadius(-1)
    :close()

	if window.time() > last_time + 0.05 then
		last_time = window.time()
		radi = radi + radii
		if radi > 55 then
		  radii = -1
		elseif radi <= 0 then
		  radii = 1
		end
	end
end
