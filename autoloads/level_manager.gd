class_name LevelManager
extends Node

static var instance: LevelManager
@export var levels: Array[PackedScene]
var current_level_index: int

func _enter_tree() -> void:
	instance = self

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
