class_name Enemy
extends CharacterBody2D

@export var speed: float = 40.0
@export var tile_size: int = 16

@onready var health_component: HealthComponent = $HealthComponent

# 狀態機定義
enum States { WANDER, CHASE, FLEE }
var current_state: States = States.WANDER

# 移動方向與路徑
var move_direction: Vector2 = Vector2.RIGHT
var grid_directions = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]

var _is_dying := false

# 網格控制變數
var target_grid_pos: Vector2i
var current_path: Array[Vector2i] = []
var player: Node2D = null

func _ready() -> void:
	# 1. 綁定生命組件
	if health_component:
		health_component.health_depleted.connect(_on_death)
	
	# 2. 獲取玩家引用
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		player = players[0]
		
	# 3. 初始對齊網格中心
	var current_grid = MyUtility.grid_pos(global_position, tile_size)
	global_position = Vector2(current_grid * tile_size) + Vector2(tile_size/2.0, tile_size/2.0)
	target_grid_pos = current_grid

func _physics_process(delta: float) -> void:
	if _is_dying:
		return
		
	var current_grid = MyUtility.grid_pos(global_position, tile_size)
	var target_world_pos = Vector2(target_grid_pos * tile_size) + Vector2(tile_size/2.0, tile_size/2.0)
	
	# 網格移動邏輯：如果還沒走到目標格子中心，就繼續走
	if global_position.distance_to(target_world_pos) > 1.0:
		move_direction = (target_world_pos - global_position).normalized()
		velocity = move_direction * speed
		move_and_slide()
		
		# 🚨【核心修正】：在移動過程中，隨時檢查是否撞到玩家（透過物理碰撞碰撞）
		_check_collision_damage()
	else:
		# 已經精準到達網格中心點，修正微小誤差，開始做新決策
		global_position = target_world_pos
		_make_grid_decision(current_grid)

# 🧠 核心大腦：每次走到網格中心點時，決定下一步去哪個格子
func _make_grid_decision(current_grid: Vector2i) -> void:
	# 優先級 1：檢查自己是否處於玩家放的炸彈危險區（保命要緊）
	if _is_in_danger_zone(current_grid):
		current_state = States.FLEE
		var safe_tile = _find_nearest_safe_tile(current_grid)
		if safe_tile != current_grid:
			current_path = _calculate_bfs_path(current_grid, safe_tile)
			if current_path.size() > 1:
				target_grid_pos = current_path[1]
				return

	# 優先級 2：檢查有沒有看到玩家，有的話就開啟 CHASE 模式追擊
	if _can_see_player(current_grid):
		current_state = States.CHASE
		if player:
			var player_grid = MyUtility.grid_pos(player.global_position, tile_size)
			current_path = _calculate_bfs_path(current_grid, player_grid)
			if current_path.size() > 1:
				target_grid_pos = current_path[1]
				return
			
	# 優先級 3：沒看見玩家，常規隨機漫步
	current_state = States.WANDER
	var valid_dirs = []
	for d in grid_directions:
		if _is_tile_walkable(current_grid + d):
			valid_dirs.append(d)
			
	if valid_dirs.size() > 0:
		target_grid_pos = current_grid + valid_dirs.pick_random()

# ─── 🛠️ 碰撞與傷害偵測 ───

# 處理 CharacterBody2D 移動時產生的碰撞
func _check_collision_damage() -> void:
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# 如果撞到的對象是玩家
		if collider is Player:
			if collider.health_component:
				collider.health_component.damage(1)
				print("怪物物理撞擊！要了玩家一口！")

# ─── 🧮 演算法與工具函數 ───

func _is_tile_walkable(cell: Vector2i) -> bool:
	# 移除了自己放彈的威脅，單純判定地圖上的障礙物與玩家的炸彈
	if GameManager.have_bomb_at(cell) or GameManager.have_box_at(cell) or GameManager.have_wall_at(cell):
		return false
	return true

func _is_in_danger_zone(cell: Vector2i) -> bool:
	var cell_world_pos = Vector2(cell * tile_size) + Vector2(tile_size/2.0, tile_size/2.0)
	var bombs = get_tree().get_nodes_in_group("Bombs")
	
	for bomb in bombs:
		var bomb_world_pos = bomb.global_position
		var fire_range = bomb.explosion_distance if "explosion_distance" in bomb else 2
		var max_physics_dist = (fire_range + 0.5) * tile_size
		
		# 穩健的物理距離與軸對齊判定，防止網格微小誤差導致 AI 變瞎子
		var is_same_x = abs(bomb_world_pos.x - cell_world_pos.x) < 2.0
		var is_same_y = abs(bomb_world_pos.y - cell_world_pos.y) < 2.0
		var dist = bomb_world_pos.distance_to(cell_world_pos)
		
		if (is_same_x or is_same_y) and dist <= max_physics_dist:
			var bomb_grid = MyUtility.grid_pos(bomb_world_pos, tile_size)
			if _has_clear_line(bomb_grid, cell): 
				return true
	return false

func _has_clear_line(start: Vector2i, end: Vector2i) -> bool:
	var diff = end - start
	var dir = Vector2i(sign(diff.x), sign(diff.y))
	var current = start + dir
	while current != end:
		if GameManager.have_wall_at(current) or GameManager.have_box_at(current):
			return false
		current += dir
	return true

func _can_see_player(current_grid: Vector2i) -> bool:
	if not player: return false
	var player_grid = MyUtility.grid_pos(player.global_position, tile_size)
	if current_grid.x == player_grid.x or current_grid.y == player_grid.y:
		return _has_clear_line(current_grid, player_grid)
	return false

func _calculate_bfs_path(start: Vector2i, target: Vector2i) -> Array[Vector2i]:
	var queue: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: null}
	
	while queue.size() > 0:
		var current = queue.pop_front()
		if current == target:
			break
			
		for d in grid_directions:
			var next = current + d
			if _is_tile_walkable(next) and not came_from.has(next):
				queue.append(next)
				came_from[next] = current
				
	var path: Array[Vector2i] = []
	if not came_from.has(target):
		return path
		
	var curr = target
	while curr != null:
		path.push_front(curr)
		curr = came_from[curr]
	return path

func _find_nearest_safe_tile(start: Vector2i) -> Vector2i:
	var queue: Array[Vector2i] = [start]
	var visited: Dictionary = {start: true}
	
	while queue.size() > 0:
		var current = queue.pop_front()
		
		if not _is_in_danger_zone(current):
			return current
			
		for d in grid_directions:
			var next = current + d
			if not GameManager.have_wall_at(next) and not GameManager.have_box_at(next) and not visited.has(next):
				visited[next] = true
				queue.append(next)
	return start

# ─── 💀 死亡邏輯 ───

func _on_death() -> void:
	if _is_dying:
		return
	_is_dying = true
	print("小怪被玩家的炸彈成功消滅了！")
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	queue_free()
