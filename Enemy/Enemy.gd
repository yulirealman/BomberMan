
extends CharacterBody2D

enum EnemyState {
	IDLE,         # 思考/挂机
	FLEE,         # 躲避炸弹（绝对最高优先级）
	CHASE_PLAYER, # 追杀玩家
	HUNT_BOX,     # 炸箱子发育
	WANDER        # 散步寻找机会
}

# ==========================================
# 🎛️ AI 性格与能力面板 (可在 Inspector 中直接调)
# ==========================================
@export_group("基础能力 (Stats)")
@export var speed: float = 110.0                 # 移动速度
@export var max_bombs: int = 7                   # 同屏最多可以放几个炸弹
@export var bomb_power: int = 5                  # 炸弹爆炸范围（需要你的Bomb脚本支持）

@export_group("AI 性格 (Personality)")
@export_range(0.0, 1.0) var aggro_chance: float = 0.6  # 60%概率优先追杀玩家，40%炸箱子
@export var box_search_radius: int = 8                 # 找箱子的视野范围 (格)
@export var think_time: float = 0.4                    # 放完炸弹或到达目标后的思考时间
@export var bomb_drop_cooldown: float = 0.25           # 连环放炸弹的间隔 (防止把7个炸弹放同一个格子里)

@export_group("节点引用 (References)")
@export var bomb_scene: PackedScene              # 炸弹预制体

# 内部状态变量
var current_state: EnemyState = EnemyState.IDLE
var current_path: Array[Vector2i] = []
var pause_timer: float = 0.0
var bomb_cd_timer: float = 0.0
var active_bombs: Array[Node] = [] # 记录自己当前放了几个炸弹

const GRID_SIZE = 32

func _ready() -> void:
	_set_idle(1.0) # 出生时先观察一下世界

func _physics_process(delta: float) -> void:
	# 1. 刷新内部计时器和炸弹数量
	bomb_cd_timer -= delta
	active_bombs = active_bombs.filter(func(b): return is_instance_valid(b)) 
	
	var my_grid_pos = GridManager.world_to_cell(global_position, GRID_SIZE)
	
	# 2. 【人类本能】：有危险绝对优先逃跑！
	if not DangerMap.is_cell_safe(my_grid_pos) and current_state != EnemyState.FLEE:
		_start_fleeing(my_grid_pos)
		
	# 3. 状态机流转
	match current_state:
		EnemyState.IDLE:
			pause_timer -= delta
			if pause_timer <= 0:
				_decide_next_action(my_grid_pos)
				
		EnemyState.FLEE:
			_move_along_path(delta)
			if current_path.is_empty():
				if DangerMap.is_cell_safe(my_grid_pos):
					_set_idle(0.3) # 逃到安全区了，松一口气
				else:
					_start_fleeing(my_grid_pos) # 居然还不安全，继续跑！
					
		EnemyState.CHASE_PLAYER, EnemyState.HUNT_BOX, EnemyState.WANDER:
			# 在移动过程中，如果是追杀玩家状态，且炸弹没放完，可以“沿途连环布雷”
			if current_state == EnemyState.CHASE_PLAYER and _can_plant_bomb():
				if randf() < 0.05: # 5% 的几率在追人的路上随手扔个炸弹封路
					_plant_bomb(my_grid_pos)
			
			_move_along_path(delta)
			
			if current_path.is_empty():
				# 到达目标点，放炸弹！
				_plant_bomb(my_grid_pos)
				_set_idle(think_time)

# ==========================================
# 🧠 AI 大脑：决策逻辑
# ==========================================
func _decide_next_action(current_grid: Vector2i) -> void:
	var player_pos = GridManager.get_player_pos()
	
	# 【高阶人类技巧】：视线狙击！
	# 如果玩家和我在同一条直线上，中间没有墙壁/箱子阻挡，且距离 <= 我的炸弹威力，直接原地放炸弹！
	if _can_plant_bomb() and _has_line_of_sight(current_grid, player_pos) and _manhattan_dist(current_grid, player_pos) <= bomb_power:
		_plant_bomb(current_grid)
		_set_idle(0.1) # 放完立马准备跑
		return
		
	# 如果没炸弹可用了，只能散步等炸弹爆炸
	if not _can_plant_bomb():
		_start_wander(current_grid)
		return

	# 投骰子决定这次是想杀人还是想炸箱子
	if randf() < aggro_chance:
		# 激进模式：去追玩家
		var target_pad = _find_free_adjacent_cell(current_grid, player_pos)
		if target_pad != Vector2i(-1, -1):
			current_path = _calculate_path(current_grid, target_pad)
			if not current_path.is_empty():
				current_state = EnemyState.CHASE_PLAYER
				return

	# 如果没抽中追人，或者找不到接近玩家的路，就去炸箱子
	var nearest_box = _find_box_in_radius(current_grid, box_search_radius)
	if nearest_box != Vector2i(-1, -1):
		var target_pad = _find_free_adjacent_cell(current_grid, nearest_box)
		if target_pad != Vector2i(-1, -1):
			current_path = _calculate_path(current_grid, target_pad)
			if not current_path.is_empty():
				current_state = EnemyState.HUNT_BOX
				return
				
	# 啥也干不了，散散步吧
	_start_wander(current_grid)


# ==========================================
# 💣 炸弹控制与防自杀机制
# ==========================================
func _can_plant_bomb() -> bool:
	return active_bombs.size() < max_bombs and bomb_cd_timer <= 0

func _plant_bomb(grid_pos: Vector2i) -> void:
	if not _can_plant_bomb(): return
	if GridManager.has_bomb_at(grid_pos): return
	
	# 【防自杀检查】：如果我在这里放炸弹，我还能跑掉吗？
	# 如果当前格子周围只有 1 个及以下的空地（死胡同），绝不放炸弹！
	if _get_walkable_neighbors_count(grid_pos) <= 1:
		return 

	var bomb = bomb_scene.instantiate()
	bomb.global_position = GridManager.cell_to_world(grid_pos, GRID_SIZE)
	
	# ！！！注意这里：如果你的炸弹脚本有设置威力的变量，在这里传给它 ！！！
	if "power" in bomb: bomb.power = bomb_power
	elif "explosion_radius" in bomb: bomb.explosion_radius = bomb_power
	
	get_parent().add_child(bomb)
	active_bombs.append(bomb)
	
	bomb_cd_timer = bomb_drop_cooldown
	
	# 真人放完炸弹的本能反应：立刻重新评估路线逃跑，而不是发呆
	_set_idle(0.1)

# ==========================================
# 🏃 移动与寻路
# ==========================================
func _move_along_path(delta: float) -> void:
	if current_path.is_empty(): return
	var target_world_pos = GridManager.cell_to_world(current_path[0], GRID_SIZE)
	global_position = global_position.move_toward(target_world_pos, speed * delta)
	if global_position.distance_to(target_world_pos) < 1.0:
		global_position = target_world_pos
		current_path.pop_front()

func _set_idle(time: float) -> void:
	current_state = EnemyState.IDLE
	pause_timer = time
	current_path.clear()

func _start_fleeing(current_grid: Vector2i) -> void:
	current_state = EnemyState.FLEE
	var safe_spot = DangerMap.find_nearest_safe_spot(current_grid)
	current_path = _calculate_path(current_grid, safe_spot)

func _start_wander(current_grid: Vector2i) -> void:
	var random_target = _get_random_walkable_cell(current_grid)
	if random_target != current_grid:
		current_path = _calculate_path(current_grid, random_target)
		if not current_path.is_empty():
			current_state = EnemyState.WANDER
			return
	_set_idle(0.5)

# ==========================================
# 🔍 辅助探测算法
# ==========================================
# 检查到目标格子之间是否有障碍物（用于十字视线狙击）
func _has_line_of_sight(start: Vector2i, end: Vector2i) -> bool:
	if start.x != end.x and start.y != end.y: return false # 不在同一直线
	
	var step = Vector2i(sign(end.x - start.x), sign(end.y - start.y))
	var curr = start + step
	while curr != end:
		if GridManager.get_object_at(curr) != null:
			return false # 中间有箱子或墙挡住了
		curr += step
	return true

func _get_walkable_neighbors_count(pos: Vector2i) -> int:
	var count = 0
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var neighbor = pos + dir
		if _is_in_bounds(neighbor) and _is_cell_walkable(neighbor):
			count += 1
	return count

func _manhattan_dist(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

# (以下函数与之前相同，直接复用)
func _find_box_in_radius(start: Vector2i, max_radius: int) -> Vector2i:
	var queue = [start]; var visited = {start: 0}
	while queue.size() > 0:
		var curr = queue.pop_front(); var dist = visited[curr]
		if dist > max_radius: continue
		var obj = GridManager.get_object_at(curr)
		if obj != null and "Box" in obj.name: return curr
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor = curr + dir
			if not visited.has(neighbor) and _is_in_bounds(neighbor):
				visited[neighbor] = dist + 1; queue.push_back(neighbor)
	return Vector2i(-1, -1)

func _find_free_adjacent_cell(start: Vector2i, target: Vector2i) -> Vector2i:
	var best_cell = Vector2i(-1, -1); var min_dist = 9999
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var neighbor = target + dir
		if _is_in_bounds(neighbor):
			var obj = GridManager.get_object_at(neighbor)
			if (obj == null or neighbor == start) and DangerMap.is_cell_safe(neighbor):
				var dist = _manhattan_dist(start, neighbor)
				if dist < min_dist: min_dist = dist; best_cell = neighbor
	return best_cell

func _get_random_walkable_cell(start: Vector2i) -> Vector2i:
	var queue = [start]; var visited = {start: true}; var valid_cells: Array[Vector2i] = []
	while queue.size() > 0:
		var curr = queue.pop_front()
		if _is_cell_walkable(curr) and DangerMap.is_cell_safe(curr): valid_cells.append(curr)
		if valid_cells.size() >= 10: break
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor = curr + dir
			if not visited.has(neighbor) and _is_in_bounds(neighbor) and _is_cell_walkable(neighbor):
				visited[neighbor] = true; queue.push_back(neighbor)
	return valid_cells.pick_random() if valid_cells.size() > 0 else start

func _calculate_path(start: Vector2i, target: Vector2i) -> Array[Vector2i]:
	if start == target: return []
	var queue = [start]; var came_from = {start: start}; var path_found = false
	while queue.size() > 0:
		var curr = queue.pop_front()
		if curr == target: path_found = true; break
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor = curr + dir
			if not came_from.has(neighbor) and _is_in_bounds(neighbor):
				var obj = GridManager.get_object_at(neighbor)
				var is_obstacle = (obj != null and not (neighbor == target)) 
				var is_danger = not DangerMap.is_cell_safe(neighbor) and current_state != EnemyState.FLEE
				if not is_obstacle and not is_danger:
					came_from[neighbor] = curr; queue.push_back(neighbor)
	if not path_found: return []
	var path: Array[Vector2i] = []; var current = target
	while current != start:
		path.push_front(current)
		current = came_from[current]
	return path

func _is_cell_walkable(pos: Vector2i) -> bool:
	return GridManager.get_object_at(pos) == null
func _is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < 12 and pos.y >= 0 and pos.y < 10
