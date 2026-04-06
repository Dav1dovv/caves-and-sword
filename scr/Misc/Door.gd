@tool
extends Area2D
class_name Door

enum data_action {load_data,save_data}

@export var go_to_scene : String
@export var new_player_position : Vector2 = Vector2.ZERO
@export var action : data_action = data_action.save_data

func _init() -> void:
	set_collision_layer_value(1,false)
	set_collision_layer_value(11,true)
	set_collision_mask_value(1,false)
	set_collision_mask_value(3,true)
	connect("body_entered",_move)

func _move(body):
	if action == data_action.save_data:
		Global.save_last_data()
		Global.scene_manager.change_scene(go_to_scene,true, new_player_position)
	elif action == data_action.load_data:
		Global.scene_manager.change_scene(Global.last_location,true, Global.last_position)
	else:
		print("trave")
		Global.scene_manager.change_scene(go_to_scene,true, new_player_position)
	#Global.scene_manager.change_scene(go_to_scene,true, new_player_position)
	
