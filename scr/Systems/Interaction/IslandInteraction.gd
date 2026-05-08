extends Area2D
class_name IslandInteraction

@export var location_ID : String
@export var Show_Hint : Label

func _interact():
	Global.scene_manager.change_scene(location_ID,true,Vector2.ZERO)

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("RMB"):
		_interact()

func _on_body_entered(body: Node2D) -> void:
	print("body entered")
	Show_Hint.visible = true
	Show_Hint.text = location_ID
