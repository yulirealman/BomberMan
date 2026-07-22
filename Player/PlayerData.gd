class_name PlayerData extends Resource

# 1. 定义数据改变时的信号
signal max_bomb_amount_changed(new_value: int)
signal explosion_distance_changed(new_value: int)
signal speed_changed(new_value: float)

@export_group("Basic Data")

@export_range(100.0, 150.0) var speed: float = 100.0:
	set(value):
		speed = clampf(value, 100.0, 150.0)

		speed_changed.emit(speed) # 2. 数据被修改时，发射信号

@export_range(1, 4, 1) var explosion_distance: int = 1:
	set(value):
		explosion_distance = clampi(value, 1, 4)
		explosion_distance_changed.emit(explosion_distance) # 发射信号

@export_range(1, 7, 1) var max_bomb_amount: int = 1:
	set(value):

		max_bomb_amount = clampi(value, 1, 7)
		max_bomb_amount_changed.emit(max_bomb_amount) # 发射信号

@export var bomb_scene: PackedScene
@export var damage: int = 1
