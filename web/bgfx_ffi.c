#include <bgfx/c99/bgfx.h>
#include <string.h>

/*
 * Keep aggregate BGFX values and 64-bit state/flag marshalling inside C.
 * lua-ffi-wasm's Wasm32 FFI boundary does not reliably pass these values by
 * value, so Lua passes scalar handles or pointers to two 32-bit words here.
 * The BGFX C ABI stays native while Lua keeps the same handle cdata as desktop.
 */

const bgfx_memory_t* clay_bgfx_ffi_copy(const void* data, uint32_t size) {
	return bgfx_copy(data, size);
}

uint16_t clay_bgfx_ffi_create_texture_2d(uint16_t width, uint16_t height,
	bool has_mips, uint16_t num_layers, bgfx_texture_format_t format,
	const uint32_t* flags_words, const bgfx_memory_t* memory, uint32_t external) {
	const uint64_t flags = ((uint64_t)flags_words[1] << 32) | flags_words[0];
	return bgfx_create_texture_2d(width, height, has_mips, num_layers, format,
		flags, memory, external).idx;
}

uint16_t clay_bgfx_ffi_create_texture_3d(uint16_t width, uint16_t height,
	uint16_t depth, bool has_mips, bgfx_texture_format_t format,
	const uint32_t* flags_words, const bgfx_memory_t* memory, uint32_t external) {
	const uint64_t flags = ((uint64_t)flags_words[1] << 32) | flags_words[0];
	return bgfx_create_texture_3d(width, height, depth, has_mips, format, flags,
		memory, external).idx;
}

uint16_t clay_bgfx_ffi_create_texture_cube(uint16_t size, bool has_mips,
	uint16_t num_layers, bgfx_texture_format_t format,
	const uint32_t* flags_words, const bgfx_memory_t* memory, uint32_t external) {
	const uint64_t flags = ((uint64_t)flags_words[1] << 32) | flags_words[0];
	return bgfx_create_texture_cube(size, has_mips, num_layers, format, flags,
		memory, external).idx;
}

uint16_t clay_bgfx_ffi_create_uniform(const char* name,
	bgfx_uniform_type_t type, uint16_t count) {
	return bgfx_create_uniform(name, type, count).idx;
}

uint16_t clay_bgfx_ffi_create_shader(const bgfx_memory_t* memory) {
	return bgfx_create_shader(memory).idx;
}

uint16_t clay_bgfx_ffi_create_program(uint16_t vertex_shader,
	uint16_t fragment_shader, bool destroy_shaders) {
	bgfx_shader_handle_t vertex = { vertex_shader };
	bgfx_shader_handle_t fragment = { fragment_shader };
	return bgfx_create_program(vertex, fragment, destroy_shaders).idx;
}

uint16_t clay_bgfx_ffi_create_vertex_layout(const bgfx_vertex_layout_t* layout) {
	return bgfx_create_vertex_layout(layout).idx;
}

uint16_t clay_bgfx_ffi_create_vertex_buffer(const bgfx_memory_t* memory,
	const bgfx_vertex_layout_t* layout, uint16_t flags) {
	return bgfx_create_vertex_buffer(memory, layout, flags).idx;
}

uint16_t clay_bgfx_ffi_create_index_buffer(const bgfx_memory_t* memory,
	uint16_t flags) {
	return bgfx_create_index_buffer(memory, flags).idx;
}

void clay_bgfx_ffi_destroy_texture(uint16_t index) {
	bgfx_texture_handle_t handle = { index };
	bgfx_destroy_texture(handle);
}

void clay_bgfx_ffi_update_texture_2d(uint16_t index, uint16_t layer,
	uint8_t mip, uint16_t x, uint16_t y, uint16_t width, uint16_t height,
	const bgfx_memory_t* memory, uint16_t pitch) {
	bgfx_texture_handle_t handle = { index };
	bgfx_update_texture_2d(handle, layer, mip, x, y, width, height, memory, pitch);
}

void clay_bgfx_ffi_destroy_uniform(uint16_t index) {
	bgfx_uniform_handle_t handle = { index };
	bgfx_destroy_uniform(handle);
}

void clay_bgfx_ffi_set_uniform(uint16_t index, const void* value, uint16_t count) {
	bgfx_uniform_handle_t handle = { index };
	bgfx_set_uniform(handle, value, count);
}

void clay_bgfx_ffi_set_texture(uint8_t stage, uint16_t sampler,
	uint16_t texture, uint32_t flags) {
	bgfx_uniform_handle_t sampler_handle = { sampler };
	bgfx_texture_handle_t texture_handle = { texture };
	bgfx_set_texture(stage, sampler_handle, texture_handle, flags);
}

void clay_bgfx_ffi_set_debug(uint32_t debug, uint16_t framebuffer, uint8_t scale) {
	bgfx_frame_buffer_handle_t handle = { framebuffer };
	bgfx_set_debug(debug, handle, scale);
}

void clay_bgfx_ffi_set_state(const uint32_t* state_words, uint32_t rgba) {
	const uint64_t state = ((uint64_t)state_words[1] << 32) | state_words[0];
	bgfx_set_state(state, rgba);
}

void clay_bgfx_ffi_set_index_buffer(uint16_t index, uint32_t first,
	uint32_t count) {
	bgfx_index_buffer_handle_t handle = { index };
	bgfx_set_index_buffer(handle, first, count);
}

void clay_bgfx_ffi_set_vertex_buffer(uint8_t stream, uint16_t index,
	uint32_t start, uint32_t count) {
	bgfx_vertex_buffer_handle_t handle = { index };
	bgfx_set_vertex_buffer(stream, handle, start, count);
}

bool clay_bgfx_ffi_set_transient_buffers(const bgfx_vertex_layout_t* layout,
	const void* vertices, uint32_t vertex_count, const uint16_t* indices,
	uint32_t index_count) {
	if (layout == NULL || vertices == NULL || indices == NULL
		|| vertex_count == 0 || index_count == 0
		|| bgfx_get_avail_transient_vertex_buffer(vertex_count, layout) < vertex_count
		|| bgfx_get_avail_transient_index_buffer(index_count, false) < index_count) {
		return false;
	}

	bgfx_transient_vertex_buffer_t vertex_buffer;
	bgfx_transient_index_buffer_t index_buffer;
	if (!bgfx_alloc_transient_buffers(&vertex_buffer, layout, vertex_count,
		&index_buffer, index_count, false)) {
		return false;
	}

	const uint16_t stride = bgfx_vertex_layout_get_stride(layout);
	memcpy(vertex_buffer.data, vertices, (size_t)stride * vertex_count);
	memcpy(index_buffer.data, indices, sizeof(uint16_t) * index_count);
	bgfx_set_transient_vertex_buffer(0, &vertex_buffer, 0, vertex_count);
	bgfx_set_transient_index_buffer(&index_buffer, 0, index_count);
	return true;
}

void clay_bgfx_ffi_submit(uint16_t view, uint16_t program, uint32_t depth,
	uint8_t flags) {
	bgfx_program_handle_t handle = { program };
	bgfx_submit(view, handle, depth, flags);
}

void clay_bgfx_ffi_destroy_program(uint16_t index) {
	bgfx_program_handle_t handle = { index };
	bgfx_destroy_program(handle);
}

void clay_bgfx_ffi_destroy_vertex_buffer(uint16_t index) {
	bgfx_vertex_buffer_handle_t handle = { index };
	bgfx_destroy_vertex_buffer(handle);
}

void clay_bgfx_ffi_destroy_index_buffer(uint16_t index) {
	bgfx_index_buffer_handle_t handle = { index };
	bgfx_destroy_index_buffer(handle);
}

void clay_bgfx_ffi_destroy_vertex_layout(uint16_t index) {
	bgfx_vertex_layout_handle_t handle = { index };
	bgfx_destroy_vertex_layout(handle);
}
