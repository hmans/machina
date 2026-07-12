package ui

import ecs "../ecs"
import shared "../shared"
import "core:testing"

@(test)
test_reconcile_tracks_ui_entity_appearance_and_disappearance :: proc(t:^testing.T) {
	scene:=shared.Scene{}
	defer delete(scene.entities)
	append(&scene.entities,
		shared.Scene_Entity{name="Root",has_ui_layout=true,ui_layout={size={300,160},padding=10,background={0.1,0.2,0.3,1},direction=.Column}},
		shared.Scene_Entity{name="Label",has_ui_layout=true,ui_layout={parent="Root",size={200,40}},has_ui_text=true,ui_text={text="HELLO",color={1,1,1,1},size=16}},
	)
	world:=ecs.build_world(&scene);defer ecs.destroy_world(&world)
	state:=new(State);defer free(state);testing.expect(t,init(state)=="");defer destroy(state)
	testing.expect(t,reconcile(state,&world,1280,720)=="")
	testing.expect(t,state.node_count==2)
	testing.expect(t,state.paint_count>2)
	world.entities[1].alive=false
	testing.expect(t,reconcile(state,&world,1280,720)=="")
	testing.expect(t,state.node_count==1)
	testing.expect(t,state.paint_count==1)
}

@(test)
test_column_layout_places_children_in_order :: proc(t:^testing.T) {
	scene:=shared.Scene{};defer delete(scene.entities)
	append(&scene.entities,
		shared.Scene_Entity{name="Root",has_ui_layout=true,ui_layout={size={300,200},padding=10,gap=5,direction=.Column}},
		shared.Scene_Entity{name="A",has_ui_layout=true,ui_layout={parent="Root",size={100,20}}},
		shared.Scene_Entity{name="B",has_ui_layout=true,ui_layout={parent="Root",size={100,30}}},
	)
	world:=ecs.build_world(&scene);defer ecs.destroy_world(&world)
	state:=new(State);defer free(state);testing.expect(t,init(state)=="");defer destroy(state)
	testing.expect(t,reconcile(state,&world,1280,720)=="")
	a:=find_node_by_entity_index(state,1);b:=find_node_by_entity_index(state,2)
	testing.expect(t,a>=0&&b>=0)
	if a>=0&&b>=0 {testing.expect(t,state.nodes[a].rect.y==10);testing.expect(t,state.nodes[b].rect.y==35)}
}
