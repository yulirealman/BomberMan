#class_name Bomb
#extends AnimatableBody2D
#
## 1. 核心添加：定义爆炸信号，用来通知 Player 回充数量
#signal exploded
#
#@onready var timer: Timer = $Timer
#@onready var collider: CollisionShape2D = $Collider
#
#var cell: Vector2i
#var explosion_id = randi()
#var explosion_grids:Array[Vector2i] = []
#
#@export var explosion_scene: PackedScene
#
#
#var explosion_distance: int = 2 
#var is_exploded := false # 改名避免和信号名 exploded 冲突
#
#
#func _ready() -> void:
	#cell = GridManager.world_to_cell(position, GridManager.GRID_SIZE)
	#print("placed bomb at ", cell)
	#add_to_group("Bombs")
	##GameManager.bomb_dict[cell] = self
	#GridManager.register_object(cell,self)
	#explosion_grids = []
	#collider.disabled = true
	#timer.start()
#
#
#func _on_timer_timeout() -> void:
	#explode()
#
#
#func explode():
	## 防止连爆或多重判定重复触发
	#if is_exploded:
		#return
	#is_exploded = true
	#
	## 2. 核心添加：在销毁前立刻发出信号，通知绑定的玩家让数量恢复
	#exploded.emit()
	#
	## 从全局字典中移除，防止连锁爆炸重复索引
	##GameManager.bomb_dict.erase(cell)
	#GridManager.unregister_object(cell)
#
	## 释放火花
	#generate_explosion(explosion_distance, GridManager.GRID_SIZE)
	#
#
	#queue_free()
#
#
#func generate_explosion(distance: int, pixel: int):
	## 1. 先生成中心点的爆炸
	#_spawn_explosion_at(global_position)
	#
	#explosion_grids.append(GridManager.world_to_cell(global_position,GridManager.GRID_SIZE))
	#
	## 2. 定义四个方向
	#var directions = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	#
	#
#
	#
	## 3. 循环生成四个方向延伸的侧边爆炸
	#for dir in directions:
		#for i in range(1, distance + 1):
			#var target_pos = global_position + dir * i * pixel
#
			## 核心细节优化：先检查该位置有没有其他炸弹，如果有，触发它引爆
			#check_bomb(target_pos)
			#
			#if check_wall(target_pos):
				#break   # 撞墙，直接阻断该方向后续的爆炸
				#
			#_spawn_explosion_at(target_pos)
			#
			#if check_box(target_pos):
				#break   # 炸到箱子，阻断该方向后续的爆炸
			#
			#explosion_grids.append(GridManager.world_to_cell(target_pos,GridManager.GRID_SIZE))
	#
#
## 抽离出来的生成爆炸实例的辅助函数
#func _spawn_explosion_at(pos: Vector2):
	#var explosion = explosion_scene.instantiate()
	#explosion.global_position = pos
	#get_parent().add_child(explosion)
	## 提示：如果你之前的 explosion 脚本里有 setup() 方法，记得在这里调用：
	## if explosion.has_method("setup"):
	##     explosion.setup(explosion_id)
#
#
#func check_bomb(pos: Vector2):
	#var target_cell = GridManager.world_to_cell(pos, GridManager.GRID_SIZE)
#
	#if GridManager.has_bomb_at(target_cell):
#
		#var bomb = GridManager.get_object_at(target_cell)
		## 确保不是自己，且对方还没爆炸，就引爆它
		#if bomb != self && !bomb.is_exploded:
			#bomb.explode()
#
#
#func _on_listener_component_area_exited(area: Area2D) -> void:
	## 玩家离开炸弹格子后，恢复碰撞，玩家就走不回来了
	#collider.set_deferred("disabled", false)
	#
#
#func check_box(pos: Vector2) -> bool:
	#return GridManager.get_object_at(GridManager.world_to_cell(pos, GridManager.GRID_SIZE)) is Box 
#
#
#func check_wall(pos: Vector2) -> bool:
	#return GridManager.get_object_at(GridManager.world_to_cell(pos, GridManager.GRID_SIZE)) is Wall
#
#
#func set_explosion_distance(amount: int):
	#explosion_distance = amount
#
#
#func get_explosion_grids():
	#return explosion_grids



class_name Bomb
extends AnimatableBody2D

# 1. 核心添加：定义爆炸信号，用来通知 Player 回充数量
signal exploded

@onready var timer: Timer = $Timer
@onready var collider: CollisionShape2D = $Collider

var cell: Vector2i
var explosion_id = randi()
var explosion_grids: Array[Vector2i] = []

@export var explosion_scene: PackedScene

var explosion_distance: int = 2 
var is_exploded := false # 改名避免和信号名 exploded 冲突


func _ready() -> void:
	cell = GridManager.world_to_cell(position, GridManager.GRID_SIZE)
	print("placed bomb at ", cell)
	add_to_group("Bombs")
	
	GridManager.register_object(cell, self)
	
	# 【核心修改】在生成时立即计算好所有受影响的格子
	_calculate_explosion_grids()
	
	#print(explosion_grids)
	collider.disabled = true
	timer.start()


func _on_timer_timeout() -> void:
	explode()


func explode():
	# 防止连爆或多重判定重复触发
	if is_exploded:
		return
	is_exploded = true
	
	# 2. 核心添加：在销毁前立刻发出信号，通知绑定的玩家让数量恢复
	exploded.emit()
	
	# 从全局字典中移除，防止连锁爆炸重复索引
	GridManager.unregister_object(cell,self)

	# 生成火花（直接使用预计算好的格子来生成，性能更好）
	generate_explosion(GridManager.GRID_SIZE)
	
	queue_free()


# 【核心修改】将原本的路径延伸逻辑提前到这里，生成时一次性算完
func _calculate_explosion_grids():
	explosion_grids.clear()
	
	# 1. 添加中心点
	explosion_grids.append(cell)
	
	# 2. 定义四个方向
	var directions = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
	
	# 3. 循环计算四个方向延伸的格子
	for dir in directions:
		for i in range(1, explosion_distance + 1):
			var target_cell = cell + dir * i
			var target_pos = GridManager.cell_to_world(target_cell, GridManager.GRID_SIZE) # 假设你有这个方法，或者用下面这种安全计算
			
			# 如果 GridManager 没有 cell_to_world，也可以用 world 坐标推导：
			# var target_pos = global_position + Vector2(dir) * i * pixel
			
			# 检查墙壁（遇到墙阻断该方向后续格子）
			if _check_wall_at_cell(target_cell):
				break
				
			explosion_grids.append(target_cell)
			
			# 检查箱子（炸到箱子后，箱子本身算受影响，但箱子后面的格子被阻断）
			if _check_box_at_cell(target_cell):
				break


# 【修改】基于预计算好的格子直接生成爆炸实例
func generate_explosion(pixel: int):
	for target_cell in explosion_grids:
		# 将格子坐标转回世界坐标来生成火花
		var target_pos = Vector2(target_cell) * pixel + Vector2(pixel / 2, pixel / 2) # 根据你的格子锚点调整，或者直接用下面更稳妥的方法：
		# 如果你的 GridManager 支持 cell 转 world：
		# var target_pos = GridManager.cell_to_world(target_cell)
		
		# 兼容你原本基于世界坐标的生成方式，也可以直接遍历格子转换：
		# 这里为了不破坏你原本的逻辑，我们通过格子反推世界坐标：
		var world_pos = (Vector2(target_cell) * pixel) + (Vector2.ONE * (pixel * 0.5)) # 视你的网格对齐而定
		# 或者最简单的：直接用世界偏移量
		var offset_from_start = (target_cell - cell) * pixel
		var final_pos = global_position + Vector2(offset_from_start)
		
		_spawn_explosion_at(final_pos)
		
		# 顺便处理链式引爆其他炸弹
		_check_bomb_at_cell(target_cell)


# 抽离出来的生成爆炸实例的辅助函数
func _spawn_explosion_at(pos: Vector2):
	var explosion = explosion_scene.instantiate()
	explosion.global_position = pos
	get_parent().add_child(explosion)


# 辅助检测方法（基于 Cell 坐标，比反复转世界坐标更精准高效）
func _check_bomb_at_cell(target_cell: Vector2i):
	if GridManager.has_bomb_at(target_cell):
		var bomb = GridManager.get_object_at(target_cell)
		if bomb != self && !bomb.is_exploded:
			bomb.explode()


func _check_box_at_cell(target_cell: Vector2i) -> bool:
	return GridManager.get_object_at(target_cell) is Box


func _check_wall_at_cell(target_cell: Vector2i) -> bool:
	return GridManager.get_object_at(target_cell) is Wall


func _on_listener_component_area_exited(area: Area2D) -> void:
	# 玩家离开炸弹格子后，恢复碰撞，玩家就走不回来了
	collider.set_deferred("disabled", false)


func set_explosion_distance(amount: int):
	explosion_distance = amount
	# 如果允许在放置后动态修改距离，这里可以重新算一次：
	# if is_inside_tree():
	#     _calculate_explosion_grids()


func get_explosion_grids():
	return explosion_grids
