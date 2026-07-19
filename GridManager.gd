
extends Node

# 用來記錄網格坐標與物件的對應，例如 { Vector2i(1, 2):  reference }
var _grid_objects: Dictionary = {}
const GRID_SIZE = 32

func has_bomb_at(grid_pos: Vector2i) -> bool:
	return _grid_objects.has(grid_pos) and _grid_objects[grid_pos] is Bomb

func register_object(grid_pos: Vector2i, obj: Node2D) -> void:

	_grid_objects[grid_pos] = obj


func unregister_object(grid_pos: Vector2i) -> void:

	_grid_objects.erase(grid_pos)


func get_object_at(grid_pos: Vector2i) -> Node2D:
	return _grid_objects.get(grid_pos)

static func world_to_cell_center(pos: Vector2, cell_size: int) -> Vector2:
	return Vector2(
		floor(pos.x / cell_size) * cell_size + cell_size * 0.5,
		floor(pos.y / cell_size) * cell_size + cell_size * 0.5
	)


static func world_to_cell(pos: Vector2, cell_size: int) -> Vector2i:
	return Vector2i(
		floor(pos.x / cell_size),
		floor(pos.y / cell_size)
	)




func print_grid() -> void:
	var width := 12
	var height := 10

	print("=== Grid ===")

	for y in range(height):
		var row := ""

		for x in range(width):
			var pos := Vector2i(x, y)

			if not _grid_objects.has(pos):
				row += "0 "
				continue

			var obj = _grid_objects[pos]

			if obj is Wall:
				row += "W "
			elif obj is Box:
				row += "B "
			elif obj is Player:
				row += "P "
			elif obj is Bomb:
				row +="X "

		print(row)

	print("============")


func _process(_delta: float) -> void:
	# 按下键盘上的 F9 键，打印一次当前网格状态
	if Input.is_action_just_pressed("Print"): # 可以在输入映射里配个专属按键
		print_grid()
