class_name ItemManager extends Node2D

# ==========================================
# 依赖注入 (由 LevelBuilder 在初始化时动态传入)
# ==========================================
var grid_manager: MyGridManager
var entity_layer: Node2D
var cell_width: int = 32 # 默认值，会被 LevelBuilder 覆盖
var drop_rates: Dictionary = {} # 接收 JSON 里的 item_drop_rates

func _ready() -> void:
	randomize() # 确保每次运行游戏的随机数种子不同
	# 监听全局实体的销毁信号
	Events.grid_entity_destroyed.connect(_ongrid_entity_destroyed)


# ==========================================
# 核心逻辑：响应网格实体的销毁
# ==========================================
func _ongrid_entity_destroyed(grid_pos: Vector2i, entity_id: int, entity_type: String) -> void:
	# 1. 掉落资格校验：当前只允许软砖块 (1002) 掉落道具
	
	if entity_type != "destructible":
		return
		
	# 2. 跑算法：算出这次掉落什么
	var drop_item_id = _calculate_drop()
	
	# 如果算出来是 0 (不掉落)，直接结束
	if drop_item_id == 0:
		return

	# 3. 实体工厂：生产道具
	var item_node = EntityFactory.create_entity(drop_item_id)
	if item_node == null:
		push_error("ItemManager: 无法生成道具 ID -> ", drop_item_id)
		return

	# 4. 坐标转换与安全挂载 (Deferred)
	item_node.position = GridUtils.cell_to_world(grid_pos, cell_width)
	# 如果你的基础道具脚本(BaseItem)里需要记录自己所在的网格位置，可以在这里赋值
	if "grid_pos" in item_node:
		item_node.grid_pos = grid_pos


	# 商业级做法：延后一帧添加节点，避免在物理或数组遍历回调中直接修改场景树导致崩溃
	if is_instance_valid(entity_layer):
		entity_layer.call_deferred("add_child", item_node)
	else:
		call_deferred("add_child", item_node)

	# 5. 闭环注册：把道具注册回网格！(这让后续的炸弹火焰能炸毁地上的道具)
	# 同样使用延迟调用，确保节点进入场景树后再注册
	call_deferred("_register_item_to_grid", grid_pos, drop_item_id, item_node)


func _register_item_to_grid(grid_pos: Vector2i, drop_item_id: int, item_node: Node2D) -> void:
	if grid_manager:
		grid_manager.register_cell(grid_pos, drop_item_id, item_node)


# ==========================================
# 商业级算法：权重随机 (Weighted Random)
# ==========================================
func _calculate_drop() -> int:
	if drop_rates.is_empty():
		return 0

	# 1. 算出所有权重总和
	var total_weight: float = 0.0
	for weight in drop_rates.values():
		total_weight += float(weight)

	# 2. 掷骰子 (在 0 到 总权重 之间取随机浮点数)
	var roll = randf_range(0.0, total_weight)
	var current_weight: float = 0.0

	# 3. 查表判定
	for key_id in drop_rates.keys():
		current_weight += float(drop_rates[key_id])
		if roll <= current_weight:
			return int(key_id) # JSON 解析出的 key 默认是 String，必须转回 int (如 "2001" -> 2001)
			
	return 0 # 兜底防错
