class_name PlayerData extends Resource

@export_group("Basic Data")

@export_range(100.0, 150.0) var speed: float = 80.0:
	set(value):
		speed = clampf(value, 100.0, 150.0) # 鎖死在 100~175 之間

@export_range(1, 4, 1) var explosion_distance: int = 1:
	set(value):
		explosion_distance = clampi(value, 1, 4) # 鎖死在 1~4 之間

@export_range(1, 7, 1) var max_bomb_amount: int = 1:
	set(value):
		max_bomb_amount = clampi(value, 1, 7) # 鎖死在 1~5 之間

@export var bomb_scene: PackedScene
@export var damage: int = 1
