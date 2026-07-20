class_name AStarPathfinder
extends RefCounted

# 使用 A* 算法寻找一条避开危险区域的路径
# current_pos: 敌人当前格子坐标
# target_pos: 敌人目标格子坐标（比如玩家位置）
# map_width / map_height: 地图边界
@warning_ignore("shadowed_variable")
static func find_safe_path(current_pos: Vector2i, target_pos: Vector2i, map_width: int = 12, map_height: int = 10) -> Array[Vector2i]:
	# 如果起点本身就是终点，直接返回
	if current_pos == target_pos:
		return [current_pos]

	# 优先队列/开放列表 (Open Set)，存入字典以快速查重：{ pos: { "g": 成本, "f": 总代价, "parent": 父节点 } }
	var open_set: Dictionary = {}
	# 关闭列表 (Closed Set)，记录已经访问过的格子
	var closed_set: Dictionary = {}

	# 初始化起点
	open_set[current_pos] = {
		"g": 0.0,
		"f": _get_heuristic(current_pos, target_pos),
		"parent": Vector2i(-1, -1)
	}

	while open_set.size() > 0:
		# 1. 在 open_set 中找到 f 值最小的节点
		var current_cell = _get_lowest_f_node(open_set)
		
		# 如果到达终点，回溯并返回完整路径
		if current_cell == target_pos:
			return _reconstruct_path(open_set, current_cell)

		var current_data = open_set[current_cell]
		open_set.erase(current_cell)
		closed_set[current_cell] = current_data

		# 2. 遍历上下左右四个邻居格子
		var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
		for dir in directions:
			var neighbor = current_cell + dir

			# 检查边界
			if neighbor.x < 0 or neighbor.x >= map_width or neighbor.y < 0 or neighbor.y >= map_height:
				continue

			# 检查是否已经在 closed_set 中
			if closed_set.has(neighbor):
				continue

			# 检查是否是墙壁（绝对不能走）
			if _is_wall(neighbor):
				continue

			# 【核心修改】获取该格子的危险评分 (DangerMap 里的得分)
			var danger_score = DangerMap.get_danger_score(neighbor)
			
			# 如果危险评分大于 0（有炸弹要炸这里），我们可以给它加上极其高昂的寻路代价
			# 这样 A* 就会极力绕开这个格子，除非万不得已
			if danger_score > 0:
				# 危险系数权重：危险分越高，走这里的代价（Cost）呈指数级上升
				# 如果你想让敌人“绝对不走”有火的格子，可以直接在这里 `continue`
				# 但为了允许“万不得已时穿过”或者配合逃跑，加权代价是最好的选择
				pass 

			# 计算到达邻居的实际代价 g
			# 基础移动代价为 1.0，如果该格子有危险，额外加上 danger_score * 50 作为惩罚
			var movement_cost = 1.0 + (float(danger_score) * 50.0)
			var tentative_g = current_data["g"] + movement_cost

			# 如果邻居不在 open_set 中，或者找到了更优的路径
			if not open_set.has(neighbor) or tentative_g < open_set[neighbor]["g"]:
				var h = _get_heuristic(neighbor, target_pos)
				open_set[neighbor] = {
					"g": tentative_g,
					"f": tentative_g + h,
					"parent": current_cell
				}

	# 如果找不到路径（被完全包围），返回空数组或者让敌人在原地执行紧急逃生
	return []


# 启发函数：曼哈顿距离 (Manhattan Distance)
static func _get_heuristic(a: Vector2i, b: Vector2i) -> float:
	return abs(a.x - b.x) + abs(a.y - b.y)


# 在 open_set 中寻找 f 值最小的格子
static func _get_lowest_f_node(open_set: Dictionary) -> Vector2i:
	var lowest_node = open_set.keys()[0]
	var lowest_f = open_set[lowest_node]["f"]
	
	for node in open_set.keys():
		var f = open_set[node]["f"]
		if f < lowest_f:
			lowest_f = f
			lowest_node = node
			
	return lowest_node


# 回溯路径
static func _reconstruct_path(open_set: Dictionary, current: Vector2i) -> Array[Vector2i]:
	# 注意：当循环结束时，终点可能已经被移到了 closed_set 里，我们需要一个能同时查阅 open 和 closed 的方法
	# 为了简化，我们把整条链回溯写好：
	pass # 在实际下面完整的合并版里处理
