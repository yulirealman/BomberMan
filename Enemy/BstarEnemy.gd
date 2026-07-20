extends CharacterBody2D

enum EnemyState {
	THINKING,     # 思考下一步
	FLEE,         # 逃命中（优先级最高）
	MOVING        # 移动去某个目标
}

# ==========================================
# 🎛️ AI 性格与能力面板
# ==========================================
@export_group("基础能力 (Stats)")
@export var speed: float = 110.0                 # 移动速度
@export var max_bombs: int = 7                   # 同屏最多可以放几个炸弹
@export var bomb_power: int = 5                  # 炸弹爆炸范围

@export_group("AI 性格 (Personality)")
@export_range(0.0, 1.0) var aggro_chance: float = 0.6  # 60%概率找玩家，40%炸箱子
@export var bomb_drop_cooldown: float = 0.2      # 连环放炸弹的间隔

@export_group("节点引用 (References)")
@export var bomb_scene: PackedScene              # 炸弹预制体

var current_state: EnemyState = EnemyState.THINKING
var current_path: Array[Vector2i] = []
var active_bombs: Array[Node] = [] 
var bomb_cd_timer: float = 0.0

const GRID_SIZE = 32
@onready var health_component = $HealthComponent # 假设你有这个组件

func _ready() -> void:
	if health_component:
		health_component.health_depleted.connect(queue_free)

func _physics_process(delta: float) -> void:
	bomb_cd_timer -= delta
	active_bombs = active_bombs.filter(func(b): return is_instance_valid(b)) 
	
	var my_grid_pos = GridManager.world_to_cell(global_position, GRID_SIZE)
	
	# ==========================================
	# 1. 绝对防御系统：随时校验生路
	# ==========================================
	if not DangerMap.is_cell_safe(my_grid_pos):
		var need_new_path = false
		
		# 如果还没开始逃，必须寻路
		if current_state != EnemyState.FLEE:
			need_new_path = true
		# 如果已经在逃了，但路径空了，或者终点变危险了
		elif current_path.is_empty() or not DangerMap.is_cell_safe(current_path.back()):
			need_new_path = true
		# 如果正在逃跑，但下一步即将爆炸（比如0.5秒内），立刻重新找路
		elif current_path.size() > 0:
			var next_step = current_path[0]
			if DangerMap.get_time_to_explosion(next_step) < 0.5:
				need_new_path = true
				
		if need_new_path:
			_start_fleeing(my_grid_pos)
	
	# ==========================================
	# 2. 状态机
	# ==========================================
	match current_state:
		EnemyState.THINKING:
			_decide_next_action(my_grid_pos)
			
		EnemyState.FLEE:
			_move_along_path(delta)
			if current_path.is_empty():
				# 跑完逃生路，转回思考。如果这里依然不安全，下一帧会被顶部防御系统抓到，再次逃跑
				current_state = EnemyState.THINKING
				
		EnemyState.MOVING:
			# 边走边拉雷：如果有闲置炸弹，且当前位置放炸弹安全，有几率顺手放一个
			if _can_plant_bomb() and randf() < 0.02:
				_try_plant_bomb(my_grid_pos)
				
			_move_along_path(delta)
			if current_path.is_empty():
				# 到达目的地，尝试放主炸弹
				_try_plant_bomb(my_grid_pos)
				current_state = EnemyState.THINKING

# ==========================================
# 🧠 AI 大脑：决策逻辑
# ==========================================
func _decide_next_action(my_grid_pos: Vector2i) -> void:
	if not DangerMap.is_cell_safe(my_grid_pos):
		return
		
	var player_pos = GridManager.get_player_pos()
	
	# 策略A：狙击玩家
	if randf() < aggro_chance and _can_plant_bomb():
		var snipe_pos = _find_attack_position(my_grid_pos, player_pos)
		if snipe_pos != Vector2i(-1, -1):
			current_path = _calculate_safe_path(my_grid_pos, snipe_pos)
			if not current_path.is_empty():
				current_state = EnemyState.MOVING
				return

	# 策略B：炸箱子发育
	if _can_plant_bomb():
		var box_pos = _find_nearest_box(my_grid_pos)
		if box_pos != Vector2i(-1, -1):
			var bomb_pad = _find_attack_position(my_grid_pos, box_pos)
			if bomb_pad != Vector2i(-1, -1):
				current_path = _calculate_safe_path(my_grid_pos, bomb_pad)
				if not current_path.is_empty():
					current_state = EnemyState.MOVING
					return

	# 策略C：随机游走
	var random_target = _get_random_safe_cell(my_grid_pos)
	current_path = _calculate_safe_path(my_grid_pos, random_target)
	current_state = EnemyState.MOVING

# ==========================================
# 💣 核心绝活：保命放雷判定
# ==========================================
func _can_plant_bomb() -> bool:
	return active_bombs.size() < max_bombs and bomb_cd_timer <= 0

func _try_plant_bomb(grid_pos: Vector2i) -> void:
	if not _can_plant_bomb(): return
	if GridManager.has_bomb_at(grid_pos): return
	
	# 如果模拟放雷后跑得掉，才放！
	if _can_escape_if_plant_here(grid_pos):
		var bomb = bomb_scene.instantiate()
		bomb.global_position = GridManager.cell_to_world(grid_pos, GRID_SIZE)
		if "explosion_distance" in bomb: bomb.explosion_distance = bomb_power
		if "fuse_time" in bomb: bomb.fuse_time = 3.0 # 确保默认倒计时
		
		get_parent().add_child(bomb)
		active_bombs.append(bomb)
		bomb_cd_timer = bomb_drop_cooldown
		
		# 放完炸弹立刻进入逃跑状态
		_start_fleeing(grid_pos)

# 脑内模拟：预判逃跑路线
func _can_escape_if_plant_here(plant_pos: Vector2i) -> bool:
	var sim_grids = []
	sim_grids.append(plant_pos)
	for dir in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		for i in range(1, bomb_power + 1):
			var target = plant_pos + dir * i
			var obj = GridManager.get_object_at(target)
			if obj is Wall: break
			sim_grids.append(target)
			if obj is Box: break
			
	# 【修复死因一】：获取这颗炸弹刚放下时的“真实寿命”
	var existing_danger_time = DangerMap.get_time_to_explosion(plant_pos)
	var actual_fuse_time = min(3.0, existing_danger_time) 
			
	var queue = [plant_pos]
	var visited = {plant_pos: 0.0}
	
	while queue.size() > 0:
		var pos = queue.pop_front()
		var arr_time = visited[pos]
		
		if DangerMap.is_cell_safe(pos) and not sim_grids.has(pos):
			return true
			
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor = pos + dir
			if not visited.has(neighbor) and _is_cell_walkable(neighbor):
				var next_arr = arr_time + (GRID_SIZE / speed)
				
				var real_explode_time = DangerMap.get_time_to_explosion(neighbor)
				# 模拟的炸弹会在 actual_fuse_time 爆炸
				var sim_explode_time = actual_fuse_time if sim_grids.has(neighbor) else INF
				var explode_time = min(real_explode_time, sim_explode_time)
				
				# 【修复死因二】：安全余量增加到 0.4 秒，防止卡墙角
				if next_arr < explode_time - 0.4:
					visited[neighbor] = next_arr
					queue.push_back(neighbor)
					
	return false

# ==========================================
# 🏃 移动与寻路
# ==========================================
func _move_along_path(delta: float) -> void:
	if current_path.is_empty(): return
	var target_world_pos = GridManager.cell_to_world(current_path[0], GRID_SIZE)
	
	global_position = global_position.move_toward(target_world_pos, speed * delta)
	
	if global_position.distance_to(target_world_pos) < 1.0:
		global_position = target_world_pos # 强制对齐网格中心，防止误差累积
		current_path.pop_front()

func _start_fleeing(current_grid: Vector2i) -> void:
	current_state = EnemyState.FLEE
	var safe_spot = DangerMap.find_nearest_safe_spot(current_grid, speed)
	
	if safe_spot == current_grid:
		# 死局：没有任何生路。放弃寻路避免死循环，原地等死
		current_path.clear()
	else:
		current_path = _calculate_safe_path(current_grid, safe_spot)

func _find_attack_position(start: Vector2i, target: Vector2i) -> Vector2i:
	var best_pos = Vector2i(-1, -1)
	var min_dist = 999
	for x in range(start.x - 5, start.x + 6):
		for y in range(start.y - 5, start.y + 6):
			var check_pos = Vector2i(x, y)
			if _is_cell_walkable(check_pos) and DangerMap.is_cell_safe(check_pos):
				if (check_pos.x == target.x or check_pos.y == target.y) and _manhattan_dist(check_pos, target) <= bomb_power:
					if _has_line_of_sight(check_pos, target):
						var dist = _manhattan_dist(start, check_pos)
						if dist < min_dist:
							min_dist = dist
							best_pos = check_pos
	return best_pos

func _calculate_safe_path(start: Vector2i, target: Vector2i) -> Array[Vector2i]:
	if start == target: return []
	var queue = [start]
	var came_from = {start: start}
	var arr_time = {start: 0.0}
	var path_found = false
	
	while queue.size() > 0:
		var curr = queue.pop_front()
		if curr == target: 
			path_found = true
			break
			
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor = curr + dir
			if _is_in_bounds(neighbor) and not came_from.has(neighbor):
				var obj = GridManager.get_object_at(neighbor)
				if obj == null or obj is CharacterBody2D:
					var next_arr = arr_time[curr] + (GRID_SIZE / speed)
					# 【修复死因二】：安全余量增加到 0.4 秒
					if next_arr < DangerMap.get_time_to_explosion(neighbor) - 0.4:
						came_from[neighbor] = curr
						arr_time[neighbor] = next_arr
						queue.push_back(neighbor)
						
	if not path_found: return []
	var path: Array[Vector2i] = []
	var current = target
	while current != start:
		path.push_front(current)
		current = came_from[current]
	return path

# ==========================================
# 🔍 辅助探测算法
# ==========================================
func _has_line_of_sight(start: Vector2i, end: Vector2i) -> bool:
	var step = Vector2i(sign(end.x - start.x), sign(end.y - start.y))
	var curr = start + step
	while curr != end:
		if not _is_cell_walkable(curr): return false 
		curr += step
	return true

func _find_nearest_box(start: Vector2i) -> Vector2i:
	var queue = [start]; var visited = {start: true}
	while queue.size() > 0:
		var curr = queue.pop_front()
		if GridManager.get_object_at(curr) is Box: return curr
		if _manhattan_dist(start, curr) > 8: continue
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor = curr + dir
			if not visited.has(neighbor) and _is_in_bounds(neighbor):
				visited[neighbor] = true; queue.push_back(neighbor)
	return Vector2i(-1, -1)

func _get_random_safe_cell(start: Vector2i) -> Vector2i:
	var valid = []
	for x in range(start.x - 3, start.x + 4):
		for y in range(start.y - 3, start.y + 4):
			var pos = Vector2i(x, y)
			if _is_in_bounds(pos) and _is_cell_walkable(pos) and DangerMap.is_cell_safe(pos):
				valid.append(pos)
	return valid.pick_random() if valid.size() > 0 else start

func _manhattan_dist(a: Vector2i, b: Vector2i) -> int: return abs(a.x - b.x) + abs(a.y - b.y)
func _is_cell_walkable(pos: Vector2i) -> bool: return not (GridManager.get_object_at(pos) is Wall or GridManager.get_object_at(pos) is Box or GridManager.get_object_at(pos) is Bomb)
func _is_in_bounds(pos: Vector2i) -> bool: return pos.x >= 0 and pos.x < 12 and pos.y >= 0 and pos.y < 10 # 去掉了原先多余的“和”字
