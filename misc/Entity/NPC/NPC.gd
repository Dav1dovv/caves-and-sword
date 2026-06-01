extends Creature
class_name NPC

enum actor_types {Simple,Swordsman,Trade}

@onready var interaction: interaction_area = $interaction_area

@export var actor : actor_types = actor_types.Simple 
var inventory

func _ready() -> void:
	super._ready()
	inventory = get_tree().get_first_node_in_group("Inventory")
	interaction.interact = Callable(self, "Interact")

func Interact():
	match actor:
		actor_types.Swordsman:
			inventory.call_craft()
		actor_types.Simple:
			Dialogic.start("Dialog1",self)
