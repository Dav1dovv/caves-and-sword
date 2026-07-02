extends Blaze_camera
class_name ZeldaCam

@onready var screen_size : Vector2 = get_viewport_rect().size
@export var player : Player

## Длительность плавного перехода между комнатами (в секундах)
@export var transition_duration : float = 0.5
## Кривая анимации перехода
@export var transition_trans : Tween.TransitionType = Tween.TRANS_SINE
@export var transition_ease : Tween.EaseType = Tween.EASE_OUT
## Скорость "довода" камеры за игроком внутри зоны, которая больше экрана
@export var follow_speed : float = 6.0

## true пока камера едет к новой комнате — игрока в это время лучше не двигать,
## иначе он обгонит камеру и вылезет за край экрана
var is_transitioning : bool = false

signal transition_started
signal transition_finished

var current_tween : Tween
var target_position : Vector2

## Текущая RoomZone (если null — работает старая grid-логика на весь экран)
var current_room : RoomZone = null


func _ready() -> void:
	add_to_group("MainCamera")

	# Инициализируем стартовую позицию без анимации
	target_position = calculate_screen_position()
	global_position = target_position


func _process(delta: float) -> void:
	if is_transitioning:
		return

	if current_room != null:
		# Внутри зоны больше экрана — плавно следуем за игроком в её границах,
		# без дискретных переходов
		var new_target := calculate_room_target()
		target_position = new_target
		global_position = global_position.lerp(new_target, follow_speed * delta)
		return

	# Фоллбек — старая grid-логика для сцен без RoomZone (комната = размер экрана)
	var new_target := calculate_screen_position()
	if new_target != target_position:
		target_position = new_target
		start_transition()


## Вызывается из RoomZone, когда игрок входит в новую зону
func set_current_room(zone: RoomZone) -> void:
	if zone == current_room:
		return
	current_room = zone
	target_position = calculate_room_target()
	start_transition()


func calculate_screen_position() -> Vector2:
	var player_pos = player.global_position
	var x = floor(player_pos.x / screen_size.x) * screen_size.x + screen_size.x / 2
	var y = floor(player_pos.y / screen_size.y) * screen_size.y + screen_size.y / 2
	return Vector2(x, y)


## Цель камеры внутри текущей RoomZone: центрируется по оси, если зона
## по этой оси меньше или равна экрану, иначе — следует за игроком с клампом
## по границам зоны (чтобы не показывать пустоту за пределами комнаты)
func calculate_room_target() -> Vector2:
	if current_room == null:
		return calculate_screen_position()

	var bounds := current_room.get_bounds()
	var half := screen_size / 2.0
	var target := Vector2.ZERO

	if bounds.size.x <= screen_size.x:
		target.x = bounds.position.x + bounds.size.x / 2.0
	else:
		target.x = clamp(player.global_position.x, bounds.position.x + half.x, bounds.position.x + bounds.size.x - half.x)

	if bounds.size.y <= screen_size.y:
		target.y = bounds.position.y + bounds.size.y / 2.0
	else:
		target.y = clamp(player.global_position.y, bounds.position.y + half.y, bounds.position.y + bounds.size.y - half.y)

	return target


func start_transition() -> void:
	if current_tween:
		current_tween.kill()

	is_transitioning = true
	transition_started.emit()

	current_tween = create_tween()
	current_tween.set_trans(transition_trans)
	current_tween.set_ease(transition_ease)
	current_tween.tween_property(self, "global_position", target_position, transition_duration)
	current_tween.finished.connect(_on_transition_finished)


func _on_transition_finished() -> void:
	is_transitioning = false
	transition_finished.emit()
