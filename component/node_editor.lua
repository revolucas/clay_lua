-- Node graph editor built from Clay elements plus one batched custom draw command.
local window = require("window")
local theme = require("theme")

_node_editor_state = _node_editor_state or {}

local DEFAULTS = {
  minZoom = 0.4,
  maxZoom = 2.25,
  zoomStep = 1.12,
}

local TYPE_COLORS = {
  flow = { r=240, g=190, b=80, a=255 },
  exec = { r=240, g=190, b=80, a=255 },
  bool = { r=220, g=85, b=94, a=255 },
  number = { r=105, g=190, b=120, a=255 },
  float = { r=105, g=190, b=120, a=255 },
  int = { r=105, g=190, b=120, a=255 },
  string = { r=220, g=170, b=85, a=255 },
  vector = { r=95, g=165, b=230, a=255 },
  color = { r=190, g=115, b=225, a=255 },
}

local NodeBuilder = {}
NodeBuilder.__index = function(self, name)
  local method = NodeBuilder[name]
  if method then return method end
  if name == "_data" or name == "_open" or name == "_closed" then
    return rawget(self, name)
  end
  return self._data[name]
end
NodeBuilder.__newindex = function(self, name, value)
  if name:sub(1, 1) == "_" then rawset(self, name, value)
  else self._data[name] = value end
end

local function node_builder_data(self)
  if rawget(self, "_closed") then error("node builder is closed", 3) end
  return rawget(self, "_data")
end

function NodeBuilder:title(value)
  node_builder_data(self).title = value
  return self
end

function NodeBuilder:position(x, y)
  local data = node_builder_data(self)
  data.x, data.y = x, y
  return self
end

function NodeBuilder:width(value)
  node_builder_data(self).width = value
  return self
end

function NodeBuilder:height(value)
  node_builder_data(self).height = value
  return self
end

function NodeBuilder:input(pin, label, pinType)
  local data = node_builder_data(self)
  if type(pin) ~= "table" then pin = { id=pin, label=label, type=pinType } end
  data.inputs[#data.inputs + 1] = pin
  return self
end

function NodeBuilder:output(pin, label, pinType)
  local data = node_builder_data(self)
  if type(pin) ~= "table" then pin = { id=pin, label=label, type=pinType } end
  data.outputs[#data.outputs + 1] = pin
  return self
end

function NodeBuilder:open()
  node_builder_data(self)
  if self._open then error("node builder is already open", 2) end
  self._open = true
  return self
end

function NodeBuilder:children(callback, contentHeight)
  local data = node_builder_data(self)
  if not self._open then error("call node:open() before node:children()", 2) end
  if type(callback) ~= "function" then error("node:children expects a function", 2) end
  data.content = callback
  if contentHeight ~= nil then data.contentHeight = contentHeight end
  return self
end

function NodeBuilder:close()
  local data = node_builder_data(self)
  self._closed = true
  return data
end

function node(id, options)
  local data = {}
  for name, value in pairs(options or {}) do data[name] = value end
  data.id = id
  data.inputs = data.inputs or {}
  data.outputs = data.outputs or {}
  return setmetatable({ _data=data, _open=false, _closed=false }, NodeBuilder)
end

local function clamp(value, low, high)
  if value < low then return low end
  if value > high then return high end
  return value
end

local function key(value)
  return tostring(value == nil and "" or value)
end

local function node_id(graphKey, nodeKey)
  return clay.id("NodeEditorNode:" .. graphKey .. ":" .. key(nodeKey))
end

local function header_id(graphKey, nodeKey)
  return clay.id("NodeEditorHeader:" .. graphKey .. ":" .. key(nodeKey))
end

local function content_id(graphKey, nodeKey)
  return clay.id("NodeEditorContent:" .. graphKey .. ":" .. key(nodeKey))
end

local function pin_id(graphKey, nodeKey, direction, pinKey)
  return clay.id("NodeEditorPin:" .. graphKey .. ":" .. key(nodeKey) .. ":" .. direction .. ":" .. key(pinKey))
end

local function pin_key(pin, index)
  return pin.id ~= nil and pin.id or index
end

local function color_for_pin(pin, opts)
  if pin.color then return pin.color end
  local colors = opts.pinColors
  if colors and pin.type and colors[pin.type] then return colors[pin.type] end
  return TYPE_COLORS[pin.type] or (opts.pinColor or theme.colors.nodeEditor.pinColor)
end

local function get_node(nodes, wanted)
  for i = 1, #nodes do
    if key(nodes[i].id or i) == key(wanted) then return nodes[i], i end
  end
end

local function hovered_pin_on_node(graphKey, node, nodeKey)
    local inputs, outputs = node.inputs or {}, node.outputs or {}
    for pi = 1, #outputs do
      local pin = outputs[pi]
      if clay.pointerOver(pin_id(graphKey, nodeKey, "out", pin_key(pin, pi))) then
        return { node=node, nodeId=nodeKey, pin=pin, pinId=pin_key(pin, pi), direction="out" }
      end
    end
    for pi = 1, #inputs do
      local pin = inputs[pi]
      if clay.pointerOver(pin_id(graphKey, nodeKey, "in", pin_key(pin, pi))) then
        return { node=node, nodeId=nodeKey, pin=pin, pinId=pin_key(pin, pi), direction="in" }
      end
    end
end

local function find_hovered_pin(graphKey, nodes, selectedNode)
  if selectedNode ~= nil then
    local selected = get_node(nodes, selectedNode)
    if selected then
      local pin = hovered_pin_on_node(graphKey, selected, selectedNode)
      if pin then return pin end
    end
  end
  for ni = #nodes, 1, -1 do
    local node = nodes[ni]
    local nodeKey = node.id or ni
    if key(nodeKey) ~= key(selectedNode) then
      local pin = hovered_pin_on_node(graphKey, node, nodeKey)
      if pin then return pin end
    end
  end
end

local function node_position(st, node, nodeKey)
  local drag = st.dragPositions and st.dragPositions[key(nodeKey)]
  if drag then return drag.x, drag.y end
  local defaults = theme.defaults.nodeEditor
  return tonumber(node.x) or defaults.defaultPosition,
      tonumber(node.y) or defaults.defaultPosition
end

local function node_content_height(node)
  if type(node.content) ~= "function" then return 0 end
  return math.max(0, tonumber(node.contentHeight) or theme.defaults.nodeEditor.contentHeight)
end

local function node_content_gap(node)
  if node_content_height(node) <= 0 then return 0 end
  return math.max(0, tonumber(node.contentGap) or theme.defaults.nodeEditor.contentGap)
end

local function node_dimensions(node, opts)
  local defaults = theme.defaults.nodeEditor
  local width = tonumber(node.width) or tonumber(opts.nodeWidth) or defaults.nodeWidth
  local inputs, outputs = node.inputs or {}, node.outputs or {}
  local rows = math.max(#inputs, #outputs, 1)
  local height = tonumber(node.height) or (tonumber(opts.headerHeight) or defaults.headerHeight)
      + 2 * (tonumber(opts.bodyPadding) or defaults.bodyPadding)
      + node_content_height(node) + node_content_gap(node)
      + rows * (tonumber(opts.rowHeight) or defaults.rowHeight)
  return width, height
end

local function selection_list(st)
  local result = {}
  for _, nodeId in pairs(st.selectedNodes or {}) do result[#result + 1] = nodeId end
  table.sort(result, function(a, b) return key(a) < key(b) end)
  return result
end

local function clear_selection(st)
  st.selectedNodes = {}
  st.selectedNode = nil
end

local function select_only(st, nodeId)
  st.selectedNodes = {}
  if nodeId ~= nil then st.selectedNodes[key(nodeId)] = nodeId end
  st.selectedNode = nodeId
end

local function is_selected(st, nodeId)
  return st.selectedNodes and st.selectedNodes[key(nodeId)] ~= nil
      or key(st.selectedNode) == key(nodeId)
end

local function update_primary_selection(st, preferred)
  if preferred ~= nil and is_selected(st, preferred) then
    st.selectedNode = preferred
    return
  end
  local items = selection_list(st)
  st.selectedNode = items[#items]
end

local function snapshot_graph(nodes, links, st, positionOverrides)
  local snapshot = { nodes={}, links={}, positions={}, selectedNodes=selection_list(st),
    selectedNode=st.selectedNode, selectedLink=st.selectedLink and links[st.selectedLink] or nil }
  for i = 1, #nodes do
    local node = nodes[i]
    local nodeId = node.id or i
    local override = positionOverrides and positionOverrides[key(nodeId)]
    snapshot.nodes[i] = node
    snapshot.positions[i] = { node=node, x=override and override.x or node.x,
      y=override and override.y or node.y, id=nodeId }
  end
  for i = 1, #links do snapshot.links[i] = links[i] end
  return snapshot
end

local function restore_array(target, source)
  for i = #target, 1, -1 do target[i] = nil end
  for i = 1, #source do target[i] = source[i] end
end

local function copy_snapshot(snapshot)
  local copy = { nodes={}, links={}, positions={}, selectedNodes={},
    selectedNode=snapshot.selectedNode, selectedLink=snapshot.selectedLink }
  for i = 1, #snapshot.nodes do copy.nodes[i] = snapshot.nodes[i] end
  for i = 1, #snapshot.links do copy.links[i] = snapshot.links[i] end
  for i = 1, #snapshot.positions do
    local item = snapshot.positions[i]
    copy.positions[i] = { node=item.node, x=item.x, y=item.y, id=item.id }
  end
  for i = 1, #snapshot.selectedNodes do copy.selectedNodes[i] = snapshot.selectedNodes[i] end
  return copy
end

local function restore_graph(snapshot, nodes, links, st)
  restore_array(nodes, snapshot.nodes)
  restore_array(links, snapshot.links)
  for i = 1, #snapshot.positions do
    local item = snapshot.positions[i]
    item.node.x, item.node.y = item.x, item.y
  end
  st.selectedNodes = {}
  for i = 1, #snapshot.selectedNodes do
    local nodeId = snapshot.selectedNodes[i]
    st.selectedNodes[key(nodeId)] = nodeId
  end
  st.selectedNode = snapshot.selectedNode
  st.selectedLink = nil
  if snapshot.selectedLink then
    for i = 1, #links do
      if links[i] == snapshot.selectedLink then st.selectedLink = i; break end
    end
  end
  st.dragNode, st.dragPositions, st.boxSelect, st.connecting = nil, nil, nil, nil
end

local function snapshot_remove_links(snapshot, removedLinks)
  local removed = {}
  for i = 1, #removedLinks do removed[removedLinks[i]] = true end
  local kept, selectedRemoved = {}, snapshot.selectedLink and removed[snapshot.selectedLink]
  for i = 1, #snapshot.links do
    local link = snapshot.links[i]
    if not removed[link] then kept[#kept + 1] = link end
  end
  snapshot.links = kept
  if selectedRemoved then snapshot.selectedLink = nil end
end

local function link_matches(a, b)
  return key(a.fromNode) == key(b.fromNode) and key(a.fromPin) == key(b.fromPin)
      and key(a.toNode) == key(b.toNode) and key(a.toPin) == key(b.toPin)
end

local function snapshot_add_link(snapshot, link)
  for i = 1, #snapshot.links do
    if snapshot.links[i] == link or link_matches(snapshot.links[i], link) then return end
  end
  snapshot.links[#snapshot.links + 1] = link
end

local function snapshot_remove_nodes(snapshot, selectedKeys)
  local nodes, positions, removedKeys = {}, {}, {}
  for i = 1, #snapshot.nodes do
    local node, position = snapshot.nodes[i], snapshot.positions[i]
    local nodeId = node.id or position.id or i
    if selectedKeys[key(nodeId)] then
      removedKeys[key(nodeId)] = true
    else
      nodes[#nodes + 1] = node
      positions[#positions + 1] = position
    end
  end
  snapshot.nodes, snapshot.positions = nodes, positions
  local links, selectedLinkRemoved = {}, false
  for i = 1, #snapshot.links do
    local link = snapshot.links[i]
    if removedKeys[key(link.fromNode)] or removedKeys[key(link.toNode)] then
      if link == snapshot.selectedLink then selectedLinkRemoved = true end
    else
      links[#links + 1] = link
    end
  end
  snapshot.links = links
  if selectedLinkRemoved then snapshot.selectedLink = nil end
  local selectedNodes = {}
  for i = 1, #snapshot.selectedNodes do
    local nodeId = snapshot.selectedNodes[i]
    if not removedKeys[key(nodeId)] then selectedNodes[#selectedNodes + 1] = nodeId end
  end
  snapshot.selectedNodes = selectedNodes
  if snapshot.selectedNode ~= nil and removedKeys[key(snapshot.selectedNode)] then
    snapshot.selectedNode = selectedNodes[#selectedNodes]
  end
end

local function history_restore_payload(snapshot)
  local positions = {}
  for i = 1, #snapshot.positions do
    local item = snapshot.positions[i]
    positions[i] = { id=item.id, x=item.x, y=item.y, node=item.node }
  end
  local selectedNodes = {}
  for i = 1, #snapshot.selectedNodes do selectedNodes[i] = snapshot.selectedNodes[i] end
  local nodes, links = {}, {}
  for i = 1, #snapshot.nodes do nodes[i] = snapshot.nodes[i] end
  for i = 1, #snapshot.links do links[i] = snapshot.links[i] end
  return { nodes=nodes, links=links, positions=positions, selectedNodes=selectedNodes,
    selectedNode=snapshot.selectedNode, selectedLink=snapshot.selectedLink }
end

local function push_history(st, before, after, limit)
  limit = tonumber(limit)
  if limit == nil then limit = 100 end
  if limit <= 0 then
    st.undoStack, st.redoStack = {}, {}
    return
  end
  st.undoStack = st.undoStack or {}
  st.redoStack = {}
  st.undoStack[#st.undoStack + 1] = { before=before, after=after }
  while #st.undoStack > limit do table.remove(st.undoStack, 1) end
end

local function pin_center(node, nodeKey, pin, index, direction, zoom, nodeWidth, headerHeight, rowHeight, bodyPadding, st)
  local nx, ny = node_position(st, node, nodeKey)
  local hitboxRadius = math.max(12, math.floor(16 * zoom + 0.5)) * 0.5 / zoom
  local px = direction == "out" and (nodeWidth - bodyPadding - hitboxRadius) or (bodyPadding + hitboxRadius)
  local py = headerHeight + bodyPadding + node_content_height(node) + node_content_gap(node)
      + (index - 0.5) * rowHeight
  return st.panX + (nx + px) * zoom, st.panY + (ny + py) * zoom
end

local function link_endpoints(graphKey, nodes, link, opts, st, zoom, linkIndex)
  local fromNode, toNode = get_node(nodes, link.fromNode), get_node(nodes, link.toNode)
  if not fromNode or not toNode then return nil end
  local fromPinIndex, toPinIndex
  local fromPin, toPin
  for i, pin in ipairs(fromNode.outputs or {}) do
    if key(pin_key(pin, i)) == key(link.fromPin) then fromPin, fromPinIndex = pin, i; break end
  end
  for i, pin in ipairs(toNode.inputs or {}) do
    if key(pin_key(pin, i)) == key(link.toPin) then toPin, toPinIndex = pin, i; break end
  end
  if not fromPin or not toPin then return nil end

  local defaults = theme.defaults.nodeEditor
  local nodeWidth = opts.nodeWidth or defaults.nodeWidth
  local headerHeight = opts.headerHeight or defaults.headerHeight
  local rowHeight = opts.rowHeight or defaults.rowHeight
  local bodyPadding = opts.bodyPadding or defaults.bodyPadding
  local fromX, fromY = pin_center(fromNode, link.fromNode, fromPin, fromPinIndex, "out", zoom,
      fromNode.width or nodeWidth, headerHeight, rowHeight, bodyPadding, st)
  local toX, toY = pin_center(toNode, link.toNode, toPin, toPinIndex, "in", zoom,
      toNode.width or nodeWidth, headerHeight, rowHeight, bodyPadding, st)
  local selected = st.selectedLink == linkIndex
  return {
    x0=fromX, y0=fromY, x1=toX, y1=toY,
    color=selected and (opts.selectedLinkColor or theme.colors.nodeEditor.selectedLinkColor)
        or link.color or color_for_pin(fromPin, opts),
    width=selected and (opts.selectedLinkWidth or defaults.selectedLinkWidth * zoom)
        or link.width or defaults.linkWidth * zoom,
    linkIndex=linkIndex,
  }
end

local function curve_distance(edge, x, y, zoom)
  local x0, y0, x1, y1 = edge.x0, edge.y0, edge.x1, edge.y1
  local bend = math.max(28 * zoom, math.abs(x1 - x0) * 0.48)
  local direction = x1 >= x0 and 1 or -1
  local c1x, c1y = x0 + bend * direction, y0
  local c2x, c2y = x1 - bend * direction, y1
  local lastX, lastY, closest = x0, y0, math.huge
  for step = 1, 16 do
    local t = step / 16
    local inv = 1 - t
    local px = inv * inv * inv * x0 + 3 * inv * inv * t * c1x + 3 * inv * t * t * c2x + t * t * t * x1
    local py = inv * inv * inv * y0 + 3 * inv * inv * t * c1y + 3 * inv * t * t * c2y + t * t * t * y1
    local dx, dy = px - lastX, py - lastY
    local lengthSq = dx * dx + dy * dy
    local along = lengthSq > 0 and clamp(((x - lastX) * dx + (y - lastY) * dy) / lengthSq, 0, 1) or 0
    local nearX, nearY = lastX + along * dx, lastY + along * dy
    local distX, distY = x - nearX, y - nearY
    closest = math.min(closest, distX * distX + distY * distY)
    lastX, lastY = px, py
  end
  return math.sqrt(closest)
end

local function hit_wire(wires, x, y, zoom, radius)
  local hitIndex, closest = nil, radius
  -- Later links render over earlier ones, so inspect them first on ties.
  for i = #wires, 1, -1 do
    local wire = wires[i]
    local distance = curve_distance(wire, x, y, zoom)
    if distance <= closest then
      hitIndex, closest = wire.linkIndex, distance
    end
  end
  return hitIndex
end

local function pin_visual(direction, graphKey, nodeKey, pin, index, opts, zoom)
  local id = pin_id(graphKey, nodeKey, direction, pin_key(pin, index))
  local size = math.max(12, math.floor(16 * zoom + 0.5))
  local dot = math.max(7, math.floor(9 * zoom + 0.5))
  local col = color_for_pin(pin, opts)
  clay.element(id)
    :width(clay.SIZING_FIXED, size)
    :height(clay.SIZING_FIXED, size)
    :childAlignment(clay.ALIGN_X_CENTER, clay.ALIGN_Y_CENTER)
    :children(function()
      clay.element(clay.id("NodeEditorPinDot:" .. graphKey .. ":" .. key(nodeKey) .. ":" .. direction .. ":" .. key(pin_key(pin, index))))
        :width(clay.SIZING_FIXED, dot)
        :height(clay.SIZING_FIXED, dot)
        :backgroundColor(col.r, col.g, col.b, col.a)
        :cornerRadius(-1, -1, -1, -1)
        :close()
    end)
end

local function port_slot(graphKey, nodeKey, pin, index, direction, opts, zoom)
  local label = pin.label or pin.name or key(pin_key(pin, index))
  local defaults = theme.defaults.nodeEditor
  clay.element(clay.id("NodeEditorPort:" .. graphKey .. ":" .. key(nodeKey) .. ":" .. direction .. ":" .. index))
    :layoutDirection(clay.LEFT_TO_RIGHT)
    :width(clay.SIZING_GROW)
    :height(clay.SIZING_GROW)
    :childGap(math.max(3, math.floor(defaults.pinGap * zoom)))
    :childAlignment(direction == "in" and clay.ALIGN_X_LEFT or clay.ALIGN_X_RIGHT, clay.ALIGN_Y_CENTER)
    :children(function()
      if direction == "in" then
        pin_visual(direction, graphKey, nodeKey, pin, index, opts, zoom)
        clay.text(label):fontId(opts.fontId or defaults.fontId)
          :fontSize(math.max(9, math.floor((opts.fontSize or theme.type.small) * zoom + 0.5)))
        :textColor((opts.textColor or theme.colors.nodeEditor.textColor).r, (opts.textColor or theme.colors.nodeEditor.textColor).g,
              (opts.textColor or theme.colors.nodeEditor.textColor).b, (opts.textColor or theme.colors.nodeEditor.textColor).a):done()
      else
        clay.text(label):fontId(opts.fontId or defaults.fontId)
          :fontSize(math.max(9, math.floor((opts.fontSize or theme.type.small) * zoom + 0.5)))
          :textColor((opts.textColor or theme.colors.nodeEditor.textColor).r, (opts.textColor or theme.colors.nodeEditor.textColor).g,
              (opts.textColor or theme.colors.nodeEditor.textColor).b, (opts.textColor or theme.colors.nodeEditor.textColor).a):done()
        pin_visual(direction, graphKey, nodeKey, pin, index, opts, zoom)
      end
    end)
end

local function draw_node(graphKey, node, index, opts, st)
  local nodeKey = node.id or index
  local zoom = st.zoom
  local defaults = theme.defaults.nodeEditor
  local logicalNodeWidth, logicalNodeHeight = node_dimensions(node, opts)
  local nodeWidth = logicalNodeWidth * zoom
  local headerHeight = (opts.headerHeight or defaults.headerHeight) * zoom
  local rowHeight = (opts.rowHeight or defaults.rowHeight) * zoom
  local bodyPadding = (opts.bodyPadding or defaults.bodyPadding) * zoom
  local inputs, outputs = node.inputs or {}, node.outputs or {}
  local rowCount = math.max(#inputs, #outputs, 1)
  local contentHeight = node_content_height(node) * zoom
  local contentGap = node_content_gap(node) * zoom
  local nodeHeight = logicalNodeHeight * zoom
  local nx, ny = node_position(st, node, nodeKey)
  local selected = is_selected(st, nodeKey)
  local selectedColor = opts.selectedBorderColor or theme.colors.nodeEditor.selectedBorderColor
  local borderColor = selected and selectedColor or (opts.borderColor or theme.colors.nodeEditor.borderColor)
  local z = selected and (10000 + index) or (100 + index)
  local id = node_id(graphKey, nodeKey)

  clay.element(id)
    :floating()
      :parent()
      :attach(clay.ATTACH_POINT_LEFT_TOP, clay.ATTACH_POINT_LEFT_TOP)
      :offset(st.panX + nx * zoom, st.panY + ny * zoom)
      :zIndex(z)
      :clipTo(clay.CLIP_TO_ATTACHED_PARENT)
      :done()
    :width(clay.SIZING_FIXED, nodeWidth)
    :height(clay.SIZING_FIXED, nodeHeight)
    :layoutDirection(clay.TOP_TO_BOTTOM)
    :backgroundColor((opts.nodeColor or theme.colors.nodeEditor.nodeColor).r, (opts.nodeColor or theme.colors.nodeEditor.nodeColor).g,
        (opts.nodeColor or theme.colors.nodeEditor.nodeColor).b, (opts.nodeColor or theme.colors.nodeEditor.nodeColor).a)
    :cornerRadius(defaults.cornerRadius * zoom)
    :borderColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
    :borderWidth(math.max(1, zoom))
    :children(function()
      clay.element(header_id(graphKey, nodeKey))
        :width(clay.SIZING_GROW)
        :height(clay.SIZING_FIXED, headerHeight)
        :padding(defaults.headerPadding * zoom, 0, defaults.headerPadding * zoom, 0)
        :backgroundColor((node.headerColor or opts.headerColor or theme.colors.nodeEditor.headerColor).r,
            (node.headerColor or opts.headerColor or theme.colors.nodeEditor.headerColor).g,
            (node.headerColor or opts.headerColor or theme.colors.nodeEditor.headerColor).b,
            (node.headerColor or opts.headerColor or theme.colors.nodeEditor.headerColor).a)
        :cornerRadius(defaults.cornerRadius * zoom, defaults.cornerRadius * zoom, 0, 0)
        :childAlignment(clay.ALIGN_X_LEFT, clay.ALIGN_Y_CENTER)
        :children(function()
          clay.text(node.title or node.label or key(nodeKey))
            :fontId(opts.fontId or defaults.fontId)
            :fontSize(math.max(10, math.floor((opts.fontSize or theme.type.small) * zoom + 1)))
            :textColor((opts.textColor or theme.colors.nodeEditor.textColor).r, (opts.textColor or theme.colors.nodeEditor.textColor).g,
                (opts.textColor or theme.colors.nodeEditor.textColor).b, (opts.textColor or theme.colors.nodeEditor.textColor).a)
            :done()
        end)

      clay.element(clay.id("NodeEditorBody:" .. graphKey .. ":" .. key(nodeKey)))
        :layoutDirection(clay.TOP_TO_BOTTOM)
        :width(clay.SIZING_GROW)
        :height(clay.SIZING_GROW)
        :clip(true, true)
        :padding(bodyPadding)
        :childGap(0)
        :children(function()
          if type(node.content) == "function" then
            clay.element(content_id(graphKey, nodeKey))
              :layoutDirection(clay.LEFT_TO_RIGHT)
              :width(clay.SIZING_GROW)
              :height(clay.SIZING_FIXED, contentHeight)
              :childAlignment(clay.ALIGN_X_CENTER, clay.ALIGN_Y_CENTER)
              :children(function()
                node.content(node, zoom, nodeWidth - 2 * bodyPadding)
              end)

            if contentGap > 0 then
              clay.element(clay.id("NodeEditorContentGap:" .. graphKey .. ":" .. key(nodeKey)))
                :width(clay.SIZING_GROW)
                :height(clay.SIZING_FIXED, contentGap)
                :close()
            end
          end

          for row = 1, rowCount do
            clay.element(clay.id("NodeEditorRow:" .. graphKey .. ":" .. key(nodeKey), row, true))
              :layoutDirection(clay.LEFT_TO_RIGHT)
              :width(clay.SIZING_GROW)
              :height(clay.SIZING_FIXED, rowHeight)
              :children(function()
                if inputs[row] then
                  port_slot(graphKey, nodeKey, inputs[row], row, "in", opts, zoom)
                else
                  clay.element(clay.id("NodeEditorInputSpacer:" .. graphKey .. ":" .. key(nodeKey), row, true))
                    :width(clay.SIZING_GROW):height(clay.SIZING_GROW):close()
                end
                if outputs[row] then
                  port_slot(graphKey, nodeKey, outputs[row], row, "out", opts, zoom)
                else
                  clay.element(clay.id("NodeEditorOutputSpacer:" .. graphKey .. ":" .. key(nodeKey), row, true))
                    :width(clay.SIZING_GROW):height(clay.SIZING_GROW):close()
                end
              end)
          end
        end)
    end)
end

local function compatible(a, b)
  if a.direction == b.direction then return false end
  if a.direction == "in" then a, b = b, a end
  local fromType, toType = a.pin.type, b.pin.type
  return fromType == nil or toType == nil or fromType == "any" or toType == "any" or fromType == toType
end

local function make_link(a, b)
  if a.direction == "in" then a, b = b, a end
  return {
    fromNode=a.nodeId, fromPin=a.pinId,
    toNode=b.nodeId, toPin=b.pinId,
  }
end

-- clay.node_editor(graphId, { nodes=..., links=..., onConnect=..., onDisconnect=..., onNodeMoved=... })
-- Nodes can be plain tables or created with clay.node(id, options):title():position():
-- input()/output():open():children(callback, height):close(). The child callback receives
-- (node, zoom, contentWidth), so it can declare any Clay content inside the node panel.
-- contentHeight reserves logical pixels for that custom Clay content. Clicks in node content
-- are left to its widgets instead of starting a node drag unless contentInteractive=false.
-- Pins contain id/label/type/[color].
-- Selection, links, node positions, and history are mutable by default. Callbacks let
-- an application own graph changes; onHistoryRestore receives snapshots for that case.
function node_editor(graphId, opts)
  opts = opts or {}
  local graphKey = key(graphId)
  local nodes = opts.nodes or {}
  local st = _node_editor_state[graphKey]
  if not st then
    st = {
      zoom=1, panX=18, panY=18, selectedNode=nil, selectedNodes={},
      selectedLink=nil, focused=false, undoStack={}, redoStack={},
      lastLeftDown=false, lastRightDown=false, lastMiddleDown=false, lastDeleteDown=false,
      lastUndoDown=false, lastRedoDown=false, lastFitDown=false,
      api={}, canvasId=clay.id("NodeEditorCanvas:" .. graphKey),
    }
    _node_editor_state[graphKey] = st
  end
  st.selectedNodes = st.selectedNodes or {}
  if st.selectedNode ~= nil and not st.selectedNodes[key(st.selectedNode)] then
    st.selectedNodes[key(st.selectedNode)] = st.selectedNode
  end
  if opts.links then st.links = opts.links end
  if not st.links then st.links = {} end
  local links = st.links
  st.nodes = nodes

  local componentDefaults = theme.defaults.nodeEditor
  local width = opts.width or componentDefaults.width
  local height = opts.height or componentDefaults.height
  local gridSize = opts.gridSize or componentDefaults.gridSize
  local mx, my = window.mousePosition()
  local leftDown = window.mouseButtonDown(window.MOUSE_BUTTON_LEFT)
  local rightDown = window.mouseButtonDown(window.MOUSE_BUTTON_RIGHT)
  local middleDown = window.mouseButtonDown(window.MOUSE_BUTTON_MIDDLE)
  local leftPressed = leftDown and not st.lastLeftDown
  local leftReleased = not leftDown and st.lastLeftDown
  local rightPressed = rightDown and not st.lastRightDown
  local middlePressed = middleDown and not st.lastMiddleDown
  local middleReleased = not middleDown and st.lastMiddleDown
  local deleteDown = window.keyDown(window.KEY_DELETE) or window.keyDown(window.KEY_BACKSPACE)
  local deletePressed = deleteDown and not st.lastDeleteDown
  local ctrlDown = window.keyDown(window.KEY_LEFT_CONTROL) or window.keyDown(window.KEY_RIGHT_CONTROL)
  local shiftDown = window.keyDown(window.KEY_LEFT_SHIFT) or window.keyDown(window.KEY_RIGHT_SHIFT)
  local undoDown = ctrlDown and window.keyDown(window.KEY_Z) and not shiftDown
  local redoDown = ctrlDown and (window.keyDown(window.KEY_Y) or
      (window.keyDown(window.KEY_Z) and shiftDown))
  local fitDown = window.keyDown(window.KEY_F)
  local undoPressed = undoDown and not st.lastUndoDown
  local redoPressed = redoDown and not st.lastRedoDown
  local fitPressed = fitDown and not st.lastFitDown
  local rootBox = clay.getElementData(st.canvasId)
  if st.boxSelect and (not rootBox or not rootBox.found) then st.boxSelect = nil end
  local inside = rootBox and rootBox.found and mx >= rootBox.x and my >= rootBox.y
      and mx < rootBox.x + rootBox.width and my < rootBox.y + rootBox.height
  local previousSelection = st.selectedNode
  local previousSelectedNodes = selection_list(st)

  -- Drop stale IDs when a graph is replaced or edited by its owner.
  for selectedKey, selectedId in pairs(st.selectedNodes) do
    if not get_node(nodes, selectedId) then st.selectedNodes[selectedKey] = nil end
  end
  update_primary_selection(st, st.selectedNode)

  local function build_wires()
    local result = {}
    for i = 1, #links do
      local wire = link_endpoints(graphKey, nodes, links[i], opts, st, st.zoom, i)
      if wire then result[#result + 1] = wire end
    end
    return result
  end

  local function fit_view()
    if #nodes == 0 then
      st.zoom, st.panX, st.panY = 1, 18, 18
      return
    end
    local minX, minY, maxX, maxY
    for i = 1, #nodes do
      local node = nodes[i]
      local x, y = tonumber(node.x) or componentDefaults.defaultPosition,
          tonumber(node.y) or componentDefaults.defaultPosition
      local w, h = node_dimensions(node, opts)
      minX, minY = minX and math.min(minX, x) or x, minY and math.min(minY, y) or y
      maxX, maxY = maxX and math.max(maxX, x + w) or (x + w),
          maxY and math.max(maxY, y + h) or (y + h)
    end
    local padding = tonumber(opts.fitPadding) or componentDefaults.fitPadding
    local boundsW, boundsH = math.max(1, maxX - minX), math.max(1, maxY - minY)
    local fitZoom = math.min((width - 2 * padding) / boundsW, (height - 2 * padding) / boundsH)
    st.zoom = clamp(fitZoom, opts.minZoom or DEFAULTS.minZoom, opts.maxZoom or DEFAULTS.maxZoom)
    st.panX = (width - boundsW * st.zoom) * 0.5 - minX * st.zoom
    st.panY = (height - boundsH * st.zoom) * 0.5 - minY * st.zoom
  end

  local function history_undo()
    local entry = st.undoStack and table.remove(st.undoStack)
    if not entry then return false end
    st.redoStack = st.redoStack or {}
    st.redoStack[#st.redoStack + 1] = entry
    restore_graph(entry.before, nodes, links, st)
    if opts.onHistoryRestore then opts.onHistoryRestore(history_restore_payload(entry.before), "undo") end
    st.api.canUndo, st.api.canRedo = #st.undoStack > 0, true
    return true
  end

  local function history_redo()
    local entry = st.redoStack and table.remove(st.redoStack)
    if not entry then return false end
    st.undoStack = st.undoStack or {}
    st.undoStack[#st.undoStack + 1] = entry
    restore_graph(entry.after, nodes, links, st)
    if opts.onHistoryRestore then opts.onHistoryRestore(history_restore_payload(entry.after), "redo") end
    st.api.canUndo, st.api.canRedo = true, #st.redoStack > 0
    return true
  end

  st.api.undo = history_undo
  st.api.redo = history_redo
  st.api.fitView = fit_view
  st.api.canUndo = st.undoStack and #st.undoStack > 0 or false
  st.api.canRedo = st.redoStack and #st.redoStack > 0 or false

  if st.focused and undoPressed then history_undo()
  elseif st.focused and redoPressed then history_redo()
  elseif st.focused and fitPressed then fit_view() end

  if inside and device and device.scroll and device.scroll.y ~= 0 and not leftDown then
    local localX, localY = mx - rootBox.x, my - rootBox.y
    local graphX, graphY = (localX - st.panX) / st.zoom, (localY - st.panY) / st.zoom
    local factor = device.scroll.y > 0 and (opts.zoomStep or DEFAULTS.zoomStep)
        or (1 / (opts.zoomStep or DEFAULTS.zoomStep))
    st.zoom = clamp(st.zoom * factor, opts.minZoom or DEFAULTS.minZoom, opts.maxZoom or DEFAULTS.maxZoom)
    st.panX = localX - graphX * st.zoom
    st.panY = localY - graphY * st.zoom
  end

  local function disconnect_link(index)
    local link = links[index]
    if not link then return false end
    if opts.onDisconnect then opts.onDisconnect(link, index)
    else table.remove(links, index) end
    if st.selectedLink == index then st.selectedLink = nil
    elseif st.selectedLink and st.selectedLink > index then st.selectedLink = st.selectedLink - 1 end
    return true
  end

  local function commit_history(before, after)
    push_history(st, before, after or snapshot_graph(nodes, links, st), opts.historyLimit)
  end

  local function remove_links(indices)
    table.sort(indices, function(a, b) return a > b end)
    for i = 1, #indices do disconnect_link(indices[i]) end
  end

  local wires = build_wires()
  local hoveredPin
  if leftPressed or leftReleased then hoveredPin = find_hovered_pin(graphKey, nodes, st.selectedNode) end

  if leftPressed and inside then
    st.focused = true
    if hoveredPin then
      select_only(st, hoveredPin.nodeId)
      st.connecting = hoveredPin
      st.selectedLink = nil
    else
      local hitNode, hitNodeKey
      for i = #nodes, 1, -1 do
        local candidateKey = nodes[i].id or i
        if clay.pointerOver(node_id(graphKey, candidateKey)) then
          hitNode, hitNodeKey = nodes[i], candidateKey
          break
        end
      end
      if hitNode then
        local contentIsInteractive = type(hitNode.content) == "function"
            and hitNode.contentInteractive ~= false
            and clay.pointerOver(content_id(graphKey, hitNodeKey))
        local wasSelected = is_selected(st, hitNodeKey)
        if ctrlDown then
          if wasSelected then
            st.selectedNodes[key(hitNodeKey)] = nil
            update_primary_selection(st)
          else
            st.selectedNodes[key(hitNodeKey)] = hitNodeKey
            st.selectedNode = hitNodeKey
          end
        elseif shiftDown then
          st.selectedNodes[key(hitNodeKey)] = hitNodeKey
          st.selectedNode = hitNodeKey
        elseif not wasSelected then
          select_only(st, hitNodeKey)
        end
        st.selectedLink = nil
        if is_selected(st, hitNodeKey) and not contentIsInteractive then
          local before = snapshot_graph(nodes, links, st)
          st.dragNode = {
            startX=mx, startY=my, before=before, items={},
          }
          st.dragPositions = {}
          for i = 1, #nodes do
            local node = nodes[i]
            local nodeKey = node.id or i
            if is_selected(st, nodeKey) then
              local nx, ny = node_position(st, node, nodeKey)
              st.dragNode.items[#st.dragNode.items + 1] = {
                id=nodeKey, node=node, index=i, originX=nx, originY=ny,
              }
              st.dragPositions[key(nodeKey)] = { x=nx, y=ny }
            end
          end
        end
      else
        local linkIndex = hit_wire(wires, mx - rootBox.x, my - rootBox.y, st.zoom,
            tonumber(opts.wireHitRadius) or math.max(7, 6 * st.zoom))
        if linkIndex then
          clear_selection(st)
          st.selectedLink = linkIndex
          st.boxSelect = nil
        else
          st.selectedLink = nil
          st.boxSelect = {
            x0=mx - rootBox.x, y0=my - rootBox.y,
            x1=mx - rootBox.x, y1=my - rootBox.y,
            additive=ctrlDown or shiftDown,
          }
        end
      end
    end
  end

  if leftPressed and not inside then st.focused = false end

  if st.boxSelect and leftDown and rootBox and rootBox.found then
    st.boxSelect.x1 = clamp(mx - rootBox.x, 0, rootBox.width)
    st.boxSelect.y1 = clamp(my - rootBox.y, 0, rootBox.height)
  end

  if rightPressed and inside then
    local linkIndex = hit_wire(wires, mx - rootBox.x, my - rootBox.y, st.zoom,
        tonumber(opts.wireHitRadius) or math.max(7, 6 * st.zoom))
    if linkIndex then
      st.focused = true
      local before = snapshot_graph(nodes, links, st)
      local removedLink = links[linkIndex]
      st.selectedLink = linkIndex
      clear_selection(st)
      disconnect_link(linkIndex)
      local after = snapshot_graph(nodes, links, st)
      if opts.onDisconnect then snapshot_remove_links(after, { removedLink }) end
      commit_history(before, after)
    end
  end

  if st.focused and deletePressed then
    if st.selectedLink and links[st.selectedLink] then
      local before = snapshot_graph(nodes, links, st)
      local removedLink = links[st.selectedLink]
      disconnect_link(st.selectedLink)
      local after = snapshot_graph(nodes, links, st)
      if opts.onDisconnect then snapshot_remove_links(after, { removedLink }) end
      commit_history(before, after)
    else
      local selectedKeys = {}
      for i = 1, #nodes do
        local nodeKey = nodes[i].id or i
        if is_selected(st, nodeKey) then selectedKeys[key(nodeKey)] = true end
      end
      if next(selectedKeys) then
        local before = snapshot_graph(nodes, links, st)
        local removeLinkIndices = {}
        for i = 1, #links do
          local link = links[i]
          if selectedKeys[key(link.fromNode)] or selectedKeys[key(link.toNode)] then
            removeLinkIndices[#removeLinkIndices + 1] = i
          end
        end
        remove_links(removeLinkIndices)
        for i = #nodes, 1, -1 do
          local node = nodes[i]
          local nodeKey = node.id or i
          if selectedKeys[key(nodeKey)] then
            if opts.onDeleteNode then opts.onDeleteNode(nodeKey, node, i)
            else table.remove(nodes, i) end
          end
        end
        clear_selection(st)
        st.selectedLink = nil
        local after = copy_snapshot(before)
        snapshot_remove_nodes(after, selectedKeys)
        commit_history(before, after)
      end
    end
  end

  if st.dragNode and (leftDown or leftReleased) then
    local dx, dy = (mx - st.dragNode.startX) / st.zoom, (my - st.dragNode.startY) / st.zoom
    for i = 1, #st.dragNode.items do
      local item = st.dragNode.items[i]
      st.dragPositions[key(item.id)] = { x=item.originX + dx, y=item.originY + dy }
    end
    if leftReleased then
      local drag = st.dragNode
      local moved, overrides = false, {}
      for i = 1, #drag.items do
        local item = drag.items[i]
        local position = st.dragPositions[key(item.id)]
        if position and (math.abs(position.x - item.originX) > 0.01 or math.abs(position.y - item.originY) > 0.01) then
          moved = true
          overrides[key(item.id)] = { x=position.x, y=position.y }
          if opts.onNodeMoved then opts.onNodeMoved(item.id, position.x, position.y, item.node)
          else item.node.x, item.node.y = position.x, position.y end
        end
      end
      st.dragNode, st.dragPositions = nil, nil
      if moved then commit_history(drag.before, snapshot_graph(nodes, links, st, overrides)) end
    end
  end

  if leftReleased and st.boxSelect then
    local box = st.boxSelect
    box.x1 = clamp(mx - rootBox.x, 0, rootBox.width)
    box.y1 = clamp(my - rootBox.y, 0, rootBox.height)
    local dx, dy = box.x1 - box.x0, box.y1 - box.y0
    if math.abs(dx) > 4 or math.abs(dy) > 4 then
      local x0, x1 = math.min(box.x0, box.x1), math.max(box.x0, box.x1)
      local y0, y1 = math.min(box.y0, box.y1), math.max(box.y0, box.y1)
      if not box.additive then clear_selection(st) end
      for i = 1, #nodes do
        local node = nodes[i]
        local nodeKey = node.id or i
        local nx, ny = node_position(st, node, nodeKey)
        local nodeWidth, nodeHeight = node_dimensions(node, opts)
        local left, top = st.panX + nx * st.zoom, st.panY + ny * st.zoom
        local right, bottom = left + nodeWidth * st.zoom, top + nodeHeight * st.zoom
        if left <= x1 and right >= x0 and top <= y1 and bottom >= y0 then
          st.selectedNodes[key(nodeKey)] = nodeKey
        end
      end
      update_primary_selection(st)
    elseif not box.additive then
      clear_selection(st)
    end
    st.boxSelect = nil
  end

  if leftReleased and st.connecting then
    local target = hoveredPin or find_hovered_pin(graphKey, nodes, st.selectedNode)
    if inside and target and compatible(st.connecting, target) then
      local link = make_link(st.connecting, target)
      local duplicate = false
      for i = 1, #links do
        local existing = links[i]
        if key(existing.fromNode) == key(link.fromNode) and key(existing.fromPin) == key(link.fromPin)
            and key(existing.toNode) == key(link.toNode) and key(existing.toPin) == key(link.toPin) then
          duplicate = true
          break
        end
      end
      if not duplicate and (not opts.canConnect or opts.canConnect(link) ~= false) then
        local toNode = get_node(nodes, link.toNode)
        local toPin, fromNode, fromPin
        if toNode then
          for i, pin in ipairs(toNode.inputs or {}) do
            if key(pin_key(pin, i)) == key(link.toPin) then toPin = pin; break end
          end
        end
        fromNode = get_node(nodes, link.fromNode)
        if fromNode then
          for i, pin in ipairs(fromNode.outputs or {}) do
            if key(pin_key(pin, i)) == key(link.fromPin) then fromPin = pin; break end
          end
        end

        local inputPolicy = opts.inputLinkPolicy or "replace"
        if toPin and (toPin.allowMultipleLinks == true or tonumber(toPin.maxLinks) and tonumber(toPin.maxLinks) > 1) then
          inputPolicy = "multiple"
        elseif toPin and toPin.allowMultipleLinks == false then inputPolicy = "replace" end
        local conflicts, inCount, outCount = {}, 0, 0
        for i = 1, #links do
          local existing = links[i]
          if key(existing.toNode) == key(link.toNode) and key(existing.toPin) == key(link.toPin) then
            inCount = inCount + 1
            conflicts[#conflicts + 1] = i
          end
          if key(existing.fromNode) == key(link.fromNode) and key(existing.fromPin) == key(link.fromPin) then
            outCount = outCount + 1
          end
        end
        local maxIn = tonumber(toPin and toPin.maxLinks)
        local maxOut = tonumber(fromPin and fromPin.maxLinks)
        local reject = (maxIn and maxIn <= 0) or (maxOut and outCount >= maxOut)
            or (inputPolicy == "reject" and inCount > 0)
        if not reject and inputPolicy == "replace" and inCount > 0 then
          local before = snapshot_graph(nodes, links, st)
          local accepted, conflictLinks = nil, {}
          for i = 1, #conflicts do conflictLinks[i] = links[conflicts[i]] end
          if opts.onConnect then
            accepted = opts.onConnect(link)
            if accepted ~= false then
              local oldIndices = {}
              for i = 1, #links do
                for j = 1, #conflictLinks do
                  if links[i] == conflictLinks[j] then oldIndices[#oldIndices + 1] = i; break end
                end
              end
              remove_links(oldIndices)
            end
          else
            remove_links(conflicts)
            links[#links + 1] = link
          end
          if accepted ~= false then
            local after = snapshot_graph(nodes, links, st)
            if opts.onConnect then
              snapshot_remove_links(after, conflictLinks)
              snapshot_add_link(after, link)
            end
            commit_history(before, after)
          end
        elseif not reject and maxIn and inCount >= maxIn then
          reject = true
        elseif not reject then
          local before = snapshot_graph(nodes, links, st)
          local accepted = opts.onConnect and opts.onConnect(link)
          if not opts.onConnect and accepted ~= false then links[#links + 1] = link end
          if accepted ~= false then
            local after = snapshot_graph(nodes, links, st)
            if opts.onConnect then snapshot_add_link(after, link) end
            commit_history(before, after)
          end
        end
      end
    end
    st.connecting = nil
  end

  if middlePressed and inside then
    st.panDrag = { x=mx, y=my, panX=st.panX, panY=st.panY }
  elseif middleDown and st.panDrag then
    st.panX = st.panDrag.panX + mx - st.panDrag.x
    st.panY = st.panDrag.panY + my - st.panDrag.y
  elseif middleReleased then
    st.panDrag = nil
  end

  st.lastLeftDown = leftDown
  st.lastRightDown = rightDown
  st.lastMiddleDown = middleDown
  st.lastDeleteDown = deleteDown
  st.lastUndoDown, st.lastRedoDown, st.lastFitDown = undoDown, redoDown, fitDown

  local selectedNow = selection_list(st)
  local selectionChanged = #selectedNow ~= #previousSelectedNodes
  if not selectionChanged then
    for i = 1, #selectedNow do
      if key(selectedNow[i]) ~= key(previousSelectedNodes[i]) then selectionChanged = true; break end
    end
  end
  if (selectionChanged or previousSelection ~= st.selectedNode) and opts.onSelectionChanged then
    opts.onSelectionChanged(st.selectedNode, previousSelection, selectedNow)
  end

  wires = build_wires()
  local pending
  if st.connecting and rootBox and rootBox.found then
    local start = st.connecting
    local node = get_node(nodes, start.nodeId)
    if node then
      local pinIndex = 1
      local pinList = start.direction == "out" and (node.outputs or {}) or (node.inputs or {})
      for i, pin in ipairs(pinList) do
        if key(pin_key(pin, i)) == key(start.pinId) then pinIndex = i; break end
      end
      local px, py = pin_center(node, start.nodeId, start.pin, pinIndex, start.direction, st.zoom,
          node.width or opts.nodeWidth or componentDefaults.nodeWidth,
          opts.headerHeight or componentDefaults.headerHeight,
          opts.rowHeight or componentDefaults.rowHeight,
          opts.bodyPadding or componentDefaults.bodyPadding, st)
      local targetX, targetY = mx - rootBox.x, my - rootBox.y
      local a, b = px, py
      if start.direction == "in" then a, b = targetX, targetY; targetX, targetY = px, py end
      pending = { x0=a, y0=b, x1=targetX, y1=targetY,
          color=color_for_pin(start.pin, opts), width=componentDefaults.linkWidth * st.zoom }
    end
  end

  local selectionRect
  if st.boxSelect then
    local box = st.boxSelect
    local x0, x1 = math.min(box.x0, box.x1), math.max(box.x0, box.x1)
    local y0, y1 = math.min(box.y0, box.y1), math.max(box.y0, box.y1)
    selectionRect = { x=x0, y=y0, w=x1-x0, h=y1-y0,
      color=opts.marqueeColor or { r=105, g=175, b=255, a=220 },
      width=opts.marqueeWidth or componentDefaults.marqueeWidth }
  end

  local gridColor = opts.gridColor or theme.colors.nodeEditor.gridColor
  local canvasColor = opts.canvasColor or theme.colors.nodeEditor.canvasColor
  clay.element(st.canvasId)
    :width(clay.SIZING_FIXED, width)
    :height(clay.SIZING_FIXED, height)
    :layoutDirection(clay.TOP_TO_BOTTOM)
    :backgroundColor(canvasColor.r, canvasColor.g, canvasColor.b, canvasColor.a)
    :borderColor((opts.borderColor or theme.colors.nodeEditor.borderColor).r, (opts.borderColor or theme.colors.nodeEditor.borderColor).g,
        (opts.borderColor or theme.colors.nodeEditor.borderColor).b, (opts.borderColor or theme.colors.nodeEditor.borderColor).a)
    :borderWidth(1)
    :clip(true, true)
    :children(function()
      clay.element(clay.id("NodeEditorWireLayer:" .. graphKey))
        :width(clay.SIZING_GROW)
        :height(clay.SIZING_GROW)
        :customData({ kind="clay_node_editor_canvas", wires=wires, pending=pending,
            selectionRect=selectionRect, zoom=st.zoom, panX=st.panX, panY=st.panY,
            gridSize=gridSize, gridColor=gridColor })
        :close()

      for i = 1, #nodes do draw_node(graphKey, nodes[i], i, opts, st) end
    end)

  st.api.selectedNode = st.selectedNode
  st.api.selectedNodes = selectedNow
  st.api.selectedLink = st.selectedLink and links[st.selectedLink] or nil
  st.api.zoom = st.zoom
  st.api.panX, st.api.panY = st.panX, st.panY
  st.api.connecting = st.connecting ~= nil
  st.api.canvasId = st.canvasId
  st.api.links = links
  st.api.nodes = nodes
  st.api.canUndo = st.undoStack and #st.undoStack > 0 or false
  st.api.canRedo = st.redoStack and #st.redoStack > 0 or false
  return st.api
end

return { node_editor = node_editor, node = node }
