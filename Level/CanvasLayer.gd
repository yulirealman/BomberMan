extends CanvasLayer

# 核心数据引用
var player_data: PlayerData 

@onready var bomb_texture: TextureRect = $BombAttribute/TextureRect
@onready var explosion_texture: TextureRect = $ExplosionAttribute/TextureRect
@onready var shoes_texture: TextureRect = $ShoesAttribute/TextureRect


func _ready() -> void:
	# 将信号直接连接到下方的 setup_player_data 函数
	Events.player_data_initialized.connect(setup_player_data)


# 接收 Player 广播过来的数据复印件
func setup_player_data(new_data: PlayerData) -> void:

	player_data = new_data # 💥 就是漏了这一行！必须要把传进来的数据保存下来！
	
	# 1. 刷新初始显示
	_on_bomb_changed(player_data.max_bomb_amount)
	_on_explosion_changed(player_data.explosion_distance)
	_on_speed_changed(player_data.speed)
	
	# 2. 绑定新数据的信号（数据一旦改变，UI自动更新）
	player_data.max_bomb_amount_changed.connect(_on_bomb_changed)
	player_data.explosion_distance_changed.connect(_on_explosion_changed)
	player_data.speed_changed.connect(_on_speed_changed)


# --- 具体的 UI 更新逻辑 ---

func _on_bomb_changed(value: int) -> void:
	var safe_count = clamp(value, 1, 9)
	bomb_texture.texture = load("res://UI/plus%d.png" % safe_count)

func _on_explosion_changed(value: int) -> void:
	var safe_count = clamp(value, 1, 9)
	explosion_texture.texture = load("res://UI/plus%d.png" % safe_count)

func _on_speed_changed(value: float) -> void:
	var base_speed: float = 100.0       # 玩家的初始基础速度
	var speed_per_item: float = 10.0    # 吃一个鞋子道具增加的速度值
	
	# 计算公式：(当前速度 - 基础速度) / 每个道具加成 + 1
	# 举例：
	# 速度 100 -> (100 - 100) / 10 + 1 = 1 (显示 plus1.png)
	# 速度 110 -> (110 - 100) / 10 + 1 = 2 (显示 plus2.png)
	var current_level = int((value - base_speed) / speed_per_item) + 1
	
	var safe_count = clamp(current_level, 1, 9)
	shoes_texture.texture = load("res://UI/plus%d.png" % safe_count)
