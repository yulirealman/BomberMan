extends AnimatableBody2D

@onready var health_component:HealthComponent = $HealthComponent
# Called when the node enters the scene tree for the first time.
@export var power_item_scene:PackedScene
@export var bomb_item_scene:PackedScene
func _ready() -> void:
	health_component.health_depleted.connect(_on_death)
	GameManager.box_dict[MyUtility.grid_pos(position,16)] = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_death() -> void:
	#var power_item = power_item_scene.instantiate()
	#get_parent().add_child(power_item)
	#power_item.global_position = global_position
	generate_item()
	GameManager.box_dict.erase(MyUtility.grid_pos(position,16))
	queue_free()
	
func generate_item() -> void:
	# randf() 会随机生成一个 0.0 到 1.0 之间的浮点数
	var roll = randf()
	
	var spawned_item: Node2D = null

	if roll < 0.3:
		# 0.0 到 0.40 之间 (40% 几率)，保持为 null，也就是 empty
		print("运气不好，箱子是空的")
		return 
	elif roll < 0.7:
		# 0.40 到 0.70 之间 (30% 几率)，生成威力道具
		spawned_item = power_item_scene.instantiate()
		print("生成了：Power Item")
	else:
		# 0.70 到 1.0 之间 (30% 几率)，生成数量道具
		spawned_item = bomb_item_scene.instantiate()
		print("生成了：Bomb Item")

	# 如果成功实例化了道具，再统一执行挂载和定位逻辑
	if spawned_item != null:
		spawned_item.global_position = global_position
		# 极其关键：用 call_deferred 确保在箱子销毁的同一帧，道具能被安全地加进场景
		get_parent().call_deferred("add_child", spawned_item)
