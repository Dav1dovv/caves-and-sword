# WeaponPassiveHandler.gd
# ─────────────────────────────────────────────────────────────────────────────
# Компонент-нода. Добавь её как дочернюю к Player.
# Имя ноды в сцене: WeaponPassiveHandler
#
# Отвечает за:
#   1. Пассивный свет оружия (PointLight2D добавляется/убирается динамически)
#   2. Пассивные эффекты на игрока (regen, speed_boost, и т.д.)
#   3. Накладывание on-hit эффектов на врагов (вызывается из player.gd)
#   4. Нанесение урона рывка врагам, оказавшимся на пути (вызывается из player.gd)
# ─────────────────────────────────────────────────────────────────────────────
extends Node
class_name WeaponPassiveHandler

# Ссылки — заполнятся в _ready через get_parent()
var _player:  Player       = null
var _hit_box              = null   # player_HitBox

# Текущее активное оружие (equip_data или null)
var _current_equip: equip_data = null

# Динамически создаваемый свет
var _light: PointLight2D = null

# Флаг активного пассивного эффекта (чтобы не добавлять дважды)
var _passive_effect_active: bool = false

# Накопитель для regen-тика (раз в секунду)
var _regen_tick: float = 0.0

const PASSIVE_TICK_INTERVAL := 1.0


func _ready() -> void:
	_player  = get_parent() as Player
	assert(_player != null, "WeaponPassiveHandler must be a child of Player")
	_hit_box = _player.hit_box


func _process(delta: float) -> void:
	var equip := _get_current_equip()

	# Если оружие сменилось — обновляем пассивы
	if equip != _current_equip:
		_on_equip_changed(_current_equip, equip)
		_current_equip = equip

	# Тик пассивных эффектов на игрока
	if _passive_effect_active and _current_equip:
		_tick_passive(delta)


# ─── Публичный API ────────────────────────────────────────────────────────────

## Вызывается из player.gd при попадании по врагу.
## target — нода врага (должна иметь метод apply_status_effect или take_damage)
func try_apply_on_hit_effect(target: Node) -> void:
	if not _current_equip:
		return
	var e := _current_equip
	if e.on_hit_effect == "none":
		return
	if randf() > e.on_hit_chance:
		return

	if e.on_hit_effect == "heal_on_hit":
		# Лечит игрока, а не врага
		var heal: float = e.on_hit_potency
		_player.Entity_stats.current_health = minf(
			_player.Entity_stats.current_health + heal,
			_player.Entity_stats.max_health
		)
		_player._on_health_changed(_player.Entity_stats.current_health)
		return

	# Передаём эффект врагу (если у него есть метод)
	if target.has_method("apply_status_effect"):
		target.apply_status_effect(e.on_hit_effect, e.on_hit_duration, e.on_hit_potency)


## Вызывается из player.gd на каждом шаге рывка.
## Возвращает список нод, которым нанесён урон (чтобы не бить дважды).
func apply_lunge_damage(already_hit: Array, lunge_damage: float) -> void:
	if not _hit_box:
		return
	# Проверяем перекрытия HitBox с врагами
	for area in _hit_box.get_overlapping_areas():
		var body: Node = area.get_parent()
		if body in already_hit:
			continue
		if area.is_in_group("Ennemy") or area.is_in_group("Harvestable"):
			if body.has_method("take_damage"):
				body.take_damage(lunge_damage, _player)
				try_apply_on_hit_effect(body)
				already_hit.append(body)


# ─── Внутренняя логика ────────────────────────────────────────────────────────

func _get_current_equip() -> equip_data:
	if not _hit_box:
		return null
	return _hit_box.equip as equip_data


func _on_equip_changed(old_equip: equip_data, new_equip: equip_data) -> void:
	# Убираем старые пассивы
	if old_equip:
		_remove_light()
		_remove_passive_player_effect(old_equip)

	# Применяем новые пассивы
	if new_equip:
		if new_equip.passive_emits_light:
			_create_light(new_equip)
		if new_equip.passive_player_effect != "none":
			_apply_passive_player_effect(new_equip)
			_passive_effect_active = true
		else:
			_passive_effect_active = false
	else:
		_passive_effect_active = false


func _create_light(e: equip_data) -> void:
	_remove_light()
	_light = PointLight2D.new()
	_light.texture = preload("uid://dsqxjnpk365qg")
	_light.color        = e.passive_light_color
	_light.texture_scale = e.passive_light_radius / 64.0  # нормализация под стандартный градиент
	_light.energy       = e.passive_light_energy
	_light.shadow_enabled = true
	# Лёгкое мерцание через AnimationPlayer можно добавить позже
	# Вешаем свет на руку игрока, чтобы он двигался вместе с ней
	_player.add_child(_light)
	_light.position = Vector2.ZERO


func _remove_light() -> void:
	if is_instance_valid(_light):
		_light.queue_free()
	_light = null


func _apply_passive_player_effect(e: equip_data) -> void:
	# Немедленное применение эффектов через систему статусов если есть
	if _player.has_method("apply_status_effect"):
		_player.apply_status_effect(e.passive_player_effect, INF, e.passive_player_potency)


func _remove_passive_player_effect(e: equip_data) -> void:
	_passive_effect_active = false
	if e.passive_player_effect == "none":
		return
	# Снимаем эффект
	if _player.has_method("remove_status_effect"):
		_player.remove_status_effect(e.passive_player_effect)
	# Сброс speed_boost вручную на случай если системы нет
	if e.passive_player_effect == "speed_boost":
		_player.Entity_stats.move_speed = maxf(
			_player.Entity_stats.move_speed - e.passive_player_potency, 1.0
		)


func _tick_passive(delta: float) -> void:
	var e := _current_equip
	_regen_tick += delta
	if _regen_tick < PASSIVE_TICK_INTERVAL:
		return
	_regen_tick = 0.0

	match e.passive_player_effect:
		"regen":
			var hp := _player.Entity_stats
			hp.current_health = minf(hp.current_health + e.passive_player_potency, hp.max_health)
			_player._on_health_changed(hp.current_health)
		"speed_boost":
			# Применяется один раз при экипировке, тик не нужен — уже обработано
			pass
		"poison", "burn":
			# Оружие-проклятие: тикает урон по игроку
			if _player.has_method("take_damage"):
				_player.take_damage(e.passive_player_potency, null)
