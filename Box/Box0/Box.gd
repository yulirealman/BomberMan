extends AnimatableBody2D

@onready var health_component:HealthComponent = $HealthComponent
# 1. 以后全游戏只需要加载这一个通用的道具场景预制体
@export var item_scene: PackedScene
# 2. 在编辑器里，把你的 .tres 资源分别拖到这里
@export var bomb_up_data: ItemData
@export var explosion_up_data: ItemData
@export var speed_up_data:ItemData
func _ready() -> void:

	health_component.health_depleted.connect(_on_death)
	GameManager.box_dict[MyUtility.grid_pos(position,GameManager.GRID_SIZE)] = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_death() -> void:

	generate_item()
	GameManager.box_dict.erase(MyUtility.grid_pos(position,GameManager.GRID_SIZE))
	queue_free()
	
func generate_item() -> void:
	# randf() 会随机生成一个 0.0 到 1.0 之间的浮点数
	var roll := randf()
	
	# 准备用来注入的资源
	var selected_data: ItemData = null

	if roll < 0.35:
		# 0.0 到 0.40 之间 (40% 几率)，保持为 null，也就是 empty
		print("运气不好，箱子是空的")
		return 
	elif roll < 0.6:
		# 0.40 到 0.70 之间 (30% 几率)
		selected_data = explosion_up_data
		print("决定生成：Power Item")
	elif roll< 0.8:
		selected_data = speed_up_data
		print("决定生成：Speed Item")
	else:
		# 0.70 到 1.0 之间 (30% 几率)
		selected_data = bomb_up_data
		print("决定生成：Bomb Item")

	# 3. 统一实例化逻辑
	if selected_data != null and item_scene != null:
		# 统一生成一个通用 Item 实例
		var spawned_item := item_scene.instantiate() as InGameItem
		
		if spawned_item != null:
			# 🟢 核心：把刚才选出来的资源，动态注入到这个道具实例中！
			# 道具内部的 _ready() 会自动根据这个 data 去替换它自己的 Sprite 贴图。
			spawned_item.item_data = selected_data
			
			# 定位与挂载逻辑
			spawned_item.global_position = global_position
			
			# 极其关键：用 call_deferred 确保在箱子销毁的同一帧，道具能被安全地加进场景
			get_parent().call_deferred("add_child", spawned_item)
