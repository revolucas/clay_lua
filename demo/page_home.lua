function layout(dt)
    clay.createTextElement("Welcome to Clay Lua! Syntax and usage are nearly identical to the original Clay. However, there are a few differences:", { fontId=1, fontSize=16, textColor=COLOR_WHITE })
    clay.createTextElement("1. For 'clip' config, you must omit childOffset if you want to use Clay_GetScrollOffset; binding will handle it.", { fontId=1, fontSize=16, textColor=COLOR_WHITE })
    clay.createTextElement("\n2. When using 'createElement' children must be wrapped in a function, this is because children need to be deffered till after element is open and config is applied.", { fontId=1, fontSize=16, textColor=COLOR_WHITE })
	
	clay.createTextElement("Здравствуйте! There is unicode support!", { fontId=0, fontSize=16, textColor=COLOR_WHITE })
	
	clay.createTextElement("Below is an example of explicit API usage (open/configure/close):", { fontId=0, fontSize=16, textColor=COLOR_WHITE })
	clay.open(clay.id("Card"))
	clay.configure({
	  layout = {
		layoutDirection = clay.TOP_TO_BOTTOM,
		sizing = { width = clay.sizingPercent(1.0), height = clay.sizingFit() },
		padding = clay.paddingAll(10), childGap = 6,
	  },
	  backgroundColor = { r=46, g=50, b=62, a=255 },
	  cornerRadius = { topLeft=10, topRight=10, bottomLeft=10, bottomRight=10 },
	})

	  clay.open(clay.id("Card-Header"))
	  clay.configure({ layout = { sizing = { width = clay.sizingGrow(), height = clay.sizingFixed(28) } } })
		clay.createTextElement("Title", { fontId=1, fontSize=18 })
	  clay.close()

	  clay.open(clay.id("Card-Body"))
	  clay.configure({
		layout = { sizing = { width = clay.sizingGrow(), height = clay.sizingFit() }, childGap = 4 }
	  })
		for i = 1, 3 do
		  clay.open(clay.id("Card-Row", i))
		  clay.configure({
			layout = { sizing = { width = clay.sizingGrow(), height = clay.sizingFixed(24) }, padding = clay.paddingLTRB(8,4,8,4) },
			backgroundColor = { r=58, g=62, b=74, a=255 },
		  })
			clay.createTextElement(("Item %d"):format(i), { fontId=1, fontSize=14 })
		  clay.close()
		end
	  clay.close()

	clay.close()
end
