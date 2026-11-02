# 原始迷宫数据

`maze_01.json` 原样复制自本机 `D:\maze_01\maze_01.json`，不修改地图通道或路线。
完整坐标和数据说明见 [MAZE_01_SOURCE.md](MAZE_01_SOURCE.md)。

若在另一台电脑更新地图，请在项目根目录使用 PowerShell：

```powershell
Copy-Item -LiteralPath 'D:\maze_01\maze_01.json' -Destination '.\src\maze\data\maze_01.json'
npm run check:maze
```

坐标使用 `[row, col]`，世界坐标 x 向右、z 向下、y 向上；每格 2.4 米。
路线 A/B 为两条设计路线，地图还有其他可行路线。
