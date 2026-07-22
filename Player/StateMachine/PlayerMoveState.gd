# player_move_state.gd
class_name PlayerMoveState
extends State

func enter() -> void:
	print("Player Entered Move State")
		
func physics_update(_delta: float) -> void:
	# 1. 處理移動
	var direction = Vector2(
		Input.get_axis(player.action_left, player.action_right),
		Input.get_axis(player.action_up, player.action_down)
	)
	# ==================== 🛠️ 新增：在这里更新朝向和播放动画 ====================
	if direction != Vector2.ZERO:
		player.update_face_direction(direction)
		player.play_directional_animation("walk")
	# =====================================================================
	player.velocity = direction.normalized() * player.duplicated_data.speed
	player.move_and_slide()
	# ==================== 🛠️ 新增：在位移完成后立刻锁死坐标 ====================
	player.clamp_to_screen()
	# ===================================================================


	player.grid_pos = GridManager.world_to_cell(
		player.position,
		GridManager.GRID_SIZE
	)
	#GridManager.update_player_pos(player.grid_pos)
	Events.player_pos_changed.emit(player,player.grid_pos)

	

	 #如果沒有輸入，可以切換回 Idle 狀態（如果想要分得更細的話）
	if direction == Vector2.ZERO:
		state_machine.change_to("idle")
	
	# 2. 處理放炸彈
	if Input.is_action_just_pressed(player.action_bomb):

		if player.curr_bomb_amount < player.duplicated_data.max_bomb_amount:

			Events.bomb_placement_requested.emit(player,player.grid_pos)
