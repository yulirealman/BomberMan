# state_machine.gd (掛載在 StateMachine 節點上)
class_name StateMachine
extends Node

@export var initial_state: State

var current_state: State
var states: Dictionary = {}

func init(player: Player) -> void:

	# 初始化：把所有子節點（狀態）找出來，並把 player 引用塞給它們
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.player = player
			child.state_machine = self # <--- 新增這一行，把狀態機自己注入進去
	if initial_state:
		current_state = initial_state
		current_state.enter()

func _process(delta: float) -> void:

	if current_state:

		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

# 核心：切換狀態的函式
func change_to(target_state_name: String) -> void:
	var new_state = states.get(target_state_name.to_lower())
	if !new_state or new_state == current_state:
		return
		
	current_state.exit()
	current_state = new_state
	current_state.enter()
