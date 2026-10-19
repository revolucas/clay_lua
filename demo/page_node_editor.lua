local function C(c) return c.r, c.g, c.b, c.a end

local function format_value_a(value)
  return string.format("A: %.1f", value)
end

local function format_value_b(value)
  return string.format("B: %.1f", value)
end

local function render_value_property(node, zoom, contentWidth)
  local options = node.propertyOptions
  options.width = math.max(1, contentWidth - 4 * zoom)
  options.height = 28 * zoom
  options.buttonW = 22 * zoom
  options.fontSize = 12 * zoom
  options.arrowSize = 15 * zoom
  node.value = clay.property(clay.id("NodeEditorValue:" .. node.id), node.label, node.value, options)
end

local sourceA = clay.node("source-a", {
  label="A", value=2.5,
  propertyOptions={
    min=0, max=20, step=0.5, fontId=1, arrowFontId=1,
    format=format_value_a,
  },
})
  :title("Input A")
  :position(20, 38)
  :width(164)
  :output({ id="value", label="Value", type="number" })
  :open()
  :children(render_value_property, 34)
  :close()

local sourceB = clay.node("source-b", {
  label="B", value=4.0,
  propertyOptions={
    min=0, max=20, step=0.5, fontId=1, arrowFontId=1,
    format=format_value_b,
  },
})
  :title("Input B")
  :position(20, 180)
  :width(164)
  :output({ id="value", label="Value", type="number" })
  :open()
  :children(render_value_property, 34)
  :close()

local multiply = clay.node("multiply")
  :title("Multiply")
  :position(210, 105)
  :width(145)
  :input({ id="a", label="A", type="number" })
  :input({ id="b", label="B", type="number" })
  :output({ id="result", label="Result", type="number" })
  :close()

local render_result
local function render_result_content(node, zoom, contentWidth)
  return render_result(node, zoom, contentWidth)
end

local resultNode = clay.node("result")
  :title("Result")
  :position(393, 105)
  :width(145)
  :input({ id="value", label="Value", type="number" })
  :open()
  :children(render_result_content, 36)
  :close()

local graphNodes = { sourceA, sourceB, multiply, resultNode }
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

render_result = function(node, zoom, contentWidth)
  local value = evaluate_input(node.id, "value")
  local label = value ~= nil and string.format("%.2f", value) or "Connect A and B"
  local color = value ~= nil and theme.colors.accent or theme.colors.textMuted

  clay.element(clay.id("NodeEditorResultValue:" .. node.id))
    :width(clay.SIZING_GROW)
    :height(clay.SIZING_GROW)
    :childAlignment(clay.ALIGN_X_CENTER, clay.ALIGN_Y_CENTER)
    :children(function()
      clay.text(label)
        :fontId(1):fontSize(20 * zoom):textColor(C(color)):done()
  end)
end

function layout()
  clay.text("Node Editor")
    :fontId(1):fontSize(theme.type.heading):textColor(C(theme.colors.text)):done()
  clay.text("Edit A and B inside their nodes. The Multiply node sends its live result to the Result node.")
    :fontId(1):fontSize(theme.type.small):textColor(C(theme.colors.textMuted)):done()

  local graphWidth = math.max(550, device.width - 300)
  local graphHeight = math.max(340, device.height - 220)
  local graph = clay.node_editor("demo-math", {
    width=graphWidth,
    height=graphHeight,
    nodes=graphNodes,
    links=graphLinks,
    inputLinkPolicy="replace",
  })

  clay.text(("Selected nodes: %d    Selected link: %s    Connections: %d    Zoom: %d%%    Undo: %s    Redo: %s")
      :format(#graph.selectedNodes, graph.selectedLink and "yes" or "none", #graphLinks,
          math.floor(graph.zoom * 100 + 0.5), graph.canUndo and "yes" or "no", graph.canRedo and "yes" or "no"))
    :fontId(1):fontSize(theme.type.small):textColor(C(theme.colors.textMuted)):done()
end
