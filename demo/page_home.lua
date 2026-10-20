local function C(c) return c.r, c.g, c.b, c.a end

function layout(dt)
  clay.text("Clay Lua uses a fluent builder API. Configure elements with chained methods, then open parents and close them after their children:")
    :fontId(1):fontSize(16)
    :textColor(C(COLOR_WHITE))
    :done()

  clay.text("For scrollable elements, :clip(horizontal, vertical) uses Clay's scroll offset automatically unless you set :childOffset(...).")
    :fontId(1):fontSize(16)
    :textColor(C(COLOR_WHITE))
    :done()

  clay.text("Floating placement is configured in a nested :floating() builder, so attachment, offset, clipping, and z-order stay grouped.")
    :fontId(1):fontSize(16)
    :textColor(C(COLOR_WHITE))
    :done()

  clay.text("Здравствуйте! There is unicode support!")
    :fontId(0):fontSize(16)
    :textColor(C(COLOR_WHITE))
    :done()

  clay.text("A nested card built with :open() and :close():")
    :fontId(0):fontSize(16)
    :textColor(C(COLOR_WHITE))
    :done()

  clay.element("Card")
    :layoutDirection(clay.TOP_TO_BOTTOM)
    :width(clay.SIZING_PERCENT, 1.0)
    :height(clay.SIZING_FIT)
    :padding(10)
    :childGap(6)
    :backgroundColor(C(theme.colors.surface))
    :cornerRadius(10)
    :open()
  clay.element("Card-Header")
    :width(clay.SIZING_GROW)
    :height(clay.SIZING_FIXED, 28)
    :open()
  clay.text("Title")
    :fontId(1):fontSize(18)
    :done()
  clay.close() -- Card-Header

  clay.element("Card-Body")
    :width(clay.SIZING_GROW)
    :height(clay.SIZING_FIT)
    :childGap(4)
    :open()
  for i = 1, 3 do
    clay.element(clay.id("Card-Row", i))
      :width(clay.SIZING_GROW)
      :height(clay.SIZING_FIXED, 24)
      :padding(8, 4, 8, 4)
      :backgroundColor(C(theme.colors.surfaceRaised))
      :open()
    clay.text(("Item %d"):format(i))
      :fontId(1):fontSize(14)
      :done()
    clay.close() -- Card-Row
  end
  clay.close() -- Card-Body
  clay.close() -- Card

  clay.text("A video tile with nested layout builders:")
    :fontId(0):fontSize(16)
    :textColor(C(COLOR_WHITE))
    :done()

  clay.element("VideoTile")
    :width(clay.SIZING_FIXED, 300)
    :height(clay.SIZING_FIXED, 250)
    :layoutDirection(clay.LEFT_TO_RIGHT)
    :childGap(5)
    :open()
  clay.element("VideoThumbnail")
    :width(clay.SIZING_FIXED, 50)
    :height(clay.SIZING_FIXED, 50)
    :backgroundColor(16, 16, 16, 255)
    :close()

  clay.element("VideoDetails")
    :width(clay.SIZING_GROW)
    :height(clay.SIZING_GROW)
    :layoutDirection(clay.TOP_TO_BOTTOM)
    :open()
  clay.text("Video Title 3. Lorem Ipsum Solor Domet Lorem Ipsum Solor Domet. Lorem Ipsum Solor")
    :fontId(1):fontSize(14)
    :done()

  clay.element("VideoMetadata")
    :width(clay.SIZING_FIT)
    :height(clay.SIZING_FIT)
    :layoutDirection(clay.LEFT_TO_RIGHT)
    :childGap(5)
    :open()
  clay.text("Long Title Corp.") :fontId(1):fontSize(12):done()
  clay.text("2000 views") :fontId(1):fontSize(12):done()
  clay.text("1 comment") :fontId(1):fontSize(12):done()
  clay.close() -- VideoMetadata

  clay.element("VideoPreview")
    :width(clay.SIZING_GROW)
    :height(clay.SIZING_FIXED, 100)
    :backgroundColor(0, 255, 0, 255)
    :close()
  clay.close() -- VideoDetails
  clay.close() -- VideoTile
end
