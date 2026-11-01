# Godot 游戏数据

`maze_01.json` 是当前 Godot 版本的地图来源，原样复制自仓库 `src/maze/data/maze_01.json`（最初来源为 `D:\maze_01\maze_01.json`）。SHA-256：

```text
F186DB1678D73B5F90821290D09A31ABC8516BF1B9AA4A7E10A65F4EA0F87BFB
```

后续地图更新以本目录为准；旧 `src/maze/data/` 保留为网页版原型参考，不需要维护两套实现。

地图坐标为 `[row, col]`，世界坐标为 x 向右、z 向下、y 向上。Godot 解析 JSON 时将数字视为浮点数，脚本会在数组索引和网格遍历处明确转为整数。墙高 3.2、墙厚 0.3、每格 2.4 米。

`prologue.json` 沿用旧原型的三段原创占位文本。正式剧情、选择分支、角色立绘、存档与报告功能后续扩展。

导出预设显式包含 `data/*.json`，保证在浏览器中仍可读取这些数据。详细地图说明见 `MAZE_01_SOURCE.md`。
