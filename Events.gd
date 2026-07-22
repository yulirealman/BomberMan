extends Node

# 定义一个全局信号：当玩家的数据准备好时发出，并带上这份数据
signal player_data_initialized(data: PlayerData)

# 你甚至可以把之前的信号也移到这里，实现更彻底的解耦
# signal bomb_amount_changed(new_value: int)
