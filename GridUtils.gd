class_name GridUtils
extends RefCounted

# 这里可以统一定义项目的标准格子大小（如果你的游戏全图都是 32x32）
const DEFAULT_CELL_SIZE = 32

# 1. 逻辑坐标 -> 像素坐标 (居中)
static func cell_to_world(cell: Vector2i, cell_size: int = DEFAULT_CELL_SIZE) -> Vector2:
	return Vector2(cell) * cell_size + Vector2(cell_size, cell_size) * 0.5

# 2. 像素坐标 -> 逻辑坐标
static func world_to_cell(pos: Vector2, cell_size: int = DEFAULT_CELL_SIZE) -> Vector2i:
	return Vector2i(
		floor(pos.x / cell_size),
		floor(pos.y / cell_size)
	)

# 甚至可以加一个超级实用的复合函数：吸附到网格中心
static func snap_to_grid_center(pos: Vector2, cell_size: int = DEFAULT_CELL_SIZE) -> Vector2:
	var cell = world_to_cell(pos, cell_size)
	return cell_to_world(cell, cell_size)
