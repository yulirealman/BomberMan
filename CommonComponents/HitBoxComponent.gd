extends Area2D
class_name HitBoxComponent

signal hit(hurtbox: Area2D)

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	
	if area is HurtboxComponent:
		hit.emit(area)
