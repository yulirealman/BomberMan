class_name Player
extends CharacterBody2D

#放入res存储的data文件
@export var data:PlayerData

#存放玩家id, 用来本地pvp
@export var player_id: int = 0

#player自带的componenet
@onready var health_component: HealthComponent = $HealthComponent
@onready var state_machine: StateMachine = $StateMachine
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D # 👈 1. 引入动画节点


# 变量用来拼接input名称与player id
var action_left: String
var action_right: String
var action_up: String
var action_down: String
var action_bomb: String
var face_direction: Vector2 = Vector2.DOWN

#复制一份plaeyr的res data
var duplicated_data:PlayerData

#存放一个临时的在游戏中的信息
var grid_pos: Vector2i

var curr_bomb_amount: int

func setup(params: Dictionary) -> void:
	if params.has("player_index"):
		player_id = params["player_index"]


func _ready():	
	#拼接对应玩家的input
	action_left = "Left" + str(player_id)
	action_right = "Right" + str(player_id)
	action_up = "Up" + str(player_id)
	action_down = "Down" + str(player_id)
	action_bomb = "PlaceBomb" + str(player_id)
	
	#加载player res资源
	if data == null:
		push_error("未配置 PlayerData 資源！")
		return
	
	#复制资源
	duplicated_data = data.duplicate()
	
	#把这个复制的资源广播到event bus，方便ui调用
	Events.player_data_initialized.emit(duplicated_data)
	Events.player_bomb_freed.connect(_on_bomb_freed)
	Events.bomb_placement_failed.connect(_on_bomb_placement_failed)
	
	#初始化临时信息
	curr_bomb_amount = duplicated_data.max_bomb_amount
	add_to_group("Player")
	grid_pos = GridManager.world_to_cell(position,GridManager.GRID_SIZE)

	#链接health组件
	health_component.health_depleted.connect(_on_health_depleted)

	#初始化状态机，并把自己的引用传过去
	state_machine.init(self)
	
func _unhandled_input(event: InputEvent) -> void:
	# 1. 严格使用 str() 将整数转换为字符串进行拼接
	# 比如当 player_id = 1 时，生成 "PlaceBomb1"
	var action_name = "PlaceBomb" + str(player_id)
	
	# 2. 检测放炸弹按键被按下
	if event.is_action_pressed(action_name):
		# 可选防御：如果玩家死亡或者处于某些不能放炸弹的状态，直接返回
		# if state_machine.current_state.name == "dead": return
		plant_bomb()
	
	

#当血量为0， 
func _on_health_depleted():
	#广播玩家死亡
	Events.player_dead.emit(self)
	#从树里清除
	queue_free()



#func register_bomb_placed(bomb: Node) -> void:
	#curr_bomb_amount += 1
	## 如果参数为炸弹
	#if bomb.is_in_group("Bomb"):
		##接受炸弹爆炸时所发出的信号
		#bomb.exploded.connect(_on_bomb_exploded)
		
#炸弹爆炸后的回充回调
# 接收回充广播的回调
func _on_bomb_freed(p_id: int) -> void:
	# 关键判定：EventBus 是全局广播，所有人都会收到。
	# 我们只处理属于自己 ID 的回充请求！
	if p_id != player_id:
		return
		
	 #核心：当前剩余炸弹数 + 1，但绝不能超过最大上限 max_bombs
	curr_bomb_amount = min(curr_bomb_amount + 1, duplicated_data.max_bomb_amount)
	
	#基本等于curr_bomb-=1 只不过不会变复数最小为0
	#curr_bomb_amount = max(0, curr_bomb_amount - 1)

func _on_bomb_placement_failed(id: int) -> void:
	# 确保是当前玩家的炸弹被拒了
	if id == player_id:
		curr_bomb_amount += 1 # 把被吞掉的炸弹加回来！
		print("❌ 炸弹放置被拒，已成功退回！当前剩余: %d" % curr_bomb_amount)

#修改复制的player res的信息
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



# Player.gd 简化后的放炸弹函数
func plant_bomb() -> void:
	if state_machine.current_state.name == "dead":
		return
		
	var cell = GridUtils.snap_to_grid_center(self.position)
	
	# 🟢 多传一个 duplicated_data.max_bomb_amount 过去，作为权威校验的依据
	Events.bomb_placement_requested.emit(
		player_id, 
		cell, 
		duplicated_data.explosion_distance, 
		duplicated_data.max_bomb_amount
	)
