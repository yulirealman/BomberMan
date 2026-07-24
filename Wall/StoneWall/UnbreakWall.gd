class_name Wall
extends AnimatableBody2D


func _ready() -> void:

	#GameManager.wall_dict[GridManager.world_to_cell(position,GridManager.GRID_SIZE)] = true
	GridManager.register_object(GridManager.world_to_cell(position, GridManager.GRID_SIZE),self)


func destory() -> void:
	pass
	
