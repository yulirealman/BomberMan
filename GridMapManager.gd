# grid_map_manager.gd
class_name GridMapManager
extends Node

# 用來記錄網格坐標與物件的對應，例如 { Vector2i(1, 2): "Bomb" }
var _grid_objects: Dictionary = {}

func has_bomb_at(grid_pos: Vector2i) -> bool:
	return _grid_objects.has(grid_pos) and _grid_objects[grid_pos] == "Bomb"

func register_object(grid_pos: Vector2i, type: String) -> void:
	_grid_objects[grid_pos] = type

func unregister_object(grid_pos: Vector2i) -> void:
	_grid_objects.erase(grid_pos)
