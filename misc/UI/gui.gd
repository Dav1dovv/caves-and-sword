extends CanvasLayer

var player

@onready var hud: Control = $HUD
@onready var inventory: Inventory = $HUD/Inventory
@onready var death_menu: Control = $DeathMenu
@onready var pause_menu: Control = $PauseMenu


func _on_inventory_visibility_changed() -> void:
	pass # Replace with function body.

func _on_pause_menu_visibility_changed() -> void:
	inventory.hide()

func call_death():
	death_menu.death()
	hud.visible = false
	pause_menu.visible = false
	pause_menu.anotherMenuOpened = true
