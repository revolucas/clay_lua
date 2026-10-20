package.cpath = "./bin/linux64/?.so;" .. package.cpath

local clay = require("clay")
_G.clay = clay
local bit = require("bit")

local width, height = 320, 240
assert(clay.initialize(clay.minMemorySize(), width, height))
local runtime = require("clay_retained").install(clay, width, height)
local releasedPacketCount = 0
clay._releaseRetainedPackets = function(packets)
  releasedPacketCount = releasedPacketCount + #(packets or {})
end

local function box(alias, w, h, color)
  local builder = clay.element()
  if alias then builder:alias(alias) end
  color = color or 0x446688ff
  builder:width(clay.SIZING_FIXED, w)
    :height(clay.SIZING_FIXED, h)
    :backgroundColor(
      bit.band(bit.rshift(color, 24), 0xff),
      bit.band(bit.rshift(color, 16), 0xff),
      bit.band(bit.rshift(color, 8), 0xff),
      bit.band(color, 0xff))
    :close()
end

local function tuple(...) return { ... } end

local immediateFrames = 0
local immediateHover = false
local function buildImmediate()
  immediateFrames = immediateFrames + 1
  immediateHover = clay.pointerOver(clay.id("immediateButton"))
  clay.element("immediateRoot")
    :width(clay.SIZING_FIXED, width)
    :height(clay.SIZING_FIXED, height)
    :open()
  clay.element("immediateButton")
    :width(clay.SIZING_FIXED, 180)
    :height(clay.SIZING_FIXED, 60)
    :backgroundColor(32, 32, 32, 255)
    :close()
  clay.close()
end

local function frame(dt, pointerX, pointerY, pointerDown, scrollX, scrollY, nextWidth, nextHeight)
  width, height = nextWidth or width, nextHeight or height
  clay.setLayoutDimensions(width, height)
  clay.setPointerState(pointerX or 300, pointerY or 220, pointerDown or false)
  clay.updateScrollContainers(true, scrollX or 0, scrollY or 0, dt or 1 / 60)
  clay.beginLayout(dt or 1 / 60)
  buildImmediate()
  local iterator = clay.endLayoutFast(dt or 1 / 60)
  local packets = 0
  while true do
    local values = tuple(iterator())
    local command, packet = values[1], values[26]
    if command == nil then break end
    if packet ~= nil then
      packets = packets + 1
      assert(packet[26] == packet, "retained packet cache key must own its command tuple")
    end
  end
  return packets
end

local count = clay.state(70)
local panelBuilds = 0
local panelClicks = 0
local panel = clay.retained({ alias = "panel", layer = 100 }, function()
  panelBuilds = panelBuilds + 1
  clay.element():alias("panel")
    :width(clay.SIZING_FIXED, 160)
    :height(clay.SIZING_FIXED, 100)
    :backgroundColor(48, 64, 80, 255)
    :open()
  clay.text("stableretainedcommand"):done()
  box("value", count:get(), 20, 0x6090b0ff)
  box("button", 100, 40, 0x90b060ff)
  clay.close()
end)
panel:on("button", "click", function()
  panelClicks = panelClicks + 1
  count:set(count:get() + 1)
end)

local firstPackets = frame(1 / 60)
assert(panelBuilds == 1 and panel:stats().layouts == 1, "a retained root should build and lay out once")
assert(firstPackets > 0, "retained commands should compose with the immediate layout")
local stablePacket = panel.packets[1]
local stableCommand = stablePacket[1]
local stableText, stableTextPacket
for i = 1, #panel.packets do
  if panel.packets[i][1] == clay.RENDER_TEXT then
    stableText, stableTextPacket = panel.packets[i][18], panel.packets[i]
  end
end
assert(stableText == "stableretainedcommand", "retained packets should own their command text")
frame(1 / 60)
assert(panelBuilds == 1 and panel:stats().layouts == 1, "a clean root should not rebuild")
assert(panel.packets[1] == stablePacket and stablePacket[1] == stableCommand,
  "cached commands must survive reuse of the Clay frame arena")
assert(stableTextPacket[18] == stableText,
  "the retained command snapshot should stay valid after the immediate layout reuses its arena")
assert(immediateFrames == 2 and panel:stats().replays > 0, "immediate UI rebuilds while retained packets replay")

count:set(71)
count:set(72)
frame(1 / 60)
assert(panelBuilds == 2, "multiple state writes should coalesce into one retained rebuild")
count:set(72)
frame(1 / 60)
assert(panelBuilds == 2, "writing an equal scalar should not dirty dependents")

local mutable = clay.state({ value = 1 })
local shallowBuilds = 0
local shallow = clay.retained(function()
  shallowBuilds = shallowBuilds + 1
  box("shallow", mutable:get().value, 12)
end)
frame(1 / 60)
mutable:get().value = 2
frame(1 / 60)
assert(shallowBuilds == 1, "table fields are not observed without an explicit touch")
mutable:touch()
frame(1 / 60)
assert(shallowBuilds == 2, "state:touch() should invalidate roots that read a table")

local higherClicks = 0
local higher = clay.retained({ alias = "higher", layer = 100 }, function()
  clay.element():alias("panel")
    :width(clay.SIZING_FIXED, 160)
    :height(clay.SIZING_FIXED, 100)
    :backgroundColor(96, 64, 48, 255)
    :open()
  box("button", 100, 40, 0xc08040ff)
  clay.close()
end)
higher:on("button", "click", function() higherClicks = higherClicks + 1 end)
local updateCalls = 0
higher:update(function() updateCalls = updateCalls + 1 end)
local lowerClicks = 0
local lowerLayer = clay.retained({ alias = "lower-layer", layer = 99 }, function()
  clay.element():alias("panel")
    :width(clay.SIZING_FIXED, 160)
    :height(clay.SIZING_FIXED, 100)
    :backgroundColor(40, 48, 56, 255)
    :open()
  box("button", 100, 40, 0x506070ff)
  clay.close()
end)
lowerLayer:on("button", "click", function() lowerClicks = lowerClicks + 1 end)
frame(1 / 60)
assert(updateCalls == 1, "retained update callbacks should run once per visible frame")

local bx, by, bw, bh, found = higher:get("button"):bounds()
assert(found and bw > 0 and bh > 0, "root-local aliases should resolve element bounds")
local px, py = bx + math.max(1, bw / 2), by + math.max(1, bh / 2)
frame(1 / 60, px, py, false)
frame(1 / 60, px, py, true)
assert(not immediateHover, "a retained root above immediate UI should consume hover")
frame(1 / 60, px, py, false)
assert(higherClicks == 1 and panelClicks == 0 and lowerClicks == 0,
  "input should go to the top layer, then the most recently registered root on that layer")

higher:hide()
local hiddenBuilds = higher:stats().builds
local hiddenUpdates = updateCalls
frame(1 / 60, px, py, false)
assert(higher:stats().builds == hiddenBuilds, "hidden roots should not build or replay")
assert(updateCalls == hiddenUpdates, "hidden roots should not run update callbacks")
higher:show()
frame(1 / 60, px, py, false)
assert(higher:stats().builds == hiddenBuilds + 1, "showing a root should rebuild its cached layout")
assert(updateCalls == hiddenUpdates + 1, "showing a root should resume its update callback")

higher:hide()
lowerLayer:hide()
panel:hide()
local passthrough = clay.retained({ alias = "passthrough", layer = 101, pointerCapture = false }, function()
  box("passthrough-hit", 160, 100)
end)
frame(1 / 60, px, py, false)
assert(immediateHover, "a pointer-transparent retained root should pass hover to immediate UI")
passthrough:destroy()
panel:show()
higher:show()
lowerLayer:show()

local left, right, chooseLeft = clay.state(80), clay.state(90), clay.state(true)
local dependencyBuilds = 0
local dependencies = clay.retained({ alias = "dependencies", layer = -1 }, function()
  dependencyBuilds = dependencyBuilds + 1
  local selected = chooseLeft:get() and left:get() or right:get()
  box("dependency", selected, 20)
end)
frame(1 / 60)
chooseLeft:set(false)
frame(1 / 60)
local afterSwitch = dependencyBuilds
left:set(81)
frame(1 / 60)
assert(dependencyBuilds == afterSwitch, "a rebuild should replace the previous state dependencies")
right:set(91)
frame(1 / 60)
assert(dependencyBuilds == afterSwitch + 1, "the newly observed state should invalidate its root")

local rows = { "alpha", "beta", "gamma" }
local keyed = clay.retained({ alias = "keyed", layer = -2 }, function()
  clay.element("keyed-list")
    :width(clay.SIZING_FIXED, 120)
    :height(clay.SIZING_FIT)
    :open()
  for i = 1, #rows do
    local key = rows[i]
    clay.keyed(key, function() box("row-" .. key, 80, 12) end)
  end
  clay.close()
end)
frame(1 / 60)
local keyedIds = {}
for i = 1, #rows do keyedIds[rows[i]] = keyed:get("row-" .. rows[i]):id().id end
rows = { "gamma", "alpha", "beta" }
keyed:invalidate()
frame(1 / 60)
for i = 1, #rows do
  local key = rows[i]
  assert(keyed:get("row-" .. key):id().id == keyedIds[key], "keyed IDs should stay stable when list order changes")
end

local mode, a, b = clay.state(true), clay.state(50), clay.state(60)
local dependencySwap = clay.retained(function()
  local size = mode:get() and a:get() or b:get()
  box("swapped-dependency", size, 12)
end)
frame(1 / 60)
mode:set(false)
frame(1 / 60)
local swapBuilds = dependencySwap:stats().builds
a:set(51)
frame(1 / 60)
assert(dependencySwap:stats().builds == swapBuilds, "old dependencies should be detached after rebuild")
b:set(61)
frame(1 / 60)
assert(dependencySwap:stats().builds == swapBuilds + 1, "new dependencies should be attached after rebuild")

panel:invalidate()
local beforeResize = panel:stats().builds
frame(1 / 60, nil, nil, false, nil, nil, 400, 300)
assert(panel:stats().builds == beforeResize + 1, "viewport changes should invalidate retained roots")
assert(releasedPacketCount > 0, "replaced cached packets should release their renderer resources")

local theme = require("theme")
theme.set("graphite")
local beforeTheme = panel:stats().builds
frame(1 / 60)
assert(panel:stats().builds == beforeTheme + 1, "theme changes should invalidate retained roots")
local revision = clay.resourcesChanged()
local beforeResources = panel:stats().builds
frame(1 / 60)
assert(clay.getResourceRevision() == revision and panel:stats().builds == beforeResources + 1,
  "resource revisions should invalidate retained roots")

local scrollBuilds = 0
local scrollRoot = clay.retained({ alias = "scroll", layer = 1000 }, function()
  scrollBuilds = scrollBuilds + 1
  clay.element("scroll-viewport")
    :width(clay.SIZING_FIXED, 100)
    :height(clay.SIZING_FIXED, 60)
    :scrollable(true, false)
    :open()
  for i = 1, 8 do box("scroll-row-" .. i, 80, 30) end
  clay.close()
end)
frame(1 / 60, 20, 20, false)
local beforeScroll = scrollBuilds
frame(1 / 60, 20, 20, false, 0, -12)
assert(scrollBuilds == beforeScroll + 1, "scroll input should invalidate the hit retained root")

local transitionWidth = clay.state(40)
local transitionBuilds = 0
local animated = clay.retained({ alias = "animated", layer = -3 }, function()
  transitionBuilds = transitionBuilds + 1
  clay.element("animated-box")
    :width(clay.SIZING_FIXED, transitionWidth:get())
    :height(clay.SIZING_FIXED, 18)
    :transition(0.2, "width")
    :close()
end)
frame(1 / 60)
transitionWidth:set(100)
frame(0.05)
local afterTransitionStart = transitionBuilds
frame(0.05)
assert(transitionBuilds > afterTransitionStart, "active Clay transitions should keep their roots invalidated")

higher:destroy()
assert(higher.destroyed and runtime:get("higher") == nil, "destroy should unregister a root and release its context")
assert(releasedPacketCount > 0, "destroy should release retained render packets")
local oldDependencyBuilds = dependencies:stats().builds
dependencies:destroy()
left:set(82)
frame(1 / 60)
assert(dependencies:stats().builds == oldDependencyBuilds, "destroyed roots should detach from state dependencies")

local buildMutation = clay.state(0)
local mutationBuilds = 0
local mutationRoot = clay.retained(function()
  mutationBuilds = mutationBuilds + 1
  local value = buildMutation:get()
  box("build-mutation", 20 + value, 12)
  if value == 0 then buildMutation:set(1) end
end)
frame(1 / 60)
assert(mutationBuilds == 1, "state changes during a build should not cause a same-frame rebuild")
frame(1 / 60)
assert(mutationBuilds == 2, "state changes after a dependency read should survive the build")

local failing = clay.retained(function() error("expected retained build failure") end)
local buildOk, buildError = pcall(frame, 1 / 60)
assert(not buildOk and tostring(buildError):find("expected retained build failure", 1, true),
  "retained build errors should preserve the callback traceback")
failing:destroy()

local cleanupRoot = clay.retained({ alias = "cleanup-root" }, function() end)
cleanupRoot:on("button", "pointerleave", function() error("expected pointerleave failure") end)
cleanupRoot.hoveredAlias = "button"
local cleanupOk = pcall(cleanupRoot.destroy, cleanupRoot)
assert(not cleanupOk and cleanupRoot.context == nil and runtime:get("cleanup-root") == nil,
  "destroy should release root resources even if a pointerleave callback fails")

clay.shutdown()
assert(clay._retainedRuntime == nil, "shutdown should clear the retained runtime")
assert(clay.initialize(clay.minMemorySize(), width, height), "Clay should initialize again after shutdown")
require("clay_retained").install(clay, width, height)
clay.beginLayout()
box(nil, 12, 12)
for _ in clay.endLayoutFast() do end
clay.shutdown()
assert(clay._retainedRuntime == nil, "a reinitialized runtime should also shut down cleanly")
print("clay_retained: ok")
