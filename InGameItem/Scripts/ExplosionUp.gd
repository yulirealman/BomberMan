extends BaseItem

func apply_effect(target: Node2D) -> void:
	if target.has_method("add_explosion_power"):
		target.add_explosion_power(1)
