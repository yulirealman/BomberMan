class_name Explosion
extends Area2D


@export var damage := 1

@onready var timer:Timer = $Timer
@onready var hit_box_component:HitBoxComponent = $HitBoxComponent



func _ready():
	hit_box_component.hit.connect(_on_hit_box_component_hit)
	timer.start()



func _on_timer_timeout() -> void:
	queue_free()

	pass # Replace with function body.


func _on_hit_box_component_hit(hurtbox: Area2D) -> void:

	hurtbox.take_damage(damage)

	pass # Replace with function body.
