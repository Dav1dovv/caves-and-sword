extends Area2D
class_name Harvestable

signal collected


@onready var Dropper_component = $droper
@export_range(2,999,1) var durability : float = 6
@export_range(0,10) var harvest_tool_lvl : int = 1
@export var VFX_component : VFX

var player
var tween: Tween

# Ссылка на ShaderMaterial спрайта
var _shader_material: ShaderMaterial

@export_group("Transparency Settings")
@export_range(0.0, 200.0, 10.0) var max_distance : float = 20
@export_range(0.0, 1.0, 0.01) var fade_alpha : float = 0.50
@export_range(0.1, 1.0, 0.05) var fade_duration : float = 0.2

func _init() -> void:
	set_collision_layer_value(2,true)
	set_collision_layer_value(5,true)
	set_collision_mask_value(1,false)
	set_collision_mask_value(4,true)
	set_collision_mask_value(9,true)

func _ready() -> void:
	add_to_group("Harvestable")
	if not is_inside_tree():
		await tree_entered
	
	Dropper_component = $droper
	player = get_tree().get_first_node_in_group("Player")
	
	# Получаем ShaderMaterial со спрайта
	var sprite = $Sprite2D
	#print("[Tree] sprite found: ", sprite)
	#if sprite:
		#print("[Tree] material: ", sprite.material)
		#print("[Tree] material type: ", type_string(typeof(sprite.material)))
	if sprite and sprite.material is ShaderMaterial:
		_shader_material = sprite.material
		#print("[Tree] shader_material assigned OK")
		_shader_material.set_shader_parameter("wind_offset", global_position.x)
	#else:
		#print("[Tree] ERROR: ShaderMaterial not found on Sprite2D")

func _physics_process(_delta: float) -> void:
	update_transparency()

func update_transparency() -> void:
	if _shader_material == null:
		return
	
	if player == null:
		_tween_fade(1.0)
		return

	var distance = global_position.distance_to(player.global_position)
	# Игрок "сзади" дерева = его Y меньше (выше на экране в top-down)
	var player_behind = player.global_position.y < global_position.y

	if player_behind and distance < max_distance:
		_tween_fade(fade_alpha)
	else:
		_tween_fade(1.0)

func _tween_fade(target_alpha: float) -> void:
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Анимируем параметр шейдера напрямую
	var current_alpha: float = _shader_material.get_shader_parameter("fade_alpha")
	tween.tween_method(
		func(v: float): _shader_material.set_shader_parameter("fade_alpha", v),
		current_alpha,
		target_alpha,
		fade_duration
	)


func Harvest(hit_strenght : float, tool_lvl:int,is_weapon:bool):
	if is_weapon:
		return
	if tool_lvl >= harvest_tool_lvl:
		if VFX_component != null: 
			VFX_component._hit_vfx($Sprite2D)
			await VFX_component.vfx_finished
		
		durability -= hit_strenght
	else:
		Global.hint(self,"you need lvl " + str(harvest_tool_lvl) + " pickaxe")
		
	if durability <= 0:
		if VFX_component: await VFX_component.vfx_finished
		if $Destroy: $Destroy.play()
		if Dropper_component != null:
			Dropper_component.max_drop += scale.x
			Dropper_component._drop_items()
		var gm := get_tree().get_first_node_in_group("World")
		if gm and gm.has_method("register_harvested"):
			var loc_key := get_tree().current_scene.scene_file_path
			gm.register_harvested(loc_key, global_position)
		emit_signal("collected")
		queue_free()
