package extension_api

import c "core:c"

ABI_VERSION :: u32(1)
MAX_COMPONENT_FIELDS :: 16

Field_Type :: enum c.int {
	Vec3 = 1,
}

Field_Definition :: struct {
	name: cstring,
	field_type: Field_Type,
}

Component_Definition :: struct {
	name: cstring,
	fields: [^]Field_Definition,
	field_count: c.int,
}

Register_Library_Component_Proc :: #type proc "c" (
	api: ^API,
	definition: ^Component_Definition,
) -> cstring

API :: struct {
	abi_version: u32,
	userdata: rawptr,
	register_library_component: Register_Library_Component_Proc,
}

Register_Proc :: #type proc "c" (api: ^API) -> cstring
