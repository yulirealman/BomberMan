extends Node

# 儲存危險熱圖： { Vector2i: int }
# 如果格子值 > 0，代表該處有火，AI 應該避開
var _danger_map: Dictionary = {}

func _ready() -> void:
	GridManager.object_registered.connect(_on_object_registered)
	GridManager.object_unregistered.connect(_on_object_unregistered)

func _on_object_registered(pos: Vector2i, obj: Node2D) -> void:
	if obj is Bomb:
		# Godot 4 的 call_deferred 正确传参方式
		_process_bomb_grids.call_deferred(obj, 1)

# 注意这里补上了 obj 参数
func _on_object_unregistered(pos: Vector2i, obj: Node2D) -> void:
	if obj is Bomb:
		_process_bomb_grids.call_deferred(obj, -1)

# 统一处理的函数接收 delta（1 或 -1）
func _process_bomb_grids(obj: Bomb, delta: int) -> void:
	var grids = obj.get_explosion_grids()
	_update_danger_zone(grids, delta)

# 核心邏輯：計算十字形危險區
func _update_danger_zone(explosion_grids: Array[Vector2i], delta: int) -> void:
	
	for explosion_grid in explosion_grids:
		_add_danger(explosion_grid, delta)

	print_danger_map()

func _add_danger(explosion_grid: Vector2i, delta: int)  -> void:	
	print(explosion_grid)
# 1. 获取当前值（如果不存在则默认为 0），然后加上 delta
	var current_danger = _danger_map.get(explosion_grid, 0) + delta
	
	# 2. 如果计算后的危险值大于 0，则更新字典
	if current_danger > 0:
		_danger_map[explosion_grid] = current_danger
	else:
		# 3. 如果危险值归零或以下，直接从字典中移除，保持干净
		_danger_map.erase(explosion_grid)


func _is_wall(pos: Vector2i) -> bool:
	var obj = GridManager.get_object_at(pos)
	return obj is Wall




func print_danger_map() -> void:
	var width := 12
	var height := 10

	print("=== Danger Map ===")

	for y in range(height):
		var row := ""
		for x in range(width):
			var pos := Vector2i(x, y)
			var danger = _danger_map.get(pos, 0)
			
			if danger == 0:
				row += ". " # 安全點用點表示
			else:
				row += str(danger) + " " # 危險點顯示數值

		print(row)

	print("==================")

# 確保這兩個函數是公開的 (沒有加底線)
func get_danger_score(pos: Vector2i) -> int:
	
	return _danger_map.get(pos, 0)

func is_cell_safe(pos: Vector2i) -> bool:
	return _danger_map.get(pos, 0) == 0


# 在 DangerMap.gd 中修改
# ==========================================
# 🛑 【核心修正】找尋安全點時過濾障礙物
# ==========================================
func find_nearest_safe_spot(current_pos: Vector2i) -> Vector2i:
	var queue: Array[Vector2i] = [current_pos]
	var visited: Dictionary = {current_pos: true}
	
	while queue.size() > 0:
		var pos = queue.pop_front()
		
		if is_cell_safe(pos) and pos != current_pos:
			return pos
		
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor = pos + dir
			if not visited.has(neighbor):
				if neighbor.x >= 0 and neighbor.x < 12 and neighbor.y >= 0 and neighbor.y < 10:
					# 【修正】必須確認該格子不是牆壁或箱子！
					var obj = GridManager.get_object_at(neighbor)
					if not (obj is Wall or obj is Box):
						visited[neighbor] = true
						queue.push_back(neighbor)
	
	return current_pos
