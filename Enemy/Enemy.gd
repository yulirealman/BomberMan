extends CharacterBody2D

var _current_grid_pos: Vector2i
var _target_pos: Vector2i
const SPEED = 100.0

func _process(_delta: float) -> void:
	# 1. 更新 AI 當前所在的網格位置
	_current_grid_pos = GridManager.world_to_cell(global_position, GridManager.GRID_SIZE)
	
	# 2. 核心邏輯：如果 AI 處於危險中
	if not DangerMap.is_cell_safe(_current_grid_pos):
		print("附近有炸弹！")
