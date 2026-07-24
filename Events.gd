extends Node

# 定义一个全局信号：当玩家的数据准备好时发出，并带上这份数据
signal player_data_initialized(data: PlayerData)

# 你甚至可以把之前的信号也移到这里，实现更彻底的解耦
# signal bomb_amount_changed(new_value: int)


# 🔴 修改 1：信号增加第一个参数，声明为 Player 类型，把自身传递给 Level 监听器
signal bomb_placement_requested(player_id: int, world_pos: Vector2, power: int, bomb_amount:int)

# 炸弹爆炸，通知对应玩家回充可用数量 (Bomb -> Player)
signal player_bomb_freed(player_id: int)


# 声明放炸弹失败的信号
signal bomb_placement_failed(player_id: int)

signal player_pos_changed(player:Player,  at_grid_pos: Vector2i)


# 定义消息协议：坐标、被毁的是什么实体
signal grid_entity_destroyed(grid_pos: Vector2i, entity_id: int, entity_type:String)
