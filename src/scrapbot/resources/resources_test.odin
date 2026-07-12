package resources

import "core:testing"

@(test)
test_cube_is_full_indexed_geometry :: proc(t: ^testing.T) {
	desc, err := cube(2)
	defer delete(desc.vertices); defer delete(desc.indices)
	testing.expect(t, err == "")
	testing.expect(t, len(desc.vertices) == 24)
	testing.expect(t, len(desc.indices) == 36)
	testing.expect(t, calculate_bounds(desc.vertices).min.x == -1)
	testing.expect(t, validate_geometry(desc) == "")
}

@(test)
test_named_geometry_updates_share_a_stable_handle :: proc(t: ^testing.T) {
	registry: Registry; defer destroy_registry(&registry)
	first, _ := cube(1); defer delete(first.vertices); defer delete(first.indices)
	handle, err := register_geometry(&registry, "cube", first)
	testing.expect(t, err == "")
	second, _ := cube(2); defer delete(second.vertices); defer delete(second.indices)
	updated, update_err := register_geometry(&registry, "cube", second)
	testing.expect(t, update_err == "")
	testing.expect(t, updated == handle)
	geometry, ok := get_geometry(&registry, handle)
	testing.expect(t, ok)
	testing.expect(t, geometry.version == 2)
	testing.expect(t, geometry.bounds.max.x == 1)
}

@(test)
test_geometry_validation_rejects_invalid_indices :: proc(t: ^testing.T) {
	desc, _ := plane()
	defer delete(desc.vertices); defer delete(desc.indices)
	desc.indices[0] = 99
	testing.expect(t, validate_geometry(desc) == "geometry index is outside the vertex array")
}
