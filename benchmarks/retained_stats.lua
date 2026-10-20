-- Compare rebuilding one fixed Clay tree every frame with replaying a retained
-- copy of that same tree. This measures the Lua/C binding and Clay work, not
-- BGFX submission or presentation time.

local sourceDir = (debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or ".")
local projectDir = sourceDir .. "/.."
package.cpath = projectDir .. "/bin/linux64/?.so;" .. package.cpath

local clay = require("clay")
_G.clay = clay
local retained = require("clay_retained")

local rowCount = tonumber(arg[1]) or 1000
local frameCount = tonumber(arg[2]) or 180
assert(rowCount > 0 and rowCount == math.floor(rowCount), "row count must be a positive integer")
assert(frameCount > 0 and frameCount == math.floor(frameCount), "frame count must be a positive integer")

local width, height = 1280, 720
local capacity = 16 * 1024 * 1024
assert(clay.initialize(capacity, width, height))
retained.install(clay, width, height)
clay.setLayoutDimensions(width, height)
clay.setPointerState(-1, -1, false)

local buildCalls = 0
local declaredElements = 0
local function buildTree()
  buildCalls = buildCalls + 1
  declaredElements = declaredElements + 1
  clay.element()
    :width(clay.SIZING_FIXED, width)
    :height(clay.SIZING_FIXED, height)
    :col()
    :backgroundColor(24, 28, 36, 255)
    :open()
  for i = 1, rowCount do
    declaredElements = declaredElements + 1
    clay.element()
      :width(clay.SIZING_GROW)
      :height(clay.SIZING_FIXED, 12)
      :backgroundColor(48 + (i % 2) * 8, 60, 76, 255)
      :close()
  end
  clay.close()
end

local function frame(buildImmediate)
  clay.beginLayout(1 / 60)
  if buildImmediate then buildTree() end
  local commands = 0
  for _ in clay.endLayoutFast(1 / 60) do commands = commands + 1 end
  return commands
end

local warmupFrames = 12
for _ = 1, warmupFrames do frame(true) end
buildCalls, declaredElements = 0, 0
collectgarbage("collect")

local immediateCommands = 0
local immediateStart = os.clock()
for _ = 1, frameCount do
  immediateCommands = immediateCommands + frame(true)
end
local immediateSeconds = os.clock() - immediateStart
local immediateBuildCalls = buildCalls
local immediateElements = declaredElements

buildCalls, declaredElements = 0, 0
local root = clay.retained({ alias = "benchmark", capacity = capacity }, buildTree)
local retainedStart = os.clock()
local retainedInitialCommands = frame(false)
local retainedBuildSeconds = os.clock() - retainedStart
local retainedBuildCalls = buildCalls
local retainedElements = declaredElements

for _ = 1, warmupFrames do frame(false) end
local before = root:stats().replays
local retainedReplayCommands = 0
local retainedReplayStart = os.clock()
for _ = 1, frameCount do
  retainedReplayCommands = retainedReplayCommands + frame(false)
end
local retainedReplaySeconds = os.clock() - retainedReplayStart
local measuredReplays = root:stats().replays - before

local commandsPerFrame = retainedInitialCommands
assert(immediateCommands == frameCount * commandsPerFrame,
  "immediate and retained paths emitted different command counts")
assert(retainedReplayCommands == frameCount * commandsPerFrame,
  "retained replay did not return the same commands per frame")
assert(immediateBuildCalls == frameCount and retainedBuildCalls == 1,
  "unexpected immediate or retained build count")
assert(immediateElements == frameCount * (rowCount + 1) and retainedElements == rowCount + 1,
  "unexpected element declaration count")
assert(measuredReplays == frameCount * commandsPerFrame,
  "retained replay statistics do not match the commands observed")

local immediateMs = immediateSeconds * 1000 / frameCount
local retainedMs = retainedReplaySeconds * 1000 / frameCount
local reduction = immediateSeconds > 0 and (1 - retainedReplaySeconds / immediateSeconds) * 100 or 0
local speedup = retainedReplaySeconds > 0 and immediateSeconds / retainedReplaySeconds or 0

print(string.format("Tree: 1 root + %d rows = %d Clay elements", rowCount, rowCount + 1))
print(string.format("Render commands per frame: %d", commandsPerFrame))
print(string.format("Measured frames per mode: %d (after %d warmup frames)", frameCount, warmupFrames))
print(string.format("Immediate: %d full builds/layouts, %d element declarations, %d generated commands, %.3f ms/frame",
  immediateBuildCalls, immediateElements, immediateCommands, immediateMs))
print(string.format("Retained:  %d full build/layout, %d element declarations, %d generated commands, %.3f ms startup build",
  retainedBuildCalls, retainedElements, retainedInitialCommands, retainedBuildSeconds * 1000))
print(string.format("           %d empty immediate layouts plus %d cached command replays, %.3f ms/frame steady-state",
  frameCount, measuredReplays, retainedMs))
print(string.format("Steady-state CPU change: %.1f%% lower, %.2fx faster (builder + Clay layout + packet iteration)",
  reduction, speedup))

root:destroy()
clay.shutdown()
