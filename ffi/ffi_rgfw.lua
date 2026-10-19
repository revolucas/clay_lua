local ffi = require("ffi")
local ffi_tryload = require("ffi.ffi_loader").tryload

ffi.cdef([[
typedef struct ClayRGFWEvent {
    int type;
    int a, b, c, d;
    float x, y;
    int codepoint;
    const char** paths;
    size_t count;
} ClayRGFWEvent;

void* clay_rgfw_create(const char* title, int x, int y, int width, int height, int fullscreen, int centered);
int clay_rgfw_next_event(void* handle, ClayRGFWEvent* out);
int clay_rgfw_key_down(void* handle, int key);
int clay_rgfw_mouse_down(void* handle, int button);
void clay_rgfw_mouse_position(void* handle, int* x, int* y);
void clay_rgfw_get_size(void* handle, int* width, int* height);
void clay_rgfw_get_position(void* handle, int* x, int* y);
int clay_rgfw_platform_data(void* handle, void** nwh, void** ndt, int* type);
void clay_rgfw_set_title(void* handle, const char* title);
void clay_rgfw_set_size(void* handle, int width, int height);
void clay_rgfw_set_position(void* handle, int x, int y);
void clay_rgfw_show(void* handle);
void clay_rgfw_hide(void* handle);
int clay_rgfw_should_close(void* handle);
void clay_rgfw_set_should_close(void* handle, int should_close);
void clay_rgfw_close(void* handle);
const char* clay_rgfw_clipboard_get(void);
void clay_rgfw_clipboard_set(const char* text, unsigned int length);
double clay_rgfw_time(void);
]])

return ffi_tryload("rgfw")
