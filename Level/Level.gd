# level.gd (關卡主控腳本)
extends Node2D

#@onready var grid_map_manager: GridManager = $GridManager
@onready var players_container: Node2D = $Players
@onready var bombs_container: Node = $BombsContainer


func _ready() -> void:
	# 在這裡動態綁定玩家的請求信號	
# 2. 遍歷 Players 容器下的所有子節點
	for child in players_container.get_children():
		# 將子節點安全地轉換為 Player 類型
		var p := child as Player
		
		
		
		# 3. 如果轉換成功（確保它不是普通的 Node2D，而是你的 Player 實例）
		if p != null:
			# 綁定信號，將當前這個 player 傳進回調函數中
			p.bomb_placement_requested.connect(_on_player_bomb_placement_requested)
			print("成功綁定玩家信號: ", p.name)
	
	

			
# 4. 當玩家發出「想放炸彈」的信號時，接收這個具體的 requesting_player
func _on_player_bomb_placement_requested(requesting_player: Player, target_grid_pos: Vector2i) -> void:

	# 1. 透過網格管理器檢查該位置有沒有炸彈
	if GridManager.has_bomb_at(target_grid_pos):
		print("這裡已經有炸彈了，不能放！")
		return
		
	# 2. 條件通過，從「發起請求的玩家」身上獲取炸彈數據
	var bomb_scene = requesting_player.duplicated_data.bomb_scene
	if bomb_scene == null: return
	
	var bomb = bomb_scene.instantiate()
	# 使用「該玩家」的 global_position 進行對齊
	bomb.global_position = GridManager.world_to_cell_center(requesting_player.global_position, GridManager.GRID_SIZE)
	bomb.set_explosion_distance(requesting_player.duplicated_data.explosion_distance)
	
	# 3. 將炸彈登記到網格地圖中
	GridManager.register_object(target_grid_pos, self)
	
	# 4. 當炸彈爆炸（消失）時，註銷網格登記
	bomb.tree_exited.connect(func(): 
		GridManager.unregister_object(target_grid_pos,self)
	)
	
	# 5. 把炸彈丟進專門的容器節點，保持場景樹乾淨
	bombs_container.add_child(bomb)
	
	# 6. 通知該玩家：放成功了，更新你內部的計數器
	requesting_player.register_bomb_placed(bomb)
