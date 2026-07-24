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

func register_cell(grid_pos: Vector2i, type_id: int, entity_node: Node2D = null):
	grid_data[grid_pos] = {
		"type": type_id,
		"node": entity_node
	}
	
		
func print_grid_data():
	# 方式一：最粗暴直接打印整個字典
	#print(grid_data)

	# 方式二：如果想排版好看點，一行行看清楚每個坐標的數據
	print("--- Grid Data ---")
	for pos in grid_data:
		print("坐標: ", pos, " | 數據: ", grid_data[pos])
		print("-----------------")
	
	
	
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
