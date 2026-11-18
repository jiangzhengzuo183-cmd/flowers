extends Resource
## The same HUD supports per-level copy without maintaining separate UI scenes.
@export var chapter := "第一章"
@export var maze_names := PackedStringArray(["迷宫一","迷宫二","迷宫三"])
@export var explore_tasks := PackedStringArray(["请尽情探索这个迷宫并尝试找到出口。","迷宫似乎发生了变化，请尝试发现它并熟悉路线。","这是你和阿尔吉侬的终极比拼，全速前进吧！"])
@export var race_task := "这是你和阿尔吉侬的终极比拼，全速前进吧！"
