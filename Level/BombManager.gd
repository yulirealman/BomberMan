class_name BombManager
extends Node2D

# 已经不再需要去获取 entity_layer 来找玩家了
# 只需要获取它用来生成炸弹的父节点即可
@export var entity_layer: Node2D 
@export var default_bomb_id: int = 997
func _ready() -> void:
	# 【核心】：全局信号只需要绑定 1 次！绝对不要放在 for 循环里。
	Events.bomb_placement_requested.connect(_on_bomb_placement_requested)
	print("BombManager 已就绪，正在全局监听放炸弹请求...")




# 接收信号的回调函数
func _on_bomb_placement_requested(player_id: int, world_pos: Vector2) -> void:
	print("收到玩家 %d 的放炸弹请求，坐标: %s" % [player_id, world_pos])
	
	# 这里执行生成炸弹的逻辑
	var bomb = EntityFactory.create_entity(default_bomb_id)
	bomb.position = GridUtils.snap_to_grid_center(world_pos)
	entity_layer.add_child(bomb)
