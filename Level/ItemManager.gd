class_name ItemManager extends Node2D

func _ready():
	Events.grid_entity_destroyed.connect(_ongrid_entity_destroyed)


func _ongrid_entity_destroyed():
	pass
