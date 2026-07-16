# state.gd (純邏輯類別，不掛載在任何地方)
class_name State
extends Node

# 拿來引用外層的 Player，方便控制玩家的物理和動畫
var player: Player
var state_machine: StateMachine # <--- 新增這一行，讓狀態知道自己屬於哪個狀態機
#signal change_state_requested

# 當切換進入這個狀態時觸發
func enter() -> void:
	pass

# 當離開這個狀態時觸發
func exit() -> void:
	pass

# 對應 Player 的 _process
func update(_delta: float) -> void:
	pass

# 對應 Player 的 _physics_process
func physics_update(_delta: float) -> void:
	pass
