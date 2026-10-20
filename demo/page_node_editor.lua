local theme = require("theme")

local function C(color) return color.r, color.g, color.b, color.a end

local function format_value_a(value)
  return string.format("A: %.1f", value)
end

local function format_value_b(value)
  return string.format("B: %.1f", value)
end

local function render_value_property(node, zoom, contentWidth)
  node.value = clay.property(clay.id("NodeEditorValue:" .. node.id), node.label, node.value)
    :range(node.min, node.max)
    :step(node.step)
    :width(math.max(1, contentWidth - 4 * zoom))
    :height(28 * zoom)
    :buttonWidth(22 * zoom)
    :fontId(1)
    :fontSize(math.max(1, math.floor(12 * zoom + 0.5)))
    :arrowFontId(1)
    :arrowSize(math.max(1, math.floor(15 * zoom + 0.5)))
    :format(node.format)
    :draw()
end

local sourceA = clay.node("source-a")
  :label("A")
  :value(2.5)
  :range(0, 20)
  :step(0.5)
  :format(format_value_a)
  :title("Input A")
  :position(20, 38)
  :width(164)
  :output("value", "Value", "number")
  :open()
  :content(render_value_property, 34)
  :close()

local sourceB = clay.node("source-b")
  :label("B")
  :value(4.0)
  :range(0, 20)
  :step(0.5)
  :format(format_value_b)
  :title("Input B")
  :position(20, 180)
  :width(164)
  :output("value", "Value", "number")
  :open()
  :content(render_value_property, 34)
  :close()

local multiply = clay.node("multiply")
  :title("Multiply")
  :position(210, 105)
  :width(145)
  :input("a", "A", "number")
  :input("b", "B", "number")
  :output("result", "Result", "number")
  :close()

local graphNodes = { sourceA, sourceB, multiply }
local graphLinks = {
  { fromNode="source-a", fromPin="value", toNode="multiply", toPin="a" },
  { fromNode="source-b", fromPin="value", toNode="multiply", toPin="b" },
  { fromNode="multiply", fromPin="result", toNode="result", toPin="value" },
}

local function evaluate_output(nodeId, pinId, visiting)
  if nodeId == "source-a" and pinId == "value" then return sourceA.value end
  if nodeId == "source-b" and pinId == "value" then return sourceB.value end
  if nodeId ~= "multiply" or pinId ~= "result" then return nil end

  local visitKey = nodeId .. ":" .. pinId
  if visiting[visitKey] then return nil end
  visiting[visitKey] = true

  local inputA, inputB
  for i = #graphLinks, 1, -1 do
    local link = graphLinks[i]
    if link.toNode == "multiply" and (link.toPin == "a" or link.toPin == "b") then
      local value = evaluate_output(link.fromNode, link.fromPin, visiting)
      if link.toPin == "a" then inputA = value else inputB = value end
    end
  end

  visiting[visitKey] = nil
  if inputA == nil or inputB == nil then return nil end
  return inputA * inputB
end

local function evaluate_input(nodeId, pinId)
  for i = #graphLinks, 1, -1 do
    local link = graphLinks[i]
    if link.toNode == nodeId and link.toPin == pinId then
      return evaluate_output(link.fromNode, link.fromPin, {})
    end
  end
end

local resultNode = clay.node("result")
  :title("Result")
  :position(393, 105)
  :width(145)
  :input("value", "Value", "number")
  :open()
  :content(function(node, zoom)
    local result = evaluate_input(node.id, "value")
    local label = result ~= nil and string.format("%.2f", result) or "Connect A and B"
    local color = result ~= nil and theme.colors.accent or theme.colors.textMuted
    clay.element()
      :width(clay.SIZING_GROW)
      :height(clay.SIZING_GROW)
      :childAlignment(clay.ALIGN_X_CENTER, clay.ALIGN_Y_CENTER)
      :open()
    clay.text(label)
      :fontId(1)
      :fontSize(math.max(1, math.floor(20 * zoom + 0.5)))
      :textColor(C(color))
      :done()
    clay.close()
  end, 36)
  :close()

graphNodes[#graphNodes + 1] = resultNode

local graphApi
local nodeScrollY = 0
local pageX, pageY, pageWidth, pageHeight = 244, 106, 900, 700

local function update_page_bounds()
  local spacing = theme.spacing
  local defaults = theme.defaults
  pageX = 220 + spacing.controlGap + spacing.panelPadding
  -- The page label and spacer are in the immediate shell above ScrollViewport.
  pageY = 60 + spacing.controlGap + 22 + 2 + spacing.panelPadding
  pageWidth = math.max(1, device.width - pageX - spacing.controlGap
    - spacing.panelPadding - defaults.scrollbar.trackWidth - defaults.scrollbar.margin)
  pageHeight = math.max(1, device.height - pageY - spacing.controlGap)
end

update_page_bounds()

local root = clay.retained({ alias = "node-editor-page", layer = 10, visible = false }, function()
  clay.element("NodeEditorRetainedPage")
    :floating()
      :root()
      :offset(pageX, pageY)
      :done()
    :width(clay.SIZING_FIXED, pageWidth)
    :height(clay.SIZING_FIXED, pageHeight)
    :layoutDirection(clay.TOP_TO_BOTTOM)
    :clip(true, true)
    :childGap(theme.spacing.controlGap)
    :open()
  clay.text("Node Editor")
    :fontId(1)
    :fontSize(theme.type.heading)
    :textColor(C(theme.colors.text))
    :done()

  clay.text("Edit A and B inside their nodes. Multiply updates the result from their live values.")
    :fontId(1)
    :fontSize(theme.type.small)
    :textColor(C(theme.colors.textMuted))
    :done()

  local graphWidth = pageWidth
  local graphHeight = math.max(140, pageHeight - theme.type.heading - theme.type.small - 66)
  graphApi = clay.node_editor("demo-math")
    :width(graphWidth)
    :height(graphHeight)
    :nodes(graphNodes)
    :links(graphLinks)
    :scrollY(nodeScrollY)
    :inputLinkPolicy("replace")
    :draw()

  clay.text(("Selected nodes: %d    Connections: %d    Zoom: %d%%    Undo: %s    Redo: %s")
    :format(#graphApi.selectedNodes, #graphLinks,
      math.floor(graphApi.zoom * 100 + 0.5),
      graphApi.canUndo and "yes" or "no", graphApi.canRedo and "yes" or "no"))
    :fontId(1)
    :fontSize(theme.type.small)
    :textColor(C(theme.colors.textMuted))
    :done()
  clay.close() -- retained page
end)

root:update(function(self, _, input)
  local oldX, oldY, oldWidth, oldHeight = pageX, pageY, pageWidth, pageHeight
  update_page_bounds()
  nodeScrollY = -input.scrollY
  if pageX ~= oldX or pageY ~= oldY or pageWidth ~= oldWidth or pageHeight ~= oldHeight then
    self:invalidate()
  end
  if graphApi and graphApi.interacting then self:invalidate() end
end)

function onShow()
  update_page_bounds()
  root:show()
end

function onHide()
  root:hide()
end

-- This invisible spacer keeps the shared immediate ScrollViewport sized to the
-- retained page. The graph itself is built and rendered by the retained root.
function layout()
  clay.element("NodeEditorRetainedPlaceholder")
    :width(clay.SIZING_FIXED, pageWidth)
    :height(clay.SIZING_FIXED, pageHeight)
    :close()
end
