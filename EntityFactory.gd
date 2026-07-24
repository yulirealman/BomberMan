class_name EntityFactory
extends RefCounted

# 存放从 JSON 读入的实体配置：{ "1": "res://...", "2": "res://..." }
static var _entity_db: Dictionary = {}
# 存放已加载的场景缓存 (按需加载)：{ "1": PackedScene, ... }
static var _scene_cache: Dictionary = {}

# ==========================================
# 1. 数据库初始化（游戏启动时调用一次）
# ==========================================
static func initialize_db(db_path: String = "res://Data/EntitiesDB.json"):
	# 如果已经加载过，就不重复加载
	if not _entity_db.is_empty():
		return
		
	var file = FileAccess.open(db_path, FileAccess.READ)
	if file == null:
		push_error("EntityFactory 致命错误: 找不到实体数据库文件 -> ", db_path)
		return
		
	var raw_data = JSON.parse_string(file.get_as_text())
	file.close()
	
	# 解析并提取我们需要的数据 (ID -> 路径)
	for key in raw_data:
	# === 修正：直接把整个字典存下来 ===
		_entity_db[key] = raw_data[key]
		
	print("EntityFactory: 实体数据库装载完毕，共包含 ", _entity_db.size(), " 种实体。")

# ==========================================
# 2. 生产工厂（懒加载机制）
# ==========================================
static func create_entity(id: int, params: Dictionary = {}) -> Node2D:
	var str_id = str(id) # 因为 JSON 里的键必定是字符串，所以这里转一下
	
	if not _entity_db.has(str_id):
		push_warning("EntityFactory 警告: 尝试生成数据库中不存在的 ID -> ", id)
		return null
		
	# 【按需懒加载】：如果内存缓存里没有，就去硬盘读取（只读一次）
	if not _scene_cache.has(str_id):
		var path = _entity_db[str_id]["path"]
		var packed_scene = load(path) as PackedScene
		if packed_scene == null:
			push_error("EntityFactory 错误: 无法加载场景资源，请检查路径 -> ", path)
			return null
		_scene_cache[str_id] = packed_scene
		
	# 瞬间实例化（极速）
	var instance = _scene_cache[str_id].instantiate() as Node2D
	
	if "entity_id" in instance:
		instance.entity_id = id
			
	if "entity_type" in instance:
		# 这里完美利用了你的 JSON 里的 "type": "destructible"
		instance.entity_type = _entity_db[str_id]["type"] 
			
	if "entity_name" in instance:
		instance.entity_name = _entity_db[str_id]["name"]	
	
	
	# 数据注入接口：给带有 setup 方法的实体塞数据（比如掉落率）
	if not params.is_empty() and instance.has_method("setup"):
		instance.setup(params)
		
	return instance

# ==========================================
# 3. 内存释放（切关卡时调用）
# ==========================================
static func clear_cache():
	_scene_cache.clear()
	print("EntityFactory: 旧关卡实体缓存已清理，内存已释放。")
