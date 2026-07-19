package render

import resources "../resources"
import shared "../shared"
import "core:math"
import "core:slice"
import "vendor:wgpu"

wgpu_align_visible_capacity :: proc(count: u32) -> u32 {
	return(
		((max(count, 1) + WGPU_VISIBLE_ALIGNMENT - 1) / WGPU_VISIBLE_ALIGNMENT) *
		WGPU_VISIBLE_ALIGNMENT \
	)
}

wgpu_create_gpu_buffer :: proc(
	renderer: ^WGPU_Renderer,
	label: string,
	usage: wgpu.BufferUsageFlags,
	size: u64,
) -> wgpu.Buffer {
	return wgpu.DeviceCreateBuffer(
		renderer.device,
		&wgpu.BufferDescriptor{label = label, usage = usage, size = size},
	)
}

wgpu_create_gpu_driven_pipelines :: proc(renderer: ^WGPU_Renderer) -> string {
	render_source := wgpu.ShaderSourceWGSL {
		chain = {sType = .ShaderSourceWGSL},
		code = WGPU_GPU_DRIVEN_SHADER,
	}
	renderer.gpu_driven_shader = wgpu.DeviceCreateShaderModule(
		renderer.device,
		&wgpu.ShaderModuleDescriptor {
			nextInChain = &render_source,
			label = "Scrapbot GPU-Driven Render Shader",
		},
	)
	if renderer.gpu_driven_shader == nil {
		return "failed to create GPU-driven render shader"
	}

	world_entries := [?]wgpu.BindGroupLayoutEntry {
		{
			binding = 0,
			visibility = {.Vertex, .Fragment},
			buffer = {type = .Uniform, minBindingSize = u64(size_of(WGPU_Render_Uniform))},
		},
		{
			binding = 1,
			visibility = {.Fragment},
			texture = {sampleType = .Depth, viewDimension = ._2D},
		},
		{binding = 2, visibility = {.Fragment}, sampler = {type = .Comparison}},
		{
			binding = 3,
			visibility = {.Vertex},
			buffer = {type = .ReadOnlyStorage, minBindingSize = u64(size_of(WGPU_GPU_Instance))},
		},
		{
			binding = 4,
			visibility = {.Vertex},
			buffer = {type = .ReadOnlyStorage, minBindingSize = 4},
		},
	}
	renderer.gpu_driven_world_bind_group_layout = wgpu.DeviceCreateBindGroupLayout(
		renderer.device,
		&wgpu.BindGroupLayoutDescriptor {
			label = "Scrapbot GPU-Driven World Bind Group Layout",
			entryCount = uint(len(world_entries)),
			entries = raw_data(world_entries[:]),
		},
	)
	if renderer.gpu_driven_world_bind_group_layout == nil {
		return "failed to create GPU-driven world bind group layout"
	}
	shadow_entries := [?]wgpu.BindGroupLayoutEntry {
		{
			binding = 0,
			visibility = {.Vertex},
			buffer = {type = .Uniform, minBindingSize = u64(size_of(WGPU_Render_Uniform))},
		},
		{
			binding = 3,
			visibility = {.Vertex},
			buffer = {type = .ReadOnlyStorage, minBindingSize = u64(size_of(WGPU_GPU_Instance))},
		},
		{
			binding = 4,
			visibility = {.Vertex},
			buffer = {type = .ReadOnlyStorage, minBindingSize = 4},
		},
	}
	renderer.gpu_driven_shadow_bind_group_layout = wgpu.DeviceCreateBindGroupLayout(
		renderer.device,
		&wgpu.BindGroupLayoutDescriptor {
			label = "Scrapbot GPU-Driven Shadow Bind Group Layout",
			entryCount = uint(len(shadow_entries)),
			entries = raw_data(shadow_entries[:]),
		},
	)
	if renderer.gpu_driven_shadow_bind_group_layout == nil {
		return "failed to create GPU-driven shadow bind group layout"
	}

	world_layouts := [?]wgpu.BindGroupLayout {
		renderer.gpu_driven_world_bind_group_layout,
		renderer.material_bind_group_layout,
	}
	renderer.gpu_driven_pipeline_layout = wgpu.DeviceCreatePipelineLayout(
		renderer.device,
		&wgpu.PipelineLayoutDescriptor {
			label = "Scrapbot GPU-Driven Pipeline Layout",
			bindGroupLayoutCount = uint(len(world_layouts)),
			bindGroupLayouts = raw_data(world_layouts[:]),
		},
	)
	if renderer.gpu_driven_pipeline_layout == nil {
		return "failed to create GPU-driven pipeline layout"
	}
	renderer.gpu_driven_shadow_pipeline_layout = wgpu.DeviceCreatePipelineLayout(
		renderer.device,
		&wgpu.PipelineLayoutDescriptor {
			label = "Scrapbot GPU-Driven Shadow Pipeline Layout",
			bindGroupLayoutCount = 1,
			bindGroupLayouts = &renderer.gpu_driven_shadow_bind_group_layout,
		},
	)
	if renderer.gpu_driven_shadow_pipeline_layout == nil {
		return "failed to create GPU-driven shadow pipeline layout"
	}

	vertex_attributes := [?]wgpu.VertexAttribute {
		{format = .Float32x3, offset = 0, shaderLocation = 0},
		{format = .Float32x3, offset = 12, shaderLocation = 1},
		{format = .Float32x2, offset = 24, shaderLocation = 2},
	}
	vertex_buffer_layout := wgpu.VertexBufferLayout {
		stepMode = .Vertex,
		arrayStride = u64(size_of(resources.Vertex)),
		attributeCount = uint(len(vertex_attributes)),
		attributes = raw_data(vertex_attributes[:]),
	}
	color_target := wgpu.ColorTargetState {
		format = .RGBA16Float,
		writeMask = wgpu.ColorWriteMaskFlags_All,
	}
	fragment_state := wgpu.FragmentState {
		module = renderer.gpu_driven_shader,
		entryPoint = "fs_main",
		targetCount = 1,
		targets = &color_target,
	}
	renderer.gpu_driven_pipeline = wgpu.DeviceCreateRenderPipeline(
		renderer.device,
		&wgpu.RenderPipelineDescriptor {
			label = "Scrapbot GPU-Driven Render Pipeline",
			layout = renderer.gpu_driven_pipeline_layout,
			vertex = {
				module = renderer.gpu_driven_shader,
				entryPoint = "vs_main",
				bufferCount = 1,
				buffers = &vertex_buffer_layout,
			},
			primitive = {topology = .TriangleList, frontFace = .CCW, cullMode = .None},
			depthStencil = &wgpu.DepthStencilState {
				format = .Depth24Plus,
				depthWriteEnabled = .True,
				depthCompare = .Less,
			},
			multisample = {count = 1, mask = 0xFFFF_FFFF},
			fragment = &fragment_state,
		},
	)
	if renderer.gpu_driven_pipeline == nil {
		return "failed to create GPU-driven render pipeline"
	}
	renderer.gpu_driven_shadow_pipeline = wgpu.DeviceCreateRenderPipeline(
		renderer.device,
		&wgpu.RenderPipelineDescriptor {
			label = "Scrapbot GPU-Driven Shadow Pipeline",
			layout = renderer.gpu_driven_shadow_pipeline_layout,
			vertex = {
				module = renderer.gpu_driven_shader,
				entryPoint = "shadow_vs",
				bufferCount = 1,
				buffers = &vertex_buffer_layout,
			},
			primitive = {topology = .TriangleList, frontFace = .CCW, cullMode = .Back},
			depthStencil = &wgpu.DepthStencilState {
				format = .Depth32Float,
				depthWriteEnabled = .True,
				depthCompare = .Less,
			},
			multisample = {count = 1, mask = 0xFFFF_FFFF},
		},
	)
	if renderer.gpu_driven_shadow_pipeline == nil {
		return "failed to create GPU-driven shadow pipeline"
	}

	cull_source := wgpu.ShaderSourceWGSL {
		chain = {sType = .ShaderSourceWGSL},
		code = WGPU_GPU_CULL_SHADER,
	}
	renderer.gpu_cull_shader = wgpu.DeviceCreateShaderModule(
		renderer.device,
		&wgpu.ShaderModuleDescriptor {
			nextInChain = &cull_source,
			label = "Scrapbot GPU Culling Shader",
		},
	)
	if renderer.gpu_cull_shader == nil {
		return "failed to create GPU culling shader"
	}
	cull_entries := [?]wgpu.BindGroupLayoutEntry {
		{binding = 0, visibility = {.Compute}, buffer = {type = .ReadOnlyStorage}},
		{binding = 1, visibility = {.Compute}, buffer = {type = .ReadOnlyStorage}},
		{binding = 2, visibility = {.Compute}, buffer = {type = .Storage}},
		{binding = 3, visibility = {.Compute}, buffer = {type = .Storage}},
		{binding = 4, visibility = {.Compute}, buffer = {type = .Storage}},
		{binding = 5, visibility = {.Compute}, buffer = {type = .Storage}},
		{
			binding = 6,
			visibility = {.Compute},
			buffer = {type = .Uniform, minBindingSize = u64(size_of(WGPU_GPU_Cull_Uniform))},
		},
	}
	renderer.gpu_cull_bind_group_layout = wgpu.DeviceCreateBindGroupLayout(
		renderer.device,
		&wgpu.BindGroupLayoutDescriptor {
			label = "Scrapbot GPU Culling Bind Group Layout",
			entryCount = uint(len(cull_entries)),
			entries = raw_data(cull_entries[:]),
		},
	)
	if renderer.gpu_cull_bind_group_layout == nil {
		return "failed to create GPU culling bind group layout"
	}
	renderer.gpu_cull_pipeline_layout = wgpu.DeviceCreatePipelineLayout(
		renderer.device,
		&wgpu.PipelineLayoutDescriptor {
			label = "Scrapbot GPU Culling Pipeline Layout",
			bindGroupLayoutCount = 1,
			bindGroupLayouts = &renderer.gpu_cull_bind_group_layout,
		},
	)
	if renderer.gpu_cull_pipeline_layout == nil {
		return "failed to create GPU culling pipeline layout"
	}
	renderer.gpu_cull_pipeline = wgpu.DeviceCreateComputePipeline(
		renderer.device,
		&wgpu.ComputePipelineDescriptor {
			label = "Scrapbot GPU Culling Pipeline",
			layout = renderer.gpu_cull_pipeline_layout,
			compute = {module = renderer.gpu_cull_shader, entryPoint = "cull_instances"},
		},
	)
	if renderer.gpu_cull_pipeline == nil {
		return "failed to create GPU culling pipeline"
	}

	instance_bytes := u64(WGPU_MAX_GPU_INSTANCES) * u64(size_of(WGPU_GPU_Instance))
	visible_entries := WGPU_MAX_GPU_INSTANCES + WGPU_MAX_DRAW_BATCHES * WGPU_VISIBLE_ALIGNMENT
	visible_bytes := u64(visible_entries) * u64(size_of(u32))
	batch_bytes := u64(WGPU_MAX_DRAW_BATCHES) * u64(size_of(WGPU_GPU_Batch_Info))
	indirect_bytes := u64(WGPU_MAX_DRAW_BATCHES) * u64(size_of(WGPU_Draw_Indexed_Indirect))
	renderer.gpu_instance_buffer = wgpu_create_gpu_buffer(
		renderer,
		"Scrapbot GPU Instance Table",
		{.Storage, .CopyDst},
		instance_bytes,
	)
	renderer.gpu_batch_info_buffer = wgpu_create_gpu_buffer(
		renderer,
		"Scrapbot GPU Batch Table",
		{.Storage, .CopyDst},
		batch_bytes,
	)
	renderer.gpu_visible_buffer = wgpu_create_gpu_buffer(
		renderer,
		"Scrapbot GPU Visible Instances",
		{.Storage, .CopyDst},
		visible_bytes,
	)
	renderer.gpu_shadow_visible_buffer = wgpu_create_gpu_buffer(
		renderer,
		"Scrapbot GPU Shadow Visible Instances",
		{.Storage, .CopyDst},
		visible_bytes,
	)
	renderer.gpu_indirect_template_buffer = wgpu_create_gpu_buffer(
		renderer,
		"Scrapbot GPU Indirect Template",
		{.CopySrc, .CopyDst},
		indirect_bytes,
	)
	renderer.gpu_indirect_buffer = wgpu_create_gpu_buffer(
		renderer,
		"Scrapbot GPU Indirect Draws",
		{.Storage, .Indirect, .CopyDst},
		indirect_bytes,
	)
	renderer.gpu_shadow_indirect_buffer = wgpu_create_gpu_buffer(
		renderer,
		"Scrapbot GPU Shadow Indirect Draws",
		{.Storage, .Indirect, .CopyDst},
		indirect_bytes,
	)
	renderer.gpu_cull_uniform_buffer = wgpu_create_gpu_buffer(
		renderer,
		"Scrapbot GPU Culling Uniform",
		{.Uniform, .CopyDst},
		u64(size_of(WGPU_GPU_Cull_Uniform)),
	)
	if renderer.gpu_instance_buffer == nil ||
	   renderer.gpu_batch_info_buffer == nil ||
	   renderer.gpu_visible_buffer == nil ||
	   renderer.gpu_shadow_visible_buffer == nil ||
	   renderer.gpu_indirect_template_buffer == nil ||
	   renderer.gpu_indirect_buffer == nil ||
	   renderer.gpu_shadow_indirect_buffer == nil ||
	   renderer.gpu_cull_uniform_buffer == nil {
		return "failed to allocate GPU-driven renderer buffers"
	}

	cull_bind_entries := [?]wgpu.BindGroupEntry {
		{binding = 0, buffer = renderer.gpu_instance_buffer, size = instance_bytes},
		{binding = 1, buffer = renderer.gpu_batch_info_buffer, size = batch_bytes},
		{binding = 2, buffer = renderer.gpu_visible_buffer, size = visible_bytes},
		{binding = 3, buffer = renderer.gpu_shadow_visible_buffer, size = visible_bytes},
		{binding = 4, buffer = renderer.gpu_indirect_buffer, size = indirect_bytes},
		{binding = 5, buffer = renderer.gpu_shadow_indirect_buffer, size = indirect_bytes},
		{
			binding = 6,
			buffer = renderer.gpu_cull_uniform_buffer,
			size = u64(size_of(WGPU_GPU_Cull_Uniform)),
		},
	}
	renderer.gpu_cull_bind_group = wgpu.DeviceCreateBindGroup(
		renderer.device,
		&wgpu.BindGroupDescriptor {
			label = "Scrapbot GPU Culling Bind Group",
			layout = renderer.gpu_cull_bind_group_layout,
			entryCount = uint(len(cull_bind_entries)),
			entries = raw_data(cull_bind_entries[:]),
		},
	)
	if renderer.gpu_cull_bind_group == nil {
		return "failed to create GPU culling bind group"
	}
	return ""
}

wgpu_release_batch_bind_groups :: proc(cache: ^WGPU_Draw_Batch_Cache) {
	if cache == nil {
		return
	}
	for batch_index in 0 ..< cache.batch_count {
		batch := &cache.batches[batch_index]
		if batch.world_bind_group != nil {
			wgpu.BindGroupRelease(batch.world_bind_group)
		}
		if batch.shadow_bind_group != nil {
			wgpu.BindGroupRelease(batch.shadow_bind_group)
		}
		batch.world_bind_group = nil
		batch.shadow_bind_group = nil
	}
}

wgpu_make_batch_bind_group :: proc(
	renderer: ^WGPU_Renderer,
	visible_buffer: wgpu.Buffer,
	visible_offset, visible_capacity: u32,
	label: string,
	shadow: bool = false,
) -> wgpu.BindGroup {
	if shadow {
		entries := [?]wgpu.BindGroupEntry {
			{
				binding = 0,
				buffer = renderer.uniform_buffer,
				size = u64(size_of(WGPU_Render_Uniform)),
			},
			{
				binding = 3,
				buffer = renderer.gpu_instance_buffer,
				size = u64(WGPU_MAX_GPU_INSTANCES) * u64(size_of(WGPU_GPU_Instance)),
			},
			{
				binding = 4,
				buffer = visible_buffer,
				offset = u64(visible_offset) * u64(size_of(u32)),
				size = u64(visible_capacity) * u64(size_of(u32)),
			},
		}
		return wgpu.DeviceCreateBindGroup(
			renderer.device,
			&wgpu.BindGroupDescriptor {
				label = label,
				layout = renderer.gpu_driven_shadow_bind_group_layout,
				entryCount = uint(len(entries)),
				entries = raw_data(entries[:]),
			},
		)
	}
	entries := [?]wgpu.BindGroupEntry {
		{binding = 0, buffer = renderer.uniform_buffer, size = u64(size_of(WGPU_Render_Uniform))},
		{binding = 1, textureView = renderer.shadow_view},
		{binding = 2, sampler = renderer.shadow_sampler},
		{
			binding = 3,
			buffer = renderer.gpu_instance_buffer,
			size = u64(WGPU_MAX_GPU_INSTANCES) * u64(size_of(WGPU_GPU_Instance)),
		},
		{
			binding = 4,
			buffer = visible_buffer,
			offset = u64(visible_offset) * u64(size_of(u32)),
			size = u64(visible_capacity) * u64(size_of(u32)),
		},
	}
	return wgpu.DeviceCreateBindGroup(
		renderer.device,
		&wgpu.BindGroupDescriptor {
			label = label,
			layout = renderer.gpu_driven_world_bind_group_layout,
			entryCount = uint(len(entries)),
			entries = raw_data(entries[:]),
		},
	)
}

wgpu_sync_gpu_topology :: proc(
	renderer: ^WGPU_Renderer,
	render_list: ^Render_List,
	registry: ^resources.Registry,
) -> (
	^WGPU_Draw_Batch_Cache,
	string,
) {
	topology_changed :=
		!renderer.gpu_topology_valid ||
		renderer.gpu_world_uuid != render_list.world_uuid ||
		renderer.gpu_topology_revision != render_list.topology_revision
	if topology_changed {
		wgpu_release_batch_bind_groups(&renderer.draw_batch_cache)
	}
	cache := wgpu_ensure_draw_batch_cache(renderer, render_list)
	if cache == nil {
		return nil, "failed to build GPU draw batches"
	}
	if !topology_changed {
		return cache, ""
	}
	if cache.overflowed {
		return nil, "GPU-driven renderer exceeded its draw-batch limit"
	}
	batch_info: [WGPU_MAX_DRAW_BATCHES]WGPU_GPU_Batch_Info
	visible_offset: u32
	for batch_index in 0 ..< cache.batch_count {
		batch := &cache.batches[batch_index]
		batch.visible_offset = visible_offset
		batch.visible_capacity = wgpu_align_visible_capacity(batch.instance_count)
		visible_offset += batch.visible_capacity
		if visible_offset >
		   u32(WGPU_MAX_GPU_INSTANCES + WGPU_MAX_DRAW_BATCHES * WGPU_VISIBLE_ALIGNMENT) {
			return nil, "GPU-driven renderer exceeded its visible-instance capacity"
		}
		geometry, geometry_err := wgpu_geometry_cache(renderer, registry, batch.geometry)
		if geometry_err != "" {
			return nil, geometry_err
		}
		batch_info[batch_index] = {
			visible_offset = batch.visible_offset,
			visible_capacity = batch.visible_capacity,
		}
		batch.world_bind_group = wgpu_make_batch_bind_group(
			renderer,
			renderer.gpu_visible_buffer,
			batch.visible_offset,
			batch.visible_capacity,
			"Scrapbot GPU-Driven Batch Bind Group",
		)
		batch.shadow_bind_group = wgpu_make_batch_bind_group(
			renderer,
			renderer.gpu_shadow_visible_buffer,
			batch.visible_offset,
			batch.visible_capacity,
			"Scrapbot GPU-Driven Shadow Batch Bind Group",
			true,
		)
		if batch.world_bind_group == nil || batch.shadow_bind_group == nil {
			return nil, "failed to create GPU-driven batch bind groups"
		}
	}
	renderer.gpu_visible_capacity = int(visible_offset)
	wgpu.QueueWriteBuffer(
		renderer.queue,
		renderer.gpu_batch_info_buffer,
		0,
		&batch_info,
		uint(size_of(batch_info)),
	)
	renderer.gpu_topology_revision = render_list.topology_revision
	renderer.gpu_world_uuid = render_list.world_uuid
	renderer.gpu_topology_valid = true
	return cache, ""
}

wgpu_build_indirect_templates :: proc(
	cache: ^WGPU_Draw_Batch_Cache,
	registry: ^resources.Registry,
) -> (
	[WGPU_MAX_DRAW_BATCHES]WGPU_Draw_Indexed_Indirect,
	string,
) {
	templates: [WGPU_MAX_DRAW_BATCHES]WGPU_Draw_Indexed_Indirect
	if cache == nil {
		return templates, "GPU draw-batch cache is not available"
	}
	for batch, batch_index in cache.batches[:cache.batch_count] {
		geometry, ok := resources.get_geometry(registry, batch.geometry)
		if !ok {
			return templates, "GPU draw batch references unavailable geometry"
		}
		templates[batch_index] = {
			index_count = u32(len(geometry.indices)),
			first_instance = 0,
		}
	}
	return templates, ""
}

wgpu_refresh_indirect_templates :: proc(
	renderer: ^WGPU_Renderer,
	cache: ^WGPU_Draw_Batch_Cache,
	registry: ^resources.Registry,
) -> string {
	templates, err := wgpu_build_indirect_templates(cache, registry)
	if err != "" {
		return err
	}
	if templates == renderer.gpu_indirect_templates {
		return ""
	}
	wgpu.QueueWriteBuffer(
		renderer.queue,
		renderer.gpu_indirect_template_buffer,
		0,
		&templates,
		uint(size_of(templates)),
	)
	renderer.gpu_indirect_templates = templates
	return ""
}

wgpu_instance_bounds :: proc(instance: Render_Instance, geometry: ^resources.Geometry) -> [4]f32 {
	center := Vec3 {
		(geometry.bounds.min.x + geometry.bounds.max.x) * 0.5,
		(geometry.bounds.min.y + geometry.bounds.max.y) * 0.5,
		(geometry.bounds.min.z + geometry.bounds.max.z) * 0.5,
	}
	half_extent := Vec3 {
		(geometry.bounds.max.x - geometry.bounds.min.x) * 0.5,
		(geometry.bounds.max.y - geometry.bounds.min.y) * 0.5,
		(geometry.bounds.max.z - geometry.bounds.min.z) * 0.5,
	}
	model := wgpu_build_model(instance.transform)
	world_center := Vec3 {
		model[0] * center.x + model[4] * center.y + model[8] * center.z + model[12],
		model[1] * center.x + model[5] * center.y + model[9] * center.z + model[13],
		model[2] * center.x + model[6] * center.y + model[10] * center.z + model[14],
	}
	local_radius := math.sqrt(
		half_extent.x * half_extent.x +
		half_extent.y * half_extent.y +
		half_extent.z * half_extent.z,
	)
	max_scale := max(
		math.abs(instance.transform.scale.x),
		math.abs(instance.transform.scale.y),
		math.abs(instance.transform.scale.z),
	)
	return {world_center.x, world_center.y, world_center.z, local_radius * max_scale}
}

wgpu_build_gpu_instance :: proc(
	instance: Render_Instance,
	geometry: ^resources.Geometry,
	material: ^resources.Material,
	batch_index: int,
) -> WGPU_GPU_Instance {
	color := material.desc.base_color
	emissive := material.desc.emissive
	return WGPU_GPU_Instance {
		model = wgpu_build_model(instance.transform),
		normal_model = wgpu_build_normal_model(instance.transform),
		color = {color.x, color.y, color.z, color.w},
		emissive = {emissive.x, emissive.y, emissive.z, 0},
		shadow_flags = {
			1 if instance.shadow_caster else 0,
			1 if instance.shadow_receiver else 0,
			0,
			0,
		},
		bounds = wgpu_instance_bounds(instance, geometry),
		batch_index = u32(batch_index),
		active = 1,
	}
}

wgpu_upload_dirty_instance_ranges :: proc(renderer: ^WGPU_Renderer, dirty_indices: []int) {
	if len(dirty_indices) == 0 {
		return
	}
	slice.sort(dirty_indices)
	index := 0
	for index < len(dirty_indices) {
		first := dirty_indices[index]
		last := first + 1
		index += 1
		for index < len(dirty_indices) {
			slot := dirty_indices[index]
			if slot < last {
				index += 1
				continue
			}
			if slot != last {
				break
			}
			last += 1
			index += 1
		}
		count := last - first
		byte_count := uint(count * size_of(WGPU_GPU_Instance))
		wgpu.QueueWriteBuffer(
			renderer.queue,
			renderer.gpu_instance_buffer,
			u64(first * size_of(WGPU_GPU_Instance)),
			raw_data(renderer.gpu_instance_records[first:last]),
			byte_count,
		)
		renderer.gpu_instance_upload_count += 1
		renderer.gpu_instance_upload_bytes += u64(byte_count)
	}
}

wgpu_cpu_cull_counts :: proc(
	instances: []WGPU_GPU_Instance,
	planes: [6][4]f32,
	batch_count: int,
	shadow: bool = false,
) -> [WGPU_MAX_DRAW_BATCHES]u32 {
	counts: [WGPU_MAX_DRAW_BATCHES]u32
	for instance in instances {
		if instance.active == 0 || int(instance.batch_index) >= batch_count {
			continue
		}
		if shadow && instance.shadow_flags[0] < 0.5 {
			continue
		}
		if wgpu_sphere_visible(instance.bounds, planes) {
			counts[instance.batch_index] += 1
		}
	}
	return counts
}

wgpu_prepare_gpu_draw_batches :: proc(
	renderer: ^WGPU_Renderer,
	render_list: ^Render_List,
	registry: ^resources.Registry,
	width, height: u32,
) -> (
	[WGPU_MAX_DRAW_BATCHES]WGPU_Draw_Batch,
	int,
	string,
) {
	topology_changed :=
		!renderer.gpu_topology_valid ||
		renderer.gpu_world_uuid != render_list.world_uuid ||
		renderer.gpu_topology_revision != render_list.topology_revision
	cache, topology_err := wgpu_sync_gpu_topology(renderer, render_list, registry)
	if topology_err != "" {
		return {}, 0, topology_err
	}
	if indirect_err := wgpu_refresh_indirect_templates(renderer, cache, registry);
	   indirect_err != "" {
		return {}, 0, indirect_err
	}
	uniform: WGPU_Render_Uniform
	view_projection := wgpu_build_view_projection(
		render_list.camera,
		render_list.has_camera,
		width,
		height,
	)
	light_view_projection := mat4_identity()
	if render_list.directional_light_count > 0 {
		light_view_projection = wgpu_build_directional_light_view_projection(
			render_list.directional_lights[0].light.direction,
		)
	}
	uniform.mvp[0] = view_projection
	uniform.shadow_mvp[0] = light_view_projection
	uniform.ambient = {render_list.ambient.x, render_list.ambient.y, render_list.ambient.z, 1}
	uniform.light_counts = {
		u32(render_list.directional_light_count),
		u32(render_list.point_light_count),
		0,
		0,
	}
	for light, index in render_list.directional_lights[:render_list.directional_light_count] {
		uniform.directional_direction_intensity[index] = {
			light.light.direction.x,
			light.light.direction.y,
			light.light.direction.z,
			light.light.intensity,
		}
		uniform.directional_color[index] = {
			light.light.color.x,
			light.light.color.y,
			light.light.color.z,
			1,
		}
	}
	for light, index in render_list.point_lights[:render_list.point_light_count] {
		uniform.point_position_range[index] = {
			light.position.x,
			light.position.y,
			light.position.z,
			light.light.range,
		}
		uniform.point_color_intensity[index] = {
			light.light.color.x,
			light.light.color.y,
			light.light.color.z,
			light.light.intensity,
		}
	}
	wgpu.QueueWriteBuffer(
		renderer.queue,
		renderer.uniform_buffer,
		0,
		&uniform,
		uint(size_of(uniform)),
	)

	max_slot := -1
	for instance in render_list.instances {
		max_slot = max(max_slot, instance.slot)
	}
	if max_slot >= WGPU_MAX_GPU_INSTANCES {
		return {}, 0, "GPU-driven renderer exceeded its instance-slot capacity"
	}
	slot_count := max_slot + 1
	previous_slot_count := len(renderer.gpu_instance_records)
	if slot_count > previous_slot_count {
		resize(&renderer.gpu_instance_records, slot_count)
		resize(&renderer.gpu_instance_sources, slot_count)
		resize(&renderer.gpu_active_slots, slot_count)
	}
	clear(&renderer.gpu_dirty_indices)
	reset_instances := renderer.gpu_slot_count != slot_count || topology_changed
	if reset_instances {
		for slot in renderer.gpu_live_slots {
			renderer.gpu_instance_records[slot] = {}
			renderer.gpu_instance_sources[slot] = {}
			renderer.gpu_active_slots[slot] = false
			append(&renderer.gpu_dirty_indices, slot)
		}
		clear(&renderer.gpu_live_slots)
	}
	if len(renderer.gpu_batch_by_source) < len(render_list.instances) {
		resize(&renderer.gpu_batch_by_source, len(render_list.instances))
	}
	batch_by_source := renderer.gpu_batch_by_source[:len(render_list.instances)]
	for batch_index in 0 ..< cache.batch_count {
		batch := cache.batches[batch_index]
		first := int(batch.first_instance)
		last := min(first + int(batch.instance_count), cache.instance_count)
		for ordered_index in first ..< last {
			batch_by_source[cache.source_indices[ordered_index]] = batch_index
		}
	}
	for instance, source_index in render_list.instances {
		if instance.slot < 0 || instance.slot >= slot_count {
			continue
		}
		geometry, geometry_ok := resources.get_geometry(registry, instance.geometry.handle)
		material, material_ok := resources.get_material(registry, instance.material.handle)
		if !geometry_ok || !material_ok {
			continue
		}
		slot := instance.slot
		source := WGPU_Instance_Source_State {
			transform = instance.transform,
			geometry = instance.geometry.handle,
			material = instance.material.handle,
			geometry_version = geometry.version,
			material_version = material.version,
			shadow_caster = instance.shadow_caster,
			shadow_receiver = instance.shadow_receiver,
			batch_index = u32(batch_by_source[source_index]),
		}
		if !renderer.gpu_active_slots[slot] || renderer.gpu_instance_sources[slot] != source {
			record := wgpu_build_gpu_instance(
				instance,
				geometry,
				material,
				batch_by_source[source_index],
			)
			renderer.gpu_instance_records[slot] = record
			renderer.gpu_instance_sources[slot] = source
			renderer.gpu_active_slots[slot] = true
			append(&renderer.gpu_dirty_indices, slot)
		}
		if reset_instances {
			append(&renderer.gpu_live_slots, slot)
		}
	}
	wgpu_upload_dirty_instance_ranges(renderer, renderer.gpu_dirty_indices[:])
	renderer.gpu_slot_count = slot_count
	cull_uniform := WGPU_GPU_Cull_Uniform {
		camera_planes = wgpu_extract_frustum_planes(view_projection),
		shadow_planes = wgpu_extract_frustum_planes(light_view_projection),
		slot_count = u32(slot_count),
		batch_count = u32(cache.batch_count),
	}
	wgpu.QueueWriteBuffer(
		renderer.queue,
		renderer.gpu_cull_uniform_buffer,
		0,
		&cull_uniform,
		uint(size_of(cull_uniform)),
	)
	return cache.batches, cache.batch_count, ""
}

wgpu_encode_gpu_culling :: proc(
	renderer: ^WGPU_Renderer,
	encoder: wgpu.CommandEncoder,
	batch_count: int,
) -> string {
	if batch_count <= 0 || renderer.gpu_slot_count <= 0 {
		return ""
	}
	copy_size := u64(batch_count) * u64(size_of(WGPU_Draw_Indexed_Indirect))
	wgpu.CommandEncoderCopyBufferToBuffer(
		encoder,
		renderer.gpu_indirect_template_buffer,
		0,
		renderer.gpu_indirect_buffer,
		0,
		copy_size,
	)
	wgpu.CommandEncoderCopyBufferToBuffer(
		encoder,
		renderer.gpu_indirect_template_buffer,
		0,
		renderer.gpu_shadow_indirect_buffer,
		0,
		copy_size,
	)
	pass := wgpu.CommandEncoderBeginComputePass(
		encoder,
		&wgpu.ComputePassDescriptor{label = "Scrapbot GPU Visibility Pass"},
	)
	if pass == nil {
		return "failed to begin GPU visibility pass"
	}
	defer wgpu.ComputePassEncoderRelease(pass)
	wgpu.ComputePassEncoderSetPipeline(pass, renderer.gpu_cull_pipeline)
	wgpu.ComputePassEncoderSetBindGroup(pass, 0, renderer.gpu_cull_bind_group)
	workgroups := u32((renderer.gpu_slot_count + 63) / 64)
	wgpu.ComputePassEncoderDispatchWorkgroups(pass, workgroups, 1, 1)
	wgpu.ComputePassEncoderEnd(pass)
	return ""
}

wgpu_prepare_cpu_culling :: proc(
	renderer: ^WGPU_Renderer,
	render_list: ^Render_List,
	width, height: u32,
) {
	if renderer == nil || renderer.gpu_slot_count <= 0 {
		return
	}
	view_projection := wgpu_build_view_projection(
		render_list.camera,
		render_list.has_camera,
		width,
		height,
	)
	light_view_projection := mat4_identity()
	if render_list.directional_light_count > 0 {
		light_view_projection = wgpu_build_directional_light_view_projection(
			render_list.directional_lights[0].light.direction,
		)
	}
	camera_planes := wgpu_extract_frustum_planes(view_projection)
	shadow_planes := wgpu_extract_frustum_planes(light_view_projection)
	if len(renderer.gpu_cpu_visible) < renderer.gpu_visible_capacity {
		resize(&renderer.gpu_cpu_visible, renderer.gpu_visible_capacity)
		resize(&renderer.gpu_cpu_shadow_visible, renderer.gpu_visible_capacity)
	}
	visible := renderer.gpu_cpu_visible[:renderer.gpu_visible_capacity]
	shadow_visible := renderer.gpu_cpu_shadow_visible[:renderer.gpu_visible_capacity]
	camera_counts := wgpu_cpu_cull_counts(
		renderer.gpu_instance_records[:renderer.gpu_slot_count],
		camera_planes,
		renderer.draw_batch_cache.batch_count,
	)
	shadow_counts := wgpu_cpu_cull_counts(
		renderer.gpu_instance_records[:renderer.gpu_slot_count],
		shadow_planes,
		renderer.draw_batch_cache.batch_count,
		true,
	)
	camera_cursors: [WGPU_MAX_DRAW_BATCHES]u32
	shadow_cursors: [WGPU_MAX_DRAW_BATCHES]u32
	for instance, slot in renderer.gpu_instance_records[:renderer.gpu_slot_count] {
		if instance.active == 0 ||
		   int(instance.batch_index) >= renderer.draw_batch_cache.batch_count {
			continue
		}
		batch := renderer.draw_batch_cache.batches[instance.batch_index]
		if wgpu_sphere_visible(instance.bounds, camera_planes) {
			visible[batch.visible_offset + camera_cursors[instance.batch_index]] = u32(slot)
			camera_cursors[instance.batch_index] += 1
		}
		if instance.shadow_flags[0] > 0.5 && wgpu_sphere_visible(instance.bounds, shadow_planes) {
			shadow_visible[batch.visible_offset + shadow_cursors[instance.batch_index]] = u32(slot)
			shadow_cursors[instance.batch_index] += 1
		}
	}
	indirect := renderer.gpu_indirect_templates
	shadow_indirect := renderer.gpu_indirect_templates
	for batch_index in 0 ..< renderer.draw_batch_cache.batch_count {
		indirect[batch_index].instance_count = camera_counts[batch_index]
		shadow_indirect[batch_index].instance_count = shadow_counts[batch_index]
	}
	wgpu.QueueWriteBuffer(
		renderer.queue,
		renderer.gpu_visible_buffer,
		0,
		raw_data(visible),
		uint(len(visible) * size_of(u32)),
	)
	wgpu.QueueWriteBuffer(
		renderer.queue,
		renderer.gpu_shadow_visible_buffer,
		0,
		raw_data(shadow_visible),
		uint(len(shadow_visible) * size_of(u32)),
	)
	wgpu.QueueWriteBuffer(
		renderer.queue,
		renderer.gpu_indirect_buffer,
		0,
		&indirect,
		uint(size_of(indirect)),
	)
	wgpu.QueueWriteBuffer(
		renderer.queue,
		renderer.gpu_shadow_indirect_buffer,
		0,
		&shadow_indirect,
		uint(size_of(shadow_indirect)),
	)
}
