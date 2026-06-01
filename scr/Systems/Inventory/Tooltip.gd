extends Control

@onready var name_label: Label = $Panel/VBoxContainer/Name
@onready var desc_label: Label = $Panel/VBoxContainer/Description

func _ready() -> void:
	hide_tooltip()

## Показать тултип с данными предмета
func set_data(item: ItemData) -> void:
	if not item:
		hide_tooltip()
		return
	name_label.text = item.item_name
	# Формируем текст описания
	var lines: PackedStringArray = []
	if item.description and item.description != "":
		lines.append(item.description)
	if item is equip_data:
		lines.append("Урон: %d" % item.Damage)
		lines.append("Уровень: %d" % item.lvl)
		if item.max_durability > 0:
			lines.append("Прочность: %d / %d" % [item.get_durability(), item.max_durability])
	elif item is ArmorData:
		lines.append("Защита: %d" % item.defense)
		if item.max_durability > 0:
			lines.append("Прочность: %d / %d" % [item.get_durability(), item.max_durability])
	elif item is FoodData:
		lines.append("Восстанавливает: %d" % item.hunger_restore)
	desc_label.text = "\n".join(lines)

func show_tooltip(item_name: String, text: String) -> void:
	name_label.text = item_name
	desc_label.text = text
	visible = true

func hide_tooltip() -> void:
	visible = false

func clear() -> void:
	hide_tooltip()
