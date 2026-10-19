local ffi = require("ffi")
local bgfx = require("ffi.ffi_bgfx")
local shaderc = require("ffi.ffi_shaderc")

local M = {}

local CACHE_REVISION = "bgfx" .. tostring(bgfx.BGFX_API_VERSION) .. "-shaderc3"
local SHADERC_SUCCESS = 1
local INVALID_HANDLE = 0xffff

local renderer_profiles = {
    [bgfx.BGFX_RENDERER_TYPE_OPENGL] = {
        key = "glsl",
        profile = "330",
    },
    [bgfx.BGFX_RENDERER_TYPE_OPENGLES] = {
        key = "essl",
        profile = "300_es",
    },
    [bgfx.BGFX_RENDERER_TYPE_DIRECT3D11] = {
        key = "dx11",
        profile = "s_5_0",
    },
    [bgfx.BGFX_RENDERER_TYPE_DIRECT3D12] = {
        key = "dx11",
        profile = "s_5_0",
    },
    [bgfx.BGFX_RENDERER_TYPE_METAL] = {
        key = "metal",
        profile = "metal",
    },
    [bgfx.BGFX_RENDERER_TYPE_VULKAN] = {
        key = "spirv",
        profile = "spirv",
    },
    [bgfx.BGFX_RENDERER_TYPE_NOOP] = {
        key = "glsl",
        profile = "330",
    },
}

local function join(root, path)
    return root:gsub("[/\\]+$", "") .. "/" .. path
end

local function read_file(path)
    local file = io.open(path, "rb")
    if not file then return nil end
    local data = file:read("*a")
    file:close()
    return data
end

local function write_file(path, data)
    local file, err = io.open(path, "wb")
    if not file then return false, err end
    local ok, write_err = file:write(data)
    file:close()
    if not ok then return false, write_err end
    return true
end

local function make_string_list(values)
    local count = #values
    local array = ffi.new("const char*[?]", math.max(count, 1))
    for i, value in ipairs(values) do
        array[i - 1] = value
    end

    local list = ffi.new("bgfx_shaderc_string_list")
    list.data = count > 0 and array or nil
    list.count = count
    return list, array
end

local function copy_shaderc_buffer(buffer)
    if buffer[0].data == nil or buffer[0].size == 0 then
        return nil
    end
    return ffi.string(buffer[0].data, tonumber(buffer[0].size))
end

local function compile_to_string(stage, platform, profile, input_path, output_path,
        include_dirs, source, varying_source, debug_information)
    local options = ffi.new("bgfx_shaderc_compile_options[1]")
    options[0].shader_type = string.byte(stage)
    options[0].platform = platform
    options[0].profile = profile
    options[0].input_path = input_path
    options[0].output_path = output_path

    local include_list, include_array = make_string_list(include_dirs)
    options[0].include_dirs = include_list
    options[0].defines.data = nil
    options[0].defines.count = 0
    options[0].dependencies.data = nil
    options[0].dependencies.count = 0

    options[0].disasm = 0
    options[0].raw = 0
    options[0].preprocess_only = 0
    options[0].depends = 0
    options[0].debug_information = debug_information and 1 or 0
    options[0].avoid_flow_control = 0
    options[0].no_preshader = 0
    options[0].partial_precision = 0
    options[0].prefer_flow_control = 0
    options[0].backwards_compatibility = 0
    options[0].warnings_are_errors = 0
    options[0].keep_intermediate = 0
    options[0].optimize = 1
    options[0].optimization_level = 3

    local output = ffi.new("bgfx_shaderc_buffer[1]")
    local messages = ffi.new("bgfx_shaderc_buffer[1]")
    local result = shaderc.bgfx_shaderc_compile(
        options,
        source, #source,
        varying_source, #varying_source,
        output,
        messages
    )

    local output_string = copy_shaderc_buffer(output)
    local message_string = copy_shaderc_buffer(messages)

    -- Shaderc can allocate diagnostic output on failed compilations too.
    if output[0].data ~= nil then
        shaderc.bgfx_shaderc_free_buffer(output)
    end
    if messages[0].data ~= nil then
        shaderc.bgfx_shaderc_free_buffer(messages)
    end

    if result ~= SHADERC_SUCCESS then
        error(("shaderc failed for %s (%d):\n%s")
            :format(input_path, tonumber(result), message_string or "no diagnostics"), 0)
    end
    if not output_string then
        error("shaderc returned no bytecode for " .. input_path, 0)
    end

    return output_string, message_string, include_array
end

local function cache_paths(root, runtime_dir, renderer_key, stage)
    local base = table.concat({
        "clay", stage, CACHE_REVISION, renderer_key,
    }, ".")
    local directory = join(root, "bin/" .. runtime_dir)
    return join(directory, base .. ".bin"), join(directory, base .. ".key")
end

local function compile_stage(root, stage, renderer, platform, runtime_dir)
    local profile = renderer_profiles[renderer]
    if not profile then
        error("no shader profile for active bgfx renderer " .. tostring(renderer), 0)
    end

    local stage_name = stage == "v" and "vertex" or "fragment"
    local source_suffix = stage == "v" and "vs" or "fs"
    local source_path = join(root, "shader/src/clay." .. source_suffix .. ".sc")
    local varying_path = join(root, "shader/src/varying.def.sc")
    local source = read_file(source_path)
    local varying_source = read_file(varying_path)
    if not source or not varying_source then
        error("missing Clay shader source or varying file under " .. join(root, "shader/src"), 0)
    end

    local include_names = {
        "common.sh",
        "shaderlib.sh",
        "bgfx_shader.sh",
        "bgfx_compute.sh",
    }
    local debug_information = os.getenv("CLAY_SHADER_DEBUG") == "1"
    local cache_inputs = {
        CACHE_REVISION,
        platform,
        profile.key,
        profile.profile,
        stage,
        debug_information and "debug" or "release",
        source,
        varying_source,
    }
    for _, name in ipairs(include_names) do
        local contents = read_file(join(root, "shader/include/" .. name))
        cache_inputs[#cache_inputs + 1] = name
        cache_inputs[#cache_inputs + 1] = contents or "<missing>"
    end
    local cache_key = table.concat(cache_inputs, "\0")

    local binary_path, key_path = cache_paths(root, runtime_dir, profile.key, stage_name)
    local cached_binary = read_file(binary_path)
    if cached_binary and read_file(key_path) == cache_key then
        return cached_binary
    end

    local include_dirs = {
        join(root, "shader/include"),
        join(root, "shader/src"),
    }
    local binary, diagnostics = compile_to_string(
        stage,
        platform,
        profile.profile,
        source_path,
        binary_path,
        include_dirs,
        source,
        varying_source,
        debug_information
    )

    local saved, save_error = write_file(binary_path, binary)
    if saved then
        local key_saved, key_error = write_file(key_path, cache_key)
        if not key_saved then
            print("[shaderc] could not save shader cache key:", key_error)
        end
    else
        print("[shaderc] could not save compiled shader:", save_error)
    end

    print("[shaderc] compiled", source_path, "for", profile.key)
    if diagnostics and diagnostics ~= "" then
        print(diagnostics)
    end
    return binary
end

local function valid_handle(handle)
    return handle ~= nil and handle.idx ~= nil and tonumber(handle.idx) ~= INVALID_HANDLE
end

local function create_shader(bytes, label)
    local memory = bgfx.bgfx_copy(ffi.cast("char *", bytes), #bytes)
    local handle = bgfx.bgfx_create_shader(memory)
    if not valid_handle(handle) then
        error("bgfx failed to create " .. label .. " shader", 0)
    end
    return handle
end

function M.load_clay_program(root)
    root = root or "."
    root = root:gsub("\\", "/"):gsub("/$", "")
    if root == "" then root = "." end

    local renderer = tonumber(bgfx.bgfx_get_renderer_type())
    local platform
    local runtime_dir
    if ffi.os == "Windows" then
        platform = "windows"
        runtime_dir = "x64"
    elseif ffi.os == "Linux" then
        platform = "linux"
        runtime_dir = "linux64"
    else
        error("runtime shader compilation is supported on Windows and Linux", 0)
    end

    local vertex = compile_stage(root, "v", renderer, platform, runtime_dir)
    local fragment = compile_stage(root, "f", renderer, platform, runtime_dir)
    local vertex_shader = create_shader(vertex, "vertex")
    local fragment_shader = create_shader(fragment, "fragment")
    local program = bgfx.bgfx_create_program(vertex_shader, fragment_shader, true)
    if not valid_handle(program) then
        error("bgfx failed to link the Clay shader program", 0)
    end
    return program
end

return M
