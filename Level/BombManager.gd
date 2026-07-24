
class_name BombManager
extends Node2D

@export var entity_layer: Node2D 
@export var default_bomb_id: int = 4002
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
# 阶段 4：推演算法（商业级重构版：鸭子类型驱动）
# ==========================================
func _calculate_explosion_area(start_cell: Vector2i, power: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.append(start_cell)
	
	var directions = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
	
	for dir in directions:
		for i in range(1, power + 1):
			var target_cell = start_cell + (dir * i)
			
			# 1. 空地判定：火焰畅通无阻，继续蔓延
			if grid_manager.is_cell_empty(target_cell):
				result.append(target_cell)
				continue
				
			# 2. 障碍判定：获取网格中的实体
			var cell_data = grid_manager.get_cell_data(target_cell)
			var entity_node = cell_data.get("node")
			
			# 3. 核心路由：纯行为判定 (不再依赖任何 type_id)
			if is_instance_valid(entity_node):
				
				# 行为 A: 连锁反应 (炸弹)
				if entity_node.has_method("explode"):
					result.append(target_cell) # 炸弹所在的格子需要渲染火焰
					entity_node.call_deferred("explode")
					break # 炸弹吸收了冲击波，阻挡火焰继续穿透
					
				# 行为 B: 可破坏物 (软砖块、木桶等)
				elif entity_node.has_method("destroy"):
					result.append(target_cell) # 砖块被炸毁的格子需要渲染火焰
					entity_node.destroy() 
					break # 砖块吸收了冲击波，阻挡火焰继续穿透
					
				# 行为 C: 不可破坏物 (硬石墙)
				else:
					# 既没有引爆机制，也没有摧毁机制，说明是无敌的实体
					break # 火焰直接被阻挡，不加入 result，不向后蔓延
					
			else:
				# 兜底防御编程：格子不为空，但获取不到有效实体 (比如纯 Tile 占位)
				break 
				
	return result
