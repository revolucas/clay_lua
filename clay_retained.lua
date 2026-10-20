-- Retained roots for the Clay Lua builder API.
-- Each root owns a Clay context and a copied command stream. Existing immediate
-- declarations continue to use the default context and are finalized normally.

local M = {}

local State = {}
State.__index = State

local Root = {}
Root.__index = Root

local ElementHandle = {}
ElementHandle.__index = ElementHandle

local function pack(...)
  return { n = select("#", ...), ... }
end

local function clearTable(t)
  for key in pairs(t) do t[key] = nil end
end

local function traceback(err)
  if debug and debug.traceback then return debug.traceback(tostring(err), 2) end
  return tostring(err)
end

function M.install(clay, width, height)
  assert(type(clay) == "table", "clay_retained.install expects the Clay module")
  if clay._retainedRuntime then return clay._retainedRuntime end
  assert(clay.createContext and clay.setCurrentContext and clay.destroyContext,
    "Clay native binding must provide managed contexts before retained roots can be used")

  local native = {
    beginLayout = clay.beginLayout,
    endLayoutFast = clay.endLayoutFast,
    setLayoutDimensions = clay.setLayoutDimensions,
    setMeasureTextFunction = clay.setMeasureTextFunction,
    setPointerState = clay.setPointerState,
    updateScrollContainers = clay.updateScrollContainers,
    setCullingEnabled = clay.setCullingEnabled,
    setExternalScrollHandlingEnabled = clay.setExternalScrollHandlingEnabled,
    setMaxElementCount = clay.setMaxElementCount,
    pointerOver = clay.pointerOver,
    hovered = clay.hovered,
    getPointerOverIds = clay.getPointerOverIds,
    id = clay.id,
    getElementData = clay.getElementData,
    contextHasActiveMotion = clay.contextHasActiveMotion,
    getCurrentContext = clay.getCurrentContext,
    setCurrentContext = clay.setCurrentContext,
    createContext = clay.createContext,
    destroyContext = clay.destroyContext,
    setAliasRegistrar = clay._setAliasRegistrar,
    minMemorySize = clay.minMemorySize,
  }
  local immediateContext = native.getCurrentContext()
  assert(immediateContext, "initialize Clay before installing retained roots")
  -- Clay includes its synthetic full-window root container in every pointer
  -- hit list. It is a layout boundary, not a hit target; counting it here
  -- makes any top-layer retained root consume input across the entire window.
  local rootContainerId = native.id("Clay__RootContainer").id

  local runtime = {
    roots = {},
    frontToBack = {},
    backToFront = {},
    updateOrder = {},
    activePointerRoots = {},
    idsByRoot = {},
    composeBefore = {},
    composeAfter = {},
    immediateContext = immediateContext,
    width = width,
    height = height,
    pointerX = 0,
    pointerY = 0,
    immediatePointerIds = { n = 0 },
    pointerInteractiveIdsByContext = {},
    collectingPointerInteractiveIdsByContext = {},
    pointerDown = false,
    previousDown = false,
    previousX = 0,
    previousY = 0,
    scrollX = 0,
    scrollY = 0,
    frameDt = 0,
    blocked = false,
    buildingRoot = nil,
    nextOrder = 0,
    totalBuilds = 0,
    totalLayouts = 0,
    totalReplays = 0,
  }

  local input = {
    pointerX = 0, pointerY = 0, pointerDown = false,
    deltaX = 0, deltaY = 0, scrollX = 0, scrollY = 0, deltaTime = 0,
  }
  input.consume = function() runtime.blocked = true end
  runtime.input = input

  local function withContext(root, fn)
    local previous = native.getCurrentContext()
    if previous ~= root.context then native.setCurrentContext(root.context) end
    local ok, result = pcall(fn)
    if previous ~= root.context then native.setCurrentContext(previous) end
    if not ok then error(traceback(result), 0) end
    return result
  end

  local function sortedRoots(reverse, out)
    out = out or (reverse and runtime.backToFront or runtime.frontToBack)
    for i = #out, 1, -1 do out[i] = nil end
    for i = 1, #runtime.roots do
      local root = runtime.roots[i]
      if root.visible and not root.destroyed then out[#out + 1] = root end
    end
    table.sort(out, function(a, b)
      if a.layer == b.layer then return a.order < b.order end
      return a.layer < b.layer
    end)
    if reverse then
      local i, j = 1, #out
      while i < j do out[i], out[j] = out[j], out[i]; i = i + 1; j = j - 1 end
    end
    return out
  end

  local function replaceDependencies(root, dependencies)
    for state in pairs(root.dependencies) do state.dependents[root] = nil end
    root.dependencies = dependencies
    for state in pairs(dependencies) do state.dependents[root] = true end
  end

  local function aliasRegistrar(name, id)
    local root = runtime.buildingRoot
    if not root then error(":alias() can only be used while building a retained root", 2) end
    if root.aliases[name] then error("duplicate retained element alias: " .. name, 2) end
    root.aliases[name] = id
    root.aliasById[id.id] = name
    root.aliasOrder[#root.aliasOrder + 1] = name
  end
  native.setAliasRegistrar(aliasRegistrar)

  local function callHandler(root, alias, event)
    if not alias then return false end
    local byAlias = root.handlers[alias]
    local handler = byAlias and byAlias[event]
    if not handler then return false end
    local ok, err = pcall(handler, root, alias, input)
    if not ok then error("retained root '" .. tostring(root.alias or root.order) .. "' " .. event .. " handler failed:\n" .. traceback(err), 0) end
    return true
  end

  local function pointerIds(root)
    withContext(root, function()
      native.getPointerOverIds(root.pointerIds)
    end)
    local ids = root.pointerIds
    local write = 1
    for read = 1, ids.n do
      local id = ids[read]
      if id ~= rootContainerId then
        ids[write] = id
        write = write + 1
      end
    end
    for i = write, ids.n do ids[i] = nil end
    ids.n = write - 1
    return ids
  end

  local function immediatePointerIds()
    local previous = native.getCurrentContext()
    if previous ~= immediateContext then native.setCurrentContext(immediateContext) end
    native.getPointerOverIds(runtime.immediatePointerIds)
    if previous ~= immediateContext then native.setCurrentContext(previous) end
    local ids = runtime.immediatePointerIds
    local write = 1
    for read = 1, ids.n do
      local id = ids[read]
      if id ~= rootContainerId then
        ids[write] = id
        write = write + 1
      end
    end
    for i = write, ids.n do ids[i] = nil end
    ids.n = write - 1
    return ids
  end

  local function recordInteractivePointer(id)
    local collecting = runtime.collectingPointerInteractiveIdsByContext[native.getCurrentContext()]
    if collecting and id and id.id then
      collecting[id.id] = true
    end
  end

  local function pointerHitsInteractive(context, pointerIds)
    local interactive = runtime.pointerInteractiveIdsByContext[context]
    if not interactive or not pointerIds then return false end
    for i = 1, pointerIds.n do
      if interactive[pointerIds[i]] then return true end
    end
    return false
  end

  local function dragScrollingFor(context, pointerIds, requested)
    return requested == true and not pointerHitsInteractive(context, pointerIds)
  end

  local function aliasForEvent(root, ids, wantedEvent)
    for i = ids.n, 1, -1 do
      local alias = root.aliasById[ids[i]]
      if alias then
        local handlers = root.handlers[alias]
        local hasHandler = handlers and handlers[wantedEvent]
        if wantedEvent == "pointerdown" and handlers then
          hasHandler = hasHandler or handlers.click or handlers.pointerup or handlers.drag
        elseif wantedEvent == "pointerhover" and handlers then
          hasHandler = handlers.pointerenter or handlers.pointerleave or handlers.pointermove
        end
        if hasHandler then
          return alias
        end
      end
    end
  end

  local function topHitRoot(roots, idsByRoot, aboveImmediate, captureOnly)
    for i = 1, #roots do
      local root = roots[i]
      if (root.layer >= 0) == aboveImmediate and idsByRoot[root].n > 0
          and (not captureOnly or root.pointerCapture) then
        return root
      end
    end
  end

  local function dispatchInput(dt)
    input.pointerX, input.pointerY, input.pointerDown = runtime.pointerX, runtime.pointerY, runtime.pointerDown
    input.deltaX = runtime.pointerX - runtime.previousX
    input.deltaY = runtime.pointerY - runtime.previousY
    input.scrollX, input.scrollY, input.deltaTime = runtime.scrollX, runtime.scrollY, dt
    local roots = sortedRoots(true)
    local idsByRoot = runtime.idsByRoot
    clearTable(idsByRoot)
    for i = 1, #roots do
      local root = roots[i]
      idsByRoot[root] = pointerIds(root)
    end
    local immediateIds = immediatePointerIds()
    local immediateHit = immediateIds.n > 0
    local rootAboveImmediate = topHitRoot(roots, idsByRoot, true)
    local rootBelowImmediate = topHitRoot(roots, idsByRoot, false)
    local captureAboveImmediate = topHitRoot(roots, idsByRoot, true, true)
    local captureBelowImmediate = topHitRoot(roots, idsByRoot, false, true)
    local hoverRoot = rootAboveImmediate or (not immediateHit and rootBelowImmediate)
    local hoverAlias = hoverRoot and aliasForEvent(hoverRoot, idsByRoot[hoverRoot], "pointerhover") or nil
    local pointerMoved = input.deltaX ~= 0 or input.deltaY ~= 0
    local pressed = input.pointerDown and not runtime.previousDown
    local released = not input.pointerDown and runtime.previousDown

    -- Pointer-transparent retained roots remain interactive for their own
    -- polling widgets, but pass input through to the next root or the
    -- immediate layout beneath them.
    local activePointerRoots = runtime.activePointerRoots
    clearTable(activePointerRoots)
    for i = 1, #roots do
      local root = roots[i]
      if root.layer >= 0 and idsByRoot[root].n > 0 then
        activePointerRoots[root] = true
        if root.pointerCapture then break end
      end
    end
    if not captureAboveImmediate and not immediateHit then
      for i = 1, #roots do
        local root = roots[i]
        if root.layer < 0 and idsByRoot[root].n > 0 then
          activePointerRoots[root] = true
          if root.pointerCapture then break end
        end
      end
    end

    -- Existing components poll pointer state while building. Wake a retained
    -- root only while it owns hover/capture, so stable roots stay cached.
    for i = 1, #roots do
      local root = roots[i]
      local ownsPointer = activePointerRoots[root] == true
      if ownsPointer ~= root.pointerInputActive or
          (pointerMoved and (ownsPointer or root.pointerInputActive)) or
          ((pressed or released) and (ownsPointer or root.pointerInputActive or runtime.captureRoot == root)) or
          (runtime.captureRoot == root and input.pointerDown) then
        root.dirty = true
      end
      root.pointerInputActive = ownsPointer
    end

    -- Retained roots at layer 0 and above render after the immediate UI.
    -- Negative layers receive input only when the immediate layout has no hit.
    runtime.blocked = captureAboveImmediate ~= nil
    for i = 1, #runtime.roots do
      local root = runtime.roots[i]
      local nextAlias = root == hoverRoot and hoverAlias or nil
      if nextAlias ~= root.hoveredAlias then
        if root.hoveredAlias then callHandler(root, root.hoveredAlias, "pointerleave") end
        root.hoveredAlias = nextAlias
        if nextAlias then callHandler(root, nextAlias, "pointerenter") end
      end
    end

    if input.deltaX ~= 0 or input.deltaY ~= 0 then
      if hoverRoot then
        local alias = aliasForEvent(hoverRoot, idsByRoot[hoverRoot], "pointermove")
        if alias then callHandler(hoverRoot, alias, "pointermove") end
      end
    end

    if pressed then
      local target = captureAboveImmediate
      if not target and not immediateHit then target = captureBelowImmediate end
      if target then
        local alias = aliasForEvent(target, idsByRoot[target], "pointerdown")
        runtime.captureRoot, runtime.captureAlias = target, alias
        runtime.blocked = true
        if alias then callHandler(target, alias, "pointerdown") end
      end
    elseif input.pointerDown and runtime.captureRoot then
      runtime.blocked = true
      if runtime.captureAlias then callHandler(runtime.captureRoot, runtime.captureAlias, "drag") end
    elseif released and runtime.captureRoot then
      local target, alias = runtime.captureRoot, runtime.captureAlias
      runtime.blocked = true
      if alias then callHandler(target, alias, "pointerup") end
      local ids = pointerIds(target)
      local stillOver = false
      for i = 1, ids.n do
        if alias and target.aliases[alias] and ids[i] == target.aliases[alias].id then stillOver = true; break end
      end
      if stillOver and alias then callHandler(target, alias, "click") end
      runtime.captureRoot, runtime.captureAlias = nil, nil
    end

    if input.scrollX ~= 0 or input.scrollY ~= 0 then
      local target = captureAboveImmediate
      if not target and not immediateHit then target = captureBelowImmediate end
      if target then
        runtime.blocked = true
        local alias = aliasForEvent(target, idsByRoot[target], "scroll")
        if alias then callHandler(target, alias, "scroll") end
      end
    end

    local updateRoots = sortedRoots(false, runtime.updateOrder)
    for i = 1, #updateRoots do
      local root = updateRoots[i]
      if not root.destroyed and root.visible and root.updateCallback then
        local ok, err = pcall(root.updateCallback, root, dt, input)
        if not ok then error("retained root update failed:\n" .. traceback(err), 0) end
      end
    end

    runtime.previousDown = runtime.pointerDown
    runtime.previousX, runtime.previousY = runtime.pointerX, runtime.pointerY
    runtime.scrollX, runtime.scrollY = 0, 0
  end

  local function captureCommands(iterator)
    local packets = {}
    while true do
      local packet = pack(iterator())
      if packet[1] == nil then break end
      -- Slot 26 is an opaque, stable renderer-cache key for this packet.
      packet[26] = packet
      packet.n = 26
      packets[#packets + 1] = packet
    end
    return packets
  end

  local function rebuild(root, dt)
    local previous = native.getCurrentContext()
    native.setCurrentContext(root.context)
    -- Clear before running user code so invalidations raised during the build
    -- survive and schedule one more rebuild on the following frame.
    root.dirty = false
    root.tracksKeyboardInput = false
    local oldAliases, oldAliasById, oldAliasOrder = root.aliases, root.aliasById, root.aliasOrder
    root.aliases, root.aliasById, root.aliasOrder = {}, {}, {}
    root.hasCustomCommands = false
    root.hasImageCommands = false
    local dependencies = {}
    local interactivePointerIds = {}
    runtime.collectingPointerInteractiveIdsByContext[root.context] = interactivePointerIds
    local ok, packets = xpcall(function()
      native.beginLayout()
      runtime.buildingRoot = root
      root.collectingDependencies = dependencies
      local buildOk, buildError = xpcall(root.buildCallback, traceback)
      runtime.buildingRoot = nil
      root.collectingDependencies = nil
      local iterator = native.endLayoutFast(dt)
      local capturedPackets = captureCommands(iterator)
      if not buildOk then error(buildError, 0) end
      return capturedPackets
    end, traceback)
    runtime.buildingRoot = nil
    root.collectingDependencies = nil
    runtime.collectingPointerInteractiveIdsByContext[root.context] = nil
    native.setCurrentContext(previous)
    if not ok then
      root.aliases, root.aliasById, root.aliasOrder = oldAliases, oldAliasById, oldAliasOrder
      root.dirty = true
      error("retained root '" .. tostring(root.alias or root.order) .. "' build failed:\n" .. tostring(packets), 0)
    end

    -- Retained event handlers are input claims too, even when their callback
    -- does not call pointerOver itself.
    for alias, handlers in pairs(root.handlers) do
      local id = root.aliases[alias]
      if id and next(handlers) then interactivePointerIds[id.id] = true end
    end

    runtime.pointerInteractiveIdsByContext[root.context] = interactivePointerIds

    replaceDependencies(root, dependencies)
    if clay._releaseRetainedPackets then clay._releaseRetainedPackets(root.packets) end
    root.packets = packets
    root.builds = root.builds + 1
    root.layouts = root.layouts + 1
    root.statistics.builds, root.statistics.layouts = root.builds, root.layouts
    runtime.totalBuilds = runtime.totalBuilds + 1
    runtime.totalLayouts = runtime.totalLayouts + 1

    for i = 1, #packets do
      local commandType = packets[i][1]
      if commandType == clay.RENDER_CUSTOM then
        root.hasCustomCommands = true
      elseif commandType == clay.RENDER_IMAGE then
        root.hasImageCommands = true
      end
      if root.hasCustomCommands and root.hasImageCommands then break end
    end
    if root.volatile then root.dirty = true end
  end

  local function collectVisibleRoots(dt)
    local roots = sortedRoots(false)
    for i = 1, #roots do
      local root = roots[i]
      if root.dirty then rebuild(root, dt) end
      if withContext(root, native.contextHasActiveMotion) then root.dirty = true end
    end
    return roots
  end

  local function composeIterator(immediateIterator, roots)
    local before, after = runtime.composeBefore, runtime.composeAfter
    for i = #before, 1, -1 do before[i] = nil end
    for i = #after, 1, -1 do after[i] = nil end
    for i = 1, #roots do
      local root = roots[i]
      if root.layer < 0 then before[#before + 1] = root else after[#after + 1] = root end
    end
    local group, rootIndex, packetIndex, immediateDone = 1, 1, 1, false
    return function()
      while true do
        local current = group == 1 and before or after
        if group == 2 then
          if not immediateDone then
            local t, x, y, w, h, r, g, b, a, tl, tr, bl, br,
              left, right, top, bottom, text, fontId, fontSize,
              letterSpacing, lineHeight, payload, clipH, clipV = immediateIterator()
            if t ~= nil then
              return t, x, y, w, h, r, g, b, a, tl, tr, bl, br,
                left, right, top, bottom, text, fontId, fontSize,
                letterSpacing, lineHeight, payload, clipH, clipV
            end
            immediateDone = true
          end
          group, rootIndex, packetIndex = 3, 1, 1
          current = after
        end
        if group == 1 and rootIndex > #before then
          group, rootIndex, packetIndex = 2, 1, 1
        elseif group == 3 and rootIndex > #after then
          return nil
        else
          local root = current[rootIndex]
          local packet = root and root.packets[packetIndex]
          if packet then
            packetIndex = packetIndex + 1
            root.replays = root.replays + 1
            root.statistics.replays = root.replays
            runtime.totalReplays = runtime.totalReplays + 1
            return unpack(packet, 1, packet.n)
          end
          rootIndex, packetIndex = rootIndex + 1, 1
        end
      end
    end
  end

  local function invalidateStateDependents(state)
    for root in pairs(state.dependents) do
      -- A dependency from the previous build is not relevant if the current
      -- branch no longer reads it. The in-progress build subscribes as it reads.
      if root ~= runtime.buildingRoot or
          (root.collectingDependencies and root.collectingDependencies[state]) then
        root.dirty = true
      end
    end
    local buildingRoot = runtime.buildingRoot
    if buildingRoot and buildingRoot.collectingDependencies and
        buildingRoot.collectingDependencies[state] then
      buildingRoot.dirty = true
    end
  end

  function State:get()
    local root = runtime.buildingRoot
    if root then root.collectingDependencies[self] = true end
    return self.value
  end

  function State:set(value)
    if self.value == value then return false end
    self.value = value
    invalidateStateDependents(self)
    return true
  end

  function State:update(fn)
    assert(type(fn) == "function", "state:update expects a function")
    local previous = self.value
    local value = fn(self.value)
    if value ~= nil then self.value = value end
    if previous ~= self.value then
      invalidateStateDependents(self)
    end
    return self.value
  end

  function State:touch()
    invalidateStateDependents(self)
    return self.value
  end

  function Root:invalidate()
    if not self.destroyed then self.dirty = true end
    return self
  end

  function Root:show()
    if not self.destroyed and not self.visible then self.visible = true; self.dirty = true end
    return self
  end

  function Root:hide()
    self.visible = false
    self.pointerInputActive = false
    if runtime.captureRoot == self then runtime.captureRoot, runtime.captureAlias = nil, nil end
    local hoveredAlias = self.hoveredAlias
    self.hoveredAlias = nil
    if hoveredAlias then callHandler(self, hoveredAlias, "pointerleave") end
    return self
  end

  function Root:withContext(callback, ...)
    assert(type(callback) == "function", "root:withContext expects a callback")
    local previous = native.getCurrentContext()
    if previous ~= self.context then native.setCurrentContext(self.context) end
    local ok, result = pcall(callback, ...)
    if previous ~= self.context then native.setCurrentContext(previous) end
    if not ok then error(traceback(result), 0) end
    return result
  end

  function Root:destroy()
    if self.destroyed then return false end
    assert(runtime.buildingRoot ~= self, "cannot destroy a retained root while its build callback is running")
    self.destroyed = true
    replaceDependencies(self, {})
    for i = #runtime.roots, 1, -1 do
      if runtime.roots[i] == self then table.remove(runtime.roots, i); break end
    end
    if runtime.captureRoot == self then runtime.captureRoot, runtime.captureAlias = nil, nil end
    local hoveredAlias = self.hoveredAlias
    self.hoveredAlias = nil
    local leaveOk, leaveError = true, nil
    if hoveredAlias then leaveOk, leaveError = pcall(callHandler, self, hoveredAlias, "pointerleave") end
    if self.alias then runtime.rootsByAlias[self.alias] = nil end
    if clay._releaseRetainedPackets then clay._releaseRetainedPackets(self.packets) end
    runtime.pointerInteractiveIdsByContext[self.context] = nil
    runtime.collectingPointerInteractiveIdsByContext[self.context] = nil
    native.destroyContext(self.context)
    self.context, self.packets, self.buildCallback = nil, nil, nil
    self.handlers, self.aliases, self.aliasById, self.aliasOrder, self.handles = {}, {}, {}, {}, {}
    if not leaveOk then error(leaveError, 0) end
    return true
  end

  function Root:on(alias, event, callback)
    assert(type(alias) == "string" and alias ~= "", "root:on expects an element alias")
    assert(type(event) == "string" and event ~= "", "root:on expects an event name")
    assert(type(callback) == "function", "root:on expects a callback")
    local byAlias = self.handlers[alias]
    if not byAlias then byAlias = {}; self.handlers[alias] = byAlias end
    byAlias[event] = callback
    local id = self.aliases[alias]
    local interactive = runtime.pointerInteractiveIdsByContext[self.context]
    if id and interactive then interactive[id.id] = true end
    return self
  end

  function Root:update(callback)
    assert(callback == nil or type(callback) == "function", "root:update expects a function or nil")
    self.updateCallback = callback
    return self
  end

  function Root:get(alias)
    assert(type(alias) == "string" and alias ~= "", "root:get expects an element alias")
    local handle = self.handles[alias]
    if not handle then
      handle = setmetatable({ root = self, alias = alias }, ElementHandle)
      self.handles[alias] = handle
    end
    return handle
  end

  function Root:stats()
    return self.statistics
  end

  function Root:_pointerOver(alias)
    local id = self.aliases[alias]
    if not id or self.destroyed then return false end
    return withContext(self, function()
      recordInteractivePointer(id)
      return native.pointerOver(id)
    end)
  end

  function ElementHandle:pointerOver()
    return self.root:_pointerOver(self.alias)
  end

  function ElementHandle:id()
    return self.root.aliases[self.alias]
  end

  function ElementHandle:bounds()
    local id = self.root.aliases[self.alias]
    if not id or self.root.destroyed then return 0, 0, 0, 0, false end
    local data = withContext(self.root, function() return native.getElementData(id) end)
    return data.x, data.y, data.width, data.height, data.found
  end

  function clay.state(value)
    return setmetatable({ value = value, dependents = {} }, State)
  end

  function clay.retained(options, buildCallback)
    if type(options) == "function" then buildCallback, options = options, {} end
    options = options or {}
    assert(type(options) == "table", "clay.retained expects options and a build callback")
    assert(type(buildCallback) == "function", "clay.retained expects a build callback")
    if options.alias ~= nil then
      assert(type(options.alias) == "string" and options.alias ~= "", "retained root alias must be a non-empty string")
      for i = 1, #runtime.roots do
        assert(runtime.roots[i].alias ~= options.alias, "duplicate retained root alias: " .. options.alias)
      end
    end
    assert(options.layer == nil or type(options.layer) == "number", "retained root layer must be numeric")
    assert(options.capacity == nil or (type(options.capacity) == "number" and options.capacity > 0 and
      options.capacity == math.floor(options.capacity)), "retained root capacity must be a positive integer")
    assert(options.volatile == nil or type(options.volatile) == "boolean", "retained root volatile must be boolean")
    assert(options.pointerCapture == nil or type(options.pointerCapture) == "boolean",
      "retained root pointerCapture must be boolean")

    runtime.nextOrder = runtime.nextOrder + 1
    local capacity = options.capacity or native.minMemorySize()
    local context = native.createContext(capacity, runtime.width or 800, runtime.height or 600)
    assert(context, "failed to create Clay context for retained root")
    local root = setmetatable({
      alias = options.alias,
      layer = options.layer or 0,
      order = runtime.nextOrder,
      context = context,
      buildCallback = buildCallback,
      updateCallback = nil,
      handlers = {},
      aliases = {},
      aliasById = {},
      aliasOrder = {},
      handles = {},
      dependencies = {},
      pointerIds = { n = 0 },
      packets = {},
      visible = options.visible ~= false,
      pointerCapture = options.pointerCapture ~= false,
      pointerInputActive = false,
      tracksKeyboardInput = false,
      dirty = true,
      volatile = options.volatile == true,
      hasCustomCommands = false,
      hasImageCommands = false,
      builds = 0,
      layouts = 0,
      replays = 0,
      destroyed = false,
      statistics = { builds = 0, layouts = 0, replays = 0 },
    }, Root)
    runtime.roots[#runtime.roots + 1] = root
    return root
  end

  function clay.invalidateAll()
    for i = 1, #runtime.roots do runtime.roots[i].dirty = true end
  end

  -- Built-in widgets that poll keyboard state during their build opt in here.
  function clay._trackRetainedKeyboardInput(active)
    local root = runtime.buildingRoot
    if not root or active == false then return false end
    root.tracksKeyboardInput = true
    return true
  end

  -- Some input-polled widgets update visual state after declaring their
  -- elements. Ask the current root for one follow-up build to publish it.
  function clay._invalidateCurrentRetainedRoot()
    local root = runtime.buildingRoot
    if not root then return false end
    root.dirty = true
    return true
  end

  function clay._invalidateRetainedKeyboardInput()
    for i = 1, #runtime.roots do
      local root = runtime.roots[i]
      if root.visible and root.tracksKeyboardInput then root.dirty = true end
    end
  end

  runtime.resourceRevision = 0
  function clay.resourcesChanged()
    runtime.resourceRevision = runtime.resourceRevision + 1
    clay.invalidateAll()
    return runtime.resourceRevision
  end

  -- Call after image handles used by retained roots become render-ready.
  -- Only roots whose captured command stream contains an image need rebuilding.
  function clay.imageResourcesChanged()
    runtime.resourceRevision = runtime.resourceRevision + 1
    for i = 1, #runtime.roots do
      local root = runtime.roots[i]
      if not root.destroyed and root.hasImageCommands then
        root.dirty = true
      end
    end
    return runtime.resourceRevision
  end

  function clay.getResourceRevision()
    return runtime.resourceRevision
  end

  function clay.retainedStats()
    return runtime.totalBuilds, runtime.totalLayouts, runtime.totalReplays
  end

  -- Keep viewport and pointer state synchronized across independent Clay contexts.
  clay.setLayoutDimensions = function(w, h)
    local changed = runtime.width ~= w or runtime.height ~= h
    runtime.width, runtime.height = w, h
    local previous = native.getCurrentContext()
    native.setCurrentContext(immediateContext)
    native.setLayoutDimensions(w, h)
    for i = 1, #runtime.roots do
      local root = runtime.roots[i]
      native.setCurrentContext(root.context)
      native.setLayoutDimensions(w, h)
      if changed then root.dirty = true end
    end
    native.setCurrentContext(previous)
  end

  local function setMeasureFunctionOnAllContexts(setter, callback)
    if not setter then return end
    local previous = native.getCurrentContext()
    native.setCurrentContext(immediateContext)
    setter(callback)
    for i = 1, #runtime.roots do
      native.setCurrentContext(runtime.roots[i].context)
      setter(callback)
    end
    native.setCurrentContext(previous)
  end

  if native.setMeasureTextFunction then
    clay.setMeasureTextFunction = function(callback)
      setMeasureFunctionOnAllContexts(native.setMeasureTextFunction, callback)
      clay.invalidateAll()
    end
  end

  clay.setPointerState = function(x, y, down)
    runtime.pointerX, runtime.pointerY, runtime.pointerDown = x, y, not not down
    down = not not down
    local previous = native.getCurrentContext()
    native.setCurrentContext(immediateContext)
    native.setPointerState(x, y, down)
    for i = 1, #runtime.roots do
      local root = runtime.roots[i]
      if root.visible then
        native.setCurrentContext(root.context)
        native.setPointerState(x, y, down)
      end
    end
    native.setCurrentContext(previous)
  end

  clay.updateScrollContainers = function(enable, dx, dy, dt, routeOnly)
    dx, dy, dt = dx or 0, dy or 0, dt or 0
    runtime.scrollX, runtime.scrollY = runtime.scrollX + dx, runtime.scrollY + dy
    local roots = sortedRoots(true)
    local idsByRoot = runtime.idsByRoot
    clearTable(idsByRoot)
    for i = 1, #roots do idsByRoot[roots[i]] = pointerIds(roots[i]) end
    local immediateIds = immediatePointerIds()
    local immediateHit = immediateIds.n > 0
    local target = topHitRoot(roots, idsByRoot, true, true)
    if not target and not immediateHit then target = topHitRoot(roots, idsByRoot, false, true) end

    local previous = native.getCurrentContext()
    native.setCurrentContext(immediateContext)
    local immediateMoving = native.contextHasActiveMotion()
    if not target then
      if not routeOnly then
        native.updateScrollContainers(
          dragScrollingFor(immediateContext, immediateIds, enable), dx, dy, dt)
      end
    elseif immediateMoving and not routeOnly then
      -- A captured retained layer owns this pointer; keep only existing
      -- momentum alive in the immediate context.
      native.updateScrollContainers(false, 0, 0, dt)
    end

    for i = 1, #runtime.roots do
      local root = runtime.roots[i]
      if root.visible then
        native.setCurrentContext(root.context)
        local moving = native.contextHasActiveMotion()
        if root == target then
          -- Clay's scroll update removes scroll-container records whose
          -- openThisFrame flag was not refreshed by a layout. Retained roots
          -- skip layout while clean, so don't run the native update just
          -- because the pointer is resting over one. Run it only for actual
          -- wheel/drag input or active momentum, then rebuild the root so its
          -- scroll containers are declared again before the next frame.
          local pointerActive = runtime.pointerDown or runtime.previousDown
          local hasScrollInput = dx ~= 0 or dy ~= 0 or pointerActive
          if not routeOnly and (hasScrollInput or moving) then
            native.updateScrollContainers(
              dragScrollingFor(root.context, idsByRoot[root], enable), dx, dy, dt)
          end
          if hasScrollInput or moving then root.dirty = true end
        elseif moving then
          root.dirty = true
          if not routeOnly then native.updateScrollContainers(false, 0, 0, dt) end
        end
      end
    end
    native.setCurrentContext(previous)
  end

  if native.setCullingEnabled then
    clay.setCullingEnabled = function(enabled)
      local previous = native.getCurrentContext()
      native.setCurrentContext(immediateContext)
      native.setCullingEnabled(enabled)
      for i = 1, #runtime.roots do
        native.setCurrentContext(runtime.roots[i].context)
        native.setCullingEnabled(enabled)
      end
      native.setCurrentContext(previous)
    end
  end

  if native.setExternalScrollHandlingEnabled then
    clay.setExternalScrollHandlingEnabled = function(enabled)
      local previous = native.getCurrentContext()
      native.setCurrentContext(immediateContext)
      native.setExternalScrollHandlingEnabled(enabled)
      for i = 1, #runtime.roots do
        native.setCurrentContext(runtime.roots[i].context)
        native.setExternalScrollHandlingEnabled(enabled)
      end
      native.setCurrentContext(previous)
    end
  end

  if native.setMaxElementCount then
    clay.setMaxElementCount = function(count)
      local previous = native.getCurrentContext()
      native.setCurrentContext(immediateContext)
      native.setMaxElementCount(count)
      for i = 1, #runtime.roots do
        native.setCurrentContext(runtime.roots[i].context)
        native.setMaxElementCount(count)
      end
      native.setCurrentContext(previous)
    end
  end

  clay.beginLayout = function(dt)
    runtime.frameDt = dt or 0
    dispatchInput(runtime.frameDt)
    runtime.collectingPointerInteractiveIdsByContext[immediateContext] = {}
    native.setCurrentContext(immediateContext)
    return native.beginLayout()
  end

  clay.endLayoutFast = function(dt)
    dt = dt or runtime.frameDt or 0
    native.setCurrentContext(immediateContext)
    local immediateIterator = native.endLayoutFast(dt)
    runtime.pointerInteractiveIdsByContext[immediateContext] =
      runtime.collectingPointerInteractiveIdsByContext[immediateContext] or {}
    runtime.collectingPointerInteractiveIdsByContext[immediateContext] = nil
    local roots = collectVisibleRoots(dt)
    native.setCurrentContext(immediateContext)
    return composeIterator(immediateIterator, roots)
  end

  local oldPointerOver = native.pointerOver
  clay.pointerOver = function(id)
    recordInteractivePointer(id)
    if runtime.blocked and native.getCurrentContext() == immediateContext then return false end
    return oldPointerOver(id)
  end
  local oldHovered = native.hovered
  clay.hovered = function()
    if runtime.blocked and native.getCurrentContext() == immediateContext then return false end
    return oldHovered()
  end

  runtime.rootsByAlias = {}
  function runtime:get(alias) return self.rootsByAlias[alias] end
  local originalRetained = clay.retained
  clay.retained = function(options, buildCallback)
    local root = originalRetained(options, buildCallback)
    if root.alias then runtime.rootsByAlias[root.alias] = root end
    return root
  end

  local originalDestroy = Root.destroy
  Root.destroy = function(self)
    if self.alias then runtime.rootsByAlias[self.alias] = nil end
    return originalDestroy(self)
  end

  local nativeShutdown = clay.shutdown
  clay.shutdown = function()
    for i = #runtime.roots, 1, -1 do runtime.roots[i]:destroy() end
    native.setAliasRegistrar(nil)
    if nativeShutdown then nativeShutdown() end
    clay.setLayoutDimensions = native.setLayoutDimensions
    clay.setPointerState = native.setPointerState
    clay.updateScrollContainers = native.updateScrollContainers
    clay.beginLayout = native.beginLayout
    clay.endLayoutFast = native.endLayoutFast
    clay.pointerOver = native.pointerOver
    clay.hovered = native.hovered
    clay.shutdown = nativeShutdown
    clay.retained = originalRetained
    if native.setMeasureTextFunction then
      clay.setMeasureTextFunction = native.setMeasureTextFunction
    end
    if native.setCullingEnabled then clay.setCullingEnabled = native.setCullingEnabled end
    if native.setExternalScrollHandlingEnabled then
      clay.setExternalScrollHandlingEnabled = native.setExternalScrollHandlingEnabled
    end
    if native.setMaxElementCount then clay.setMaxElementCount = native.setMaxElementCount end
    clay.state = nil
    clay.invalidateAll = nil
    clay._trackRetainedKeyboardInput = nil
    clay._invalidateCurrentRetainedRoot = nil
    clay._invalidateRetainedKeyboardInput = nil
    clay.resourcesChanged = nil
    clay.imageResourcesChanged = nil
    clay.getResourceRevision = nil
    clay.retainedStats = nil
    Root.destroy = originalDestroy
    clay._retainedRuntime = nil
  end

  clay._retainedRuntime = runtime
  return runtime
end

return M
