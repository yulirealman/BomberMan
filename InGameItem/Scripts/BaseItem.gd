# BaseItem.gd
class_name BaseItem
extends Area2D

# 留空，等待工厂在生成时注入
var entity_id: int 
var entity_type: String
var grid_pos: Vector2i


func _ready() -> void:
	# 动态连接碰撞信号，不需要在编辑器里手动连
	body_entered.connect(_on_body_entered)
	print("ITEM GENERATED, ",grid_pos," entity_type ",entity_type," entity_id ",entity_id)

func _on_body_entered(body: Node2D) -> void:
	# 商业级判定：不判断对方是不是 Player，而是判断对方有没有“接收道具”的能力
	# 这样哪怕你以后做个“怪物也能吃道具”的机制，代码都不用改
	if body.is_in_group("player"): 
		apply_effect(body)
		_consume_item()

# 虚方法：留给具体的子类去实现
func apply_effect(_target: Node2D) -> void:
	push_warning("BaseItem: apply_effect() 必须被子类重写！")

func _consume_item() -> void:
	# 可以在这里做两件事：
	# 1. 告诉 GridManager 把这个格子的道具清空 (如果你把道具也注册进网格了)
	#signal grid_entity_destroyed(grid_pos: Vector2i, entity_id: int, entity_type:String)

	Events.grid_entity_destroyed.emit(grid_pos,entity_id,entity_type)
	# 2. 播放销毁动画并删除自己
	queue_free()
