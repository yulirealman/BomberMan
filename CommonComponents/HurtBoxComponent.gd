extends Area2D
class_name HurtboxComponent

@export var health_component:HealthComponent


func take_damage(damage):


	if health_component:

		health_component.damage(damage)
	else:
		print("HURT BOX DID NOT ASSIGN HEALTH COMPONENT")
