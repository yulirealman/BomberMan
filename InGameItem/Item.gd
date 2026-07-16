# item.gd
class_name InGameItem
extends Area2D

# 在編輯器中，你可以把剛才創建的 .tres 拖到這裡作為預設值
@export var item_data: ItemData

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_component:HealthComponent = $HealthComponent

func _ready() -> void:
	# 根據注入的 Resource 數據，動態加載貼圖
	if item_data != null:
		sprite.texture = item_data.sprite_texture
		
	# 監聽與玩家的碰撞
	body_entered.connect(_on_body_entered)
	health_component.health_depleted.connect(_on_death)
	
func _on_death()->void:
	queue_free()
	
	
func _on_body_entered(body: Node2D) -> void:
	# 安全地轉換為 Player
	var player := body as Player
	if player != null:
		# 讓玩家自己去消費這個道具數據
		player.apply_item_effect(item_data)
		# 播放拾取特效/音效（可選）
		queue_free()
