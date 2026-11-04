# 《献给阿尔吉侬的花束》互动叙事游戏

三人小组课程项目，以丹尼尔·凯斯的《献给阿尔吉侬的花束》为灵感。当前开发方向为 **Godot 统一制作、优先发布电脑浏览器版本**，组合 2D 剧情与 3D 迷宫。

当前本地 Maze 01 已接入新版灰模：圆形教堂、六处高低空间、下沉石廊、拱形桥洞和可手动平视/轻微仰视的镜头。继续用原来的 Godot 工程，按 **F5** 即可进入新版；原地图数据和旧迷宫场景保留。详见 [Maze 01 灰模说明](docs/MAZE_01_GREYBOX.md)。源码交付分支为 `codex/maze-01-delivery`；本轮未重新导出网页。

## 先打开哪里

本机仓库根目录：

```text
C:\Users\30968\Documents\ChatGPT\献给阿尔吉侬的花束
```

Godot 工程根目录是上面目录中的 `godot`，在 Godot 项目管理器中导入：

```text
C:\Users\30968\Documents\ChatGPT\献给阿尔吉侬的花束\godot\project.godot
```

- 开发游戏：双击根目录 `打开Godot工程.cmd`，或手动导入 `godot/project.godot`，按 F5 直接进入迷宫试玩。
- 查看网页成品：本机已完成导出时，双击 `启动游戏.cmd`，在 `http://127.0.0.1:5180/` 预览。
- 其他成员本机试玩只需安装 Godot 并导入工程；需要网页版本时才另外导出。导出产物与引擎程序不提交到源码仓库。

## 基础版本功能（旧迷宫场景保留）

- 启动后直接进入查理迷宫试玩，不再经过开场剧情页；当前界面不显示“故事”入口。占位剧情源文件保留供叙事模块后续使用。
- 原样读取 `godot/data/maze_01.json`，生成 19×19 迷宫、378 段墙与地面。
- 入口、出口、三个检查点；路线 A（60 步）/B（92 步）显示开关，默认隐藏。
- 对称等距正交镜头：固定俯仰角；左键旋转，松开后按 90 度对齐；滚轮缩放、右键平移、重置视角。
- “柔和配色”仅示意美术方向，当前墙体与地面对比不足，试玩建议保持默认灰盒配色；正式美术后续统一处理。
- 已建立墙体和地面碰撞形状，供后续人物移动使用。
- 查理模型与骨骼动画已接入迷宫：WASD / 方向键走路，按住 Shift 跑步，松开或撞墙停止时恢复待机。鼠标拖动观察，滚轮调整距离，镜头平滑跟随；可切回全图查看、回到入口。步行时使用矮墙显示以便看清人物，完整墙体碰撞与原地图保持不变。
- 滚轮支持大范围缩放：行走镜头距离 2.5–150，拉远后逐渐对准地图中心并提高俯视角。可一键“俯视全貌”，正交俯视自动容纳全图，拖动平移、滚轮细看；点击“亲自走迷宫”返回人物操作。

查理基础模型与待机、走路、跑步动画已可试玩。走路速度 1.6 米/秒，跑步 2.7 米/秒，步频随实际速度匹配。默认采用距离 2.8 米、48° 视野的近距离第三人称镜头，仍可拖动、缩放和重置；迷宫使用 AgX 色彩映射、较低对比度和补光，让角色更接近动画 GIF。跑步手臂已收拢，原版模型保留，游戏使用 `charlie_refined.glb` 修正版。阿尔吉侬 AI、计时、正式剧情、存档、报告与证据玩法仍待开发。迷宫暂不支持跳跃，地图外边界限制在地面范围内；Jump 动画保留在角色独立预览中。角色与测试细节见 [角色说明](art/characters/charlie/README.md)。

## 安装、检查与网页导出

本次实际使用 **Godot 4.7.2 Standard + GDScript**，不需要 .NET。建议团队统一这个版本。官方下载：https://godotengine.org/download/windows/

1. 在 Godot 项目管理器导入 `godot/project.godot`。
2. 在编辑器菜单“编辑器 → 管理导出模板”安装同版本模板。
3. 选择“项目 → 导出”，使用仓库已有的 **Web** 预设，导出到 `godot/exports/web/index.html`。
4. 在仓库根目录运行以下预览命令，或双击 `启动游戏.cmd`：

```powershell
node scripts/serve-godot.mjs
```

预览服务需要 Node.js；本机启动脚本也兼容已确认存在的 Codex 内置 Node。其他电脑可安装 Node.js 24。正常运行 Godot 编辑器和最终发布的网页游戏均不需要玩家安装 Node。

使用命令行检查和导出（`godot` 替换为自己电脑上的 Godot 可执行文件路径）：

```powershell
godot --headless --path godot --editor --import --quit
godot --headless --path godot --script res://tests/check_project.gd
godot --headless --path godot --fixed-fps 60 --script res://tests/characters/check_charlie.gd
godot --headless --path godot --fixed-fps 60 --script res://tests/characters/check_maze_charlie.gd
godot --headless --path godot --export-release Web exports/web/index.html
node scripts/serve-godot.mjs
```

本机便携版位于被 Git 忽略的 `.tools/godot/`。该目录不属于共享源码，也不需要放进 GitHub。已生成的网页压缩包位于 `godot/exports/flowers-godot-web.zip`；该文件需要构建后才存在。

## 网页表现与美术方向

开发与网页导出统一使用 Compatibility 渲染；Web 预设使用单线程，不要求跨源隔离响应头。主要目标为电脑键鼠浏览器，当前已用 Edge 实际验证。其他浏览器、移动设备和低性能设备仍需要单独测试，不能承诺所有设备完全一致。

等距/正交构图、简洁几何建筑、奶油色与淡紫色、定向光影、角色动画等可以围绕这个配置制作。以网页导出的实际表现为验收依据，不依赖只有其他渲染模式才有的特效。视错觉、可旋转建筑、楼梯机关等属于后续专门的关卡设计，本次迁移尚未实现。

中文字体随资源包嵌入，减少不同电脑上字体与换行的差异。思源黑体许可证保存在 `godot/assets/fonts/LICENSE.txt`。

网页加载画面使用 `godot/web/game.html`，与游戏的奶油色和绿色界面保持一致，显示真实下载进度。默认 Godot 启动画面已关闭，未额外设置展示等待时间。下载和引擎初始化仍需时间；失败时显示重试提示。

网页首次需要加载引擎与素材。当前导出的原始引擎 WASM 约 39.5 MB、资源包约 16.7 MB（未计网络压缩，实际大小以本次导出为准）。正式发布应启用服务端压缩与缓存，并继续控制纹理、模型和音频大小。

## 分享给别人

`127.0.0.1` 是本机预览地址。要让别人点链接玩，需要把 `godot/exports/web/` 中的**整套文件**放到支持 HTTPS 的静态托管服务，或上传网页压缩包到支持 HTML 游戏的平台。

HTML、JS、WASM、PCK、图片和音频 worklet 文件需要保持导出时的文件名。服务器应为 `.wasm` 返回 `application/wasm`。本次完成了源码迁移、网页导出与本地预览，尚未发布公开游戏网址。

官方参考：[Godot 网页导出](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)。

## 目录与模块接口

```text
godot/
├── project.godot / export_presets.cfg
├── scenes/                 主入口、剧情、迷宫场景，可在 Godot 中编辑
├── scripts/
│   ├── main.gd             场景切换
│   ├── story/              读取剧情、翻页与重读
│   └── maze/               地图校验、生成、镜头与场景组合
├── data/                   当前地图与剧情 JSON
├── ui/                     统一主题与字体设置
├── assets/                 矢量插画、图标与授权字体
├── tests/check_project.gd  地图异常检查与场景流程检查
└── exports/                本机构建产物，Git 忽略
scripts/serve-godot.mjs      本地网页预览服务
```

- `MazeLoader.load_map(path)` 返回 `ok/data/metrics` 或 `ok/error`，在生成前验证矩阵、格子墙体、开口、检查点、路线与全图可达性。
- `GeneratedMaze.build(maze)` 生成网格、碰撞、标记与路线；`set_route(id)` 切换路线。
- `StoryScene.enter_maze` 信号请求主入口切换；剧情内容在 JSON 中编辑。
- `CameraRig.configure(width, depth)` 配置观察范围；鼠标事件仅从迷宫预览区进入。
- `WalkPlayer.configure(entry, size, width, depth)` 配置出生点与边界；移动使用摄像机方向和真实墙体碰撞。`FollowRig.configure(player)` 配置跟随目标；`MazeScene.set_walk_mode(enabled)` 切换行走与全图查看，仅调整墙体显示高度。

## 历史原型与团队协作

根目录的 `src/`、`public/`、`package.json` 等 React + Three.js 文件保留为历史原型参考。原型可通过 `启动旧版原型.cmd` 或原 npm 命令运行；后续正式开发以 `godot/` 为准。

旧 README 已完整保留为 [网页版原型说明](docs/README.web-prototype.md)，最初的仓库说明保存在 [初始化前 README](docs/README.before-initialization.md)。原始地图资料仍在 `D:\maze_01`，运行不再依赖这个目录。

`main` 为稳定分支。本次完整 Maze 01 灰模交付位于 `codex/maze-01-delivery`，基于已带查理与动画的版本；由团队通过 Pull Request 检查后再合并。组员已有克隆时：先关闭 Godot，保存自己的工作，在 GitHub Desktop 点击 Fetch origin，切换到 `codex/maze-01-delivery`，如显示 Pull origin 则点击更新。再用 Godot 导入同一仓库的 `godot/project.godot`，等待首次导入完成，点击编辑器右上角 ▶ 运行项目（Windows 也可按 F5）。切换分支时如提示保留改动，应将自己的改动留在原分支，不混入试玩分支。

试玩无需重新克隆，也无需发布网页；其他成员本机应安装相同版本的 Godot。Windows 根目录灰模启动脚本为可选入口，macOS 请直接通过 Godot 项目管理器打开工程。

后续成员从团队确认的最新稳定版本创建各自功能分支，避免同时编辑共享场景、主题和配置。首次下载本次试玩可直接克隆：

```powershell
git clone --branch codex/maze-01-delivery https://github.com/jiangzhengzuo183-cmd/flowers.git
```

- [团队协作流程](docs/TEAM_WORKFLOW.md)
- [Codex 项目协作规则](AGENTS.md)
