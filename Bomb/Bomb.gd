class_name Bomb
extends AnimatableBody2D

# 1. 核心添加：定义爆炸信号，用来通知 Player 回充数量
signal exploded

@onready var timer: Timer = $Timer
@onready var collider: CollisionShape2D = $Collider

var cell: Vector2i
var explosion_id = randi()

@export var explosion_scene: PackedScene


var explosion_distance: int = 2 
var is_exploded := false # 改名避免和信号名 exploded 冲突


func _ready() -> void:
	cell = MyUtility.grid_pos(position, GameManager.GRID_SIZE)
	print("placed bomb at ", cell)
	add_to_group("Bombs")
	GameManager.bomb_dict[cell] = self
	collider.disabled = true
	timer.start()


func _on_timer_timeout() -> void:
	explode()


func explode():
	# 防止连爆或多重判定重复触发
	if is_exploded:
		return
	is_exploded = true
	
	# 2. 核心添加：在销毁前立刻发出信号，通知绑定的玩家让数量恢复
	exploded.emit()
	
	# 从全局字典中移除，防止连锁爆炸重复索引
	GameManager.bomb_dict.erase(cell)

	# 释放火花
	generate_explosion(explosion_distance, GameManager.GRID_SIZE)
	
	queue_free()


func generate_explosion(distance: int, pixel: int):
	# 1. 先生成中心点的爆炸
	_spawn_explosion_at(global_position)
	
	# 2. 定义四个方向
	var directions = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	
	

	
	# 3. 循环生成四个方向延伸的侧边爆炸
	for dir in directions:
		for i in range(1, distance + 1):
			var target_pos = global_position + dir * i * pixel
			
			# 核心细节优化：先检查该位置有没有其他炸弹，如果有，触发它引爆
			check_bomb(target_pos)
			
			if check_wall(target_pos):
				break   # 撞墙，直接阻断该方向后续的爆炸
				
			_spawn_explosion_at(target_pos)
			
			if check_box(target_pos):
				break   # 炸到箱子，阻断该方向后续的爆炸


# 抽离出来的生成爆炸实例的辅助函数
func _spawn_explosion_at(pos: Vector2):
	var explosion = explosion_scene.instantiate()
	explosion.global_position = pos
	get_parent().add_child(explosion)
	# 提示：如果你之前的 explosion 脚本里有 setup() 方法，记得在这里调用：
	# if explosion.has_method("setup"):
	#     explosion.setup(explosion_id)


func check_bomb(pos: Vector2):
	var target_cell = MyUtility.grid_pos(pos, GameManager.GRID_SIZE)

	if GameManager.bomb_dict.has(target_cell):
		var bomb = GameManager.bomb_dict[target_cell]
		# 确保不是自己，且对方还没爆炸，就引爆它
		if bomb != self && !bomb.is_exploded:
			bomb.explode()


func _on_listener_component_area_exited(area: Area2D) -> void:
	# 玩家离开炸弹格子后，恢复碰撞，玩家就走不回来了
	collider.set_deferred("disabled", false)
	

func check_box(pos: Vector2) -> bool:
	return GameManager.have_box_at(MyUtility.grid_pos(pos, GameManager.GRID_SIZE)) 


func check_wall(pos: Vector2) -> bool:
	return GameManager.have_wall_at(MyUtility.grid_pos(pos, GameManager.GRID_SIZE))


func set_explosion_distance(amount: int):
	explosion_distance = amount
