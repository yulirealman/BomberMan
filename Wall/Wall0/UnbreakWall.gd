extends AnimatableBody2D


func _ready() -> void:

	GameManager.wall_dict[MyUtility.grid_pos(position,16)] = true



func _on_death() -> void:

	GameManager.wall_dict.erase(MyUtility.grid_pos(position,16))

	
