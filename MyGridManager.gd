class_name MyGridManager
extends Node2D

var columns: int
var rows: int
var cell_size: Vector2

# 核心字典，用 Vector2i(x,y) 作为 Key，进行 O(1) 的极速查找
var grid_data: Dictionary = {} 

func _init(c: int, r: int, size: Vector2):
	columns = c
	rows = r
	cell_size = size
	Events.grid_entity_destroyed.connect(_on_entity_destroyed)

func register_cell(grid_pos: Vector2i, type_id: int, entity_node: Node2D = null):
	grid_data[grid_pos] = {
		"type": type_id,
		"node": entity_node
	}

	
		
func print_grid_visual():
	print("--- 遊戲網格視覺圖 ---")
	
	# 利用類別中已經定義好的 rows 和 columns 進行雙層迴圈
	for y in range(rows):
		var row_str = ""
		for x in range(columns):
			var pos = Vector2i(x, y)
			
			# 檢查該坐標是否有註冊數據
			if grid_data.has(pos):
				var type_id = grid_data[pos]["type"]
				# 偶數印出 b，奇數印出 w
				if type_id == 0:
					row_str+=" 0 "
				elif type_id % 2 == 0:
					row_str += " b "
				else:
					row_str += " w "
			else:
				# 若該格子未註冊，顯示空白佔位符
				row_str += " . "
				
		print(row_str)
		
	print("----------------------")
	
	
# 检查某个格子是否可以被穿透 (空地)
func is_cell_empty(grid_pos: Vector2i) -> bool:
	if not grid_data.has(grid_pos):
		return true # 超出边界或者没注册的格子，默认当空地（或者你也可以按需改成 false）
	
	# 如果 type 是 0 (假设 0 是你的地板/空地 ID)，那就是空的
	return grid_data[grid_pos]["type"] == 0


# 获取某个格子的完整数据字典
func get_cell_data(grid_pos: Vector2i) -> Dictionary:
	return grid_data.get(grid_pos, {})


# 清理某个格子的实体占位（比如炸弹爆了，箱子碎了）
func remove_entity(grid_pos: Vector2i) -> void:
	if grid_data.has(grid_pos):
		grid_data[grid_pos]["node"] = null
		grid_data[grid_pos]["type"] = 0 # 恢复成空地
	
	print_grid_visual()

# 接收来自 EventBus 的广播
func _on_entity_destroyed(grid_pos: Vector2i, entity_id: int, entity_type: String) -> void:
	print("Going to destroy ", entity_id,entity_type)
	# 1. 安全校验：这个坐标是否在我们的字典里？
	if grid_data.has(grid_pos):
		
		# 2. 商业级防呆验证（极其重要）
		# 我们必须确认：当前网格里记录的“路障类型”，确实是刚才被炸毁的这个 entity_id！
		# 这样如果一个怪物 (Enemy, ID:998) 死在这里，它不会误把这格的数据清空。
		if grid_data[grid_pos]["type"] == entity_id:
			
			# 清除引用，防止内存泄漏或野指针
			grid_data[grid_pos]["node"] = null
			
			# 恢复成绝对的空地 (0)
			grid_data[grid_pos]["type"] = 0 
			
			# (如果这里接了 A*，可以在这里立刻更新 A* 权重，让怪物马上知道路通了)
			# astar.set_point_weight_scale(astar_id, 1.0)
			
	# 如果你在 Debug 阶段，可以保留打印。正式上线时建议注释掉，节省性能。
	print_grid_visual()
	
## 供你的 A* 算法和炸弹光波调用的核心 API
#func get_cell_type(grid_pos: Vector2i) -> int:
	#if grid_data.has(grid_pos):
		#return grid_data[grid_pos]["type"]
	#return -1 # 越界或未知
#
## 寻路检测：是不是空地
#func is_walkable(grid_pos: Vector2i) -> bool:
	#var type = get_cell_type(grid_pos)
	#return type == 0
