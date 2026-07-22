class_name PlayerIdleState extends State


# Called when the node enters the scene tree for the first time.
func enter() -> void:
	print("Player entered Idle State")
	# 進入 Idle 時，可以將速度歸零，防止慣性滑行
	player.velocity = Vector2.ZERO

	
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func physics_update(delta: float) -> void:
	# 1. 處理移動
	var direction = Vector2(
		Input.get_axis(player.action_left, player.action_right),
		Input.get_axis(player.action_up, player.action_down)
	)
	if direction != Vector2.ZERO:
		state_machine.change_to("move")
	# 2. 原地放炸彈邏輯（補上這段，讓 Idle 也能放炸彈）
	if Input.is_action_just_pressed(player.action_bomb):
		if player.curr_bomb_amount < player.duplicated_data.max_bomb_amount:
			Events.bomb_placement_requested.emit(player,player.grid_pos)
