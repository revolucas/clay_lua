local theme = require("theme")
local ComponentBuilder = require("component.builder")

local inspectorStates = {}
local apiMethods = {}
local apiMetatable = { __index = apiMethods }

local function C(color)
  return color.r, color.g, color.b, color.a
end

local function ensure_state(rootId)
  local state = inspectorStates[rootId]
  if not state then
    state = { rowIndex = 0, sectionIndex = 0 }
    state.api = setmetatable({ _state = state }, apiMetatable)
    inspectorStates[rootId] = state
  end
  return state
end

local function begin_row(api, label)
  local state = api._state
  state.rowIndex = state.rowIndex + 1
  local rowId = clay.id("InspectorRow", state.rowIndex, true)
  local labelId = clay.id("InspectorLabel", state.rowIndex, true)
  local valueId = clay.id("InspectorValue", state.rowIndex, true)

  clay.element(rowId)
    :layoutDirection(clay.LEFT_TO_RIGHT)
    :width(clay.SIZING_GROW)
    :height(clay.SIZING_FIXED, state.rowHeight)
    :childGap(state.gap)
    :childAlignment(clay.ALIGN_X_LEFT, clay.ALIGN_Y_CENTER)
    :open()

  clay.element(labelId)
    :layoutDirection(clay.LEFT_TO_RIGHT)
    :width(clay.SIZING_FIXED, state.labelWidth)
    :height(clay.SIZING_FIXED, state.rowHeight)
    :childAlignment(clay.ALIGN_X_LEFT, clay.ALIGN_Y_CENTER)
    :open()
    clay.text(tostring(label))
      :fontId(state.fontId)
      :fontSize(state.fontSize)
      :textColor(C(theme.colors.textMuted))
      :wrapMode(clay.TEXT_WRAP_NONE)
      :done()
  clay.close()

  clay.element(valueId)
    :layoutDirection(clay.LEFT_TO_RIGHT)
    :width(clay.SIZING_GROW)
    :height(clay.SIZING_FIXED, state.rowHeight)
    :childAlignment(clay.ALIGN_X_LEFT, clay.ALIGN_Y_CENTER)
    :open()
end

local function end_row()
  clay.close() -- value cell
  clay.close() -- row
end

function apiMethods:section(title)
  local state = self._state
  state.sectionIndex = state.sectionIndex + 1
  local sectionId = clay.id("InspectorSection", state.sectionIndex, true)
  clay.element(sectionId)
    :layoutDirection(clay.LEFT_TO_RIGHT)
    :width(clay.SIZING_GROW)
    :height(clay.SIZING_FIXED, state.sectionHeight)
    :padding(2, 0, 2, 4)
    :borderColor(C(theme.colors.borderSubtle))
    :borderWidth(0, 0, 0, 1)
    :childAlignment(clay.ALIGN_X_LEFT, clay.ALIGN_Y_CENTER)
    :open()
    clay.text(tostring(title))
      :fontId(state.fontId)
      :fontSize(state.headingSize)
      :textColor(C(theme.colors.textStrong))
      :wrapMode(clay.TEXT_WRAP_NONE)
      :done()
  clay.close()
  return self
end

function apiMethods:row(label, draw)
  begin_row(self, label)
  if draw then draw(self) end
  end_row()
  return self
end

function apiMethods:value(label, value, suffix)
  begin_row(self, label)
  clay.text(value == nil and "—" or tostring(value))
    :fontId(self._state.fontId)
    :fontSize(self._state.fontSize)
    :textColor(C(theme.colors.text))
    :wrapMode(clay.TEXT_WRAP_NONE)
    :done()
  if suffix and suffix ~= "" then
    clay.text(tostring(suffix))
      :fontId(self._state.fontId)
      :fontSize(self._state.fontSize)
      :textColor(C(theme.colors.textMuted))
      :wrapMode(clay.TEXT_WRAP_NONE)
      :done()
  end
  end_row()
  return self
end

function apiMethods:note(text)
  local state = self._state
  state.noteIndex = state.noteIndex + 1
  clay.element(clay.id("InspectorNote", state.noteIndex, true))
    :layoutDirection(clay.LEFT_TO_RIGHT)
    :width(clay.SIZING_GROW)
    :height(clay.SIZING_FIT)
    :padding(4, 6)
    :backgroundColor(C(theme.colors.surfaceRaised))
    :open()
    clay.text(tostring(text))
      :fontId(state.fontId)
      :fontSize(state.smallSize)
      :textColor(C(theme.colors.textMuted))
      :wrapMode(clay.TEXT_WRAP_WORDS)
      :done()
  clay.close()
  return self
end

local function render_inspector(elid, build, opts)
  assert(type(build) == "function", "inspector: build callback is required")
  local state = ensure_state(elid.id)
  local defaults = theme.defaults.inspector
  state.rowIndex = 0
  state.sectionIndex = 0
  state.noteIndex = 0
  state.rowHeight = opts.rowHeight or defaults.rowHeight
  state.sectionHeight = opts.sectionHeight or defaults.sectionHeight
  state.labelWidth = opts.labelWidth or defaults.labelWidth
  state.gap = opts.gap or theme.spacing.controlGap
  state.fontId = opts.fontId or defaults.fontId
  state.fontSize = opts.fontSize or theme.type.body
  state.headingSize = opts.headingSize or theme.type.body
  state.smallSize = opts.smallSize or theme.type.small

  local root = clay.element(elid)
    :layoutDirection(clay.TOP_TO_BOTTOM)
    :height(clay.SIZING_FIT)
    :padding(opts.pad or defaults.padding)
    :childGap(opts.sectionGap or defaults.sectionGap)
    :backgroundColor(C(theme.colors.surface))
    :borderColor(C(theme.colors.border))
    :borderWidth(1)
  if opts.width then root:width(clay.SIZING_FIXED, opts.width)
  else root:width(clay.SIZING_GROW) end
  root:open()
  build(state.api)
  clay.close()
end

ComponentBuilder.register("inspector", function(builder)
  return render_inspector(rawget(builder, "_id"), rawget(builder, "_arg1"), builder)
end)

function inspector(id, build)
  return ComponentBuilder.new("inspector", id, build)
end
