extends Node


#region game data
var player_name: String = "Deffault"
var player_skin_index: int = 0
var player_skin_head_index: int = 0
var game_difficult : int = 0
var current_save_slot: String = ""
var current_location : String = "Land"

var last_location : String
var last_position : Vector2
#endregion

#region UI controll
var is_opened_menu : bool = false

var hotbar
var inventory : Inventory
const MOUSE_Arrow = preload("res://Assets/Textures/UI/Cursors/Cursor1.png")
const HINT = preload("uid://wyeldfaexejh")
#endregion


@onready var developer_console: CanvasLayer = %DeveloperConsole
@onready var scene_manager: SceneManager = $SceneManager
@onready var BGM: AudioStreamPlayer = $AudioStreamPlayer
@onready var setting_manager: SettingManager = $SettingManager


func _init() -> void:
	#Input.set_custom_mouse_cursor(MOUSE_Interact,Input.CURSOR_CAN_DROP,Vector2(11,13))
	Input.set_custom_mouse_cursor(MOUSE_Arrow,Input.CURSOR_ARROW,Vector2(0,0))
	
func _ready() -> void:
	# Register singleton
	if not Engine.has_singleton("Global"):
		Engine.register_singleton("Global", self)
	
	# Create Saves directory if it doesn't exist
	var dir = DirAccess.open("user://")
	if dir:
		dir.make_dir("Saves")
		
	

# Set character name and create folder
func set_character_name(new_name: String):
	if new_name.strip_edges().is_empty():
		print("Error: Character name cannot be empty")
		return
	player_name = new_name.strip_edges()
	print("Global character name set to: %s" % player_name)
	
	# Create character folder
	var save_dir = "user://Saves/%s" % player_name.replace(" ", "_")
	var dir = DirAccess.open("user://Saves")
	if dir:
		dir.make_dir(save_dir)

func pickup_item(item_data: ItemData, amount: int = 1) -> void:
	
	if not hotbar or not inventory:
		print("Ошибка: Hotbar или Inventory не найдены!")
		return
	
	# 1. Сначала пытаемся положить в ХОТБАР
	var added_to_hotbar = _try_add_to_container(hotbar, item_data, amount)
	
	if added_to_hotbar:
		print("Предмет добавлен в хотбар: ", item_data.item_name)
		return
	
	# 2. Если хотбар полон — кладём в основной инвентарь
	var added_to_inventory = _try_add_to_container(inventory, item_data, amount)
	
	if added_to_inventory:
		print("Предмет добавлен в инвентарь: ", item_data.item_name)
	else:
		print("Инвентарь и хотбар полные! Предмет потерян: ", item_data.item_name)
		# Можно показать уведомление игроку

func _try_add_to_container(container, item_data: ItemData, amount: int) -> bool:
	if not container or not container.has_method("add_item"):
		return false
	
	# Попробуем добавить — возвращает true, если хоть что-то добавилось
	return container.add_item(item_data, amount)

func add_initial_items():
	pickup_item(preload("uid://ch2r3sdjgisqa").duplicate(), 1)
	pickup_item(preload("uid://prg8cq5chkl2").duplicate(), 1)
	pass

# Get full path to save file
func get_save_path() -> String:
	if player_name.is_empty():
		print("Error: Character name is empty")
		return ""
	return "user://Saves/%s/save.json" % player_name.replace(" ", "_")

func save_last_data():
	last_location = current_location
	last_position = get_tree().get_first_node_in_group("Player").global_position

func delete_game_data():
	_delete_dir_recursive("user://Saves")
	print("Save data deleted")

func _delete_dir_recursive(path: String):
	if not DirAccess.dir_exists_absolute(path):
		return
	
	var dir = DirAccess.open(path)
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name != "." and file_name != "..":
			var full_path = path + "/" + file_name
			if dir.current_is_dir():
				_delete_dir_recursive(full_path)  # рекурсия для подпапок
			else:
				dir.remove(full_path)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	DirAccess.remove_absolute(path)  # удаляем уже пустую папку
	

func hint(object : Node2D,message : String):
		print("hint working")
		var hint_instant = HINT.instantiate()
		hint_instant.text = message
		hint_instant.position = object.global_position
		hint_instant.position.y -= 10
		object.call_deferred("add_child",hint_instant)

func save():
	get_tree().call_group("Save","save_game")

func _switch_bgm(clip_name: StringName) -> void:
	if not BGM.playing:
		BGM.play()
	var playback := BGM.get_stream_playback() as AudioStreamPlaybackInteractive
	if playback:
		playback.switch_to_clip_by_name(clip_name)


func _on_scene_manager_scene_change_finished(scene_key: String) -> void:
	var stream := BGM.get_stream() as AudioStreamInteractive
	if not stream:
		return
	
	match scene_key:
		"Main Menu":
			_switch_bgm(&"Main Menu")
		"Land":
			_switch_bgm(&"Land " + str(randi_range(1, 2)))
		"Forest":
			_switch_bgm(&"Forest " + str(randi_range(1, 2)))
		"Village":
			_switch_bgm(&"Village " + str(randi_range(1, 2)))
		"Cave":
			_switch_bgm(&"Cave " + str(randi_range(1, 2)))
		"Deep Cave":
			_switch_bgm(&"Deep Cave " + str(randi_range(1, 2)))
		"Thundra":
			_switch_bgm(&"Thundra 1")
		"Desert":
			_switch_bgm(&"Desert 1")
		"Corrupted":
			_switch_bgm(&"Corrupted " + str(randi_range(1, 2)))
		"Beach":
			_switch_bgm(&"Beach " + str(randi_range(1, 2)))
		"Lullaby":
			_switch_bgm(&"Lullaby " + str(randi_range(1, 2)))
		"World":
			_switch_bgm(&"World")

func play_game_over():
	_switch_bgm(&"Game Over " + str(randi_range(1, 3)))
