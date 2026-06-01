# ArmorSlot.gd
# Путь: res://scr/Systems/Inventory/ArmorSlot.gd
extends TextureButton
class_name ArmorSlot

## Какой тип брони принимает этот слот (0=HEAD 1=CHEST 2=LEGS 3=BOOTS)
@export var slot_type: int = ArmorData.SlotType.CHEST

@export var empty_texture: Texture2D
@export var active_texture: Texture2D

@onready var icon_rect: TextureRect      = $Icon
@onready var dur_bar: TextureProgressBar = $DurabilityBar

var equipped_item: ArmorData = null
var inventory: Inventory = null

signal armor_equipped(armor: ArmorData)
signal armor_unequipped(armor: ArmorData)

func _ready() -> void:
	_update_ui()
	pressed.connect(_on_pressed)

# ─── Публичный API ───────────────────────────────────────────────

func try_equip(armor: ArmorData) -> bool:
	if armor == null:
		return false
	if armor.slot != slot_type:
		return false

	# Если уже есть броня — сначала возвращаем в инвентарь
	var old := equipped_item
	if old:
		if inventory:
			if not inventory.can_add_item(old):
				push_warning("ArmorSlot: no space to unequip %s" % old.item_name)
				return false
			equipped_item = null
			emit_signal("armor_unequipped", old)
			inventory.add_item(old)
		else:
			equipped_item = null
			emit_signal("armor_unequipped", old)

	equipped_item = armor
	_update_ui()
	emit_signal("armor_equipped", armor)
	return true

func unequip() -> void:
	if not equipped_item:
		return
	if inventory and not inventory.can_add_item(equipped_item):
		push_warning("ArmorSlot: no space to unequip %s" % equipped_item.item_name)
		return
	var old := equipped_item
	equipped_item = null
	_update_ui()
	emit_signal("armor_unequipped", old)
	if inventory:
		inventory.add_item(old)

func get_defense() -> int:
	return equipped_item.defense if equipped_item else 0

# ─── UI ──────────────────────────────────────────────────────────

func _update_ui() -> void:
	if equipped_item:
		if icon_rect:
			icon_rect.texture = equipped_item.icon
		if active_texture:
			texture_normal = active_texture
		_update_durability_bar()
	else:
		if icon_rect:
			icon_rect.texture = empty_texture
		if dur_bar:
			dur_bar.visible = false

func _update_durability_bar() -> void:
	if not dur_bar or not equipped_item:
		return
	var cur  = float(equipped_item.get_durability())
	var maxd = float(equipped_item.max_durability)
	dur_bar.min_value = 0.0
	dur_bar.max_value = maxd
	dur_bar.value     = cur
	dur_bar.visible   = true
	var ratio = cur / maxd if maxd > 0 else 0.0
	if   ratio > 0.6: dur_bar.tint_progress = Color(0.2, 0.85, 0.2)
	elif ratio > 0.3: dur_bar.tint_progress = Color(0.95, 0.75, 0.1)
	else:             dur_bar.tint_progress = Color(0.9, 0.15, 0.15)

# ─── Клик — снять броню ──────────────────────────────────────────

func _on_pressed() -> void:
	if equipped_item:
		unequip()

# ─── Drag & Drop ─────────────────────────────────────────────────

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.has("item"):
		var itm = data["item"]
		return itm is ArmorData and itm.slot == slot_type
	return false

func _drop_data(_pos: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var armor := data.get("item") as ArmorData
	if not armor:
		return

	var src: InventorySlotData = data.get("source_slot", null)

	# Если слот уже занят — сначала надо вернуть старую броню в инвентарь.
	# try_equip сам это делает, но нам нужно убедиться, что place есть.
	if equipped_item and inventory and not inventory.can_add_item(equipped_item):
		push_warning("ArmorSlot: inventory full, cannot swap armor")
		return

	# Очищаем исходный слот
	if src:
		src.item    = null
		src.amount  = 0
		src.slot_node.item    = null
		src.slot_node.ammount = 0
		src.slot_node.update_ui()

	var ok := try_equip(armor)
	if not ok:
		# Возвращаем предмет в исходный слот, если надеть не удалось
		if src:
			src.item    = armor
			src.amount  = 1
			src.slot_node.item    = armor
			src.slot_node.ammount = 1
			src.slot_node.update_ui()
		return

	if inventory:
		inventory.emit_signal("inventory_changed")
