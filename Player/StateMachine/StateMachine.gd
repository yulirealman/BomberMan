class_name StateMachine
extends Node

@export var initial_state: State

var current_state: State
var states: Dictionary = {}

# 参数改为接收泛型的 actor
func init(actor: Node) -> void:
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.actor = actor # 把泛型实体注入给状态
			child.state_machine = self
			
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
