package main

import "core:c"
import "core:dynlib"

// First-pass wgpu-native C ABI surface used by the Odin renderer migration.
// This file intentionally avoids foreign procedure declarations until the Odin
// build owns platform-specific wgpu-native linking.

WGPU_U32_MAX :: u32(~u32(0))
WGPU_U64_MAX :: u64(~u64(0))
WGPU_USIZE_MAX :: uint(~uint(0))

WGPU_WHOLE_SIZE :: WGPU_U64_MAX
WGPU_STRLEN :: c.size_t(WGPU_USIZE_MAX)

WGPU_Bool :: u32
WGPU_Flags :: u64
WGPU_Buffer_Usage :: WGPU_Flags
WGPU_Texture_Usage :: WGPU_Flags
WGPU_Texture_Format :: u32
WGPU_Texture_Dimension :: u32
WGPU_Texture_View_Dimension :: u32
WGPU_Texture_Aspect :: u32
WGPU_Map_Mode :: WGPU_Flags
WGPU_Callback_Mode :: u32
WGPU_Feature_Level :: u32
WGPU_Power_Preference :: u32
WGPU_Backend_Type :: u32
WGPU_Request_Adapter_Status :: u32
WGPU_Request_Device_Status :: u32
WGPU_Device_Lost_Reason :: u32
WGPU_Error_Type :: u32
WGPU_Feature_Name :: u32
WGPU_SType :: u32
WGPU_Status :: u32
WGPU_Optional_Bool :: u32
WGPU_Map_Async_Status :: u32

WGPU_Instance :: rawptr
WGPU_Adapter :: rawptr
WGPU_Device :: rawptr
WGPU_Queue :: rawptr
WGPU_Surface :: rawptr
WGPU_Texture :: rawptr
WGPU_Texture_View :: rawptr
WGPU_Buffer :: rawptr
WGPU_Shader_Module :: rawptr
WGPU_Render_Pipeline :: rawptr
WGPU_Pipeline_Layout :: rawptr
WGPU_Bind_Group :: rawptr
WGPU_Bind_Group_Layout :: rawptr
WGPU_Command_Encoder :: rawptr
WGPU_Command_Buffer :: rawptr
WGPU_Render_Pass_Encoder :: rawptr
WGPU_Limits :: rawptr

WGPU_FALSE :: WGPU_Bool(0)
WGPU_TRUE :: WGPU_Bool(1)

WGPU_STATUS_SUCCESS :: WGPU_Status(0x00000001)
WGPU_STATUS_ERROR :: WGPU_Status(0x00000002)

WGPU_OPTIONAL_BOOL_FALSE :: WGPU_Optional_Bool(0x00000000)
WGPU_OPTIONAL_BOOL_TRUE :: WGPU_Optional_Bool(0x00000001)
WGPU_OPTIONAL_BOOL_UNDEFINED :: WGPU_Optional_Bool(0x00000002)

WGPU_MAP_ASYNC_STATUS_SUCCESS :: WGPU_Map_Async_Status(0x00000001)
WGPU_MAP_ASYNC_STATUS_INSTANCE_DROPPED :: WGPU_Map_Async_Status(0x00000002)
WGPU_MAP_ASYNC_STATUS_ERROR :: WGPU_Map_Async_Status(0x00000003)
WGPU_MAP_ASYNC_STATUS_ABORTED :: WGPU_Map_Async_Status(0x00000004)
WGPU_MAP_ASYNC_STATUS_UNKNOWN :: WGPU_Map_Async_Status(0x00000005)

WGPU_CALLBACK_MODE_WAIT_ANY_ONLY :: WGPU_Callback_Mode(0x00000001)
WGPU_CALLBACK_MODE_ALLOW_PROCESS_EVENTS :: WGPU_Callback_Mode(0x00000002)
WGPU_CALLBACK_MODE_ALLOW_SPONTANEOUS :: WGPU_Callback_Mode(0x00000003)

WGPU_FEATURE_LEVEL_COMPATIBILITY :: WGPU_Feature_Level(0x00000001)
WGPU_FEATURE_LEVEL_CORE :: WGPU_Feature_Level(0x00000002)

WGPU_POWER_PREFERENCE_UNDEFINED :: WGPU_Power_Preference(0x00000000)
WGPU_POWER_PREFERENCE_LOW_POWER :: WGPU_Power_Preference(0x00000001)
WGPU_POWER_PREFERENCE_HIGH_PERFORMANCE :: WGPU_Power_Preference(0x00000002)

WGPU_BACKEND_TYPE_UNDEFINED :: WGPU_Backend_Type(0x00000000)
WGPU_BACKEND_TYPE_NULL :: WGPU_Backend_Type(0x00000001)
WGPU_BACKEND_TYPE_WEBGPU :: WGPU_Backend_Type(0x00000002)
WGPU_BACKEND_TYPE_D3D11 :: WGPU_Backend_Type(0x00000003)
WGPU_BACKEND_TYPE_D3D12 :: WGPU_Backend_Type(0x00000004)
WGPU_BACKEND_TYPE_METAL :: WGPU_Backend_Type(0x00000005)
WGPU_BACKEND_TYPE_VULKAN :: WGPU_Backend_Type(0x00000006)
WGPU_BACKEND_TYPE_OPENGL :: WGPU_Backend_Type(0x00000007)
WGPU_BACKEND_TYPE_OPENGL_ES :: WGPU_Backend_Type(0x00000008)

WGPU_REQUEST_ADAPTER_STATUS_SUCCESS :: WGPU_Request_Adapter_Status(0x00000001)
WGPU_REQUEST_ADAPTER_STATUS_INSTANCE_DROPPED :: WGPU_Request_Adapter_Status(0x00000002)
WGPU_REQUEST_ADAPTER_STATUS_UNAVAILABLE :: WGPU_Request_Adapter_Status(0x00000003)
WGPU_REQUEST_ADAPTER_STATUS_ERROR :: WGPU_Request_Adapter_Status(0x00000004)
WGPU_REQUEST_ADAPTER_STATUS_UNKNOWN :: WGPU_Request_Adapter_Status(0x00000005)

WGPU_REQUEST_DEVICE_STATUS_SUCCESS :: WGPU_Request_Device_Status(0x00000001)
WGPU_REQUEST_DEVICE_STATUS_INSTANCE_DROPPED :: WGPU_Request_Device_Status(0x00000002)
WGPU_REQUEST_DEVICE_STATUS_ERROR :: WGPU_Request_Device_Status(0x00000003)
WGPU_REQUEST_DEVICE_STATUS_UNKNOWN :: WGPU_Request_Device_Status(0x00000004)

WGPU_DEVICE_LOST_REASON_UNKNOWN :: WGPU_Device_Lost_Reason(0x00000001)
WGPU_DEVICE_LOST_REASON_DESTROYED :: WGPU_Device_Lost_Reason(0x00000002)
WGPU_DEVICE_LOST_REASON_INSTANCE_DROPPED :: WGPU_Device_Lost_Reason(0x00000003)
WGPU_DEVICE_LOST_REASON_FAILED_CREATION :: WGPU_Device_Lost_Reason(0x00000004)

WGPU_ERROR_TYPE_NO_ERROR :: WGPU_Error_Type(0x00000001)
WGPU_ERROR_TYPE_VALIDATION :: WGPU_Error_Type(0x00000002)
WGPU_ERROR_TYPE_OUT_OF_MEMORY :: WGPU_Error_Type(0x00000003)
WGPU_ERROR_TYPE_INTERNAL :: WGPU_Error_Type(0x00000004)
WGPU_ERROR_TYPE_UNKNOWN :: WGPU_Error_Type(0x00000005)

WGPU_STYPE_SHADER_SOURCE_SPIRV :: WGPU_SType(0x00000001)
WGPU_STYPE_SHADER_SOURCE_WGSL :: WGPU_SType(0x00000002)
WGPU_STYPE_RENDER_PASS_MAX_DRAW_COUNT :: WGPU_SType(0x00000003)
WGPU_STYPE_SURFACE_SOURCE_METAL_LAYER :: WGPU_SType(0x00000004)
WGPU_STYPE_SURFACE_SOURCE_WINDOWS_HWND :: WGPU_SType(0x00000005)
WGPU_STYPE_SURFACE_SOURCE_XLIB_WINDOW :: WGPU_SType(0x00000006)
WGPU_STYPE_SURFACE_SOURCE_WAYLAND_SURFACE :: WGPU_SType(0x00000007)
WGPU_STYPE_SURFACE_SOURCE_ANDROID_NATIVE_WINDOW :: WGPU_SType(0x00000008)
WGPU_STYPE_SURFACE_SOURCE_XCB_WINDOW :: WGPU_SType(0x00000009)

WGPU_STYPE_DEVICE_EXTRAS :: WGPU_SType(0x00030001)
WGPU_STYPE_NATIVE_LIMITS :: WGPU_SType(0x00030002)
WGPU_STYPE_PIPELINE_LAYOUT_EXTRAS :: WGPU_SType(0x00030003)
WGPU_STYPE_SHADER_SOURCE_GLSL :: WGPU_SType(0x00030004)
WGPU_STYPE_INSTANCE_EXTRAS :: WGPU_SType(0x00030006)
WGPU_STYPE_BIND_GROUP_ENTRY_EXTRAS :: WGPU_SType(0x00030007)
WGPU_STYPE_BIND_GROUP_LAYOUT_ENTRY_EXTRAS :: WGPU_SType(0x00030008)
WGPU_STYPE_QUERY_SET_DESCRIPTOR_EXTRAS :: WGPU_SType(0x00030009)
WGPU_STYPE_SURFACE_CONFIGURATION_EXTRAS :: WGPU_SType(0x0003000A)

WGPU_TEXTURE_FORMAT_UNDEFINED :: WGPU_Texture_Format(0x00000000)
WGPU_TEXTURE_FORMAT_RGBA8_UNORM :: WGPU_Texture_Format(0x00000012)
WGPU_TEXTURE_FORMAT_RGBA8_UNORM_SRGB :: WGPU_Texture_Format(0x00000013)
WGPU_TEXTURE_FORMAT_BGRA8_UNORM :: WGPU_Texture_Format(0x00000017)
WGPU_TEXTURE_FORMAT_BGRA8_UNORM_SRGB :: WGPU_Texture_Format(0x00000018)
WGPU_TEXTURE_FORMAT_DEPTH24_PLUS :: WGPU_Texture_Format(0x00000028)
WGPU_TEXTURE_FORMAT_DEPTH24_PLUS_STENCIL8 :: WGPU_Texture_Format(0x00000029)
WGPU_TEXTURE_FORMAT_DEPTH32_FLOAT :: WGPU_Texture_Format(0x0000002A)
WGPU_TEXTURE_FORMAT_DEPTH32_FLOAT_STENCIL8 :: WGPU_Texture_Format(0x0000002B)

WGPU_TEXTURE_DIMENSION_UNDEFINED :: WGPU_Texture_Dimension(0x00000000)
WGPU_TEXTURE_DIMENSION_1D :: WGPU_Texture_Dimension(0x00000001)
WGPU_TEXTURE_DIMENSION_2D :: WGPU_Texture_Dimension(0x00000002)
WGPU_TEXTURE_DIMENSION_3D :: WGPU_Texture_Dimension(0x00000003)

WGPU_TEXTURE_VIEW_DIMENSION_UNDEFINED :: WGPU_Texture_View_Dimension(0x00000000)
WGPU_TEXTURE_VIEW_DIMENSION_1D :: WGPU_Texture_View_Dimension(0x00000001)
WGPU_TEXTURE_VIEW_DIMENSION_2D :: WGPU_Texture_View_Dimension(0x00000002)
WGPU_TEXTURE_VIEW_DIMENSION_2D_ARRAY :: WGPU_Texture_View_Dimension(0x00000003)
WGPU_TEXTURE_VIEW_DIMENSION_CUBE :: WGPU_Texture_View_Dimension(0x00000004)
WGPU_TEXTURE_VIEW_DIMENSION_CUBE_ARRAY :: WGPU_Texture_View_Dimension(0x00000005)
WGPU_TEXTURE_VIEW_DIMENSION_3D :: WGPU_Texture_View_Dimension(0x00000006)

WGPU_TEXTURE_ASPECT_UNDEFINED :: WGPU_Texture_Aspect(0x00000000)
WGPU_TEXTURE_ASPECT_ALL :: WGPU_Texture_Aspect(0x00000001)
WGPU_TEXTURE_ASPECT_STENCIL_ONLY :: WGPU_Texture_Aspect(0x00000002)
WGPU_TEXTURE_ASPECT_DEPTH_ONLY :: WGPU_Texture_Aspect(0x00000003)

WGPU_BUFFER_USAGE_NONE :: WGPU_Buffer_Usage(0x0000000000000000)
WGPU_BUFFER_USAGE_MAP_READ :: WGPU_Buffer_Usage(0x0000000000000001)
WGPU_BUFFER_USAGE_MAP_WRITE :: WGPU_Buffer_Usage(0x0000000000000002)
WGPU_BUFFER_USAGE_COPY_SRC :: WGPU_Buffer_Usage(0x0000000000000004)
WGPU_BUFFER_USAGE_COPY_DST :: WGPU_Buffer_Usage(0x0000000000000008)
WGPU_BUFFER_USAGE_INDEX :: WGPU_Buffer_Usage(0x0000000000000010)
WGPU_BUFFER_USAGE_VERTEX :: WGPU_Buffer_Usage(0x0000000000000020)
WGPU_BUFFER_USAGE_UNIFORM :: WGPU_Buffer_Usage(0x0000000000000040)
WGPU_BUFFER_USAGE_STORAGE :: WGPU_Buffer_Usage(0x0000000000000080)
WGPU_BUFFER_USAGE_INDIRECT :: WGPU_Buffer_Usage(0x0000000000000100)
WGPU_BUFFER_USAGE_QUERY_RESOLVE :: WGPU_Buffer_Usage(0x0000000000000200)

WGPU_MAP_MODE_NONE :: WGPU_Map_Mode(0x0000000000000000)
WGPU_MAP_MODE_READ :: WGPU_Map_Mode(0x0000000000000001)
WGPU_MAP_MODE_WRITE :: WGPU_Map_Mode(0x0000000000000002)

WGPU_TEXTURE_USAGE_NONE :: WGPU_Texture_Usage(0x0000000000000000)
WGPU_TEXTURE_USAGE_COPY_SRC :: WGPU_Texture_Usage(0x0000000000000001)
WGPU_TEXTURE_USAGE_COPY_DST :: WGPU_Texture_Usage(0x0000000000000002)
WGPU_TEXTURE_USAGE_TEXTURE_BINDING :: WGPU_Texture_Usage(0x0000000000000004)
WGPU_TEXTURE_USAGE_STORAGE_BINDING :: WGPU_Texture_Usage(0x0000000000000008)
WGPU_TEXTURE_USAGE_RENDER_ATTACHMENT :: WGPU_Texture_Usage(0x0000000000000010)

WGPU_DEFAULT_TARGET_FORMAT :: WGPU_TEXTURE_FORMAT_BGRA8_UNORM_SRGB
WGPU_DEPTH_FORMAT :: WGPU_TEXTURE_FORMAT_DEPTH24_PLUS
WGPU_SHADOW_DEPTH_FORMAT :: WGPU_TEXTURE_FORMAT_DEPTH32_FLOAT
WGPU_ARRAY_LAYER_COUNT_UNDEFINED :: WGPU_U32_MAX
WGPU_MIP_LEVEL_COUNT_UNDEFINED :: WGPU_U32_MAX
WGPU_COPY_STRIDE_UNDEFINED :: WGPU_U32_MAX

WGPU_String_View :: struct #align(align_of(rawptr)) {
	data:   rawptr,
	length: c.size_t,
}

WGPU_Chained_Struct :: struct #align(align_of(rawptr)) {
	next:   ^WGPU_Chained_Struct,
	s_type: WGPU_SType,
}

WGPU_Chained_Struct_Out :: struct #align(align_of(rawptr)) {
	next:   ^WGPU_Chained_Struct_Out,
	s_type: WGPU_SType,
}

WGPU_Future :: struct {
	id: u64,
}

WGPU_Extent_3D :: struct {
	width:                 u32,
	height:                u32,
	depth_or_array_layers: u32,
}

WGPU_Origin_3D :: struct {
	x: u32,
	y: u32,
	z: u32,
}

WGPU_Buffer_Descriptor :: struct #align(align_of(rawptr)) {
	next_in_chain:      ^WGPU_Chained_Struct,
	label:              WGPU_String_View,
	usage:              WGPU_Buffer_Usage,
	size:               u64,
	mapped_at_creation: WGPU_Bool,
}

WGPU_Texture_Descriptor :: struct #align(align_of(rawptr)) {
	next_in_chain:    ^WGPU_Chained_Struct,
	label:            WGPU_String_View,
	usage:            WGPU_Texture_Usage,
	dimension:        WGPU_Texture_Dimension,
	size:             WGPU_Extent_3D,
	format:           WGPU_Texture_Format,
	mip_level_count:  u32,
	sample_count:     u32,
	view_format_count: c.size_t,
	view_formats:     rawptr,
}

WGPU_Texture_View_Descriptor :: struct #align(align_of(rawptr)) {
	next_in_chain:    ^WGPU_Chained_Struct,
	label:            WGPU_String_View,
	format:           WGPU_Texture_Format,
	dimension:        WGPU_Texture_View_Dimension,
	base_mip_level:   u32,
	mip_level_count:  u32,
	base_array_layer: u32,
	array_layer_count: u32,
	aspect:           WGPU_Texture_Aspect,
	usage:            WGPU_Texture_Usage,
}

WGPU_Texel_Copy_Texture_Info :: struct #align(align_of(rawptr)) {
	texture:   WGPU_Texture,
	mip_level: u32,
	origin:    WGPU_Origin_3D,
	aspect:    WGPU_Texture_Aspect,
}

WGPU_Texel_Copy_Buffer_Layout :: struct {
	offset:         u64,
	bytes_per_row:  u32,
	rows_per_image: u32,
}

WGPU_Texel_Copy_Buffer_Info :: struct #align(align_of(rawptr)) {
	layout: WGPU_Texel_Copy_Buffer_Layout,
	buffer: WGPU_Buffer,
}

WGPU_Command_Encoder_Descriptor :: struct #align(align_of(rawptr)) {
	next_in_chain: ^WGPU_Chained_Struct,
	label:         WGPU_String_View,
}

WGPU_Command_Buffer_Descriptor :: struct #align(align_of(rawptr)) {
	next_in_chain: ^WGPU_Chained_Struct,
	label:         WGPU_String_View,
}

WGPU_Instance_Capabilities :: struct #align(align_of(rawptr)) {
	next_in_chain:            ^WGPU_Chained_Struct_Out,
	timed_wait_any_enable:    WGPU_Bool,
	timed_wait_any_max_count: c.size_t,
}

WGPU_Instance_Descriptor :: struct #align(align_of(rawptr)) {
	next_in_chain: ^WGPU_Chained_Struct,
	features:      WGPU_Instance_Capabilities,
}

WGPU_Request_Adapter_Options :: struct #align(align_of(rawptr)) {
	next_in_chain:          ^WGPU_Chained_Struct,
	feature_level:          WGPU_Feature_Level,
	power_preference:       WGPU_Power_Preference,
	force_fallback_adapter: WGPU_Bool,
	backend_type:           WGPU_Backend_Type,
	compatible_surface:     WGPU_Surface,
}

WGPU_Queue_Descriptor :: struct #align(align_of(rawptr)) {
	next_in_chain: ^WGPU_Chained_Struct,
	label:         WGPU_String_View,
}

WGPU_Device_Lost_Callback :: proc "c" (device: rawptr, reason: WGPU_Device_Lost_Reason, message: WGPU_String_View, userdata1, userdata2: rawptr)

WGPU_Device_Lost_Callback_Info :: struct #align(align_of(rawptr)) {
	next_in_chain: ^WGPU_Chained_Struct,
	mode:          WGPU_Callback_Mode,
	callback:      WGPU_Device_Lost_Callback,
	userdata1:     rawptr,
	userdata2:     rawptr,
}

WGPU_Uncaptured_Error_Callback :: proc "c" (device: WGPU_Device, error_type: WGPU_Error_Type, message: WGPU_String_View, userdata1, userdata2: rawptr)

WGPU_Uncaptured_Error_Callback_Info :: struct #align(align_of(rawptr)) {
	next_in_chain: ^WGPU_Chained_Struct,
	callback:      WGPU_Uncaptured_Error_Callback,
	userdata1:     rawptr,
	userdata2:     rawptr,
}

WGPU_Device_Descriptor :: struct #align(align_of(rawptr)) {
	next_in_chain:                  ^WGPU_Chained_Struct,
	label:                          WGPU_String_View,
	required_feature_count:         c.size_t,
	required_features:              rawptr,
	required_limits:                WGPU_Limits,
	default_queue:                  WGPU_Queue_Descriptor,
	device_lost_callback_info:      WGPU_Device_Lost_Callback_Info,
	uncaptured_error_callback_info: WGPU_Uncaptured_Error_Callback_Info,
}

WGPU_Request_Adapter_Callback :: proc "c" (status: WGPU_Request_Adapter_Status, adapter: WGPU_Adapter, message: WGPU_String_View, userdata1, userdata2: rawptr)

WGPU_Request_Adapter_Callback_Info :: struct #align(align_of(rawptr)) {
	next_in_chain: ^WGPU_Chained_Struct,
	mode:          WGPU_Callback_Mode,
	callback:      WGPU_Request_Adapter_Callback,
	userdata1:     rawptr,
	userdata2:     rawptr,
}

WGPU_Request_Device_Callback :: proc "c" (status: WGPU_Request_Device_Status, device: WGPU_Device, message: WGPU_String_View, userdata1, userdata2: rawptr)

WGPU_Request_Device_Callback_Info :: struct #align(align_of(rawptr)) {
	next_in_chain: ^WGPU_Chained_Struct,
	mode:          WGPU_Callback_Mode,
	callback:      WGPU_Request_Device_Callback,
	userdata1:     rawptr,
	userdata2:     rawptr,
}

WGPU_Buffer_Map_Callback :: proc "c" (status: WGPU_Map_Async_Status, message: WGPU_String_View, userdata1, userdata2: rawptr)

WGPU_Buffer_Map_Callback_Info :: struct #align(align_of(rawptr)) {
	next_in_chain: ^WGPU_Chained_Struct,
	mode:          WGPU_Callback_Mode,
	callback:      WGPU_Buffer_Map_Callback,
	userdata1:     rawptr,
	userdata2:     rawptr,
}

WGPU_Device_Create_Texture_Proc :: proc "c" (device: WGPU_Device, descriptor: ^WGPU_Texture_Descriptor) -> WGPU_Texture
WGPU_Device_Create_Buffer_Proc :: proc "c" (device: WGPU_Device, descriptor: ^WGPU_Buffer_Descriptor) -> WGPU_Buffer
WGPU_Device_Create_Command_Encoder_Proc :: proc "c" (device: WGPU_Device, descriptor: ^WGPU_Command_Encoder_Descriptor) -> WGPU_Command_Encoder
WGPU_Texture_Create_View_Proc :: proc "c" (texture: WGPU_Texture, descriptor: ^WGPU_Texture_View_Descriptor) -> WGPU_Texture_View
WGPU_Command_Encoder_Copy_Texture_To_Buffer_Proc :: proc "c" (encoder: WGPU_Command_Encoder, source: ^WGPU_Texel_Copy_Texture_Info, destination: ^WGPU_Texel_Copy_Buffer_Info, copy_size: ^WGPU_Extent_3D)
WGPU_Command_Encoder_Finish_Proc :: proc "c" (encoder: WGPU_Command_Encoder, descriptor: ^WGPU_Command_Buffer_Descriptor) -> WGPU_Command_Buffer
WGPU_Queue_Submit_Proc :: proc "c" (queue: WGPU_Queue, command_count: c.size_t, commands: [^]WGPU_Command_Buffer)
WGPU_Buffer_Map_Async_Proc :: proc "c" (buffer: WGPU_Buffer, mode: WGPU_Map_Mode, offset, size: c.size_t, callback_info: WGPU_Buffer_Map_Callback_Info) -> WGPU_Future
WGPU_Buffer_Get_Mapped_Range_Proc :: proc "c" (buffer: WGPU_Buffer, offset, size: c.size_t) -> rawptr
WGPU_Buffer_Unmap_Proc :: proc "c" (buffer: WGPU_Buffer)
WGPU_Instance_Process_Events_Proc :: proc "c" (instance: WGPU_Instance)
WGPU_Texture_Release_Proc :: proc "c" (texture: WGPU_Texture)
WGPU_Texture_View_Release_Proc :: proc "c" (texture_view: WGPU_Texture_View)
WGPU_Buffer_Release_Proc :: proc "c" (buffer: WGPU_Buffer)
WGPU_Command_Encoder_Release_Proc :: proc "c" (encoder: WGPU_Command_Encoder)
WGPU_Command_Buffer_Release_Proc :: proc "c" (command_buffer: WGPU_Command_Buffer)
WGPU_Create_Instance_Proc :: proc "c" (descriptor: ^WGPU_Instance_Descriptor) -> WGPU_Instance
WGPU_Instance_Request_Adapter_Proc :: proc "c" (instance: WGPU_Instance, options: ^WGPU_Request_Adapter_Options, callback_info: WGPU_Request_Adapter_Callback_Info) -> WGPU_Future
WGPU_Adapter_Request_Device_Proc :: proc "c" (adapter: WGPU_Adapter, descriptor: ^WGPU_Device_Descriptor, callback_info: WGPU_Request_Device_Callback_Info) -> WGPU_Future
WGPU_Device_Get_Queue_Proc :: proc "c" (device: WGPU_Device) -> WGPU_Queue
WGPU_Instance_Release_Proc :: proc "c" (instance: WGPU_Instance)
WGPU_Adapter_Release_Proc :: proc "c" (adapter: WGPU_Adapter)
WGPU_Device_Release_Proc :: proc "c" (device: WGPU_Device)
WGPU_Queue_Release_Proc :: proc "c" (queue: WGPU_Queue)

WGPU_Symbol_Resolver :: proc(name: string, user_data: rawptr) -> rawptr

WGPU_OFFSCREEN_LIBRARY_LOAD_ERROR :: "load_library"

WGPU_SYMBOL_DEVICE_CREATE_TEXTURE :: "wgpuDeviceCreateTexture"
WGPU_SYMBOL_DEVICE_CREATE_BUFFER :: "wgpuDeviceCreateBuffer"
WGPU_SYMBOL_DEVICE_CREATE_COMMAND_ENCODER :: "wgpuDeviceCreateCommandEncoder"
WGPU_SYMBOL_TEXTURE_CREATE_VIEW :: "wgpuTextureCreateView"
WGPU_SYMBOL_COMMAND_ENCODER_COPY_TEXTURE_TO_BUFFER :: "wgpuCommandEncoderCopyTextureToBuffer"
WGPU_SYMBOL_COMMAND_ENCODER_FINISH :: "wgpuCommandEncoderFinish"
WGPU_SYMBOL_QUEUE_SUBMIT :: "wgpuQueueSubmit"
WGPU_SYMBOL_BUFFER_MAP_ASYNC :: "wgpuBufferMapAsync"
WGPU_SYMBOL_BUFFER_GET_MAPPED_RANGE :: "wgpuBufferGetMappedRange"
WGPU_SYMBOL_BUFFER_UNMAP :: "wgpuBufferUnmap"
WGPU_SYMBOL_INSTANCE_PROCESS_EVENTS :: "wgpuInstanceProcessEvents"
WGPU_SYMBOL_TEXTURE_RELEASE :: "wgpuTextureRelease"
WGPU_SYMBOL_TEXTURE_VIEW_RELEASE :: "wgpuTextureViewRelease"
WGPU_SYMBOL_BUFFER_RELEASE :: "wgpuBufferRelease"
WGPU_SYMBOL_COMMAND_ENCODER_RELEASE :: "wgpuCommandEncoderRelease"
WGPU_SYMBOL_COMMAND_BUFFER_RELEASE :: "wgpuCommandBufferRelease"
WGPU_SYMBOL_CREATE_INSTANCE :: "wgpuCreateInstance"
WGPU_SYMBOL_INSTANCE_REQUEST_ADAPTER :: "wgpuInstanceRequestAdapter"
WGPU_SYMBOL_ADAPTER_REQUEST_DEVICE :: "wgpuAdapterRequestDevice"
WGPU_SYMBOL_DEVICE_GET_QUEUE :: "wgpuDeviceGetQueue"
WGPU_SYMBOL_INSTANCE_RELEASE :: "wgpuInstanceRelease"
WGPU_SYMBOL_ADAPTER_RELEASE :: "wgpuAdapterRelease"
WGPU_SYMBOL_DEVICE_RELEASE :: "wgpuDeviceRelease"
WGPU_SYMBOL_QUEUE_RELEASE :: "wgpuQueueRelease"

WGPU_Offscreen_Procs :: struct {
	create_instance:                        WGPU_Create_Instance_Proc,
	instance_request_adapter:               WGPU_Instance_Request_Adapter_Proc,
	adapter_request_device:                 WGPU_Adapter_Request_Device_Proc,
	device_get_queue:                       WGPU_Device_Get_Queue_Proc,
	device_create_texture:                  WGPU_Device_Create_Texture_Proc,
	device_create_buffer:                   WGPU_Device_Create_Buffer_Proc,
	device_create_command_encoder:          WGPU_Device_Create_Command_Encoder_Proc,
	texture_create_view:                    WGPU_Texture_Create_View_Proc,
	command_encoder_copy_texture_to_buffer: WGPU_Command_Encoder_Copy_Texture_To_Buffer_Proc,
	command_encoder_finish:                 WGPU_Command_Encoder_Finish_Proc,
	queue_submit:                           WGPU_Queue_Submit_Proc,
	buffer_map_async:                       WGPU_Buffer_Map_Async_Proc,
	buffer_get_mapped_range:                WGPU_Buffer_Get_Mapped_Range_Proc,
	buffer_unmap:                           WGPU_Buffer_Unmap_Proc,
	instance_process_events:                WGPU_Instance_Process_Events_Proc,
	texture_release:                        WGPU_Texture_Release_Proc,
	texture_view_release:                   WGPU_Texture_View_Release_Proc,
	buffer_release:                         WGPU_Buffer_Release_Proc,
	command_encoder_release:                WGPU_Command_Encoder_Release_Proc,
	command_buffer_release:                 WGPU_Command_Buffer_Release_Proc,
	instance_release:                       WGPU_Instance_Release_Proc,
	adapter_release:                        WGPU_Adapter_Release_Proc,
	device_release:                         WGPU_Device_Release_Proc,
	queue_release:                          WGPU_Queue_Release_Proc,
}

WGPU_Offscreen_Dynamic_Library :: struct {
	handle: dynlib.Library,
	procs:  WGPU_Offscreen_Procs,
}

WGPU_Dynlib_Resolver_Context :: struct {
	library: dynlib.Library,
}

wgpu_string_view_null :: proc() -> WGPU_String_View {
	return WGPU_String_View{data = nil, length = WGPU_STRLEN}
}

wgpu_string_view_empty :: proc() -> WGPU_String_View {
	return WGPU_String_View{data = nil, length = 0}
}

wgpu_string_view_from_raw :: proc(data: rawptr, length: c.size_t) -> WGPU_String_View {
	return WGPU_String_View{data = data, length = length}
}

wgpu_extent_3d :: proc(width, height: u32, depth_or_array_layers: u32 = 1) -> WGPU_Extent_3D {
	return WGPU_Extent_3D{
		width = width,
		height = height,
		depth_or_array_layers = depth_or_array_layers,
	}
}

wgpu_origin_3d_zero :: proc() -> WGPU_Origin_3D {
	return WGPU_Origin_3D{}
}

wgpu_texture_descriptor_2d :: proc(label: WGPU_String_View, width, height: u32, format: WGPU_Texture_Format, usage: WGPU_Texture_Usage) -> WGPU_Texture_Descriptor {
	return WGPU_Texture_Descriptor{
		next_in_chain = nil,
		label = label,
		usage = usage,
		dimension = WGPU_TEXTURE_DIMENSION_2D,
		size = wgpu_extent_3d(width, height),
		format = format,
		mip_level_count = 1,
		sample_count = 1,
		view_format_count = 0,
		view_formats = nil,
	}
}

wgpu_texture_view_descriptor_default :: proc(label: WGPU_String_View) -> WGPU_Texture_View_Descriptor {
	return WGPU_Texture_View_Descriptor{
		next_in_chain = nil,
		label = label,
		format = WGPU_TEXTURE_FORMAT_UNDEFINED,
		dimension = WGPU_TEXTURE_VIEW_DIMENSION_UNDEFINED,
		base_mip_level = 0,
		mip_level_count = WGPU_MIP_LEVEL_COUNT_UNDEFINED,
		base_array_layer = 0,
		array_layer_count = WGPU_ARRAY_LAYER_COUNT_UNDEFINED,
		aspect = WGPU_TEXTURE_ASPECT_ALL,
		usage = WGPU_TEXTURE_USAGE_NONE,
	}
}

wgpu_single_mip_texture_view_descriptor :: proc(label: WGPU_String_View) -> WGPU_Texture_View_Descriptor {
	descriptor := wgpu_texture_view_descriptor_default(label)
	descriptor.mip_level_count = 1
	descriptor.array_layer_count = 1
	return descriptor
}

wgpu_buffer_descriptor :: proc(label: WGPU_String_View, usage: WGPU_Buffer_Usage, size: u64, mapped_at_creation: bool = false) -> WGPU_Buffer_Descriptor {
	mapped := WGPU_FALSE
	if mapped_at_creation {
		mapped = WGPU_TRUE
	}
	return WGPU_Buffer_Descriptor{
		next_in_chain = nil,
		label = label,
		usage = usage,
		size = size,
		mapped_at_creation = mapped,
	}
}

wgpu_texel_copy_texture_info :: proc(texture: WGPU_Texture) -> WGPU_Texel_Copy_Texture_Info {
	return WGPU_Texel_Copy_Texture_Info{
		texture = texture,
		mip_level = 0,
		origin = wgpu_origin_3d_zero(),
		aspect = WGPU_TEXTURE_ASPECT_ALL,
	}
}

wgpu_texel_copy_buffer_info :: proc(buffer: WGPU_Buffer, bytes_per_row, rows_per_image: u32) -> WGPU_Texel_Copy_Buffer_Info {
	return WGPU_Texel_Copy_Buffer_Info{
		layout = WGPU_Texel_Copy_Buffer_Layout{
			offset = 0,
			bytes_per_row = bytes_per_row,
			rows_per_image = rows_per_image,
		},
		buffer = buffer,
	}
}

wgpu_command_encoder_descriptor :: proc(label: WGPU_String_View) -> WGPU_Command_Encoder_Descriptor {
	return WGPU_Command_Encoder_Descriptor{next_in_chain = nil, label = label}
}

wgpu_command_buffer_descriptor :: proc(label: WGPU_String_View) -> WGPU_Command_Buffer_Descriptor {
	return WGPU_Command_Buffer_Descriptor{next_in_chain = nil, label = label}
}

wgpu_instance_descriptor_default :: proc() -> WGPU_Instance_Descriptor {
	return WGPU_Instance_Descriptor{
		next_in_chain = nil,
		features = WGPU_Instance_Capabilities{
			next_in_chain = nil,
			timed_wait_any_enable = WGPU_FALSE,
			timed_wait_any_max_count = 0,
		},
	}
}

wgpu_request_adapter_options :: proc(compatible_surface: WGPU_Surface = nil) -> WGPU_Request_Adapter_Options {
	return WGPU_Request_Adapter_Options{
		next_in_chain = nil,
		feature_level = WGPU_FEATURE_LEVEL_CORE,
		power_preference = WGPU_POWER_PREFERENCE_UNDEFINED,
		force_fallback_adapter = WGPU_FALSE,
		backend_type = WGPU_BACKEND_TYPE_UNDEFINED,
		compatible_surface = compatible_surface,
	}
}

wgpu_queue_descriptor :: proc(label: WGPU_String_View) -> WGPU_Queue_Descriptor {
	return WGPU_Queue_Descriptor{
		next_in_chain = nil,
		label = label,
	}
}

wgpu_device_lost_callback_info :: proc(callback: WGPU_Device_Lost_Callback, userdata1: rawptr = nil, userdata2: rawptr = nil) -> WGPU_Device_Lost_Callback_Info {
	return WGPU_Device_Lost_Callback_Info{
		next_in_chain = nil,
		mode = WGPU_CALLBACK_MODE_ALLOW_PROCESS_EVENTS,
		callback = callback,
		userdata1 = userdata1,
		userdata2 = userdata2,
	}
}

wgpu_uncaptured_error_callback_info :: proc(callback: WGPU_Uncaptured_Error_Callback = nil, userdata1: rawptr = nil, userdata2: rawptr = nil) -> WGPU_Uncaptured_Error_Callback_Info {
	return WGPU_Uncaptured_Error_Callback_Info{
		next_in_chain = nil,
		callback = callback,
		userdata1 = userdata1,
		userdata2 = userdata2,
	}
}

wgpu_device_descriptor_default :: proc() -> WGPU_Device_Descriptor {
	return WGPU_Device_Descriptor{
		next_in_chain = nil,
		label = wgpu_string_view_empty(),
		required_feature_count = 0,
		required_features = nil,
		required_limits = nil,
		default_queue = wgpu_queue_descriptor(wgpu_string_view_empty()),
		device_lost_callback_info = wgpu_device_lost_callback_info(wgpu_default_device_lost_callback),
		uncaptured_error_callback_info = wgpu_uncaptured_error_callback_info(),
	}
}

wgpu_request_adapter_callback_info :: proc(callback: WGPU_Request_Adapter_Callback, userdata1: rawptr = nil, userdata2: rawptr = nil) -> WGPU_Request_Adapter_Callback_Info {
	return WGPU_Request_Adapter_Callback_Info{
		next_in_chain = nil,
		mode = WGPU_CALLBACK_MODE_ALLOW_PROCESS_EVENTS,
		callback = callback,
		userdata1 = userdata1,
		userdata2 = userdata2,
	}
}

wgpu_request_device_callback_info :: proc(callback: WGPU_Request_Device_Callback, userdata1: rawptr = nil, userdata2: rawptr = nil) -> WGPU_Request_Device_Callback_Info {
	return WGPU_Request_Device_Callback_Info{
		next_in_chain = nil,
		mode = WGPU_CALLBACK_MODE_ALLOW_PROCESS_EVENTS,
		callback = callback,
		userdata1 = userdata1,
		userdata2 = userdata2,
	}
}

wgpu_default_device_lost_callback :: proc "c" (device: rawptr, reason: WGPU_Device_Lost_Reason, message: WGPU_String_View, userdata1, userdata2: rawptr) {
	_ = device
	_ = reason
	_ = message
	_ = userdata1
	_ = userdata2
}

wgpu_buffer_map_callback_info :: proc(callback: WGPU_Buffer_Map_Callback, userdata1: rawptr = nil, userdata2: rawptr = nil) -> WGPU_Buffer_Map_Callback_Info {
	return WGPU_Buffer_Map_Callback_Info{
		next_in_chain = nil,
		mode = WGPU_CALLBACK_MODE_ALLOW_PROCESS_EVENTS,
		callback = callback,
		userdata1 = userdata1,
		userdata2 = userdata2,
	}
}

wgpu_resolve_offscreen_procs :: proc(resolver: WGPU_Symbol_Resolver, user_data: rawptr = nil) -> (WGPU_Offscreen_Procs, string, bool) {
	procs: WGPU_Offscreen_Procs
	symbol: rawptr

	symbol = resolver(WGPU_SYMBOL_CREATE_INSTANCE, user_data)
	if symbol == nil do return procs, WGPU_SYMBOL_CREATE_INSTANCE, false
	procs.create_instance = cast(WGPU_Create_Instance_Proc)symbol

	symbol = resolver(WGPU_SYMBOL_INSTANCE_REQUEST_ADAPTER, user_data)
	if symbol == nil do return procs, WGPU_SYMBOL_INSTANCE_REQUEST_ADAPTER, false
	procs.instance_request_adapter = cast(WGPU_Instance_Request_Adapter_Proc)symbol

	symbol = resolver(WGPU_SYMBOL_ADAPTER_REQUEST_DEVICE, user_data)
	if symbol == nil do return procs, WGPU_SYMBOL_ADAPTER_REQUEST_DEVICE, false
	procs.adapter_request_device = cast(WGPU_Adapter_Request_Device_Proc)symbol

	symbol = resolver(WGPU_SYMBOL_DEVICE_GET_QUEUE, user_data)
	if symbol == nil do return procs, WGPU_SYMBOL_DEVICE_GET_QUEUE, false
	procs.device_get_queue = cast(WGPU_Device_Get_Queue_Proc)symbol

	symbol = resolver(WGPU_SYMBOL_DEVICE_CREATE_TEXTURE, user_data)
	if symbol == nil do return procs, WGPU_SYMBOL_DEVICE_CREATE_TEXTURE, false
	procs.device_create_texture = cast(WGPU_Device_Create_Texture_Proc)symbol

	symbol = resolver(WGPU_SYMBOL_DEVICE_CREATE_BUFFER, user_data)
	if symbol == nil do return procs, WGPU_SYMBOL_DEVICE_CREATE_BUFFER, false
	procs.device_create_buffer = cast(WGPU_Device_Create_Buffer_Proc)symbol

	symbol = resolver(WGPU_SYMBOL_DEVICE_CREATE_COMMAND_ENCODER, user_data)
	if symbol == nil do return procs, WGPU_SYMBOL_DEVICE_CREATE_COMMAND_ENCODER, false
	procs.device_create_command_encoder = cast(WGPU_Device_Create_Command_Encoder_Proc)symbol

	symbol = resolver(WGPU_SYMBOL_TEXTURE_CREATE_VIEW, user_data)
	if symbol == nil do return procs, WGPU_SYMBOL_TEXTURE_CREATE_VIEW, false
	procs.texture_create_view = cast(WGPU_Texture_Create_View_Proc)symbol

	symbol = resolver(WGPU_SYMBOL_COMMAND_ENCODER_COPY_TEXTURE_TO_BUFFER, user_data)
	if symbol == nil do return procs, WGPU_SYMBOL_COMMAND_ENCODER_COPY_TEXTURE_TO_BUFFER, false
	procs.command_encoder_copy_texture_to_buffer = cast(WGPU_Command_Encoder_Copy_Texture_To_Buffer_Proc)symbol

	symbol = resolver(WGPU_SYMBOL_COMMAND_ENCODER_FINISH, user_data)
	if symbol == nil do return procs, WGPU_SYMBOL_COMMAND_ENCODER_FINISH, false
	procs.command_encoder_finish = cast(WGPU_Command_Encoder_Finish_Proc)symbol

	symbol = resolver(WGPU_SYMBOL_QUEUE_SUBMIT, user_data)
	if symbol == nil do return procs, WGPU_SYMBOL_QUEUE_SUBMIT, false
	procs.queue_submit = cast(WGPU_Queue_Submit_Proc)symbol

	symbol = resolver(WGPU_SYMBOL_BUFFER_MAP_ASYNC, user_data)
	if symbol == nil do return procs, WGPU_SYMBOL_BUFFER_MAP_ASYNC, false
	procs.buffer_map_async = cast(WGPU_Buffer_Map_Async_Proc)symbol

	symbol = resolver(WGPU_SYMBOL_BUFFER_GET_MAPPED_RANGE, user_data)
	if symbol == nil do return procs, WGPU_SYMBOL_BUFFER_GET_MAPPED_RANGE, false
	procs.buffer_get_mapped_range = cast(WGPU_Buffer_Get_Mapped_Range_Proc)symbol

	symbol = resolver(WGPU_SYMBOL_BUFFER_UNMAP, user_data)
	if symbol == nil do return procs, WGPU_SYMBOL_BUFFER_UNMAP, false
	procs.buffer_unmap = cast(WGPU_Buffer_Unmap_Proc)symbol

	symbol = resolver(WGPU_SYMBOL_INSTANCE_PROCESS_EVENTS, user_data)
	if symbol == nil do return procs, WGPU_SYMBOL_INSTANCE_PROCESS_EVENTS, false
	procs.instance_process_events = cast(WGPU_Instance_Process_Events_Proc)symbol

	symbol = resolver(WGPU_SYMBOL_TEXTURE_RELEASE, user_data)
	if symbol == nil do return procs, WGPU_SYMBOL_TEXTURE_RELEASE, false
	procs.texture_release = cast(WGPU_Texture_Release_Proc)symbol

	symbol = resolver(WGPU_SYMBOL_TEXTURE_VIEW_RELEASE, user_data)
	if symbol == nil do return procs, WGPU_SYMBOL_TEXTURE_VIEW_RELEASE, false
	procs.texture_view_release = cast(WGPU_Texture_View_Release_Proc)symbol

	symbol = resolver(WGPU_SYMBOL_BUFFER_RELEASE, user_data)
	if symbol == nil do return procs, WGPU_SYMBOL_BUFFER_RELEASE, false
	procs.buffer_release = cast(WGPU_Buffer_Release_Proc)symbol

	symbol = resolver(WGPU_SYMBOL_COMMAND_ENCODER_RELEASE, user_data)
	if symbol == nil do return procs, WGPU_SYMBOL_COMMAND_ENCODER_RELEASE, false
	procs.command_encoder_release = cast(WGPU_Command_Encoder_Release_Proc)symbol

	symbol = resolver(WGPU_SYMBOL_COMMAND_BUFFER_RELEASE, user_data)
	if symbol == nil do return procs, WGPU_SYMBOL_COMMAND_BUFFER_RELEASE, false
	procs.command_buffer_release = cast(WGPU_Command_Buffer_Release_Proc)symbol

	symbol = resolver(WGPU_SYMBOL_INSTANCE_RELEASE, user_data)
	if symbol == nil do return procs, WGPU_SYMBOL_INSTANCE_RELEASE, false
	procs.instance_release = cast(WGPU_Instance_Release_Proc)symbol

	symbol = resolver(WGPU_SYMBOL_ADAPTER_RELEASE, user_data)
	if symbol == nil do return procs, WGPU_SYMBOL_ADAPTER_RELEASE, false
	procs.adapter_release = cast(WGPU_Adapter_Release_Proc)symbol

	symbol = resolver(WGPU_SYMBOL_DEVICE_RELEASE, user_data)
	if symbol == nil do return procs, WGPU_SYMBOL_DEVICE_RELEASE, false
	procs.device_release = cast(WGPU_Device_Release_Proc)symbol

	symbol = resolver(WGPU_SYMBOL_QUEUE_RELEASE, user_data)
	if symbol == nil do return procs, WGPU_SYMBOL_QUEUE_RELEASE, false
	procs.queue_release = cast(WGPU_Queue_Release_Proc)symbol

	return procs, "", true
}

wgpu_load_offscreen_library :: proc(path: string) -> (WGPU_Offscreen_Dynamic_Library, string, bool) {
	loaded: WGPU_Offscreen_Dynamic_Library

	library, library_ok := dynlib.load_library(path)
	if !library_ok {
		return loaded, WGPU_OFFSCREEN_LIBRARY_LOAD_ERROR, false
	}

	resolver_context := WGPU_Dynlib_Resolver_Context{library = library}
	procs, missing, procs_ok := wgpu_resolve_offscreen_procs(wgpu_dynlib_symbol_resolver, rawptr(&resolver_context))
	if !procs_ok {
		dynlib.unload_library(library)
		return loaded, missing, false
	}

	loaded.handle = library
	loaded.procs = procs
	return loaded, "", true
}

wgpu_unload_offscreen_library :: proc(loaded: ^WGPU_Offscreen_Dynamic_Library) -> bool {
	if loaded == nil || loaded.handle == dynlib.Library(nil) {
		return true
	}
	unload_ok := dynlib.unload_library(loaded.handle)
	loaded^ = WGPU_Offscreen_Dynamic_Library{}
	return unload_ok
}

wgpu_dynlib_symbol_resolver :: proc(name: string, user_data: rawptr) -> rawptr {
	if user_data == nil {
		return nil
	}
	resolver_context := (^WGPU_Dynlib_Resolver_Context)(user_data)
	symbol, symbol_ok := dynlib.symbol_address(resolver_context.library, name)
	if !symbol_ok {
		return nil
	}
	return symbol
}

wgpu_offscreen_texture_usage :: proc() -> WGPU_Texture_Usage {
	return WGPU_TEXTURE_USAGE_RENDER_ATTACHMENT | WGPU_TEXTURE_USAGE_COPY_SRC
}

wgpu_staging_buffer_usage :: proc() -> WGPU_Buffer_Usage {
	return WGPU_BUFFER_USAGE_MAP_READ | WGPU_BUFFER_USAGE_COPY_DST
}
