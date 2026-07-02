extends RapierArea2D
class_name Harvestable

signal collected

var is_corrupted : bool = false
var gm

@onready var Dropper_component = $droper
@export_range(2,999,1) var durability : float = 6
@export_range(0,10) var harvest_tool_lvl : int = 1
@export var VFX_component : VFX
@export var corrupted_texture : Texture2D

# ─── CurseObject ────────────────────────────────────────────────────────────
## Сцена CurseObject — создаётся когда объект добывают киркой ниже нужного тира
@export var curse_object_scene : PackedScene

## Сколько заражения получает игрок за КАЖДЫЙ удар по заражённому объекту
## Финальное значение умножается на armor_curse_multiplier из брони/амулетов
@export_range(0.0, 20.0, 0.5) var infection_per_hit : float = 2.0
# ────────────────────────────────────────────────────────────────────────────

var player
var tween: Tween
var _last_tool_lvl: int = 999  # запоминаем последний использованный tier

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
	gm = get_tree().get_first_node_in_group("World")

	var sprite = $Sprite2D
	if sprite and sprite.material is ShaderMaterial:
		_shader_material = sprite.material
		_shader_material.set_shader_parameter("wind_offset", global_position.x)
	
	#region CORRUPTION
	var scene_data: SceneData = Global.scene_manager.get_current_scene_data()
	var location_name: String = ""
	if scene_data != null and not scene_data.biome.is_empty():
		location_name = scene_data.biome
	elif not gm.biome.is_empty():
		location_name = gm.biome

	if location_name.is_empty() or not Global.corruption.has(location_name):
		is_corrupted = false
		return
	var corruption_value: float = 0.0
	if Global.corruption.has(location_name):
		corruption_value = Global.corruption[location_name]

	# Заражение берём из зоны, в которой физически стоит этот объект (если она
	# есть и задаёт свой уровень), а не из общего заражения всей сцены —
	# так один и тот же биом может иметь спокойные и сильно заражённые комнаты.
	var zone := RoomZone.find_zone_at(get_tree(), global_position)
	var effective_corruption_level: int = zone.get_effective_corruption(gm) if zone else gm.corruption_level

	var chance: float = (corruption_value / 100.0) * (effective_corruption_level / 3.0)
	is_corrupted = randf() < chance
	
	if is_corrupted:
		if corrupted_texture:
			$Sprite2D.texture = corrupted_texture
		else:
			modulate = Color(0.733, 0.325, 0.745, 1.0)
		$PointLight2D.visible = true
		$"Corruption Effect".emitting = true
		durability += 20
	else: 
		$PointLight2D.queue_free()
		$"Corruption Effect".queue_free()
	#endregion

func _physics_process(_delta: float) -> void:
	update_transparency()


func Harvest(hit_strenght : float, tool_lvl : int, is_weapon : bool) -> void:
	if is_weapon:
		return

	# Запоминаем тир для spawn CurseObject при разрушении
	_last_tool_lvl = tool_lvl

	# ── Визуальный фидбэк ────────────────────────────────────────────────────
	if VFX_component != null:
		VFX_component._hit_vfx($Sprite2D)
		await VFX_component.vfx_finished
	# ─────────────────────────────────────────────────────────────────────────

	# ── Заражение игрока при каждом ударе по corrupted объекту ───────────────
	if is_corrupted and player and player.has_method("curse"):
		var mult: float = _get_armor_curse_multiplier()
		player.curse(infection_per_hit * mult)
	# ─────────────────────────────────────────────────────────────────────────

	# ── Уменьшение прочности (ВСЕГДА, не только при наличии VFX) ────────────
	durability -= hit_strenght
	# ─────────────────────────────────────────────────────────────────────────

	if durability <= 0:
		_on_destroyed(tool_lvl)


func _on_destroyed(tool_lvl: int) -> void:
	# Дроп ресурсов
	if Dropper_component != null:
		Dropper_component.max_drop += scale.x
		Dropper_component._drop_items()

	# Регистрация сбора в мире
	if gm and gm.has_method("register_harvested"):
		var loc_key := get_tree().current_scene.scene_file_path
		gm.register_harvested(loc_key, global_position, is_corrupted)

	# ── Спавн CurseObject если тир кирки ниже требуемого ────────────────────
	#if tool_lvl < harvest_tool_lvl and curse_object_scene != null:
	if is_corrupted:
		_spawn_curse_object(harvest_tool_lvl - tool_lvl)
	# ─────────────────────────────────────────────────────────────────────────

	emit_signal("collected")
	queue_free()


func _spawn_curse_object(tier_diff: int) -> void:
	## Сила проклятия растёт с разницей тиров:
	##   tier_diff 1 → infection_damage 8
	##   tier_diff 2 → infection_damage 16
	##   tier_diff 3 → infection_damage 24
	var curse = curse_object_scene.instantiate()
	curse.global_position = global_position
	curse.infection_damage = tier_diff * 8.0

	# Отдаём в сцену (не в себя — мы сами queue_free)
	get_tree().current_scene.add_child(curse)


## Возвращает множитель заражения в зависимости от брони/амулетов игрока.
## 1.0 = без защиты, 0.0 = полный иммунитет.
## TODO: подключить к системе брони когда она будет реализована.
func _get_armor_curse_multiplier() -> float:
	# Пример: если у игрока есть метод get_curse_resistance — используем его
	if player.has_method("get_curse_resistance"):
		return 1.0 - clamp(player.get_curse_resistance(), 0.0, 1.0)
	return 1.0


#region Background transparency
func update_transparency() -> void:
	if _shader_material == null:
		return
	if player == null:
		_tween_fade(1.0)
		return

	var distance = global_position.distance_to(player.global_position)
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
	var current_alpha: float = _shader_material.get_shader_parameter("fade_alpha")
	tween.tween_method(
		func(v: float): _shader_material.set_shader_parameter("fade_alpha", v),
		current_alpha,
		target_alpha,
		fade_duration
	)
#endregion
