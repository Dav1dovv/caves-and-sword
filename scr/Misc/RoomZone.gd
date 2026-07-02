extends Area2D
class_name RoomZone

## Размер зоны задаётся формой коллизии (RectangleShape2D) дочернего
## CollisionShape2D — просто растяни прямоугольник в редакторе под нужный
## размер комнаты. Может быть как с экран, так и в несколько экранов.
##
## ВАЖНО: collision_layer/mask этой Area2D должны пересекаться со слоем игрока,
## иначе body_entered не сработает.

## Биом этой зоны. Пусто = не трогает GameManager.biome (обычная комната внутри
## одного биома). Задай, если в одной сцене несколько биомов (открытый мир,
## переход лес -> пустыня и т.п.) — при входе игрока GameManager.biome обновится.
@export_enum(" ", "Desert", "Forest", "Thundra", "Deep") var zone_biome: String = " "

## Уровень заражения именно этой зоны (0-3).
## -1 (по умолчанию) = зона не переопределяет заражение и использует общий
## GameManager.corruption_level текущей сцены — обычная незаражённая комната.
## Поставь 0-3 вручную, чтобы конкретная зона/комната была спокойнее или
## опаснее остальной локации (например "заражённое ядро" пещеры = 3,
## а стартовая площадка той же сцены = 0).
@export_range(-1, 3, 1) var zone_corruption_level: int = -1

@onready var _shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("RoomZones")
	monitoring = true
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		var cam := get_tree().get_first_node_in_group("MainCamera") as ZeldaCam
		if cam:
			cam.set_current_room(self)
		_update_gamemanager_biome()

## Сообщает GameManager, в каком биоме сейчас находится игрок, и меняет
## значение GameManager.biome на нужное, если оно отличается.
func _update_gamemanager_biome() -> void:
	if zone_biome.is_empty():
		return
	var gm := get_tree().get_first_node_in_group("World") as GameManager
	if gm and gm.biome != zone_biome:
		gm.set_biome(zone_biome)

## Возвращает заражение, которое реально нужно применять в этой зоне:
## свой собственный уровень, если он задан (>= 0), иначе — общий
## GameManager.corruption_level текущей сцены.
func get_effective_corruption(gm: GameManager) -> int:
	if zone_corruption_level < 0:
		return gm.corruption_level if gm else 0
	return zone_corruption_level


## Находит RoomZone (или наследника вроде SpawnZone), в границах которого
## находится point. Используется объектами вроде Harvestable, чтобы узнать
## "своё" локальное заражение независимо от того, где сейчас игрок/камера.
## Если зон несколько накладываются друг на друга — возвращается первая найденная.
static func find_zone_at(tree: SceneTree, point: Vector2) -> RoomZone:
	for zone in tree.get_nodes_in_group("RoomZones"):
		if zone is RoomZone and zone.get_bounds().has_point(point):
			return zone
	return null


## Возвращает границы зоны в глобальных координатах
func get_bounds() -> Rect2:
	var rect_shape := _shape.shape as RectangleShape2D
	if not rect_shape:
		push_warning("RoomZone: CollisionShape2D должен использовать RectangleShape2D")
		return Rect2(global_position, Vector2.ZERO)

	var size := rect_shape.size * _shape.global_scale
	var pos := _shape.global_position - size / 2.0
	return Rect2(pos, size)
