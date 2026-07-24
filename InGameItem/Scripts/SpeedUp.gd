extends BaseItem

func apply_effect(target: Node2D) -> void:
	if target.has_method("add_speed"):
		target.add_speed(10)
