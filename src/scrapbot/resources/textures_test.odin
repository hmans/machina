package resources

import asset_import "../asset_import"
import shared "../shared"
import "core:testing"

@(test)
test_project_texture_products_register_and_update_by_stable_uuid :: proc(t: ^testing.T) {
	texture_id, _ := shared.resource_uuid_parse("a1000000-0000-4000-8000-000000000099")
	declaration := shared.Project_Resource {
		id = texture_id,
		kind = .Texture,
		name = "Checker",
		source = "checker.resource.toml",
		texture = {source = "assets/checker.png", color_space = .SRGB, generate_mipmaps = true},
	}
	imports := asset_import.ensure_project_imports(
		"examples/minimal",
		[]shared.Project_Resource{declaration},
	)
	defer asset_import.destroy_report(&imports)
	testing.expectf(t, imports.err == "", "texture import failed: %s", imports.err)
	registry: Registry
	defer destroy_registry(&registry)
	err := register_project_textures(
		&registry,
		[]shared.Project_Resource{declaration},
		imports.products[:],
	)
	testing.expectf(t, err == "", "texture registration failed: %s", err)
	handle, found := texture_handle_by_uuid(&registry, texture_id)
	testing.expect(t, found)
	texture, alive := get_texture(&registry, handle)
	testing.expect(t, alive)
	if alive {
		testing.expect_value(t, texture.desc.width, u32(8))
		testing.expect_value(t, texture.desc.height, u32(8))
		testing.expect_value(t, texture.desc.mip_count, u32(4))
		testing.expect_value(t, texture.asset_source, "assets/checker.png")
	}
	first_version := texture.version
	testing.expect(
		t,
		register_project_textures(
			&registry,
			[]shared.Project_Resource{declaration},
			imports.products[:],
		) ==
		"",
	)
	updated, still_alive := get_texture(&registry, handle)
	testing.expect(t, still_alive)
	if still_alive {
		testing.expect(t, updated.version == first_version + 1)
	}
	cloned: Registry
	testing.expect(t, clone_registry(&registry, &cloned) == "")
	defer destroy_registry(&cloned)
	cloned_texture, cloned_alive := get_texture(&cloned, handle)
	testing.expect(t, cloned_alive)
	if cloned_alive {
		testing.expect(t, string(cloned_texture.desc.pixels) == string(updated.desc.pixels))
	}
}
