# item_data.gd
class_name ItemData
extends Resource

# 定義道具效果枚舉（方便在編輯器中下拉選擇）
enum ItemType {
	BOMB_UP,      # 增加炸彈上限
	EXPLOSION_UP, # 增加爆炸範圍
	SPEED_UP,           # 增加移動速度
}

@export var item_name: String = "未命名道具"
@export var item_type: ItemType
@export var value: float = 1.0 # 效果數值（例如：數量+1，範圍+1，速度+50.0）
@export var sprite_texture: Texture2D # 道具的地圖貼圖
@export var description: String = ""
