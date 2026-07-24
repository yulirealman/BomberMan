class_name Box
extends AnimatableBody2D

@onready var health_component: HealthComponent = $HealthComponent

# 1. 以后全游戏只需要加载这一个通用的道具场景预制体
@export var item_scene: PackedScene
# 2. 在编辑器里，把你的 .tres 资源分别拖到这里
@export var bomb_up_data: ItemData
@export var explosion_up_data: ItemData
@export var speed_up_data: ItemData



# 留空，等待工厂在生成时注入
var entity_id: int 
var entity_type: String
var grid_pos: Vector2i


func _ready() -> void:
	print("Box generated at",grid_pos," entity_type is ",entity_type, "entity_id is ",entity_id)
	if health_component:
		health_component.health_depleted.connect(_on_death)


# ==========================================
# 🟢 核心补充：对接 BombManager 的销毁接口
# ==========================================
func destroy() -> void:
	_on_death()


func _on_death() -> void:
	#print("WHY BOX NOT SEND SIGNAL",entity_id,entity_type)
	generate_item()
	Events.grid_entity_destroyed.emit(grid_pos, entity_id, entity_type)
	queue_free()
	

func generate_item() -> void:
	var roll := randf() # 0.0 到 1.0 的随机数
	var selected_data: ItemData = null

	# 规范化的概率区间分配（可根据需要自由调整数值）
	if roll < 0.1:
		# 0.0 ~ 0.4 (40% 几率)：箱子是空的
		print("运气不好，箱子是空的")
		return 
	elif roll < 0.2:
		# 0.4 ~ 0.6 (20% 几率)：威力提升
		selected_data = explosion_up_data
		print("决定生成：Power Item")
	elif roll < 0.3:
		# 0.6 ~ 0.8 (20% 几率)：速度提升
		selected_data = speed_up_data
		print("决定生成：Speed Item")
	else:
		# 0.8 ~ 1.0 (20% 几率)：炸弹数量提升
		selected_data = bomb_up_data
		print("决定生成：Bomb Item")

	# 3. 统一实例化逻辑
	if selected_data != null and item_scene != null:
		# 统一生成一个通用 Item 实例
		var spawned_item := item_scene.instantiate() as InGameItem
		
		if spawned_item != null:
			# 🟢 把选出来的资源动态注入到道具实例中
			spawned_item.item_data = selected_data
			
			# 定位与挂载逻辑（对齐格子中心）
			spawned_item.global_position = GridManager.world_to_cell_center(global_position, GridManager.GRID_SIZE)
			
			# 极其关键：用 call_deferred 确保在箱子销毁的同一帧，道具能被安全地加进场景
			get_parent().call_deferred("add_child", spawned_item)
