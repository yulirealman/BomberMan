class_name HealthComponent
extends Node

signal health_changed(current_health: int)
signal health_depleted
signal damaged(amount: int)

@export var max_health: int = 1

var current_health: int


func _ready():
	current_health = max_health


func damage(amount: int):

	if amount <= 0 or current_health <= 0:
		return

	current_health -= amount
	
	damaged.emit(amount)
	health_changed.emit(current_health)

	if current_health <= 0:
		#print(current_health)
		health_depleted.emit()


func heal(amount: int):
	if amount <= 0:
		return

	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health)


func is_dead() -> bool:
	return current_health <= 0
