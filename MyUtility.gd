class_name MyUtility
extends Node


static func snap(pos: Vector2, size: int) -> Vector2:
	return Vector2(
		floor(pos.x / size) * size + size * 0.5,
		floor(pos.y / size) * size + size * 0.5
	)


static func grid_pos(pos: Vector2, size: int) -> Vector2i:
	return Vector2i(
		floor(pos.x / size),
		floor(pos.y / size)
	)
