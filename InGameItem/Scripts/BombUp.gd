extends BaseItem

func apply_effect(target: Node2D) -> void:
	if target.has_method("add_bomb_capacity"):
		target.add_bomb_capacity(1)
