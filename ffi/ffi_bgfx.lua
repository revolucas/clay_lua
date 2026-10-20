local ffi = require("ffi")
local ok_bit, bit = pcall(require, "bit")
if not ok_bit then
    bit = {
        rshift = function(value, amount)
            return math.floor((tonumber(value) % 4294967296) / (2 ^ amount))
        end,
        lshift = function(value, amount)
            return (tonumber(value) * (2 ^ amount)) % 4294967296
        end,
    }
end
local ffi_tryload = require("ffi.ffi_loader").tryload
ffi.cdef([[
typedef enum bgfx_fatal
{
    BGFX_FATAL_DEBUG_CHECK,
    BGFX_FATAL_INVALID_SHADER,
    BGFX_FATAL_UNABLE_TO_INITIALIZE,
    BGFX_FATAL_UNABLE_TO_CREATE_TEXTURE,
    BGFX_FATAL_DEVICE_LOST,
    BGFX_FATAL_COUNT
} bgfx_fatal_t;
typedef enum bgfx_renderer_type
{
    BGFX_RENDERER_TYPE_NOOP,
    BGFX_RENDERER_TYPE_AGC,
    BGFX_RENDERER_TYPE_DIRECT3D11,
    BGFX_RENDERER_TYPE_DIRECT3D12,
    BGFX_RENDERER_TYPE_GNM,
    BGFX_RENDERER_TYPE_METAL,
    BGFX_RENDERER_TYPE_NVN,
    BGFX_RENDERER_TYPE_OPENGLES,
    BGFX_RENDERER_TYPE_OPENGL,
    BGFX_RENDERER_TYPE_VULKAN,
    BGFX_RENDERER_TYPE_WEBGPU,
    BGFX_RENDERER_TYPE_COUNT
} bgfx_renderer_type_t;
typedef enum bgfx_access
{
    BGFX_ACCESS_READ,
    BGFX_ACCESS_WRITE,
    BGFX_ACCESS_READWRITE,
    BGFX_ACCESS_COUNT
} bgfx_access_t;
typedef enum bgfx_attrib
{
    BGFX_ATTRIB_POSITION,
    BGFX_ATTRIB_NORMAL,
    BGFX_ATTRIB_TANGENT,
    BGFX_ATTRIB_BITANGENT,
    BGFX_ATTRIB_COLOR0,
    BGFX_ATTRIB_COLOR1,
    BGFX_ATTRIB_COLOR2,
    BGFX_ATTRIB_COLOR3,
    BGFX_ATTRIB_INDICES,
    BGFX_ATTRIB_WEIGHT,
    BGFX_ATTRIB_TEXCOORD0,
    BGFX_ATTRIB_TEXCOORD1,
    BGFX_ATTRIB_TEXCOORD2,
    BGFX_ATTRIB_TEXCOORD3,
    BGFX_ATTRIB_TEXCOORD4,
    BGFX_ATTRIB_TEXCOORD5,
    BGFX_ATTRIB_TEXCOORD6,
    BGFX_ATTRIB_TEXCOORD7,
    BGFX_ATTRIB_TEXCOORD8,
    BGFX_ATTRIB_TEXCOORD9,
    BGFX_ATTRIB_TEXCOORD10,
    BGFX_ATTRIB_TEXCOORD11,
    BGFX_ATTRIB_TEXCOORD12,
    BGFX_ATTRIB_TEXCOORD13,
    BGFX_ATTRIB_TEXCOORD14,
    BGFX_ATTRIB_TEXCOORD15,
    BGFX_ATTRIB_COUNT
} bgfx_attrib_t;
typedef enum bgfx_attrib_type
{
    BGFX_ATTRIB_TYPE_INT8,
    BGFX_ATTRIB_TYPE_UINT8,
    BGFX_ATTRIB_TYPE_UINT10,
    BGFX_ATTRIB_TYPE_INT16,
    BGFX_ATTRIB_TYPE_UINT16,
    BGFX_ATTRIB_TYPE_HALF,
    BGFX_ATTRIB_TYPE_FLOAT,
    BGFX_ATTRIB_TYPE_INT32,
    BGFX_ATTRIB_TYPE_UINT32,
    BGFX_ATTRIB_TYPE_COUNT
} bgfx_attrib_type_t;
typedef enum bgfx_texture_format
{
    BGFX_TEXTURE_FORMAT_BC1,
    BGFX_TEXTURE_FORMAT_BC2,
    BGFX_TEXTURE_FORMAT_BC3,
    BGFX_TEXTURE_FORMAT_BC4,
    BGFX_TEXTURE_FORMAT_BC4S,
    BGFX_TEXTURE_FORMAT_BC5,
    BGFX_TEXTURE_FORMAT_BC5S,
    BGFX_TEXTURE_FORMAT_BC6H,
    BGFX_TEXTURE_FORMAT_BC6HU,
    BGFX_TEXTURE_FORMAT_BC7,
    BGFX_TEXTURE_FORMAT_ETC1,
    BGFX_TEXTURE_FORMAT_ETC2,
    BGFX_TEXTURE_FORMAT_ETC2A,
    BGFX_TEXTURE_FORMAT_ETC2A1,
    BGFX_TEXTURE_FORMAT_EACR11,
    BGFX_TEXTURE_FORMAT_EACR11S,
    BGFX_TEXTURE_FORMAT_EACRG11,
    BGFX_TEXTURE_FORMAT_EACRG11S,
    BGFX_TEXTURE_FORMAT_PTC12,
    BGFX_TEXTURE_FORMAT_PTC14,
    BGFX_TEXTURE_FORMAT_PTC12A,
    BGFX_TEXTURE_FORMAT_PTC14A,
    BGFX_TEXTURE_FORMAT_PTC22,
    BGFX_TEXTURE_FORMAT_PTC24,
    BGFX_TEXTURE_FORMAT_ATC,
    BGFX_TEXTURE_FORMAT_ATCE,
    BGFX_TEXTURE_FORMAT_ATCI,
    BGFX_TEXTURE_FORMAT_ASTC4X4,
    BGFX_TEXTURE_FORMAT_ASTC5X4,
    BGFX_TEXTURE_FORMAT_ASTC5X5,
    BGFX_TEXTURE_FORMAT_ASTC6X5,
    BGFX_TEXTURE_FORMAT_ASTC6X6,
    BGFX_TEXTURE_FORMAT_ASTC8X5,
    BGFX_TEXTURE_FORMAT_ASTC8X6,
    BGFX_TEXTURE_FORMAT_ASTC8X8,
    BGFX_TEXTURE_FORMAT_ASTC10X5,
    BGFX_TEXTURE_FORMAT_ASTC10X6,
    BGFX_TEXTURE_FORMAT_ASTC10X8,
    BGFX_TEXTURE_FORMAT_ASTC10X10,
    BGFX_TEXTURE_FORMAT_ASTC12X10,
    BGFX_TEXTURE_FORMAT_ASTC12X12,
    BGFX_TEXTURE_FORMAT_UNKNOWN,
    BGFX_TEXTURE_FORMAT_R1,
    BGFX_TEXTURE_FORMAT_A8,
    BGFX_TEXTURE_FORMAT_R8,
    BGFX_TEXTURE_FORMAT_R8I,
    BGFX_TEXTURE_FORMAT_R8U,
    BGFX_TEXTURE_FORMAT_R8S,
    BGFX_TEXTURE_FORMAT_R16,
    BGFX_TEXTURE_FORMAT_R16I,
    BGFX_TEXTURE_FORMAT_R16U,
    BGFX_TEXTURE_FORMAT_R16F,
    BGFX_TEXTURE_FORMAT_R16S,
    BGFX_TEXTURE_FORMAT_R32I,
    BGFX_TEXTURE_FORMAT_R32U,
    BGFX_TEXTURE_FORMAT_R32F,
    BGFX_TEXTURE_FORMAT_RG8,
    BGFX_TEXTURE_FORMAT_RG8I,
    BGFX_TEXTURE_FORMAT_RG8U,
    BGFX_TEXTURE_FORMAT_RG8S,
    BGFX_TEXTURE_FORMAT_RG16,
    BGFX_TEXTURE_FORMAT_RG16I,
    BGFX_TEXTURE_FORMAT_RG16U,
    BGFX_TEXTURE_FORMAT_RG16F,
    BGFX_TEXTURE_FORMAT_RG16S,
    BGFX_TEXTURE_FORMAT_RG32I,
    BGFX_TEXTURE_FORMAT_RG32U,
    BGFX_TEXTURE_FORMAT_RG32F,
    BGFX_TEXTURE_FORMAT_RGB8,
    BGFX_TEXTURE_FORMAT_RGB8I,
    BGFX_TEXTURE_FORMAT_RGB8U,
    BGFX_TEXTURE_FORMAT_RGB8S,
    BGFX_TEXTURE_FORMAT_RGB9E5F,
    BGFX_TEXTURE_FORMAT_BGRA8,
    BGFX_TEXTURE_FORMAT_RGBA8,
    BGFX_TEXTURE_FORMAT_RGBA8I,
    BGFX_TEXTURE_FORMAT_RGBA8U,
    BGFX_TEXTURE_FORMAT_RGBA8S,
    BGFX_TEXTURE_FORMAT_RGBA16,
    BGFX_TEXTURE_FORMAT_RGBA16I,
    BGFX_TEXTURE_FORMAT_RGBA16U,
    BGFX_TEXTURE_FORMAT_RGBA16F,
    BGFX_TEXTURE_FORMAT_RGBA16S,
    BGFX_TEXTURE_FORMAT_RGBA32I,
    BGFX_TEXTURE_FORMAT_RGBA32U,
    BGFX_TEXTURE_FORMAT_RGBA32F,
    BGFX_TEXTURE_FORMAT_B5G6R5,
    BGFX_TEXTURE_FORMAT_R5G6B5,
    BGFX_TEXTURE_FORMAT_BGRA4,
    BGFX_TEXTURE_FORMAT_RGBA4,
    BGFX_TEXTURE_FORMAT_BGR5A1,
    BGFX_TEXTURE_FORMAT_RGB5A1,
    BGFX_TEXTURE_FORMAT_RGB10A2,
    BGFX_TEXTURE_FORMAT_RGB10A2U,
    BGFX_TEXTURE_FORMAT_RG11B10F,
    BGFX_TEXTURE_FORMAT_UNKNOWNDEPTH,
    BGFX_TEXTURE_FORMAT_D16,
    BGFX_TEXTURE_FORMAT_D24,
    BGFX_TEXTURE_FORMAT_D24S8,
    BGFX_TEXTURE_FORMAT_D32,
    BGFX_TEXTURE_FORMAT_D16F,
    BGFX_TEXTURE_FORMAT_D24F,
    BGFX_TEXTURE_FORMAT_D32F,
    BGFX_TEXTURE_FORMAT_D32FS8,
    BGFX_TEXTURE_FORMAT_D0S8,
    BGFX_TEXTURE_FORMAT_COUNT
} bgfx_texture_format_t;
typedef enum bgfx_uniform_type
{
    BGFX_UNIFORM_TYPE_SAMPLER,
    BGFX_UNIFORM_TYPE_END,
    BGFX_UNIFORM_TYPE_VEC4,
    BGFX_UNIFORM_TYPE_MAT3,
    BGFX_UNIFORM_TYPE_MAT4,
    BGFX_UNIFORM_TYPE_COUNT
} bgfx_uniform_type_t;
typedef enum bgfx_uniform_freq
{
    BGFX_UNIFORM_FREQ_DRAW,
    BGFX_UNIFORM_FREQ_VIEW,
    BGFX_UNIFORM_FREQ_FRAME,
    BGFX_UNIFORM_FREQ_COUNT
} bgfx_uniform_freq_t;
typedef enum bgfx_backbuffer_ratio
{
    BGFX_BACKBUFFER_RATIO_EQUAL,
    BGFX_BACKBUFFER_RATIO_HALF,
    BGFX_BACKBUFFER_RATIO_QUARTER,
    BGFX_BACKBUFFER_RATIO_EIGHTH,
    BGFX_BACKBUFFER_RATIO_SIXTEENTH,
    BGFX_BACKBUFFER_RATIO_DOUBLE,
    BGFX_BACKBUFFER_RATIO_COUNT
} bgfx_backbuffer_ratio_t;
typedef enum bgfx_occlusion_query_result
{
    BGFX_OCCLUSION_QUERY_RESULT_INVISIBLE,
    BGFX_OCCLUSION_QUERY_RESULT_VISIBLE,
    BGFX_OCCLUSION_QUERY_RESULT_NORESULT,
    BGFX_OCCLUSION_QUERY_RESULT_COUNT
} bgfx_occlusion_query_result_t;
typedef enum bgfx_video_codec
{
    BGFX_VIDEO_CODEC_H264,
    BGFX_VIDEO_CODEC_H265,
    BGFX_VIDEO_CODEC_AV1,
    BGFX_VIDEO_CODEC_COUNT
} bgfx_video_codec_t;
typedef enum bgfx_topology
{
    BGFX_TOPOLOGY_TRI_LIST,
    BGFX_TOPOLOGY_TRI_STRIP,
    BGFX_TOPOLOGY_LINE_LIST,
    BGFX_TOPOLOGY_LINE_STRIP,
    BGFX_TOPOLOGY_POINT_LIST,
    BGFX_TOPOLOGY_COUNT
} bgfx_topology_t;
typedef enum bgfx_topology_convert
{
    BGFX_TOPOLOGY_CONVERT_TRI_LIST_FLIP_WINDING,
    BGFX_TOPOLOGY_CONVERT_TRI_STRIP_FLIP_WINDING,
    BGFX_TOPOLOGY_CONVERT_TRI_LIST_TO_LINE_LIST,
    BGFX_TOPOLOGY_CONVERT_TRI_STRIP_TO_TRI_LIST,
    BGFX_TOPOLOGY_CONVERT_LINE_STRIP_TO_LINE_LIST,
    BGFX_TOPOLOGY_CONVERT_COUNT
} bgfx_topology_convert_t;
typedef enum bgfx_topology_sort
{
    BGFX_TOPOLOGY_SORT_DIRECTION_FRONT_TO_BACK_MIN,
    BGFX_TOPOLOGY_SORT_DIRECTION_FRONT_TO_BACK_AVG,
    BGFX_TOPOLOGY_SORT_DIRECTION_FRONT_TO_BACK_MAX,
    BGFX_TOPOLOGY_SORT_DIRECTION_BACK_TO_FRONT_MIN,
    BGFX_TOPOLOGY_SORT_DIRECTION_BACK_TO_FRONT_AVG,
    BGFX_TOPOLOGY_SORT_DIRECTION_BACK_TO_FRONT_MAX,
    BGFX_TOPOLOGY_SORT_DISTANCE_FRONT_TO_BACK_MIN,
    BGFX_TOPOLOGY_SORT_DISTANCE_FRONT_TO_BACK_AVG,
    BGFX_TOPOLOGY_SORT_DISTANCE_FRONT_TO_BACK_MAX,
    BGFX_TOPOLOGY_SORT_DISTANCE_BACK_TO_FRONT_MIN,
    BGFX_TOPOLOGY_SORT_DISTANCE_BACK_TO_FRONT_AVG,
    BGFX_TOPOLOGY_SORT_DISTANCE_BACK_TO_FRONT_MAX,
    BGFX_TOPOLOGY_SORT_COUNT
} bgfx_topology_sort_t;
typedef enum bgfx_view_mode
{
    BGFX_VIEW_MODE_DEFAULT,
    BGFX_VIEW_MODE_SEQUENTIAL,
    BGFX_VIEW_MODE_DEPTH_ASCENDING,
    BGFX_VIEW_MODE_DEPTH_DESCENDING,
    BGFX_VIEW_MODE_COUNT
} bgfx_view_mode_t;
typedef enum bgfx_shading_rate
{
    BGFX_SHADING_RATE_RATE_1X_1,
    BGFX_SHADING_RATE_RATE_1X_2,
    BGFX_SHADING_RATE_RATE_2X_1,
    BGFX_SHADING_RATE_RATE_2X_2,
    BGFX_SHADING_RATE_RATE_2X_4,
    BGFX_SHADING_RATE_RATE_4X_2,
    BGFX_SHADING_RATE_RATE_4X_4,
    BGFX_SHADING_RATE_COUNT
} bgfx_shading_rate_t;
typedef enum bgfx_native_window_handle_type
{
    BGFX_NATIVE_WINDOW_HANDLE_TYPE_DEFAULT,
    BGFX_NATIVE_WINDOW_HANDLE_TYPE_WAYLAND,
    BGFX_NATIVE_WINDOW_HANDLE_TYPE_COUNT
} bgfx_native_window_handle_type_t;
typedef enum bgfx_render_frame
{
    BGFX_RENDER_FRAME_NO_CONTEXT,
    BGFX_RENDER_FRAME_RENDER,
    BGFX_RENDER_FRAME_TIMEOUT,
    BGFX_RENDER_FRAME_EXITING,
    BGFX_RENDER_FRAME_COUNT
} bgfx_render_frame_t;
typedef uint16_t bgfx_view_id_t;
typedef struct bgfx_allocator_interface_s
{
    const struct bgfx_allocator_vtbl_s* vtbl;
} bgfx_allocator_interface_t;
typedef struct bgfx_allocator_vtbl_s
{
    void* (*realloc)(bgfx_allocator_interface_t* _this, void* _ptr, size_t _size, size_t _align, const char* _file, uint32_t _line);
} bgfx_allocator_vtbl_t;
typedef struct bgfx_interface_vtbl bgfx_interface_vtbl_t;
typedef struct bgfx_callback_interface_s
{
    const struct bgfx_callback_vtbl_s* vtbl;
} bgfx_callback_interface_t;
typedef struct bgfx_callback_vtbl_s
{
    void (*fatal)(bgfx_callback_interface_t* _this, const char* _filePath, uint16_t _line, bgfx_fatal_t _code, const char* _str);
    void (*trace_vargs)(bgfx_callback_interface_t* _this, const char* _filePath, uint16_t _line, const char* _format, va_list _argList);
    void (*profiler_begin)(bgfx_callback_interface_t* _this, const char* _name, uint32_t _abgr, const char* _filePath, uint16_t _line);
    void (*profiler_begin_literal)(bgfx_callback_interface_t* _this, const char* _name, uint32_t _abgr, const char* _filePath, uint16_t _line);
    void (*profiler_end)(bgfx_callback_interface_t* _this);
    uint32_t (*cache_read_size)(bgfx_callback_interface_t* _this, uint64_t _id);
    bool (*cache_read)(bgfx_callback_interface_t* _this, uint64_t _id, void* _data, uint32_t _size);
    void (*cache_write)(bgfx_callback_interface_t* _this, uint64_t _id, const void* _data, uint32_t _size);
    void (*screen_shot)(bgfx_callback_interface_t* _this, const char* _filePath, uint32_t _width, uint32_t _height, uint32_t _pitch, bgfx_texture_format_t _format, const void* _data, uint32_t _size, bool _yflip);
    void (*capture_begin)(bgfx_callback_interface_t* _this, uint32_t _width, uint32_t _height, uint32_t _pitch, bgfx_texture_format_t _format, bool _yflip);
    void (*capture_end)(bgfx_callback_interface_t* _this);
    void (*capture_frame)(bgfx_callback_interface_t* _this, const void* _data, uint32_t _size);
} bgfx_callback_vtbl_t;
typedef struct bgfx_dynamic_index_buffer_handle_s { uint16_t idx; } bgfx_dynamic_index_buffer_handle_t;
typedef struct bgfx_dynamic_vertex_buffer_handle_s { uint16_t idx; } bgfx_dynamic_vertex_buffer_handle_t;
typedef struct bgfx_frame_buffer_handle_s { uint16_t idx; } bgfx_frame_buffer_handle_t;
typedef struct bgfx_index_buffer_handle_s { uint16_t idx; } bgfx_index_buffer_handle_t;
typedef struct bgfx_indirect_buffer_handle_s { uint16_t idx; } bgfx_indirect_buffer_handle_t;
typedef struct bgfx_occlusion_query_handle_s { uint16_t idx; } bgfx_occlusion_query_handle_t;
typedef struct bgfx_program_handle_s { uint16_t idx; } bgfx_program_handle_t;
typedef struct bgfx_shader_handle_s { uint16_t idx; } bgfx_shader_handle_t;
typedef struct bgfx_texture_handle_s { uint16_t idx; } bgfx_texture_handle_t;
typedef struct bgfx_uniform_handle_s { uint16_t idx; } bgfx_uniform_handle_t;
typedef struct bgfx_vertex_buffer_handle_s { uint16_t idx; } bgfx_vertex_buffer_handle_t;
typedef struct bgfx_vertex_layout_handle_s { uint16_t idx; } bgfx_vertex_layout_handle_t;
typedef struct bgfx_buffer_handle_s { uint16_t idx; uint16_t type; } bgfx_buffer_handle_t;
typedef enum bgfx_buffer_handle_type
{
    BGFX_BUFFER_HANDLE_TYPE_DYNAMIC_INDEX_BUFFER,
    BGFX_BUFFER_HANDLE_TYPE_DYNAMIC_VERTEX_BUFFER,
    BGFX_BUFFER_HANDLE_TYPE_INDEX_BUFFER,
    BGFX_BUFFER_HANDLE_TYPE_INDIRECT_BUFFER,
    BGFX_BUFFER_HANDLE_TYPE_VERTEX_BUFFER,
    BGFX_BUFFER_HANDLE_TYPE_COUNT
} bgfx_buffer_handle_type_t;
typedef void (*bgfx_release_fn_t)(void* _ptr, void* _userData);
typedef struct bgfx_caps_gpu_s
{
    uint16_t             vendorId;
    uint16_t             deviceId;
} bgfx_caps_gpu_t;
typedef struct bgfx_caps_limits_s
{
    uint32_t             maxDrawCalls;
    uint32_t             maxBlits;
    uint32_t             maxTextureSize;
    uint32_t             maxTextureLayers;
    uint32_t             maxViews;
    uint32_t             maxFrameBuffers;
    uint32_t             maxFBAttachments;
    uint32_t             maxPrograms;
    uint32_t             maxShaders;
    uint32_t             maxTextures;
    uint32_t             maxTextureSamplers;
    uint32_t             maxComputeBindings;
    uint32_t             maxVertexLayouts;
    uint32_t             maxVertexStreams;
    uint32_t             maxVertexAttributes;
    uint32_t             maxInstanceData;
    uint32_t             maxIndexBuffers;
    uint32_t             maxVertexBuffers;
    uint32_t             maxDynamicIndexBuffers;
    uint32_t             maxDynamicVertexBuffers;
    uint32_t             maxUniforms;
    uint32_t             maxOcclusionQueries;
    uint32_t             maxEncoders;
    uint32_t             minResourceCbSize;
    uint32_t             maxTransientVbSize;
    uint32_t             maxTransientIbSize;
    uint32_t             minUniformBufferSize;
    uint32_t             minUniformCacheSize;
    uint32_t             blitRowPitchAlign;
    uint32_t             blitOffsetAlign;
} bgfx_caps_limits_t;
typedef struct bgfx_caps_s
{
    bgfx_renderer_type_t rendererType;
    uint64_t             supported;
    uint16_t             vendorId;
    uint16_t             deviceId;
    bool                 homogeneousDepth;
    bool                 originBottomLeft;
    uint8_t              numGPUs;
    bgfx_caps_gpu_t      gpu[4];
    bgfx_caps_limits_t   limits;
    uint32_t             formats[BGFX_TEXTURE_FORMAT_COUNT];
    uint32_t             codecs[BGFX_VIDEO_CODEC_COUNT];
} bgfx_caps_t;
typedef struct bgfx_internal_data_s
{
    const bgfx_caps_t*   caps;
    void*                context;
} bgfx_internal_data_t;
typedef struct bgfx_platform_data_s
{
    void*                context;
    void*                queue;
    bgfx_native_window_handle_type_t type;
} bgfx_platform_data_t;
typedef struct bgfx_swap_chain_s
{
    void*                nwh;
    void*                ndt;
    uint32_t             width;
    uint32_t             height;
    uint32_t             flags;
    bgfx_texture_format_t formatColor;
    bgfx_texture_format_t formatDepthStencil;
    bgfx_texture_handle_t depth;
    uint8_t              numBackBuffers;
    uint8_t              maxFrameLatency;
} bgfx_swap_chain_t;
typedef struct bgfx_init_limits_s
{
    uint16_t             maxEncoders;
    uint32_t             numDrawCalls;
    uint32_t             numDrawCallPeakFrames;
    uint32_t             minViews;
    uint32_t             minResourceCbSize;
    uint32_t             maxTransientVbSize;
    uint32_t             maxTransientIbSize;
    uint32_t             minUniformBufferSize;
    uint32_t             minUniformCacheSize;
} bgfx_init_limits_t;
typedef struct bgfx_init_s
{
    bgfx_renderer_type_t type;
    uint16_t             vendorId;
    uint16_t             deviceId;
    uint64_t             capabilities;
    bool                 debug;
    bool                 profile;
    bool                 fallback;
    bool                 videoDecode;
    bgfx_platform_data_t platformData;
    bgfx_swap_chain_t    swapChain;
    uint32_t             reset;
    bgfx_init_limits_t   limits;
    bgfx_callback_interface_t* callback;
    bgfx_allocator_interface_t* allocator;
} bgfx_init_t;
typedef struct bgfx_memory_s
{
    uint8_t*             data;
    uint32_t             size;
} bgfx_memory_t;
typedef struct bgfx_transient_index_buffer_s
{
    uint8_t*             data;
    uint32_t             size;
    uint32_t             startIndex;
    bgfx_index_buffer_handle_t handle;
    bool                 isIndex16;
} bgfx_transient_index_buffer_t;
typedef struct bgfx_transient_vertex_buffer_s
{
    uint8_t*             data;
    uint32_t             size;
    uint32_t             startVertex;
    uint16_t             stride;
    bgfx_vertex_buffer_handle_t handle;
    bgfx_vertex_layout_handle_t layoutHandle;
} bgfx_transient_vertex_buffer_t;
typedef struct bgfx_instance_data_buffer_s
{
    uint8_t*             data;
    uint32_t             size;
    uint32_t             offset;
    uint32_t             num;
    uint16_t             stride;
    bgfx_vertex_buffer_handle_t handle;
} bgfx_instance_data_buffer_t;
typedef struct bgfx_texture_region_s
{
    bgfx_texture_handle_t handle;
    uint8_t              mip;
    uint16_t             x;
    uint16_t             y;
    uint16_t             z;
    uint16_t             width;
    uint16_t             height;
    uint16_t             depth;
} bgfx_texture_region_t;
typedef struct bgfx_buffer_region_s
{
    bgfx_buffer_handle_t handle;
    uint32_t             offset;
    uint32_t             size;
    uint32_t             rowPitch;
    uint32_t             slicePitch;
} bgfx_buffer_region_t;
typedef struct bgfx_texture_info_s
{
    bgfx_texture_format_t format;
    uint32_t             storageSize;
    uint16_t             width;
    uint16_t             height;
    uint16_t             depth;
    uint16_t             numLayers;
    uint8_t              numMips;
    uint8_t              bitsPerPixel;
    bool                 cubeMap;
} bgfx_texture_info_t;
typedef struct bgfx_video_decoder_init_s
{
    uint32_t             magic;
    bgfx_video_codec_t   codec;
    const uint8_t*       parameterSets;
    uint32_t             parameterSetsSize;
    uint32_t             cachedAuBytes;
    uint8_t              flags;
} bgfx_video_decoder_init_t;
typedef struct bgfx_video_decoder_au_s
{
    uint32_t             size;
    int64_t              ptsUs;
} bgfx_video_decoder_au_t;
typedef struct bgfx_video_decoder_frame_s
{
    uint32_t             magic;
    const uint8_t*       bitstream;
    const bgfx_video_decoder_au_t* aus;
    uint32_t             numAus;
    int64_t              presentationTimeUs;
    uint8_t              flags;
} bgfx_video_decoder_frame_t;
typedef struct bgfx_uniform_info_s
{
    char                 name[256];
    bgfx_uniform_type_t  type;
    uint16_t             num;
} bgfx_uniform_info_t;
typedef struct bgfx_attachment_s
{
    bgfx_access_t        access;
    bgfx_texture_handle_t handle;
    uint16_t             mip;
    uint16_t             layer;
    uint16_t             numLayers;
    uint8_t              flags;
} bgfx_attachment_t;
typedef struct bgfx_transform_s
{
    float*               data;
    uint16_t             num;
} bgfx_transform_t;
typedef struct bgfx_view_stats_s
{
    char                 name[256];
    bgfx_view_id_t       view;
    int64_t              cpuTimeBegin;
    int64_t              cpuTimeEnd;
    int64_t              gpuTimeBegin;
    int64_t              gpuTimeEnd;
    uint32_t             gpuFrameNum;
} bgfx_view_stats_t;
typedef struct bgfx_encoder_stats_s
{
    int64_t              cpuTimeBegin;
    int64_t              cpuTimeEnd;
} bgfx_encoder_stats_t;
typedef struct bgfx_stats_s
{
    int64_t              cpuTimeFrame;
    int64_t              cpuTimeBegin;
    int64_t              cpuTimeEnd;
    int64_t              cpuTimerFreq;
    int64_t              gpuTimeBegin;
    int64_t              gpuTimeEnd;
    int64_t              gpuTimerFreq;
    int64_t              waitRender;
    int64_t              waitSubmit;
    int64_t              latencySleep;
    int64_t              latencyTotal;
    int64_t              latencySimulation;
    int64_t              latencyRenderSubmit;
    int64_t              latencyPresent;
    int64_t              latencyQueue;
    int64_t              latencyGpu;
    uint32_t             numDraw;
    uint32_t             numCompute;
    uint32_t             numBlit;
    uint32_t             numBlitRepack;
    uint32_t             numDrawCallsPeak;
    uint32_t             maxGpuLatency;
    uint32_t             gpuFrameNum;
    uint16_t             numDynamicIndexBuffers;
    uint16_t             numDynamicVertexBuffers;
    uint16_t             numFrameBuffers;
    uint16_t             numIndexBuffers;
    uint16_t             numOcclusionQueries;
    uint16_t             numPrograms;
    uint16_t             numShaders;
    uint16_t             numTextures;
    uint16_t             numUniforms;
    uint16_t             numVertexBuffers;
    uint16_t             numVertexLayouts;
    int64_t              textureMemoryUsed;
    int64_t              rtMemoryUsed;
    int32_t              transientVbUsed;
    int32_t              transientIbUsed;
    uint32_t             numPrims[BGFX_TOPOLOGY_COUNT];
    int64_t              gpuMemoryMax;
    int64_t              gpuMemoryUsed;
    uint16_t             width;
    uint16_t             height;
    uint16_t             textWidth;
    uint16_t             textHeight;
    uint16_t             numViews;
    bgfx_view_stats_t*   viewStats;
    uint8_t              numEncoders;
    bgfx_encoder_stats_t* encoderStats;
} bgfx_stats_t;
typedef struct bgfx_vertex_layout_s
{
    uint32_t             hash;
    uint16_t             stride;
    uint16_t             offset[BGFX_ATTRIB_COUNT];
    uint16_t             attributes[BGFX_ATTRIB_COUNT];
} bgfx_vertex_layout_t;
struct bgfx_encoder_s;
typedef struct bgfx_encoder_s bgfx_encoder_t;
void bgfx_texture_region_init(bgfx_texture_region_t* _this, bgfx_texture_handle_t _handle, uint16_t _x, uint16_t _y, uint16_t _width, uint16_t _height);
void bgfx_buffer_region_init_texture(bgfx_buffer_region_t* _this, const bgfx_texture_region_t * _texture);
void bgfx_buffer_region_init_buffer(bgfx_buffer_region_t* _this, bgfx_buffer_handle_t _handle, uint32_t _offset, uint32_t _size);
void bgfx_attachment_init(bgfx_attachment_t* _this, bgfx_texture_handle_t _handle, bgfx_access_t _access, uint16_t _layer, uint16_t _numLayers, uint16_t _mip, uint8_t _flags);
bgfx_vertex_layout_t* bgfx_vertex_layout_begin(bgfx_vertex_layout_t* _this, bgfx_renderer_type_t _rendererType);
bgfx_vertex_layout_t* bgfx_vertex_layout_add(bgfx_vertex_layout_t* _this, bgfx_attrib_t _attrib, uint8_t _num, bgfx_attrib_type_t _type, bool _normalized, bool _asInt);
void bgfx_vertex_layout_decode(const bgfx_vertex_layout_t* _this, bgfx_attrib_t _attrib, uint8_t * _num, bgfx_attrib_type_t * _type, bool * _normalized, bool * _asInt);
bool bgfx_vertex_layout_has(const bgfx_vertex_layout_t* _this, bgfx_attrib_t _attrib);
bgfx_vertex_layout_t* bgfx_vertex_layout_skip(bgfx_vertex_layout_t* _this, uint8_t _num);
void bgfx_vertex_layout_end(bgfx_vertex_layout_t* _this);
uint16_t bgfx_vertex_layout_get_offset(const bgfx_vertex_layout_t* _this, bgfx_attrib_t _attrib);
uint16_t bgfx_vertex_layout_get_stride(const bgfx_vertex_layout_t* _this);
uint32_t bgfx_vertex_layout_get_size(const bgfx_vertex_layout_t* _this, uint32_t _num);
void bgfx_vertex_pack(const float _input[4], bool _inputNormalized, bgfx_attrib_t _attr, const bgfx_vertex_layout_t * _layout, void* _data, uint32_t _index);
void bgfx_vertex_unpack(float _output[4], bgfx_attrib_t _attr, const bgfx_vertex_layout_t * _layout, const void* _data, uint32_t _index);
void bgfx_vertex_convert(const bgfx_vertex_layout_t * _dstLayout, void* _dstData, const bgfx_vertex_layout_t * _srcLayout, const void* _srcData, uint32_t _num);
uint32_t bgfx_topology_convert(bgfx_topology_convert_t _conversion, void* _dst, uint32_t _dstSize, const void* _indices, uint32_t _numIndices, bool _index32);
void bgfx_topology_sort_tri_list(bgfx_topology_sort_t _sort, void* _dst, uint32_t _dstSize, const float _dir[3], const float _pos[3], const void* _vertices, uint32_t _stride, const void* _indices, uint32_t _numIndices, bool _index32);
uint8_t bgfx_get_supported_renderers(uint8_t _max, bgfx_renderer_type_t* _enum);
const char* bgfx_get_renderer_name(bgfx_renderer_type_t _type);
void bgfx_init_ctor(bgfx_init_t* _init);
bool bgfx_init(const bgfx_init_t * _init);
void bgfx_shutdown(void);
void bgfx_reset(uint32_t _flags, const bgfx_swap_chain_t* _swapChain);
uint32_t bgfx_frame(uint8_t _flags);
bgfx_renderer_type_t bgfx_get_renderer_type(void);
const bgfx_caps_t* bgfx_get_caps(void);
const bgfx_stats_t* bgfx_get_stats(void);
const bgfx_memory_t* bgfx_alloc(uint32_t _size);
const bgfx_memory_t* bgfx_copy(const void* _data, uint32_t _size);
const bgfx_memory_t* bgfx_make_ref(const void* _data, uint32_t _size);
const bgfx_memory_t* bgfx_make_ref_release(const void* _data, uint32_t _size, bgfx_release_fn_t _releaseFn, void* _userData);
void bgfx_set_debug(uint32_t _debug, bgfx_frame_buffer_handle_t _handle, uint8_t _scale);
void bgfx_dbg_text_clear(uint8_t _attr, bool _small);
void bgfx_dbg_text_printf(uint16_t _x, uint16_t _y, uint8_t _attr, const char* _format, ... );
void bgfx_dbg_text_vprintf(uint16_t _x, uint16_t _y, uint8_t _attr, const char* _format, va_list _argList);
void bgfx_dbg_text_image(uint16_t _x, uint16_t _y, uint16_t _width, uint16_t _height, const void* _data, uint16_t _pitch);
bgfx_index_buffer_handle_t bgfx_create_index_buffer(const bgfx_memory_t* _mem, uint16_t _flags);
uint32_t bgfx_read_buffer(const bgfx_buffer_region_t * _src, void* _data);
void bgfx_set_index_buffer_name(bgfx_index_buffer_handle_t _handle, const char* _name, int32_t _len);
void bgfx_destroy_index_buffer(bgfx_index_buffer_handle_t _handle);
bgfx_vertex_layout_handle_t bgfx_create_vertex_layout(const bgfx_vertex_layout_t * _layout);
void bgfx_destroy_vertex_layout(bgfx_vertex_layout_handle_t _layoutHandle);
bgfx_vertex_buffer_handle_t bgfx_create_vertex_buffer(const bgfx_memory_t* _mem, const bgfx_vertex_layout_t * _layout, uint16_t _flags);
void bgfx_set_vertex_buffer_name(bgfx_vertex_buffer_handle_t _handle, const char* _name, int32_t _len);
void bgfx_destroy_vertex_buffer(bgfx_vertex_buffer_handle_t _handle);
bgfx_dynamic_index_buffer_handle_t bgfx_create_dynamic_index_buffer(uint32_t _num, uint16_t _flags);
bgfx_dynamic_index_buffer_handle_t bgfx_create_dynamic_index_buffer_mem(const bgfx_memory_t* _mem, uint16_t _flags);
void bgfx_update_dynamic_index_buffer(bgfx_dynamic_index_buffer_handle_t _handle, uint32_t _startIndex, const bgfx_memory_t* _mem);
void bgfx_destroy_dynamic_index_buffer(bgfx_dynamic_index_buffer_handle_t _handle);
bgfx_dynamic_vertex_buffer_handle_t bgfx_create_dynamic_vertex_buffer(uint32_t _num, const bgfx_vertex_layout_t* _layout, uint16_t _flags);
bgfx_dynamic_vertex_buffer_handle_t bgfx_create_dynamic_vertex_buffer_mem(const bgfx_memory_t* _mem, const bgfx_vertex_layout_t* _layout, uint16_t _flags);
void bgfx_update_dynamic_vertex_buffer(bgfx_dynamic_vertex_buffer_handle_t _handle, uint32_t _startVertex, const bgfx_memory_t* _mem);
void bgfx_destroy_dynamic_vertex_buffer(bgfx_dynamic_vertex_buffer_handle_t _handle);
uint32_t bgfx_get_avail_transient_index_buffer(uint32_t _num, bool _index32);
uint32_t bgfx_get_avail_transient_vertex_buffer(uint32_t _num, const bgfx_vertex_layout_t * _layout);
uint32_t bgfx_get_avail_instance_data_buffer(uint32_t _num, uint16_t _stride);
void bgfx_alloc_transient_index_buffer(bgfx_transient_index_buffer_t* _tib, uint32_t _num, bool _index32);
void bgfx_alloc_transient_vertex_buffer(bgfx_transient_vertex_buffer_t* _tvb, uint32_t _num, const bgfx_vertex_layout_t * _layout);
bool bgfx_alloc_transient_buffers(bgfx_transient_vertex_buffer_t* _tvb, const bgfx_vertex_layout_t * _layout, uint32_t _numVertices, bgfx_transient_index_buffer_t* _tib, uint32_t _numIndices, bool _index32);
void bgfx_alloc_instance_data_buffer(bgfx_instance_data_buffer_t* _idb, uint32_t _num, uint16_t _stride);
bgfx_indirect_buffer_handle_t bgfx_create_indirect_buffer(uint32_t _num);
void bgfx_destroy_indirect_buffer(bgfx_indirect_buffer_handle_t _handle);
bgfx_shader_handle_t bgfx_create_shader(const bgfx_memory_t* _mem);
uint16_t bgfx_get_shader_uniforms(bgfx_shader_handle_t _handle, bgfx_uniform_handle_t* _uniforms, uint16_t _max);
void bgfx_set_shader_name(bgfx_shader_handle_t _handle, const char* _name, int32_t _len);
void bgfx_destroy_shader(bgfx_shader_handle_t _handle);
bgfx_program_handle_t bgfx_create_program(bgfx_shader_handle_t _vsh, bgfx_shader_handle_t _fsh, bool _destroyShaders);
bgfx_program_handle_t bgfx_create_compute_program(bgfx_shader_handle_t _csh, bool _destroyShaders);
void bgfx_destroy_program(bgfx_program_handle_t _handle);
bool bgfx_is_texture_valid(uint16_t _depth, bool _cubeMap, uint16_t _numLayers, bgfx_texture_format_t _format, uint64_t _flags);
bool bgfx_is_video_codec_valid(bgfx_video_codec_t _codec, uint8_t _chroma, uint8_t _bitDepth, uint16_t _codedWidth, uint16_t _codedHeight, uint8_t _maxDpbSlots, uint8_t _maxActiveReferences);
bool bgfx_is_frame_buffer_valid(uint8_t _num, const bgfx_attachment_t* _attachment);
void bgfx_calc_texture_size(bgfx_texture_info_t * _info, uint16_t _width, uint16_t _height, uint16_t _depth, bool _cubeMap, bool _hasMips, uint16_t _numLayers, bgfx_texture_format_t _format);
bgfx_texture_handle_t bgfx_create_texture(const bgfx_memory_t* _mem, uint64_t _flags, uint8_t _skip, bgfx_texture_info_t* _info);
bgfx_texture_handle_t bgfx_create_texture_2d(uint16_t _width, uint16_t _height, bool _hasMips, uint16_t _numLayers, bgfx_texture_format_t _format, uint64_t _flags, const bgfx_memory_t* _mem, uint64_t _external);
bgfx_texture_handle_t bgfx_create_texture_2d_scaled(bgfx_backbuffer_ratio_t _ratio, bool _hasMips, uint16_t _numLayers, bgfx_texture_format_t _format, uint64_t _flags);
bgfx_texture_handle_t bgfx_create_texture_3d(uint16_t _width, uint16_t _height, uint16_t _depth, bool _hasMips, bgfx_texture_format_t _format, uint64_t _flags, const bgfx_memory_t* _mem, uint64_t _external);
bgfx_texture_handle_t bgfx_create_texture_cube(uint16_t _size, bool _hasMips, uint16_t _numLayers, bgfx_texture_format_t _format, uint64_t _flags, const bgfx_memory_t* _mem, uint64_t _external);
void bgfx_update_texture_2d(bgfx_texture_handle_t _handle, uint16_t _layer, uint8_t _mip, uint16_t _x, uint16_t _y, uint16_t _width, uint16_t _height, const bgfx_memory_t* _mem, uint16_t _pitch);
void bgfx_update_texture_3d(bgfx_texture_handle_t _handle, uint8_t _mip, uint16_t _x, uint16_t _y, uint16_t _z, uint16_t _width, uint16_t _height, uint16_t _depth, const bgfx_memory_t* _mem);
void bgfx_update_texture_cube(bgfx_texture_handle_t _handle, uint16_t _layer, uint8_t _side, uint8_t _mip, uint16_t _x, uint16_t _y, uint16_t _width, uint16_t _height, const bgfx_memory_t* _mem, uint16_t _pitch);
void bgfx_clear_texture(bgfx_texture_handle_t _handle, uint8_t _mip, uint8_t _numMips, uint16_t _layer, uint16_t _numLayers);
uint32_t bgfx_read_texture(const bgfx_texture_region_t * _src, void* _data);
void bgfx_set_texture_name(bgfx_texture_handle_t _handle, const char* _name, int32_t _len);
void* bgfx_get_direct_access_ptr(bgfx_texture_handle_t _handle);
void bgfx_destroy_texture(bgfx_texture_handle_t _handle);
bgfx_frame_buffer_handle_t bgfx_create_frame_buffer(uint16_t _width, uint16_t _height, bgfx_texture_format_t _format, uint64_t _textureFlags);
bgfx_frame_buffer_handle_t bgfx_create_frame_buffer_scaled(bgfx_backbuffer_ratio_t _ratio, bgfx_texture_format_t _format, uint64_t _textureFlags);
bgfx_frame_buffer_handle_t bgfx_create_frame_buffer_from_handles(uint8_t _num, const bgfx_texture_handle_t* _handles, bool _destroyTexture);
bgfx_frame_buffer_handle_t bgfx_create_frame_buffer_from_attachment(uint8_t _num, const bgfx_attachment_t* _attachment, bool _destroyTexture);
bgfx_frame_buffer_handle_t bgfx_create_frame_buffer_from_swap_chain(const bgfx_swap_chain_t* _desc);
void bgfx_update_swap_chain(bgfx_frame_buffer_handle_t _handle, const bgfx_swap_chain_t* _desc);
void bgfx_set_frame_buffer_name(bgfx_frame_buffer_handle_t _handle, const char* _name, int32_t _len);
bgfx_texture_handle_t bgfx_get_texture(bgfx_frame_buffer_handle_t _handle, uint8_t _attachment);
void bgfx_destroy_frame_buffer(bgfx_frame_buffer_handle_t _handle);
bgfx_uniform_handle_t bgfx_create_uniform(const char* _name, bgfx_uniform_type_t _type, uint16_t _num);
bgfx_uniform_handle_t bgfx_create_uniform_with_freq(const char* _name, bgfx_uniform_freq_t _freq, bgfx_uniform_type_t _type, uint16_t _num);
void bgfx_get_uniform_info(bgfx_uniform_handle_t _handle, bgfx_uniform_info_t * _info);
void bgfx_destroy_uniform(bgfx_uniform_handle_t _handle);
bgfx_occlusion_query_handle_t bgfx_create_occlusion_query(void);
bgfx_occlusion_query_result_t bgfx_get_result(bgfx_occlusion_query_handle_t _handle, int32_t* _result);
void bgfx_destroy_occlusion_query(bgfx_occlusion_query_handle_t _handle);
void bgfx_set_palette_color(uint8_t _index, const float _rgba[4]);
void bgfx_set_palette_color_rgba32f(uint8_t _index, float _r, float _g, float _b, float _a);
void bgfx_set_palette_color_rgba8(uint8_t _index, uint32_t _rgba);
void bgfx_set_view_name(bgfx_view_id_t _id, const char* _name, int32_t _len);
void bgfx_set_view_rect(bgfx_view_id_t _id, int16_t _x, int16_t _y, uint16_t _width, uint16_t _height, float _minDepth, float _maxDepth);
void bgfx_set_view_rect_ratio(bgfx_view_id_t _id, int16_t _x, int16_t _y, bgfx_backbuffer_ratio_t _ratio);
void bgfx_set_view_scissor(bgfx_view_id_t _id, uint16_t _x, uint16_t _y, uint16_t _width, uint16_t _height);
void bgfx_set_view_depth_bias(bgfx_view_id_t _id, int32_t _constant, float _slopeScale, float _clamp);
void bgfx_set_view_sample_mask(bgfx_view_id_t _id, uint32_t _mask);
void bgfx_set_view_clear(bgfx_view_id_t _id, uint16_t _flags, uint32_t _rgba, float _depth, uint8_t _stencil);
void bgfx_set_view_clear_mrt(bgfx_view_id_t _id, uint16_t _flags, float _depth, uint8_t _stencil, uint8_t _c0, uint8_t _c1, uint8_t _c2, uint8_t _c3, uint8_t _c4, uint8_t _c5, uint8_t _c6, uint8_t _c7);
void bgfx_set_view_mode(bgfx_view_id_t _id, bgfx_view_mode_t _mode);
void bgfx_set_view_frame_buffer(bgfx_view_id_t _id, bgfx_frame_buffer_handle_t _handle);
void bgfx_set_view_transform(bgfx_view_id_t _id, const void* _view, const void* _proj);
void bgfx_set_view_order(bgfx_view_id_t _id, uint16_t _num, const bgfx_view_id_t* _order);
void bgfx_set_view_shading_rate(bgfx_view_id_t _id, bgfx_shading_rate_t _shadingRate);
void bgfx_reset_view(bgfx_view_id_t _id);
bgfx_encoder_t* bgfx_encoder_begin(bool _forceNewEncoder);
void bgfx_encoder_end(bgfx_encoder_t* _encoder);
void bgfx_encoder_set_marker(bgfx_encoder_t* _this, const char* _name, int32_t _len);
void bgfx_encoder_set_state(bgfx_encoder_t* _this, uint64_t _state, uint32_t _rgba);
void bgfx_encoder_set_condition(bgfx_encoder_t* _this, bgfx_occlusion_query_handle_t _handle, bool _visible);
void bgfx_encoder_set_stencil(bgfx_encoder_t* _this, uint32_t _fstencil, uint32_t _bstencil);
void bgfx_encoder_set_sample_mask(bgfx_encoder_t* _this, uint32_t _mask);
uint16_t bgfx_encoder_set_scissor(bgfx_encoder_t* _this, uint16_t _x, uint16_t _y, uint16_t _width, uint16_t _height);
void bgfx_encoder_set_scissor_cached(bgfx_encoder_t* _this, uint16_t _cache);
uint16_t bgfx_encoder_set_depth_control(bgfx_encoder_t* _this, int32_t _constant, float _slopeScale, float _clamp, bool _depthClamp);
void bgfx_encoder_set_depth_control_cached(bgfx_encoder_t* _this, uint16_t _cache);
uint32_t bgfx_encoder_set_transform(bgfx_encoder_t* _this, const void* _mtx, uint16_t _num);
void bgfx_encoder_set_transform_cached(bgfx_encoder_t* _this, uint32_t _cache, uint16_t _num);
uint32_t bgfx_encoder_alloc_transform(bgfx_encoder_t* _this, bgfx_transform_t* _transform, uint16_t _num);
void bgfx_encoder_set_uniform(bgfx_encoder_t* _this, bgfx_uniform_handle_t _handle, const void* _value, uint16_t _num);
void bgfx_encoder_set_uniform_ref(bgfx_encoder_t* _this, bgfx_uniform_handle_t _handle, const void* _value, uint16_t _num);
void bgfx_set_view_uniform(bgfx_view_id_t _id, bgfx_uniform_handle_t _handle, const void* _value, uint16_t _num);
void bgfx_set_frame_uniform(bgfx_uniform_handle_t _handle, const void* _value, uint16_t _num);
void bgfx_encoder_set_index_buffer(bgfx_encoder_t* _this, bgfx_index_buffer_handle_t _handle, uint32_t _firstIndex, uint32_t _numIndices);
void bgfx_encoder_set_dynamic_index_buffer(bgfx_encoder_t* _this, bgfx_dynamic_index_buffer_handle_t _handle, uint32_t _firstIndex, uint32_t _numIndices);
void bgfx_encoder_set_transient_index_buffer(bgfx_encoder_t* _this, const bgfx_transient_index_buffer_t* _tib, uint32_t _firstIndex, uint32_t _numIndices);
void bgfx_encoder_set_vertex_buffer(bgfx_encoder_t* _this, uint8_t _stream, bgfx_vertex_buffer_handle_t _handle, uint32_t _startVertex, uint32_t _numVertices);
void bgfx_encoder_set_vertex_buffer_with_layout(bgfx_encoder_t* _this, uint8_t _stream, bgfx_vertex_buffer_handle_t _handle, uint32_t _startVertex, uint32_t _numVertices, bgfx_vertex_layout_handle_t _layoutHandle);
void bgfx_encoder_set_dynamic_vertex_buffer(bgfx_encoder_t* _this, uint8_t _stream, bgfx_dynamic_vertex_buffer_handle_t _handle, uint32_t _startVertex, uint32_t _numVertices);
void bgfx_encoder_set_dynamic_vertex_buffer_with_layout(bgfx_encoder_t* _this, uint8_t _stream, bgfx_dynamic_vertex_buffer_handle_t _handle, uint32_t _startVertex, uint32_t _numVertices, bgfx_vertex_layout_handle_t _layoutHandle);
void bgfx_encoder_set_transient_vertex_buffer(bgfx_encoder_t* _this, uint8_t _stream, const bgfx_transient_vertex_buffer_t* _tvb, uint32_t _startVertex, uint32_t _numVertices);
void bgfx_encoder_set_transient_vertex_buffer_with_layout(bgfx_encoder_t* _this, uint8_t _stream, const bgfx_transient_vertex_buffer_t* _tvb, uint32_t _startVertex, uint32_t _numVertices, bgfx_vertex_layout_handle_t _layoutHandle);
void bgfx_encoder_set_vertex_count(bgfx_encoder_t* _this, uint32_t _numVertices);
void bgfx_encoder_set_instance_data_buffer(bgfx_encoder_t* _this, const bgfx_instance_data_buffer_t* _idb, uint32_t _start, uint32_t _num);
void bgfx_encoder_set_instance_data_from_vertex_buffer(bgfx_encoder_t* _this, bgfx_vertex_buffer_handle_t _handle, uint32_t _startVertex, uint32_t _num);
void bgfx_encoder_set_instance_data_from_dynamic_vertex_buffer(bgfx_encoder_t* _this, bgfx_dynamic_vertex_buffer_handle_t _handle, uint32_t _startVertex, uint32_t _num);
void bgfx_encoder_set_instance_count(bgfx_encoder_t* _this, uint32_t _numInstances);
void bgfx_encoder_set_texture(bgfx_encoder_t* _this, uint8_t _stage, bgfx_uniform_handle_t _sampler, bgfx_texture_handle_t _handle, uint32_t _flags);
void bgfx_encoder_set_texture_view(bgfx_encoder_t* _this, uint8_t _stage, bgfx_uniform_handle_t _sampler, bgfx_texture_handle_t _handle, uint16_t _firstLayer, uint16_t _numLayers, uint8_t _firstMip, uint8_t _numMips, uint32_t _flags, uint8_t _lodMin, uint8_t _lodMax);
void bgfx_encoder_touch(bgfx_encoder_t* _this, bgfx_view_id_t _id);
void bgfx_encoder_submit(bgfx_encoder_t* _this, bgfx_view_id_t _id, bgfx_program_handle_t _program, uint32_t _depth, uint8_t _flags);
void bgfx_encoder_submit_occlusion_query(bgfx_encoder_t* _this, bgfx_view_id_t _id, bgfx_program_handle_t _program, bgfx_occlusion_query_handle_t _occlusionQuery, uint32_t _depth, uint8_t _flags);
void bgfx_encoder_submit_indirect(bgfx_encoder_t* _this, bgfx_view_id_t _id, bgfx_program_handle_t _program, bgfx_indirect_buffer_handle_t _indirectHandle, uint32_t _start, uint32_t _num, uint32_t _depth, uint8_t _flags);
void bgfx_encoder_submit_indirect_count(bgfx_encoder_t* _this, bgfx_view_id_t _id, bgfx_program_handle_t _program, bgfx_indirect_buffer_handle_t _indirectHandle, uint32_t _start, bgfx_index_buffer_handle_t _numHandle, uint32_t _numIndex, uint32_t _numMax, uint32_t _depth, uint8_t _flags);
void bgfx_encoder_set_compute_index_buffer(bgfx_encoder_t* _this, uint8_t _stage, bgfx_index_buffer_handle_t _handle, bgfx_access_t _access, uint32_t _offset, uint32_t _size);
void bgfx_encoder_set_compute_vertex_buffer(bgfx_encoder_t* _this, uint8_t _stage, bgfx_vertex_buffer_handle_t _handle, bgfx_access_t _access, uint32_t _offset, uint32_t _size);
void bgfx_encoder_set_compute_dynamic_index_buffer(bgfx_encoder_t* _this, uint8_t _stage, bgfx_dynamic_index_buffer_handle_t _handle, bgfx_access_t _access, uint32_t _offset, uint32_t _size);
void bgfx_encoder_set_compute_dynamic_vertex_buffer(bgfx_encoder_t* _this, uint8_t _stage, bgfx_dynamic_vertex_buffer_handle_t _handle, bgfx_access_t _access, uint32_t _offset, uint32_t _size);
void bgfx_encoder_set_compute_indirect_buffer(bgfx_encoder_t* _this, uint8_t _stage, bgfx_indirect_buffer_handle_t _handle, bgfx_access_t _access);
void bgfx_encoder_set_image(bgfx_encoder_t* _this, uint8_t _stage, bgfx_texture_handle_t _handle, uint8_t _mip, bgfx_access_t _access, bgfx_texture_format_t _format);
void bgfx_encoder_set_image_view(bgfx_encoder_t* _this, uint8_t _stage, bgfx_texture_handle_t _handle, uint16_t _firstLayer, uint16_t _numLayers, uint8_t _mip, bgfx_access_t _access, bgfx_texture_format_t _format);
void bgfx_encoder_dispatch(bgfx_encoder_t* _this, bgfx_view_id_t _id, bgfx_program_handle_t _program, uint32_t _numX, uint32_t _numY, uint32_t _numZ, uint8_t _flags);
void bgfx_encoder_dispatch_indirect(bgfx_encoder_t* _this, bgfx_view_id_t _id, bgfx_program_handle_t _program, bgfx_indirect_buffer_handle_t _indirectHandle, uint32_t _start, uint32_t _num, uint8_t _flags);
void bgfx_encoder_discard(bgfx_encoder_t* _this, uint8_t _flags);
void bgfx_encoder_blit(bgfx_encoder_t* _this, bgfx_view_id_t _id, const bgfx_texture_region_t * _dst, const bgfx_texture_region_t * _src);
void bgfx_encoder_blit_buffer(bgfx_encoder_t* _this, bgfx_view_id_t _id, const bgfx_buffer_region_t * _dst, const bgfx_buffer_region_t * _src);
void bgfx_encoder_blit_to_buffer(bgfx_encoder_t* _this, bgfx_view_id_t _id, const bgfx_buffer_region_t * _dst, const bgfx_texture_region_t * _src);
void bgfx_encoder_blit_from_buffer(bgfx_encoder_t* _this, bgfx_view_id_t _id, const bgfx_texture_region_t * _dst, const bgfx_buffer_region_t * _src);
void bgfx_request_screen_shot(bgfx_frame_buffer_handle_t _handle, const char* _filePath);
bgfx_render_frame_t bgfx_render_frame(int32_t _msecs);
const bgfx_internal_data_t* bgfx_get_internal_data(void);
void bgfx_set_marker(const char* _name, int32_t _len);
void bgfx_set_state(uint64_t _state, uint32_t _rgba);
void bgfx_set_condition(bgfx_occlusion_query_handle_t _handle, bool _visible);
void bgfx_set_stencil(uint32_t _fstencil, uint32_t _bstencil);
void bgfx_set_sample_mask(uint32_t _mask);
uint16_t bgfx_set_scissor(uint16_t _x, uint16_t _y, uint16_t _width, uint16_t _height);
void bgfx_set_scissor_cached(uint16_t _cache);
uint16_t bgfx_set_depth_control(int32_t _constant, float _slopeScale, float _clamp, bool _depthClamp);
void bgfx_set_depth_control_cached(uint16_t _cache);
uint32_t bgfx_set_transform(const void* _mtx, uint16_t _num);
void bgfx_set_transform_cached(uint32_t _cache, uint16_t _num);
uint32_t bgfx_alloc_transform(bgfx_transform_t* _transform, uint16_t _num);
void bgfx_set_uniform(bgfx_uniform_handle_t _handle, const void* _value, uint16_t _num);
void bgfx_set_uniform_ref(bgfx_uniform_handle_t _handle, const void* _value, uint16_t _num);
void bgfx_set_index_buffer(bgfx_index_buffer_handle_t _handle, uint32_t _firstIndex, uint32_t _numIndices);
void bgfx_set_dynamic_index_buffer(bgfx_dynamic_index_buffer_handle_t _handle, uint32_t _firstIndex, uint32_t _numIndices);
void bgfx_set_transient_index_buffer(const bgfx_transient_index_buffer_t* _tib, uint32_t _firstIndex, uint32_t _numIndices);
void bgfx_set_vertex_buffer(uint8_t _stream, bgfx_vertex_buffer_handle_t _handle, uint32_t _startVertex, uint32_t _numVertices);
void bgfx_set_vertex_buffer_with_layout(uint8_t _stream, bgfx_vertex_buffer_handle_t _handle, uint32_t _startVertex, uint32_t _numVertices, bgfx_vertex_layout_handle_t _layoutHandle);
void bgfx_set_dynamic_vertex_buffer(uint8_t _stream, bgfx_dynamic_vertex_buffer_handle_t _handle, uint32_t _startVertex, uint32_t _numVertices);
void bgfx_set_dynamic_vertex_buffer_with_layout(uint8_t _stream, bgfx_dynamic_vertex_buffer_handle_t _handle, uint32_t _startVertex, uint32_t _numVertices, bgfx_vertex_layout_handle_t _layoutHandle);
void bgfx_set_transient_vertex_buffer(uint8_t _stream, const bgfx_transient_vertex_buffer_t* _tvb, uint32_t _startVertex, uint32_t _numVertices);
void bgfx_set_transient_vertex_buffer_with_layout(uint8_t _stream, const bgfx_transient_vertex_buffer_t* _tvb, uint32_t _startVertex, uint32_t _numVertices, bgfx_vertex_layout_handle_t _layoutHandle);
void bgfx_set_vertex_count(uint32_t _numVertices);
void bgfx_set_instance_data_buffer(const bgfx_instance_data_buffer_t* _idb, uint32_t _start, uint32_t _num);
void bgfx_set_instance_data_from_vertex_buffer(bgfx_vertex_buffer_handle_t _handle, uint32_t _startVertex, uint32_t _num);
void bgfx_set_instance_data_from_dynamic_vertex_buffer(bgfx_dynamic_vertex_buffer_handle_t _handle, uint32_t _startVertex, uint32_t _num);
void bgfx_set_instance_count(uint32_t _numInstances);
void bgfx_set_texture(uint8_t _stage, bgfx_uniform_handle_t _sampler, bgfx_texture_handle_t _handle, uint32_t _flags);
void bgfx_set_texture_view(uint8_t _stage, bgfx_uniform_handle_t _sampler, bgfx_texture_handle_t _handle, uint16_t _firstLayer, uint16_t _numLayers, uint8_t _firstMip, uint8_t _numMips, uint32_t _flags, uint8_t _lodMin, uint8_t _lodMax);
void bgfx_touch(bgfx_view_id_t _id);
void bgfx_submit(bgfx_view_id_t _id, bgfx_program_handle_t _program, uint32_t _depth, uint8_t _flags);
void bgfx_submit_occlusion_query(bgfx_view_id_t _id, bgfx_program_handle_t _program, bgfx_occlusion_query_handle_t _occlusionQuery, uint32_t _depth, uint8_t _flags);
void bgfx_submit_indirect(bgfx_view_id_t _id, bgfx_program_handle_t _program, bgfx_indirect_buffer_handle_t _indirectHandle, uint32_t _start, uint32_t _num, uint32_t _depth, uint8_t _flags);
void bgfx_submit_indirect_count(bgfx_view_id_t _id, bgfx_program_handle_t _program, bgfx_indirect_buffer_handle_t _indirectHandle, uint32_t _start, bgfx_index_buffer_handle_t _numHandle, uint32_t _numIndex, uint32_t _numMax, uint32_t _depth, uint8_t _flags);
void bgfx_set_compute_index_buffer(uint8_t _stage, bgfx_index_buffer_handle_t _handle, bgfx_access_t _access, uint32_t _offset, uint32_t _size);
void bgfx_set_compute_vertex_buffer(uint8_t _stage, bgfx_vertex_buffer_handle_t _handle, bgfx_access_t _access, uint32_t _offset, uint32_t _size);
void bgfx_set_compute_dynamic_index_buffer(uint8_t _stage, bgfx_dynamic_index_buffer_handle_t _handle, bgfx_access_t _access, uint32_t _offset, uint32_t _size);
void bgfx_set_compute_dynamic_vertex_buffer(uint8_t _stage, bgfx_dynamic_vertex_buffer_handle_t _handle, bgfx_access_t _access, uint32_t _offset, uint32_t _size);
void bgfx_set_compute_indirect_buffer(uint8_t _stage, bgfx_indirect_buffer_handle_t _handle, bgfx_access_t _access);
void bgfx_set_image(uint8_t _stage, bgfx_texture_handle_t _handle, uint8_t _mip, bgfx_access_t _access, bgfx_texture_format_t _format);
void bgfx_set_image_view(uint8_t _stage, bgfx_texture_handle_t _handle, uint16_t _firstLayer, uint16_t _numLayers, uint8_t _mip, bgfx_access_t _access, bgfx_texture_format_t _format);
void bgfx_dispatch(bgfx_view_id_t _id, bgfx_program_handle_t _program, uint32_t _numX, uint32_t _numY, uint32_t _numZ, uint8_t _flags);
void bgfx_dispatch_indirect(bgfx_view_id_t _id, bgfx_program_handle_t _program, bgfx_indirect_buffer_handle_t _indirectHandle, uint32_t _start, uint32_t _num, uint8_t _flags);
void bgfx_discard(uint8_t _flags);
void bgfx_blit(bgfx_view_id_t _id, const bgfx_texture_region_t * _dst, const bgfx_texture_region_t * _src);
void bgfx_blit_buffer(bgfx_view_id_t _id, const bgfx_buffer_region_t * _dst, const bgfx_buffer_region_t * _src);
void bgfx_blit_to_buffer(bgfx_view_id_t _id, const bgfx_buffer_region_t * _dst, const bgfx_texture_region_t * _src);
void bgfx_blit_from_buffer(bgfx_view_id_t _id, const bgfx_texture_region_t * _dst, const bgfx_buffer_region_t * _src);
typedef enum bgfx_function_id
{
    BGFX_FUNCTION_ID_TEXTURE_REGION_INIT,
    BGFX_FUNCTION_ID_BUFFER_REGION_INIT_TEXTURE,
    BGFX_FUNCTION_ID_BUFFER_REGION_INIT_BUFFER,
    BGFX_FUNCTION_ID_ATTACHMENT_INIT,
    BGFX_FUNCTION_ID_VERTEX_LAYOUT_BEGIN,
    BGFX_FUNCTION_ID_VERTEX_LAYOUT_ADD,
    BGFX_FUNCTION_ID_VERTEX_LAYOUT_DECODE,
    BGFX_FUNCTION_ID_VERTEX_LAYOUT_HAS,
    BGFX_FUNCTION_ID_VERTEX_LAYOUT_SKIP,
    BGFX_FUNCTION_ID_VERTEX_LAYOUT_END,
    BGFX_FUNCTION_ID_VERTEX_LAYOUT_GET_OFFSET,
    BGFX_FUNCTION_ID_VERTEX_LAYOUT_GET_STRIDE,
    BGFX_FUNCTION_ID_VERTEX_LAYOUT_GET_SIZE,
    BGFX_FUNCTION_ID_VERTEX_PACK,
    BGFX_FUNCTION_ID_VERTEX_UNPACK,
    BGFX_FUNCTION_ID_VERTEX_CONVERT,
    BGFX_FUNCTION_ID_TOPOLOGY_CONVERT,
    BGFX_FUNCTION_ID_TOPOLOGY_SORT_TRI_LIST,
    BGFX_FUNCTION_ID_GET_SUPPORTED_RENDERERS,
    BGFX_FUNCTION_ID_GET_RENDERER_NAME,
    BGFX_FUNCTION_ID_INIT_CTOR,
    BGFX_FUNCTION_ID_INIT,
    BGFX_FUNCTION_ID_SHUTDOWN,
    BGFX_FUNCTION_ID_RESET,
    BGFX_FUNCTION_ID_FRAME,
    BGFX_FUNCTION_ID_GET_RENDERER_TYPE,
    BGFX_FUNCTION_ID_GET_CAPS,
    BGFX_FUNCTION_ID_GET_STATS,
    BGFX_FUNCTION_ID_ALLOC,
    BGFX_FUNCTION_ID_COPY,
    BGFX_FUNCTION_ID_MAKE_REF,
    BGFX_FUNCTION_ID_MAKE_REF_RELEASE,
    BGFX_FUNCTION_ID_SET_DEBUG,
    BGFX_FUNCTION_ID_DBG_TEXT_CLEAR,
    BGFX_FUNCTION_ID_DBG_TEXT_PRINTF,
    BGFX_FUNCTION_ID_DBG_TEXT_VPRINTF,
    BGFX_FUNCTION_ID_DBG_TEXT_IMAGE,
    BGFX_FUNCTION_ID_CREATE_INDEX_BUFFER,
    BGFX_FUNCTION_ID_READ_BUFFER,
    BGFX_FUNCTION_ID_SET_INDEX_BUFFER_NAME,
    BGFX_FUNCTION_ID_DESTROY_INDEX_BUFFER,
    BGFX_FUNCTION_ID_CREATE_VERTEX_LAYOUT,
    BGFX_FUNCTION_ID_DESTROY_VERTEX_LAYOUT,
    BGFX_FUNCTION_ID_CREATE_VERTEX_BUFFER,
    BGFX_FUNCTION_ID_SET_VERTEX_BUFFER_NAME,
    BGFX_FUNCTION_ID_DESTROY_VERTEX_BUFFER,
    BGFX_FUNCTION_ID_CREATE_DYNAMIC_INDEX_BUFFER,
    BGFX_FUNCTION_ID_CREATE_DYNAMIC_INDEX_BUFFER_MEM,
    BGFX_FUNCTION_ID_UPDATE_DYNAMIC_INDEX_BUFFER,
    BGFX_FUNCTION_ID_DESTROY_DYNAMIC_INDEX_BUFFER,
    BGFX_FUNCTION_ID_CREATE_DYNAMIC_VERTEX_BUFFER,
    BGFX_FUNCTION_ID_CREATE_DYNAMIC_VERTEX_BUFFER_MEM,
    BGFX_FUNCTION_ID_UPDATE_DYNAMIC_VERTEX_BUFFER,
    BGFX_FUNCTION_ID_DESTROY_DYNAMIC_VERTEX_BUFFER,
    BGFX_FUNCTION_ID_GET_AVAIL_TRANSIENT_INDEX_BUFFER,
    BGFX_FUNCTION_ID_GET_AVAIL_TRANSIENT_VERTEX_BUFFER,
    BGFX_FUNCTION_ID_GET_AVAIL_INSTANCE_DATA_BUFFER,
    BGFX_FUNCTION_ID_ALLOC_TRANSIENT_INDEX_BUFFER,
    BGFX_FUNCTION_ID_ALLOC_TRANSIENT_VERTEX_BUFFER,
    BGFX_FUNCTION_ID_ALLOC_TRANSIENT_BUFFERS,
    BGFX_FUNCTION_ID_ALLOC_INSTANCE_DATA_BUFFER,
    BGFX_FUNCTION_ID_CREATE_INDIRECT_BUFFER,
    BGFX_FUNCTION_ID_DESTROY_INDIRECT_BUFFER,
    BGFX_FUNCTION_ID_CREATE_SHADER,
    BGFX_FUNCTION_ID_GET_SHADER_UNIFORMS,
    BGFX_FUNCTION_ID_SET_SHADER_NAME,
    BGFX_FUNCTION_ID_DESTROY_SHADER,
    BGFX_FUNCTION_ID_CREATE_PROGRAM,
    BGFX_FUNCTION_ID_CREATE_COMPUTE_PROGRAM,
    BGFX_FUNCTION_ID_DESTROY_PROGRAM,
    BGFX_FUNCTION_ID_IS_TEXTURE_VALID,
    BGFX_FUNCTION_ID_IS_VIDEO_CODEC_VALID,
    BGFX_FUNCTION_ID_IS_FRAME_BUFFER_VALID,
    BGFX_FUNCTION_ID_CALC_TEXTURE_SIZE,
    BGFX_FUNCTION_ID_CREATE_TEXTURE,
    BGFX_FUNCTION_ID_CREATE_TEXTURE_2D,
    BGFX_FUNCTION_ID_CREATE_TEXTURE_2D_SCALED,
    BGFX_FUNCTION_ID_CREATE_TEXTURE_3D,
    BGFX_FUNCTION_ID_CREATE_TEXTURE_CUBE,
    BGFX_FUNCTION_ID_UPDATE_TEXTURE_2D,
    BGFX_FUNCTION_ID_UPDATE_TEXTURE_3D,
    BGFX_FUNCTION_ID_UPDATE_TEXTURE_CUBE,
    BGFX_FUNCTION_ID_CLEAR_TEXTURE,
    BGFX_FUNCTION_ID_READ_TEXTURE,
    BGFX_FUNCTION_ID_SET_TEXTURE_NAME,
    BGFX_FUNCTION_ID_GET_DIRECT_ACCESS_PTR,
    BGFX_FUNCTION_ID_DESTROY_TEXTURE,
    BGFX_FUNCTION_ID_CREATE_FRAME_BUFFER,
    BGFX_FUNCTION_ID_CREATE_FRAME_BUFFER_SCALED,
    BGFX_FUNCTION_ID_CREATE_FRAME_BUFFER_FROM_HANDLES,
    BGFX_FUNCTION_ID_CREATE_FRAME_BUFFER_FROM_ATTACHMENT,
    BGFX_FUNCTION_ID_CREATE_FRAME_BUFFER_FROM_SWAP_CHAIN,
    BGFX_FUNCTION_ID_UPDATE_SWAP_CHAIN,
    BGFX_FUNCTION_ID_SET_FRAME_BUFFER_NAME,
    BGFX_FUNCTION_ID_GET_TEXTURE,
    BGFX_FUNCTION_ID_DESTROY_FRAME_BUFFER,
    BGFX_FUNCTION_ID_CREATE_UNIFORM,
    BGFX_FUNCTION_ID_CREATE_UNIFORM_WITH_FREQ,
    BGFX_FUNCTION_ID_GET_UNIFORM_INFO,
    BGFX_FUNCTION_ID_DESTROY_UNIFORM,
    BGFX_FUNCTION_ID_CREATE_OCCLUSION_QUERY,
    BGFX_FUNCTION_ID_GET_RESULT,
    BGFX_FUNCTION_ID_DESTROY_OCCLUSION_QUERY,
    BGFX_FUNCTION_ID_SET_PALETTE_COLOR,
    BGFX_FUNCTION_ID_SET_PALETTE_COLOR_RGBA32F,
    BGFX_FUNCTION_ID_SET_PALETTE_COLOR_RGBA8,
    BGFX_FUNCTION_ID_SET_VIEW_NAME,
    BGFX_FUNCTION_ID_SET_VIEW_RECT,
    BGFX_FUNCTION_ID_SET_VIEW_RECT_RATIO,
    BGFX_FUNCTION_ID_SET_VIEW_SCISSOR,
    BGFX_FUNCTION_ID_SET_VIEW_DEPTH_BIAS,
    BGFX_FUNCTION_ID_SET_VIEW_SAMPLE_MASK,
    BGFX_FUNCTION_ID_SET_VIEW_CLEAR,
    BGFX_FUNCTION_ID_SET_VIEW_CLEAR_MRT,
    BGFX_FUNCTION_ID_SET_VIEW_MODE,
    BGFX_FUNCTION_ID_SET_VIEW_FRAME_BUFFER,
    BGFX_FUNCTION_ID_SET_VIEW_TRANSFORM,
    BGFX_FUNCTION_ID_SET_VIEW_ORDER,
    BGFX_FUNCTION_ID_SET_VIEW_SHADING_RATE,
    BGFX_FUNCTION_ID_RESET_VIEW,
    BGFX_FUNCTION_ID_ENCODER_BEGIN,
    BGFX_FUNCTION_ID_ENCODER_END,
    BGFX_FUNCTION_ID_ENCODER_SET_MARKER,
    BGFX_FUNCTION_ID_ENCODER_SET_STATE,
    BGFX_FUNCTION_ID_ENCODER_SET_CONDITION,
    BGFX_FUNCTION_ID_ENCODER_SET_STENCIL,
    BGFX_FUNCTION_ID_ENCODER_SET_SAMPLE_MASK,
    BGFX_FUNCTION_ID_ENCODER_SET_SCISSOR,
    BGFX_FUNCTION_ID_ENCODER_SET_SCISSOR_CACHED,
    BGFX_FUNCTION_ID_ENCODER_SET_DEPTH_CONTROL,
    BGFX_FUNCTION_ID_ENCODER_SET_DEPTH_CONTROL_CACHED,
    BGFX_FUNCTION_ID_ENCODER_SET_TRANSFORM,
    BGFX_FUNCTION_ID_ENCODER_SET_TRANSFORM_CACHED,
    BGFX_FUNCTION_ID_ENCODER_ALLOC_TRANSFORM,
    BGFX_FUNCTION_ID_ENCODER_SET_UNIFORM,
    BGFX_FUNCTION_ID_ENCODER_SET_UNIFORM_REF,
    BGFX_FUNCTION_ID_SET_VIEW_UNIFORM,
    BGFX_FUNCTION_ID_SET_FRAME_UNIFORM,
    BGFX_FUNCTION_ID_ENCODER_SET_INDEX_BUFFER,
    BGFX_FUNCTION_ID_ENCODER_SET_DYNAMIC_INDEX_BUFFER,
    BGFX_FUNCTION_ID_ENCODER_SET_TRANSIENT_INDEX_BUFFER,
    BGFX_FUNCTION_ID_ENCODER_SET_VERTEX_BUFFER,
    BGFX_FUNCTION_ID_ENCODER_SET_VERTEX_BUFFER_WITH_LAYOUT,
    BGFX_FUNCTION_ID_ENCODER_SET_DYNAMIC_VERTEX_BUFFER,
    BGFX_FUNCTION_ID_ENCODER_SET_DYNAMIC_VERTEX_BUFFER_WITH_LAYOUT,
    BGFX_FUNCTION_ID_ENCODER_SET_TRANSIENT_VERTEX_BUFFER,
    BGFX_FUNCTION_ID_ENCODER_SET_TRANSIENT_VERTEX_BUFFER_WITH_LAYOUT,
    BGFX_FUNCTION_ID_ENCODER_SET_VERTEX_COUNT,
    BGFX_FUNCTION_ID_ENCODER_SET_INSTANCE_DATA_BUFFER,
    BGFX_FUNCTION_ID_ENCODER_SET_INSTANCE_DATA_FROM_VERTEX_BUFFER,
    BGFX_FUNCTION_ID_ENCODER_SET_INSTANCE_DATA_FROM_DYNAMIC_VERTEX_BUFFER,
    BGFX_FUNCTION_ID_ENCODER_SET_INSTANCE_COUNT,
    BGFX_FUNCTION_ID_ENCODER_SET_TEXTURE,
    BGFX_FUNCTION_ID_ENCODER_SET_TEXTURE_VIEW,
    BGFX_FUNCTION_ID_ENCODER_TOUCH,
    BGFX_FUNCTION_ID_ENCODER_SUBMIT,
    BGFX_FUNCTION_ID_ENCODER_SUBMIT_OCCLUSION_QUERY,
    BGFX_FUNCTION_ID_ENCODER_SUBMIT_INDIRECT,
    BGFX_FUNCTION_ID_ENCODER_SUBMIT_INDIRECT_COUNT,
    BGFX_FUNCTION_ID_ENCODER_SET_COMPUTE_INDEX_BUFFER,
    BGFX_FUNCTION_ID_ENCODER_SET_COMPUTE_VERTEX_BUFFER,
    BGFX_FUNCTION_ID_ENCODER_SET_COMPUTE_DYNAMIC_INDEX_BUFFER,
    BGFX_FUNCTION_ID_ENCODER_SET_COMPUTE_DYNAMIC_VERTEX_BUFFER,
    BGFX_FUNCTION_ID_ENCODER_SET_COMPUTE_INDIRECT_BUFFER,
    BGFX_FUNCTION_ID_ENCODER_SET_IMAGE,
    BGFX_FUNCTION_ID_ENCODER_SET_IMAGE_VIEW,
    BGFX_FUNCTION_ID_ENCODER_DISPATCH,
    BGFX_FUNCTION_ID_ENCODER_DISPATCH_INDIRECT,
    BGFX_FUNCTION_ID_ENCODER_DISCARD,
    BGFX_FUNCTION_ID_ENCODER_BLIT,
    BGFX_FUNCTION_ID_ENCODER_BLIT_BUFFER,
    BGFX_FUNCTION_ID_ENCODER_BLIT_TO_BUFFER,
    BGFX_FUNCTION_ID_ENCODER_BLIT_FROM_BUFFER,
    BGFX_FUNCTION_ID_REQUEST_SCREEN_SHOT,
    BGFX_FUNCTION_ID_RENDER_FRAME,
    BGFX_FUNCTION_ID_GET_INTERNAL_DATA,
    BGFX_FUNCTION_ID_SET_MARKER,
    BGFX_FUNCTION_ID_SET_STATE,
    BGFX_FUNCTION_ID_SET_CONDITION,
    BGFX_FUNCTION_ID_SET_STENCIL,
    BGFX_FUNCTION_ID_SET_SAMPLE_MASK,
    BGFX_FUNCTION_ID_SET_SCISSOR,
    BGFX_FUNCTION_ID_SET_SCISSOR_CACHED,
    BGFX_FUNCTION_ID_SET_DEPTH_CONTROL,
    BGFX_FUNCTION_ID_SET_DEPTH_CONTROL_CACHED,
    BGFX_FUNCTION_ID_SET_TRANSFORM,
    BGFX_FUNCTION_ID_SET_TRANSFORM_CACHED,
    BGFX_FUNCTION_ID_ALLOC_TRANSFORM,
    BGFX_FUNCTION_ID_SET_UNIFORM,
    BGFX_FUNCTION_ID_SET_UNIFORM_REF,
    BGFX_FUNCTION_ID_SET_INDEX_BUFFER,
    BGFX_FUNCTION_ID_SET_DYNAMIC_INDEX_BUFFER,
    BGFX_FUNCTION_ID_SET_TRANSIENT_INDEX_BUFFER,
    BGFX_FUNCTION_ID_SET_VERTEX_BUFFER,
    BGFX_FUNCTION_ID_SET_VERTEX_BUFFER_WITH_LAYOUT,
    BGFX_FUNCTION_ID_SET_DYNAMIC_VERTEX_BUFFER,
    BGFX_FUNCTION_ID_SET_DYNAMIC_VERTEX_BUFFER_WITH_LAYOUT,
    BGFX_FUNCTION_ID_SET_TRANSIENT_VERTEX_BUFFER,
    BGFX_FUNCTION_ID_SET_TRANSIENT_VERTEX_BUFFER_WITH_LAYOUT,
    BGFX_FUNCTION_ID_SET_VERTEX_COUNT,
    BGFX_FUNCTION_ID_SET_INSTANCE_DATA_BUFFER,
    BGFX_FUNCTION_ID_SET_INSTANCE_DATA_FROM_VERTEX_BUFFER,
    BGFX_FUNCTION_ID_SET_INSTANCE_DATA_FROM_DYNAMIC_VERTEX_BUFFER,
    BGFX_FUNCTION_ID_SET_INSTANCE_COUNT,
    BGFX_FUNCTION_ID_SET_TEXTURE,
    BGFX_FUNCTION_ID_SET_TEXTURE_VIEW,
    BGFX_FUNCTION_ID_TOUCH,
    BGFX_FUNCTION_ID_SUBMIT,
    BGFX_FUNCTION_ID_SUBMIT_OCCLUSION_QUERY,
    BGFX_FUNCTION_ID_SUBMIT_INDIRECT,
    BGFX_FUNCTION_ID_SUBMIT_INDIRECT_COUNT,
    BGFX_FUNCTION_ID_SET_COMPUTE_INDEX_BUFFER,
    BGFX_FUNCTION_ID_SET_COMPUTE_VERTEX_BUFFER,
    BGFX_FUNCTION_ID_SET_COMPUTE_DYNAMIC_INDEX_BUFFER,
    BGFX_FUNCTION_ID_SET_COMPUTE_DYNAMIC_VERTEX_BUFFER,
    BGFX_FUNCTION_ID_SET_COMPUTE_INDIRECT_BUFFER,
    BGFX_FUNCTION_ID_SET_IMAGE,
    BGFX_FUNCTION_ID_SET_IMAGE_VIEW,
    BGFX_FUNCTION_ID_DISPATCH,
    BGFX_FUNCTION_ID_DISPATCH_INDIRECT,
    BGFX_FUNCTION_ID_DISCARD,
    BGFX_FUNCTION_ID_BLIT,
    BGFX_FUNCTION_ID_BLIT_BUFFER,
    BGFX_FUNCTION_ID_BLIT_TO_BUFFER,
    BGFX_FUNCTION_ID_BLIT_FROM_BUFFER,
    BGFX_FUNCTION_ID_COUNT
} bgfx_function_id_t;
struct bgfx_interface_vtbl
{
    void (*texture_region_init)(bgfx_texture_region_t* _this, bgfx_texture_handle_t _handle, uint16_t _x, uint16_t _y, uint16_t _width, uint16_t _height);
    void (*buffer_region_init_texture)(bgfx_buffer_region_t* _this, const bgfx_texture_region_t * _texture);
    void (*buffer_region_init_buffer)(bgfx_buffer_region_t* _this, bgfx_buffer_handle_t _handle, uint32_t _offset, uint32_t _size);
    void (*attachment_init)(bgfx_attachment_t* _this, bgfx_texture_handle_t _handle, bgfx_access_t _access, uint16_t _layer, uint16_t _numLayers, uint16_t _mip, uint8_t _flags);
    bgfx_vertex_layout_t* (*vertex_layout_begin)(bgfx_vertex_layout_t* _this, bgfx_renderer_type_t _rendererType);
    bgfx_vertex_layout_t* (*vertex_layout_add)(bgfx_vertex_layout_t* _this, bgfx_attrib_t _attrib, uint8_t _num, bgfx_attrib_type_t _type, bool _normalized, bool _asInt);
    void (*vertex_layout_decode)(const bgfx_vertex_layout_t* _this, bgfx_attrib_t _attrib, uint8_t * _num, bgfx_attrib_type_t * _type, bool * _normalized, bool * _asInt);
    bool (*vertex_layout_has)(const bgfx_vertex_layout_t* _this, bgfx_attrib_t _attrib);
    bgfx_vertex_layout_t* (*vertex_layout_skip)(bgfx_vertex_layout_t* _this, uint8_t _num);
    void (*vertex_layout_end)(bgfx_vertex_layout_t* _this);
    uint16_t (*vertex_layout_get_offset)(const bgfx_vertex_layout_t* _this, bgfx_attrib_t _attrib);
    uint16_t (*vertex_layout_get_stride)(const bgfx_vertex_layout_t* _this);
    uint32_t (*vertex_layout_get_size)(const bgfx_vertex_layout_t* _this, uint32_t _num);
    void (*vertex_pack)(const float _input[4], bool _inputNormalized, bgfx_attrib_t _attr, const bgfx_vertex_layout_t * _layout, void* _data, uint32_t _index);
    void (*vertex_unpack)(float _output[4], bgfx_attrib_t _attr, const bgfx_vertex_layout_t * _layout, const void* _data, uint32_t _index);
    void (*vertex_convert)(const bgfx_vertex_layout_t * _dstLayout, void* _dstData, const bgfx_vertex_layout_t * _srcLayout, const void* _srcData, uint32_t _num);
    uint32_t (*topology_convert)(bgfx_topology_convert_t _conversion, void* _dst, uint32_t _dstSize, const void* _indices, uint32_t _numIndices, bool _index32);
    void (*topology_sort_tri_list)(bgfx_topology_sort_t _sort, void* _dst, uint32_t _dstSize, const float _dir[3], const float _pos[3], const void* _vertices, uint32_t _stride, const void* _indices, uint32_t _numIndices, bool _index32);
    uint8_t (*get_supported_renderers)(uint8_t _max, bgfx_renderer_type_t* _enum);
    const char* (*get_renderer_name)(bgfx_renderer_type_t _type);
    void (*init_ctor)(bgfx_init_t* _init);
    bool (*init)(const bgfx_init_t * _init);
    void (*shutdown)(void);
    void (*reset)(uint32_t _flags, const bgfx_swap_chain_t* _swapChain);
    uint32_t (*frame)(uint8_t _flags);
    bgfx_renderer_type_t (*get_renderer_type)(void);
    const bgfx_caps_t* (*get_caps)(void);
    const bgfx_stats_t* (*get_stats)(void);
    const bgfx_memory_t* (*alloc)(uint32_t _size);
    const bgfx_memory_t* (*copy)(const void* _data, uint32_t _size);
    const bgfx_memory_t* (*make_ref)(const void* _data, uint32_t _size);
    const bgfx_memory_t* (*make_ref_release)(const void* _data, uint32_t _size, bgfx_release_fn_t _releaseFn, void* _userData);
    void (*set_debug)(uint32_t _debug, bgfx_frame_buffer_handle_t _handle, uint8_t _scale);
    void (*dbg_text_clear)(uint8_t _attr, bool _small);
    void (*dbg_text_printf)(uint16_t _x, uint16_t _y, uint8_t _attr, const char* _format, ... );
    void (*dbg_text_vprintf)(uint16_t _x, uint16_t _y, uint8_t _attr, const char* _format, va_list _argList);
    void (*dbg_text_image)(uint16_t _x, uint16_t _y, uint16_t _width, uint16_t _height, const void* _data, uint16_t _pitch);
    bgfx_index_buffer_handle_t (*create_index_buffer)(const bgfx_memory_t* _mem, uint16_t _flags);
    uint32_t (*read_buffer)(const bgfx_buffer_region_t * _src, void* _data);
    void (*set_index_buffer_name)(bgfx_index_buffer_handle_t _handle, const char* _name, int32_t _len);
    void (*destroy_index_buffer)(bgfx_index_buffer_handle_t _handle);
    bgfx_vertex_layout_handle_t (*create_vertex_layout)(const bgfx_vertex_layout_t * _layout);
    void (*destroy_vertex_layout)(bgfx_vertex_layout_handle_t _layoutHandle);
    bgfx_vertex_buffer_handle_t (*create_vertex_buffer)(const bgfx_memory_t* _mem, const bgfx_vertex_layout_t * _layout, uint16_t _flags);
    void (*set_vertex_buffer_name)(bgfx_vertex_buffer_handle_t _handle, const char* _name, int32_t _len);
    void (*destroy_vertex_buffer)(bgfx_vertex_buffer_handle_t _handle);
    bgfx_dynamic_index_buffer_handle_t (*create_dynamic_index_buffer)(uint32_t _num, uint16_t _flags);
    bgfx_dynamic_index_buffer_handle_t (*create_dynamic_index_buffer_mem)(const bgfx_memory_t* _mem, uint16_t _flags);
    void (*update_dynamic_index_buffer)(bgfx_dynamic_index_buffer_handle_t _handle, uint32_t _startIndex, const bgfx_memory_t* _mem);
    void (*destroy_dynamic_index_buffer)(bgfx_dynamic_index_buffer_handle_t _handle);
    bgfx_dynamic_vertex_buffer_handle_t (*create_dynamic_vertex_buffer)(uint32_t _num, const bgfx_vertex_layout_t* _layout, uint16_t _flags);
    bgfx_dynamic_vertex_buffer_handle_t (*create_dynamic_vertex_buffer_mem)(const bgfx_memory_t* _mem, const bgfx_vertex_layout_t* _layout, uint16_t _flags);
    void (*update_dynamic_vertex_buffer)(bgfx_dynamic_vertex_buffer_handle_t _handle, uint32_t _startVertex, const bgfx_memory_t* _mem);
    void (*destroy_dynamic_vertex_buffer)(bgfx_dynamic_vertex_buffer_handle_t _handle);
    uint32_t (*get_avail_transient_index_buffer)(uint32_t _num, bool _index32);
    uint32_t (*get_avail_transient_vertex_buffer)(uint32_t _num, const bgfx_vertex_layout_t * _layout);
    uint32_t (*get_avail_instance_data_buffer)(uint32_t _num, uint16_t _stride);
    void (*alloc_transient_index_buffer)(bgfx_transient_index_buffer_t* _tib, uint32_t _num, bool _index32);
    void (*alloc_transient_vertex_buffer)(bgfx_transient_vertex_buffer_t* _tvb, uint32_t _num, const bgfx_vertex_layout_t * _layout);
    bool (*alloc_transient_buffers)(bgfx_transient_vertex_buffer_t* _tvb, const bgfx_vertex_layout_t * _layout, uint32_t _numVertices, bgfx_transient_index_buffer_t* _tib, uint32_t _numIndices, bool _index32);
    void (*alloc_instance_data_buffer)(bgfx_instance_data_buffer_t* _idb, uint32_t _num, uint16_t _stride);
    bgfx_indirect_buffer_handle_t (*create_indirect_buffer)(uint32_t _num);
    void (*destroy_indirect_buffer)(bgfx_indirect_buffer_handle_t _handle);
    bgfx_shader_handle_t (*create_shader)(const bgfx_memory_t* _mem);
    uint16_t (*get_shader_uniforms)(bgfx_shader_handle_t _handle, bgfx_uniform_handle_t* _uniforms, uint16_t _max);
    void (*set_shader_name)(bgfx_shader_handle_t _handle, const char* _name, int32_t _len);
    void (*destroy_shader)(bgfx_shader_handle_t _handle);
    bgfx_program_handle_t (*create_program)(bgfx_shader_handle_t _vsh, bgfx_shader_handle_t _fsh, bool _destroyShaders);
    bgfx_program_handle_t (*create_compute_program)(bgfx_shader_handle_t _csh, bool _destroyShaders);
    void (*destroy_program)(bgfx_program_handle_t _handle);
    bool (*is_texture_valid)(uint16_t _depth, bool _cubeMap, uint16_t _numLayers, bgfx_texture_format_t _format, uint64_t _flags);
    bool (*is_video_codec_valid)(bgfx_video_codec_t _codec, uint8_t _chroma, uint8_t _bitDepth, uint16_t _codedWidth, uint16_t _codedHeight, uint8_t _maxDpbSlots, uint8_t _maxActiveReferences);
    bool (*is_frame_buffer_valid)(uint8_t _num, const bgfx_attachment_t* _attachment);
    void (*calc_texture_size)(bgfx_texture_info_t * _info, uint16_t _width, uint16_t _height, uint16_t _depth, bool _cubeMap, bool _hasMips, uint16_t _numLayers, bgfx_texture_format_t _format);
    bgfx_texture_handle_t (*create_texture)(const bgfx_memory_t* _mem, uint64_t _flags, uint8_t _skip, bgfx_texture_info_t* _info);
    bgfx_texture_handle_t (*create_texture_2d)(uint16_t _width, uint16_t _height, bool _hasMips, uint16_t _numLayers, bgfx_texture_format_t _format, uint64_t _flags, const bgfx_memory_t* _mem, uint64_t _external);
    bgfx_texture_handle_t (*create_texture_2d_scaled)(bgfx_backbuffer_ratio_t _ratio, bool _hasMips, uint16_t _numLayers, bgfx_texture_format_t _format, uint64_t _flags);
    bgfx_texture_handle_t (*create_texture_3d)(uint16_t _width, uint16_t _height, uint16_t _depth, bool _hasMips, bgfx_texture_format_t _format, uint64_t _flags, const bgfx_memory_t* _mem, uint64_t _external);
    bgfx_texture_handle_t (*create_texture_cube)(uint16_t _size, bool _hasMips, uint16_t _numLayers, bgfx_texture_format_t _format, uint64_t _flags, const bgfx_memory_t* _mem, uint64_t _external);
    void (*update_texture_2d)(bgfx_texture_handle_t _handle, uint16_t _layer, uint8_t _mip, uint16_t _x, uint16_t _y, uint16_t _width, uint16_t _height, const bgfx_memory_t* _mem, uint16_t _pitch);
    void (*update_texture_3d)(bgfx_texture_handle_t _handle, uint8_t _mip, uint16_t _x, uint16_t _y, uint16_t _z, uint16_t _width, uint16_t _height, uint16_t _depth, const bgfx_memory_t* _mem);
    void (*update_texture_cube)(bgfx_texture_handle_t _handle, uint16_t _layer, uint8_t _side, uint8_t _mip, uint16_t _x, uint16_t _y, uint16_t _width, uint16_t _height, const bgfx_memory_t* _mem, uint16_t _pitch);
    void (*clear_texture)(bgfx_texture_handle_t _handle, uint8_t _mip, uint8_t _numMips, uint16_t _layer, uint16_t _numLayers);
    uint32_t (*read_texture)(const bgfx_texture_region_t * _src, void* _data);
    void (*set_texture_name)(bgfx_texture_handle_t _handle, const char* _name, int32_t _len);
    void* (*get_direct_access_ptr)(bgfx_texture_handle_t _handle);
    void (*destroy_texture)(bgfx_texture_handle_t _handle);
    bgfx_frame_buffer_handle_t (*create_frame_buffer)(uint16_t _width, uint16_t _height, bgfx_texture_format_t _format, uint64_t _textureFlags);
    bgfx_frame_buffer_handle_t (*create_frame_buffer_scaled)(bgfx_backbuffer_ratio_t _ratio, bgfx_texture_format_t _format, uint64_t _textureFlags);
    bgfx_frame_buffer_handle_t (*create_frame_buffer_from_handles)(uint8_t _num, const bgfx_texture_handle_t* _handles, bool _destroyTexture);
    bgfx_frame_buffer_handle_t (*create_frame_buffer_from_attachment)(uint8_t _num, const bgfx_attachment_t* _attachment, bool _destroyTexture);
    bgfx_frame_buffer_handle_t (*create_frame_buffer_from_swap_chain)(const bgfx_swap_chain_t* _desc);
    void (*update_swap_chain)(bgfx_frame_buffer_handle_t _handle, const bgfx_swap_chain_t* _desc);
    void (*set_frame_buffer_name)(bgfx_frame_buffer_handle_t _handle, const char* _name, int32_t _len);
    bgfx_texture_handle_t (*get_texture)(bgfx_frame_buffer_handle_t _handle, uint8_t _attachment);
    void (*destroy_frame_buffer)(bgfx_frame_buffer_handle_t _handle);
    bgfx_uniform_handle_t (*create_uniform)(const char* _name, bgfx_uniform_type_t _type, uint16_t _num);
    bgfx_uniform_handle_t (*create_uniform_with_freq)(const char* _name, bgfx_uniform_freq_t _freq, bgfx_uniform_type_t _type, uint16_t _num);
    void (*get_uniform_info)(bgfx_uniform_handle_t _handle, bgfx_uniform_info_t * _info);
    void (*destroy_uniform)(bgfx_uniform_handle_t _handle);
    bgfx_occlusion_query_handle_t (*create_occlusion_query)(void);
    bgfx_occlusion_query_result_t (*get_result)(bgfx_occlusion_query_handle_t _handle, int32_t* _result);
    void (*destroy_occlusion_query)(bgfx_occlusion_query_handle_t _handle);
    void (*set_palette_color)(uint8_t _index, const float _rgba[4]);
    void (*set_palette_color_rgba32f)(uint8_t _index, float _r, float _g, float _b, float _a);
    void (*set_palette_color_rgba8)(uint8_t _index, uint32_t _rgba);
    void (*set_view_name)(bgfx_view_id_t _id, const char* _name, int32_t _len);
    void (*set_view_rect)(bgfx_view_id_t _id, int16_t _x, int16_t _y, uint16_t _width, uint16_t _height, float _minDepth, float _maxDepth);
    void (*set_view_rect_ratio)(bgfx_view_id_t _id, int16_t _x, int16_t _y, bgfx_backbuffer_ratio_t _ratio);
    void (*set_view_scissor)(bgfx_view_id_t _id, uint16_t _x, uint16_t _y, uint16_t _width, uint16_t _height);
    void (*set_view_depth_bias)(bgfx_view_id_t _id, int32_t _constant, float _slopeScale, float _clamp);
    void (*set_view_sample_mask)(bgfx_view_id_t _id, uint32_t _mask);
    void (*set_view_clear)(bgfx_view_id_t _id, uint16_t _flags, uint32_t _rgba, float _depth, uint8_t _stencil);
    void (*set_view_clear_mrt)(bgfx_view_id_t _id, uint16_t _flags, float _depth, uint8_t _stencil, uint8_t _c0, uint8_t _c1, uint8_t _c2, uint8_t _c3, uint8_t _c4, uint8_t _c5, uint8_t _c6, uint8_t _c7);
    void (*set_view_mode)(bgfx_view_id_t _id, bgfx_view_mode_t _mode);
    void (*set_view_frame_buffer)(bgfx_view_id_t _id, bgfx_frame_buffer_handle_t _handle);
    void (*set_view_transform)(bgfx_view_id_t _id, const void* _view, const void* _proj);
    void (*set_view_order)(bgfx_view_id_t _id, uint16_t _num, const bgfx_view_id_t* _order);
    void (*set_view_shading_rate)(bgfx_view_id_t _id, bgfx_shading_rate_t _shadingRate);
    void (*reset_view)(bgfx_view_id_t _id);
    bgfx_encoder_t* (*encoder_begin)(bool _forceNewEncoder);
    void (*encoder_end)(bgfx_encoder_t* _encoder);
    void (*encoder_set_marker)(bgfx_encoder_t* _this, const char* _name, int32_t _len);
    void (*encoder_set_state)(bgfx_encoder_t* _this, uint64_t _state, uint32_t _rgba);
    void (*encoder_set_condition)(bgfx_encoder_t* _this, bgfx_occlusion_query_handle_t _handle, bool _visible);
    void (*encoder_set_stencil)(bgfx_encoder_t* _this, uint32_t _fstencil, uint32_t _bstencil);
    void (*encoder_set_sample_mask)(bgfx_encoder_t* _this, uint32_t _mask);
    uint16_t (*encoder_set_scissor)(bgfx_encoder_t* _this, uint16_t _x, uint16_t _y, uint16_t _width, uint16_t _height);
    void (*encoder_set_scissor_cached)(bgfx_encoder_t* _this, uint16_t _cache);
    uint16_t (*encoder_set_depth_control)(bgfx_encoder_t* _this, int32_t _constant, float _slopeScale, float _clamp, bool _depthClamp);
    void (*encoder_set_depth_control_cached)(bgfx_encoder_t* _this, uint16_t _cache);
    uint32_t (*encoder_set_transform)(bgfx_encoder_t* _this, const void* _mtx, uint16_t _num);
    void (*encoder_set_transform_cached)(bgfx_encoder_t* _this, uint32_t _cache, uint16_t _num);
    uint32_t (*encoder_alloc_transform)(bgfx_encoder_t* _this, bgfx_transform_t* _transform, uint16_t _num);
    void (*encoder_set_uniform)(bgfx_encoder_t* _this, bgfx_uniform_handle_t _handle, const void* _value, uint16_t _num);
    void (*encoder_set_uniform_ref)(bgfx_encoder_t* _this, bgfx_uniform_handle_t _handle, const void* _value, uint16_t _num);
    void (*set_view_uniform)(bgfx_view_id_t _id, bgfx_uniform_handle_t _handle, const void* _value, uint16_t _num);
    void (*set_frame_uniform)(bgfx_uniform_handle_t _handle, const void* _value, uint16_t _num);
    void (*encoder_set_index_buffer)(bgfx_encoder_t* _this, bgfx_index_buffer_handle_t _handle, uint32_t _firstIndex, uint32_t _numIndices);
    void (*encoder_set_dynamic_index_buffer)(bgfx_encoder_t* _this, bgfx_dynamic_index_buffer_handle_t _handle, uint32_t _firstIndex, uint32_t _numIndices);
    void (*encoder_set_transient_index_buffer)(bgfx_encoder_t* _this, const bgfx_transient_index_buffer_t* _tib, uint32_t _firstIndex, uint32_t _numIndices);
    void (*encoder_set_vertex_buffer)(bgfx_encoder_t* _this, uint8_t _stream, bgfx_vertex_buffer_handle_t _handle, uint32_t _startVertex, uint32_t _numVertices);
    void (*encoder_set_vertex_buffer_with_layout)(bgfx_encoder_t* _this, uint8_t _stream, bgfx_vertex_buffer_handle_t _handle, uint32_t _startVertex, uint32_t _numVertices, bgfx_vertex_layout_handle_t _layoutHandle);
    void (*encoder_set_dynamic_vertex_buffer)(bgfx_encoder_t* _this, uint8_t _stream, bgfx_dynamic_vertex_buffer_handle_t _handle, uint32_t _startVertex, uint32_t _numVertices);
    void (*encoder_set_dynamic_vertex_buffer_with_layout)(bgfx_encoder_t* _this, uint8_t _stream, bgfx_dynamic_vertex_buffer_handle_t _handle, uint32_t _startVertex, uint32_t _numVertices, bgfx_vertex_layout_handle_t _layoutHandle);
    void (*encoder_set_transient_vertex_buffer)(bgfx_encoder_t* _this, uint8_t _stream, const bgfx_transient_vertex_buffer_t* _tvb, uint32_t _startVertex, uint32_t _numVertices);
    void (*encoder_set_transient_vertex_buffer_with_layout)(bgfx_encoder_t* _this, uint8_t _stream, const bgfx_transient_vertex_buffer_t* _tvb, uint32_t _startVertex, uint32_t _numVertices, bgfx_vertex_layout_handle_t _layoutHandle);
    void (*encoder_set_vertex_count)(bgfx_encoder_t* _this, uint32_t _numVertices);
    void (*encoder_set_instance_data_buffer)(bgfx_encoder_t* _this, const bgfx_instance_data_buffer_t* _idb, uint32_t _start, uint32_t _num);
    void (*encoder_set_instance_data_from_vertex_buffer)(bgfx_encoder_t* _this, bgfx_vertex_buffer_handle_t _handle, uint32_t _startVertex, uint32_t _num);
    void (*encoder_set_instance_data_from_dynamic_vertex_buffer)(bgfx_encoder_t* _this, bgfx_dynamic_vertex_buffer_handle_t _handle, uint32_t _startVertex, uint32_t _num);
    void (*encoder_set_instance_count)(bgfx_encoder_t* _this, uint32_t _numInstances);
    void (*encoder_set_texture)(bgfx_encoder_t* _this, uint8_t _stage, bgfx_uniform_handle_t _sampler, bgfx_texture_handle_t _handle, uint32_t _flags);
    void (*encoder_set_texture_view)(bgfx_encoder_t* _this, uint8_t _stage, bgfx_uniform_handle_t _sampler, bgfx_texture_handle_t _handle, uint16_t _firstLayer, uint16_t _numLayers, uint8_t _firstMip, uint8_t _numMips, uint32_t _flags, uint8_t _lodMin, uint8_t _lodMax);
    void (*encoder_touch)(bgfx_encoder_t* _this, bgfx_view_id_t _id);
    void (*encoder_submit)(bgfx_encoder_t* _this, bgfx_view_id_t _id, bgfx_program_handle_t _program, uint32_t _depth, uint8_t _flags);
    void (*encoder_submit_occlusion_query)(bgfx_encoder_t* _this, bgfx_view_id_t _id, bgfx_program_handle_t _program, bgfx_occlusion_query_handle_t _occlusionQuery, uint32_t _depth, uint8_t _flags);
    void (*encoder_submit_indirect)(bgfx_encoder_t* _this, bgfx_view_id_t _id, bgfx_program_handle_t _program, bgfx_indirect_buffer_handle_t _indirectHandle, uint32_t _start, uint32_t _num, uint32_t _depth, uint8_t _flags);
    void (*encoder_submit_indirect_count)(bgfx_encoder_t* _this, bgfx_view_id_t _id, bgfx_program_handle_t _program, bgfx_indirect_buffer_handle_t _indirectHandle, uint32_t _start, bgfx_index_buffer_handle_t _numHandle, uint32_t _numIndex, uint32_t _numMax, uint32_t _depth, uint8_t _flags);
    void (*encoder_set_compute_index_buffer)(bgfx_encoder_t* _this, uint8_t _stage, bgfx_index_buffer_handle_t _handle, bgfx_access_t _access, uint32_t _offset, uint32_t _size);
    void (*encoder_set_compute_vertex_buffer)(bgfx_encoder_t* _this, uint8_t _stage, bgfx_vertex_buffer_handle_t _handle, bgfx_access_t _access, uint32_t _offset, uint32_t _size);
    void (*encoder_set_compute_dynamic_index_buffer)(bgfx_encoder_t* _this, uint8_t _stage, bgfx_dynamic_index_buffer_handle_t _handle, bgfx_access_t _access, uint32_t _offset, uint32_t _size);
    void (*encoder_set_compute_dynamic_vertex_buffer)(bgfx_encoder_t* _this, uint8_t _stage, bgfx_dynamic_vertex_buffer_handle_t _handle, bgfx_access_t _access, uint32_t _offset, uint32_t _size);
    void (*encoder_set_compute_indirect_buffer)(bgfx_encoder_t* _this, uint8_t _stage, bgfx_indirect_buffer_handle_t _handle, bgfx_access_t _access);
    void (*encoder_set_image)(bgfx_encoder_t* _this, uint8_t _stage, bgfx_texture_handle_t _handle, uint8_t _mip, bgfx_access_t _access, bgfx_texture_format_t _format);
    void (*encoder_set_image_view)(bgfx_encoder_t* _this, uint8_t _stage, bgfx_texture_handle_t _handle, uint16_t _firstLayer, uint16_t _numLayers, uint8_t _mip, bgfx_access_t _access, bgfx_texture_format_t _format);
    void (*encoder_dispatch)(bgfx_encoder_t* _this, bgfx_view_id_t _id, bgfx_program_handle_t _program, uint32_t _numX, uint32_t _numY, uint32_t _numZ, uint8_t _flags);
    void (*encoder_dispatch_indirect)(bgfx_encoder_t* _this, bgfx_view_id_t _id, bgfx_program_handle_t _program, bgfx_indirect_buffer_handle_t _indirectHandle, uint32_t _start, uint32_t _num, uint8_t _flags);
    void (*encoder_discard)(bgfx_encoder_t* _this, uint8_t _flags);
    void (*encoder_blit)(bgfx_encoder_t* _this, bgfx_view_id_t _id, const bgfx_texture_region_t * _dst, const bgfx_texture_region_t * _src);
    void (*encoder_blit_buffer)(bgfx_encoder_t* _this, bgfx_view_id_t _id, const bgfx_buffer_region_t * _dst, const bgfx_buffer_region_t * _src);
    void (*encoder_blit_to_buffer)(bgfx_encoder_t* _this, bgfx_view_id_t _id, const bgfx_buffer_region_t * _dst, const bgfx_texture_region_t * _src);
    void (*encoder_blit_from_buffer)(bgfx_encoder_t* _this, bgfx_view_id_t _id, const bgfx_texture_region_t * _dst, const bgfx_buffer_region_t * _src);
    void (*request_screen_shot)(bgfx_frame_buffer_handle_t _handle, const char* _filePath);
    bgfx_render_frame_t (*render_frame)(int32_t _msecs);
    const bgfx_internal_data_t* (*get_internal_data)(void);
    void (*set_marker)(const char* _name, int32_t _len);
    void (*set_state)(uint64_t _state, uint32_t _rgba);
    void (*set_condition)(bgfx_occlusion_query_handle_t _handle, bool _visible);
    void (*set_stencil)(uint32_t _fstencil, uint32_t _bstencil);
    void (*set_sample_mask)(uint32_t _mask);
    uint16_t (*set_scissor)(uint16_t _x, uint16_t _y, uint16_t _width, uint16_t _height);
    void (*set_scissor_cached)(uint16_t _cache);
    uint16_t (*set_depth_control)(int32_t _constant, float _slopeScale, float _clamp, bool _depthClamp);
    void (*set_depth_control_cached)(uint16_t _cache);
    uint32_t (*set_transform)(const void* _mtx, uint16_t _num);
    void (*set_transform_cached)(uint32_t _cache, uint16_t _num);
    uint32_t (*alloc_transform)(bgfx_transform_t* _transform, uint16_t _num);
    void (*set_uniform)(bgfx_uniform_handle_t _handle, const void* _value, uint16_t _num);
    void (*set_uniform_ref)(bgfx_uniform_handle_t _handle, const void* _value, uint16_t _num);
    void (*set_index_buffer)(bgfx_index_buffer_handle_t _handle, uint32_t _firstIndex, uint32_t _numIndices);
    void (*set_dynamic_index_buffer)(bgfx_dynamic_index_buffer_handle_t _handle, uint32_t _firstIndex, uint32_t _numIndices);
    void (*set_transient_index_buffer)(const bgfx_transient_index_buffer_t* _tib, uint32_t _firstIndex, uint32_t _numIndices);
    void (*set_vertex_buffer)(uint8_t _stream, bgfx_vertex_buffer_handle_t _handle, uint32_t _startVertex, uint32_t _numVertices);
    void (*set_vertex_buffer_with_layout)(uint8_t _stream, bgfx_vertex_buffer_handle_t _handle, uint32_t _startVertex, uint32_t _numVertices, bgfx_vertex_layout_handle_t _layoutHandle);
    void (*set_dynamic_vertex_buffer)(uint8_t _stream, bgfx_dynamic_vertex_buffer_handle_t _handle, uint32_t _startVertex, uint32_t _numVertices);
    void (*set_dynamic_vertex_buffer_with_layout)(uint8_t _stream, bgfx_dynamic_vertex_buffer_handle_t _handle, uint32_t _startVertex, uint32_t _numVertices, bgfx_vertex_layout_handle_t _layoutHandle);
    void (*set_transient_vertex_buffer)(uint8_t _stream, const bgfx_transient_vertex_buffer_t* _tvb, uint32_t _startVertex, uint32_t _numVertices);
    void (*set_transient_vertex_buffer_with_layout)(uint8_t _stream, const bgfx_transient_vertex_buffer_t* _tvb, uint32_t _startVertex, uint32_t _numVertices, bgfx_vertex_layout_handle_t _layoutHandle);
    void (*set_vertex_count)(uint32_t _numVertices);
    void (*set_instance_data_buffer)(const bgfx_instance_data_buffer_t* _idb, uint32_t _start, uint32_t _num);
    void (*set_instance_data_from_vertex_buffer)(bgfx_vertex_buffer_handle_t _handle, uint32_t _startVertex, uint32_t _num);
    void (*set_instance_data_from_dynamic_vertex_buffer)(bgfx_dynamic_vertex_buffer_handle_t _handle, uint32_t _startVertex, uint32_t _num);
    void (*set_instance_count)(uint32_t _numInstances);
    void (*set_texture)(uint8_t _stage, bgfx_uniform_handle_t _sampler, bgfx_texture_handle_t _handle, uint32_t _flags);
    void (*set_texture_view)(uint8_t _stage, bgfx_uniform_handle_t _sampler, bgfx_texture_handle_t _handle, uint16_t _firstLayer, uint16_t _numLayers, uint8_t _firstMip, uint8_t _numMips, uint32_t _flags, uint8_t _lodMin, uint8_t _lodMax);
    void (*touch)(bgfx_view_id_t _id);
    void (*submit)(bgfx_view_id_t _id, bgfx_program_handle_t _program, uint32_t _depth, uint8_t _flags);
    void (*submit_occlusion_query)(bgfx_view_id_t _id, bgfx_program_handle_t _program, bgfx_occlusion_query_handle_t _occlusionQuery, uint32_t _depth, uint8_t _flags);
    void (*submit_indirect)(bgfx_view_id_t _id, bgfx_program_handle_t _program, bgfx_indirect_buffer_handle_t _indirectHandle, uint32_t _start, uint32_t _num, uint32_t _depth, uint8_t _flags);
    void (*submit_indirect_count)(bgfx_view_id_t _id, bgfx_program_handle_t _program, bgfx_indirect_buffer_handle_t _indirectHandle, uint32_t _start, bgfx_index_buffer_handle_t _numHandle, uint32_t _numIndex, uint32_t _numMax, uint32_t _depth, uint8_t _flags);
    void (*set_compute_index_buffer)(uint8_t _stage, bgfx_index_buffer_handle_t _handle, bgfx_access_t _access, uint32_t _offset, uint32_t _size);
    void (*set_compute_vertex_buffer)(uint8_t _stage, bgfx_vertex_buffer_handle_t _handle, bgfx_access_t _access, uint32_t _offset, uint32_t _size);
    void (*set_compute_dynamic_index_buffer)(uint8_t _stage, bgfx_dynamic_index_buffer_handle_t _handle, bgfx_access_t _access, uint32_t _offset, uint32_t _size);
    void (*set_compute_dynamic_vertex_buffer)(uint8_t _stage, bgfx_dynamic_vertex_buffer_handle_t _handle, bgfx_access_t _access, uint32_t _offset, uint32_t _size);
    void (*set_compute_indirect_buffer)(uint8_t _stage, bgfx_indirect_buffer_handle_t _handle, bgfx_access_t _access);
    void (*set_image)(uint8_t _stage, bgfx_texture_handle_t _handle, uint8_t _mip, bgfx_access_t _access, bgfx_texture_format_t _format);
    void (*set_image_view)(uint8_t _stage, bgfx_texture_handle_t _handle, uint16_t _firstLayer, uint16_t _numLayers, uint8_t _mip, bgfx_access_t _access, bgfx_texture_format_t _format);
    void (*dispatch)(bgfx_view_id_t _id, bgfx_program_handle_t _program, uint32_t _numX, uint32_t _numY, uint32_t _numZ, uint8_t _flags);
    void (*dispatch_indirect)(bgfx_view_id_t _id, bgfx_program_handle_t _program, bgfx_indirect_buffer_handle_t _indirectHandle, uint32_t _start, uint32_t _num, uint8_t _flags);
    void (*discard)(uint8_t _flags);
    void (*blit)(bgfx_view_id_t _id, const bgfx_texture_region_t * _dst, const bgfx_texture_region_t * _src);
    void (*blit_buffer)(bgfx_view_id_t _id, const bgfx_buffer_region_t * _dst, const bgfx_buffer_region_t * _src);
    void (*blit_to_buffer)(bgfx_view_id_t _id, const bgfx_buffer_region_t * _dst, const bgfx_texture_region_t * _src);
    void (*blit_from_buffer)(bgfx_view_id_t _id, const bgfx_texture_region_t * _dst, const bgfx_buffer_region_t * _src);
};
typedef bgfx_interface_vtbl_t* (*PFN_BGFX_GET_INTERFACE)(uint32_t _version);
bgfx_interface_vtbl_t* bgfx_get_interface(uint32_t _version);
]])

if ffi.arch == "wasm" then
	ffi.cdef([[
	const bgfx_memory_t* clay_bgfx_ffi_copy(const void* data, uint32_t size);
	uint16_t clay_bgfx_ffi_create_texture_2d(uint16_t width, uint16_t height, bool has_mips, uint16_t num_layers, bgfx_texture_format_t format, const uint32_t* flags_words, const bgfx_memory_t* memory, uint32_t external);
	uint16_t clay_bgfx_ffi_create_texture_3d(uint16_t width, uint16_t height, uint16_t depth, bool has_mips, bgfx_texture_format_t format, const uint32_t* flags_words, const bgfx_memory_t* memory, uint32_t external);
	uint16_t clay_bgfx_ffi_create_texture_cube(uint16_t size, bool has_mips, uint16_t num_layers, bgfx_texture_format_t format, const uint32_t* flags_words, const bgfx_memory_t* memory, uint32_t external);
	uint16_t clay_bgfx_ffi_create_uniform(const char* name, bgfx_uniform_type_t type, uint16_t count);
	uint16_t clay_bgfx_ffi_create_shader(const bgfx_memory_t* memory);
	uint16_t clay_bgfx_ffi_create_program(uint16_t vertex_shader, uint16_t fragment_shader, bool destroy_shaders);
	uint16_t clay_bgfx_ffi_create_vertex_layout(const bgfx_vertex_layout_t* layout);
	uint16_t clay_bgfx_ffi_create_vertex_buffer(const bgfx_memory_t* memory, const bgfx_vertex_layout_t* layout, uint16_t flags);
	uint16_t clay_bgfx_ffi_create_index_buffer(const bgfx_memory_t* memory, uint16_t flags);
	void clay_bgfx_ffi_destroy_texture(uint16_t index);
	void clay_bgfx_ffi_update_texture_2d(uint16_t index, uint16_t layer, uint8_t mip, uint16_t x, uint16_t y, uint16_t width, uint16_t height, const bgfx_memory_t* memory, uint16_t pitch);
	void clay_bgfx_ffi_destroy_uniform(uint16_t index);
	void clay_bgfx_ffi_set_uniform(uint16_t index, const void* value, uint16_t count);
	void clay_bgfx_ffi_set_texture(uint8_t stage, uint16_t sampler, uint16_t texture, uint32_t flags);
	void clay_bgfx_ffi_set_debug(uint32_t debug, uint16_t framebuffer, uint8_t scale);
	void clay_bgfx_ffi_set_state(const uint32_t* state_words, uint32_t rgba);
	void clay_bgfx_ffi_set_index_buffer(uint16_t index, uint32_t first, uint32_t count);
	void clay_bgfx_ffi_set_vertex_buffer(uint8_t stream, uint16_t index, uint32_t start, uint32_t count);
	bool clay_bgfx_ffi_set_transient_buffers(const bgfx_vertex_layout_t* layout, const void* vertices, uint32_t vertex_count, const uint16_t* indices, uint32_t index_count);
	void clay_bgfx_ffi_submit(uint16_t view, uint16_t program, uint32_t depth, uint8_t flags);
	void clay_bgfx_ffi_destroy_program(uint16_t index);
	void clay_bgfx_ffi_destroy_vertex_buffer(uint16_t index);
	void clay_bgfx_ffi_destroy_index_buffer(uint16_t index);
	void clay_bgfx_ffi_destroy_vertex_layout(uint16_t index);
	]])
end

local bgfx_api = {}
bgfx_api.BGFX_API_VERSION = 166
bgfx_api.BGFX_STATE_WRITE_R = 1
bgfx_api.BGFX_STATE_WRITE_G = 2
bgfx_api.BGFX_STATE_WRITE_B = 4
bgfx_api.BGFX_STATE_WRITE_A = 8
bgfx_api.BGFX_STATE_WRITE_Z = 0x0000004000000000ULL
bgfx_api.BGFX_STATE_WRITE_RGB = 7
bgfx_api.BGFX_STATE_WRITE_MASK = 0x000000400000000fULL
bgfx_api.BGFX_STATE_DEPTH_TEST_LESS = 16
bgfx_api.BGFX_STATE_DEPTH_TEST_LEQUAL = 32
bgfx_api.BGFX_STATE_DEPTH_TEST_EQUAL = 48
bgfx_api.BGFX_STATE_DEPTH_TEST_GEQUAL = 64
bgfx_api.BGFX_STATE_DEPTH_TEST_GREATER = 80
bgfx_api.BGFX_STATE_DEPTH_TEST_NOTEQUAL = 96
bgfx_api.BGFX_STATE_DEPTH_TEST_NEVER = 112
bgfx_api.BGFX_STATE_DEPTH_TEST_ALWAYS = 128
bgfx_api.BGFX_STATE_DEPTH_TEST_SHIFT = 4
bgfx_api.BGFX_STATE_DEPTH_TEST_MASK = 240
bgfx_api.BGFX_STATE_BLEND_ZERO = 4096
bgfx_api.BGFX_STATE_BLEND_ONE = 8192
bgfx_api.BGFX_STATE_BLEND_SRC_COLOR = 12288
bgfx_api.BGFX_STATE_BLEND_INV_SRC_COLOR = 16384
bgfx_api.BGFX_STATE_BLEND_SRC_ALPHA = 20480
bgfx_api.BGFX_STATE_BLEND_INV_SRC_ALPHA = 24576
bgfx_api.BGFX_STATE_BLEND_DST_ALPHA = 28672
bgfx_api.BGFX_STATE_BLEND_INV_DST_ALPHA = 32768
bgfx_api.BGFX_STATE_BLEND_DST_COLOR = 36864
bgfx_api.BGFX_STATE_BLEND_INV_DST_COLOR = 40960
bgfx_api.BGFX_STATE_BLEND_SRC_ALPHA_SAT = 45056
bgfx_api.BGFX_STATE_BLEND_FACTOR = 49152
bgfx_api.BGFX_STATE_BLEND_INV_FACTOR = 53248
bgfx_api.BGFX_STATE_BLEND_SHIFT = 12
bgfx_api.BGFX_STATE_BLEND_MASK = 268431360
bgfx_api.BGFX_STATE_BLEND_EQUATION_ADD = 0
bgfx_api.BGFX_STATE_BLEND_EQUATION_SUB = 268435456
bgfx_api.BGFX_STATE_BLEND_EQUATION_REVSUB = 536870912
bgfx_api.BGFX_STATE_BLEND_EQUATION_MIN = 805306368
bgfx_api.BGFX_STATE_BLEND_EQUATION_MAX = 1073741824
bgfx_api.BGFX_STATE_BLEND_EQUATION_SHIFT = 28
bgfx_api.BGFX_STATE_BLEND_EQUATION_MASK = 0x00000003f0000000ULL
bgfx_api.BGFX_STATE_CULL_CW = 0x0000001000000000ULL
bgfx_api.BGFX_STATE_CULL_CCW = 0x0000002000000000ULL
bgfx_api.BGFX_STATE_CULL_SHIFT = 36
bgfx_api.BGFX_STATE_CULL_MASK = 0x0000003000000000ULL
bgfx_api.BGFX_STATE_ALPHA_REF_SHIFT = 40
bgfx_api.BGFX_STATE_ALPHA_REF_MASK = 0x0000ff0000000000ULL
bgfx_api.BGFX_STATE_PT_TRISTRIP = 0x0001000000000000ULL
bgfx_api.BGFX_STATE_PT_LINES = 0x0002000000000000ULL
bgfx_api.BGFX_STATE_PT_LINESTRIP = 0x0003000000000000ULL
bgfx_api.BGFX_STATE_PT_POINTS = 0x0004000000000000ULL
bgfx_api.BGFX_STATE_PT_SHIFT = 48
bgfx_api.BGFX_STATE_PT_MASK = 0x0007000000000000ULL
bgfx_api.BGFX_STATE_POINT_SIZE_SHIFT = 52
bgfx_api.BGFX_STATE_POINT_SIZE_MASK = 0x00f0000000000000ULL
bgfx_api.BGFX_STATE_MSAA = 0x0100000000000000ULL
bgfx_api.BGFX_STATE_LINEAA = 0x0200000000000000ULL
bgfx_api.BGFX_STATE_CONSERVATIVE_RASTER = 0x0400000000000000ULL
bgfx_api.BGFX_STATE_NONE = 0
bgfx_api.BGFX_STATE_FRONT_CCW = 0x0000008000000000ULL
bgfx_api.BGFX_STATE_BLEND_INDEPENDENT = 0x0000000400000000ULL
bgfx_api.BGFX_STATE_BLEND_ALPHA_TO_COVERAGE = 0x0000000800000000ULL
bgfx_api.BGFX_STATE_DEFAULT = 0x010000500000001fULL
bgfx_api.BGFX_STATE_MASK = 0xffffffffffffffffULL
bgfx_api.BGFX_STATE_RESERVED_SHIFT = 61
bgfx_api.BGFX_STATE_RESERVED_MASK = 0xe000000000000000ULL
bgfx_api.BGFX_STENCIL_FUNC_REF_SHIFT = 0
bgfx_api.BGFX_STENCIL_FUNC_REF_MASK = 255
bgfx_api.BGFX_STENCIL_FUNC_RMASK_SHIFT = 8
bgfx_api.BGFX_STENCIL_FUNC_RMASK_MASK = 65280
bgfx_api.BGFX_STENCIL_NONE = 65280
bgfx_api.BGFX_STENCIL_MASK = 4294967295
bgfx_api.BGFX_STENCIL_TEST_LESS = 65536
bgfx_api.BGFX_STENCIL_TEST_LEQUAL = 131072
bgfx_api.BGFX_STENCIL_TEST_EQUAL = 196608
bgfx_api.BGFX_STENCIL_TEST_GEQUAL = 262144
bgfx_api.BGFX_STENCIL_TEST_GREATER = 327680
bgfx_api.BGFX_STENCIL_TEST_NOTEQUAL = 393216
bgfx_api.BGFX_STENCIL_TEST_NEVER = 458752
bgfx_api.BGFX_STENCIL_TEST_ALWAYS = 524288
bgfx_api.BGFX_STENCIL_TEST_SHIFT = 16
bgfx_api.BGFX_STENCIL_TEST_MASK = 983040
bgfx_api.BGFX_STENCIL_OP_FAIL_S_ZERO = 0
bgfx_api.BGFX_STENCIL_OP_FAIL_S_KEEP = 1048576
bgfx_api.BGFX_STENCIL_OP_FAIL_S_REPLACE = 2097152
bgfx_api.BGFX_STENCIL_OP_FAIL_S_INCR = 3145728
bgfx_api.BGFX_STENCIL_OP_FAIL_S_INCRSAT = 4194304
bgfx_api.BGFX_STENCIL_OP_FAIL_S_DECR = 5242880
bgfx_api.BGFX_STENCIL_OP_FAIL_S_DECRSAT = 6291456
bgfx_api.BGFX_STENCIL_OP_FAIL_S_INVERT = 7340032
bgfx_api.BGFX_STENCIL_OP_FAIL_S_SHIFT = 20
bgfx_api.BGFX_STENCIL_OP_FAIL_S_MASK = 15728640
bgfx_api.BGFX_STENCIL_OP_FAIL_Z_ZERO = 0
bgfx_api.BGFX_STENCIL_OP_FAIL_Z_KEEP = 16777216
bgfx_api.BGFX_STENCIL_OP_FAIL_Z_REPLACE = 33554432
bgfx_api.BGFX_STENCIL_OP_FAIL_Z_INCR = 50331648
bgfx_api.BGFX_STENCIL_OP_FAIL_Z_INCRSAT = 67108864
bgfx_api.BGFX_STENCIL_OP_FAIL_Z_DECR = 83886080
bgfx_api.BGFX_STENCIL_OP_FAIL_Z_DECRSAT = 100663296
bgfx_api.BGFX_STENCIL_OP_FAIL_Z_INVERT = 117440512
bgfx_api.BGFX_STENCIL_OP_FAIL_Z_SHIFT = 24
bgfx_api.BGFX_STENCIL_OP_FAIL_Z_MASK = 251658240
bgfx_api.BGFX_STENCIL_OP_PASS_Z_ZERO = 0
bgfx_api.BGFX_STENCIL_OP_PASS_Z_KEEP = 268435456
bgfx_api.BGFX_STENCIL_OP_PASS_Z_REPLACE = 536870912
bgfx_api.BGFX_STENCIL_OP_PASS_Z_INCR = 805306368
bgfx_api.BGFX_STENCIL_OP_PASS_Z_INCRSAT = 1073741824
bgfx_api.BGFX_STENCIL_OP_PASS_Z_DECR = 1342177280
bgfx_api.BGFX_STENCIL_OP_PASS_Z_DECRSAT = 1610612736
bgfx_api.BGFX_STENCIL_OP_PASS_Z_INVERT = 1879048192
bgfx_api.BGFX_STENCIL_OP_PASS_Z_SHIFT = 28
bgfx_api.BGFX_STENCIL_OP_PASS_Z_MASK = 4026531840
bgfx_api.BGFX_CLEAR_NONE = 0
bgfx_api.BGFX_CLEAR_COLOR = 1
bgfx_api.BGFX_CLEAR_DEPTH = 2
bgfx_api.BGFX_CLEAR_STENCIL = 4
bgfx_api.BGFX_CLEAR_DISCARD_COLOR_0 = 8
bgfx_api.BGFX_CLEAR_DISCARD_COLOR_1 = 16
bgfx_api.BGFX_CLEAR_DISCARD_COLOR_2 = 32
bgfx_api.BGFX_CLEAR_DISCARD_COLOR_3 = 64
bgfx_api.BGFX_CLEAR_DISCARD_COLOR_4 = 128
bgfx_api.BGFX_CLEAR_DISCARD_COLOR_5 = 256
bgfx_api.BGFX_CLEAR_DISCARD_COLOR_6 = 512
bgfx_api.BGFX_CLEAR_DISCARD_COLOR_7 = 1024
bgfx_api.BGFX_CLEAR_DISCARD_DEPTH = 2048
bgfx_api.BGFX_CLEAR_DISCARD_STENCIL = 4096
bgfx_api.BGFX_CLEAR_DISCARD_COLOR_MASK = 2040
bgfx_api.BGFX_CLEAR_DISCARD_MASK = 8184
bgfx_api.BGFX_DISCARD_NONE = 0
bgfx_api.BGFX_DISCARD_BINDINGS = 1
bgfx_api.BGFX_DISCARD_INDEX_BUFFER = 2
bgfx_api.BGFX_DISCARD_INSTANCE_DATA = 4
bgfx_api.BGFX_DISCARD_STATE = 8
bgfx_api.BGFX_DISCARD_TRANSFORM = 16
bgfx_api.BGFX_DISCARD_VERTEX_STREAMS = 32
bgfx_api.BGFX_DISCARD_ALL = 255
bgfx_api.BGFX_DEBUG_NONE = 0
bgfx_api.BGFX_DEBUG_WIREFRAME = 1
bgfx_api.BGFX_DEBUG_IFH = 2
bgfx_api.BGFX_DEBUG_STATS = 4
bgfx_api.BGFX_DEBUG_TEXT = 8
bgfx_api.BGFX_DEBUG_PROFILER = 16
bgfx_api.BGFX_BUFFER_NONE = 0
bgfx_api.BGFX_BUFFER_COMPUTE_READ = 256
bgfx_api.BGFX_BUFFER_COMPUTE_WRITE = 512
bgfx_api.BGFX_BUFFER_DRAW_INDIRECT = 1024
bgfx_api.BGFX_BUFFER_ALLOW_RESIZE = 2048
bgfx_api.BGFX_BUFFER_INDEX32 = 4096
bgfx_api.BGFX_BUFFER_COMPUTE_READ_WRITE = 768
bgfx_api.BGFX_TEXTURE_NONE = 0
bgfx_api.BGFX_TEXTURE_MSAA_SAMPLE = 0x0000000800000000ULL
bgfx_api.BGFX_TEXTURE_RT = 0x0000001000000000ULL
bgfx_api.BGFX_TEXTURE_COMPUTE_WRITE = 0x0000100000000000ULL
bgfx_api.BGFX_TEXTURE_SRGB = 0x0000200000000000ULL
bgfx_api.BGFX_TEXTURE_BLIT_DST = 0x0000400000000000ULL
bgfx_api.BGFX_TEXTURE_READ_BACK = 0x0000800000000000ULL
bgfx_api.BGFX_TEXTURE_EXTERNAL_SHARED = 0x0001000000000000ULL
bgfx_api.BGFX_TEXTURE_SRGB_MUTABLE = 0x0040000000000000ULL
bgfx_api.BGFX_TEXTURE_RESERVED_SHIFT = 60
bgfx_api.BGFX_TEXTURE_RESERVED_MASK = 0xf000000000000000ULL
bgfx_api.BGFX_TEXTURE_RT_MSAA_X2 = 0x0000002000000000ULL
bgfx_api.BGFX_TEXTURE_RT_MSAA_X4 = 0x0000003000000000ULL
bgfx_api.BGFX_TEXTURE_RT_MSAA_X8 = 0x0000004000000000ULL
bgfx_api.BGFX_TEXTURE_RT_MSAA_X16 = 0x0000005000000000ULL
bgfx_api.BGFX_TEXTURE_RT_MSAA_SHIFT = 36
bgfx_api.BGFX_TEXTURE_RT_MSAA_MASK = 0x0000007000000000ULL
bgfx_api.BGFX_TEXTURE_RT_WRITE_ONLY = 0x0000008000000000ULL
bgfx_api.BGFX_TEXTURE_RT_SHIFT = 36
bgfx_api.BGFX_TEXTURE_RT_MASK = 0x000000f000000000ULL
bgfx_api.BGFX_TEXTURE_MIP_COUNT_SHIFT = 49
bgfx_api.BGFX_TEXTURE_MIP_COUNT_MASK = 0x003e000000000000ULL
bgfx_api.BGFX_SAMPLER_U_MIRROR = 1
bgfx_api.BGFX_SAMPLER_U_CLAMP = 2
bgfx_api.BGFX_SAMPLER_U_BORDER = 3
bgfx_api.BGFX_SAMPLER_U_SHIFT = 0
bgfx_api.BGFX_SAMPLER_U_MASK = 3
bgfx_api.BGFX_SAMPLER_V_MIRROR = 4
bgfx_api.BGFX_SAMPLER_V_CLAMP = 8
bgfx_api.BGFX_SAMPLER_V_BORDER = 12
bgfx_api.BGFX_SAMPLER_V_SHIFT = 2
bgfx_api.BGFX_SAMPLER_V_MASK = 12
bgfx_api.BGFX_SAMPLER_W_MIRROR = 16
bgfx_api.BGFX_SAMPLER_W_CLAMP = 32
bgfx_api.BGFX_SAMPLER_W_BORDER = 48
bgfx_api.BGFX_SAMPLER_W_SHIFT = 4
bgfx_api.BGFX_SAMPLER_W_MASK = 48
bgfx_api.BGFX_SAMPLER_MIN_POINT = 64
bgfx_api.BGFX_SAMPLER_MIN_ANISOTROPIC = 128
bgfx_api.BGFX_SAMPLER_MIN_SHIFT = 6
bgfx_api.BGFX_SAMPLER_MIN_MASK = 192
bgfx_api.BGFX_SAMPLER_MAG_POINT = 256
bgfx_api.BGFX_SAMPLER_MAG_ANISOTROPIC = 512
bgfx_api.BGFX_SAMPLER_MAG_SHIFT = 8
bgfx_api.BGFX_SAMPLER_MAG_MASK = 768
bgfx_api.BGFX_SAMPLER_MIP_POINT = 1024
bgfx_api.BGFX_SAMPLER_MIP_SHIFT = 10
bgfx_api.BGFX_SAMPLER_MIP_MASK = 1024
bgfx_api.BGFX_SAMPLER_COMPARE_LESS = 65536
bgfx_api.BGFX_SAMPLER_COMPARE_LEQUAL = 131072
bgfx_api.BGFX_SAMPLER_COMPARE_EQUAL = 196608
bgfx_api.BGFX_SAMPLER_COMPARE_GEQUAL = 262144
bgfx_api.BGFX_SAMPLER_COMPARE_GREATER = 327680
bgfx_api.BGFX_SAMPLER_COMPARE_NOTEQUAL = 393216
bgfx_api.BGFX_SAMPLER_COMPARE_NEVER = 458752
bgfx_api.BGFX_SAMPLER_COMPARE_ALWAYS = 524288
bgfx_api.BGFX_SAMPLER_COMPARE_SHIFT = 16
bgfx_api.BGFX_SAMPLER_COMPARE_MASK = 983040
bgfx_api.BGFX_SAMPLER_BORDER_COLOR_SHIFT = 24
bgfx_api.BGFX_SAMPLER_BORDER_COLOR_MASK = 251658240
bgfx_api.BGFX_SAMPLER_RESERVED_SHIFT = 28
bgfx_api.BGFX_SAMPLER_RESERVED_MASK = 4026531840
bgfx_api.BGFX_SAMPLER_NONE = 0
bgfx_api.BGFX_SAMPLER_SAMPLE_STENCIL = 1048576
bgfx_api.BGFX_SAMPLER_SRGB = 2097152
bgfx_api.BGFX_SAMPLER_POINT = 1344
bgfx_api.BGFX_SAMPLER_UVW_MIRROR = 21
bgfx_api.BGFX_SAMPLER_UVW_CLAMP = 42
bgfx_api.BGFX_SAMPLER_UVW_BORDER = 63
bgfx_api.BGFX_SAMPLER_BITS_MASK = 985087
bgfx_api.BGFX_RESET_MSAA_X2 = 16
bgfx_api.BGFX_RESET_MSAA_X4 = 32
bgfx_api.BGFX_RESET_MSAA_X8 = 48
bgfx_api.BGFX_RESET_MSAA_X16 = 64
bgfx_api.BGFX_RESET_MSAA_SHIFT = 4
bgfx_api.BGFX_RESET_MSAA_MASK = 112
bgfx_api.BGFX_RESET_NONE = 0
bgfx_api.BGFX_RESET_FULLSCREEN = 1
bgfx_api.BGFX_RESET_VSYNC = 128
bgfx_api.BGFX_RESET_MAXANISOTROPY = 256
bgfx_api.BGFX_RESET_CAPTURE = 512
bgfx_api.BGFX_RESET_FLUSH_AFTER_RENDER = 8192
bgfx_api.BGFX_RESET_FLIP_AFTER_RENDER = 16384
bgfx_api.BGFX_RESET_SRGB_BACKBUFFER = 32768
bgfx_api.BGFX_RESET_HDR10 = 65536
bgfx_api.BGFX_RESET_HIDPI = 131072
bgfx_api.BGFX_RESET_SUSPEND = 524288
bgfx_api.BGFX_RESET_TRANSPARENT_BACKBUFFER = 1048576
bgfx_api.BGFX_RESET_LOW_LATENCY_ON = 1024
bgfx_api.BGFX_RESET_LOW_LATENCY_BOOST = 2048
bgfx_api.BGFX_RESET_LOW_LATENCY_SHIFT = 10
bgfx_api.BGFX_RESET_LOW_LATENCY_MASK = 3072
bgfx_api.BGFX_RESET_FULLSCREEN_SHIFT = 0
bgfx_api.BGFX_RESET_FULLSCREEN_MASK = 1
bgfx_api.BGFX_RESET_RESERVED_SHIFT = 31
bgfx_api.BGFX_RESET_RESERVED_MASK = 2147483648
bgfx_api.BGFX_SWAP_CHAIN_MSAA_X2 = 16
bgfx_api.BGFX_SWAP_CHAIN_MSAA_X4 = 32
bgfx_api.BGFX_SWAP_CHAIN_MSAA_X8 = 48
bgfx_api.BGFX_SWAP_CHAIN_MSAA_X16 = 64
bgfx_api.BGFX_SWAP_CHAIN_MSAA_SHIFT = 4
bgfx_api.BGFX_SWAP_CHAIN_MSAA_MASK = 112
bgfx_api.BGFX_SWAP_CHAIN_NONE = 0
bgfx_api.BGFX_SWAP_CHAIN_FULLSCREEN = 1
bgfx_api.BGFX_SWAP_CHAIN_SRGB_BACKBUFFER = 32768
bgfx_api.BGFX_SWAP_CHAIN_HDR10 = 65536
bgfx_api.BGFX_SWAP_CHAIN_HIDPI = 131072
bgfx_api.BGFX_SWAP_CHAIN_TRANSPARENT_BACKBUFFER = 1048576
bgfx_api.BGFX_SWAP_CHAIN_FULLSCREEN_SHIFT = 0
bgfx_api.BGFX_SWAP_CHAIN_FULLSCREEN_MASK = 1
bgfx_api.BGFX_CAPS_BLEND_INDEPENDENT = 1
bgfx_api.BGFX_CAPS_COMPUTE = 2
bgfx_api.BGFX_CAPS_CONSERVATIVE_RASTER = 4
bgfx_api.BGFX_CAPS_DRAW_INDIRECT = 8
bgfx_api.BGFX_CAPS_DRAW_INDIRECT_COUNT = 16
bgfx_api.BGFX_CAPS_FRAGMENT_ORDERING = 32
bgfx_api.BGFX_CAPS_GRAPHICS_DEBUGGER = 64
bgfx_api.BGFX_CAPS_HDR10 = 128
bgfx_api.BGFX_CAPS_IMAGE_RW = 256
bgfx_api.BGFX_CAPS_INDEX32 = 512
bgfx_api.BGFX_CAPS_LOW_LATENCY = 1024
bgfx_api.BGFX_CAPS_PRIMITIVE_ID = 2048
bgfx_api.BGFX_CAPS_RENDERER_MULTITHREADED = 4096
bgfx_api.BGFX_CAPS_SHADER_F16 = 8192
bgfx_api.BGFX_CAPS_SWAP_CHAIN = 16384
bgfx_api.BGFX_CAPS_TEXTURE_CUBE_ARRAY = 32768
bgfx_api.BGFX_CAPS_TEXTURE_DIRECT_ACCESS = 65536
bgfx_api.BGFX_CAPS_TEXTURE_EXTERNAL = 131072
bgfx_api.BGFX_CAPS_TEXTURE_EXTERNAL_SHARED = 262144
bgfx_api.BGFX_CAPS_TRANSPARENT_BACKBUFFER = 524288
bgfx_api.BGFX_CAPS_VARIABLE_RATE_SHADING = 1048576
bgfx_api.BGFX_CAPS_VERTEX_ATTRIB_UINT10 = 2097152
bgfx_api.BGFX_CAPS_VIDEO_DECODE = 4194304
bgfx_api.BGFX_CAPS_VIEWPORT_LAYER_ARRAY = 8388608
bgfx_api.BGFX_CAPS_FORMAT_TEXTURE_NONE = 0
bgfx_api.BGFX_CAPS_FORMAT_TEXTURE_2D = 1
bgfx_api.BGFX_CAPS_FORMAT_TEXTURE_2D_SRGB = 2
bgfx_api.BGFX_CAPS_FORMAT_TEXTURE_2D_EMULATED = 4
bgfx_api.BGFX_CAPS_FORMAT_TEXTURE_3D = 8
bgfx_api.BGFX_CAPS_FORMAT_TEXTURE_3D_SRGB = 16
bgfx_api.BGFX_CAPS_FORMAT_TEXTURE_3D_EMULATED = 32
bgfx_api.BGFX_CAPS_FORMAT_TEXTURE_CUBE = 64
bgfx_api.BGFX_CAPS_FORMAT_TEXTURE_CUBE_SRGB = 128
bgfx_api.BGFX_CAPS_FORMAT_TEXTURE_CUBE_EMULATED = 256
bgfx_api.BGFX_CAPS_FORMAT_TEXTURE_VERTEX = 512
bgfx_api.BGFX_CAPS_FORMAT_TEXTURE_IMAGE_READ = 1024
bgfx_api.BGFX_CAPS_FORMAT_TEXTURE_IMAGE_WRITE = 2048
bgfx_api.BGFX_CAPS_FORMAT_TEXTURE_FRAMEBUFFER = 4096
bgfx_api.BGFX_CAPS_FORMAT_TEXTURE_FRAMEBUFFER_MSAA = 8192
bgfx_api.BGFX_CAPS_FORMAT_TEXTURE_MSAA = 16384
bgfx_api.BGFX_CAPS_FORMAT_TEXTURE_MIP_AUTOGEN = 32768
bgfx_api.BGFX_CAPS_FORMAT_TEXTURE_BACKBUFFER = 65536
bgfx_api.BGFX_CAPS_FORMAT_TEXTURE_VIDEO_DECODE_DST = 131072
bgfx_api.BGFX_CAPS_VIDEO_CODEC_NONE = 0
bgfx_api.BGFX_CAPS_VIDEO_CODEC_BIT_8 = 1
bgfx_api.BGFX_CAPS_VIDEO_CODEC_BIT_10 = 2
bgfx_api.BGFX_CAPS_VIDEO_CODEC_BIT_12 = 4
bgfx_api.BGFX_CAPS_VIDEO_CODEC_CHROMA_420 = 8
bgfx_api.BGFX_CAPS_VIDEO_CODEC_CHROMA_422 = 16
bgfx_api.BGFX_CAPS_VIDEO_CODEC_CHROMA_444 = 32
bgfx_api.BGFX_VIDEO_DECODER_INIT_NONE = 0
bgfx_api.BGFX_VIDEO_DECODER_INIT_RETAIN = 1
bgfx_api.BGFX_VIDEO_DECODE_FRAME_NONE = 0
bgfx_api.BGFX_VIDEO_DECODE_FRAME_SET = 1
bgfx_api.BGFX_VIDEO_DECODE_FRAME_NO_BLIT = 2
bgfx_api.BGFX_VIDEO_DECODE_FRAME_FINAL = 4
bgfx_api.BGFX_VIDEO_DECODE_FRAME_LOOP = 8
bgfx_api.BGFX_ATTACHMENT_NONE = 0
bgfx_api.BGFX_ATTACHMENT_AUTO_GEN_MIPS = 1
bgfx_api.BGFX_ATTACHMENT_READ_ONLY_DEPTH = 2
bgfx_api.BGFX_ATTACHMENT_READ_ONLY_STENCIL = 4
bgfx_api.BGFX_ATTACHMENT_SRGB = 8
bgfx_api.BGFX_PCI_ID_NONE = 0
bgfx_api.BGFX_PCI_ID_SOFTWARE_RASTERIZER = 1
bgfx_api.BGFX_PCI_ID_AMD = 4098
bgfx_api.BGFX_PCI_ID_APPLE = 4203
bgfx_api.BGFX_PCI_ID_INTEL = 32902
bgfx_api.BGFX_PCI_ID_NVIDIA = 4318
bgfx_api.BGFX_PCI_ID_MICROSOFT = 5140
bgfx_api.BGFX_PCI_ID_ARM = 5045
bgfx_api.BGFX_CUBE_MAP_POSITIVE_X = 0
bgfx_api.BGFX_CUBE_MAP_NEGATIVE_X = 1
bgfx_api.BGFX_CUBE_MAP_POSITIVE_Y = 2
bgfx_api.BGFX_CUBE_MAP_NEGATIVE_Y = 3
bgfx_api.BGFX_CUBE_MAP_POSITIVE_Z = 4
bgfx_api.BGFX_CUBE_MAP_NEGATIVE_Z = 5
bgfx_api.BGFX_FRAME_NONE = 0
bgfx_api.BGFX_FRAME_DEBUG_CAPTURE = 1
bgfx_api.BGFX_FRAME_DISCARD = 2
bgfx_api.BGFX_FRAME_FLUSH = 4
bgfx_api.BGFX_STATE_BLEND_ADD = 35790848
bgfx_api.BGFX_STATE_BLEND_ALPHA = 106319872
bgfx_api.BGFX_STATE_BLEND_DARKEN = 0x00000001b2222000ULL
bgfx_api.BGFX_STATE_BLEND_LIGHTEN = 0x0000000242222000ULL
bgfx_api.BGFX_STATE_BLEND_MULTIPLY = 26316800
bgfx_api.BGFX_STATE_BLEND_NORMAL = 103161856
bgfx_api.BGFX_STATE_BLEND_SCREEN = 69476352
bgfx_api.BGFX_STATE_BLEND_LINEAR_BURN = 2593820672
bgfx_api.BGFX_FATAL_DEBUG_CHECK = 0
bgfx_api.BGFX_FATAL_INVALID_SHADER = 1
bgfx_api.BGFX_FATAL_UNABLE_TO_INITIALIZE = 2
bgfx_api.BGFX_FATAL_UNABLE_TO_CREATE_TEXTURE = 3
bgfx_api.BGFX_FATAL_DEVICE_LOST = 4
bgfx_api.BGFX_FATAL_COUNT = 5
bgfx_api.BGFX_RENDERER_TYPE_NOOP = 0
bgfx_api.BGFX_RENDERER_TYPE_AGC = 1
bgfx_api.BGFX_RENDERER_TYPE_DIRECT3D11 = 2
bgfx_api.BGFX_RENDERER_TYPE_DIRECT3D12 = 3
bgfx_api.BGFX_RENDERER_TYPE_GNM = 4
bgfx_api.BGFX_RENDERER_TYPE_METAL = 5
bgfx_api.BGFX_RENDERER_TYPE_NVN = 6
bgfx_api.BGFX_RENDERER_TYPE_OPENGLES = 7
bgfx_api.BGFX_RENDERER_TYPE_OPENGL = 8
bgfx_api.BGFX_RENDERER_TYPE_VULKAN = 9
bgfx_api.BGFX_RENDERER_TYPE_WEBGPU = 10
bgfx_api.BGFX_RENDERER_TYPE_COUNT = 11
bgfx_api.BGFX_ACCESS_READ = 0
bgfx_api.BGFX_ACCESS_WRITE = 1
bgfx_api.BGFX_ACCESS_READWRITE = 2
bgfx_api.BGFX_ACCESS_COUNT = 3
bgfx_api.BGFX_ATTRIB_POSITION = 0
bgfx_api.BGFX_ATTRIB_NORMAL = 1
bgfx_api.BGFX_ATTRIB_TANGENT = 2
bgfx_api.BGFX_ATTRIB_BITANGENT = 3
bgfx_api.BGFX_ATTRIB_COLOR0 = 4
bgfx_api.BGFX_ATTRIB_COLOR1 = 5
bgfx_api.BGFX_ATTRIB_COLOR2 = 6
bgfx_api.BGFX_ATTRIB_COLOR3 = 7
bgfx_api.BGFX_ATTRIB_INDICES = 8
bgfx_api.BGFX_ATTRIB_WEIGHT = 9
bgfx_api.BGFX_ATTRIB_TEXCOORD0 = 10
bgfx_api.BGFX_ATTRIB_TEXCOORD1 = 11
bgfx_api.BGFX_ATTRIB_TEXCOORD2 = 12
bgfx_api.BGFX_ATTRIB_TEXCOORD3 = 13
bgfx_api.BGFX_ATTRIB_TEXCOORD4 = 14
bgfx_api.BGFX_ATTRIB_TEXCOORD5 = 15
bgfx_api.BGFX_ATTRIB_TEXCOORD6 = 16
bgfx_api.BGFX_ATTRIB_TEXCOORD7 = 17
bgfx_api.BGFX_ATTRIB_TEXCOORD8 = 18
bgfx_api.BGFX_ATTRIB_TEXCOORD9 = 19
bgfx_api.BGFX_ATTRIB_TEXCOORD10 = 20
bgfx_api.BGFX_ATTRIB_TEXCOORD11 = 21
bgfx_api.BGFX_ATTRIB_TEXCOORD12 = 22
bgfx_api.BGFX_ATTRIB_TEXCOORD13 = 23
bgfx_api.BGFX_ATTRIB_TEXCOORD14 = 24
bgfx_api.BGFX_ATTRIB_TEXCOORD15 = 25
bgfx_api.BGFX_ATTRIB_COUNT = 26
bgfx_api.BGFX_ATTRIB_TYPE_INT8 = 0
bgfx_api.BGFX_ATTRIB_TYPE_UINT8 = 1
bgfx_api.BGFX_ATTRIB_TYPE_UINT10 = 2
bgfx_api.BGFX_ATTRIB_TYPE_INT16 = 3
bgfx_api.BGFX_ATTRIB_TYPE_UINT16 = 4
bgfx_api.BGFX_ATTRIB_TYPE_HALF = 5
bgfx_api.BGFX_ATTRIB_TYPE_FLOAT = 6
bgfx_api.BGFX_ATTRIB_TYPE_INT32 = 7
bgfx_api.BGFX_ATTRIB_TYPE_UINT32 = 8
bgfx_api.BGFX_ATTRIB_TYPE_COUNT = 9
bgfx_api.BGFX_TEXTURE_FORMAT_BC1 = 0
bgfx_api.BGFX_TEXTURE_FORMAT_BC2 = 1
bgfx_api.BGFX_TEXTURE_FORMAT_BC3 = 2
bgfx_api.BGFX_TEXTURE_FORMAT_BC4 = 3
bgfx_api.BGFX_TEXTURE_FORMAT_BC4S = 4
bgfx_api.BGFX_TEXTURE_FORMAT_BC5 = 5
bgfx_api.BGFX_TEXTURE_FORMAT_BC5S = 6
bgfx_api.BGFX_TEXTURE_FORMAT_BC6H = 7
bgfx_api.BGFX_TEXTURE_FORMAT_BC6HU = 8
bgfx_api.BGFX_TEXTURE_FORMAT_BC7 = 9
bgfx_api.BGFX_TEXTURE_FORMAT_ETC1 = 10
bgfx_api.BGFX_TEXTURE_FORMAT_ETC2 = 11
bgfx_api.BGFX_TEXTURE_FORMAT_ETC2A = 12
bgfx_api.BGFX_TEXTURE_FORMAT_ETC2A1 = 13
bgfx_api.BGFX_TEXTURE_FORMAT_EACR11 = 14
bgfx_api.BGFX_TEXTURE_FORMAT_EACR11S = 15
bgfx_api.BGFX_TEXTURE_FORMAT_EACRG11 = 16
bgfx_api.BGFX_TEXTURE_FORMAT_EACRG11S = 17
bgfx_api.BGFX_TEXTURE_FORMAT_PTC12 = 18
bgfx_api.BGFX_TEXTURE_FORMAT_PTC14 = 19
bgfx_api.BGFX_TEXTURE_FORMAT_PTC12A = 20
bgfx_api.BGFX_TEXTURE_FORMAT_PTC14A = 21
bgfx_api.BGFX_TEXTURE_FORMAT_PTC22 = 22
bgfx_api.BGFX_TEXTURE_FORMAT_PTC24 = 23
bgfx_api.BGFX_TEXTURE_FORMAT_ATC = 24
bgfx_api.BGFX_TEXTURE_FORMAT_ATCE = 25
bgfx_api.BGFX_TEXTURE_FORMAT_ATCI = 26
bgfx_api.BGFX_TEXTURE_FORMAT_ASTC4X4 = 27
bgfx_api.BGFX_TEXTURE_FORMAT_ASTC5X4 = 28
bgfx_api.BGFX_TEXTURE_FORMAT_ASTC5X5 = 29
bgfx_api.BGFX_TEXTURE_FORMAT_ASTC6X5 = 30
bgfx_api.BGFX_TEXTURE_FORMAT_ASTC6X6 = 31
bgfx_api.BGFX_TEXTURE_FORMAT_ASTC8X5 = 32
bgfx_api.BGFX_TEXTURE_FORMAT_ASTC8X6 = 33
bgfx_api.BGFX_TEXTURE_FORMAT_ASTC8X8 = 34
bgfx_api.BGFX_TEXTURE_FORMAT_ASTC10X5 = 35
bgfx_api.BGFX_TEXTURE_FORMAT_ASTC10X6 = 36
bgfx_api.BGFX_TEXTURE_FORMAT_ASTC10X8 = 37
bgfx_api.BGFX_TEXTURE_FORMAT_ASTC10X10 = 38
bgfx_api.BGFX_TEXTURE_FORMAT_ASTC12X10 = 39
bgfx_api.BGFX_TEXTURE_FORMAT_ASTC12X12 = 40
bgfx_api.BGFX_TEXTURE_FORMAT_UNKNOWN = 41
bgfx_api.BGFX_TEXTURE_FORMAT_R1 = 42
bgfx_api.BGFX_TEXTURE_FORMAT_A8 = 43
bgfx_api.BGFX_TEXTURE_FORMAT_R8 = 44
bgfx_api.BGFX_TEXTURE_FORMAT_R8I = 45
bgfx_api.BGFX_TEXTURE_FORMAT_R8U = 46
bgfx_api.BGFX_TEXTURE_FORMAT_R8S = 47
bgfx_api.BGFX_TEXTURE_FORMAT_R16 = 48
bgfx_api.BGFX_TEXTURE_FORMAT_R16I = 49
bgfx_api.BGFX_TEXTURE_FORMAT_R16U = 50
bgfx_api.BGFX_TEXTURE_FORMAT_R16F = 51
bgfx_api.BGFX_TEXTURE_FORMAT_R16S = 52
bgfx_api.BGFX_TEXTURE_FORMAT_R32I = 53
bgfx_api.BGFX_TEXTURE_FORMAT_R32U = 54
bgfx_api.BGFX_TEXTURE_FORMAT_R32F = 55
bgfx_api.BGFX_TEXTURE_FORMAT_RG8 = 56
bgfx_api.BGFX_TEXTURE_FORMAT_RG8I = 57
bgfx_api.BGFX_TEXTURE_FORMAT_RG8U = 58
bgfx_api.BGFX_TEXTURE_FORMAT_RG8S = 59
bgfx_api.BGFX_TEXTURE_FORMAT_RG16 = 60
bgfx_api.BGFX_TEXTURE_FORMAT_RG16I = 61
bgfx_api.BGFX_TEXTURE_FORMAT_RG16U = 62
bgfx_api.BGFX_TEXTURE_FORMAT_RG16F = 63
bgfx_api.BGFX_TEXTURE_FORMAT_RG16S = 64
bgfx_api.BGFX_TEXTURE_FORMAT_RG32I = 65
bgfx_api.BGFX_TEXTURE_FORMAT_RG32U = 66
bgfx_api.BGFX_TEXTURE_FORMAT_RG32F = 67
bgfx_api.BGFX_TEXTURE_FORMAT_RGB8 = 68
bgfx_api.BGFX_TEXTURE_FORMAT_RGB8I = 69
bgfx_api.BGFX_TEXTURE_FORMAT_RGB8U = 70
bgfx_api.BGFX_TEXTURE_FORMAT_RGB8S = 71
bgfx_api.BGFX_TEXTURE_FORMAT_RGB9E5F = 72
bgfx_api.BGFX_TEXTURE_FORMAT_BGRA8 = 73
bgfx_api.BGFX_TEXTURE_FORMAT_RGBA8 = 74
bgfx_api.BGFX_TEXTURE_FORMAT_RGBA8I = 75
bgfx_api.BGFX_TEXTURE_FORMAT_RGBA8U = 76
bgfx_api.BGFX_TEXTURE_FORMAT_RGBA8S = 77
bgfx_api.BGFX_TEXTURE_FORMAT_RGBA16 = 78
bgfx_api.BGFX_TEXTURE_FORMAT_RGBA16I = 79
bgfx_api.BGFX_TEXTURE_FORMAT_RGBA16U = 80
bgfx_api.BGFX_TEXTURE_FORMAT_RGBA16F = 81
bgfx_api.BGFX_TEXTURE_FORMAT_RGBA16S = 82
bgfx_api.BGFX_TEXTURE_FORMAT_RGBA32I = 83
bgfx_api.BGFX_TEXTURE_FORMAT_RGBA32U = 84
bgfx_api.BGFX_TEXTURE_FORMAT_RGBA32F = 85
bgfx_api.BGFX_TEXTURE_FORMAT_B5G6R5 = 86
bgfx_api.BGFX_TEXTURE_FORMAT_R5G6B5 = 87
bgfx_api.BGFX_TEXTURE_FORMAT_BGRA4 = 88
bgfx_api.BGFX_TEXTURE_FORMAT_RGBA4 = 89
bgfx_api.BGFX_TEXTURE_FORMAT_BGR5A1 = 90
bgfx_api.BGFX_TEXTURE_FORMAT_RGB5A1 = 91
bgfx_api.BGFX_TEXTURE_FORMAT_RGB10A2 = 92
bgfx_api.BGFX_TEXTURE_FORMAT_RGB10A2U = 93
bgfx_api.BGFX_TEXTURE_FORMAT_RG11B10F = 94
bgfx_api.BGFX_TEXTURE_FORMAT_UNKNOWNDEPTH = 95
bgfx_api.BGFX_TEXTURE_FORMAT_D16 = 96
bgfx_api.BGFX_TEXTURE_FORMAT_D24 = 97
bgfx_api.BGFX_TEXTURE_FORMAT_D24S8 = 98
bgfx_api.BGFX_TEXTURE_FORMAT_D32 = 99
bgfx_api.BGFX_TEXTURE_FORMAT_D16F = 100
bgfx_api.BGFX_TEXTURE_FORMAT_D24F = 101
bgfx_api.BGFX_TEXTURE_FORMAT_D32F = 102
bgfx_api.BGFX_TEXTURE_FORMAT_D32FS8 = 103
bgfx_api.BGFX_TEXTURE_FORMAT_D0S8 = 104
bgfx_api.BGFX_TEXTURE_FORMAT_COUNT = 105
bgfx_api.BGFX_UNIFORM_TYPE_SAMPLER = 0
bgfx_api.BGFX_UNIFORM_TYPE_END = 1
bgfx_api.BGFX_UNIFORM_TYPE_VEC4 = 2
bgfx_api.BGFX_UNIFORM_TYPE_MAT3 = 3
bgfx_api.BGFX_UNIFORM_TYPE_MAT4 = 4
bgfx_api.BGFX_UNIFORM_TYPE_COUNT = 5
bgfx_api.BGFX_UNIFORM_FREQ_DRAW = 0
bgfx_api.BGFX_UNIFORM_FREQ_VIEW = 1
bgfx_api.BGFX_UNIFORM_FREQ_FRAME = 2
bgfx_api.BGFX_UNIFORM_FREQ_COUNT = 3
bgfx_api.BGFX_BACKBUFFER_RATIO_EQUAL = 0
bgfx_api.BGFX_BACKBUFFER_RATIO_HALF = 1
bgfx_api.BGFX_BACKBUFFER_RATIO_QUARTER = 2
bgfx_api.BGFX_BACKBUFFER_RATIO_EIGHTH = 3
bgfx_api.BGFX_BACKBUFFER_RATIO_SIXTEENTH = 4
bgfx_api.BGFX_BACKBUFFER_RATIO_DOUBLE = 5
bgfx_api.BGFX_BACKBUFFER_RATIO_COUNT = 6
bgfx_api.BGFX_OCCLUSION_QUERY_RESULT_INVISIBLE = 0
bgfx_api.BGFX_OCCLUSION_QUERY_RESULT_VISIBLE = 1
bgfx_api.BGFX_OCCLUSION_QUERY_RESULT_NORESULT = 2
bgfx_api.BGFX_OCCLUSION_QUERY_RESULT_COUNT = 3
bgfx_api.BGFX_VIDEO_CODEC_H264 = 0
bgfx_api.BGFX_VIDEO_CODEC_H265 = 1
bgfx_api.BGFX_VIDEO_CODEC_AV1 = 2
bgfx_api.BGFX_VIDEO_CODEC_COUNT = 3
bgfx_api.BGFX_TOPOLOGY_TRI_LIST = 0
bgfx_api.BGFX_TOPOLOGY_TRI_STRIP = 1
bgfx_api.BGFX_TOPOLOGY_LINE_LIST = 2
bgfx_api.BGFX_TOPOLOGY_LINE_STRIP = 3
bgfx_api.BGFX_TOPOLOGY_POINT_LIST = 4
bgfx_api.BGFX_TOPOLOGY_COUNT = 5
bgfx_api.BGFX_TOPOLOGY_CONVERT_TRI_LIST_FLIP_WINDING = 0
bgfx_api.BGFX_TOPOLOGY_CONVERT_TRI_STRIP_FLIP_WINDING = 1
bgfx_api.BGFX_TOPOLOGY_CONVERT_TRI_LIST_TO_LINE_LIST = 2
bgfx_api.BGFX_TOPOLOGY_CONVERT_TRI_STRIP_TO_TRI_LIST = 3
bgfx_api.BGFX_TOPOLOGY_CONVERT_LINE_STRIP_TO_LINE_LIST = 4
bgfx_api.BGFX_TOPOLOGY_CONVERT_COUNT = 5
bgfx_api.BGFX_TOPOLOGY_SORT_DIRECTION_FRONT_TO_BACK_MIN = 0
bgfx_api.BGFX_TOPOLOGY_SORT_DIRECTION_FRONT_TO_BACK_AVG = 1
bgfx_api.BGFX_TOPOLOGY_SORT_DIRECTION_FRONT_TO_BACK_MAX = 2
bgfx_api.BGFX_TOPOLOGY_SORT_DIRECTION_BACK_TO_FRONT_MIN = 3
bgfx_api.BGFX_TOPOLOGY_SORT_DIRECTION_BACK_TO_FRONT_AVG = 4
bgfx_api.BGFX_TOPOLOGY_SORT_DIRECTION_BACK_TO_FRONT_MAX = 5
bgfx_api.BGFX_TOPOLOGY_SORT_DISTANCE_FRONT_TO_BACK_MIN = 6
bgfx_api.BGFX_TOPOLOGY_SORT_DISTANCE_FRONT_TO_BACK_AVG = 7
bgfx_api.BGFX_TOPOLOGY_SORT_DISTANCE_FRONT_TO_BACK_MAX = 8
bgfx_api.BGFX_TOPOLOGY_SORT_DISTANCE_BACK_TO_FRONT_MIN = 9
bgfx_api.BGFX_TOPOLOGY_SORT_DISTANCE_BACK_TO_FRONT_AVG = 10
bgfx_api.BGFX_TOPOLOGY_SORT_DISTANCE_BACK_TO_FRONT_MAX = 11
bgfx_api.BGFX_TOPOLOGY_SORT_COUNT = 12
bgfx_api.BGFX_VIEW_MODE_DEFAULT = 0
bgfx_api.BGFX_VIEW_MODE_SEQUENTIAL = 1
bgfx_api.BGFX_VIEW_MODE_DEPTH_ASCENDING = 2
bgfx_api.BGFX_VIEW_MODE_DEPTH_DESCENDING = 3
bgfx_api.BGFX_VIEW_MODE_COUNT = 4
bgfx_api.BGFX_SHADING_RATE_RATE_1X_1 = 0
bgfx_api.BGFX_SHADING_RATE_RATE_1X_2 = 1
bgfx_api.BGFX_SHADING_RATE_RATE_2X_1 = 2
bgfx_api.BGFX_SHADING_RATE_RATE_2X_2 = 3
bgfx_api.BGFX_SHADING_RATE_RATE_2X_4 = 4
bgfx_api.BGFX_SHADING_RATE_RATE_4X_2 = 5
bgfx_api.BGFX_SHADING_RATE_RATE_4X_4 = 6
bgfx_api.BGFX_SHADING_RATE_COUNT = 7
bgfx_api.BGFX_NATIVE_WINDOW_HANDLE_TYPE_DEFAULT = 0
bgfx_api.BGFX_NATIVE_WINDOW_HANDLE_TYPE_WAYLAND = 1
bgfx_api.BGFX_NATIVE_WINDOW_HANDLE_TYPE_COUNT = 2
bgfx_api.BGFX_RENDER_FRAME_NO_CONTEXT = 0
bgfx_api.BGFX_RENDER_FRAME_RENDER = 1
bgfx_api.BGFX_RENDER_FRAME_TIMEOUT = 2
bgfx_api.BGFX_RENDER_FRAME_EXITING = 3
bgfx_api.BGFX_RENDER_FRAME_COUNT = 4
bgfx_api.BGFX_BUFFER_HANDLE_TYPE_DYNAMIC_INDEX_BUFFER = 0
bgfx_api.BGFX_BUFFER_HANDLE_TYPE_DYNAMIC_VERTEX_BUFFER = 1
bgfx_api.BGFX_BUFFER_HANDLE_TYPE_INDEX_BUFFER = 2
bgfx_api.BGFX_BUFFER_HANDLE_TYPE_INDIRECT_BUFFER = 3
bgfx_api.BGFX_BUFFER_HANDLE_TYPE_VERTEX_BUFFER = 4
bgfx_api.BGFX_BUFFER_HANDLE_TYPE_COUNT = 5
bgfx_api.BGFX_FUNCTION_ID_TEXTURE_REGION_INIT = 0
bgfx_api.BGFX_FUNCTION_ID_BUFFER_REGION_INIT_TEXTURE = 1
bgfx_api.BGFX_FUNCTION_ID_BUFFER_REGION_INIT_BUFFER = 2
bgfx_api.BGFX_FUNCTION_ID_ATTACHMENT_INIT = 3
bgfx_api.BGFX_FUNCTION_ID_VERTEX_LAYOUT_BEGIN = 4
bgfx_api.BGFX_FUNCTION_ID_VERTEX_LAYOUT_ADD = 5
bgfx_api.BGFX_FUNCTION_ID_VERTEX_LAYOUT_DECODE = 6
bgfx_api.BGFX_FUNCTION_ID_VERTEX_LAYOUT_HAS = 7
bgfx_api.BGFX_FUNCTION_ID_VERTEX_LAYOUT_SKIP = 8
bgfx_api.BGFX_FUNCTION_ID_VERTEX_LAYOUT_END = 9
bgfx_api.BGFX_FUNCTION_ID_VERTEX_LAYOUT_GET_OFFSET = 10
bgfx_api.BGFX_FUNCTION_ID_VERTEX_LAYOUT_GET_STRIDE = 11
bgfx_api.BGFX_FUNCTION_ID_VERTEX_LAYOUT_GET_SIZE = 12
bgfx_api.BGFX_FUNCTION_ID_VERTEX_PACK = 13
bgfx_api.BGFX_FUNCTION_ID_VERTEX_UNPACK = 14
bgfx_api.BGFX_FUNCTION_ID_VERTEX_CONVERT = 15
bgfx_api.BGFX_FUNCTION_ID_TOPOLOGY_CONVERT = 16
bgfx_api.BGFX_FUNCTION_ID_TOPOLOGY_SORT_TRI_LIST = 17
bgfx_api.BGFX_FUNCTION_ID_GET_SUPPORTED_RENDERERS = 18
bgfx_api.BGFX_FUNCTION_ID_GET_RENDERER_NAME = 19
bgfx_api.BGFX_FUNCTION_ID_INIT_CTOR = 20
bgfx_api.BGFX_FUNCTION_ID_INIT = 21
bgfx_api.BGFX_FUNCTION_ID_SHUTDOWN = 22
bgfx_api.BGFX_FUNCTION_ID_RESET = 23
bgfx_api.BGFX_FUNCTION_ID_FRAME = 24
bgfx_api.BGFX_FUNCTION_ID_GET_RENDERER_TYPE = 25
bgfx_api.BGFX_FUNCTION_ID_GET_CAPS = 26
bgfx_api.BGFX_FUNCTION_ID_GET_STATS = 27
bgfx_api.BGFX_FUNCTION_ID_ALLOC = 28
bgfx_api.BGFX_FUNCTION_ID_COPY = 29
bgfx_api.BGFX_FUNCTION_ID_MAKE_REF = 30
bgfx_api.BGFX_FUNCTION_ID_MAKE_REF_RELEASE = 31
bgfx_api.BGFX_FUNCTION_ID_SET_DEBUG = 32
bgfx_api.BGFX_FUNCTION_ID_DBG_TEXT_CLEAR = 33
bgfx_api.BGFX_FUNCTION_ID_DBG_TEXT_PRINTF = 34
bgfx_api.BGFX_FUNCTION_ID_DBG_TEXT_VPRINTF = 35
bgfx_api.BGFX_FUNCTION_ID_DBG_TEXT_IMAGE = 36
bgfx_api.BGFX_FUNCTION_ID_CREATE_INDEX_BUFFER = 37
bgfx_api.BGFX_FUNCTION_ID_READ_BUFFER = 38
bgfx_api.BGFX_FUNCTION_ID_SET_INDEX_BUFFER_NAME = 39
bgfx_api.BGFX_FUNCTION_ID_DESTROY_INDEX_BUFFER = 40
bgfx_api.BGFX_FUNCTION_ID_CREATE_VERTEX_LAYOUT = 41
bgfx_api.BGFX_FUNCTION_ID_DESTROY_VERTEX_LAYOUT = 42
bgfx_api.BGFX_FUNCTION_ID_CREATE_VERTEX_BUFFER = 43
bgfx_api.BGFX_FUNCTION_ID_SET_VERTEX_BUFFER_NAME = 44
bgfx_api.BGFX_FUNCTION_ID_DESTROY_VERTEX_BUFFER = 45
bgfx_api.BGFX_FUNCTION_ID_CREATE_DYNAMIC_INDEX_BUFFER = 46
bgfx_api.BGFX_FUNCTION_ID_CREATE_DYNAMIC_INDEX_BUFFER_MEM = 47
bgfx_api.BGFX_FUNCTION_ID_UPDATE_DYNAMIC_INDEX_BUFFER = 48
bgfx_api.BGFX_FUNCTION_ID_DESTROY_DYNAMIC_INDEX_BUFFER = 49
bgfx_api.BGFX_FUNCTION_ID_CREATE_DYNAMIC_VERTEX_BUFFER = 50
bgfx_api.BGFX_FUNCTION_ID_CREATE_DYNAMIC_VERTEX_BUFFER_MEM = 51
bgfx_api.BGFX_FUNCTION_ID_UPDATE_DYNAMIC_VERTEX_BUFFER = 52
bgfx_api.BGFX_FUNCTION_ID_DESTROY_DYNAMIC_VERTEX_BUFFER = 53
bgfx_api.BGFX_FUNCTION_ID_GET_AVAIL_TRANSIENT_INDEX_BUFFER = 54
bgfx_api.BGFX_FUNCTION_ID_GET_AVAIL_TRANSIENT_VERTEX_BUFFER = 55
bgfx_api.BGFX_FUNCTION_ID_GET_AVAIL_INSTANCE_DATA_BUFFER = 56
bgfx_api.BGFX_FUNCTION_ID_ALLOC_TRANSIENT_INDEX_BUFFER = 57
bgfx_api.BGFX_FUNCTION_ID_ALLOC_TRANSIENT_VERTEX_BUFFER = 58
bgfx_api.BGFX_FUNCTION_ID_ALLOC_TRANSIENT_BUFFERS = 59
bgfx_api.BGFX_FUNCTION_ID_ALLOC_INSTANCE_DATA_BUFFER = 60
bgfx_api.BGFX_FUNCTION_ID_CREATE_INDIRECT_BUFFER = 61
bgfx_api.BGFX_FUNCTION_ID_DESTROY_INDIRECT_BUFFER = 62
bgfx_api.BGFX_FUNCTION_ID_CREATE_SHADER = 63
bgfx_api.BGFX_FUNCTION_ID_GET_SHADER_UNIFORMS = 64
bgfx_api.BGFX_FUNCTION_ID_SET_SHADER_NAME = 65
bgfx_api.BGFX_FUNCTION_ID_DESTROY_SHADER = 66
bgfx_api.BGFX_FUNCTION_ID_CREATE_PROGRAM = 67
bgfx_api.BGFX_FUNCTION_ID_CREATE_COMPUTE_PROGRAM = 68
bgfx_api.BGFX_FUNCTION_ID_DESTROY_PROGRAM = 69
bgfx_api.BGFX_FUNCTION_ID_IS_TEXTURE_VALID = 70
bgfx_api.BGFX_FUNCTION_ID_IS_VIDEO_CODEC_VALID = 71
bgfx_api.BGFX_FUNCTION_ID_IS_FRAME_BUFFER_VALID = 72
bgfx_api.BGFX_FUNCTION_ID_CALC_TEXTURE_SIZE = 73
bgfx_api.BGFX_FUNCTION_ID_CREATE_TEXTURE = 74
bgfx_api.BGFX_FUNCTION_ID_CREATE_TEXTURE_2D = 75
bgfx_api.BGFX_FUNCTION_ID_CREATE_TEXTURE_2D_SCALED = 76
bgfx_api.BGFX_FUNCTION_ID_CREATE_TEXTURE_3D = 77
bgfx_api.BGFX_FUNCTION_ID_CREATE_TEXTURE_CUBE = 78
bgfx_api.BGFX_FUNCTION_ID_UPDATE_TEXTURE_2D = 79
bgfx_api.BGFX_FUNCTION_ID_UPDATE_TEXTURE_3D = 80
bgfx_api.BGFX_FUNCTION_ID_UPDATE_TEXTURE_CUBE = 81
bgfx_api.BGFX_FUNCTION_ID_CLEAR_TEXTURE = 82
bgfx_api.BGFX_FUNCTION_ID_READ_TEXTURE = 83
bgfx_api.BGFX_FUNCTION_ID_SET_TEXTURE_NAME = 84
bgfx_api.BGFX_FUNCTION_ID_GET_DIRECT_ACCESS_PTR = 85
bgfx_api.BGFX_FUNCTION_ID_DESTROY_TEXTURE = 86
bgfx_api.BGFX_FUNCTION_ID_CREATE_FRAME_BUFFER = 87
bgfx_api.BGFX_FUNCTION_ID_CREATE_FRAME_BUFFER_SCALED = 88
bgfx_api.BGFX_FUNCTION_ID_CREATE_FRAME_BUFFER_FROM_HANDLES = 89
bgfx_api.BGFX_FUNCTION_ID_CREATE_FRAME_BUFFER_FROM_ATTACHMENT = 90
bgfx_api.BGFX_FUNCTION_ID_CREATE_FRAME_BUFFER_FROM_SWAP_CHAIN = 91
bgfx_api.BGFX_FUNCTION_ID_UPDATE_SWAP_CHAIN = 92
bgfx_api.BGFX_FUNCTION_ID_SET_FRAME_BUFFER_NAME = 93
bgfx_api.BGFX_FUNCTION_ID_GET_TEXTURE = 94
bgfx_api.BGFX_FUNCTION_ID_DESTROY_FRAME_BUFFER = 95
bgfx_api.BGFX_FUNCTION_ID_CREATE_UNIFORM = 96
bgfx_api.BGFX_FUNCTION_ID_CREATE_UNIFORM_WITH_FREQ = 97
bgfx_api.BGFX_FUNCTION_ID_GET_UNIFORM_INFO = 98
bgfx_api.BGFX_FUNCTION_ID_DESTROY_UNIFORM = 99
bgfx_api.BGFX_FUNCTION_ID_CREATE_OCCLUSION_QUERY = 100
bgfx_api.BGFX_FUNCTION_ID_GET_RESULT = 101
bgfx_api.BGFX_FUNCTION_ID_DESTROY_OCCLUSION_QUERY = 102
bgfx_api.BGFX_FUNCTION_ID_SET_PALETTE_COLOR = 103
bgfx_api.BGFX_FUNCTION_ID_SET_PALETTE_COLOR_RGBA32F = 104
bgfx_api.BGFX_FUNCTION_ID_SET_PALETTE_COLOR_RGBA8 = 105
bgfx_api.BGFX_FUNCTION_ID_SET_VIEW_NAME = 106
bgfx_api.BGFX_FUNCTION_ID_SET_VIEW_RECT = 107
bgfx_api.BGFX_FUNCTION_ID_SET_VIEW_RECT_RATIO = 108
bgfx_api.BGFX_FUNCTION_ID_SET_VIEW_SCISSOR = 109
bgfx_api.BGFX_FUNCTION_ID_SET_VIEW_DEPTH_BIAS = 110
bgfx_api.BGFX_FUNCTION_ID_SET_VIEW_SAMPLE_MASK = 111
bgfx_api.BGFX_FUNCTION_ID_SET_VIEW_CLEAR = 112
bgfx_api.BGFX_FUNCTION_ID_SET_VIEW_CLEAR_MRT = 113
bgfx_api.BGFX_FUNCTION_ID_SET_VIEW_MODE = 114
bgfx_api.BGFX_FUNCTION_ID_SET_VIEW_FRAME_BUFFER = 115
bgfx_api.BGFX_FUNCTION_ID_SET_VIEW_TRANSFORM = 116
bgfx_api.BGFX_FUNCTION_ID_SET_VIEW_ORDER = 117
bgfx_api.BGFX_FUNCTION_ID_SET_VIEW_SHADING_RATE = 118
bgfx_api.BGFX_FUNCTION_ID_RESET_VIEW = 119
bgfx_api.BGFX_FUNCTION_ID_ENCODER_BEGIN = 120
bgfx_api.BGFX_FUNCTION_ID_ENCODER_END = 121
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_MARKER = 122
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_STATE = 123
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_CONDITION = 124
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_STENCIL = 125
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_SAMPLE_MASK = 126
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_SCISSOR = 127
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_SCISSOR_CACHED = 128
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_DEPTH_CONTROL = 129
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_DEPTH_CONTROL_CACHED = 130
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_TRANSFORM = 131
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_TRANSFORM_CACHED = 132
bgfx_api.BGFX_FUNCTION_ID_ENCODER_ALLOC_TRANSFORM = 133
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_UNIFORM = 134
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_UNIFORM_REF = 135
bgfx_api.BGFX_FUNCTION_ID_SET_VIEW_UNIFORM = 136
bgfx_api.BGFX_FUNCTION_ID_SET_FRAME_UNIFORM = 137
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_INDEX_BUFFER = 138
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_DYNAMIC_INDEX_BUFFER = 139
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_TRANSIENT_INDEX_BUFFER = 140
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_VERTEX_BUFFER = 141
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_VERTEX_BUFFER_WITH_LAYOUT = 142
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_DYNAMIC_VERTEX_BUFFER = 143
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_DYNAMIC_VERTEX_BUFFER_WITH_LAYOUT = 144
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_TRANSIENT_VERTEX_BUFFER = 145
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_TRANSIENT_VERTEX_BUFFER_WITH_LAYOUT = 146
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_VERTEX_COUNT = 147
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_INSTANCE_DATA_BUFFER = 148
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_INSTANCE_DATA_FROM_VERTEX_BUFFER = 149
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_INSTANCE_DATA_FROM_DYNAMIC_VERTEX_BUFFER = 150
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_INSTANCE_COUNT = 151
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_TEXTURE = 152
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_TEXTURE_VIEW = 153
bgfx_api.BGFX_FUNCTION_ID_ENCODER_TOUCH = 154
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SUBMIT = 155
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SUBMIT_OCCLUSION_QUERY = 156
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SUBMIT_INDIRECT = 157
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SUBMIT_INDIRECT_COUNT = 158
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_COMPUTE_INDEX_BUFFER = 159
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_COMPUTE_VERTEX_BUFFER = 160
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_COMPUTE_DYNAMIC_INDEX_BUFFER = 161
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_COMPUTE_DYNAMIC_VERTEX_BUFFER = 162
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_COMPUTE_INDIRECT_BUFFER = 163
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_IMAGE = 164
bgfx_api.BGFX_FUNCTION_ID_ENCODER_SET_IMAGE_VIEW = 165
bgfx_api.BGFX_FUNCTION_ID_ENCODER_DISPATCH = 166
bgfx_api.BGFX_FUNCTION_ID_ENCODER_DISPATCH_INDIRECT = 167
bgfx_api.BGFX_FUNCTION_ID_ENCODER_DISCARD = 168
bgfx_api.BGFX_FUNCTION_ID_ENCODER_BLIT = 169
bgfx_api.BGFX_FUNCTION_ID_ENCODER_BLIT_BUFFER = 170
bgfx_api.BGFX_FUNCTION_ID_ENCODER_BLIT_TO_BUFFER = 171
bgfx_api.BGFX_FUNCTION_ID_ENCODER_BLIT_FROM_BUFFER = 172
bgfx_api.BGFX_FUNCTION_ID_REQUEST_SCREEN_SHOT = 173
bgfx_api.BGFX_FUNCTION_ID_RENDER_FRAME = 174
bgfx_api.BGFX_FUNCTION_ID_GET_INTERNAL_DATA = 175
bgfx_api.BGFX_FUNCTION_ID_SET_MARKER = 176
bgfx_api.BGFX_FUNCTION_ID_SET_STATE = 177
bgfx_api.BGFX_FUNCTION_ID_SET_CONDITION = 178
bgfx_api.BGFX_FUNCTION_ID_SET_STENCIL = 179
bgfx_api.BGFX_FUNCTION_ID_SET_SAMPLE_MASK = 180
bgfx_api.BGFX_FUNCTION_ID_SET_SCISSOR = 181
bgfx_api.BGFX_FUNCTION_ID_SET_SCISSOR_CACHED = 182
bgfx_api.BGFX_FUNCTION_ID_SET_DEPTH_CONTROL = 183
bgfx_api.BGFX_FUNCTION_ID_SET_DEPTH_CONTROL_CACHED = 184
bgfx_api.BGFX_FUNCTION_ID_SET_TRANSFORM = 185
bgfx_api.BGFX_FUNCTION_ID_SET_TRANSFORM_CACHED = 186
bgfx_api.BGFX_FUNCTION_ID_ALLOC_TRANSFORM = 187
bgfx_api.BGFX_FUNCTION_ID_SET_UNIFORM = 188
bgfx_api.BGFX_FUNCTION_ID_SET_UNIFORM_REF = 189
bgfx_api.BGFX_FUNCTION_ID_SET_INDEX_BUFFER = 190
bgfx_api.BGFX_FUNCTION_ID_SET_DYNAMIC_INDEX_BUFFER = 191
bgfx_api.BGFX_FUNCTION_ID_SET_TRANSIENT_INDEX_BUFFER = 192
bgfx_api.BGFX_FUNCTION_ID_SET_VERTEX_BUFFER = 193
bgfx_api.BGFX_FUNCTION_ID_SET_VERTEX_BUFFER_WITH_LAYOUT = 194
bgfx_api.BGFX_FUNCTION_ID_SET_DYNAMIC_VERTEX_BUFFER = 195
bgfx_api.BGFX_FUNCTION_ID_SET_DYNAMIC_VERTEX_BUFFER_WITH_LAYOUT = 196
bgfx_api.BGFX_FUNCTION_ID_SET_TRANSIENT_VERTEX_BUFFER = 197
bgfx_api.BGFX_FUNCTION_ID_SET_TRANSIENT_VERTEX_BUFFER_WITH_LAYOUT = 198
bgfx_api.BGFX_FUNCTION_ID_SET_VERTEX_COUNT = 199
bgfx_api.BGFX_FUNCTION_ID_SET_INSTANCE_DATA_BUFFER = 200
bgfx_api.BGFX_FUNCTION_ID_SET_INSTANCE_DATA_FROM_VERTEX_BUFFER = 201
bgfx_api.BGFX_FUNCTION_ID_SET_INSTANCE_DATA_FROM_DYNAMIC_VERTEX_BUFFER = 202
bgfx_api.BGFX_FUNCTION_ID_SET_INSTANCE_COUNT = 203
bgfx_api.BGFX_FUNCTION_ID_SET_TEXTURE = 204
bgfx_api.BGFX_FUNCTION_ID_SET_TEXTURE_VIEW = 205
bgfx_api.BGFX_FUNCTION_ID_TOUCH = 206
bgfx_api.BGFX_FUNCTION_ID_SUBMIT = 207
bgfx_api.BGFX_FUNCTION_ID_SUBMIT_OCCLUSION_QUERY = 208
bgfx_api.BGFX_FUNCTION_ID_SUBMIT_INDIRECT = 209
bgfx_api.BGFX_FUNCTION_ID_SUBMIT_INDIRECT_COUNT = 210
bgfx_api.BGFX_FUNCTION_ID_SET_COMPUTE_INDEX_BUFFER = 211
bgfx_api.BGFX_FUNCTION_ID_SET_COMPUTE_VERTEX_BUFFER = 212
bgfx_api.BGFX_FUNCTION_ID_SET_COMPUTE_DYNAMIC_INDEX_BUFFER = 213
bgfx_api.BGFX_FUNCTION_ID_SET_COMPUTE_DYNAMIC_VERTEX_BUFFER = 214
bgfx_api.BGFX_FUNCTION_ID_SET_COMPUTE_INDIRECT_BUFFER = 215
bgfx_api.BGFX_FUNCTION_ID_SET_IMAGE = 216
bgfx_api.BGFX_FUNCTION_ID_SET_IMAGE_VIEW = 217
bgfx_api.BGFX_FUNCTION_ID_DISPATCH = 218
bgfx_api.BGFX_FUNCTION_ID_DISPATCH_INDIRECT = 219
bgfx_api.BGFX_FUNCTION_ID_DISCARD = 220
bgfx_api.BGFX_FUNCTION_ID_BLIT = 221
bgfx_api.BGFX_FUNCTION_ID_BLIT_BUFFER = 222
bgfx_api.BGFX_FUNCTION_ID_BLIT_TO_BUFFER = 223
bgfx_api.BGFX_FUNCTION_ID_BLIT_FROM_BUFFER = 224
bgfx_api.BGFX_FUNCTION_ID_COUNT = 225

-- Preserve this established convenience alias; upstream exposes the channels separately.
bgfx_api.BGFX_STATE_WRITE_RGBA = bgfx_api.BGFX_STATE_WRITE_R
    + bgfx_api.BGFX_STATE_WRITE_G
    + bgfx_api.BGFX_STATE_WRITE_B
    + bgfx_api.BGFX_STATE_WRITE_A

-- Lua equivalents for the function-like macros in bgfx/defines.h.
local function field_value(value, width)
    value = math.floor(tonumber(value) or 0)
    return value % (2 ^ width)
end

bgfx_api.BGFX_STATE_ALPHA_REF = function(v)
    return ffi.new("uint64_t", field_value(v, 8)) * ffi.new("uint64_t", 2 ^ bgfx_api.BGFX_STATE_ALPHA_REF_SHIFT)
end
bgfx_api.BGFX_STATE_POINT_SIZE = function(v)
    return ffi.new("uint64_t", field_value(v, 4)) * ffi.new("uint64_t", 2 ^ bgfx_api.BGFX_STATE_POINT_SIZE_SHIFT)
end
bgfx_api.BGFX_STENCIL_FUNC_REF = function(v)
    return field_value(v, 8)
end
bgfx_api.BGFX_STENCIL_FUNC_RMASK = function(v)
    return field_value(v, 8) * 256
end
bgfx_api.BGFX_TEXTURE_MIP_COUNT = function(v)
    return ffi.new("uint64_t", field_value(v, 5)) * ffi.new("uint64_t", 2 ^ bgfx_api.BGFX_TEXTURE_MIP_COUNT_SHIFT)
end
bgfx_api.BGFX_SAMPLER_BORDER_COLOR = function(v)
    return field_value(v, 4) * 0x01000000
end
bgfx_api.BGFX_STATE_BLEND_FUNC_SEPARATE = function(srcRGB, dstRGB, srcA, dstA)
    return srcRGB + dstRGB * 16 + (srcA + dstA * 16) * 256
end
bgfx_api.BGFX_STATE_BLEND_EQUATION_SEPARATE = function(equationRGB, equationA)
    return equationRGB + equationA * 8
end
bgfx_api.BGFX_STATE_BLEND_FUNC = function(src, dst)
    return bgfx_api.BGFX_STATE_BLEND_FUNC_SEPARATE(src, dst, src, dst)
end
bgfx_api.BGFX_STATE_BLEND_EQUATION = function(equation)
    return bgfx_api.BGFX_STATE_BLEND_EQUATION_SEPARATE(equation, equation)
end
bgfx_api.BGFX_STATE_BLEND_FUNC_RT_x = function(src, dst)
    return bit.rshift(src, bgfx_api.BGFX_STATE_BLEND_SHIFT)
        + bit.lshift(bit.rshift(dst, bgfx_api.BGFX_STATE_BLEND_SHIFT), 4)
end
bgfx_api.BGFX_STATE_BLEND_FUNC_RT_xE = function(src, dst, equation)
    return bgfx_api.BGFX_STATE_BLEND_FUNC_RT_x(src, dst)
        + bit.lshift(bit.rshift(equation, bgfx_api.BGFX_STATE_BLEND_EQUATION_SHIFT), 8)
end
bgfx_api.BGFX_STATE_BLEND_FUNC_RT_1 = function(src, dst)
    return bgfx_api.BGFX_STATE_BLEND_FUNC_RT_x(src, dst)
end
bgfx_api.BGFX_STATE_BLEND_FUNC_RT_2 = function(src, dst)
    return bit.lshift(bgfx_api.BGFX_STATE_BLEND_FUNC_RT_x(src, dst), 11)
end
bgfx_api.BGFX_STATE_BLEND_FUNC_RT_3 = function(src, dst)
    return bit.lshift(bgfx_api.BGFX_STATE_BLEND_FUNC_RT_x(src, dst), 22)
end
bgfx_api.BGFX_STATE_BLEND_FUNC_RT_1E = function(src, dst, equation)
    return bgfx_api.BGFX_STATE_BLEND_FUNC_RT_xE(src, dst, equation)
end
bgfx_api.BGFX_STATE_BLEND_FUNC_RT_2E = function(src, dst, equation)
    return bit.lshift(bgfx_api.BGFX_STATE_BLEND_FUNC_RT_xE(src, dst, equation), 11)
end
bgfx_api.BGFX_STATE_BLEND_FUNC_RT_3E = function(src, dst, equation)
    return bit.lshift(bgfx_api.BGFX_STATE_BLEND_FUNC_RT_xE(src, dst, equation), 22)
end


local C = ffi_tryload("bgfx-shared-libRelease")
local bgfx_interface = C.bgfx_get_interface(bgfx_api.BGFX_API_VERSION)
if bgfx_interface == nil or bgfx_interface == ffi.NULL then
	error(string.format(
		"bgfx shared library does not expose BGFX_API_VERSION %d; ffi_bgfx.lua is out of sync with the loaded runtime",
		bgfx_api.BGFX_API_VERSION
	))
end

bgfx_api.bgfx_create_texture_2d = function(_width, _height, _hasMips, _numLayers, _format, _flags, _mem, _external)
	return bgfx_interface.create_texture_2d(_width, _height, _hasMips, _numLayers, _format, _flags, _mem, _external or 0)
end

bgfx_api.bgfx_create_texture_3d = function(_width, _height, _depth, _hasMips, _format, _flags, _mem, _external)
	return bgfx_interface.create_texture_3d(_width, _height, _depth, _hasMips, _format, _flags, _mem, _external or 0)
end

bgfx_api.bgfx_create_texture_cube = function(_size, _hasMips, _numLayers, _format, _flags, _mem, _external)
	return bgfx_interface.create_texture_cube(_size, _hasMips, _numLayers, _format, _flags, _mem, _external or 0)
end

if ffi.arch == "wasm" then
	local uint64_scratch = ffi.new("uint64_t[1]")
	local uint64_words = ffi.cast("const uint32_t *", uint64_scratch)
	local function use_uint64_words(value)
		uint64_scratch[0] = value or 0
		return uint64_words
	end
	local function uint32_value(value)
		return tonumber(ffi.cast("uint32_t", value or 0))
	end
	local function handle_index(handle)
		if handle == nil then return 0xffff end
		if type(handle) == "number" then return handle end
		return tonumber(handle.idx) or 0xffff
	end

	local function make_handle(ctype, index)
		local handle = ffi.new(ctype)
		handle.idx = tonumber(index)
		return handle
	end
	bgfx_api.bgfx_copy = function(data, size)
		return C.clay_bgfx_ffi_copy(data, size)
	end

	bgfx_api.bgfx_create_texture_2d = function(width, height, has_mips, num_layers, format, flags, memory, external)
		return make_handle("bgfx_texture_handle_t", C.clay_bgfx_ffi_create_texture_2d(
			width, height, has_mips, num_layers, format, use_uint64_words(flags), memory,
			uint32_value(external)))
	end
	bgfx_api.bgfx_create_texture_3d = function(width, height, depth, has_mips, format, flags, memory, external)
		return make_handle("bgfx_texture_handle_t", C.clay_bgfx_ffi_create_texture_3d(
			width, height, depth, has_mips, format, use_uint64_words(flags), memory,
			uint32_value(external)))
	end
	bgfx_api.bgfx_create_texture_cube = function(size, has_mips, num_layers, format, flags, memory, external)
		return make_handle("bgfx_texture_handle_t", C.clay_bgfx_ffi_create_texture_cube(
			size, has_mips, num_layers, format, use_uint64_words(flags), memory,
			uint32_value(external)))
	end
	bgfx_api.bgfx_create_uniform = function(...)
		return make_handle("bgfx_uniform_handle_t", C.clay_bgfx_ffi_create_uniform(...))
	end
	bgfx_api.bgfx_create_shader = function(...)
		return make_handle("bgfx_shader_handle_t", C.clay_bgfx_ffi_create_shader(...))
	end
	bgfx_api.bgfx_create_program = function(vertex_shader, fragment_shader, destroy_shaders)
		return make_handle("bgfx_program_handle_t", C.clay_bgfx_ffi_create_program(
			handle_index(vertex_shader), handle_index(fragment_shader), destroy_shaders))
	end
	bgfx_api.bgfx_create_vertex_layout = function(...)
		return make_handle("bgfx_vertex_layout_handle_t", C.clay_bgfx_ffi_create_vertex_layout(...))
	end
	bgfx_api.bgfx_create_vertex_buffer = function(...)
		return make_handle("bgfx_vertex_buffer_handle_t", C.clay_bgfx_ffi_create_vertex_buffer(...))
	end
	bgfx_api.bgfx_create_index_buffer = function(...)
		return make_handle("bgfx_index_buffer_handle_t", C.clay_bgfx_ffi_create_index_buffer(...))
	end

	bgfx_api.bgfx_destroy_texture = function(handle)
		return C.clay_bgfx_ffi_destroy_texture(handle_index(handle))
	end
	bgfx_api.bgfx_update_texture_2d = function(handle, ...)
		return C.clay_bgfx_ffi_update_texture_2d(handle_index(handle), ...)
	end
	bgfx_api.bgfx_destroy_uniform = function(handle)
		return C.clay_bgfx_ffi_destroy_uniform(handle_index(handle))
	end
	bgfx_api.bgfx_set_uniform = function(handle, ...)
		return C.clay_bgfx_ffi_set_uniform(handle_index(handle), ...)
	end
	bgfx_api.bgfx_set_texture = function(stage, sampler, texture, flags)
		return C.clay_bgfx_ffi_set_texture(stage, handle_index(sampler), handle_index(texture), flags)
	end
	bgfx_api.bgfx_set_debug = function(debug, framebuffer, scale)
		return C.clay_bgfx_ffi_set_debug(debug, handle_index(framebuffer), scale)
	end
	bgfx_api.bgfx_set_state = function(state, rgba)
		return C.clay_bgfx_ffi_set_state(use_uint64_words(state), rgba)
	end
	bgfx_api.bgfx_set_index_buffer = function(handle, ...)
		return C.clay_bgfx_ffi_set_index_buffer(handle_index(handle), ...)
	end
	bgfx_api.bgfx_set_vertex_buffer = function(stream, handle, ...)
		return C.clay_bgfx_ffi_set_vertex_buffer(stream, handle_index(handle), ...)
	end
	bgfx_api.bgfx_set_transient_buffers = function(...)
		return C.clay_bgfx_ffi_set_transient_buffers(...)
	end
	bgfx_api.bgfx_submit = function(view, program, ...)
		return C.clay_bgfx_ffi_submit(view, handle_index(program), ...)
	end
	bgfx_api.bgfx_destroy_program = function(handle)
		return C.clay_bgfx_ffi_destroy_program(handle_index(handle))
	end
	bgfx_api.bgfx_destroy_vertex_buffer = function(handle)
		return C.clay_bgfx_ffi_destroy_vertex_buffer(handle_index(handle))
	end
	bgfx_api.bgfx_destroy_index_buffer = function(handle)
		return C.clay_bgfx_ffi_destroy_index_buffer(handle_index(handle))
	end
	bgfx_api.bgfx_destroy_vertex_layout = function(handle)
		return C.clay_bgfx_ffi_destroy_vertex_layout(handle_index(handle))
	end
end

return setmetatable( bgfx_api, {
	__index = function( table, key )
		if ffi.arch ~= "wasm" then return C[key] end
		local function_name = type(key) == "string" and key:match("^bgfx_(.+)$")
		if not function_name then return nil end
		local ok, fn = pcall(function() return bgfx_interface[function_name] end)
		if not ok or fn == nil then return nil end
		table[key] = fn
		return fn
	end
} )
