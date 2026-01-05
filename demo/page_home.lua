local function C(c) return c.r, c.g, c.b, c.a end

function layout(dt)
  clay.text("Welcome to Clay Lua! Syntax and usage are nearly identical to the original Clay. However, there are a few differences:")
    :fontId(1):fontSize(16)
    :textColor(C(COLOR_WHITE))
    :done()

  clay.text("1. For 'clip' config, you must omit childOffset if you want to use Clay_GetScrollOffset; binding will handle it.")
    :fontId(1):fontSize(16)
    :textColor(C(COLOR_WHITE))
    :done()

  clay.text("\n2. When using 'createElement' children must be wrapped in a function, this is because children need to be deffered till after element is open and config is applied.")
    :fontId(1):fontSize(16)
    :textColor(C(COLOR_WHITE))
    :done()

  clay.text("Здравствуйте! There is unicode support!")
    :fontId(0):fontSize(16)
    :textColor(C(COLOR_WHITE))
    :done()

  clay.text("Below is an example of explicit API usage (open/configure/close):")
    :fontId(0):fontSize(16)
    :textColor(C(COLOR_WHITE))
    :done()

  -- Card (explicit open/close because we're demonstrating leaf/explicit usage)
  local card = clay.element("Card")
    :layoutDirection(clay.TOP_TO_BOTTOM)
    :width(clay.SIZING_PERCENT, 1.0)
    :height(clay.SIZING_FIT)
    :padding(10)
    :childGap(6)
    :backgroundColor(46, 50, 62, 255)
    :cornerRadius(10)

  -- Card-Header
  clay.element("Card-Header")
    :width(clay.SIZING_GROW)
    :height(clay.SIZING_FIXED, 28)
    :children(function()
      clay.text("Title")
        :fontId(1):fontSize(18)
        :done()
    end)

  -- Card-Body
  clay.element("Card-Body")
    :width(clay.SIZING_GROW)
    :height(clay.SIZING_FIT)
    :childGap(4)
    :children(function()
      for i = 1, 3 do
        clay.element(clay.id("Card-Row", i))
          :width(clay.SIZING_GROW)
          :height(clay.SIZING_FIXED, 24)
          :padding(8, 4, 8, 4)
          :backgroundColor(58, 62, 74, 255)
          :children(function()
            clay.text(("Item %d"):format(i))
              :fontId(1):fontSize(14)
              :done()
          end)
      end
    end)

  -- Close Card (no :children() on the card itself)
  card:close()
end

