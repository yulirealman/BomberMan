@tool
extends Node

@export_category("UI Settings")
@export_range(0.0, 1.0) var right_ui_width_ratio: float = 0.2
@export_range(0.0, 1.0) var bottom_ui_height_ratio: float = 0.1

# ==========================================
# 新增：布局模式开关
# ==========================================
@export_category("Layout Scaling Mode")
@export var fill_entire_safe_area: bool = false # 开关：是否无视比例，填充满整个安全区
@export var game_aspect_ratio: float = 4.0 / 3.0 # 当上方开关为 false 时，强制保持的比例

@onready var viewport_container: SubViewportContainer = $SubViewportContainer
@onready var ui_right: ColorRect = $ColorRect
@onready var ui_bottom: ColorRect = $ColorRect2

func _ready() -> void:
	if not Engine.is_editor_hint():
		get_tree().get_root().size_changed.connect(update_layout)
	update_layout()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		update_layout()

func update_layout() -> void:
	if not is_instance_valid(viewport_container) or not is_instance_valid(ui_right) or not is_instance_valid(ui_bottom):
		return

	var window_size = get_viewport().get_visible_rect().size
	var w = window_size.x
	var h = window_size.y
	if w <= 0 or h <= 0: return

	# 1. 划分右侧和底部 UI
	var right_w = w * right_ui_width_ratio
	ui_right.size = Vector2(right_w, h)
	ui_right.position = Vector2(w - right_w, 0)

	var bottom_w = w - right_w
	var bottom_h = h * bottom_ui_height_ratio
	ui_bottom.size = Vector2(bottom_w, bottom_h)
	ui_bottom.position = Vector2(0, h - bottom_h)

	# 2. 获取剩余可用安全区
	var game_area_w = bottom_w
	var game_area_h = h - bottom_h

	# ==========================================
	# 3. 算法分支：根据开关选择切割策略
	# ==========================================
	if fill_entire_safe_area:
		# 模式B：完全填满
		viewport_container.size = Vector2(game_area_w, game_area_h)
		viewport_container.position = Vector2(0, 0)
	else:
		# 模式A：保持指定比例，尽量放大并居中
		var target_w = game_area_w
		var target_h = target_w / game_aspect_ratio

		if target_h > game_area_h:
			target_h = game_area_h
			target_w = target_h * game_aspect_ratio

		viewport_container.size = Vector2(target_w, target_h)
		var offset_x = (game_area_w - target_w) / 2.0
		var offset_y = (game_area_h - target_h) / 2.0
		viewport_container.position = Vector2(offset_x, offset_y)
