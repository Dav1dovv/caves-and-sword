extends UniversalAI
class_name Bee

var is_attacked : bool = false

func _ready() -> void:
	super._ready()

func _on_touch_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		_is_touching_player = true
		is_attacked = true
		$Skin/Sprite/Sting.visible = false
		$DeathTimer.start()
		_touch_timer = config.touch_damage_interval  # Первый тик сразу


func _on_touch_body_exited(body: Node) -> void:
	if body.is_in_group("Player"):
		_is_touching_player = false
		_touch_timer = 0.0


func _on_death_timer_timeout() -> void:
	die()
