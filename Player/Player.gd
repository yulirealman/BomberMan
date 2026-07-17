class_name Player
extends CharacterBody2D

#data
@export var data:PlayerData
var duplicated_data:PlayerData

#componenet
@onready var health_component: HealthComponent = $HealthComponent
@onready var state_machine: StateMachine = $StateMachine # 引入狀態機
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D # 👈 1. 引入动画节点

@export var player_id: int = 0
# 动态生成的动作名称
var action_left: String
var action_right: String
var action_up: String
var action_down: String
var action_bomb: String

#local variable
var grid_pos: Vector2i
var curr_bomb_amount: int
var face_direction: Vector2 = Vector2.DOWN
# 🔴 修改 1：信号增加第一个参数，声明为 Player 类型，把自身传递给 Level 监听器
signal bomb_placement_requested(player: Player, at_grid_pos: Vector2i)

func _ready():
	
	action_left = "Left" + str(player_id)
	action_right = "Right" + str(player_id)
	action_up = "Up" + str(player_id)
	action_down = "Down" + str(player_id)
	action_bomb = "PlaceBomb" + str(player_id)
	
	if data == null:
		push_error("未配置 PlayerData 資源！")
		return
	duplicated_data = data.duplicate()

	curr_bomb_amount = 0 # 刚出生时场上炸弹数为 0
	add_to_group("Player")
	grid_pos = MyUtility.grid_pos(position,16)
	health_component.health_depleted.connect(_on_health_depleted)

	state_machine.init(self)
	
func _on_health_depleted():
	queue_free()





func register_bomb_placed(bomb: Node) -> void:
	curr_bomb_amount += 1
	# 這裡依然保持你優雅的信號回充設計
	if bomb.has_signal("exploded"):
		bomb.exploded.connect(_on_bomb_exploded) 
		
# 炸弹爆炸后的回充回调
func _on_bomb_exploded() -> void:
	curr_bomb_amount = max(0, curr_bomb_amount - 1)
	print("A bomb exploded. Recharged 1 bomb. Bombs remaining in Field:", curr_bomb_amount)

## 吃到“加范围”道具时调用
#func update_explosion_distance():
	#duplicated_data.explosion_distance += 1
#
#
## 吃到“加数量上限”道具时调用
#func update_bomb_amount():
	#duplicated_data.max_bomb_amount += 1
	#print("Bomb capacity increased! New maximum:", duplicated_data.max_bomb_amount)



# 在 Player.gd 中新增此函數
func apply_item_effect(item: ItemData) -> void:
	print("玩家 %d 拾取了道具: %s" % [player_id, item.item_name])
	
	match item.item_type:
		ItemData.ItemType.BOMB_UP:
			# 以前你寫的 update_bomb_amount()
			# 這裡我們用 item.value 進行動態加成，更靈活！
			duplicated_data.max_bomb_amount += int(item.value)
			print("炸彈上限增加至: ", duplicated_data.max_bomb_amount)
			
		ItemData.ItemType.EXPLOSION_UP:
			# 以前你寫的 update_explosion_distance()
			duplicated_data.explosion_distance += int(item.value)
			print("爆炸範圍增加至: ", duplicated_data.explosion_distance)
			
		ItemData.ItemType.SPEED_UP:
			# 輕鬆新增原本沒有的“速度鞋”道具
			duplicated_data.speed += item.value
			print("移動速度增加至: ", duplicated_data.speed)
			
		_:
			push_warning("未處理的道具類型！")


# for animation
func update_face_direction(input_vector: Vector2) -> void:
	if input_vector == Vector2.ZERO:
		return
	
	# 如果是斜向移动，优先取绝对值大的方向作为主朝向
	if abs(input_vector.x) > abs(input_vector.y):
		face_direction = Vector2.RIGHT if input_vector.x > 0 else Vector2.LEFT
	else:
		face_direction = Vector2.DOWN if input_vector.y > 0 else Vector2.UP

## 状态机调用：传入 "idle" 或 "walk"，函数会自动拼装方向后缀（如 "walk_down"）
func play_directional_animation(anim_base_name: String) -> void:
	var dir_suffix: String = "down"
	
	if face_direction == Vector2.UP:
		dir_suffix = "up"
	elif face_direction == Vector2.DOWN:
		dir_suffix = "down"
	elif face_direction == Vector2.LEFT:
		dir_suffix = "left"
	elif face_direction == Vector2.RIGHT:
		dir_suffix = "right"
		
	sprite.play(anim_base_name + "_" + dir_suffix)


# ==================== 🛠️ 新增：商业化屏幕坐标钳制 ====================
func clamp_to_screen() -> void:
	# 1. 获取当前游戏视口的实际像素大小（支持多分辨率自适应）
	var view_size = get_viewport_rect().size
	
	# 2. 设置安全边距（防止角色的半个身体或贴图边缘穿出屏幕）
	# 既然你的格子是 16x16，通常角色碰撞体半径约为 6 到 7 像素
	var margin: float = 7.0 
	
	# 3. 强行把 global_position 锁死在屏幕可见区域内
	global_position.x = clamp(global_position.x, margin, view_size.x - margin)
	global_position.y = clamp(global_position.y, margin+6, view_size.y - margin)
# =====================================================================
