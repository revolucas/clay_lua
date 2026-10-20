-- Reusable theme tokens for Clay UI. Palettes and aliases are allocated once;
-- token reads resolve against the active palette and nested element scopes.
local function rgba(r, g, b, a)
  return {
    r = math.max(0, math.min(255, r)),
    g = math.max(0, math.min(255, g)),
    b = math.max(0, math.min(255, b)),
    a = a or 255,
  }
end

local function palette(colors, componentColors, spacing, radius, typeScale, defaults)
  for key, value in pairs(componentColors) do colors[key] = value end
  return {
    colors = colors,
    spacing = spacing,
    radius = radius,
    type = typeScale,
    defaults = defaults,
    motion = { fast = 0.12, standard = 0.18, slow = 0.28 },
  }
end

local function sharedComponentColors(accent, surface, text, muted, border, selected, selectedText)
  local clear = rgba(0, 0, 0, 0)
  selectedText = selectedText or rgba(255, 255, 255, 255)
  local softBorder = rgba(border.r, border.g, border.b, 44)
  local hover = rgba(surface.r + 13, surface.g + 14, surface.b + 18, 255)
  local selectedBg = rgba(selected.r, selected.g, selected.b, selected.a or 255)
  return {
    checkbox = {
      box_base = surface, box_hov = hover, box_act = selectedBg,
      box_dis = rgba(surface.r, surface.g, surface.b, 120), border = softBorder,
      fill = accent, label = text, fillBorder = softBorder,
    },
    radio = {
      ringBase = surface, ringHov = hover, ringAct = selectedBg,
      ringDis = rgba(surface.r, surface.g, surface.b, 120), border = softBorder,
      dot = accent, label = text, dotBorder = softBorder,
    },
    dropdown = {
      button = surface, buttonHover = hover, popup = surface, row = surface,
      rowHover = hover, rowSelected = selectedBg, border = softBorder, text = text,
    },
    slider = {
      bg = clear, bgHov = clear, bgAct = clear, bgborder = clear,
      border = softBorder, track = rgba(muted.r, muted.g, muted.b, 170),
      thumb = accent, fill = rgba(accent.r, accent.g, accent.b, 190),
      disable = rgba(muted.r, muted.g, muted.b, 100),
    },
    property = {
      bg = surface, bgHov = hover, bgAct = selectedBg, text = text,
      btn = hover, btnHov = selectedBg, btnAct = accent,
    },
    edit = {
      bg = surface, bgHov = hover, bgAct = selectedBg, border = softBorder,
      text = text, caret = accent,
      selBg = rgba(accent.r, accent.g, accent.b, 100), selTxt = selectedText,
    },
    listview = {
      bg = clear, bgAlt = rgba(text.r, text.g, text.b, 10),
      hover = rgba(accent.r, accent.g, accent.b, 42), text = text,
      selBg = rgba(accent.r, accent.g, accent.b, 82), selText = selectedText,
    },
    assetBrowser = {
      background = surface, viewport = clear,
      tile = rgba(surface.r + 8, surface.g + 8, surface.b + 10, 255),
      hover = hover, selected = selectedBg, text = text, icon = text, muted = muted,
      border = softBorder,
    },
    tableview = {
      bg = clear, header = surface, headerText = text, headerHover = hover,
      headerSort = accent, resize = softBorder,
      resizeHover = accent, rowAlt = rgba(text.r, text.g, text.b, 8),
      rowHover = rgba(accent.r, accent.g, accent.b, 35),
      rowSelBg = rgba(accent.r, accent.g, accent.b, 105), rowText = text,
      rowSelTxt = selectedText, grid = rgba(border.r, border.g, border.b, 55),
      emptyText = muted,
    },
    colorPicker = { bg = surface, border = softBorder },
    scrollbar = {
      colorTrackBase = rgba(muted.r, muted.g, muted.b, 40),
      colorTrackHot = rgba(muted.r, muted.g, muted.b, 65),
      thumbBase = rgba(muted.r, muted.g, muted.b, 165),
      thumbDrag = rgba(accent.r, accent.g, accent.b, 220),
      thumbBorder = softBorder,
    },
    resizable = {
      gripColor = rgba(text.r, text.g, text.b, 48),
      glyphColor = rgba(text.r, text.g, text.b, 90),
    },
    nodeEditor = {
      gridColor = rgba(muted.r, muted.g, muted.b, 52),
      canvasColor = surface, nodeColor = hover,
      headerColor = selectedBg, borderColor = border,
      selectedBorderColor = accent, selectedLinkColor = accent,
      textColor = text, pinColor = muted,
    },
  }
end

-- Shared visual defaults for built-in widgets. Component options still take
-- precedence, and aliases can override individual values with theme.defaults.*.
local componentDefaults = {
  checkbox = { size = 18, fontId = 1 },
  radio = { size = 20, fontId = 1 },
  edit = { width = 200, height = 24, padding = 8, fontId = 1 },
  slider = { width = 200, height = 24, padding = 0 },
  property = {
    width = 220, height = 28, padding = 6, buttonWidth = 28,
    fontId = 0, arrowFontId = 0, arrowSize = 20,
  },
  dropdown = { width = 260, fontId = 1, paddingX = 10, maxRows = 8 },
  listview = { rowHeight = 22, indent = 16, fontId = 0, paddingX = 8 },
  inspector = {
    labelWidth = 100, rowHeight = 30, sectionHeight = 28,
    padding = 10, sectionGap = 6, fontId = 1,
  },
  assetBrowser = {
    width = 420, height = 340, columns = 3, tileWidth = 112,
    tileHeight = 104, gap = 8, padding = 8, searchHeight = 32, fontId = 1,
  },
  tableview = {
    fontId = 1, minColumnWidth = 36, resizeHandleWidth = 6,
    headerPadL = 6, headerPadR = 4, cellPadL = 6, cellPadR = 4,
  },
  colorPicker = { width = 260, height = 180, padding = 6, barWidth = 18 },
  resizable = { grip = 16, inset = 2, glyphScale = 0.9, glyphFontId = 0 },
  scrollbar = { trackWidth = 10, minThumb = 24, margin = 4 },
  nodeEditor = {
    width = 640, height = 420, nodeWidth = 188, headerHeight = 30,
    rowHeight = 23, bodyPadding = 7, fontId = 1, gridSize = 32,
    cornerRadius = 6, headerPadding = 8, contentHeight = 36, contentGap = 4,
    fitPadding = 32, defaultPosition = 32, linkWidth = 2.2,
    selectedLinkWidth = 3.5, marqueeWidth = 1.5, pinGap = 5,
  },
}

local function makeTheme(root, header, content, sidebar, text, muted, accent, selected, border, selectedText)
  local colors = {
    transparent = rgba(0, 0, 0, 0),
    root = root, header = header, content = content, sidebar = sidebar,
    sidebarHover = rgba(sidebar.r + 18, sidebar.g + 18, sidebar.b + 22, 255),
    sidebarActive = selected,
    text = text, textStrong = text, textMuted = muted,
    borderSubtle = rgba(border.r, border.g, border.b, 34),
    border = rgba(border.r, border.g, border.b, 64),
    borderStrong = rgba(border.r, border.g, border.b, 100),
    surface = rgba(content.r + 8, content.g + 8, content.b + 10, 255),
    surfaceRaised = rgba(content.r + 14, content.g + 14, content.b + 18, 255),
    surfaceHover = rgba(content.r + 24, content.g + 24, content.b + 28, 255),
    surfaceSelected = selected,
    input = rgba(content.r + 3, content.g + 3, content.b + 5, 255),
    inputBorder = border,
    accent = accent,
    accentHover = rgba(math.min(255, accent.r + 20), math.min(255, accent.g + 20), math.min(255, accent.b + 20), 255),
    accentPressed = selected,
    selection = rgba(accent.r, accent.g, accent.b, 100),
    selectionText = selectedText or rgba(255, 255, 255, 255),
    grid = rgba(border.r, border.g, border.b, 44),
  }
  local components = sharedComponentColors(accent, colors.surface, text, muted, border, selected, selectedText)
  return palette(colors, components,
    { navItemHeight = 44, navItemPadding = 12, panelPadding = 16, layoutGap = 12, controlGap = 8, controlHeight = 34 },
    { control = 6, panel = 8, card = 10 },
    { small = 13, body = 16, heading = 22, title = 20 },
    componentDefaults)
end

local palettes = {
  indigo = makeTheme(
    rgba(50, 80, 120), rgba(35, 56, 90), rgba(30, 46, 75), rgba(60, 78, 110),
    rgba(244, 246, 252), rgba(190, 199, 216), rgba(105, 174, 255),
    rgba(40, 60, 95), rgba(210, 220, 238)),
  graphite = makeTheme(
    rgba(34, 37, 43), rgba(45, 49, 57), rgba(28, 31, 37), rgba(39, 43, 50),
    rgba(238, 240, 244), rgba(166, 173, 185), rgba(101, 176, 255),
    rgba(54, 77, 104), rgba(171, 180, 194)),
  paper = makeTheme(
    rgba(235, 239, 245), rgba(222, 229, 239), rgba(247, 249, 252), rgba(228, 234, 242),
    rgba(31, 39, 52), rgba(89, 101, 119), rgba(31, 111, 205),
    rgba(195, 218, 244), rgba(96, 111, 132), rgba(31, 39, 52)),
}

local themeNames = { indigo = "Indigo Night", graphite = "Graphite", paper = "Paper" }

local function invalidateRetainedRoots()
  local clay = rawget(_G, "clay")
  if clay and clay.invalidateAll then clay.invalidateAll() end
end
local options = {
  { label = "Indigo Night", value = "indigo" },
  { label = "Graphite", value = "graphite" },
  { label = "Paper", value = "paper" },
}

local aliases = {
  compact = {
    spacing = { navItemHeight = 36, navItemPadding = 8, panelPadding = 12, layoutGap = 8, controlGap = 6, controlHeight = 30 },
    type = { small = 12, body = 14, heading = 20, title = 18 },
    defaults = {
      checkbox = { size = 16 }, radio = { size = 18 },
      edit = { height = 30, padding = 6 }, slider = { height = 30 },
      property = { height = 30, buttonWidth = 24, padding = 5 },
      dropdown = { width = 240, paddingX = 8 },
      listview = { rowHeight = 20, paddingX = 6 },
      tableview = { minColumnWidth = 32, resizeHandleWidth = 5, headerPadL = 5, headerPadR = 3, cellPadL = 5, cellPadR = 3 },
      colorPicker = { width = 240, height = 160, padding = 5, barWidth = 16 },
      resizable = { grip = 14 }, scrollbar = { trackWidth = 8, minThumb = 20 },
      nodeEditor = {
        width = 600, height = 390, nodeWidth = 176, headerHeight = 28,
        rowHeight = 21, bodyPadding = 6, gridSize = 28,
        cornerRadius = 5, headerPadding = 7, contentHeight = 32, contentGap = 3,
        fitPadding = 28, defaultPosition = 28, linkWidth = 2, selectedLinkWidth = 3,
        marqueeWidth = 1.25, pinGap = 4,
      },
    },
  },
  relaxed = {
    spacing = { navItemHeight = 50, navItemPadding = 14, panelPadding = 20, layoutGap = 16, controlGap = 10, controlHeight = 38 },
    type = { small = 14, body = 18, heading = 24, title = 22 },
    defaults = {
      checkbox = { size = 20 }, radio = { size = 22 },
      edit = { height = 38, padding = 10 }, slider = { height = 38 },
      property = { height = 38, buttonWidth = 32, padding = 8 },
      dropdown = { width = 280, paddingX = 12 },
      listview = { rowHeight = 26, paddingX = 10 },
      tableview = { minColumnWidth = 42, resizeHandleWidth = 8, headerPadL = 8, headerPadR = 6, cellPadL = 8, cellPadR = 6 },
      colorPicker = { width = 290, height = 205, padding = 8, barWidth = 20 },
      resizable = { grip = 20 }, scrollbar = { trackWidth = 12, minThumb = 28 },
      nodeEditor = {
        width = 700, height = 460, nodeWidth = 204, headerHeight = 34,
        rowHeight = 26, bodyPadding = 9, gridSize = 36,
        cornerRadius = 8, headerPadding = 10, contentHeight = 42, contentGap = 5,
        fitPadding = 38, defaultPosition = 38, linkWidth = 2.5, selectedLinkWidth = 4,
        marqueeWidth = 1.75, pinGap = 6,
      },
    },
  },
  accent = { colors = { accent = rgba(226, 151, 67), accentHover = rgba(245, 177, 88) } },
}

local currentName = "indigo"
local current = palettes[currentName]
local stack, depth = {}, 0

local function lookup_path(value, path, key)
  for j = 1, #path do
    if type(value) ~= "table" then return nil end
    value = value[path[j]]
  end
  if key ~= nil then
    if type(value) ~= "table" then return nil end
    value = value[key]
  end
  return value
end

local function resolve(domain, path, key)
  for i = depth, 1, -1 do
    local value = lookup_path(stack[i].style[domain], path, key)
    if value ~= nil then return value end
  end
  local value = lookup_path(current[domain], path, key)
  if value == nil and domain == "defaults" then value = lookup_path(componentDefaults, path, key) end
  return value
end

local function isColor(value)
  return type(value) == "table" and value.r ~= nil and value.g ~= nil
      and value.b ~= nil and value.a ~= nil
end

local function tokenProxy(domain, path)
  path = path or {}
  local children = {}
  return setmetatable({}, {
    __index = function(_, key)
      local value = resolve(domain, path, key)
      if type(value) == "table" and not isColor(value) then
        local child = children[key]
        if not child then
          local nestedPath = {}
          for i = 1, #path do nestedPath[i] = path[i] end
          nestedPath[#nestedPath + 1] = key
          child = tokenProxy(domain, nestedPath)
          children[key] = child
        end
        return child
      end
      return value
    end,
    __newindex = function() error("theme tokens are read-only", 2) end,
    __metatable = "theme token proxy",
  })
end

local theme = {
  colors = tokenProxy("colors"),
  spacing = tokenProxy("spacing"),
  radius = tokenProxy("radius"),
  type = tokenProxy("type"),
  motion = tokenProxy("motion"),
  defaults = tokenProxy("defaults"),
  options = options,
  aliases = aliases,
  currentName = currentName,
}

function theme.set(name)
  assert(type(name) == "string" and palettes[name], "unknown theme: " .. tostring(name))
  currentName, current = name, palettes[name]
  theme.currentName = name
  theme.syncGlobals()
  invalidateRetainedRoots()
  return currentName
end

function theme.get()
  return currentName, current
end

function theme.label(name)
  return themeNames[name or currentName]
end

function theme.define(alias, overlay)
  assert(type(alias) == "string" and alias ~= "", "theme.define: alias name required")
  assert(type(overlay) == "table", "theme.define: overlay table required")
  aliases[alias] = overlay
  invalidateRetainedRoots()
  return overlay
end

function theme.defineTheme(name, definition, label)
  assert(type(name) == "string" and name ~= "", "theme.defineTheme: theme name required")
  assert(type(definition) == "table", "theme.defineTheme: palette table required")
  for _, domain in ipairs({ "colors", "spacing", "radius", "type", "motion" }) do
    assert(type(definition[domain]) == "table", "theme.defineTheme: palette needs a " .. domain .. " table")
  end
  if definition.defaults ~= nil then
    assert(type(definition.defaults) == "table", "theme.defineTheme: defaults must be a table")
  end

  palettes[name] = definition
  local displayName = label or name
  themeNames[name] = displayName
  if currentName == name then
    current = definition
    theme.syncGlobals()
    invalidateRetainedRoots()
  end
  for i = 1, #options do
    if options[i].value == name then
      options[i].label = displayName
      return definition
    end
  end
  options[#options + 1] = { label = displayName, value = name }
  return definition
end

-- Called by the native builder when an element's :style(alias) scope begins.
function theme._push(alias, elementId)
  local style = assert(aliases[alias], "unknown theme style alias: " .. tostring(alias))
  depth = depth + 1
  local frame = stack[depth]
  if not frame then frame = {}; stack[depth] = frame end
  frame.style, frame.elementId = style, elementId
end

-- Called by Clay close operations. A chain of aliases may belong to one node.
function theme._popElement(elementId)
  while depth > 0 and stack[depth].elementId == elementId do
    local frame = stack[depth]
    frame.style, frame.elementId = nil, nil
    depth = depth - 1
  end
end

function theme.resetScopes()
  for i = depth, 1, -1 do
    stack[i].style, stack[i].elementId = nil, nil
  end
  depth = 0
end

function theme.syncGlobals()
  local c = current.colors
  _G.COLOR_NONE = c.transparent
  _G.COLOR_WHITE = c.text
  _G.COLOR_WHITE_24 = c.borderSubtle
  _G.COLOR_WHITE_32 = c.border
  _G.COLOR_WHITE_45 = c.borderStrong
  _G.COLOR_HEADER_BG = c.header
  _G.COLOR_ROOT_BG = c.root
  _G.COLOR_CONTENT_BG = c.content
  _G.COLOR_SIDEBAR_BG_BASE = c.sidebar
  _G.COLOR_SIDEBAR_BG_HOV = c.sidebarHover
  _G.COLOR_SIDEBAR_BG_ACT = c.sidebarActive
end

return theme
