package render

WGPU_CLUSTERED_LIGHTING_SHADER :: `
struct Point_Light {
	position_range: vec4<f32>,
	color_intensity: vec4<f32>,
};

struct Cluster_Uniform {
	view: mat4x4<f32>,
	projection: mat4x4<f32>,
	viewport: vec4<f32>,
	z_parameters: vec4<f32>,
	counts: vec4<u32>,
};

@group(0) @binding(0) var<storage, read> point_lights: array<Point_Light>;
@group(0) @binding(1) var<storage, read_write> cluster_light_counts: array<u32>;
@group(0) @binding(2) var<storage, read_write> cluster_light_indices: array<u32>;
@group(0) @binding(3) var<uniform> cluster: Cluster_Uniform;

fn depth_slice(depth: f32) -> u32 {
	let clamped_depth = clamp(depth, cluster.z_parameters.x, cluster.z_parameters.y);
	return min(
		u32(floor(log2(clamped_depth / cluster.z_parameters.x) / cluster.z_parameters.z * f32(cluster.counts.z))),
		cluster.counts.z - 1u,
	);
}

fn light_overlaps_cluster(
	light: Point_Light,
	target_tile: vec2<u32>,
	target_slice: u32,
) -> bool {
	let view_position = cluster.view * vec4<f32>(light.position_range.xyz, 1.0);
	let depth = -view_position.z;
	let radius = light.position_range.w;
	let near_plane = cluster.z_parameters.x;
	let far_plane = cluster.z_parameters.y;
	if (depth + radius < near_plane || depth - radius > far_plane) {
		return false;
	}
	let projection_depth = max(depth - radius, near_plane);
	let center_ndc = vec2<f32>(
		cluster.projection[0][0] * view_position.x / max(depth, near_plane),
		cluster.projection[1][1] * view_position.y / max(depth, near_plane),
	);
	let radius_ndc = vec2<f32>(
		abs(cluster.projection[0][0]) * radius / projection_depth,
		abs(cluster.projection[1][1]) * radius / projection_depth,
	);
	let minimum_ndc = clamp(center_ndc - radius_ndc, vec2<f32>(-1.0), vec2<f32>(1.0));
	let maximum_ndc = clamp(center_ndc + radius_ndc, vec2<f32>(-1.0), vec2<f32>(1.0));
	if (minimum_ndc.x >= 1.0 || maximum_ndc.x <= -1.0 || minimum_ndc.y >= 1.0 || maximum_ndc.y <= -1.0) {
		return false;
	}
	let minimum_uv = vec2<f32>(minimum_ndc.x * 0.5 + 0.5, 0.5 - maximum_ndc.y * 0.5);
	let maximum_uv = vec2<f32>(maximum_ndc.x * 0.5 + 0.5, 0.5 - minimum_ndc.y * 0.5);
	let minimum_tile = min(
		vec2<u32>(floor(minimum_uv * vec2<f32>(cluster.counts.xy))),
		cluster.counts.xy - vec2<u32>(1u),
	);
	let maximum_tile = min(
		vec2<u32>(floor(maximum_uv * vec2<f32>(cluster.counts.xy))),
		cluster.counts.xy - vec2<u32>(1u),
	);
	let minimum_slice = depth_slice(max(depth - radius, near_plane));
	let maximum_slice = depth_slice(min(depth + radius, far_plane));
	return all(target_tile >= minimum_tile) &&
		all(target_tile <= maximum_tile) &&
		target_slice >= minimum_slice &&
		target_slice <= maximum_slice;
}

@compute @workgroup_size(64)
fn assign_lights(@builtin(global_invocation_id) invocation: vec3<u32>) {
	let cluster_index = invocation.x;
	let cluster_count = cluster.counts.x * cluster.counts.y * cluster.counts.z;
	if (cluster_index >= cluster_count) {
		return;
	}
	let clusters_per_slice = cluster.counts.x * cluster.counts.y;
	let target_slice = cluster_index / clusters_per_slice;
	let slice_index = cluster_index - target_slice * clusters_per_slice;
	let target_tile = vec2<u32>(slice_index % cluster.counts.x, slice_index / cluster.counts.x);
	let maximum_lights = u32(cluster.z_parameters.w);
	var light_count = 0u;
	for (var light_index = 0u; light_index < cluster.counts.w; light_index = light_index + 1u) {
		if (light_overlaps_cluster(point_lights[light_index], target_tile, target_slice)) {
			if (light_count < maximum_lights) {
				cluster_light_indices[cluster_index * maximum_lights + light_count] = light_index;
				light_count = light_count + 1u;
			} else {
				break;
			}
		}
	}
	cluster_light_counts[cluster_index] = light_count;
}
`
