package render

WGPU_GPU_DRIVEN_SHADER :: `
struct Render_Uniform {
	mvp: array<mat4x4<f32>, 64>,
	model: array<mat4x4<f32>, 64>,
	normal_model: array<mat4x4<f32>, 64>,
	shadow_mvp: array<mat4x4<f32>, 64>,
	color: array<vec4<f32>, 64>,
	emissive: array<vec4<f32>, 64>,
	shadow_flags: array<vec4<f32>, 64>,
	ambient: vec4<f32>,
	directional_direction_intensity: array<vec4<f32>, 4>,
	directional_color: array<vec4<f32>, 4>,
	point_position_range: array<vec4<f32>, 16>,
	point_color_intensity: array<vec4<f32>, 16>,
	light_counts: vec4<u32>,
};

struct GPU_Instance {
	model: mat4x4<f32>,
	normal_model: mat4x4<f32>,
	color: vec4<f32>,
	emissive: vec4<f32>,
	shadow_flags: vec4<f32>,
	bounds: vec4<f32>,
	batch_index: u32,
	enabled: u32,
	padding: vec2<u32>,
};

@group(0) @binding(0) var<uniform> render: Render_Uniform;
@group(0) @binding(1) var shadow_map: texture_depth_2d;
@group(0) @binding(2) var shadow_sampler: sampler_comparison;
@group(0) @binding(3) var<storage, read> instances: array<GPU_Instance>;
@group(0) @binding(4) var<storage, read> visible_instances: array<u32>;
@group(1) @binding(0) var base_color_texture: texture_2d<f32>;
@group(1) @binding(1) var base_color_sampler: sampler;

struct Vertex_Input {
	@location(0) position: vec3<f32>,
	@location(1) normal: vec3<f32>,
	@location(2) uv: vec2<f32>,
};

struct Vertex_Output {
	@builtin(position) position: vec4<f32>,
	@location(0) color: vec3<f32>,
	@location(1) world_position: vec3<f32>,
	@location(2) world_normal: vec3<f32>,
	@location(3) shadow_position: vec4<f32>,
	@location(4) shadow_receiver: f32,
	@location(5) uv: vec2<f32>,
	@location(6) emissive: vec3<f32>,
};

@vertex
fn vs_main(input: Vertex_Input, @builtin(instance_index) visible_index: u32) -> Vertex_Output {
	let instance = instances[visible_instances[visible_index]];
	var output: Vertex_Output;
	let local_position = vec4<f32>(input.position, 1.0);
	output.position = render.mvp[0] * instance.model * local_position;
	output.world_position = (instance.model * local_position).xyz;
	output.world_normal = normalize((instance.normal_model * vec4<f32>(input.normal, 0.0)).xyz);
	output.color = instance.color.rgb;
	output.emissive = instance.emissive.rgb;
	output.shadow_position = render.shadow_mvp[0] * instance.model * local_position;
	output.shadow_receiver = instance.shadow_flags.y;
	output.uv = input.uv;
	return output;
}

@fragment
fn fs_main(input: Vertex_Output) -> @location(0) vec4<f32> {
	let normal = normalize(input.world_normal);
	var lighting = render.ambient.rgb;
	var shadow = 1.0;
	if (input.shadow_receiver > 0.5 && render.light_counts.x > 0u && input.shadow_position.w > 0.0) {
		let projected = input.shadow_position.xyz / input.shadow_position.w;
		let uv = vec2<f32>(projected.x * 0.5 + 0.5, 0.5 - projected.y * 0.5);
		if (all(uv >= vec2<f32>(0.0)) && all(uv <= vec2<f32>(1.0)) && projected.z >= 0.0 && projected.z <= 1.0) {
			shadow = textureSampleCompare(shadow_map, shadow_sampler, uv, projected.z - 0.002);
		}
	}
	for (var i: u32 = 0u; i < render.light_counts.x; i = i + 1u) {
		let packed = render.directional_direction_intensity[i];
		let diffuse = max(dot(normal, -normalize(packed.xyz)), 0.0);
		lighting += render.directional_color[i].rgb * packed.w * diffuse * shadow;
	}
	for (var i: u32 = 0u; i < render.light_counts.y; i = i + 1u) {
		let packed = render.point_position_range[i];
		let offset = packed.xyz - input.world_position;
		let distance = length(offset);
		if (distance < packed.w && distance > 0.0001) {
			let diffuse = max(dot(normal, offset / distance), 0.0);
			let range_fade = max(1.0 - distance / packed.w, 0.0);
			let attenuation = range_fade * range_fade / (1.0 + distance * distance);
			lighting += render.point_color_intensity[i].rgb * render.point_color_intensity[i].w * diffuse * attenuation;
		}
	}
	let texture_color = textureSample(base_color_texture, base_color_sampler, input.uv).rgb;
	let base_color = texture_color * pow(max(input.color, vec3<f32>(0.0)), vec3<f32>(2.2));
	return vec4<f32>(base_color * lighting + input.emissive, 1.0);
}

@vertex
fn shadow_vs(input: Vertex_Input, @builtin(instance_index) visible_index: u32) -> @builtin(position) vec4<f32> {
	let instance = instances[visible_instances[visible_index]];
	return render.shadow_mvp[0] * instance.model * vec4<f32>(input.position, 1.0);
}
`

WGPU_GPU_CULL_SHADER :: `
struct GPU_Instance {
	model: mat4x4<f32>,
	normal_model: mat4x4<f32>,
	color: vec4<f32>,
	emissive: vec4<f32>,
	shadow_flags: vec4<f32>,
	bounds: vec4<f32>,
	batch_index: u32,
	enabled: u32,
	padding: vec2<u32>,
};

struct Batch_Info {
	visible_offset: u32,
	visible_capacity: u32,
	padding: vec2<u32>,
};

struct Draw_Indexed_Indirect {
	index_count: u32,
	instance_count: atomic<u32>,
	first_index: u32,
	base_vertex: i32,
	first_instance: u32,
};

struct Cull_Uniform {
	camera_planes: array<vec4<f32>, 6>,
	shadow_planes: array<vec4<f32>, 6>,
	slot_count: u32,
	batch_count: u32,
	padding: vec2<u32>,
};

@group(0) @binding(0) var<storage, read> instances: array<GPU_Instance>;
@group(0) @binding(1) var<storage, read> batches: array<Batch_Info>;
@group(0) @binding(2) var<storage, read_write> visible_instances: array<u32>;
@group(0) @binding(3) var<storage, read_write> shadow_visible_instances: array<u32>;
@group(0) @binding(4) var<storage, read_write> indirect: array<Draw_Indexed_Indirect>;
@group(0) @binding(5) var<storage, read_write> shadow_indirect: array<Draw_Indexed_Indirect>;
@group(0) @binding(6) var<uniform> cull: Cull_Uniform;

fn camera_sphere_visible(bounds: vec4<f32>) -> bool {
	for (var plane_index: u32 = 0u; plane_index < 6u; plane_index = plane_index + 1u) {
		let plane = cull.camera_planes[plane_index];
		if (dot(plane.xyz, bounds.xyz) + plane.w < -bounds.w) {
			return false;
		}
	}
	return true;
}

fn shadow_sphere_visible(bounds: vec4<f32>) -> bool {
	for (var plane_index: u32 = 0u; plane_index < 6u; plane_index = plane_index + 1u) {
		let plane = cull.shadow_planes[plane_index];
		if (dot(plane.xyz, bounds.xyz) + plane.w < -bounds.w) {
			return false;
		}
	}
	return true;
}

@compute @workgroup_size(64)
fn cull_instances(@builtin(global_invocation_id) invocation: vec3<u32>) {
	let slot = invocation.x;
	if (slot >= cull.slot_count) {
		return;
	}
	let instance = instances[slot];
	if (instance.enabled == 0u || instance.batch_index >= cull.batch_count) {
		return;
	}
	let batch = batches[instance.batch_index];
	if (camera_sphere_visible(instance.bounds)) {
		let local_index = atomicAdd(&indirect[instance.batch_index].instance_count, 1u);
		if (local_index < batch.visible_capacity) {
			visible_instances[batch.visible_offset + local_index] = slot;
		}
	}
	if (instance.shadow_flags.x > 0.5 && shadow_sphere_visible(instance.bounds)) {
		let local_index = atomicAdd(&shadow_indirect[instance.batch_index].instance_count, 1u);
		if (local_index < batch.visible_capacity) {
			shadow_visible_instances[batch.visible_offset + local_index] = slot;
		}
	}
}
`
