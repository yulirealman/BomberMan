extends Node

var _active_bombs: Array[Bomb] = []
# 【新增】缓存每个炸弹的“真实”爆炸时间，解决连环爆问题
var _true_bomb_times: Dictionary = {}
#func _process(delta: float) -> void:
	#debug_print_map()
func _ready() -> void:
	GridManager.object_registered.connect(_on_object_registered)
	GridManager.object_unregistered.connect(_on_object_unregistered)

# 【新增】使用物理帧进行统一计算，极大地优化了性能
func _physics_process(_delta: float) -> void:
	# 1. 清理无效的炸弹（替代了之前在 getter 里疯狂 filter 的性能隐患）
	for i in range(_active_bombs.size() - 1, -1, -1):
		if not is_instance_valid(_active_bombs[i]):
			_active_bombs.remove_at(i)
			
	# 2. 每帧预计算一次连锁反应的真实时间
	_calculate_chain_reactions()

func _on_object_registered(pos: Vector2i, obj: Node2D) -> void:
	if obj is Bomb and not _active_bombs.has(obj):
		_active_bombs.append(obj)

func _on_object_unregistered(pos: Vector2i, obj: Node2D) -> void:
	if obj is Bomb:
		_active_bombs.erase(obj)

# ==========================================
# 🧠 核心修复：连环爆炸推演算法
# ==========================================
func _calculate_chain_reactions() -> void:
	_true_bomb_times.clear()
	
	# 初始状态：假设每个炸弹的真实时间就是它自己的倒计时
	for bomb in _active_bombs:
		_true_bomb_times[bomb] = bomb.get_time_left()
		
	# 连锁反应推导 (Graph Relaxation 算法)
	var changed = true
	var max_loops = _active_bombs.size()
	
	while changed and max_loops > 0:
		changed = false
		max_loops -= 1
		
		# 比较任意两颗炸弹
		for b1 in _active_bombs:
			for b2 in _active_bombs:
				if b1 == b2: 
					continue
					
				# 如果 b2 在 b1 的爆炸范围内
				if b2.cell in b1.get_explosion_grids():
					# 那么 b2 的爆炸时间，最晚不能超过 b1 的爆炸时间
					if _true_bomb_times[b1] < _true_bomb_times[b2]:
						_true_bomb_times[b2] = _true_bomb_times[b1]
						changed = true # 发生更新，再检查一轮（可能引发三连爆）

# ==========================================
# 🔍 寻路接口更新
# ==========================================
func get_time_to_explosion(pos: Vector2i) -> float:
	var min_time = INF
	
	for bomb in _active_bombs:
		if is_instance_valid(bomb) and pos in bomb.get_explosion_grids():
			# 【修复点】不再读取 bomb.get_time_left()，而是读取推演后的真实时间！
			var t = _true_bomb_times.get(bomb, bomb.get_time_left())
			if t < min_time:
				min_time = t
				
	return min_time

# 判断一个格子现在是否安全
func is_cell_safe(pos: Vector2i) -> bool:
	return get_time_to_explosion(pos) == INF

# 寻路找安全点 (不再局限于死板的权重，只需找 INF 的格子)
func find_nearest_safe_spot(current_pos: Vector2i, speed: float) -> Vector2i:
	var queue = [current_pos]
	var visited = {current_pos: 0.0} # 记录走到这里的花费时间
	
	while queue.size() > 0:
		var pos = queue.pop_front()
		var arrival_time = visited[pos]
		
		# 如果这个点绝对安全，返回它
		if is_cell_safe(pos):
			return pos
			
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor = pos + dir
			var walk_time = 32.0 / speed # 走一格需要的时间 (假设格子32)
			var next_arrival = arrival_time + walk_time
			
			if not visited.has(neighbor):
				if neighbor.x >= 0 and neighbor.x < 12 and neighbor.y >= 0 and neighbor.y < 10:
					var obj = GridManager.get_object_at(neighbor)
					if not (obj is Wall or obj is Box):
						# 只有当我们到达那个格子时，它还没炸，我们才能走过去！(预留 0.2 秒安全余量)
						if next_arrival < get_time_to_explosion(neighbor) - 0.2:
							visited[neighbor] = next_arrival
							queue.push_back(neighbor)
	
	return current_pos # 找不到就返回原地听天由命


# ==========================================
# 🛠️ 调试专用：打印当前危险地图
# ==========================================
func debug_print_map() -> void:
	# 假设你的地图尺寸是 12x10，如果 GridManager 里有变量建议替换成 GridManager.WIDTH
	var map_width = 12
	var map_height = 10
	
	print("\n=== 💣 危险地图预测 (Danger Map) ===")
	
	for y in range(map_height):
		var row_str = ""
		for x in range(map_width):
			var pos = Vector2i(x, y)
			
			# 获取格子上的物体，方便对照地形
			var obj = GridManager.get_object_at(pos)
			
			if obj is Wall:
				row_str += "[ W ]" # 墙壁
			elif obj is Box:
				row_str += "[ B ]" # 箱子
			else:
				var t = get_time_to_explosion(pos)
				if t == INF:
					row_str += "[ . ]" # 安全地带
				else:
					# 有危险的地方，打印出爆炸倒计时（保留1位小数）
					row_str += "[%3.1f]" % t 
		print(row_str)
		
	print("===================================\n")
