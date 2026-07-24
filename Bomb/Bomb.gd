class_name Bomb
extends AnimatableBody2D

signal exploded_requested(cell: Vector2i, power: int, player_id: int)
signal fuse_urgency_changed(bomb: Bomb, urgency_level: int)

@onready var timer: Timer = $Timer
@onready var collider: CollisionShape2D = $Collider

var cell: Vector2i
var explosion_distance: int = 1
var owner_player_id: int = 99
var is_exploded := false

func setup(p_id: int, power: int) -> void:
	owner_player_id = p_id
	explosion_distance = power

func _ready() -> void:
	cell = GridUtils.world_to_cell(position) # 用上你完美的静态方法
	collider.disabled = true
	timer.start(3.0)

func explode() -> void:
	if is_exploded: return
	is_exploded = true
	
	# 【核心】：自己不生成火焰，而是向外求助
	exploded_requested.emit(cell, explosion_distance, owner_player_id)
	
	## 让玩家回充炸弹数量 (假设也是通过 EventBus 或者直接发信号)
	print("🔴 炸弹爆炸！向总线发送回充信号，认定的主人 ID 是: ", owner_player_id)
	Events.player_bomb_freed.emit(owner_player_id)
	
	queue_free()

func _on_timer_timeout() -> void:
	explode()

func _on_listener_component_area_exited(area: Area2D) -> void:
	collider.set_deferred("disabled", false)
