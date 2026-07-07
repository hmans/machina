package main

import "core:c"
import "core:dynlib"
import "core:os"
import "core:testing"

@(test)
test_wgpu_abi_structs_have_c_pointer_alignment :: proc(t: ^testing.T) {
	testing.expect_value(t, align_of(WGPU_String_View), align_of(rawptr))
	testing.expect_value(t, size_of(WGPU_String_View), size_of(rawptr) + size_of(c.size_t))
	testing.expect_value(t, align_of(WGPU_Chained_Struct), align_of(rawptr))
	testing.expect_value(t, align_of(WGPU_Chained_Struct_Out), align_of(rawptr))
	testing.expect_value(t, align_of(WGPU_Buffer_Descriptor), align_of(rawptr))
	testing.expect_value(t, align_of(WGPU_Texture_Descriptor), align_of(rawptr))
	testing.expect_value(t, align_of(WGPU_Texture_View_Descriptor), align_of(rawptr))
	testing.expect_value(t, align_of(WGPU_Texel_Copy_Texture_Info), align_of(rawptr))
	testing.expect_value(t, align_of(WGPU_Texel_Copy_Buffer_Info), align_of(rawptr))
	testing.expect_value(t, align_of(WGPU_Command_Encoder_Descriptor), align_of(rawptr))
	testing.expect_value(t, align_of(WGPU_Command_Buffer_Descriptor), align_of(rawptr))
	testing.expect_value(t, align_of(WGPU_Instance_Capabilities), align_of(rawptr))
	testing.expect_value(t, align_of(WGPU_Instance_Descriptor), align_of(rawptr))
	testing.expect_value(t, align_of(WGPU_Request_Adapter_Options), align_of(rawptr))
	testing.expect_value(t, align_of(WGPU_Queue_Descriptor), align_of(rawptr))
	testing.expect_value(t, align_of(WGPU_Device_Lost_Callback_Info), align_of(rawptr))
	testing.expect_value(t, align_of(WGPU_Uncaptured_Error_Callback_Info), align_of(rawptr))
	testing.expect_value(t, align_of(WGPU_Device_Descriptor), align_of(rawptr))
	testing.expect_value(t, align_of(WGPU_Request_Adapter_Callback_Info), align_of(rawptr))
	testing.expect_value(t, align_of(WGPU_Request_Device_Callback_Info), align_of(rawptr))
	testing.expect_value(t, align_of(WGPU_Buffer_Map_Callback_Info), align_of(rawptr))
}

@(test)
test_wgpu_string_view_null_matches_c_abi_sentinel :: proc(t: ^testing.T) {
	view := wgpu_string_view_null()
	testing.expect_value(t, view.data, rawptr(nil))
	testing.expect_value(t, view.length, WGPU_STRLEN)
}

@(test)
test_wgpu_string_view_can_hold_explicit_pointer_and_length :: proc(t: ^testing.T) {
	bytes := [?]u8{'w', 'g', 'p', 'u'}
	view := wgpu_string_view_from_raw(rawptr(&bytes[0]), c.size_t(len(bytes)))
	testing.expect_value(t, view.data, rawptr(&bytes[0]))
	testing.expect_value(t, view.length, c.size_t(4))
}

@(test)
test_wgpu_renderer_formats_match_vendored_binding_values :: proc(t: ^testing.T) {
	testing.expect_value(t, WGPU_DEFAULT_TARGET_FORMAT, WGPU_Texture_Format(0x18))
	testing.expect_value(t, WGPU_DEPTH_FORMAT, WGPU_Texture_Format(0x28))
	testing.expect_value(t, WGPU_SHADOW_DEPTH_FORMAT, WGPU_Texture_Format(0x2A))
}

@(test)
test_wgpu_renderer_usage_helpers_match_zig_render_paths :: proc(t: ^testing.T) {
	testing.expect_value(t, wgpu_offscreen_texture_usage(), WGPU_TEXTURE_USAGE_RENDER_ATTACHMENT | WGPU_TEXTURE_USAGE_COPY_SRC)
	testing.expect_value(t, wgpu_staging_buffer_usage(), WGPU_BUFFER_USAGE_MAP_READ | WGPU_BUFFER_USAGE_COPY_DST)
}

@(test)
test_wgpu_texture_descriptor_matches_offscreen_target_defaults :: proc(t: ^testing.T) {
	label := wgpu_string_view_from_raw(rawptr(uintptr(0x1234)), 6)
	descriptor := wgpu_texture_descriptor_2d(label, 640, 480, WGPU_DEFAULT_TARGET_FORMAT, wgpu_offscreen_texture_usage())
	testing.expect_value(t, descriptor.next_in_chain, (^WGPU_Chained_Struct)(nil))
	testing.expect_value(t, descriptor.label, label)
	testing.expect_value(t, descriptor.usage, WGPU_TEXTURE_USAGE_RENDER_ATTACHMENT | WGPU_TEXTURE_USAGE_COPY_SRC)
	testing.expect_value(t, descriptor.dimension, WGPU_TEXTURE_DIMENSION_2D)
	testing.expect_value(t, descriptor.size, WGPU_Extent_3D{width = 640, height = 480, depth_or_array_layers = 1})
	testing.expect_value(t, descriptor.format, WGPU_TEXTURE_FORMAT_BGRA8_UNORM_SRGB)
	testing.expect_value(t, descriptor.mip_level_count, u32(1))
	testing.expect_value(t, descriptor.sample_count, u32(1))
	testing.expect_value(t, descriptor.view_format_count, c.size_t(0))
	testing.expect_value(t, descriptor.view_formats, rawptr(nil))
}

@(test)
test_wgpu_texture_view_descriptor_matches_single_mip_render_view :: proc(t: ^testing.T) {
	descriptor := wgpu_single_mip_texture_view_descriptor(wgpu_string_view_empty())
	testing.expect_value(t, descriptor.next_in_chain, (^WGPU_Chained_Struct)(nil))
	testing.expect_value(t, descriptor.label, wgpu_string_view_empty())
	testing.expect_value(t, descriptor.format, WGPU_TEXTURE_FORMAT_UNDEFINED)
	testing.expect_value(t, descriptor.dimension, WGPU_TEXTURE_VIEW_DIMENSION_UNDEFINED)
	testing.expect_value(t, descriptor.base_mip_level, u32(0))
	testing.expect_value(t, descriptor.mip_level_count, u32(1))
	testing.expect_value(t, descriptor.base_array_layer, u32(0))
	testing.expect_value(t, descriptor.array_layer_count, u32(1))
	testing.expect_value(t, descriptor.aspect, WGPU_TEXTURE_ASPECT_ALL)
	testing.expect_value(t, descriptor.usage, WGPU_TEXTURE_USAGE_NONE)
}

@(test)
test_wgpu_buffer_descriptor_matches_offscreen_staging_defaults :: proc(t: ^testing.T) {
	descriptor := wgpu_buffer_descriptor(wgpu_string_view_empty(), wgpu_staging_buffer_usage(), 4096)
	testing.expect_value(t, descriptor.next_in_chain, (^WGPU_Chained_Struct)(nil))
	testing.expect_value(t, descriptor.label, wgpu_string_view_empty())
	testing.expect_value(t, descriptor.usage, WGPU_BUFFER_USAGE_MAP_READ | WGPU_BUFFER_USAGE_COPY_DST)
	testing.expect_value(t, descriptor.size, u64(4096))
	testing.expect_value(t, descriptor.mapped_at_creation, WGPU_FALSE)
}

@(test)
test_wgpu_copy_texture_to_buffer_structs_match_offscreen_readback_defaults :: proc(t: ^testing.T) {
	texture := WGPU_Texture(rawptr(uintptr(0x4444)))
	buffer := WGPU_Buffer(rawptr(uintptr(0x5555)))

	source := wgpu_texel_copy_texture_info(texture)
	testing.expect_value(t, source.texture, texture)
	testing.expect_value(t, source.mip_level, u32(0))
	testing.expect_value(t, source.origin, WGPU_Origin_3D{})
	testing.expect_value(t, source.aspect, WGPU_TEXTURE_ASPECT_ALL)

	destination := wgpu_texel_copy_buffer_info(buffer, 2560, 480)
	testing.expect_value(t, destination.buffer, buffer)
	testing.expect_value(t, destination.layout.offset, u64(0))
	testing.expect_value(t, destination.layout.bytes_per_row, u32(2560))
	testing.expect_value(t, destination.layout.rows_per_image, u32(480))
}

@(test)
test_wgpu_command_descriptors_hold_labels_and_no_chains :: proc(t: ^testing.T) {
	label := wgpu_string_view_from_raw(rawptr(uintptr(0x9876)), 13)
	encoder := wgpu_command_encoder_descriptor(label)
	command_buffer := wgpu_command_buffer_descriptor(label)

	testing.expect_value(t, encoder.next_in_chain, (^WGPU_Chained_Struct)(nil))
	testing.expect_value(t, encoder.label, label)
	testing.expect_value(t, command_buffer.next_in_chain, (^WGPU_Chained_Struct)(nil))
	testing.expect_value(t, command_buffer.label, label)
}

@(test)
test_wgpu_buffer_map_callback_info_uses_process_events_mode :: proc(t: ^testing.T) {
	userdata1 := rawptr(uintptr(0x1111))
	userdata2 := rawptr(uintptr(0x2222))
	info := wgpu_buffer_map_callback_info(wgpu_test_buffer_map_callback, userdata1, userdata2)
	testing.expect_value(t, info.next_in_chain, (^WGPU_Chained_Struct)(nil))
	testing.expect_value(t, info.mode, WGPU_CALLBACK_MODE_ALLOW_PROCESS_EVENTS)
	testing.expect_value(t, info.callback, WGPU_Buffer_Map_Callback(wgpu_test_buffer_map_callback))
	testing.expect_value(t, info.userdata1, userdata1)
	testing.expect_value(t, info.userdata2, userdata2)
}

@(test)
test_wgpu_context_request_descriptors_match_open_gpu_defaults :: proc(t: ^testing.T) {
	instance := wgpu_instance_descriptor_default()
	testing.expect_value(t, instance.next_in_chain, (^WGPU_Chained_Struct)(nil))
	testing.expect_value(t, instance.features.next_in_chain, (^WGPU_Chained_Struct_Out)(nil))
	testing.expect_value(t, instance.features.timed_wait_any_enable, WGPU_FALSE)
	testing.expect_value(t, instance.features.timed_wait_any_max_count, c.size_t(0))

	adapter := wgpu_request_adapter_options(WGPU_Surface(rawptr(uintptr(0x7777))))
	testing.expect_value(t, adapter.next_in_chain, (^WGPU_Chained_Struct)(nil))
	testing.expect_value(t, adapter.feature_level, WGPU_FEATURE_LEVEL_CORE)
	testing.expect_value(t, adapter.power_preference, WGPU_POWER_PREFERENCE_UNDEFINED)
	testing.expect_value(t, adapter.force_fallback_adapter, WGPU_FALSE)
	testing.expect_value(t, adapter.backend_type, WGPU_BACKEND_TYPE_UNDEFINED)
	testing.expect_value(t, adapter.compatible_surface, WGPU_Surface(rawptr(uintptr(0x7777))))

	device := wgpu_device_descriptor_default()
	testing.expect_value(t, device.next_in_chain, (^WGPU_Chained_Struct)(nil))
	testing.expect_value(t, device.label, wgpu_string_view_empty())
	testing.expect_value(t, device.required_feature_count, c.size_t(0))
	testing.expect_value(t, device.required_features, rawptr(nil))
	testing.expect_value(t, device.required_limits, WGPU_Limits(nil))
	testing.expect_value(t, device.default_queue.next_in_chain, (^WGPU_Chained_Struct)(nil))
	testing.expect_value(t, device.default_queue.label, wgpu_string_view_empty())
	testing.expect_value(t, device.device_lost_callback_info.mode, WGPU_CALLBACK_MODE_ALLOW_PROCESS_EVENTS)
	testing.expect_value(t, device.device_lost_callback_info.callback, WGPU_Device_Lost_Callback(wgpu_default_device_lost_callback))
	testing.expect_value(t, device.uncaptured_error_callback_info.callback, WGPU_Uncaptured_Error_Callback(nil))
}

@(test)
test_wgpu_request_callback_infos_use_process_events_mode :: proc(t: ^testing.T) {
	userdata1 := rawptr(uintptr(0x1212))
	userdata2 := rawptr(uintptr(0x3434))
	adapter := wgpu_request_adapter_callback_info(wgpu_test_request_adapter_callback, userdata1, userdata2)
	testing.expect_value(t, adapter.next_in_chain, (^WGPU_Chained_Struct)(nil))
	testing.expect_value(t, adapter.mode, WGPU_CALLBACK_MODE_ALLOW_PROCESS_EVENTS)
	testing.expect_value(t, adapter.callback, WGPU_Request_Adapter_Callback(wgpu_test_request_adapter_callback))
	testing.expect_value(t, adapter.userdata1, userdata1)
	testing.expect_value(t, adapter.userdata2, userdata2)

	device := wgpu_request_device_callback_info(wgpu_test_request_device_callback, userdata1, userdata2)
	testing.expect_value(t, device.next_in_chain, (^WGPU_Chained_Struct)(nil))
	testing.expect_value(t, device.mode, WGPU_CALLBACK_MODE_ALLOW_PROCESS_EVENTS)
	testing.expect_value(t, device.callback, WGPU_Request_Device_Callback(wgpu_test_request_device_callback))
	testing.expect_value(t, device.userdata1, userdata1)
	testing.expect_value(t, device.userdata2, userdata2)
}

@(test)
test_wgpu_offscreen_proc_table_resolves_required_symbols :: proc(t: ^testing.T) {
	ctx := WGPU_Test_Resolver_Context{}
	procs, missing, ok := wgpu_resolve_offscreen_procs(wgpu_test_symbol_resolver, rawptr(&ctx))

	testing.expect_value(t, ok, true)
	testing.expect_value(t, missing, "")
	testing.expect_value(t, ctx.calls, 24)
	testing.expect_value(t, ctx.last_user_data, rawptr(&ctx))

	instance := procs.create_instance((^WGPU_Instance_Descriptor)(nil))
	testing.expect_value(t, instance, WGPU_Instance(rawptr(uintptr(0x100A))))

	texture := procs.device_create_texture(WGPU_Device(nil), (^WGPU_Texture_Descriptor)(nil))
	testing.expect_value(t, texture, WGPU_Texture(rawptr(uintptr(0x1001))))

	command_buffer := procs.command_encoder_finish(WGPU_Command_Encoder(nil), (^WGPU_Command_Buffer_Descriptor)(nil))
	testing.expect_value(t, command_buffer, WGPU_Command_Buffer(rawptr(uintptr(0x1006))))

	future := procs.buffer_map_async(WGPU_Buffer(nil), WGPU_MAP_MODE_READ, 0, 16, wgpu_buffer_map_callback_info(wgpu_test_buffer_map_callback))
	testing.expect_value(t, future, WGPU_Future{id = 0x1008})

	queue := procs.device_get_queue(WGPU_Device(nil))
	testing.expect_value(t, queue, WGPU_Queue(rawptr(uintptr(0x100D))))
}

@(test)
test_wgpu_offscreen_proc_table_reports_first_missing_symbol :: proc(t: ^testing.T) {
	ctx := WGPU_Test_Resolver_Context{missing = WGPU_SYMBOL_COMMAND_ENCODER_FINISH}
	_, missing, ok := wgpu_resolve_offscreen_procs(wgpu_test_symbol_resolver, rawptr(&ctx))

	testing.expect_value(t, ok, false)
	testing.expect_value(t, missing, WGPU_SYMBOL_COMMAND_ENCODER_FINISH)
	testing.expect_value(t, ctx.calls, 10)
}

@(test)
test_wgpu_offscreen_dynamic_library_loads_proc_table :: proc(t: ^testing.T) {
	root := make_test_project_root(t, "wgpu-offscreen-dynlib")
	defer os.remove_all(root)
	defer delete(root)

	library_path := build_fake_wgpu_library(t, root, FAKE_WGPU_DYNAMIC_LIBRARY_SOURCE)
	defer delete(library_path)

	loaded, missing, ok := wgpu_load_offscreen_library(library_path)
	defer wgpu_unload_offscreen_library(&loaded)

	testing.expect_value(t, ok, true)
	testing.expect_value(t, missing, "")

	instance := loaded.procs.create_instance((^WGPU_Instance_Descriptor)(nil))
	testing.expect_value(t, instance, WGPU_Instance(rawptr(uintptr(0x200A))))

	adapter_future := loaded.procs.instance_request_adapter(WGPU_Instance(nil), (^WGPU_Request_Adapter_Options)(nil), wgpu_request_adapter_callback_info(wgpu_test_request_adapter_callback))
	testing.expect_value(t, adapter_future, WGPU_Future{id = 0x200B})

	device_future := loaded.procs.adapter_request_device(WGPU_Adapter(nil), (^WGPU_Device_Descriptor)(nil), wgpu_request_device_callback_info(wgpu_test_request_device_callback))
	testing.expect_value(t, device_future, WGPU_Future{id = 0x200C})

	queue := loaded.procs.device_get_queue(WGPU_Device(nil))
	testing.expect_value(t, queue, WGPU_Queue(rawptr(uintptr(0x200D))))

	texture := loaded.procs.device_create_texture(WGPU_Device(nil), (^WGPU_Texture_Descriptor)(nil))
	testing.expect_value(t, texture, WGPU_Texture(rawptr(uintptr(0x2001))))

	future := loaded.procs.buffer_map_async(WGPU_Buffer(nil), WGPU_MAP_MODE_READ, 0, 16, wgpu_buffer_map_callback_info(wgpu_test_buffer_map_callback))
	testing.expect_value(t, future, WGPU_Future{id = 0x2008})
}

@(test)
test_wgpu_offscreen_dynamic_library_reports_missing_required_symbol :: proc(t: ^testing.T) {
	root := make_test_project_root(t, "wgpu-offscreen-dynlib-missing-symbol")
	defer os.remove_all(root)
	defer delete(root)

	library_path := build_fake_wgpu_library(t, root, FAKE_WGPU_MISSING_SYMBOL_DYNAMIC_LIBRARY_SOURCE)
	defer delete(library_path)

	loaded, missing, ok := wgpu_load_offscreen_library(library_path)

	testing.expect_value(t, ok, false)
	testing.expect_value(t, missing, WGPU_SYMBOL_COMMAND_ENCODER_FINISH)
	testing.expect_value(t, loaded.handle, dynlib.Library(nil))
}

@(test)
test_wgpu_offscreen_dynamic_library_reports_load_failure :: proc(t: ^testing.T) {
	root := make_test_project_root(t, "wgpu-offscreen-dynlib-missing-file")
	defer os.remove_all(root)
	defer delete(root)

	library_path := join_test_path(t, root, dynamic_library_file_name())
	defer delete(library_path)

	loaded, missing, ok := wgpu_load_offscreen_library(library_path)

	testing.expect_value(t, ok, false)
	testing.expect_value(t, missing, WGPU_OFFSCREEN_LIBRARY_LOAD_ERROR)
	testing.expect_value(t, loaded.handle, dynlib.Library(nil))
}

build_fake_wgpu_library :: proc(t: ^testing.T, root, source: string) -> string {
	write_file(t, root, "fake_wgpu.odin", source)

	output_name := dynamic_library_file_name()
	output_path := join_test_path(t, root, output_name)
	output_arg := build_prefixed_string("-out:", output_name)
	defer delete(output_arg)

	command := []string{"odin", "build", ".", "-build-mode:dll", output_arg}
	state, stdout, stderr, exec_err := os.process_exec(os.Process_Desc{
		working_dir = root,
		command = command,
	}, context.allocator)
	defer {
		if stdout != nil {
			delete(stdout)
		}
		if stderr != nil {
			delete(stderr)
		}
	}
	if exec_err != nil || !state.exited || state.exit_code != 0 || !os.exists(output_path) {
		delete(output_path)
		testing.fail_now(t, "failed to build fake wgpu dynamic library")
	}

	return output_path
}

wgpu_test_buffer_map_callback :: proc "c" (status: WGPU_Map_Async_Status, message: WGPU_String_View, userdata1, userdata2: rawptr) {
	_ = status
	_ = message
	_ = userdata1
	_ = userdata2
}

wgpu_test_request_adapter_callback :: proc "c" (status: WGPU_Request_Adapter_Status, adapter: WGPU_Adapter, message: WGPU_String_View, userdata1, userdata2: rawptr) {
	_ = status
	_ = adapter
	_ = message
	_ = userdata1
	_ = userdata2
}

wgpu_test_request_device_callback :: proc "c" (status: WGPU_Request_Device_Status, device: WGPU_Device, message: WGPU_String_View, userdata1, userdata2: rawptr) {
	_ = status
	_ = device
	_ = message
	_ = userdata1
	_ = userdata2
}

FAKE_WGPU_DYNAMIC_LIBRARY_SOURCE :: `package fake_wgpu

import "core:c"

WGPU_Future :: struct {
	id: u64,
}

WGPU_String_View :: struct #align(align_of(rawptr)) {
	data:   rawptr,
	length: c.size_t,
}

WGPU_Buffer_Map_Callback_Info :: struct #align(align_of(rawptr)) {
	next_in_chain: rawptr,
	mode:          u32,
	callback:      rawptr,
	userdata1:     rawptr,
	userdata2:     rawptr,
}

WGPU_Request_Adapter_Callback_Info :: struct #align(align_of(rawptr)) {
	next_in_chain: rawptr,
	mode:          u32,
	callback:      rawptr,
	userdata1:     rawptr,
	userdata2:     rawptr,
}

WGPU_Request_Device_Callback_Info :: struct #align(align_of(rawptr)) {
	next_in_chain: rawptr,
	mode:          u32,
	callback:      rawptr,
	userdata1:     rawptr,
	userdata2:     rawptr,
}

@(export)
wgpuCreateInstance :: proc "c" (descriptor: rawptr) -> rawptr {
	_ = descriptor
	return rawptr(uintptr(0x200A))
}

@(export)
wgpuInstanceRequestAdapter :: proc "c" (instance, options: rawptr, callback_info: WGPU_Request_Adapter_Callback_Info) -> WGPU_Future {
	_ = instance
	_ = options
	_ = callback_info
	return WGPU_Future{id = 0x200B}
}

@(export)
wgpuAdapterRequestDevice :: proc "c" (adapter, descriptor: rawptr, callback_info: WGPU_Request_Device_Callback_Info) -> WGPU_Future {
	_ = adapter
	_ = descriptor
	_ = callback_info
	return WGPU_Future{id = 0x200C}
}

@(export)
wgpuDeviceGetQueue :: proc "c" (device: rawptr) -> rawptr {
	_ = device
	return rawptr(uintptr(0x200D))
}

@(export)
wgpuDeviceCreateTexture :: proc "c" (device, descriptor: rawptr) -> rawptr {
	_ = device
	_ = descriptor
	return rawptr(uintptr(0x2001))
}

@(export)
wgpuDeviceCreateBuffer :: proc "c" (device, descriptor: rawptr) -> rawptr {
	_ = device
	_ = descriptor
	return rawptr(uintptr(0x2002))
}

@(export)
wgpuDeviceCreateCommandEncoder :: proc "c" (device, descriptor: rawptr) -> rawptr {
	_ = device
	_ = descriptor
	return rawptr(uintptr(0x2003))
}

@(export)
wgpuTextureCreateView :: proc "c" (texture, descriptor: rawptr) -> rawptr {
	_ = texture
	_ = descriptor
	return rawptr(uintptr(0x2004))
}

@(export)
wgpuCommandEncoderCopyTextureToBuffer :: proc "c" (encoder, source, destination, copy_size: rawptr) {
	_ = encoder
	_ = source
	_ = destination
	_ = copy_size
}

@(export)
wgpuCommandEncoderFinish :: proc "c" (encoder, descriptor: rawptr) -> rawptr {
	_ = encoder
	_ = descriptor
	return rawptr(uintptr(0x2006))
}

@(export)
wgpuQueueSubmit :: proc "c" (queue: rawptr, command_count: c.size_t, commands: rawptr) {
	_ = queue
	_ = command_count
	_ = commands
}

@(export)
wgpuBufferMapAsync :: proc "c" (buffer: rawptr, mode: u64, offset, size: c.size_t, callback_info: WGPU_Buffer_Map_Callback_Info) -> WGPU_Future {
	_ = buffer
	_ = mode
	_ = offset
	_ = size
	_ = callback_info
	return WGPU_Future{id = 0x2008}
}

@(export)
wgpuBufferGetMappedRange :: proc "c" (buffer: rawptr, offset, size: c.size_t) -> rawptr {
	_ = buffer
	_ = offset
	_ = size
	return rawptr(uintptr(0x2009))
}

@(export)
wgpuBufferUnmap :: proc "c" (buffer: rawptr) {
	_ = buffer
}

@(export)
wgpuInstanceProcessEvents :: proc "c" (instance: rawptr) {
	_ = instance
}

@(export)
wgpuTextureRelease :: proc "c" (texture: rawptr) {
	_ = texture
}

@(export)
wgpuTextureViewRelease :: proc "c" (texture_view: rawptr) {
	_ = texture_view
}

@(export)
wgpuBufferRelease :: proc "c" (buffer: rawptr) {
	_ = buffer
}

@(export)
wgpuCommandEncoderRelease :: proc "c" (encoder: rawptr) {
	_ = encoder
}

@(export)
wgpuCommandBufferRelease :: proc "c" (command_buffer: rawptr) {
	_ = command_buffer
}

@(export)
wgpuInstanceRelease :: proc "c" (instance: rawptr) {
	_ = instance
}

@(export)
wgpuAdapterRelease :: proc "c" (adapter: rawptr) {
	_ = adapter
}

@(export)
wgpuDeviceRelease :: proc "c" (device: rawptr) {
	_ = device
}

@(export)
wgpuQueueRelease :: proc "c" (queue: rawptr) {
	_ = queue
}
`

FAKE_WGPU_MISSING_SYMBOL_DYNAMIC_LIBRARY_SOURCE :: `package fake_wgpu

import "core:c"

WGPU_Future :: struct {
	id: u64,
}

WGPU_Buffer_Map_Callback_Info :: struct #align(align_of(rawptr)) {
	next_in_chain: rawptr,
	mode:          u32,
	callback:      rawptr,
	userdata1:     rawptr,
	userdata2:     rawptr,
}

WGPU_Request_Adapter_Callback_Info :: struct #align(align_of(rawptr)) {
	next_in_chain: rawptr,
	mode:          u32,
	callback:      rawptr,
	userdata1:     rawptr,
	userdata2:     rawptr,
}

WGPU_Request_Device_Callback_Info :: struct #align(align_of(rawptr)) {
	next_in_chain: rawptr,
	mode:          u32,
	callback:      rawptr,
	userdata1:     rawptr,
	userdata2:     rawptr,
}

@(export)
wgpuCreateInstance :: proc "c" (descriptor: rawptr) -> rawptr {
	_ = descriptor
	return rawptr(uintptr(0x300A))
}

@(export)
wgpuInstanceRequestAdapter :: proc "c" (instance, options: rawptr, callback_info: WGPU_Request_Adapter_Callback_Info) -> WGPU_Future {
	_ = instance
	_ = options
	_ = callback_info
	return WGPU_Future{id = 0x300B}
}

@(export)
wgpuAdapterRequestDevice :: proc "c" (adapter, descriptor: rawptr, callback_info: WGPU_Request_Device_Callback_Info) -> WGPU_Future {
	_ = adapter
	_ = descriptor
	_ = callback_info
	return WGPU_Future{id = 0x300C}
}

@(export)
wgpuDeviceGetQueue :: proc "c" (device: rawptr) -> rawptr {
	_ = device
	return rawptr(uintptr(0x300D))
}

@(export)
wgpuDeviceCreateTexture :: proc "c" (device, descriptor: rawptr) -> rawptr {
	_ = device
	_ = descriptor
	return rawptr(uintptr(0x3001))
}

@(export)
wgpuDeviceCreateBuffer :: proc "c" (device, descriptor: rawptr) -> rawptr {
	_ = device
	_ = descriptor
	return rawptr(uintptr(0x3002))
}

@(export)
wgpuDeviceCreateCommandEncoder :: proc "c" (device, descriptor: rawptr) -> rawptr {
	_ = device
	_ = descriptor
	return rawptr(uintptr(0x3003))
}

@(export)
wgpuTextureCreateView :: proc "c" (texture, descriptor: rawptr) -> rawptr {
	_ = texture
	_ = descriptor
	return rawptr(uintptr(0x3004))
}

@(export)
wgpuCommandEncoderCopyTextureToBuffer :: proc "c" (encoder, source, destination, copy_size: rawptr) {
	_ = encoder
	_ = source
	_ = destination
	_ = copy_size
}

@(export)
wgpuQueueSubmit :: proc "c" (queue: rawptr, command_count: c.size_t, commands: rawptr) {
	_ = queue
	_ = command_count
	_ = commands
}

@(export)
wgpuBufferMapAsync :: proc "c" (buffer: rawptr, mode: u64, offset, size: c.size_t, callback_info: WGPU_Buffer_Map_Callback_Info) -> WGPU_Future {
	_ = buffer
	_ = mode
	_ = offset
	_ = size
	_ = callback_info
	return WGPU_Future{id = 0x3008}
}

@(export)
wgpuBufferGetMappedRange :: proc "c" (buffer: rawptr, offset, size: c.size_t) -> rawptr {
	_ = buffer
	_ = offset
	_ = size
	return rawptr(uintptr(0x3009))
}

@(export)
wgpuBufferUnmap :: proc "c" (buffer: rawptr) {
	_ = buffer
}

@(export)
wgpuInstanceProcessEvents :: proc "c" (instance: rawptr) {
	_ = instance
}

@(export)
wgpuTextureRelease :: proc "c" (texture: rawptr) {
	_ = texture
}

@(export)
wgpuTextureViewRelease :: proc "c" (texture_view: rawptr) {
	_ = texture_view
}

@(export)
wgpuBufferRelease :: proc "c" (buffer: rawptr) {
	_ = buffer
}

@(export)
wgpuCommandEncoderRelease :: proc "c" (encoder: rawptr) {
	_ = encoder
}

@(export)
wgpuCommandBufferRelease :: proc "c" (command_buffer: rawptr) {
	_ = command_buffer
}

@(export)
wgpuInstanceRelease :: proc "c" (instance: rawptr) {
	_ = instance
}

@(export)
wgpuAdapterRelease :: proc "c" (adapter: rawptr) {
	_ = adapter
}

@(export)
wgpuDeviceRelease :: proc "c" (device: rawptr) {
	_ = device
}

@(export)
wgpuQueueRelease :: proc "c" (queue: rawptr) {
	_ = queue
}
`

WGPU_Test_Resolver_Context :: struct {
	missing:        string,
	calls:          int,
	last_user_data: rawptr,
}

wgpu_test_symbol_resolver :: proc(name: string, user_data: rawptr) -> rawptr {
	ctx := (^WGPU_Test_Resolver_Context)(user_data)
	ctx.calls += 1
	ctx.last_user_data = user_data
	if ctx.missing == name {
		return nil
	}
	switch name {
	case WGPU_SYMBOL_CREATE_INSTANCE:
		return rawptr(wgpu_test_create_instance)
	case WGPU_SYMBOL_INSTANCE_REQUEST_ADAPTER:
		return rawptr(wgpu_test_instance_request_adapter)
	case WGPU_SYMBOL_ADAPTER_REQUEST_DEVICE:
		return rawptr(wgpu_test_adapter_request_device)
	case WGPU_SYMBOL_DEVICE_GET_QUEUE:
		return rawptr(wgpu_test_device_get_queue)
	case WGPU_SYMBOL_DEVICE_CREATE_TEXTURE:
		return rawptr(wgpu_test_device_create_texture)
	case WGPU_SYMBOL_DEVICE_CREATE_BUFFER:
		return rawptr(wgpu_test_device_create_buffer)
	case WGPU_SYMBOL_DEVICE_CREATE_COMMAND_ENCODER:
		return rawptr(wgpu_test_device_create_command_encoder)
	case WGPU_SYMBOL_TEXTURE_CREATE_VIEW:
		return rawptr(wgpu_test_texture_create_view)
	case WGPU_SYMBOL_COMMAND_ENCODER_COPY_TEXTURE_TO_BUFFER:
		return rawptr(wgpu_test_command_encoder_copy_texture_to_buffer)
	case WGPU_SYMBOL_COMMAND_ENCODER_FINISH:
		return rawptr(wgpu_test_command_encoder_finish)
	case WGPU_SYMBOL_QUEUE_SUBMIT:
		return rawptr(wgpu_test_queue_submit)
	case WGPU_SYMBOL_BUFFER_MAP_ASYNC:
		return rawptr(wgpu_test_buffer_map_async)
	case WGPU_SYMBOL_BUFFER_GET_MAPPED_RANGE:
		return rawptr(wgpu_test_buffer_get_mapped_range)
	case WGPU_SYMBOL_BUFFER_UNMAP:
		return rawptr(wgpu_test_buffer_unmap)
	case WGPU_SYMBOL_INSTANCE_PROCESS_EVENTS:
		return rawptr(wgpu_test_instance_process_events)
	case WGPU_SYMBOL_TEXTURE_RELEASE:
		return rawptr(wgpu_test_texture_release)
	case WGPU_SYMBOL_TEXTURE_VIEW_RELEASE:
		return rawptr(wgpu_test_texture_view_release)
	case WGPU_SYMBOL_BUFFER_RELEASE:
		return rawptr(wgpu_test_buffer_release)
	case WGPU_SYMBOL_COMMAND_ENCODER_RELEASE:
		return rawptr(wgpu_test_command_encoder_release)
	case WGPU_SYMBOL_COMMAND_BUFFER_RELEASE:
		return rawptr(wgpu_test_command_buffer_release)
	case WGPU_SYMBOL_INSTANCE_RELEASE:
		return rawptr(wgpu_test_instance_release)
	case WGPU_SYMBOL_ADAPTER_RELEASE:
		return rawptr(wgpu_test_adapter_release)
	case WGPU_SYMBOL_DEVICE_RELEASE:
		return rawptr(wgpu_test_device_release)
	case WGPU_SYMBOL_QUEUE_RELEASE:
		return rawptr(wgpu_test_queue_release)
	}
	return nil
}

wgpu_test_create_instance :: proc "c" (descriptor: ^WGPU_Instance_Descriptor) -> WGPU_Instance {
	_ = descriptor
	return WGPU_Instance(rawptr(uintptr(0x100A)))
}

wgpu_test_instance_request_adapter :: proc "c" (instance: WGPU_Instance, options: ^WGPU_Request_Adapter_Options, callback_info: WGPU_Request_Adapter_Callback_Info) -> WGPU_Future {
	_ = instance
	_ = options
	_ = callback_info
	return WGPU_Future{id = 0x100B}
}

wgpu_test_adapter_request_device :: proc "c" (adapter: WGPU_Adapter, descriptor: ^WGPU_Device_Descriptor, callback_info: WGPU_Request_Device_Callback_Info) -> WGPU_Future {
	_ = adapter
	_ = descriptor
	_ = callback_info
	return WGPU_Future{id = 0x100C}
}

wgpu_test_device_get_queue :: proc "c" (device: WGPU_Device) -> WGPU_Queue {
	_ = device
	return WGPU_Queue(rawptr(uintptr(0x100D)))
}

wgpu_test_device_create_texture :: proc "c" (device: WGPU_Device, descriptor: ^WGPU_Texture_Descriptor) -> WGPU_Texture {
	_ = device
	_ = descriptor
	return WGPU_Texture(rawptr(uintptr(0x1001)))
}

wgpu_test_device_create_buffer :: proc "c" (device: WGPU_Device, descriptor: ^WGPU_Buffer_Descriptor) -> WGPU_Buffer {
	_ = device
	_ = descriptor
	return WGPU_Buffer(rawptr(uintptr(0x1002)))
}

wgpu_test_device_create_command_encoder :: proc "c" (device: WGPU_Device, descriptor: ^WGPU_Command_Encoder_Descriptor) -> WGPU_Command_Encoder {
	_ = device
	_ = descriptor
	return WGPU_Command_Encoder(rawptr(uintptr(0x1003)))
}

wgpu_test_texture_create_view :: proc "c" (texture: WGPU_Texture, descriptor: ^WGPU_Texture_View_Descriptor) -> WGPU_Texture_View {
	_ = texture
	_ = descriptor
	return WGPU_Texture_View(rawptr(uintptr(0x1004)))
}

wgpu_test_command_encoder_copy_texture_to_buffer :: proc "c" (encoder: WGPU_Command_Encoder, source: ^WGPU_Texel_Copy_Texture_Info, destination: ^WGPU_Texel_Copy_Buffer_Info, copy_size: ^WGPU_Extent_3D) {
	_ = encoder
	_ = source
	_ = destination
	_ = copy_size
}

wgpu_test_command_encoder_finish :: proc "c" (encoder: WGPU_Command_Encoder, descriptor: ^WGPU_Command_Buffer_Descriptor) -> WGPU_Command_Buffer {
	_ = encoder
	_ = descriptor
	return WGPU_Command_Buffer(rawptr(uintptr(0x1006)))
}

wgpu_test_queue_submit :: proc "c" (queue: WGPU_Queue, command_count: c.size_t, commands: [^]WGPU_Command_Buffer) {
	_ = queue
	_ = command_count
	_ = commands
}

wgpu_test_buffer_map_async :: proc "c" (buffer: WGPU_Buffer, mode: WGPU_Map_Mode, offset, size: c.size_t, callback_info: WGPU_Buffer_Map_Callback_Info) -> WGPU_Future {
	_ = buffer
	_ = mode
	_ = offset
	_ = size
	_ = callback_info
	return WGPU_Future{id = 0x1008}
}

wgpu_test_buffer_get_mapped_range :: proc "c" (buffer: WGPU_Buffer, offset, size: c.size_t) -> rawptr {
	_ = buffer
	_ = offset
	_ = size
	return rawptr(uintptr(0x1009))
}

wgpu_test_buffer_unmap :: proc "c" (buffer: WGPU_Buffer) {
	_ = buffer
}

wgpu_test_instance_process_events :: proc "c" (instance: WGPU_Instance) {
	_ = instance
}

wgpu_test_texture_release :: proc "c" (texture: WGPU_Texture) {
	_ = texture
}

wgpu_test_texture_view_release :: proc "c" (texture_view: WGPU_Texture_View) {
	_ = texture_view
}

wgpu_test_buffer_release :: proc "c" (buffer: WGPU_Buffer) {
	_ = buffer
}

wgpu_test_command_encoder_release :: proc "c" (encoder: WGPU_Command_Encoder) {
	_ = encoder
}

wgpu_test_command_buffer_release :: proc "c" (command_buffer: WGPU_Command_Buffer) {
	_ = command_buffer
}

wgpu_test_instance_release :: proc "c" (instance: WGPU_Instance) {
	_ = instance
}

wgpu_test_adapter_release :: proc "c" (adapter: WGPU_Adapter) {
	_ = adapter
}

wgpu_test_device_release :: proc "c" (device: WGPU_Device) {
	_ = device
}

wgpu_test_queue_release :: proc "c" (queue: WGPU_Queue) {
	_ = queue
}

@(test)
test_wgpu_platform_surface_stype_values_match_vendored_binding :: proc(t: ^testing.T) {
	testing.expect_value(t, WGPU_STYPE_SURFACE_SOURCE_METAL_LAYER, WGPU_SType(0x00000004))
	testing.expect_value(t, WGPU_STYPE_SURFACE_SOURCE_WINDOWS_HWND, WGPU_SType(0x00000005))
	testing.expect_value(t, WGPU_STYPE_SURFACE_SOURCE_XLIB_WINDOW, WGPU_SType(0x00000006))
	testing.expect_value(t, WGPU_STYPE_SURFACE_SOURCE_WAYLAND_SURFACE, WGPU_SType(0x00000007))
	testing.expect_value(t, WGPU_STYPE_SURFACE_SOURCE_XCB_WINDOW, WGPU_SType(0x00000009))
}
