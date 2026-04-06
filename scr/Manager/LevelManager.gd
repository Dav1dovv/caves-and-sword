extends Node
class_name SceneManager

# ═══════════════════════════════════════════════════════════════════════════════
#  SceneManager — менеджер переходов между сценами
# ───────────────────────────────────────────────────────────────────────────────
#  Возможности:
#   • Переход с fade-анимацией и загрузочным сообщением
#   • Именованные точки спавна внутри сцены
#   • Точная установка позиции игрока ПОСЛЕ загрузки (без таймеров наугад)
#   • Опциональное сохранение перед переходом
#   • Команды консоли: tp_scene, list_scenes
#   • Сигналы для подписки других систем (музыка, UI и т.д.)
# ═══════════════════════════════════════════════════════════════════════════════

# ── Сигналы ───────────────────────────────────────────────────────────────────
## Выстреливает перед сменой сцены (можно подписать MusicManager, UI и т.д.)
signal scene_change_started(scene_key: String)
## Выстреливает когда новая сцена полностью готова и игрок размещён
signal scene_change_finished(scene_key: String)

# ── Константы ─────────────────────────────────────────────────────────────────
const MAIN_MENU := "res://Assets/Scenes/Menu/main_menu.tscn"

# ── Экспорты ──────────────────────────────────────────────────────────────────

## Словарь сцен: ключ → путь к .tscn файлу
@export var scenes: Dictionary = {
	"Test_Scene" : "res://Assets/Locations/WorlRoot.tscn",
	"World"      : "res://Assets/Scenes/Playable/world_root.tscn",
	"oktavia"    : "res://Assets/Scenes/Playable/Planets/Oktavia.tscn",
}

## Сообщения на экране загрузки
@export var loading_messages: Array[String] = [
	"Mineral warriors is dangerous",
	"Tree's is the best helpful instrument",
	"Forest's not so dangerous than tundra or desert",
]

## Длительность fade-анимации затемнения (сек)
@export_range(0.2, 3.0, 0.05) var fade_in_duration:  float = 0.6

## Длительность fade-анимации появления (сек)
@export_range(0.2, 3.0, 0.05) var fade_out_duration: float = 0.8

## Минимальное время показа экрана загрузки (сек) — чтобы не мелькало
@export_range(0.0, 3.0, 0.1) var min_loading_time: float = 1.0

# ── Ноды ──────────────────────────────────────────────────────────────────────
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var message_label:    Label           = $CanvasLayer/ColorRect/Message

# ── Внутреннее состояние ──────────────────────────────────────────────────────
var _is_transitioning: bool = false


# ═══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	_register_commands()


func _register_commands() -> void:
	if not %DeveloperConsole:
		return
	var c := %DeveloperConsole
	c.register_command("tp_scene",    _cmd_change_scene, "Перейти в сцену: tp_scene [ключ] [x y]")
	c.register_command("list_scenes", _cmd_list_scenes,  "Показать все доступные сцены")


# ═══════════════════════════════════════════════════════════════════════════════
#  ПУБЛИЧНЫЙ API
# ═══════════════════════════════════════════════════════════════════════════════

## Основной переход между сценами.
##
## [param scene_key]       — ключ из словаря [member scenes]
## [param can_save]        — сохранить игру перед переходом
## [param spawn]           — куда поставить игрока после загрузки:
##                           • Vector2          → конкретная позиция
##                           • String           → имя ноды SpawnPoint в новой сцене
##                           • Vector2.ZERO     → не двигать (позиция по умолчанию)
func change_scene(scene_key: String, can_save: bool = false, spawn = Vector2.ZERO) -> void:
	if _is_transitioning:
		push_warning("SceneManager: переход уже идёт, запрос проигнорирован.")
		return
	if not scenes.has(scene_key):
		push_error("SceneManager: неизвестная сцена '%s'. Доступные: %s" % [scene_key, str(scenes.keys())])
		return

	_is_transitioning = true
	emit_signal("scene_change_started", scene_key)

	# ── Сохранение ────────────────────────────────────────────────────────────
	if can_save:
		get_parent().save()

	# ── Обновляем текущую локацию в Global ────────────────────────────────────
	get_parent().current_location = scene_key

	# ── Уведомляем подписчиков (музыка, UI) ───────────────────────────────────
	get_tree().call_group("MusicManager", "on_scene_changed", scene_key)
	Cursor.detection_mode(true)

	# ── Fade IN (затемнение) ───────────────────────────────────────────────────
	_update_message()
	animation_player.play("Fade_In")
	await animation_player.animation_finished

	# Минимальное время показа экрана загрузки
	var load_start := Time.get_ticks_msec()

	# ── Смена сцены ───────────────────────────────────────────────────────────
	get_tree().change_scene_to_file(scenes[scene_key])

	# Ждём один физический кадр — сцена гарантированно создана
	await get_tree().physics_frame

	# Добиваем минимальное время загрузки если нужно
	var elapsed := (Time.get_ticks_msec() - load_start) / 1000.0
	if elapsed < min_loading_time:
		await get_tree().create_timer(min_loading_time - elapsed).timeout

	# ── Позиционируем игрока ──────────────────────────────────────────────────
	_place_player(spawn)

	# ── Fade OUT (появление) ──────────────────────────────────────────────────
	animation_player.play("Fade_out")
	await animation_player.animation_finished

	Cursor.detection_mode(false)
	_is_transitioning = false
	emit_signal("scene_change_finished", scene_key)


## Переход в главное меню с автосохранением.
func change_to_main_menu() -> void:
	if _is_transitioning:
		return

	_is_transitioning = true
	_update_message()
	Cursor.detection_mode(true)
	get_tree().call_group("Save", "save_game")

	animation_player.play("Fade_In")
	await animation_player.animation_finished

	get_tree().change_scene_to_file(MAIN_MENU)
	await get_tree().physics_frame

	animation_player.play("Fade_out")
	await animation_player.animation_finished

	Cursor.detection_mode(false)
	_is_transitioning = false


## Простой fade без смены сцены (например, для cutscene или телепорта внутри сцены).
func fade(update_msg: bool = true) -> void:
	if update_msg:
		_update_message()
	animation_player.play("Fade_In")
	await animation_player.animation_finished
	animation_player.play("Fade_out")
	await animation_player.animation_finished


## Телепортирует игрока внутри текущей сцены без перехода.
## [param spawn] — Vector2 или String (имя SpawnPoint-ноды).
func teleport_player(spawn) -> void:
	_place_player(spawn)


## Возвращает true если переход сейчас в процессе.
func is_busy() -> bool:
	return _is_transitioning


## Добавить новую сцену в словарь во время игры (например, из мода).
func register_scene(key: String, path: String) -> void:
	scenes[key] = path


# ═══════════════════════════════════════════════════════════════════════════════
#  ВНУТРЕННИЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════════

# Ставит игрока на позицию после загрузки сцены.
# spawn: Vector2 → абсолютная позиция
#        String  → ищет ноду с таким именем в группе "SpawnPoint"
#        Vector2.ZERO → ничего не делать
func _place_player(spawn) -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return

	if spawn is String and spawn != "":
		# Ищем именованную точку спавна
		var point := _find_spawn_point(spawn)
		if point:
			player.global_position = point.global_position
		else:
			push_warning("SceneManager: SpawnPoint '%s' не найден в сцене." % spawn)

	elif spawn is Vector2 and spawn != Vector2.ZERO:
		player.global_position = spawn


# Ищет SpawnPoint по имени ноды среди нод в группе "SpawnPoint".
func _find_spawn_point(point_name: String) -> Node2D:
	for node in get_tree().get_nodes_in_group("SpawnPoint"):
		if node.name == point_name:
			return node as Node2D
	return null


func _update_message() -> void:
	if loading_messages.is_empty():
		return
	message_label.text = loading_messages.pick_random()


# ═══════════════════════════════════════════════════════════════════════════════
#  КОМАНДЫ КОНСОЛИ
# ═══════════════════════════════════════════════════════════════════════════════

# tp_scene World          → переход в World, игрок на дефолтной позиции
# tp_scene World 100 200  → переход в World, игрок на (100, 200)
# tp_scene World entrance → переход в World, игрок на SpawnPoint "entrance"
func _cmd_change_scene(args: Array) -> String:
	if args.is_empty():
		return "Usage: tp_scene [key] [x y | spawn_name]"

	var key: String = args[0]
	if not scenes.has(key):
		return "Неизвестная сцена '%s'. Доступные: %s" % [key, str(scenes.keys())]

	var spawn = Vector2.ZERO

	if args.size() == 3 and args[1].is_valid_float() and args[2].is_valid_float():
		spawn = Vector2(args[1].to_float(), args[2].to_float())
	elif args.size() == 2:
		spawn = args[1]  # имя SpawnPoint

	change_scene(key, false, spawn)
	return "Переход в '%s'..." % key


func _cmd_list_scenes(args: Array) -> String:
	if scenes.is_empty():
		return "Нет зарегистрированных сцен."
	var lines := ["Доступные сцены:"]
	for key in scenes:
		lines.append("  • %s → %s" % [key, scenes[key]])
	return "\n".join(lines)
