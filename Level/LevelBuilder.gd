extends Node2D

@export var map_json_path: String = "res://Data/level_1.json"

@onready var floor_map: TileMapLayer = $FloorTileMap


# ==========================================
# 新增：相机缩放模式开关
# ==========================================
@export_category("Camera Scaling Mode")
@export var allow_stretch_distortion: bool = false # 开关：是否允许拉伸画面变形，以彻底消灭内部留白

# 网格管理器
var grid_manager: MyGridManager
@onready var bomb_manager: BombManager = $BombManager
# ==========================================
# 状态缓存：用于绕过生命周期，纯算法监控自适应缩放
# ==========================================
var _map_pixel_width: float = 0.0
var _map_pixel_height: float = 0.0
var _last_viewport_size: Vector2 = Vector2.ZERO
var _game_camera: Camera2D


# [新增] 语义映射表：将 JSON 里的文本 type 映射到 EntityDB 的真实 ID
const SPAWN_MAPPING: Dictionary = {
	"player_start": 999,
	"ghost": 998,
	"slime": 998, # 假设你目前 DB 只有 998，slime 先用 Redot 代替，后续 DB 加了新怪物再改
	# "boss_1": 1001 
}
# 假设当前游戏游玩人数（后续可由游戏大厅/选人界面传入）
var active_player_count: int = 2
# 建议在 LevelBuilder 节点下建一个名为 "EntityLayer" 的 Node2D 并开启 Y-Sort
@onready var entity_layer: Node2D = $EntityLayer # 如果没有，就直接用 self (add_child)


func _ready():
	# 1. 游戏启动，先让工厂去读表
	EntityFactory.initialize_db("res://Data/EntitiesDB.json")
	
	# 2. 然后再开始生成具体的关卡
	build_level_from_json(map_json_path)


func build_level_from_json(path: String):
	# 1. 打开并解析 JSON
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("文件读取失败，请检查路径: ", path)
		return
		
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null:
		print("JSON解析失败")
		return

	# 2. 提取网格配置
	var config = data["grid_config"]
	var c_width = float(config["cell_width"])
	var c_height = float(config["cell_height"])
	var cols = int(config["columns"])
	var rows = int(config["rows"])

	# 3. 初始化数据网格
	grid_manager = MyGridManager.new(cols, rows, Vector2(c_width, c_height))
	# 【核心】：把刚刚建好的网格实例，塞给炸弹管理器！
	if bomb_manager:
		bomb_manager.grid_manager = grid_manager
	# 4. 生成地图实体
	var map_array = data["map_layout"]
	for y in range(rows):
		for x in range(cols):
			var tile_id = int(map_array[y][x])
			var grid_pos = Vector2i(x, y)

			# 铺地板
			floor_map.set_cell(grid_pos, 0, Vector2i(0,0))

			if tile_id == 0:
				grid_manager.register_cell(grid_pos, tile_id)
				continue

			# 生产障碍物
			var entity = EntityFactory.create_entity(tile_id)
			if entity:
				#var target_x = (x * c_width) + (c_width / 2.0)
				#var target_y = (y * c_height) + (c_height / 2.0)
				#entity.position = Vector2(round(target_x), round(target_y))
				#add_child(entity)
				#grid_manager.register_cell(grid_pos, tile_id, entity)
				entity.position = GridUtils.cell_to_world(grid_pos, int(c_width))
				entity.grid_pos = grid_pos
				entity_layer.add_child(entity)
				grid_manager.register_cell(grid_pos, tile_id, entity)
	
	# ---------------- 新增部分开始 ----------------
	# 4.5 生成动态实体 (玩家与敌人)
	if data.has("spawns"):
		_build_dynamic_entities(data["spawns"], c_width, c_height)
	else:
		push_warning("LevelBuilder: JSON 中没有找到 spawns 节点，跳过动态实体生成。")
	# ---------------- 新增部分结束 ----------------	
	

	
	# 5. 保存地图物理绝对长宽
	_map_pixel_width = cols * c_width
	_map_pixel_height = rows * c_height
	
	# 6. 初始化摄像机坐标
	_init_camera()
	

	print("地图构建完成！Camera进入纯算法自适应监控模式")







# ==========================================
# 动态实体生成子系统
# ==========================================

func _build_dynamic_entities(spawns_data: Array, cell_w: float, cell_h: float) -> void:
	var player_spawn_pool: Array[Vector2] = []

	# 1. 遍历并分类收集出生点
	for spawn in spawns_data:
		# 防御性编程：检查 JSON 字段是否存在
		if not spawn.has("type") or not spawn.has("x") or not spawn.has("y"):
			push_warning("LevelBuilder: 发现格式损坏的 spawn 数据 -> ", spawn)
			continue
			
		var type_name = str(spawn["type"])
		#var grid_x = float(spawn["x"])
		#var grid_y = float(spawn["y"])
		#
		## 将网格坐标转换为精确的像素世界坐标 (居中对齐)
		#var target_x = (grid_x * cell_w) + (cell_w / 2.0)
		#var target_y = (grid_y * cell_h) + (cell_h / 2.0)
		#var world_pos = Vector2(round(target_x), round(target_y))
		#
		## 2. 路由分发
		#if type_name == "player_start":
			#player_spawn_pool.append(world_pos)
		#else:
			#_spawn_enemy(type_name, world_pos)
		var grid_pos = Vector2i(int(spawn["x"]), int(spawn["y"]))
		var world_pos = GridUtils.cell_to_world(grid_pos, int(cell_w))
		
		if type_name == "player_start":
			player_spawn_pool.append(world_pos)
		else:
			_spawn_enemy(type_name, world_pos)
			
	_spawn_players(player_spawn_pool)
			#
	## 3. 结算玩家生成
#
	#_spawn_players(player_spawn_pool)


func _spawn_enemy(type_name: String, world_pos: Vector2) -> void:
	if not SPAWN_MAPPING.has(type_name):
		push_error("LevelBuilder: 未知的怪物类型映射 -> ", type_name)
		return
		
	var entity_id = SPAWN_MAPPING[type_name]
	var enemy = EntityFactory.create_entity(entity_id)
	
	if enemy:
		enemy.position = world_pos
		# 可选：如果你需要给怪物传入初始巡逻参数，可以通过 params 传进去
		# var params = {"patrol_dir": Vector2.RIGHT} 
		# var enemy = EntityFactory.create_entity(entity_id, params)
		
		# 添加到场景树 (如果是 Y-Sort 层最好，否则直接 add_child)
		#add_child(enemy)
		entity_layer.add_child(enemy)
		# 注意：不要把怪物注册进 grid_manager 占坑！它应该动态走动。


func _spawn_players(spawn_pool: Array[Vector2]) -> void:
	if spawn_pool.is_empty():
		push_error("LevelBuilder 致命错误: 地图中没有配置任何 player_start！")
		return
		
	# 商业级细节：打乱出生点，保证多人游戏时的公平性和随机感
	spawn_pool.shuffle()
	
	var player_id = SPAWN_MAPPING["player_start"] # 就是 999
	
	# 根据当前活跃玩家数量进行实例化
	for i in range(active_player_count):
		# 防御：玩家人数超过地图预设的出生点数量
		if i >= spawn_pool.size():
			push_warning("LevelBuilder: 地图出生点不足，玩家 %d 无法生成！" % (i + 1))
			break
			
		var player_instance = EntityFactory.create_entity(player_id)
		if player_instance:
			player_instance.position = spawn_pool[i]
			
			# 如果你的 Player 脚本有 setup 方法，把玩家序号 (P1, P2) 传进去
			# 以便 Player 内部根据序号绑定不同的 Input Map (比如 "p1_move_left", "p2_move_left")
			if player_instance.has_method("setup"):
				player_instance.setup({"player_index": i}) 
				
			#add_child(player_instance)
			entity_layer.add_child(player_instance)








func _init_camera():
	_game_camera = get_node_or_null("Camera2D")
	if _game_camera == null:
		_game_camera = Camera2D.new()
		_game_camera.name = "Camera2D"
		add_child(_game_camera)

	_game_camera.make_current()
	_game_camera.position_smoothing_enabled = false
	
	# 摄像机死锁在地图物理正中心
	_game_camera.position = Vector2(
		_map_pixel_width / 2.0,
		_map_pixel_height / 2.0
	)


# ==========================================
# 核心状态机：每帧检查视口变化，动态重算缩放
# ==========================================
func _process(_delta: float) -> void:
	if _game_camera == null or _map_pixel_width <= 0:
		return

	# 获取当前 SubViewport 被外层强行设定的真实大小
	var current_size = get_viewport().get_visible_rect().size
	
	if current_size.x <= 0 or current_size.y <= 0:
		return
		
	# 如果视口尺寸与上一帧不同，立即触发重新缩放
	if current_size != _last_viewport_size:
		_last_viewport_size = current_size
		_apply_camera_zoom(current_size)


# 只需要替换最底下的这个应用缩放的函数：
func _apply_camera_zoom(v_size: Vector2):
	var scale_x = v_size.x / _map_pixel_width
	var scale_y = v_size.y / _map_pixel_height

	if allow_stretch_distortion:
		# 模式B：无视地图原始比例，X和Y独立强行拉伸（彻底没有灰边，但画面会变形）
		_game_camera.zoom = Vector2(scale_x, scale_y)
	else:
		# 模式A：保持等比例，取最小缩放比（保证全图可见且不变形，但非同比例边缘会有灰边）
		var adaptive_scale = min(scale_x, scale_y)
		_game_camera.zoom = Vector2(adaptive_scale, adaptive_scale)
