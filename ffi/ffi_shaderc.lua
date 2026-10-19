local ffi = require("ffi")
local ffi_tryload = require("ffi.ffi_loader").tryload
require("ffi.ffi_bgfx") -- defines the fixed-width integer types used below

ffi.cdef([[
enum
{
    BGFX_SHADERC_RESULT_INVALID_ARGUMENT = -1,
    BGFX_SHADERC_RESULT_ERROR            = 0,
    BGFX_SHADERC_RESULT_SUCCESS          = 1,
};

typedef struct bgfx_shaderc_buffer
{
    uint8_t* data;
    uint32_t size;
} bgfx_shaderc_buffer;

typedef struct bgfx_shaderc_string_list
{
    const char** data;   // 'const char* const*' in C; pointer constness is irrelevant here
    uint32_t     count;
} bgfx_shaderc_string_list;

typedef struct bgfx_shaderc_compile_options
{
    char        shader_type;
    const char* platform;
    const char* profile;
    const char* input_path;
    const char* output_path;

    bgfx_shaderc_string_list include_dirs;
    bgfx_shaderc_string_list defines;
    bgfx_shaderc_string_list dependencies;

    unsigned char disasm;
    unsigned char raw;
    unsigned char preprocess_only;
    unsigned char depends;

    unsigned char debug_information;

    unsigned char avoid_flow_control;
    unsigned char no_preshader;
    unsigned char partial_precision;
    unsigned char prefer_flow_control;
    unsigned char backwards_compatibility;
    unsigned char warnings_are_errors;
    unsigned char keep_intermediate;

    unsigned char     optimize;
    uint32_t optimization_level;
} bgfx_shaderc_compile_options;

int bgfx_shaderc_compile(
      const bgfx_shaderc_compile_options* _options
    , const char* _shader_source
    , uint32_t _shader_size
    , const char* _varying_source
    , uint32_t _varying_size
    , bgfx_shaderc_buffer* _output
    , bgfx_shaderc_buffer* _messages
    );

void bgfx_shaderc_free_buffer(bgfx_shaderc_buffer* _buffer);
]])

local C = ffi_tryload("shaderc_sharedRelease")
return C
