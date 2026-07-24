#class_name BombManager
#extends Node2D
#
#@export var entity_layer: Node2D 
#@export var default_bomb_id: int = 997
## 如果你有爆炸特效场景，记得暴露出来
#@export var explosion_scene: PackedScene 
#
#var grid_manager: MyGridManager # 接收 LevelBuilder 传来的实例
#
#
#func _ready() -> void:
	## 确保信号参数带上 power (火力值)，不然没法算距离
	#Events.bomb_placement_requested.connect(_on_bomb_placement_requested)
	#print("BombManager 已就绪，正在全局监听放炸弹请求...")
#
#
## ==========================================
## 阶段 1：放置炸弹
## ==========================================
#func _on_bomb_placement_requested(player_id: int, world_pos: Vector2, power: int) -> void:
	## 1. 算出目标格子
	#var cell = GridUtils.world_to_cell(world_pos)
	#
	## 2. 【防抖查重】：如果这个格子里已经有东西了（不管是墙、箱子还是另一颗炸弹），绝对不放！
	#if not grid_manager.is_cell_empty(cell):
		#print("格子已被占用，无法放置炸弹！")
		## 🟢 【核心修复】通知对应的玩家：放炸弹失败，把炸弹退给我！
		#Events.bomb_placement_failed.emit(player_id)
		#return
#
	#print("收到玩家 %d 的放炸弹请求，坐标: %s" % [player_id, world_pos])
	#
	## 3. 生产炸弹
	#var bomb = EntityFactory.create_entity(default_bomb_id)
	#bomb.position = GridUtils.cell_to_world(cell)
	#
	#if bomb.has_method("setup"):
		#bomb.setup(player_id, power)
		#
	## 【核心】：监听这颗炸弹倒计时结束的求救信号
	#bomb.exploded_requested.connect(_on_bomb_exploded_requested)
	#
	#entity_layer.add_child(bomb)
	#
	## 4. 【占坑】：告诉 GridManager 这个格子里多了一颗炸弹
	#grid_manager.register_cell(cell, default_bomb_id, bomb)
#
#
## ==========================================
## 阶段 2：引爆结算
## ==========================================
#func _on_bomb_exploded_requested(center_cell: Vector2i, power: int, _player_id: int) -> void:
	## 1. 炸弹爆炸前，必须把自己从网格里清理掉，不然它的本体会挡住十字火焰！
	#grid_manager.remove_entity(center_cell) 
	#
	## 2. 调用你的完美算法推演格子
	#var affected_cells = _calculate_explosion_area(center_cell, power)
	#
	## 3. 生成火焰特效
	#if explosion_scene != null:
		#for target_cell in affected_cells:
			#var fire = explosion_scene.instantiate()
			#fire.position = GridUtils.cell_to_world(target_cell)
			#entity_layer.add_child(fire)
#
#
## ==========================================
## 阶段 3：推演算法
## ==========================================
#func _calculate_explosion_area(start_cell: Vector2i, power: int) -> Array[Vector2i]:
	#var result: Array[Vector2i] = []
	#result.append(start_cell)
	#
	#var directions = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
	#
	#for dir in directions:
		#for i in range(1, power + 1):
			#var target_cell = start_cell + (dir * i)
			#
			#if grid_manager.is_cell_empty(target_cell):
				#result.append(target_cell)
				#continue
				#
			#var cell_data = grid_manager.get_cell_data(target_cell)
			#var type_id = cell_data.get("type", 0)
			#var entity_node = cell_data.get("node")
			#
			#match type_id:
				#1: # 硬墙
					#break 
					#
				#2: # 软箱子
					#result.append(target_cell)
					## 【重要】必须从网格数据中移除该实体，否则格子会卡死
					#grid_manager.remove_entity(target_cell)
					#if entity_node and entity_node.has_method("destroy"):
						#entity_node.destroy() 
					#break
					#
				## 修复 ID 匹配问题，这里直接使用上面的配置常量
				#default_bomb_id: 
					#if entity_node and entity_node.has_method("explode"):
						#entity_node.call_deferred("explode")
					#break
					#
				#_: 
					#break
			#
	#return result
class_name BombManager
extends Node2D

@export var entity_layer: Node2D 
@export var default_bomb_id: int = 997
@export var explosion_scene: PackedScene 

var grid_manager: MyGridManager 

# 🟢 【核心新增】记录每个 player_id 当前在场上的活跃炸弹数量
# key: player_id, value: 活跃炸弹数
var active_bombs_count: Dictionary = {}


func _ready() -> void:
	# 监听带有 max_bombs 参数的放炸弹请求
	Events.bomb_placement_requested.connect(_on_bomb_placement_requested)

	print("BombManager 已就绪，正在全局监听放炸弹请求...")


# ==========================================
# 阶段 1：放置炸弹（含权威数量与格子双重校验）
# ==========================================
func _on_bomb_placement_requested(player_id: int, world_pos: Vector2, power: int, max_bombs: int) -> void:
	var cell = GridUtils.world_to_cell(world_pos)
	
	# 1. 初始化该玩家的计数器字典
	if not active_bombs_count.has(player_id):
		active_bombs_count[player_id] = 0
		
	# 2. 【权威校验 A】：检查该玩家场上炸弹数是否已达上限
	if active_bombs_count[player_id] >= max_bombs:
		print("❌ 玩家 %d 炸弹数量已达上限 (%d/%d)，拒绝放置！" % [player_id, active_bombs_count[player_id], max_bombs])
		Events.bomb_placement_failed.emit(player_id)
		return
		
	# 3. 【权威校验 B】：检查目标格子是否被占用
	if not grid_manager.is_cell_empty(cell):
		print("❌ 格子已被占用，无法放置炸弹！")
		Events.bomb_placement_failed.emit(player_id)
		return

	print("🟢 玩家 %d 成功放置炸弹，坐标: %s" % [player_id, world_pos])
	
	# 4. 校验通过，该玩家活跃炸弹数 +1
	active_bombs_count[player_id] += 1
	
	# 5. 生产炸弹实体
	var bomb = EntityFactory.create_entity(default_bomb_id)
	bomb.position = GridUtils.cell_to_world(cell)
	bomb.grid_pos = cell
	if bomb.has_method("setup"):
		bomb.setup(player_id, power)
		
	# 监听炸弹的引爆请求
	bomb.exploded_requested.connect(_on_bomb_exploded_requested)
	
	# 🟢 【核心挂钩】：利用 Godot 节点的 `tree_exited`（脱离场景树/被销毁）来自动安全回收名额！
	bomb.tree_exited.connect(func(): _on_bomb_freed(player_id))
	
	entity_layer.add_child(bomb)
	
	# 6. 【占坑】：告诉 GridManager 这个格子里多了一颗炸弹
	grid_manager.register_cell(cell, default_bomb_id, bomb)


# ==========================================
# 阶段 2：引爆结算
# ==========================================
func _on_bomb_exploded_requested(center_cell: Vector2i, power: int, _player_id: int) -> void:
	# 1. 炸弹爆炸前，把自己从网格里清理掉，避免挡住十字火焰
	#grid_manager.remove_entity(center_cell) 
	
	# 1. 查表：从 GridManager 拿到这个格子的完整数据包
	var cell_data = grid_manager.get_cell_data(center_cell)
	# 2. 如果这格子里真的有炸弹，命令它“自我毁灭”
	if not cell_data.is_empty() and cell_data.has("node") and cell_data["node"] != null:
		var bomb_node = cell_data["node"]
		
		# 面向对象的精髓：我不管你是啥，只要你有 explode 方法，你就炸
		if bomb_node.has_method("explode"):
			bomb_node.explode() 
	else:
		push_warning("BombManager: 坐标 ", center_cell, " 没有可引爆的炸弹实体！")
	# 2. 计算爆炸影响的格子
	var affected_cells = _calculate_explosion_area(center_cell, power)
	
	# 3. 生成火焰特效
	if explosion_scene != null:
		for target_cell in affected_cells:
			var fire = explosion_scene.instantiate()
			fire.position = GridUtils.cell_to_world(target_cell)
			entity_layer.add_child(fire)


# ==========================================
# 阶段 3：炸弹销毁与名额回充
# ==========================================
func _on_bomb_freed(player_id: int) -> void:
	if active_bombs_count.has(player_id):
		# 确保计数器绝不会变成负数
		active_bombs_count[player_id] = max(0, active_bombs_count[player_id] - 1)
		
		# 🟢 广播回充事件，UI 可以绑定这个信号来实时刷新炸弹冷却/剩余可用数
		Events.player_bomb_freed.emit(player_id)
		print("🔄 玩家 %d 的炸弹已安全回收，当前场上剩余: %d" % [player_id, active_bombs_count[player_id]])


# ==========================================
# 阶段 4：推演算法（保持不变）
# ==========================================
func _calculate_explosion_area(start_cell: Vector2i, power: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.append(start_cell)
	
	var directions = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
	
	for dir in directions:
		for i in range(1, power + 1):
			var target_cell = start_cell + (dir * i)
			
			if grid_manager.is_cell_empty(target_cell):
				result.append(target_cell)
				continue
				
			var cell_data = grid_manager.get_cell_data(target_cell)
			var type_id = cell_data.get("type", 0)
			var entity_node = cell_data.get("node")
			
			match type_id:
				1: # 硬墙
					break 
					
				2: # 软箱子
					result.append(target_cell)
					if entity_node and entity_node.has_method("destroy"):
						entity_node.destroy() 
					break
					
				default_bomb_id: 
					if entity_node and entity_node.has_method("explode"):
						entity_node.call_deferred("explode")
					break
					
				_: 
					break
			
	return result
