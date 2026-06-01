extends Creature
class_name Trader

@export var merchant : TraderData
@onready var interaction: interaction_area = $interaction_area

func _ready() -> void:
	super._ready()
	interaction.interact = Callable(self, "open")

func open():
	#Global.inventory.Trade(merchant)
	pass
