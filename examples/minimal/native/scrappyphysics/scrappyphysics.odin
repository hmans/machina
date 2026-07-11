package scrappyphysics

import c "core:c"
import api "scrapbot:extension_api"

@(export)
scrapbot_extension_register :: proc "c" (scrapbot: ^api.API) -> cstring {
	if scrapbot == nil {
		return "Scrapbot API is not available"
	}
	if scrapbot.abi_version != api.ABI_VERSION {
		return "unsupported Scrapbot extension ABI"
	}

	fields := [?]api.Field_Definition {
		{name = "velocity", field_type = .Vec3},
	}
	definition := api.Component_Definition {
		name = "scrappyphysics.rigidbody",
		fields = raw_data(fields[:]),
		field_count = c.int(len(fields)),
	}
	return scrapbot.register_library_component(scrapbot, &definition)
}
