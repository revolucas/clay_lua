ffi = require("ffi")

local function script_dir()
  local src = debug.getinfo(1, "S").source
  if src:sub(1, 1) == "@" then
    src = src:sub(2)
  end
  return (src:match("^(.*)[/\\]") or ".")
end

if ffi.os == "Windows" then
	local dir = script_dir()
	local bin = dir .. "/bin/x64"
	bin = bin:gsub("/", "\\")

	package.cpath = bin .. "\\?.dll;" .. package.cpath

	-- Set DLL directory (necessary for ffi.load)
	ffi.cdef[[
		int __stdcall SetDllDirectoryA(const char* lpPathName);
	]]

	ffi.C.SetDllDirectoryA(bin)
elseif ffi.os == "Linux" then
	local dir = script_dir()
	package.cpath = dir .. "/bin/linux64/?.so;" .. package.cpath
end

clay = require("clay") -- global make project-wide
theme = require("theme") -- global reusable color/spacing/type tokens
clay.theme = theme -- native :style(alias) scopes resolve through this table
theme.syncGlobals()
local retained_runtime = require("clay_retained")
bgfx = require("ffi.ffi_bgfx") -- global make project-wide
local shader_manager = require("shader_manager")

local stbrt = require("ffi.ffi_stb_rect_pack")
local stbtt = require("ffi.ffi_stb_truetype")
local stbi = require("ffi.ffi_stb_image")

local window = require("window")
local font_manager = require("font_manager")

require("ffi.ffi_math")

local uniformScratch = ffi.new("float[4]")
local function setUniform4(uniform, x, y, z, w)
	uniformScratch[0], uniformScratch[1], uniformScratch[2], uniformScratch[3] = x, y, z, w
	bgfx.bgfx_set_uniform(uniform, uniformScratch, 1)
end

local retainedRenderGeometry = setmetatable({}, { __mode = "k" })
local function retainedGeometry(packet, slot, create)
	if not packet then return create() end
	local packetCache = retainedRenderGeometry[packet]
	if not packetCache then
		packetCache = {}
		retainedRenderGeometry[packet] = packetCache
	end
	local data = packetCache[slot]
	if not data then
		data = create()
		packetCache[slot] = data
	end
	return data
end

local transientVertexScratch = ffi.new("bgfx_transient_vertex_buffer_t[1]")
local transientIndexScratch = ffi.new("bgfx_transient_index_buffer_t[1]")

local function validBuffer(handle)
	return handle ~= nil and handle.idx ~= 0xffff
end

local function bindGeometry(packet, geometry)
	local vertexCount, indexCount = geometry.vertCount or 0, geometry.idxCount or 0
	if vertexCount <= 0 or indexCount <= 0 then return false end

	if packet then
		if not validBuffer(geometry.vertexBuffer) or not validBuffer(geometry.indexBuffer) then
			if validBuffer(geometry.vertexBuffer) then bgfx.bgfx_destroy_vertex_buffer(geometry.vertexBuffer) end
			if validBuffer(geometry.indexBuffer) then bgfx.bgfx_destroy_index_buffer(geometry.indexBuffer) end
			geometry.vertexBuffer, geometry.indexBuffer = nil, nil

			local vertexMemory = bgfx.bgfx_copy(geometry.vertices, ffi.sizeof("Vertex") * vertexCount)
			if vertexMemory == nil or vertexMemory == ffi.NULL then return false end
			geometry.vertexBuffer = bgfx.bgfx_create_vertex_buffer(vertexMemory, device.vdecl, bgfx.BGFX_BUFFER_NONE)
			if not validBuffer(geometry.vertexBuffer) then
				geometry.vertexBuffer = nil
				return false
			end

			local indexMemory = bgfx.bgfx_copy(geometry.indices, ffi.sizeof("uint16_t") * indexCount)
			if indexMemory == nil or indexMemory == ffi.NULL then
				bgfx.bgfx_destroy_vertex_buffer(geometry.vertexBuffer)
				geometry.vertexBuffer = nil
				return false
			end
			geometry.indexBuffer = bgfx.bgfx_create_index_buffer(indexMemory, bgfx.BGFX_BUFFER_NONE)
			if not validBuffer(geometry.vertexBuffer) or not validBuffer(geometry.indexBuffer) then
				bgfx.bgfx_destroy_vertex_buffer(geometry.vertexBuffer)
				if validBuffer(geometry.indexBuffer) then bgfx.bgfx_destroy_index_buffer(geometry.indexBuffer) end
				geometry.vertexBuffer, geometry.indexBuffer = nil, nil
				return false
			end
		end
		bgfx.bgfx_set_vertex_buffer(0, geometry.vertexBuffer, 0, vertexCount)
		bgfx.bgfx_set_index_buffer(geometry.indexBuffer, 0, indexCount)
		return true
	end

	if bgfx.bgfx_get_avail_transient_vertex_buffer(vertexCount, device.vdecl) < vertexCount
		or bgfx.bgfx_get_avail_transient_index_buffer(indexCount, true) < indexCount then
		return false
	end
	bgfx.bgfx_alloc_transient_vertex_buffer(transientVertexScratch, vertexCount, device.vdecl)
	bgfx.bgfx_alloc_transient_index_buffer(transientIndexScratch, indexCount, false)
	ffi.copy(transientVertexScratch[0].data, geometry.vertices, ffi.sizeof("Vertex") * vertexCount)
	ffi.copy(transientIndexScratch[0].data, geometry.indices, ffi.sizeof("uint16_t") * indexCount)
	bgfx.bgfx_set_transient_vertex_buffer(0, transientVertexScratch, 0, vertexCount)
	bgfx.bgfx_set_transient_index_buffer(transientIndexScratch, 0, indexCount)
	return true
end

local function releaseRetainedPackets(packets)
	if not packets then return end
	for i = 1, #packets do
		local packet = packets[i]
		local cache = retainedRenderGeometry[packet]
		if cache then
			for _, geometry in pairs(cache) do
				if geometry.font then
					font_manager.release(geometry.font)
				end
				local batches = geometry.batches
				if batches then
					for _, batch in ipairs(batches) do
						if validBuffer(batch.vertexBuffer) then bgfx.bgfx_destroy_vertex_buffer(batch.vertexBuffer) end
						if validBuffer(batch.indexBuffer) then bgfx.bgfx_destroy_index_buffer(batch.indexBuffer) end
					end
				end
				if validBuffer(geometry.vertexBuffer) then bgfx.bgfx_destroy_vertex_buffer(geometry.vertexBuffer) end
				if validBuffer(geometry.indexBuffer) then bgfx.bgfx_destroy_index_buffer(geometry.indexBuffer) end
			end
			retainedRenderGeometry[packet] = nil
		end
	end
end

ffi.cdef [[
	typedef struct {
		float x, y;
		float u, v;
		uint8_t r, g, b, a;
	} Vertex;
]]

demo = nil -- main layout

-- Device setup
device = {}
device.win = nil
device.width = 800
device.height = 600
device.view_id = 0 -- BGFX view ID
device.font = nil -- For stb_truetype font
device.shader = nil -- BGFX shader program
device.bgfx_init_s = nil
device.clay_memory = nil
device.clay_arena = nil
device.scroll = {x = 0, y = 0}

-- Shader uniforms
u_transform2D = nil
u_rcParams = nil
u_rcCorner = nil
u_rcBorder = nil
u_borderColor = nil
u_mode = nil

cache = {}
function loadScript(filename)
	if cache[filename] then
		return cache[filename]
	end

	local fh = assert(io.open(filename, "rb"), "[WARNING] File not found: " .. filename)
	local src = fh:read("*a")
	fh:close()

	-- Give the chunk a real name so traces show "filename:line"
	local chunk, err = loadstring(src, "@" .. filename)
	if not chunk then
		-- Show where load failed (syntax error, etc.)
		io.stderr:write(debug.traceback(err, 2), "\n")
		return nil
	end

	-- Isolated environment (inherit globals via metatable)
	local env = {}
	setmetatable(env, { __index = _G })
	setfenv(chunk, env)

	-- Traceback handler that anchors at level 2 (skip xpcall + handler)
	local function tb(msg)
		return debug.traceback(tostring(msg), 2)
	end

	local ok, res = xpcall(chunk, tb)
	if ok then
		print("Loaded script: " .. filename)
		cache[filename] = env
		return env
	else
		-- res already includes the full traceback with filename:line
		io.stderr:write(res, "\n")
		return nil
	end
end

-- Helper to generate vertices for a rectangle
local function generateRectangleVertices(x, y, width, height, r, g, b, a)
	local r = math.max(0, math.min(255, r))
	local g = math.max(0, math.min(255, g))
	local b = math.max(0, math.min(255, b))
	local a = math.max(0, math.min(255, a))

	local vertices = ffi.new("Vertex[4]")
	vertices[0] = {x, y, 0, 0, r, g, b, a}
	vertices[1] = {x + width, y, 1, 0, r, g, b, a}
	vertices[2] = {x + width, y + height, 1, 1, r, g, b, a}
	vertices[3] = {x, y + height, 0, 1, r, g, b, a}
	local indices = ffi.new("uint16_t[6]", {0, 1, 2, 0, 2, 3})
	return vertices, indices
end

local function generateCircleVertices(x, y, w, h, r, g, b, a, segments)
	segments = segments or 48

	-- clamp to 0..255 like your rectangle helper
	r = math.max(0, math.min(255, r))
	g = math.max(0, math.min(255, g))
	b = math.max(0, math.min(255, b))
	a = math.max(0, math.min(255, a))

	local cx = x + w * 0.5
	local cy = y + h * 0.5
	local radius = math.max(0.0, math.min(w, h) * 0.5)

	-- center + one per segment + closing vertex
	local vertCount = segments + 2
	local idxCount  = segments * 3

	local vertices = ffi.new("Vertex[?]", vertCount)
	local indices  = ffi.new("uint16_t[?]", idxCount)

	-- center
	vertices[0] = { cx, cy, 0.5, 0.5, r, g, b, a }

	for i = 0, segments do
		local t = (i / segments) * (math.pi * 2.0)
		local vx = cx + math.cos(t) * radius
		local vy = cy + math.sin(t) * radius
		-- put UVs in 0..1 circle just to keep sampling the white tex sane
		local u = 0.5 + 0.5 * math.cos(t)
		local v = 0.5 + 0.5 * math.sin(t)
		vertices[i + 1] = { vx, vy, u, v, r, g, b, a }

		if i < segments then
			local base = i * 3
			indices[base + 0] = 0
			indices[base + 1] = i + 1
			indices[base + 2] = i + 2
		end
	end

	return vertices, indices, vertCount, idxCount
end

local function generateRingVertices(x, y, w, h, thickness, r, g, b, a, segments)
	segments = segments or 64

	-- color clamp like your other helpers
	local function c(v) return math.max(0, math.min(255, v)) end
	r, g, b, a = c(r), c(g), c(b), c(a)

	-- inscribed circle
	local cx = x + w * 0.5
	local cy = y + h * 0.5
	local outerR = math.max(0.0, math.min(w, h) * 0.5)
	local innerR = math.max(0.0, outerR - math.max(0.0, thickness))
	if innerR == 0 or innerR >= outerR then
		-- nothing to draw
		return nil, nil, 0, 0
	end

	-- we duplicate the first pair at the end to close the ring
	local vertCount = (segments + 1) * 2
	local idxCount  = segments * 6

	local vertices = ffi.new("Vertex[?]", vertCount)
	local indices  = ffi.new("uint16_t[?]", idxCount)

	for i = 0, segments do
		local t = (i / segments) * (math.pi * 2.0)
		local ct, st = math.cos(t), math.sin(t)

		local ox = cx + ct * outerR
		local oy = cy + st * outerR
		local ix = cx + ct * innerR
		local iy = cy + st * innerR

		-- keep UVs in a reasonable range for your white texture
		local uo, vo = 0.5 + 0.5 * ct, 0.5 + 0.5 * st
		local ui, vi = 0.5 + 0.5 * ct * (innerR/outerR), 0.5 + 0.5 * st * (innerR/outerR)

		local base = i * 2
		vertices[base + 0] = { ox, oy, uo, vo, r, g, b, a } -- outer
		vertices[base + 1] = { ix, iy, ui, vi, r, g, b, a } -- inner
	end

	-- triangles: (outer_i, inner_i, outer_i+1) and (inner_i, inner_i+1, outer_i+1)
	local k = 0
	for i = 0, segments - 1 do
		local v0 = i * 2
		local v1 = v0 + 1
		local v2 = v0 + 2
		local v3 = v0 + 3

		indices[k+0] = v0; indices[k+1] = v1; indices[k+2] = v2
		indices[k+3] = v1; indices[k+4] = v3; indices[k+5] = v2
		k = k + 6
	end

	return vertices, indices, vertCount, idxCount
end


local function init_bgfx()
	if not bgfx then
		return
	end
	
	print("init_bgfx")
	local bgfx_init_s = ffi.new("bgfx_init_t[1]")
	device.bgfx_init_s = bgfx_init_s
	
	bgfx.bgfx_init_ctor(bgfx_init_s)
	bgfx_init_s[0].type = ffi.os == "Windows" and bgfx.BGFX_RENDERER_TYPE_OPENGL or bgfx.BGFX_RENDERER_TYPE_COUNT
	bgfx_init_s[0].vendorId = bgfx.BGFX_PCI_ID_NONE
	bgfx_init_s[0].deviceId = 0
	bgfx_init_s[0].debug = false
	bgfx_init_s[0].profile = false
	bgfx_init_s[0].swapChain.width = device.width
	bgfx_init_s[0].swapChain.height = device.height
	bgfx_init_s[0].swapChain.flags = 0
	bgfx_init_s[0].swapChain.formatColor = bgfx.BGFX_TEXTURE_FORMAT_RGBA8
	device.bgfx_reset_flags = bgfx.BGFX_RESET_VSYNC
	bgfx_init_s[0].reset = device.bgfx_reset_flags

	-- RGFW supplies the native window and display handles BGFX needs.
	local nwh, ndt, handle_type = window.nativeHandles()
	bgfx_init_s[0].swapChain.nwh = nwh
	bgfx_init_s[0].swapChain.ndt = ndt
	bgfx_init_s[0].platformData.type = handle_type

	-- BGFX reset takes a pointer to the full swap-chain description in this API.
	-- Keep a stable copy so resize callbacks can update it and reset the backbuffer.
	device.bgfx_main_swap_chain_s = ffi.new("bgfx_swap_chain_t[1]")
	device.bgfx_main_swap_chain_s[0] = bgfx_init_s[0].swapChain

	-- Initialize bgfx
	bgfx.bgfx_init(bgfx_init_s[0])

	--bgfx.bgfx_set_debug(bgfx.BGFX_DEBUG_TEXT)

	local renderer = bgfx.bgfx_get_renderer_name(bgfx.bgfx_get_renderer_type())
	print("renderer:", renderer ~= nil and ffi.string(renderer) or "unknown")

	device.bgfx_main_swap_chain_s[0].width = device.width
	device.bgfx_main_swap_chain_s[0].height = device.height
	device.bgfx_main_swap_chain_s[0].flags = 0
	bgfx.bgfx_reset(device.bgfx_reset_flags, device.bgfx_main_swap_chain_s)
	bgfx.bgfx_set_view_rect(device.view_id, 0, 0, device.width, device.height, 0.0, 1.0)
	bgfx.bgfx_set_view_clear(device.view_id, bgfx.BGFX_CLEAR_COLOR + bgfx.BGFX_CLEAR_DEPTH, 0x336666ff, 1.0, 0)
	
	return true
end

-- Initialization
local function initialize()
	print("initializing")
	device.win = window.create({0, 0, device.width, device.height, false})
	device.width, device.height = window.framebufferSize()

	if not init_bgfx() then
		return
	end

	-- Initialize Clay with default memory
	if clay then
		print("init_clay")
		local minMemory = clay.minMemorySize()
		local ctx, mem = clay.initialize(minMemory, device.width, device.height)
		if ctx == nil then
			error("Failed to initialize Clay")
		end

		clay.setMeasureTextFunction(font_manager.measureText)
		retained_runtime.install(clay, device.width, device.height)
		clay._releaseRetainedPackets = releaseRetainedPackets
	end

	print("compiling and binding shaders")
	device.shader = shader_manager.load_clay_program(script_dir())

	device.vdecl = ffi.new("bgfx_vertex_layout_t[1]")
	bgfx.bgfx_vertex_layout_begin(device.vdecl, bgfx.bgfx_get_renderer_type())
	bgfx.bgfx_vertex_layout_add(device.vdecl, bgfx.BGFX_ATTRIB_POSITION, 2, bgfx.BGFX_ATTRIB_TYPE_FLOAT, false, false)
	bgfx.bgfx_vertex_layout_add(device.vdecl, bgfx.BGFX_ATTRIB_TEXCOORD0, 2, bgfx.BGFX_ATTRIB_TYPE_FLOAT, false, false)
	bgfx.bgfx_vertex_layout_add(device.vdecl, bgfx.BGFX_ATTRIB_COLOR0, 4, bgfx.BGFX_ATTRIB_TYPE_UINT8, true, false)
	bgfx.bgfx_vertex_layout_end(device.vdecl)
	device.vdecl_h = bgfx.bgfx_create_vertex_layout(device.vdecl)

	device.view = ffi.new("mat4_t"):identity()
	device.projection =
		ffi.new("mat4_t"):from_ortho(
		0,
		device.width,
		device.height,
		0,
		0,
		100,
		0,
		bgfx.bgfx_get_caps().homogeneousDepth,
		false
	)

	print("creating buffers")
	-- Create buffers
	local stride = ffi.sizeof("Vertex")
	device.maxVertexCount = 65536
	device.maxVertexBufferSize = stride * device.maxVertexCount
	device.maxElementCount = device.maxVertexCount * 2
	device.maxElementBufferSize = device.maxElementCount * ffi.sizeof("uint16_t")

	if not device.white_tex then
		local white = ffi.new("uint32_t[1]", 0xffffffff)
		local mem = bgfx.bgfx_copy(white, 4)
		device.white_tex = bgfx.bgfx_create_texture_2d(1, 1, false, 1, bgfx.BGFX_TEXTURE_FORMAT_RGBA8, 0, mem)
		device.s_texColor = bgfx.bgfx_create_uniform("s_texColor", bgfx.BGFX_UNIFORM_TYPE_SAMPLER, 1)
	end

	print("creating uniforms")
	-- Create shader uniform handles
	u_transform2D = bgfx.bgfx_create_uniform("u_transform2D", bgfx.BGFX_UNIFORM_TYPE_VEC4, 1)
	u_rcParams = bgfx.bgfx_create_uniform("u_rcParams", bgfx.BGFX_UNIFORM_TYPE_VEC4, 1)
	u_rcCorner = bgfx.bgfx_create_uniform("u_rcCorner", bgfx.BGFX_UNIFORM_TYPE_VEC4, 1)
	u_rcBorder = bgfx.bgfx_create_uniform("u_rcBorder", bgfx.BGFX_UNIFORM_TYPE_VEC4, 1)
	u_borderColor = bgfx.bgfx_create_uniform("u_borderColor", bgfx.BGFX_UNIFORM_TYPE_VEC4, 1)
	u_mode = bgfx.bgfx_create_uniform("u_mode", bgfx.BGFX_UNIFORM_TYPE_VEC4, 1)

	-- Set clay debug
	--clay.setDebugModeEnabled(true)

	print("setting window callbacks")
	-- Set callbacks
	window.callback_register(
		"mouse_scroll",
		function(delta_x, delta_y, x, y)
			device.scroll.x = delta_x
			device.scroll.y = delta_y
		end
	)

	local function wakeRetainedKeyboardWidgets()
		if clay and clay._invalidateRetainedKeyboardInput then
			clay._invalidateRetainedKeyboardInput()
		end
	end
	window.callback_register("window_set_key", wakeRetainedKeyboardWidgets)
	window.callback_register("window_set_char", wakeRetainedKeyboardWidgets)

	window.callback_register(
		"window_framebuffer_size",
		function(w, h)
			if w == 0 or h == 0 then
				return
			end -- ignore minimized window
			device.width = w
			device.height = h

			-- Reset BGFX to new size
			local swap_chain = device.bgfx_main_swap_chain_s
			swap_chain[0].width = w
			swap_chain[0].height = h
			swap_chain[0].flags = 0
			bgfx.bgfx_reset(device.bgfx_reset_flags, swap_chain)
			bgfx.bgfx_set_view_rect(device.view_id, 0, 0, w, h, 0.0, 1.0)

			-- Update Clay and projection matrix
			if clay then
				clay.setLayoutDimensions(w, h)
			end
			device.projection = ffi.new("mat4_t"):from_ortho(0, w, h, 0, 0, 100, 0, bgfx.bgfx_get_caps().homogeneousDepth, false)
		end
	)

	if clay then
		demo = loadScript("demo/body.lua")

		-- UI component extensions
		clay.scrollbar = loadScript("component/scrollbar.lua").scrollbar
		clay.checkbox = loadScript("component/checkbox.lua").checkbox
		clay.radio = loadScript("component/radio.lua").radio
		clay.edit = loadScript("component/edit.lua").edit
		clay.slider = loadScript("component/slider.lua").slider
		clay.property = loadScript("component/property.lua").property
		clay.resizable = loadScript("component/resizable.lua").resizable
		clay.color_picker = loadScript("component/color_picker.lua").color_picker
		clay.dropdown = loadScript("component/dropdown.lua").dropdown
		clay.inspector = loadScript("component/inspector.lua").inspector
		clay.asset_browser = loadScript("component/asset_browser.lua").asset_browser
		
		local M = loadScript("component/listview.lua")
		clay.listview = M.listview
		clay.treeview = M.treeview
        clay.listview_open = M.listview_open
		clay.listview_close = M.listview_close
        
        clay.tableview = loadScript("component/tableview.lua").tableview
		local node_editor = loadScript("component/node_editor.lua")
		clay.node_editor = node_editor.node_editor
		clay.node = node_editor.node
	end
end

local clipStack = {}

local function pushScissor(x, y, w, h)
	x, y = math.floor(x or 0), math.floor(y or 0)
	w, h = math.max(0, math.floor(w or 0)), math.max(0, math.floor(h or 0))
	local x1, y1 = math.min(device.width, x + w), math.min(device.height, y + h)
	x, y = math.min(device.width, math.max(0, x)), math.min(device.height, math.max(0, y))
	local parent = clipStack[#clipStack]
	if parent then
		x, y = math.max(x, parent.x), math.max(y, parent.y)
		x1, y1 = math.min(x1, parent.x + parent.w), math.min(y1, parent.y + parent.h)
	end
	w, h = math.max(0, x1 - x), math.max(0, y1 - y)
	table.insert(clipStack, {x = x, y = y, w = w, h = h})
	bgfx.bgfx_set_scissor(x, y, w, h)
end

local function popScissor()
	clipStack[#clipStack] = nil
	local top = clipStack[#clipStack]
	if top then
		bgfx.bgfx_set_scissor(top.x, top.y, top.w, top.h)
	else
		-- disable scissor
		bgfx.bgfx_set_scissor(0, 0, 0, 0)
	end
end

local function applyTopScissor()
	local top = clipStack[#clipStack]
	if top then
		bgfx.bgfx_set_scissor(top.x, top.y, top.w, top.h)
	end
end

-- Render a graph's grid and all its wires with one transient-buffer submit.
local function drawNodeEditorCanvas(x, y, w, h, payload)
	local wires = payload.wires or {}
	local pending = payload.pending
	local selectionRect = payload.selectionRect
	local zoom = tonumber(payload.zoom) or 1
	local gridStep = math.max(12, (tonumber(payload.gridSize) or 32) * zoom)
	local gridSegments = math.ceil(w / gridStep) + math.ceil(h / gridStep) + 2
	local wireSegments = (#wires + (pending and 1 or 0)) * 16
	local selectionSegments = selectionRect and 4 or 0
	local segmentCapacity = math.min(16000, gridSegments + wireSegments + selectionSegments)
	if segmentCapacity < 1 then return end

	local vertexCapacity, indexCapacity = segmentCapacity * 4, segmentCapacity * 6
	local availVertices = bgfx.bgfx_get_avail_transient_vertex_buffer(vertexCapacity, device.vdecl)
	local availIndices = bgfx.bgfx_get_avail_transient_index_buffer(indexCapacity, false)
	segmentCapacity = math.min(segmentCapacity, math.floor(availVertices / 4), math.floor(availIndices / 6))
	if segmentCapacity < 1 then return end

	vertexCapacity, indexCapacity = segmentCapacity * 4, segmentCapacity * 6
	local tvb, tib = ffi.new("bgfx_transient_vertex_buffer_t[1]"), ffi.new("bgfx_transient_index_buffer_t[1]")
	tib[0].isIndex16 = true
	bgfx.bgfx_alloc_transient_vertex_buffer(tvb, vertexCapacity, device.vdecl)
	bgfx.bgfx_alloc_transient_index_buffer(tib, indexCapacity, false)
	local vertices = ffi.cast("Vertex*", tvb[0].data)
	local indices = ffi.cast("uint16_t*", tib[0].data)
	local vertexCount, indexCount, segmentCount = 0, 0, 0
	local normalSegmentCapacity = selectionRect and segmentCapacity >= 4 and segmentCapacity - 4 or segmentCapacity
	local selectionPass = false

	local function emitSegment(x0, y0, x1, y1, width, color)
		local limit = selectionPass and segmentCapacity or normalSegmentCapacity
		if segmentCount >= limit then return false end
		local dx, dy = x1 - x0, y1 - y0
		local length = math.sqrt(dx * dx + dy * dy)
		if length < 0.001 then return true end
		local half = (width or 1) * 0.5
		local nx, ny = -dy / length * half, dx / length * half
		local r = math.max(0, math.min(255, color.r or 255))
		local g = math.max(0, math.min(255, color.g or 255))
		local b = math.max(0, math.min(255, color.b or 255))
		local a = math.max(0, math.min(255, color.a or 255))
		local v = vertexCount
		vertices[v + 0] = { x + x0 + nx, y + y0 + ny, 0.5, 0.5, r, g, b, a }
		vertices[v + 1] = { x + x0 - nx, y + y0 - ny, 0.5, 0.5, r, g, b, a }
		vertices[v + 2] = { x + x1 - nx, y + y1 - ny, 0.5, 0.5, r, g, b, a }
		vertices[v + 3] = { x + x1 + nx, y + y1 + ny, 0.5, 0.5, r, g, b, a }
		indices[indexCount + 0] = v + 0
		indices[indexCount + 1] = v + 1
		indices[indexCount + 2] = v + 2
		indices[indexCount + 3] = v + 0
		indices[indexCount + 4] = v + 2
		indices[indexCount + 5] = v + 3
		vertexCount, indexCount, segmentCount = vertexCount + 4, indexCount + 6, segmentCount + 1
		return true
	end

	local gridColor = payload.gridColor or { r=86, g=103, b=132, a=46 }
	local gridX = (payload.panX or 0) % gridStep
	local gridY = (payload.panY or 0) % gridStep
	while gridX < w and segmentCount < segmentCapacity do
		emitSegment(gridX, 0, gridX, h, 1, gridColor)
		gridX = gridX + gridStep
	end
	while gridY < h and segmentCount < segmentCapacity do
		emitSegment(0, gridY, w, gridY, 1, gridColor)
		gridY = gridY + gridStep
	end

	local function emitCurve(edge)
		local x0, y0, x1, y1 = edge.x0, edge.y0, edge.x1, edge.y1
		local bend = math.max(28 * zoom, math.abs(x1 - x0) * 0.48)
		local direction = x1 >= x0 and 1 or -1
		local c1x, c1y = x0 + bend * direction, y0
		local c2x, c2y = x1 - bend * direction, y1
		local lastX, lastY = x0, y0
		local color = edge.color or { r=180, g=191, b=211, a=235 }
		for step = 1, 16 do
			local t = step / 16
			local inv = 1 - t
			local px = inv * inv * inv * x0 + 3 * inv * inv * t * c1x + 3 * inv * t * t * c2x + t * t * t * x1
			local py = inv * inv * inv * y0 + 3 * inv * inv * t * c1y + 3 * inv * t * t * c2y + t * t * t * y1
			if not emitSegment(lastX, lastY, px, py, edge.width or 2.2 * zoom, color) then return false end
			lastX, lastY = px, py
		end
		return true
	end

	for i = 1, #wires do
		if not emitCurve(wires[i]) then break end
	end
	if pending and segmentCount < segmentCapacity then emitCurve(pending) end
	if selectionRect and segmentCapacity - segmentCount >= 4 then
		selectionPass = true
		local x0, y0 = selectionRect.x, selectionRect.y
		local x1, y1 = x0 + selectionRect.w, y0 + selectionRect.h
		local color, lineWidth = selectionRect.color, selectionRect.width or 1.5
		emitSegment(x0, y0, x1, y0, lineWidth, color)
		emitSegment(x1, y0, x1, y1, lineWidth, color)
		emitSegment(x1, y1, x0, y1, lineWidth, color)
		emitSegment(x0, y1, x0, y0, lineWidth, color)
	end
	if indexCount == 0 then return end

	bgfx.bgfx_set_transient_vertex_buffer(0, tvb, 0, vertexCount)
	bgfx.bgfx_set_transient_index_buffer(tib, 0, indexCount)
	bgfx.bgfx_set_texture(0, device.s_texColor, device.white_tex, 0xffffffff)
	setUniform4(u_transform2D, 1, 1, 0, 0)
	setUniform4(u_rcBorder, 0, 0, 0, 0)
	setUniform4(u_rcCorner, 0, 0, 0, 0)
	setUniform4(u_rcParams, 0, 0, 0, 0)
	setUniform4(u_borderColor, 0, 0, 0, 0)
	local state = bit.bor(bgfx.BGFX_STATE_WRITE_RGB, bgfx.BGFX_STATE_WRITE_A,
		bgfx.BGFX_STATE_BLEND_ALPHA, bgfx.BGFX_STATE_MSAA)
	bgfx.bgfx_set_state(state, 0)
	applyTopScissor()
	bgfx.bgfx_submit(device.view_id, device.shader, 0, bgfx.BGFX_DISCARD_ALL)
end

-- Main loop
local function mainLoop()
	local lastTime = window.time()
	while not window.shouldClose() do
		local currentTime = window.time()
		local dt = currentTime - lastTime
		lastTime = currentTime

		window.update(dt)

		if demo then
			demo.layout(dt)
		end
		
		device.scroll.x = 0
		device.scroll.y = 0

		-- Sets view and projection matrix for view_id
		if bgfx then
			bgfx.bgfx_set_view_transform(device.view_id, device.view, device.projection)

			bgfx.bgfx_touch(device.view_id)

			if clay then
				
				for t, x, y, w, h, r, g, b, a, tl, tr, bl, br, left, right, top, bottom,
						text, fontId, fontSize, letterSpacing, lineHeight, payload, clipH, clipV, renderPacket
						in clay.endLayoutFast(dt) do

					-- Safe defaults before any bgfx_submit()
					setUniform4(u_rcBorder, 0, 0, 0, 0)
					setUniform4(u_borderColor, 1, 1, 1, 1)
					setUniform4(u_rcCorner, 0, 0, 0, 0)
					setUniform4(u_rcParams, 0, 0, 0, 0)

					if t == clay.RENDER_RECTANGLE then
						-- Convention: if all 4 radii are negative, draw an *inscribed circle*.
						local drawCircle = (tl < 0 and tr < 0 and bl < 0 and br < 0)

						local shape = retainedGeometry(renderPacket, "shape", function()
							local vertices, indices, vertCount, idxCount
							if drawCircle then
								vertices, indices, vertCount, idxCount = generateCircleVertices(x, y, w, h, r, g, b, a, 48)
							else
								vertices, indices = generateRectangleVertices(x, y, w, h, r, g, b, a)
								vertCount, idxCount = 4, 6
							end
							return { vertices = vertices, indices = indices, vertCount = vertCount, idxCount = idxCount }
						end)
						local vertices, indices = shape.vertices, shape.indices
						local vertCount, idxCount = shape.vertCount, shape.idxCount

						if not bindGeometry(renderPacket, shape) then
							print("Warning: Not enough transient buffer space")
						else
							bgfx.bgfx_set_texture(0, device.s_texColor, device.white_tex, 0xffffffff)
							setUniform4(u_transform2D, 1, 1, 0, 0)

							local feather = 1.25
							local invW = (w > 0) and (1.0 / w) or 0.0
							local invH = (h > 0) and (1.0 / h) or 0.0

							setUniform4(u_rcBorder, 0, 0, 0, 0)
							setUniform4(u_borderColor, r / 255, g / 255, b / 255, a / 255)
							setUniform4(u_rcCorner, tl, tr, br, bl)
							setUniform4(u_rcParams, feather, invW, invH, 0.0)

							local state =
								bit.bor(
								bgfx.BGFX_STATE_WRITE_RGB,
								bgfx.BGFX_STATE_WRITE_A,
								bgfx.BGFX_STATE_BLEND_ALPHA,
								bgfx.BGFX_STATE_MSAA
							)
							bgfx.bgfx_set_state(state, 0)
							applyTopScissor()
							bgfx.bgfx_submit(device.view_id, device.shader, 0, bgfx.BGFX_DISCARD_ALL)
						end
					elseif t == clay.RENDER_BORDER then
						local circle = (tl < 0 and tr < 0 and bl < 0 and br < 0)

						if circle and left > 0 then
							local ring = retainedGeometry(renderPacket, "ring", function()
								local vertices, indices, vertCount, idxCount = generateRingVertices(x, y, w, h, left, r, g, b, a, 64)
								return { vertices = vertices, indices = indices, vertCount = vertCount, idxCount = idxCount }
							end)
							local vertices, indices, vertCount, idxCount = ring.vertices, ring.indices, ring.vertCount, ring.idxCount
							if vertices ~= nil then
								if bindGeometry(renderPacket, ring) then
									bgfx.bgfx_set_texture(0, device.s_texColor, device.white_tex, 0xffffffff)

									-- neutralize rounded-rect shader path — we’re drawing raw geometry
									setUniform4(u_transform2D, 1,1,0,0)
									setUniform4(u_rcBorder, 0,0,0,0)
									setUniform4(u_rcCorner, 0,0,0,0)
									setUniform4(u_rcParams, 0,0,0,0)
									setUniform4(u_borderColor, r/255, g/255, b/255, a/255)

									local state = bit.bor(
										bgfx.BGFX_STATE_WRITE_RGB,
										bgfx.BGFX_STATE_WRITE_A,
										bgfx.BGFX_STATE_BLEND_ALPHA,
										bgfx.BGFX_STATE_MSAA
									)
									bgfx.bgfx_set_state(state, 0)
									applyTopScissor()
									bgfx.bgfx_submit(device.view_id, device.shader, 0, bgfx.BGFX_DISCARD_ALL)
								end
							end

						else
							local hasRounded = (tl > 0) or (tr > 0) or (bl > 0) or (br > 0)
							local feather = 1.25
							local invW = (w > 0) and (1.0 / w) or 0.0
							local invH = (h > 0) and (1.0 / h) or 0.0

							local shape = retainedGeometry(renderPacket, "borderShape", function()
								local vertices, indices = generateRectangleVertices(x, y, w, h, r, g, b, a)
								return { vertices = vertices, indices = indices, vertCount = 4, idxCount = 6 }
							end)
							local vertices, indices = shape.vertices, shape.indices
							local vertCount, idxCount = shape.vertCount, shape.idxCount

							if not bindGeometry(renderPacket, shape) then
								print("Warning: Not enough transient buffer space")
							else
								bgfx.bgfx_set_texture(0, device.s_texColor, device.white_tex, 0xffffffff)

								setUniform4(u_rcCorner, tl, tr, br, bl)
								setUniform4(u_rcBorder, left, right, top, bottom)
								setUniform4(u_borderColor, r / 255, g / 255, b / 255, a / 255)

								local modeVal = hasRounded and 1.0 or 2.0
								setUniform4(u_rcParams, feather, invW, invH, modeVal)

								local state =
									bit.bor(
									bgfx.BGFX_STATE_WRITE_RGB,
									bgfx.BGFX_STATE_WRITE_A,
									bgfx.BGFX_STATE_BLEND_ALPHA,
									bgfx.BGFX_STATE_MSAA
								)
								bgfx.bgfx_set_state(state, 0)
								applyTopScissor()
								bgfx.bgfx_submit(device.view_id, device.shader, 0, bgfx.BGFX_DISCARD_ALL)
							end
						end
					elseif t == clay.RENDER_TEXT then
						if text and #text > 0 then
							local textGeometry = retainedGeometry(renderPacket, "text", function()
								local font = font_manager.load(fontId, fontSize)
								if not font then return { font = false, batches = {}, decorations = {} } end
								local vertices, indices, vertCount, idxCount, decorations, textBatches =
									font_manager.generateTextVertices(font, text, x, y, r, g, b, a)
								local batches = textBatches
								if not batches or #batches == 0 then
									batches = {{ vertices = vertices, indices = indices, vertCount = vertCount,
										idxCount = idxCount, texture = font.texture }}
								end
								return { font = font_manager.retain(font), batches = batches, decorations = decorations or {} }
							end)
							local font = textGeometry.font
							local batches = textGeometry.batches
							local decorations = textGeometry.decorations
							if font then

								for _, batch in ipairs(batches) do
									if batch.vertCount > 0 and batch.idxCount > 0 then
										if not bindGeometry(renderPacket, batch) then
											print("Warning: Not enough transient buffer space for text")
										else
											bgfx.bgfx_set_texture(0, device.s_texColor, batch.texture or font.texture, 0xffffffff)
											setUniform4(u_transform2D, 1, 1, 0, 0)
											local state = bit.bor(
												bgfx.BGFX_STATE_WRITE_RGB,
												bgfx.BGFX_STATE_WRITE_A,
												bgfx.BGFX_STATE_MSAA,
												bgfx.BGFX_STATE_BLEND_FUNC_SEPARATE(
													bgfx.BGFX_STATE_BLEND_ONE,
													bgfx.BGFX_STATE_BLEND_INV_SRC_ALPHA,
													bgfx.BGFX_STATE_BLEND_ONE,
													bgfx.BGFX_STATE_BLEND_INV_SRC_ALPHA))
											bgfx.bgfx_set_state(state, 0)
											applyTopScissor()
											bgfx.bgfx_submit(device.view_id, device.shader, 0, bgfx.BGFX_DISCARD_ALL)
										end
									end
								end

								if decorations and #decorations > 0 then
									local decorationGeometry = retainedGeometry(renderPacket, "decorations", function()
										local vertexCount, indexCount = 4 * #decorations, 6 * #decorations
										local vertices = ffi.new("Vertex[?]", vertexCount)
										local indices = ffi.new("uint16_t[?]", indexCount)
										local vertexBase, indexOffset = 0, 0
										for _, decoration in ipairs(decorations) do
											local quad, quadIndices = generateRectangleVertices(decoration.x1,
												decoration.y - decoration.h * 0.5, decoration.x2 - decoration.x1,
												decoration.h, decoration.color.r, decoration.color.g,
												decoration.color.b, decoration.color.a)
											ffi.copy(vertices + vertexBase, quad, ffi.sizeof("Vertex") * 4)
											for i = 0, 5 do indices[indexOffset + i] = quadIndices[i] + vertexBase end
											vertexBase, indexOffset = vertexBase + 4, indexOffset + 6
										end
										return { vertices = vertices, indices = indices, vertCount = vertexCount, idxCount = indexCount }
									end)
									if bindGeometry(renderPacket, decorationGeometry) then
										bgfx.bgfx_set_texture(0, device.s_texColor, device.white_tex, 0xffffffff)
										setUniform4(u_transform2D, 1, 1, 0, 0)
										setUniform4(u_rcBorder, 0, 0, 0, 0)
										setUniform4(u_rcCorner, 0, 0, 0, 0)
										setUniform4(u_rcParams, 0, 0, 0, 0)
										setUniform4(u_borderColor, 0, 0, 0, 0)
										local state = bit.bor(
											bgfx.BGFX_STATE_WRITE_RGB,
											bgfx.BGFX_STATE_WRITE_A,
											bgfx.BGFX_STATE_BLEND_ALPHA,
											bgfx.BGFX_STATE_MSAA)
										bgfx.bgfx_set_state(state, 0)
										applyTopScissor()
										bgfx.bgfx_submit(device.view_id, device.shader, 0, bgfx.BGFX_DISCARD_ALL)
									end
								end
							end
						end
					elseif t == clay.RENDER_IMAGE then
						local imageGeometry = retainedGeometry(renderPacket, "image", function()
							local vertices, indices = generateRectangleVertices(x, y, w, h, 255, 255, 255, 255)
							return { vertices = vertices, indices = indices, vertCount = 4, idxCount = 6 }
						end)
						if not bindGeometry(renderPacket, imageGeometry) then
							print("Warning: Not enough transient buffer space")
						else
							local textureHandle = payload and ffi.new("bgfx_texture_handle_t", payload) or device.white_tex
							bgfx.bgfx_set_texture(0, device.s_texColor, textureHandle, 0xffffffff)
							setUniform4(u_transform2D, 1, 1, 0, 0)
							bgfx.bgfx_set_state(bgfx.BGFX_STATE_WRITE_RGB + bgfx.BGFX_STATE_BLEND_ALPHA, 0)
							applyTopScissor()
							bgfx.bgfx_submit(device.view_id, device.shader, 0, bgfx.BGFX_DISCARD_ALL)
						end
					elseif t == clay.RENDER_SCISSOR_START then
						if not clipH then
							x, w = 0, device.width
						end
						if not clipV then
							y, h = 0, device.height
						end
						pushScissor(x, y, w, h)
					elseif t == clay.RENDER_SCISSOR_END then
						popScissor()
					elseif t == clay.RENDER_CUSTOM then
						if type(payload) == "table" and payload.kind == "clay_node_editor_canvas" then
							drawNodeEditorCanvas(x, y, w, h, payload)
						end
						applyTopScissor()
					end
				end
			end
			bgfx.bgfx_frame(false)
		else
			print("No rendering backend")
		end
	end
end

local function cleanup()
	local INVALID = 0xffff

	if font_manager and font_manager.shutdown then
		font_manager.shutdown()
	end

	local function destroy_uniform(handle)
		if handle ~= nil and handle.idx ~= INVALID then
			bgfx.bgfx_destroy_uniform(handle)
		end
	end

	local function destroy_texture(handle)
		if handle ~= nil and handle.idx ~= INVALID then
			bgfx.bgfx_destroy_texture(handle)
		end
	end

	local function destroy_program(handle)
		if handle ~= nil and handle.idx ~= INVALID then
			bgfx.bgfx_destroy_program(handle)
		end
	end

	if device then
		destroy_program(device.shader)
		device.shader = nil

		if device.vdecl_h ~= nil and device.vdecl_h.idx ~= INVALID then
			bgfx.bgfx_destroy_vertex_layout(device.vdecl_h)
		end
		device.vdecl_h = nil

		destroy_texture(device.white_tex)
		device.white_tex = nil

		destroy_uniform(device.s_texColor)
		device.s_texColor = nil
	end

	destroy_uniform(u_transform2D)
	destroy_uniform(u_rcParams)
	destroy_uniform(u_rcCorner)
	destroy_uniform(u_rcBorder)
	destroy_uniform(u_borderColor)
	destroy_uniform(u_mode)

	u_transform2D = nil
	u_rcParams = nil
	u_rcCorner = nil
	u_rcBorder = nil
	u_borderColor = nil
	u_mode = nil

	if clay then
		clay.shutdown()
	end
	if bgfx then
		bgfx.bgfx_shutdown()
	end
	window.destroy()
end

initialize()
mainLoop()
cleanup()
