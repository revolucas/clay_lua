-- Shared fluent builders for immediate-mode components.
-- One builder table carries both call data and options; the shared __index
-- switches between fluent methods and option reads while :draw() runs.

local M = {}
local methods = {}
local renderers = {}

local optionMethods = {
  "allowMultipleLinks", "allowNone", "alphaSteps", "arrowFontId", "arrowSize",
  "barWidth", "bodyPadding", "borderColor", "buttonW", "canConnect", "canvasColor",
  "cellRenderer", "colorThumb", "colorTrack", "colors", "columns", "columnWidths",
  "contentHeight", "contentInteractive", "copyHeaders", "cornerRadius", "dataVersion",
  "disabled", "doubleClickTime", "emptyText", "expanded", "filter", "filterColumns",
  "filterFn", "fitPadding", "focusOnCreate", "fontId", "fontSize", "format",
  "gap", "getCategory", "getChildren", "getColor", "getDescription", "getIcon",
  "getKey", "getLabel", "getRowKey", "getThumbnail", "gridColor", "gridSize",
  "grip", "gripColor", "gripGlyph", "glyphColor", "glyphFontId", "glyphScale", "hueSteps",
  "headerColor", "headerHeight", "headingSize", "height", "historyLimit", "horizontal",
  "indent", "inputLinkPolicy", "inset", "items", "keyboardNavigation", "labelWidth",
  "links", "marqueeColor", "marqueeWidth", "max", "maxChars", "maxH", "maxRows", "maxW",
  "maxZoom", "matrixSteps", "min", "minColumnWidth", "minH", "minThumb", "minW",
  "minZoom", "multiSelect", "nodeColor", "nodeWidth", "nodes", "onActivate",
  "onCellCommit", "onColumnResize", "onConnect", "onContextMenu", "onDeleteNode",
  "onDisconnect", "onDoubleClick", "onHistoryRestore", "onNodeMoved", "onRowClick",
  "onSelect", "onSelectionChanged", "onSortChanged", "overscan", "pad", "pageStep",
  "pinColor", "pinColors", "pinGap", "placeholder", "range", "resizableColumns", "rowFilter",
  "rowHeight", "searchHeight", "searchable", "sectionGap", "sectionHeight", "selectedKey",
  "scrollX", "scrollY", "selectedBorderColor", "selectedLinkColor", "selectedLinkWidth",
  "selectionMode", "showAlpha", "showGrip",
  "size", "smallSize", "snapH", "snapW", "sort", "sortBy", "sortColumn",
  "sortDirection", "sortOrder", "sortable", "step", "textColor", "thumbCornerRadius",
  "thumbThickness", "tileHeight", "tileWidth", "trackThickness", "trackW",
  "transitionDuration", "viewportHeight", "viewport_id", "wheelStep", "wheelX", "width",
  "wireHitRadius", "zebra", "zIndex", "zoomStep",
}

for i = 1, #optionMethods do
  local name = optionMethods[i]
  local field = "_" .. name
  methods[name] = function(self, value)
    rawset(self, field, value)
    return self
  end
end

function methods:range(minimum, maximum)
  rawset(self, "_min", minimum)
  rawset(self, "_max", maximum)
  return self
end

function methods:size(width, height)
  if height ~= nil then
    rawset(self, "_width", width)
    rawset(self, "_height", height)
  else
    rawset(self, "_size", width)
  end
  return self
end

function methods:padding(value)
  rawset(self, "_pad", value)
  return self
end

function methods:buttonWidth(value)
  rawset(self, "_buttonW", value)
  return self
end

function methods:transition(duration)
  rawset(self, "_transitionDuration", duration)
  return self
end

function methods:viewport(id)
  rawset(self, "_viewport_id", id)
  return self
end

function methods:tileSize(width, height)
  rawset(self, "_tileWidth", width)
  rawset(self, "_tileHeight", height)
  return self
end

function methods:rangeWidth(minimum, maximum)
  rawset(self, "_minW", minimum)
  rawset(self, "_maxW", maximum)
  return self
end

function methods:rangeHeight(minimum, maximum)
  rawset(self, "_minH", minimum)
  rawset(self, "_maxH", maximum)
  return self
end

function methods:draw()
  local renderer = renderers[rawget(self, "_component")]
  assert(renderer, "component builder has no registered renderer")

  rawset(self, "_drawing", true)
  local ok, first, second, third, fourth, fifth = pcall(renderer, self)
  rawset(self, "_drawing", nil)
  if not ok then error(first, 0) end
  return first, second, third, fourth, fifth
end

local metatable = {
  __index = function(self, name)
    if rawget(self, "_drawing") then
      return rawget(self, "_" .. name)
    end
    return methods[name]
  end,
}

function M.new(component, id, arg1, arg2, arg3, arg4)
  return setmetatable({
    _component = component,
    _id = id,
    _arg1 = arg1,
    _arg2 = arg2,
    _arg3 = arg3,
    _arg4 = arg4,
  }, metatable)
end

function M.register(component, renderer)
  assert(type(component) == "string" and type(renderer) == "function")
  renderers[component] = renderer
end

return M
