# ArmorData.gd
# Путь: res://scr/Resources/ItemData/ArmorData.gd
@icon("res://common/icons/helpcon2.png")
extends ItemData
class_name ArmorData

enum SlotType { HEAD, CHEST, LEGS, BOOTS }

@export_category("Armor")

## В какой слот экипируется
@export var slot: SlotType = SlotType.CHEST

## Защита — снижает входящий урон
@export_range(0, 100, 1) var defense: int = 5

## Максимальная прочность
@export_range(10, 500, 1) var max_durability: int = 100

## Бонус к максимальному HP
@export_range(0, 200, 1) var bonus_hp: int = 0

## Множитель скорости (1.0 = без изменений)
@export_range(0.5, 1.5, 0.01) var speed_multiplier: float = 1.0

# Runtime — не экспортируем
var durability: int = -1

signal durability_changed(current: int, maximum: int)
signal armor_broken

func get_durability() -> int:
	if durability < 0:
		durability = max_durability
	return durability

func reduce_durability(amount: int = 1) -> void:
	if durability < 0:
		durability = max_durability
	durability = max(0, durability - amount)
	emit_signal("durability_changed", durability, max_durability)
	if durability <= 0:
		emit_signal("armor_broken")

func is_broken() -> bool:
	return get_durability() <= 0

func repair(amount: int = -1) -> void:
	if amount < 0:
		durability = max_durability
	else:
		durability = min(max_durability, get_durability() + amount)
	emit_signal("durability_changed", durability, max_durability)

func get_durability_ratio() -> float:
	return float(get_durability()) / float(max_durability)

func get_slot_name() -> String:
	match slot:
		SlotType.HEAD:  return "Голова"
		SlotType.CHEST: return "Грудь"
		SlotType.LEGS:  return "Ноги"
		SlotType.BOOTS: return "Ботинки"
	return "?"

func apply_quality_multiplier(q: int) -> void:
	super.apply_quality_multiplier(q)
	defense        = int(defense * (1.0 + q * 0.4))
	max_durability += q * 20
	bonus_hp       += q * 10
	if durability > 0:
		durability = min(durability, max_durability)
