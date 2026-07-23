#状态机的状态
class_name State
extends Node


#actor代表使用状态机的node
var actor: Node 
#需要一个状态机的引用，这样我们就能状态.状态机.change_state()
var state_machine: StateMachine 

func enter() -> void:
	pass

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass
