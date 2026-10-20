local function C(color) return color.r, color.g, color.b, color.a end

local count = clay.state(0)
local immediateFrames = 0
local updateTicks = 0
local polledTime = 0
local panelX, panelY

local function retained_panel_position(width, height)
  if width >= 1120 then return 720, 170 end
  return 240, math.max(150, math.min(320, height - 300))
end

panelX, panelY = retained_panel_position(device.width, device.height)

local root = clay.retained({ alias = "retained-counter", layer = 10 }, function()
  clay.element():alias("panel")
    :floating():root():offset(panelX, panelY):done()
    :width(clay.SIZING_FIXED, 390)
    :height(clay.SIZING_FIT)
    :padding(18)
    :childGap(12)
    :col()
    :backgroundColor(C(theme.colors.surfaceRaised))
    :borderColor(C(theme.colors.borderStrong))
    :borderWidth(1)
    :cornerRadius(10)
    :open()
  clay.text("Retained counter")
    :fontId(1):fontSize(22)
    :textColor(C(theme.colors.textStrong))
    :done()

  clay.text("This panel rebuilds only when its state changes.")
    :fontId(1):fontSize(14)
    :textColor(C(theme.colors.textMuted))
    :done()

  clay.element():alias("value")
    :width(clay.SIZING_GROW)
    :height(clay.SIZING_FIXED, 52)
    :childAlignment(clay.ALIGN_X_CENTER, clay.ALIGN_Y_CENTER)
    :backgroundColor(C(theme.colors.content))
    :cornerRadius(6)
    :open()
  clay.text("Value: " .. tostring(count:get()))
    :fontId(1):fontSize(24)
    :textColor(C(theme.colors.text))
    :done()
  clay.close()

  clay.element():alias("increment")
    :width(clay.SIZING_GROW)
    :height(clay.SIZING_FIXED, 42)
    :childAlignment(clay.ALIGN_X_CENTER, clay.ALIGN_Y_CENTER)
    :backgroundColor(C(theme.colors.accent))
    :cornerRadius(6)
    :open()
  clay.text("Click to increment")
    :fontId(1):fontSize(16)
    :textColor(C(theme.colors.textStrong))
    :done()
  clay.close()

  clay.element():alias("reset")
    :width(clay.SIZING_GROW)
    :height(clay.SIZING_FIXED, 34)
    :childAlignment(clay.ALIGN_X_CENTER, clay.ALIGN_Y_CENTER)
    :backgroundColor(C(theme.colors.sidebar))
    :cornerRadius(5)
    :open()
  clay.text("Reset")
    :fontId(1):fontSize(14)
    :textColor(C(theme.colors.text))
    :done()
  clay.close()
  clay.close() -- retained counter panel
end)

root:on("increment", "click", function()
  count:set(count:get() + 1)
end)

root:on("reset", "click", function()
  count:set(0)
end)

root:update(function(_, dt, input)
  updateTicks = updateTicks + 1
  polledTime = polledTime + dt
  local nextX, nextY = retained_panel_position(device.width, device.height)
  if nextX ~= panelX or nextY ~= panelY then
    panelX, panelY = nextX, nextY
    root:invalidate()
  end
end)

function onShow()
  root:show()
end

function onHide()
  root:hide()
end

function layout(dt)
  immediateFrames = immediateFrames + 1
  local stats = root:stats()
  local statsWidth = panelX >= 600 and 420 or math.max(240, device.width - 280)

  clay.element("RetainedStats")
    :width(clay.SIZING_FIXED, statsWidth)
    :height(clay.SIZING_FIT)
    :childGap(8)
    :open()
  clay.text("Immediate content keeps updating every frame.")
    :fontId(1):fontSize(18)
    :textColor(C(theme.colors.textStrong))
    :done()
  clay.text("Immediate frame: " .. tostring(immediateFrames))
    :fontId(1):fontSize(15)
    :textColor(C(theme.colors.textMuted))
    :done()
  clay.text("Retained builds: " .. tostring(stats.builds))
    :fontId(1):fontSize(15)
    :textColor(C(theme.colors.textMuted))
    :done()
  clay.text("Cached packet replays: " .. tostring(stats.replays))
    :fontId(1):fontSize(15)
    :textColor(C(theme.colors.textMuted))
    :done()
  clay.text("Per-frame update callbacks: " .. tostring(updateTicks))
    :fontId(1):fontSize(15)
    :textColor(C(theme.colors.textMuted))
    :done()
  clay.text(string.format("Time polled without rebuilding: %.2fs", polledTime))
    :fontId(1):fontSize(15)
    :textColor(C(theme.colors.textMuted))
    :done()
  clay.text("Click the retained panel buttons, then watch builds stay flat between changes.")
    :fontId(1):fontSize(14)
    :textColor(C(theme.colors.textMuted))
    :done()
  clay.close()
end
