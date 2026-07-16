extends Node

var bomb_dict = {}
var wall_dict = {}
var box_dict = {}
var item_dict= {}

func have_bomb_at(cell: Vector2i) -> bool:
	return bomb_dict.has(cell)
	
func have_wall_at(cell: Vector2i) -> bool:
	return wall_dict.get(cell, false)

func have_box_at(cell: Vector2i) -> bool:

	return box_dict.get(cell, false)
	
#func get_box_at(cell:Vector2i):
#
	#if box_dict.has(cell):
		#return box_dict[cell]
#
	#return null
