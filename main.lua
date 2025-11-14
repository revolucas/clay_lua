ffi = require("ffi")

if ffi.os == "Windows" then
	package.cpath = "./bin/x64/?.dll;" .. package.cpath

	-- Set DLL directory (necessary for ffi.load)
	ffi.cdef[[
		int __stdcall SetDllDirectoryA(const char* lpPathName);
	]]

	ffi.C.SetDllDirectoryA("bin/x64")
elseif ffi.os == "Linux" then
	package.cpath = "./bin/linux64/?.so;" .. package.cpath
end

clay = require("clay") -- global make project-wide
bgfx = require("ffi.ffi_bgfx") -- global make project-wide
glfw = require("ffi.ffi_glfw") -- global make project-wide

local stbrt = require("ffi.ffi_stb_rect_pack")
local stbtt = require("ffi.ffi_stb_truetype")
local stbi = require("ffi.ffi_stb_image")

local window = require("window")
local font_manager = require("font_manager")

require("ffi.ffi_math")

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

-- Color palette
COLOR_NONE = { r = 0, g = 0, b = 0, a = 0 }
COLOR_WHITE = {r = 255, g = 255, b = 255, a = 255}
COLOR_WHITE_24 = {r = 255, g = 255, b = 255, a = 24}
COLOR_WHITE_32 = {r = 255, g = 255, b = 255, a = 32}
COLOR_WHITE_45 = {r = 255, g = 255, b = 255, a = 45}

COLOR_HEADER_BG = {r = 35, g = 56, b = 90, a = 255}
COLOR_ROOT_BG = {r = 50, g = 80, b = 120, a = 255}
COLOR_CONTENT_BG = {r = 30, g = 46, b = 75, a = 255}

COLOR_SIDEBAR_BG_BASE = {r = 60, g = 78, b = 110, a = 255}
COLOR_SIDEBAR_BG_HOV = {r = 85, g = 105, b = 150, a = 255}
COLOR_SIDEBAR_BG_ACT = {r = 40, g = 60, b = 95, a = 255}

-- Shader uniforms
u_transform2D = nil
u_rcParams = nil
u_rcCorner = nil
u_rcBorder = nil
u_borderColor = nil
u_mode = nil

mouse_x = ffi.new("double[1]")
mouse_y = ffi.new("double[1]")

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

local function create_shader_from_file(filename)
	local file = io.open(filename, "rb")

	assert(file, filename .. "not found")

	local source = file:read("*a")
	file:close()

	local mem = bgfx.bgfx_copy(ffi.cast("char *", source), #source)
	local shader = bgfx.bgfx_create_shader(mem)
	if (shader == nil) then
		print("failed to create shader " .. filename)
		return
	end

	return shader
end

-- Load BGFX shader
local function load_shader(vs_path, fs_path)
	local vs = create_shader_from_file(vs_path)
	local fs = create_shader_from_file(fs_path)
	if vs == nil or fs == nil then
		error("Shader load failed")
	end
	local program = bgfx.bgfx_create_program(vs, fs, true)
	return program
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
	bgfx_init_s[0].resolution.width = device.width
	bgfx_init_s[0].resolution.height = device.height
	bgfx_init_s[0].resolution.reset = bgfx.BGFX_RESET_VSYNC
	bgfx_init_s[0].resolution.format = bgfx.BGFX_TEXTURE_FORMAT_RGBA8

	-- Retrieve platform data
	if (ffi.os == "Windows") then
		local nwh = ffi.cast("void*", glfw.GetWin32Window(device.win))
		bgfx_init_s[0].platformData.nwh = nwh
	elseif (ffi.os == "OSX") then
		local nwh = ffi.cast("void*", glfw.GetCocoaWindow(device.win))
		bgfx_init_s[0].platformData.nwh = nwh
	elseif (ffi.os == "Linux") then
		local nwh = ffi.cast("void *", glfw.GetX11Window(device.win))
		local ndt = ffi.cast("void *", glfw.GetX11Display())
		bgfx_init_s[0].platformData.nwh = nwh
		bgfx_init_s[0].platformData.ndt = ndt
	else
		error("Unsupported platform: " .. ffi.os)
	end

	-- Initialize bgfx
	bgfx.bgfx_init(bgfx_init_s[0])

	--bgfx.bgfx_set_debug(bgfx.BGFX_DEBUG_TEXT)

	local renderer = bgfx.bgfx_get_renderer_name(bgfx.bgfx_get_renderer_type())
	print("renderer:", renderer ~= nil and ffi.string(renderer) or "unknown")

	local video_flags = 0
	bgfx.bgfx_reset(device.width, device.height, video_flags, bgfx_init_s[0].resolution.format)
	bgfx.bgfx_set_view_rect(device.view_id, 0, 0, device.width, device.height)
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
	end

	print("binding shaders")
	-- If windows use opengl if linux use vulkan
	local vs_shader = "shader/spriv/clay.vs.bin"
	local fs_shader = "shader/spriv/clay.fs.bin"
	
	if ffi.os == "Windows" then
		vs_shader = "shader/glsl/clay.vs.bin"
		fs_shader = "shader/glsl/clay.fs.bin"	
	end
	
	device.shader = load_shader(vs_shader, fs_shader)

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
			device.scroll.x = y
			device.scroll.y = y
		end
	)

	window.callback_register(
		"window_framebuffer_size",
		function(w, h)
			if w == 0 or h == 0 then
				return
			end -- ignore minimized window
			device.width = w
			device.height = h

			-- Reset BGFX to new size
			local format = bgfx.BGFX_TEXTURE_FORMAT_RGBA8
			bgfx.bgfx_reset(w, h, bgfx.BGFX_RESET_VSYNC, format)
			bgfx.bgfx_set_view_rect(device.view_id, 0, 0, w, h)

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
		
		local M = loadScript("component/listview.lua")
		clay.listview = M.listview
		clay.listview_open = M.listview_open
		clay.listview_close = M.listview_close
        
        clay.tableview = loadScript("component/tableview.lua").tableview
	end
end

local clipStack = {}

local function pushScissor(x, y, w, h)
	-- TODO: Clamp to view size if needed.
	x = math.max(0, math.floor(x or 0))
	y = math.max(0, math.floor(y or 0))
	w = math.max(0, math.floor(w or 0))
	h = math.max(0, math.floor(h or 0))
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

-- Main loop
local function mainLoop()
	local lastTime = window.time()
	while not window.shouldClose() do
		local currentTime = glfw.GetTime()
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
				
				local vertexStride = ffi.sizeof("Vertex")
				for cmd in clay.endLayoutIter() do
					local t = cmd:type()

					-- Safe defaults before any bgfx_submit()
					bgfx.bgfx_set_uniform(u_rcBorder, ffi.new("float[4]", 0, 0, 0, 0), 1)
					bgfx.bgfx_set_uniform(u_borderColor, ffi.new("float[4]", 1, 1, 1, 1), 1)
					bgfx.bgfx_set_uniform(u_rcCorner, ffi.new("float[4]", 0, 0, 0, 0), 1)
					bgfx.bgfx_set_uniform(u_rcParams, ffi.new("float[4]", 0, 0, 0, 0), 1)

					if t == clay.RENDER_RECTANGLE then
						local x, y, w, h = cmd:bounds()
						local r, g, b, a = cmd:color()
						local tl, tr, bl, br = cmd:cornerRadius()

						-- Convention: if all 4 radii are negative, draw an *inscribed circle*.
						local drawCircle = (tl < 0 and tr < 0 and bl < 0 and br < 0)

						local vertices, indices, vertCount, idxCount
						if drawCircle then
							vertices, indices, vertCount, idxCount = generateCircleVertices(x, y, w, h, r, g, b, a, 48)
						else
							vertices, indices = generateRectangleVertices(x, y, w, h, r, g, b, a)
							vertCount, idxCount = 4, 6
						end

						local tvb = ffi.new("bgfx_transient_vertex_buffer_t[1]")
						local tib = ffi.new("bgfx_transient_index_buffer_t[1]")
						tib[0].isIndex16 = true

						if bgfx.bgfx_get_avail_transient_vertex_buffer(vertCount, device.vdecl) < vertCount then
							print("Warning: Not enough transient buffer space")
						else
							bgfx.bgfx_alloc_transient_vertex_buffer(tvb, vertCount, device.vdecl)
							bgfx.bgfx_alloc_transient_index_buffer(tib, idxCount, false)

							ffi.copy(tvb[0].data, vertices, vertexStride * vertCount)
							ffi.copy(tib[0].data, indices, ffi.sizeof("uint16_t") * idxCount)

							bgfx.bgfx_set_transient_vertex_buffer(0, tvb, 0, vertCount)
							bgfx.bgfx_set_transient_index_buffer(tib, 0, idxCount)
							bgfx.bgfx_set_texture(0, device.s_texColor, device.white_tex, 0xffffffff)
							bgfx.bgfx_set_uniform(u_transform2D, ffi.new("float[4]", 1, 1, 0, 0), 1)

							local feather = 1.25
							local invW = (w > 0) and (1.0 / w) or 0.0
							local invH = (h > 0) and (1.0 / h) or 0.0

							bgfx.bgfx_set_uniform(u_rcBorder, ffi.new("float[4]", 0, 0, 0, 0), 1)
							bgfx.bgfx_set_uniform(u_borderColor, ffi.new("float[4]", r / 255, g / 255, b / 255, a / 255), 1)
							bgfx.bgfx_set_uniform(u_rcCorner, ffi.new("float[4]", tl, tr, br, bl), 1)
							bgfx.bgfx_set_uniform(u_rcParams, ffi.new("float[4]", feather, invW, invH, 0.0), 1)

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
						local x, y, w, h = cmd:bounds()
						local r, g, b, a = cmd:color()

						local left, right, top, bottom = cmd:borderWidth()
						local tl, tr, bl, br = cmd:cornerRadius()

						local circle = (tl < 0 and tr < 0 and bl < 0 and br < 0)

						if circle and left > 0 then
							local vertices, indices, vertCount, idxCount = generateRingVertices(x, y, w, h, left, r, g, b, a, 64)
							if vertices ~= nil then
								local tvb = ffi.new("bgfx_transient_vertex_buffer_t[1]")
								local tib = ffi.new("bgfx_transient_index_buffer_t[1]")
								tib[0].isIndex16 = true

								if bgfx.bgfx_get_avail_transient_vertex_buffer(vertCount, device.vdecl) >= vertCount
								   and bgfx.bgfx_get_avail_transient_index_buffer(idxCount, true) >= idxCount then

									bgfx.bgfx_alloc_transient_vertex_buffer(tvb, vertCount, device.vdecl)
									bgfx.bgfx_alloc_transient_index_buffer(tib, idxCount, false)

									ffi.copy(tvb[0].data, vertices, vertexStride * vertCount)
									ffi.copy(tib[0].data, indices, ffi.sizeof("uint16_t") * idxCount)

									bgfx.bgfx_set_transient_vertex_buffer(0, tvb, 0, vertCount)
									bgfx.bgfx_set_transient_index_buffer(tib, 0, idxCount)
									bgfx.bgfx_set_texture(0, device.s_texColor, device.white_tex, 0xffffffff)

									-- neutralize rounded-rect shader path — we’re drawing raw geometry
									bgfx.bgfx_set_uniform(u_transform2D, ffi.new("float[4]", 1,1,0,0), 1)
									bgfx.bgfx_set_uniform(u_rcBorder,    ffi.new("float[4]", 0,0,0,0), 1)
									bgfx.bgfx_set_uniform(u_rcCorner,    ffi.new("float[4]", 0,0,0,0), 1)
									bgfx.bgfx_set_uniform(u_rcParams,    ffi.new("float[4]", 0,0,0,0), 1)
									bgfx.bgfx_set_uniform(u_borderColor, ffi.new("float[4]", r/255, g/255, b/255, a/255), 1)

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

							local vertices, indices = generateRectangleVertices(x, y, w, h, r, g, b, a)
							local vertCount, idxCount = 4, 6

							local tvb = ffi.new("bgfx_transient_vertex_buffer_t[1]")
							local tib = ffi.new("bgfx_transient_index_buffer_t[1]")
							tib[0].isIndex16 = true

							if bgfx.bgfx_get_avail_transient_vertex_buffer(vertCount, device.vdecl) < vertCount then
								print("Warning: Not enough transient buffer space")
							else
								bgfx.bgfx_alloc_transient_vertex_buffer(tvb, vertCount, device.vdecl)
								bgfx.bgfx_alloc_transient_index_buffer(tib, idxCount, false)

								ffi.copy(tvb[0].data, vertices, vertexStride * vertCount)
								ffi.copy(tib[0].data, indices, ffi.sizeof("uint16_t") * idxCount)

								bgfx.bgfx_set_transient_vertex_buffer(0, tvb, 0, vertCount)
								bgfx.bgfx_set_transient_index_buffer(tib, 0, idxCount)
								bgfx.bgfx_set_texture(0, device.s_texColor, device.white_tex, 0xffffffff)

								bgfx.bgfx_set_uniform(u_rcCorner, ffi.new("float[4]", tl, tr, br, bl), 1)
								bgfx.bgfx_set_uniform(u_rcBorder, ffi.new("float[4]", left, right, top, bottom), 1)
								bgfx.bgfx_set_uniform(u_borderColor, ffi.new("float[4]", r / 255, g / 255, b / 255, a / 255), 1)

								local modeVal = hasRounded and 1.0 or 2.0
								bgfx.bgfx_set_uniform(u_rcParams, ffi.new("float[4]", feather, invW, invH, modeVal), 1)

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
						local text, fontId, fontSize, letterSpacing, lineHeight = cmd:text()
						local r, g, b, a = cmd:color()
						local x, y = cmd:bounds()

						local font = font_manager.load(fontId, fontSize)
						if text and #text > 0 and font then
							local vertices, indices, vertCount, idxCount, decorations = font_manager.generateTextVertices(font, text, x, y, r, g, b, a)

							local tvb = ffi.new("bgfx_transient_vertex_buffer_t[1]")
							local tib = ffi.new("bgfx_transient_index_buffer_t[1]")
							tib[0].isIndex16 = true

							if bgfx.bgfx_get_avail_transient_vertex_buffer(vertCount, device.vdecl) < vertCount then
								print("Warning: Not enough transient buffer space")
							else
								bgfx.bgfx_alloc_transient_vertex_buffer(tvb, vertCount, device.vdecl)
								bgfx.bgfx_alloc_transient_index_buffer(tib, idxCount, false)

								ffi.copy(tvb[0].data, vertices, vertexStride * vertCount)
								ffi.copy(tib[0].data, indices, ffi.sizeof("uint16_t") * idxCount)

								bgfx.bgfx_set_transient_vertex_buffer(0, tvb, 0, vertCount)
								bgfx.bgfx_set_transient_index_buffer(tib, 0, idxCount)
								bgfx.bgfx_set_texture(0, device.s_texColor, font.texture, 0xffffffff)
								bgfx.bgfx_set_uniform(u_transform2D, ffi.new("float[4]", 1, 1, 0, 0), 1)

								local state =
									bit.bor(
									bgfx.BGFX_STATE_WRITE_RGB,
									bgfx.BGFX_STATE_WRITE_A,
									bgfx.BGFX_STATE_MSAA,
									bgfx.BGFX_STATE_BLEND_FUNC_SEPARATE(
										bgfx.BGFX_STATE_BLEND_ONE,
										bgfx.BGFX_STATE_BLEND_INV_SRC_ALPHA,
										bgfx.BGFX_STATE_BLEND_ONE,
										bgfx.BGFX_STATE_BLEND_INV_SRC_ALPHA
									)
								)
								bgfx.bgfx_set_state(state, 0)
								applyTopScissor()
								bgfx.bgfx_submit(device.view_id, device.shader, 0, bgfx.BGFX_DISCARD_ALL)
							end
							
							if decorations and #decorations > 0 then
								local totalV, totalI = 4 * #decorations, 6 * #decorations
								local tvb = ffi.new("bgfx_transient_vertex_buffer_t[1]")
								local tib = ffi.new("bgfx_transient_index_buffer_t[1]")
								tib[0].isIndex16 = true

								if  bgfx.bgfx_get_avail_transient_vertex_buffer(totalV, device.vdecl) >= totalV
								and bgfx.bgfx_get_avail_transient_index_buffer(totalI, true) >= totalI then
									bgfx.bgfx_alloc_transient_vertex_buffer(tvb, totalV, device.vdecl)
									bgfx.bgfx_alloc_transient_index_buffer(tib, totalI, false)

									local vptr = ffi.cast("uint8_t*", tvb[0].data)
									local iptr = ffi.cast("uint16_t*", tib[0].data)
									local vstride = ffi.sizeof("Vertex")
									local vbase = 0
									local iofs  = 0

									for _, d in ipairs(decorations) do
										local vtx, idx = generateRectangleVertices(d.x1, d.y - d.h*0.5, (d.x2 - d.x1), d.h,
																				   d.color.r, d.color.g, d.color.b, d.color.a)
										-- copy 4 verts
										ffi.copy(vptr + vbase * vstride, vtx, vstride * 4)
										-- copy 6 indices with base offset
										iptr[iofs + 0] = vbase + 0
										iptr[iofs + 1] = vbase + 1
										iptr[iofs + 2] = vbase + 2
										iptr[iofs + 3] = vbase + 0
										iptr[iofs + 4] = vbase + 2
										iptr[iofs + 5] = vbase + 3
										vbase = vbase + 4
										iofs  = iofs + 6
									end

									bgfx.bgfx_set_transient_vertex_buffer(0, tvb, 0, totalV)
									bgfx.bgfx_set_transient_index_buffer(tib, 0, totalI)
									bgfx.bgfx_set_texture(0, device.s_texColor, device.white_tex, 0xffffffff)

									bgfx.bgfx_set_uniform(u_transform2D, ffi.new("float[4]", 1,1,0,0), 1)
									bgfx.bgfx_set_uniform(u_rcBorder,    ffi.new("float[4]", 0,0,0,0), 1)
									bgfx.bgfx_set_uniform(u_rcCorner,    ffi.new("float[4]", 0,0,0,0), 1)
									bgfx.bgfx_set_uniform(u_rcParams,    ffi.new("float[4]", 0,0,0,0), 1)
									bgfx.bgfx_set_uniform(u_borderColor, ffi.new("float[4]", 0,0,0,0), 1)

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
						end
					elseif t == clay.RENDER_IMAGE then
						local r, g, b, a = cmd:color()
						local tl, tr, bl, br = cmd:cornerRadius()
						local idx = cmd:imageData()

						local x, y, w, h = cmd:bounds()
						local vertices, indices = generateRectangleVertices(x, y, w, h, 255, 255, 255, 255)
						local vertCount = 4
						local idxCount = 6

						local tvb = ffi.new("bgfx_transient_vertex_buffer_t[1]")
						local tib = ffi.new("bgfx_transient_index_buffer_t[1]")
						tib[0].isIndex16 = true

						if bgfx.bgfx_get_avail_transient_vertex_buffer(vertCount, device.vdecl) < vertCount then
							print("Warning: Not enough transient buffer space")
						else
							bgfx.bgfx_alloc_transient_vertex_buffer(tvb, vertCount, device.vdecl)
							bgfx.bgfx_alloc_transient_index_buffer(tib, idxCount, false)

							ffi.copy(tvb[0].data, vertices, vertexStride * vertCount)
							ffi.copy(tib[0].data, indices, ffi.sizeof("uint16_t") * idxCount)

							bgfx.bgfx_set_transient_vertex_buffer(0, tvb, 0, vertCount)
							bgfx.bgfx_set_transient_index_buffer(tib, 0, idxCount)
							
							local tex_h = idx and ffi.new("bgfx_texture_handle_t",idx) or device.white_tex
							bgfx.bgfx_set_texture(0, device.s_texColor, tex_h, 0xffffffff)
							bgfx.bgfx_set_uniform(u_transform2D, ffi.new("float[4]", 1, 1, 0, 0), 1)
						
							bgfx.bgfx_set_state(bgfx.BGFX_STATE_WRITE_RGB + bgfx.BGFX_STATE_BLEND_ALPHA, 0)
							applyTopScissor()
							bgfx.bgfx_submit(device.view_id, device.shader, 0, bgfx.BGFX_DISCARD_ALL)
						end
					elseif t == clay.RENDER_SCISSOR_START then
						local x, y, w, h = cmd:bounds()
						local clipH, clipV = cmd:clip()
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
						local r, g, b, a = cmd:color()
						local tl, tr, bl, br = cmd:cornerRadius()
						local passthrough = cmd:customData()
					
						applyTopScissor()
						bgfx.bgfx_submit(device.view_id, device.shader, 0, bgfx.BGFX_DISCARD_ALL)
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
