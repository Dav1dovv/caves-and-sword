extends Node

# ═══════════════════════════════════════════════════════════════════════════
#  CreatureSpawnManager — реестр таблиц спавна + пул существ + бюджет спавна
# ───────────────────────────────────────────────────────────────────────────
#  Project Settings → Autoload → добавить этот скрипт под именем
#  "CreatureSpawnManager" (имя автозагрузки = имя, которым вызываешь его
#  из SpawnZone.gd, ничего менять там не нужно если назовёшь так же)
#
#  Оптимизация в трёх местах:
#   1. Пул объектов — despawn не делает queue_free(), а прячет существо
#      и переиспользует при следующем спавне (без instantiate() в рантайме)
#   2. Спавн растянут по кадрам (SPAWNS_PER_FRAME) — вход в большую зону
#      не спавнит 8 мобов в один кадр и не роняет FPS
#   3. sleep()/wake() — существа вне активной зоны полностью останавливают
#      _process/_physics_process, а не просто становятся невидимыми
# ═══════════════════════════════════════════════════════════════════════════

@export var spawn_tables_dir := "res://data/spawn_tables/"

const SPAWNS_PER_FRAME := 1

var _tables: Dictionary = {}          # biome (String) -> BiomeSpawnTable
var _pool: Dictionary = {}            # scene.resource_path (String) -> Array[Node2D]
var _spawn_queue: Array = []          # [{scene: PackedScene, pos: Vector2}]


func _ready() -> void:
	_load_tables()


func _load_tables() -> void:
	var dir := DirAccess.open(spawn_tables_dir)
	if not dir:
		push_warning("[CreatureSpawnManager] Папка не найдена: %s" % spawn_tables_dir)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var res := load(spawn_tables_dir + file_name) as BiomeSpawnTable
			if res:
				_tables[res.biome] = res
		file_name = dir.get_next()
	dir.list_dir_end()

	print("[CreatureSpawnManager] Загружено таблиц спавна: %d" % _tables.size())


func get_table(biome: String) -> BiomeSpawnTable:
	return _tables.get(biome, null)


func _process(_delta: float) -> void:
	var n := 0
	while not _spawn_queue.is_empty() and n < SPAWNS_PER_FRAME:
		var req: Dictionary = _spawn_queue.pop_front()
		var creature := _do_spawn(req["scene"], req["pos"])
		var callback: Callable = req.get("callback", Callable())
		if callback.is_valid():
			callback.call(creature)
		n += 1


## Ставит существо в очередь на спавн (растянуто по кадрам).
## Существо появляется не мгновенно, а через 1-N кадров — поэтому эта функция
## ничего не возвращает. Если вызывающему коду нужна ссылка на реально
## созданное существо (напр. чтобы потом положить его в свой список для
## sleep()/wake()), передай on_spawned: он вызовется с готовым Node2D, когда
## существо действительно заспавнится.
## Если нужен мгновенный результат синхронно — используй spawn_immediate().
func request_spawn(scene: PackedScene, pos: Vector2, on_spawned: Callable = Callable()) -> void:
	_spawn_queue.append({"scene": scene, "pos": pos, "callback": on_spawned})


func spawn_immediate(scene: PackedScene, pos: Vector2) -> Node2D:
	return _do_spawn(scene, pos)


func _do_spawn(scene: PackedScene, pos: Vector2) -> Node2D:
	var key := scene.resource_path
	var creature: Node2D

	if _pool.has(key) and not _pool[key].is_empty():
		creature = _pool[key].pop_back()
		creature.global_position = pos
		if creature.has_method("reset_state"):
			creature.reset_state()
	else:
		creature = scene.instantiate()
		get_tree().current_scene.add_child(creature)
		creature.global_position = pos

	creature.add_to_group("Ennemy")
	wake(creature)
	return creature


## Существо активно: AI, физика, видимость — всё работает
func wake(creature: Node2D) -> void:
	if not is_instance_valid(creature):
		return
	creature.visible = true
	creature.set_physics_process(true)
	creature.set_process(true)
	if creature.has_method("wake"):
		creature.wake()


## Существо "заморожено": не двигается, не думает, не рисуется — но и не
## удаляется, что дешевле повторного instantiate() при возврате игрока
func sleep(creature: Node2D) -> void:
	if not is_instance_valid(creature):
		return
	creature.visible = false
	creature.set_physics_process(false)
	creature.set_process(false)
	if creature.has_method("sleep"):
		creature.sleep()


## Полностью убрать существо (напр. при смерти) — уходит в пул, а не в queue_free()
func despawn(creature: Node2D) -> void:
	if not is_instance_valid(creature):
		return

	var key := creature.scene_file_path
	creature.remove_from_group("Ennemy")
	sleep(creature)

	if key == "":
		creature.queue_free()
		return

	if not _pool.has(key):
		_pool[key] = []
	_pool[key].append(creature)
