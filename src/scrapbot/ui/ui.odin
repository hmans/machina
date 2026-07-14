package ui

import shared "../shared"
import "core:fmt"
import "core:math"

MAX_NODES :: 4096
MAX_PAINT_COMMANDS :: 16384
FONT_FIRST_CHAR :: 32
FONT_CHAR_COUNT :: 95
FONT_ATLAS_SIZE :: 512
FONT_ASCENDER :: f32(0.96875)
FONT_ATLAS_DATA :: #load("assets/inter_mtsdf.bin")

EDITOR_TOP_BAR_HEIGHT :: f32(48)
EDITOR_STATUS_BAR_HEIGHT :: f32(28)
EDITOR_LEFT_SIDEBAR_WIDTH :: f32(240)
EDITOR_RIGHT_SIDEBAR_WIDTH :: f32(300)
EDITOR_SIDEBAR_MIN_WIDTH :: f32(150)
EDITOR_VIEWPORT_MIN_WIDTH :: f32(320)
EDITOR_VIEWPORT_INSET :: f32(4)
EDITOR_ENTITY_ROW_HEIGHT :: f32(28)
EDITOR_SCROLL_SPEED :: f32(48)
EDITOR_SCROLL_SMOOTHNESS :: f32(18)
EDITOR_SNAPSHOT_INTERVAL :: f32(0.2)

Rect :: struct {
	x, y, width, height: f32,
}
Pointer_Input :: struct {
	position: shared.Vec2,
	wheel_y: f32,
	primary_down, available: bool,
}
Paint_Kind :: enum {
	Panel,
	Glyph,
	Line,
	Triangle,
	Ring,
}
Paint_Command :: struct {
	kind: Paint_Kind,
	rect: Rect,
	color: shared.Vec4,
	uv: shared.Vec4,
	corner_radius: f32,
	border_color: shared.Vec4,
	border_width: f32,
	line_start, line_end: shared.Vec2,
	line_thickness: f32,
	triangle: [3]shared.Vec2,
	ring_center, ring_axis_x, ring_axis_y: shared.Vec2,
	ring_thickness: f32,
	clip: Rect,
	has_clip: bool,
}
Editor_Gizmo_Handle :: enum {
	None,
	X,
	Y,
	Z,
	XY,
	XZ,
	YZ,
	Center,
}
EDITOR_GIZMO_RING_POINT_COUNT :: 64
Font_Glyph :: struct {
	advance: f32,
	plane, uv: shared.Vec4,
}
Font_Atlas :: struct {
	glyphs: [FONT_CHAR_COUNT]Font_Glyph,
	ready: bool,
}
Split_Handle :: struct {
	rect: Rect,
	before_node, after_node: int,
	min_size: f32,
	horizontal: bool,
	editor: bool,
	hovered, active: bool,
}
Node :: struct {
	entity: shared.Entity,
	origin: shared.Entity_Origin,
	editor_role: shared.Editor_UI_Role,
	layout_index, hstack_index, vstack_index, scroll_area_index, panel_index, table_index, text_index, button_index, parent_entity_index: int,
	rect, clip: Rect,
	paint_order: int,
	scroll_offset, scroll_target, scroll_max, scroll_content_height: f32,
	split_weight: f32,
	split_parent: shared.Entity,
	split_weight_valid: bool,
	seen, hovered, active, has_clip: bool,
}
State :: struct {
	nodes: [MAX_NODES]Node,
	node_count: int,
	paint: [MAX_PAINT_COMMANDS]Paint_Command,
	paint_count: int,
	font: Font_Atlas,
	active_entity: shared.Entity,
	has_active_entity: bool,
	previous_primary_down: bool,
	editor_ui_active_entity: shared.Entity,
	editor_ui_has_active_entity: bool,
	next_paint_order: int,
	split_handles: [MAX_NODES]Split_Handle,
	split_handle_count, active_split_handle: int,
	split_previous_primary_down: bool,
	editor_split_previous_primary_down: bool,
	active_split_editor: bool,
	split_drag_pointer: f32,
	editor_visible: bool,
	editor_pixel_density: f32,
	editor_paint_start: int,
	editor_selected_entity: shared.Entity,
	editor_has_selection: bool,
	editor_snapshot_elapsed: f32,
	editor_snapshot_valid: bool,
	editor_snapshot_was_visible: bool,
	editor_snapshot_has_selection: bool,
	editor_snapshot_selected_entity: shared.Entity,
	editor_snapshot_refresh_count: u64,
	editor_previous_primary_down: bool,
	editor_pick_requested: bool,
	editor_pick_position: shared.Vec2,
	editor_scene_camera_captures_input: bool,
	editor_gizmo_visible: bool,
	editor_gizmo_mode: shared.Editor_Gizmo_Mode,
	editor_gizmo_origin: shared.Vec2,
	editor_gizmo_endpoints: [3]shared.Vec2,
	editor_gizmo_plane_points: [3][4]shared.Vec2,
	editor_gizmo_ring_points: [3][EDITOR_GIZMO_RING_POINT_COUNT]shared.Vec2,
	editor_gizmo_hovered_handle: Editor_Gizmo_Handle,
	editor_gizmo_active_handle: Editor_Gizmo_Handle,
	editor_gizmo_captures_pointer: bool,
	editor_gizmo_drag_pointer: shared.Vec2,
	editor_gizmo_drag_last_pointer: shared.Vec2,
	editor_gizmo_drag_angle: f32,
	editor_gizmo_drag_position: shared.Vec3,
	editor_gizmo_drag_rotation: shared.Vec3,
	editor_gizmo_drag_scale: shared.Vec3,
	editor_gizmo_drag_direction: shared.Vec2,
	editor_gizmo_drag_screen_axes: [3]shared.Vec2,
	editor_gizmo_drag_camera_right: shared.Vec3,
	editor_gizmo_drag_camera_up: shared.Vec3,
	editor_gizmo_drag_pixels: f32,
	editor_gizmo_drag_world_scale: f32,
	editor_gizmo_paint_start: int,
	editor_gizmo_paint_end: int,
	err: string,
}

init :: proc(state: ^State) -> string {
	state^ = {}
	state.editor_pixel_density = 1
	state.active_split_handle = -1
	state.font.glyphs = FONT_GLYPHS
	state.font.ready = true
	return ""
}

destroy :: proc(state: ^State) {
	if state == nil { return }
	state^ = {}
}

reconcile :: proc(
	state: ^State,
	world: ^shared.World,
	width, height: f32,
	pointer: Pointer_Input = {},
	drawable_width: f32 = 0,
	drawable_height: f32 = 0,
	delta_seconds: f32 = 1.0 / 60.0,
) -> string {
	if state == nil || world == nil { return "UI state or world is unavailable" }
	surface_width := drawable_width; if surface_width <= 0 { surface_width = width }
	surface_height := drawable_height; if surface_height <= 0 { surface_height = height }
	if !state.font.ready { if err := init(state); err != "" { return err } }
	editor_scale := max(state.editor_pixel_density, 1)
	editor_width := surface_width / editor_scale
	editor_height := surface_height / editor_scale
	reconcile_editor_ui_world(state, world, editor_width, editor_height)
	for &node in state.nodes[:state.node_count] { node.seen = false }
	for &entity in world.entities {
		if !entity.alive ||
		   (entity.origin == .Editor && !state.editor_visible) ||
		   entity.ui_layout_index < 0 ||
		   entity.ui_layout_index >= len(world.ui_layouts) ||
		   ui_entity_or_ancestor_hidden(world, int(entity.id.index)) { continue }
		index := find_node(state, entity.id)
		if index <
		   0 { if state.node_count >= MAX_NODES { return "too many UI entities" }; index = state.node_count; state.node_count += 1; state.nodes[index] = {} }
		node := &state.nodes[index]; node.entity = entity.id; node.origin = entity.origin; node.editor_role = .None; if entity.editor_ui_index >= 0 && entity.editor_ui_index < len(world.editor_uis) { node.editor_role = world.editor_uis[entity.editor_ui_index].role }; node.layout_index = entity.ui_layout_index; node.hstack_index = entity.ui_hstack_index; node.vstack_index = entity.ui_vstack_index; node.scroll_area_index = entity.ui_scroll_area_index; node.panel_index = entity.ui_panel_index; node.table_index = entity.ui_table_index; node.text_index = entity.ui_text_index; node.button_index = entity.ui_button_index; node.parent_entity_index = find_parent_entity(world, world.ui_layouts[entity.ui_layout_index].parent, entity.origin); node.seen = true
	}
	for i := 0;
	    i <
	    state.node_count; { if state.nodes[i].seen { i += 1 } else { state.node_count -= 1; state.nodes[i] = state.nodes[state.node_count] } }
	project_layout := Rect{0, 0, width, height}
	editor_layout := Rect{0, 0, editor_width, editor_height}
	project_pointer := project_pointer_input(
		state,
		pointer,
		width,
		height,
		surface_width,
		surface_height,
	); if state.editor_gizmo_captures_pointer { project_pointer = {} }
	editor_pointer := pointer
	if editor_pointer.available { editor_pointer.position.x /= editor_scale; editor_pointer.position.y /= editor_scale }
	if err := layout_all(state, world, project_layout, editor_layout); err != "" { return err }
	if editor_ui_fit_inspector_width(state, world) {
		if err := layout_all(state, world, project_layout, editor_layout); err != "" { return err }
	}
	if update_split_interaction(
		state,
		project_pointer,
		false,
	) { if err := layout_all(state, world, project_layout, editor_layout); err != "" { return err }; _ = update_split_interaction(state, project_pointer, false) }
	if update_split_interaction(
		state,
		editor_pointer,
		true,
	) { if err := layout_all(state, world, project_layout, editor_layout); err != "" { return err }; if editor_ui_fit_inspector_width(state, world) { if err := layout_all(state, world, project_layout, editor_layout); err != "" { return err } }; _ = update_split_interaction(state, editor_pointer, true) }
	if state.active_split_handle >= 0 { project_pointer = {}; editor_pointer = {} }
	if update_scroll_areas(
		state,
		world,
		project_pointer,
		delta_seconds,
		false,
	) { if err := layout_all(state, world, project_layout, editor_layout); err != "" { return err } }
	if update_scroll_areas(
		state,
		world,
		editor_pointer,
		delta_seconds,
		true,
	) { if err := layout_all(state, world, project_layout, editor_layout); err != "" { return err } }
	_, _ = update_interaction(state, project_pointer, false)
	pressed, pressed_ok := update_interaction(state, editor_pointer, true)
	if pressed_ok { handle_editor_ecs_press(state, world, pressed, editor_pointer.position) }
	if state.editor_has_selection {
		index := int(state.editor_selected_entity.index)
		if index < 0 ||
		   index >= len(world.entities) ||
		   !world.entities[index].alive ||
		   world.entities[index].origin == .Editor ||
		   world.entities[index].id.generation !=
			   state.editor_selected_entity.generation { editor_clear_selection(state) }
	}
	if state.editor_visible {
		state.editor_snapshot_elapsed += max(delta_seconds, 0)
		selection_changed :=
			state.editor_snapshot_has_selection != state.editor_has_selection ||
			(state.editor_has_selection &&
					state.editor_snapshot_selected_entity != state.editor_selected_entity)
		if !state.editor_snapshot_valid ||
		   selection_changed ||
		   state.editor_snapshot_elapsed >= EDITOR_SNAPSHOT_INTERVAL {
			refresh_editor_ecs_snapshot(state, world)
		}
	}
	state.editor_snapshot_was_visible = state.editor_visible
	if state.editor_pick_requested { state.editor_pick_position.x *= editor_scale; state.editor_pick_position.y *= editor_scale }
	state.paint_count = 0
	for i in 0 ..< state.node_count { if state.nodes[i].origin != .Editor && state.nodes[i].parent_entity_index < 0 { if err := paint_node(state, world, i, 0); err != "" { return err } } }
	if err := append_split_handles(state, false); err != "" { return err }
	state.editor_paint_start = state.paint_count
	if state.editor_visible {
		for i in 0 ..< state.node_count { if state.nodes[i].origin == .Editor && state.nodes[i].parent_entity_index < 0 { if err := paint_node(state, world, i, 0); err != "" { return err } } }
		if err := append_split_handles(state, true); err != "" { return err }
		if editor_scale !=
		   1 { for i in state.editor_paint_start ..< state.paint_count { scale_paint_command(&state.paint[i], editor_scale) } }
		state.editor_gizmo_paint_start = state.paint_count
		if err := append_editor_gizmo(state); err != "" { return err }
		state.editor_gizmo_paint_end = state.paint_count
	}
	return ""
}

ui_entity_or_ancestor_hidden :: proc(world: ^shared.World, entity_index: int) -> bool {
	index := entity_index
	for depth in 0 ..< MAX_NODES {
		if index < 0 || index >= len(world.entities) { return false }
		entity := world.entities[index]
		if entity.ui_layout_index < 0 ||
		   entity.ui_layout_index >= len(world.ui_layouts) { return false }
		layout := world.ui_layouts[entity.ui_layout_index]
		if layout.hidden { return true }
		if layout.parent == "" { return false }
		index = find_parent_entity(world, layout.parent, entity.origin)
		if index < 0 { return false }
	}
	return true
}

editor_viewport :: proc(
	state: ^State,
	drawable_width, drawable_height: f32,
	project_width: f32 = 1280,
	project_height: f32 = 720,
) -> Rect {
	scale := f32(
		1,
	); if state != nil && state.editor_pixel_density > 0 { scale = state.editor_pixel_density }
	return editor_viewport_for_scale(state, drawable_width, drawable_height, scale)
}

editor_viewport_for_scale :: proc(
	state: ^State,
	drawable_width, drawable_height, scale: f32,
) -> Rect {
	available := Rect{0, 0, drawable_width, drawable_height}
	if state != nil && state.editor_visible {
		found := false
		for node in state.nodes[:state.node_count] {
			if node.origin != .Editor || node.editor_role != .Viewport { continue }
			available = {
				node.rect.x * scale,
				node.rect.y * scale,
				node.rect.width * scale,
				node.rect.height * scale,
			}
			found = true
			break
		}
		if !found { available = {(EDITOR_LEFT_SIDEBAR_WIDTH + EDITOR_VIEWPORT_INSET) * scale, EDITOR_TOP_BAR_HEIGHT * scale, drawable_width - (EDITOR_LEFT_SIDEBAR_WIDTH + EDITOR_RIGHT_SIDEBAR_WIDTH + EDITOR_VIEWPORT_INSET * 2) * scale, drawable_height - (EDITOR_TOP_BAR_HEIGHT + EDITOR_STATUS_BAR_HEIGHT) * scale} }
	}
	if available.width <= 0 ||
	   available.height <=
		   0 { return {available.x, available.y, max(available.width, 0), max(available.height, 0)} }
	return available
}

project_pointer_input :: proc(
	state: ^State,
	pointer: Pointer_Input,
	width, height: f32,
	drawable_width: f32 = 0,
	drawable_height: f32 = 0,
) -> Pointer_Input {
	if state == nil || !pointer.available { return pointer }
	surface_width := drawable_width; if surface_width <= 0 { surface_width = width }
	surface_height := drawable_height; if surface_height <= 0 { surface_height = height }
	viewport := editor_viewport(state, surface_width, surface_height, width, height)
	if !rect_contains(viewport, pointer.position) { return {} }
	return {
		position = {
			(pointer.position.x - viewport.x) / viewport.width * width,
			(pointer.position.y - viewport.y) / viewport.height * height,
		},
		wheel_y = pointer.wheel_y,
		primary_down = pointer.primary_down,
		available = true,
	}
}

editor_clear_selection :: proc(state: ^State) {if state == nil { return }
	state.editor_has_selection = false
	state.editor_snapshot_valid = false
	for &node in state.nodes[:state.node_count] { if node.editor_role == .Inspector_Scroll { node.scroll_offset = 0; node.scroll_target = 0 } }
	state.editor_gizmo_active_handle = .None
	state.editor_gizmo_captures_pointer = false
	state.editor_gizmo_visible = false}

editor_set_gizmo_mode :: proc(state: ^State, mode: shared.Editor_Gizmo_Mode) {
	if state == nil || state.editor_gizmo_mode == mode { return }
	state.editor_gizmo_mode = mode
	state.editor_gizmo_active_handle = .None
	state.editor_gizmo_hovered_handle = .None
	state.editor_gizmo_captures_pointer = false
	state.editor_snapshot_valid = false
}

editor_select_entity :: proc(
	state: ^State,
	world: ^shared.World,
	entity: shared.Entity,
	height: f32,
) -> bool {
	_ = height
	if state == nil || world == nil { return false }; index := int(entity.index)
	if index < 0 ||
	   index >= len(world.entities) ||
	   !world.entities[index].alive ||
	   world.entities[index].origin == .Editor ||
	   world.entities[index].id.generation != entity.generation { return false }
	if !state.editor_has_selection ||
	   state.editor_selected_entity !=
		   entity { for &node in state.nodes[:state.node_count] { if node.editor_role == .Inspector_Scroll { node.scroll_offset = 0; node.scroll_target = 0 } } }
	if !state.editor_has_selection ||
	   state.editor_selected_entity !=
		   entity { state.editor_gizmo_active_handle = .None; state.editor_gizmo_captures_pointer = false }
	state.editor_selected_entity =
		entity; state.editor_has_selection = true; state.editor_snapshot_valid = false
	row_slot := -1
	for component in world.editor_uis { if (component.role == .Browser_Row || component.role == .Browser_Row_Label) && component.target == entity { row_slot = component.slot; break } }
	if row_slot >=
	   0 { for &node in state.nodes[:state.node_count] { if node.editor_role != .Browser_Scroll { continue }; row_top := f32(row_slot) * EDITOR_ENTITY_ROW_HEIGHT; row_bottom := row_top + EDITOR_ENTITY_ROW_HEIGHT; if row_top < node.scroll_target { node.scroll_target = row_top } else if row_bottom > node.scroll_target + node.rect.height { node.scroll_target = row_bottom - node.rect.height }; break } }
	return true
}

find_node :: proc(state: ^State, entity: shared.Entity) -> int {
	for node, i in state.nodes[:state.node_count] {
		if node.entity == entity { return i }
	}
	return -1
}

find_node_by_entity_index :: proc(state: ^State, index: int) -> int {
	for node, i in state.nodes[:state.node_count] {
		if int(node.entity.index) == index { return i }
	}
	return -1
}

find_parent_entity :: proc(
	world: ^shared.World,
	name: string,
	origin: shared.Entity_Origin,
) -> int {
	if name == "" { return -1 }
	for entity in world.entities {
		if entity.alive &&
		   entity.origin == origin &&
		   entity.name == name { return int(entity.id.index) }
	}
	return -1
}

handle_editor_ecs_press :: proc(
	state: ^State,
	world: ^shared.World,
	pressed: shared.Entity,
	position: shared.Vec2,
) {
	entity_index := int(pressed.index)
	for entity_index >= 0 && entity_index < len(world.entities) {
		entity := world.entities[entity_index]
		if entity.editor_ui_index >= 0 && entity.editor_ui_index < len(world.editor_uis) {
			component := world.editor_uis[entity.editor_ui_index]
			switch component.role {
				case .Browser_Row, .Browser_Row_Label:
					if editor_select_entity(
						state,
						world,
						component.target,
						0,
					) { state.editor_snapshot_valid = false }
					return
				case .Viewport:
					if !state.editor_gizmo_captures_pointer { state.editor_pick_requested = true; state.editor_pick_position = position }
					return
				case .None,
				     .Root,
				     .Browser_Scroll,
				     .Browser_Header,
				     .Inspector_Header,
				     .Inspector_Scroll,
				     .Inspector_Content,
				     .Inspector_Panel,
				     .Inspector_Table,
				     .Inspector_Cell,
				     .Status:
			}
		}
		layout_index := entity.ui_layout_index
		if layout_index < 0 || layout_index >= len(world.ui_layouts) { return }
		entity_index = find_parent_entity(world, world.ui_layouts[layout_index].parent, .Editor)
	}
}

layout_all :: proc(
	state: ^State,
	world: ^shared.World,
	project_viewport, editor_viewport: Rect,
) -> string {
	state.next_paint_order = 0
	state.split_handle_count = 0
	for i in 0 ..< state.node_count { if state.nodes[i].parent_entity_index < 0 { viewport := project_viewport; if state.nodes[i].origin == .Editor { viewport = editor_viewport }; if err := layout_node(state, world, i, viewport, {}, false, {}, false, {}, false, 0); err != "" { return err } } }
	return ""
}

layout_node :: proc(
	state: ^State,
	world: ^shared.World,
	node_index: int,
	parent: Rect,
	flow_position: shared.Vec2,
	flowed: bool,
	flow_size: shared.Vec2,
	has_flow_size: bool,
	inherited_clip: Rect,
	has_inherited_clip: bool,
	depth: int,
) -> string {
	if depth > MAX_NODES { return "UI hierarchy contains a cycle" }
	node := &state.nodes[node_index]; layout := world.ui_layouts[node.layout_index]
	if node.parent_entity_index < 0 {
		node.rect = {
			layout.position.x + layout.margin.w,
			layout.position.y + layout.margin.x,
			layout.size.x,
			layout.size.y,
		}
	} else if flowed {
		size := layout.size
		if has_flow_size { size = flow_size }
		node.rect = {flow_position.x, flow_position.y, size.x, size.y}
	} else {
		parent_padding: shared.Vec4
		parent_entity := world.entities[node.parent_entity_index]
		if parent_entity.ui_layout_index >= 0 &&
		   parent_entity.ui_layout_index < len(world.ui_layouts) {
			parent_padding = world.ui_layouts[parent_entity.ui_layout_index].padding
		}
		node.rect = {
			parent.x + parent_padding.w + layout.position.x + layout.margin.w,
			parent.y + parent_padding.x + layout.position.y + layout.margin.x,
			layout.size.x,
			layout.size.y,
		}
	}
	node.paint_order = state.next_paint_order; state.next_paint_order += 1
	node.clip = inherited_clip; node.has_clip = has_inherited_clip
	cursor := f32(0)
	gap := f32(
		0,
	); stack := shared.UI_Stack_Component{}; is_hstack := node.hstack_index >= 0 && node.hstack_index < len(world.ui_hstacks); is_vstack := node.vstack_index >= 0 && node.vstack_index < len(world.ui_vstacks)
	is_scroll_area :=
		node.scroll_area_index >= 0 && node.scroll_area_index < len(world.ui_scroll_areas)
	is_panel := node.panel_index >= 0 && node.panel_index < len(world.ui_panels)
	is_table := node.table_index >= 0 && node.table_index < len(world.ui_tables)
	panel: shared.UI_Panel_Component
	table: shared.UI_Table_Component
	if is_panel { panel = world.ui_panels[node.panel_index] }
	if is_table { table = world.ui_tables[node.table_index] }
	if is_hstack { stack = world.ui_hstacks[node.hstack_index]; gap = stack.gap }
	if is_vstack { stack = world.ui_vstacks[node.vstack_index]; gap = stack.gap }
	content := Rect {
		node.rect.x + layout.padding.w,
		node.rect.y + layout.padding.x,
		max(node.rect.width - layout.padding.w - layout.padding.y, 0),
		max(node.rect.height - layout.padding.x - layout.padding.z, 0),
	}
	if is_panel && panel.title != "" {
		title_height := min(max(panel.title_height, 0), content.height)
		content.y += title_height
		content.height -= title_height
	}
	child_clip := inherited_clip; child_has_clip := has_inherited_clip
	if is_scroll_area { if child_has_clip { child_clip = rect_intersection(child_clip, content) } else { child_clip = content }; child_has_clip = true }
	scroll_offset := node.scroll_offset
	content_bottom := f32(0)
	children: [MAX_NODES]int
	child_count := 0
	total_margins := f32(0)
	total_weight := f32(0)
	if ((is_hstack || is_vstack) && stack.fill) || is_table {
		for child_index in 0 ..< state.node_count {
			child := &state.nodes[child_index]
			if child.parent_entity_index != int(node.entity.index) { continue }
			children[child_count] = child_index
			child_count += 1
			if is_table { continue }
			child_layout := world.ui_layouts[child.layout_index]
			if is_hstack {
				total_margins += child_layout.margin.w + child_layout.margin.y
			} else {
				total_margins += child_layout.margin.x + child_layout.margin.z
			}
			if !child.split_weight_valid || child.split_parent != node.entity {
				child.split_weight = max(child_layout.size.y, 1)
				if is_hstack { child.split_weight = max(child_layout.size.x, 1) }
				child.split_parent = node.entity
				child.split_weight_valid = true
			}
			total_weight += child.split_weight
		}
	}
	available_main := content.height; if is_hstack { available_main = content.width }
	available_main = max(available_main - total_margins - gap * f32(max(child_count - 1, 0)), 0)
	child_main_sizes: [MAX_NODES]f32
	if (is_hstack || is_vstack) && stack.fill && child_count > 0 {
		resolved: [MAX_NODES]bool
		remaining_size := available_main
		remaining_weight := total_weight
		effective_min := min(stack.min_size, available_main / f32(child_count))
		for _ in 0 ..< child_count {
			resolved_one := false
			for ordinal in 0 ..< child_count {
				if resolved[ordinal] { continue }
				weight := state.nodes[children[ordinal]].split_weight
				proposed := remaining_size / f32(max(child_count, 1))
				if remaining_weight > 0 { proposed = remaining_size * weight / remaining_weight }
				if proposed >= effective_min { continue }
				child_main_sizes[ordinal] = effective_min
				resolved[ordinal] = true
				remaining_size = max(remaining_size - effective_min, 0)
				remaining_weight = max(remaining_weight - weight, 0)
				resolved_one = true
			}
			if !resolved_one { break }
		}
		for ordinal in 0 ..< child_count {
			if resolved[ordinal] { continue }
			weight := state.nodes[children[ordinal]].split_weight
			child_main_sizes[ordinal] = remaining_size / f32(max(child_count, 1))
			if remaining_weight >
			   0 { child_main_sizes[ordinal] = remaining_size * weight / remaining_weight }
		}
	}
	child_ordinal := 0
	table_y, table_row_height := f32(0), f32(0)
	table_columns := max(table.columns, 1)
	table_column_width := max(
		(content.width - table.column_gap * f32(max(table_columns - 1, 0))) / f32(table_columns),
		0,
	)
	for child_index in 0 ..< state.node_count {
		child := &state.nodes[child_index]; if child.parent_entity_index != int(node.entity.index) { continue }
		child_layout := world.ui_layouts[child.layout_index]
		position: shared.Vec2; child_flowed := false; child_size := child_layout.size; has_child_size := false
		if (is_hstack || is_vstack) &&
		   stack.fill { main_size := child_main_sizes[child_ordinal]; if is_hstack { child_size = {main_size, max(content.height - child_layout.margin.x - child_layout.margin.z, 0)} } else { child_size = {max(content.width - child_layout.margin.w - child_layout.margin.y, 0), main_size} }; has_child_size = true }
		if is_table {
			column := child_ordinal % table_columns
			if column == 0 && child_ordinal > 0 {
				table_y += table_row_height + table.row_gap
				table_row_height = 0
			}
			child_size = {
				max(table_column_width - child_layout.margin.w - child_layout.margin.y, 0),
				child_layout.size.y,
			}
			position = {
				content.x +
				f32(column) * (table_column_width + table.column_gap) +
				child_layout.margin.w,
				content.y + table_y + child_layout.margin.x,
			}
			table_row_height = max(
				table_row_height,
				child_layout.margin.x + child_size.y + child_layout.margin.z,
			)
			has_child_size = true
			child_flowed = true
		} else if is_hstack {position = {content.x + cursor + child_layout.margin.w, content.y + child_layout.margin.x}; cursor += child_layout.margin.w + child_size.x + child_layout.margin.y; if stack.draggable && child_ordinal < child_count - 1 && state.split_handle_count < MAX_NODES {handle_rect := Rect{content.x + cursor, content.y, max(gap, 8), content.height}; handle_rect.x += (gap - handle_rect.width) * 0.5; state.split_handles[state.split_handle_count] = {
					rect = handle_rect,
					before_node = child_index,
					after_node = children[child_ordinal + 1],
					horizontal = true,
					editor = node.origin == .Editor,
					min_size = stack.min_size,
				}; state.split_handle_count += 1}; cursor += gap; child_flowed = true} else if is_vstack {position = {content.x + child_layout.margin.w, content.y + cursor + child_layout.margin.x}; cursor += child_layout.margin.x + child_size.y + child_layout.margin.z; if stack.draggable && child_ordinal < child_count - 1 && state.split_handle_count < MAX_NODES {handle_rect := Rect{content.x, content.y + cursor, content.width, max(gap, 8)}; handle_rect.y += (gap - handle_rect.height) * 0.5; state.split_handles[state.split_handle_count] = {
					rect = handle_rect,
					before_node = child_index,
					after_node = children[child_ordinal + 1],
					horizontal = false,
					editor = node.origin == .Editor,
					min_size = stack.min_size,
				}; state.split_handle_count += 1}; cursor += gap; child_flowed = true}
		if is_scroll_area { position = {position.x, position.y - scroll_offset}; if !child_flowed { position = {node.rect.x + layout.padding.w + child_layout.position.x + child_layout.margin.w, content.y + child_layout.position.y + child_layout.margin.x - scroll_offset}; child_flowed = true } }
		err := layout_node(
			state,
			world,
			child_index,
			node.rect,
			position,
			child_flowed,
			child_size,
			has_child_size,
			child_clip,
			child_has_clip,
			depth + 1,
		)
		if err != "" { return err }
		unscrolled_bottom :=
			state.nodes[child_index].rect.y +
			state.nodes[child_index].rect.height +
			child_layout.margin.z
		if is_scroll_area { unscrolled_bottom += scroll_offset }
		content_bottom = max(content_bottom, unscrolled_bottom - content.y)
		child_ordinal += 1
	}
	if is_table &&
	   child_count > 0 { content_bottom = max(content_bottom, table_y + table_row_height) }
	if is_scroll_area { node.scroll_content_height = max(content.height, content_bottom); node.scroll_max = max(node.scroll_content_height - content.height, 0); node.scroll_target = clamp(node.scroll_target, 0, node.scroll_max); node.scroll_offset = clamp(node.scroll_offset, 0, node.scroll_max) }
	return ""
}

scroll_target_after_wheel :: proc(target, wheel_y, speed, max_scroll: f32) -> f32 {
	return clamp(target - wheel_y * speed, 0, max_scroll)
}

smooth_scroll_step :: proc(offset, target, smoothness, delta_seconds: f32) -> f32 {
	alpha := f32(1) - math.exp(-smoothness * clamp(delta_seconds, 0, f32(0.25)))
	next := offset + (target - offset) * alpha
	if math.abs(target - next) < 0.02 { return target }
	return next
}

update_split_interaction :: proc(state: ^State, pointer: Pointer_Input, editor: bool) -> bool {
	for &handle in state.split_handles[:state.split_handle_count] { if handle.editor == editor { handle.hovered = false; handle.active = false } }
	changed := false
	if !pointer.available {
		if state.active_split_handle >= 0 &&
		   state.active_split_editor == editor { state.active_split_handle = -1 }
		if editor { state.editor_split_previous_primary_down = false } else { state.split_previous_primary_down = false }
		return false
	}
	hit := -1
	for handle, index in state.split_handles[:state.split_handle_count] { if handle.editor == editor && rect_contains(handle.rect, pointer.position) { hit = index } }
	if hit >= 0 { state.split_handles[hit].hovered = true }
	previous_down := state.split_previous_primary_down
	if editor { previous_down = state.editor_split_previous_primary_down }
	just_pressed := pointer.primary_down && !previous_down
	if just_pressed && hit >= 0 {
		state.active_split_handle = hit
		state.active_split_editor = editor
		handle := state.split_handles[hit]
		parent := state.nodes[handle.before_node].split_parent
		for &node in state.nodes[:state.node_count] {
			if !node.split_weight_valid || node.split_parent != parent { continue }
			node.split_weight = node.rect.height
			if handle.horizontal { node.split_weight = node.rect.width }
		}
		state.split_drag_pointer =
			pointer.position.y; if handle.horizontal { state.split_drag_pointer = pointer.position.x }
	}
	if pointer.primary_down &&
	   state.active_split_editor == editor &&
	   state.active_split_handle >= 0 &&
	   state.active_split_handle < state.split_handle_count {
		handle := &state.split_handles[state.active_split_handle]; handle.active = true
		position := pointer.position.y; if handle.horizontal { position = pointer.position.x }
		delta := position - state.split_drag_pointer
		before := &state.nodes[handle.before_node]; after := &state.nodes[handle.after_node]
		before_size :=
			before.rect.height; after_size := after.rect.height; if handle.horizontal { before_size = before.rect.width; after_size = after.rect.width }
		min_size := max(handle.min_size, 1)
		applied := clamp(delta, -before_size + min_size, after_size - min_size)
		if math.abs(applied) >
		   0.0001 { before.split_weight = max(before_size + applied, min_size); after.split_weight = max(after_size - applied, min_size); state.split_drag_pointer += applied; changed = true }
	} else if !pointer.primary_down &&
	   state.active_split_editor == editor { state.active_split_handle = -1 }
	if editor { state.editor_split_previous_primary_down = pointer.primary_down } else { state.split_previous_primary_down = pointer.primary_down }
	return changed
}

append_split_handles :: proc(state: ^State, editor: bool) -> string {
	for handle in state.split_handles[:state.split_handle_count] {
		if handle.editor != editor { continue }
		if !handle.hovered && !handle.active { continue }
		color := shared.Vec4 {
			0.42,
			0.46,
			0.54,
			0.55,
		}; if handle.active { color = {0.12, 0.74, 0.62, 0.8} }
		rect := handle.rect
		if handle.horizontal { rect.x = rect.x + rect.width * 0.5 - 0.75; rect.width = 1.5 } else { rect.y = rect.y + rect.height * 0.5 - 0.75; rect.height = 1.5 }
		if err := append_paint(state, {kind = .Panel, rect = rect, color = color});
		   err != "" { return err }
	}
	return ""
}

update_scroll_areas :: proc(
	state: ^State,
	world: ^shared.World,
	pointer: Pointer_Input,
	delta_seconds: f32,
	editor: bool,
) -> bool {
	changed := false
	if pointer.available && pointer.wheel_y != 0 {
		hit := -1; highest_order := -1
		for node, index in state.nodes[:state.node_count] {
			if (node.origin == .Editor) != editor { continue }
			if node.scroll_area_index < 0 ||
			   node.scroll_area_index >= len(world.ui_scroll_areas) ||
			   node.scroll_max <= 0 { continue }
			if node_pointer_contains(node, pointer.position) &&
			   node.paint_order >= highest_order { hit = index; highest_order = node.paint_order }
		}
		if hit >=
		   0 { node := &state.nodes[hit]; component := world.ui_scroll_areas[node.scroll_area_index]; node.scroll_target = scroll_target_after_wheel(node.scroll_target, pointer.wheel_y, component.scroll_speed, node.scroll_max) }
	}
	for &node in state.nodes[:state.node_count] {
		if (node.origin == .Editor) != editor { continue }
		if node.scroll_area_index < 0 ||
		   node.scroll_area_index >= len(world.ui_scroll_areas) { continue }
		component := world.ui_scroll_areas[node.scroll_area_index]
		next := smooth_scroll_step(
			node.scroll_offset,
			node.scroll_target,
			component.smoothness,
			delta_seconds,
		)
		if math.abs(next - node.scroll_offset) >
		   0.0001 { node.scroll_offset = next; changed = true }
	}
	return changed
}

mark_interaction_chain :: proc(state: ^State, node_index: int, active: bool) {
	index := node_index
	for index >= 0 {
		if active { state.nodes[index].active = true } else { state.nodes[index].hovered = true }
		index = find_node_by_entity_index(state, state.nodes[index].parent_entity_index)
	}
}

update_interaction :: proc(
	state: ^State,
	pointer: Pointer_Input,
	editor: bool,
) -> (
	shared.Entity,
	bool,
) {
	for &node in state.nodes[:state.node_count] { if (node.origin == .Editor) == editor { node.hovered = false; node.active = false } }
	previous_down := state.previous_primary_down
	has_active := state.has_active_entity
	active_entity := state.active_entity
	if editor { previous_down = state.editor_previous_primary_down; has_active = state.editor_ui_has_active_entity; active_entity = state.editor_ui_active_entity }
	if !pointer.available {
		if editor { state.editor_ui_has_active_entity = false; state.editor_previous_primary_down = false } else { state.has_active_entity = false; state.previous_primary_down = false }
		return {}, false
	}
	hit := -1
	highest_order := -1
	for node, index in state.nodes[:state.node_count] {
		if (node.origin == .Editor) != editor { continue }
		if node_pointer_contains(node, pointer.position) &&
		   node.paint_order >= highest_order { hit = index; highest_order = node.paint_order }
	}
	if hit >= 0 { mark_interaction_chain(state, hit, false) }
	pressed, pressed_ok := shared.Entity{}, false
	if pointer.primary_down && !previous_down {
		has_active = hit >= 0
		if hit >=
		   0 { active_entity = state.nodes[hit].entity; pressed = active_entity; pressed_ok = true }
	}
	if pointer.primary_down && has_active {
		if active_index := find_node(state, active_entity);
		   active_index >=
		   0 { mark_interaction_chain(state, active_index, true) } else { has_active = false }
	} else if !pointer.primary_down { has_active = false }
	if editor { state.editor_ui_has_active_entity = has_active; state.editor_ui_active_entity = active_entity; state.editor_previous_primary_down = pointer.primary_down } else { state.has_active_entity = has_active; state.active_entity = active_entity; state.previous_primary_down = pointer.primary_down }
	return pressed, pressed_ok
}

node_pointer_contains :: proc(node: Node, point: shared.Vec2) -> bool {return(
		rect_contains(node.rect, point) &&
		(!node.has_clip || rect_contains(node.clip, point)) \
	)}
rect_intersection :: proc(a, b: Rect) -> Rect {x0 := max(a.x, b.x); y0 := max(a.y, b.y); x1 := min(
		a.x + a.width,
		b.x + b.width,
	)
	y1 := min(a.y + a.height, b.y + b.height)
	return{x0, y0, max(x1 - x0, 0), max(y1 - y0, 0)}}

paint_node :: proc(state: ^State, world: ^shared.World, node_index, depth: int) -> string {
	if depth > MAX_NODES { return "UI hierarchy contains a cycle" }
	node := &state.nodes[node_index]; layout := world.ui_layouts[node.layout_index]
	if node.has_clip {
		visible := rect_intersection(node.rect, node.clip)
		if visible.width <= 0 || visible.height <= 0 { return "" }
	}
	paint_start := state.paint_count
	background := layout.background
	if node.button_index >= 0 && node.button_index < len(world.ui_buttons) {
		button := world.ui_buttons[node.button_index]
		if node.active &&
		   button.active_background.w >
			   0 { background = button.active_background } else if node.hovered && button.hover_background.w > 0 { background = button.hover_background }
	}
	if background.w > 0 ||
	   layout.border_color.w > 0 &&
		   layout.border_width >
			   0 { if err := append_paint(state, {kind = .Panel, rect = node.rect, color = background, uv = {0, 0, 0, 0}, corner_radius = layout.corner_radius, border_color = layout.border_color, border_width = layout.border_width}); err != "" { return err } }
	if node.panel_index >= 0 && node.panel_index < len(world.ui_panels) {
		panel := world.ui_panels[node.panel_index]
		if panel.title != "" {
			title_height := min(max(panel.title_height, 0), node.rect.height)
			title_rect := Rect{node.rect.x, node.rect.y, node.rect.width, title_height}
			if panel.title_background.w > 0 {
				if err := append_paint(
					state,
					{
						kind = .Panel,
						rect = title_rect,
						color = panel.title_background,
						corner_radius = layout.corner_radius,
					},
				); err != "" { return err }
			}
			text_rect := Rect {
				title_rect.x + 10,
				title_rect.y + max((title_height - panel.title_size * 1.25) * 0.5, 0),
				max(title_rect.width - 20, 0),
				panel.title_size * 1.5,
			}
			if err := append_text(
				state,
				panel.title,
				panel.title_color,
				panel.title_size,
				text_rect,
				{},
			); err != "" { return err }
		}
	}
	if node.text_index >= 0 &&
	   node.text_index <
		   len(
			   world.ui_texts,
		   ) { text := world.ui_texts[node.text_index]; if err := append_text(state, text.text, text.color, text.size, node.rect, layout.padding); err != "" { return err } }
	if node.button_index >= 0 &&
	   node.button_index <
		   len(
			   world.ui_buttons,
		   ) { button := world.ui_buttons[node.button_index]; color := button.color; if node.active && button.active_color.w > 0 { color = button.active_color } else if node.hovered && button.hover_color.w > 0 { color = button.hover_color }; if err := append_centered_text(state, button.text, color, button.size, node.rect, layout.padding); err != "" { return err } }
	apply_paint_clip(state, paint_start, state.paint_count, node.clip, node.has_clip)
	for child_index in 0 ..< state.node_count { if state.nodes[child_index].parent_entity_index == int(node.entity.index) { if err := paint_node(state, world, child_index, depth + 1); err != "" { return err } } }
	if node.scroll_area_index >= 0 &&
	   node.scroll_area_index < len(world.ui_scroll_areas) &&
	   node.scroll_max > 0 {
		track := Rect {
			node.rect.x + node.rect.width - 7,
			node.rect.y + 5,
			3,
			max(node.rect.height - 10, 0),
		}
		thumb_height := max(
			track.height * track.height / max(node.scroll_content_height, track.height),
			18,
		)
		thumb_y :=
			track.y + (track.height - thumb_height) * node.scroll_offset / max(node.scroll_max, 1)
		start := state.paint_count
		if err := append_paint(
			state,
			{kind = .Panel, rect = track, color = {0.08, 0.09, 0.11, 0.78}, corner_radius = 1.5},
		); err != "" { return err }
		if err := append_paint(
			state,
			{
				kind = .Panel,
				rect = {track.x, thumb_y, track.width, thumb_height},
				color = {0.34, 0.37, 0.42, 0.92},
				corner_radius = 1.5,
			},
		); err != "" { return err }
		apply_paint_clip(state, start, state.paint_count, node.clip, node.has_clip)
	}
	return ""
}

apply_paint_clip :: proc(state: ^State, start, end: int, clip: Rect, has_clip: bool) {
	if !has_clip { return }
	for &command in state.paint[start:end] {
		command.clip = clip
		command.has_clip = true
	}
}

rect_contains :: proc(rect: Rect, point: shared.Vec2) -> bool {return(
		point.x >= rect.x &&
		point.y >= rect.y &&
		point.x < rect.x + rect.width &&
		point.y < rect.y + rect.height \
	)}

scale_paint_command :: proc(command: ^Paint_Command, scale: f32) {
	command.rect = {
		command.rect.x * scale,
		command.rect.y * scale,
		command.rect.width * scale,
		command.rect.height * scale,
	}
	command.corner_radius *= scale
	command.border_width *= scale
	command.line_start.x *=
		scale; command.line_start.y *= scale; command.line_end.x *= scale; command.line_end.y *= scale; command.line_thickness *= scale
	for &point in command.triangle { point.x *= scale; point.y *= scale }
	command.ring_center.x *=
		scale; command.ring_center.y *= scale; command.ring_axis_x.x *= scale; command.ring_axis_x.y *= scale; command.ring_axis_y.x *= scale; command.ring_axis_y.y *= scale; command.ring_thickness *= scale
	if command.has_clip { command.clip = {command.clip.x * scale, command.clip.y * scale, command.clip.width * scale, command.clip.height * scale} }
}

append_editor_gizmo :: proc(state: ^State) -> string {
	if !state.editor_gizmo_visible { return "" }
	scale := max(state.editor_pixel_density, 1)
	colors := [3]shared.Vec4{{0.95, 0.20, 0.24, 1}, {0.28, 0.88, 0.42, 1}, {0.24, 0.48, 1, 1}}
	labels := [3]string{"X", "Y", "Z"}
	if state.editor_gizmo_mode == .Rotate {
		for ring, index in state.editor_gizmo_ring_points {
			axis := Editor_Gizmo_Handle(
				index + 1,
			); active := state.editor_gizmo_hovered_handle == axis || state.editor_gizmo_active_handle == axis
			color :=
				colors[index]; if state.editor_gizmo_active_handle != .None && state.editor_gizmo_active_handle != axis { color.w = 0.30 }
			if active { color.x = min(color.x + 0.20, 1); color.y = min(color.y + 0.20, 1); color.z = min(color.z + 0.20, 1) }
			thickness := f32(1.35) * scale; if active { thickness = 2.75 * scale }
			p0, p1, p2, p3 :=
				ring[0], ring[len(ring) / 4], ring[len(ring) / 2], ring[len(ring) * 3 / 4]
			center := shared.Vec2 {
				(p0.x + p1.x + p2.x + p3.x) * 0.25,
				(p0.y + p1.y + p2.y + p3.y) * 0.25,
			}
			axis_x := shared.Vec2 {
				(p0.x - p2.x) * 0.5,
				(p0.y - p2.y) * 0.5,
			}; axis_y := shared.Vec2{(p1.x - p3.x) * 0.5, (p1.y - p3.y) * 0.5}
			length_x := math.sqrt(
				axis_x.x * axis_x.x + axis_x.y * axis_x.y,
			); length_y := math.sqrt(axis_y.x * axis_y.x + axis_y.y * axis_y.y)
			major, minor := axis_x, length_y
			major_length := length_x
			if length_y > length_x { major = axis_y; major_length = length_y; minor = length_x }
			projected_minor :=
				math.abs(axis_x.x * axis_y.y - axis_x.y * axis_y.x) / max(major_length, f32(0.001))
			if min(minor, projected_minor) < max(f32(1.5) * scale, major_length * 0.025) {
				if err := append_paint(
					state,
					{
						kind = .Line,
						color = color,
						line_start = {center.x - major.x, center.y - major.y},
						line_end = {center.x + major.x, center.y + major.y},
						line_thickness = thickness,
						corner_radius = thickness * 0.5,
					},
				); err != "" { return err }
			} else if err := append_paint(
				state,
				{
					kind = .Ring,
					color = color,
					ring_center = center,
					ring_axis_x = axis_x,
					ring_axis_y = axis_y,
					ring_thickness = thickness,
				},
			); err != "" { return err }
		}
		if err := append_gizmo_center(state, state.editor_gizmo_origin, scale);
		   err != "" { return err }
		return ""
	}
	plane_handles := [3]Editor_Gizmo_Handle{.XY, .XZ, .YZ}
	plane_colors := [3]shared.Vec4 {
		{0.82, 0.84, 0.18, 0.28},
		{0.82, 0.28, 0.68, 0.28},
		{0.18, 0.76, 0.78, 0.28},
	}
	for plane, index in state.editor_gizmo_plane_points {
		handle :=
			plane_handles[index]; active := state.editor_gizmo_hovered_handle == handle || state.editor_gizmo_active_handle == handle
		color := plane_colors[index]
		if state.editor_gizmo_active_handle != .None &&
		   state.editor_gizmo_active_handle != handle { color.w = 0.10 }
		if active { color.w = 0.64; color.x = min(color.x + 0.12, 1); color.y = min(color.y + 0.12, 1); color.z = min(color.z + 0.12, 1) }
		if err := append_paint(
			state,
			{kind = .Triangle, color = color, triangle = {plane[0], plane[1], plane[2]}},
		); err != "" { return err }
		if err := append_paint(
			state,
			{kind = .Triangle, color = color, triangle = {plane[0], plane[2], plane[3]}},
		); err != "" { return err }
	}
	for endpoint, index in state.editor_gizmo_endpoints {
		axis := Editor_Gizmo_Handle(
			index + 1,
		); active := editor_gizmo_handle_contains_axis(state.editor_gizmo_hovered_handle, axis) || editor_gizmo_handle_contains_axis(state.editor_gizmo_active_handle, axis)
		color :=
			colors[index]; if state.editor_gizmo_active_handle != .None && !editor_gizmo_handle_contains_axis(state.editor_gizmo_active_handle, axis) { color.w = 0.30 }
		if active { color.x = min(color.x + 0.20, 1); color.y = min(color.y + 0.20, 1); color.z = min(color.z + 0.20, 1) }
		delta := shared.Vec2 {
			endpoint.x - state.editor_gizmo_origin.x,
			endpoint.y - state.editor_gizmo_origin.y,
		}; length := math.sqrt(delta.x * delta.x + delta.y * delta.y)
		if length <= 0.001 { continue }
		direction := shared.Vec2 {
			delta.x / length,
			delta.y / length,
		}; perpendicular := shared.Vec2{-direction.y, direction.x}
		thickness := f32(3) * scale; if active { thickness = 5 * scale }
		terminal_back :=
			f32(13) * scale; if state.editor_gizmo_mode == .Scale { terminal_back = 6 * scale }
		shaft_end := shared.Vec2 {
			endpoint.x - direction.x * terminal_back,
			endpoint.y - direction.y * terminal_back,
		}
		if err := append_paint(
			state,
			{
				kind = .Line,
				color = color,
				line_start = state.editor_gizmo_origin,
				line_end = shaft_end,
				line_thickness = thickness,
				corner_radius = thickness * 0.5,
			},
		); err != "" { return err }
		if state.editor_gizmo_mode == .Translate {
			triangle := [3]shared.Vec2 {
				endpoint,
				{
					endpoint.x - direction.x * 15 * scale + perpendicular.x * 7 * scale,
					endpoint.y - direction.y * 15 * scale + perpendicular.y * 7 * scale,
				},
				{
					endpoint.x - direction.x * 15 * scale - perpendicular.x * 7 * scale,
					endpoint.y - direction.y * 15 * scale - perpendicular.y * 7 * scale,
				},
			}
			if err := append_paint(state, {kind = .Triangle, color = color, triangle = triangle});
			   err != "" { return err }
		} else {
			if err := append_paint(
				state,
				{
					kind = .Panel,
					rect = {
						endpoint.x - 6 * scale,
						endpoint.y - 6 * scale,
						12 * scale,
						12 * scale,
					},
					color = color,
					corner_radius = 1.5 * scale,
				},
			); err != "" { return err }
		}
		label_center := shared.Vec2 {
			endpoint.x + direction.x * 12 * scale,
			endpoint.y + direction.y * 12 * scale,
		}
		if err := append_centered_text(
			state,
			labels[index],
			color,
			9 * scale,
			{label_center.x - 7 * scale, label_center.y - 7 * scale, 14 * scale, 14 * scale},
			{},
		); err != "" { return err }
	}
	center_active :=
		state.editor_gizmo_hovered_handle == .Center || state.editor_gizmo_active_handle == .Center
	center_size := f32(11) * scale; if center_active { center_size = 15 * scale }
	center_color := shared.Vec4 {
		0.82,
		0.86,
		0.92,
		0.84,
	}; if center_active { center_color = {1, 1, 1, 1} } else if state.editor_gizmo_active_handle != .None { center_color.w = 0.30 }
	if err := append_paint(
		state,
		{
			kind = .Panel,
			rect = {
				state.editor_gizmo_origin.x - center_size * 0.5,
				state.editor_gizmo_origin.y - center_size * 0.5,
				center_size,
				center_size,
			},
			color = center_color,
			corner_radius = 2 * scale,
		},
	); err != "" { return err }
	return ""
}

editor_gizmo_handle_contains_axis :: proc(handle, axis: Editor_Gizmo_Handle) -> bool {
	if handle == axis || handle == .Center { return true }
	switch handle {case .XY:
			return axis == .X || axis == .Y; case .XZ:
			return axis == .X || axis == .Z; case .YZ:
			return axis == .Y || axis == .Z; case .None, .X, .Y, .Z, .Center:
			return false}
	return false
}

append_gizmo_center :: proc(state: ^State, origin: shared.Vec2, scale: f32) -> string {
	return append_paint(
		state,
		{
			kind = .Panel,
			rect = {origin.x - 2.5 * scale, origin.y - 2.5 * scale, 5 * scale, 5 * scale},
			color = {0.88, 0.92, 0.98, 0.92},
			corner_radius = 2.5 * scale,
		},
	)
}

entity_component_count :: proc(world: ^shared.World, entity_index: int) -> int {
	if entity_index < 0 || entity_index >= len(world.entities) {
		return 0
	}
	entity := world.entities[entity_index]
	count := 0
	indices := [14]int {
		entity.transform_index,
		entity.camera_index,
		entity.ambient_light_index,
		entity.directional_light_index,
		entity.point_light_index,
		entity.mesh_index,
		entity.geometry_index,
		entity.material_index,
		entity.render_instance_index,
		entity.ui_layout_index,
		entity.ui_scroll_area_index,
		entity.ui_panel_index,
		entity.ui_table_index,
		entity.ui_text_index,
	}
	for index in indices {
		if index >= 0 { count += 1 }
	}
	if entity.ui_hstack_index >= 0 { count += 1 }
	if entity.ui_vstack_index >= 0 { count += 1 }
	if entity.ui_button_index >= 0 { count += 1 }
	if entity.editor_transform_gizmo_index >= 0 &&
	   entity.editor_transform_gizmo_index < len(world.editor_transform_gizmos) &&
	   world.editor_transform_gizmos[entity.editor_transform_gizmo_index].entity_index ==
		   entity_index { count += 1 }
	for camera in world.editor_scene_cameras { if camera.entity_index == entity_index { count += 1; break } }
	if entity.has_shadow_caster { count += 1 }; if entity.has_shadow_receiver { count += 1 }
	for storage in world.custom_components { for component in storage.components { if component.entity_index == entity_index { count += 1; break } } }
	return count
}

format_vec2 :: proc(value: shared.Vec2) -> string {return fmt.tprintf(
		"(%.2f, %.2f)",
		value.x,
		value.y,
	)}
format_vec3 :: proc(value: shared.Vec3) -> string {return fmt.tprintf(
		"(%.2f, %.2f, %.2f)",
		value.x,
		value.y,
		value.z,
	)}
format_vec4 :: proc(value: shared.Vec4) -> string {return fmt.tprintf(
		"(%.2f, %.2f, %.2f, %.2f)",
		value.x,
		value.y,
		value.z,
		value.w,
	)}
format_handle :: proc(index, generation: u32) -> string {return fmt.tprintf(
		"#%d:%d",
		index,
		generation,
	)}

append_text :: proc(
	state: ^State,
	text: string,
	color: shared.Vec4,
	size: f32,
	rect: Rect,
	padding: shared.Vec4,
) -> string {
	x := rect.x + padding.w; baseline := rect.y + padding.x + FONT_ASCENDER * size
	return append_text_at(state, text, color, size, x, baseline, rect.x + padding.w)
}

append_text_clipped :: proc(
	state: ^State,
	text: string,
	color: shared.Vec4,
	size: f32,
	rect: Rect,
) -> string {
	x := rect.x; baseline := rect.y + FONT_ASCENDER * size
	for character in text {
		code := int(
			character,
		); if code < FONT_FIRST_CHAR || code >= FONT_FIRST_CHAR + FONT_CHAR_COUNT { code = int('?') }; glyph := state.font.glyphs[code - FONT_FIRST_CHAR]
		width :=
			(glyph.plane.z - glyph.plane.x) *
			size; height := (glyph.plane.w - glyph.plane.y) * size; glyph_x := x + glyph.plane.x * size
		if glyph_x + width > rect.x + rect.width { return "" }
		if width > 0 &&
		   height >
			   0 { if err := append_paint(state, {kind = .Glyph, rect = {glyph_x, baseline + glyph.plane.y * size, width, height}, color = color, uv = glyph.uv}); err != "" { return err } }
		x += glyph.advance * size
	}
	return ""
}

append_centered_text :: proc(
	state: ^State,
	text: string,
	color: shared.Vec4,
	size: f32,
	rect: Rect,
	padding: shared.Vec4,
) -> string {
	bounds, has_ink := measure_text_ink(state, text, size)
	if !has_ink { return "" }
	content := Rect {
		rect.x + padding.w,
		rect.y + padding.x,
		rect.width - padding.w - padding.y,
		rect.height - padding.x - padding.z,
	}
	x := content.x + (content.width - bounds.width) * 0.5 - bounds.x
	baseline := content.y + (content.height - bounds.height) * 0.5 - bounds.y
	return append_text_at(state, text, color, size, x, baseline, x)
}

append_text_at :: proc(
	state: ^State,
	text: string,
	color: shared.Vec4,
	size, x_start, baseline_start, line_start: f32,
) -> string {
	x := x_start; baseline := baseline_start
	for character in text {
		if character == '\n' { x = line_start; baseline += size; continue }
		code := int(
			character,
		); if code < FONT_FIRST_CHAR || code >= FONT_FIRST_CHAR + FONT_CHAR_COUNT { code = int('?') }
		glyph := state.font.glyphs[code - FONT_FIRST_CHAR]
		width :=
			(glyph.plane.z - glyph.plane.x) *
			size; height := (glyph.plane.w - glyph.plane.y) * size
		if width > 0 &&
		   height >
			   0 { if err := append_paint(state, {kind = .Glyph, rect = {x + glyph.plane.x * size, baseline + glyph.plane.y * size, width, height}, color = color, uv = glyph.uv}); err != "" { return err } }
		x += glyph.advance * size
	}
	return ""
}

measure_text_ink :: proc(state: ^State, text: string, size: f32) -> (Rect, bool) {
	x := f32(0); min_x, min_y, max_x, max_y := f32(0), f32(0), f32(0), f32(0); has_ink := false
	for character in text {
		if character == '\n' { break }
		code := int(
			character,
		); if code < FONT_FIRST_CHAR || code >= FONT_FIRST_CHAR + FONT_CHAR_COUNT { code = int('?') }
		glyph := state.font.glyphs[code - FONT_FIRST_CHAR]
		x0 :=
			x +
			glyph.plane.x *
				size; y0 := glyph.plane.y * size; x1 := x + glyph.plane.z * size; y1 := glyph.plane.w * size
		if x1 > x0 &&
		   y1 >
			   y0 { if !has_ink { min_x = x0; min_y = y0; max_x = x1; max_y = y1; has_ink = true } else { min_x = min(min_x, x0); min_y = min(min_y, y0); max_x = max(max_x, x1); max_y = max(max_y, y1) } }
		x += glyph.advance * size
	}
	return {min_x, min_y, max_x - min_x, max_y - min_y}, has_ink
}

append_paint :: proc(state: ^State, command: Paint_Command) -> string {if state.paint_count >=
	   MAX_PAINT_COMMANDS { return "too many UI paint commands" }
	state.paint[state.paint_count] = command
	state.paint_count += 1
	return ""}
