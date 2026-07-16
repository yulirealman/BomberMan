extends Area2D

var can_be_destroyed := false

@onready var health_component:HealthComponent = $HealthComponent

func _ready() -> void:
	#await get_tree().create_timer(0.1).timeout
	#can_be_destroyed = true
	health_component.health_depleted.connect(_on_death)


func _on_death()->void:
	#if !can_be_destroyed:
		#return
	queue_free()
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		print("碰到了玩家！")
		body.update_explosion_distance()

	queue_free()
