# 《献给阿尔吉侬的花束》互动叙事游戏

三人小组课程项目，以丹尼尔·凯斯的《献给阿尔吉侬的花束》为灵感。当前开发方向为 **Godot 统一制作、优先发布电脑浏览器版本**，组合 2D 剧情与 3D 迷宫。

## 先打开哪里

本机仓库根目录：

```text
C:\Users\30968\Documents\ChatGPT\献给阿尔吉侬的花束
```

Godot 工程根目录是上面目录中的 `godot`，在 Godot 项目管理器中导入：

```text
C:\Users\30968\Documents\ChatGPT\献给阿尔吉侬的花束\godot\project.godot
```

- 开发游戏：双击根目录 `打开Godot工程.cmd`，或手动导入 `godot/project.godot`，按 F5 运行。
- 查看网页成品：本机已完成导出时，双击 `启动游戏.cmd`，在 `http://127.0.0.1:5180/` 预览。
- 其他成员第一次克隆时，需要先安装 Godot 并导出网页；导出产物与引擎程序不提交到源码仓库。

## 当前能体验什么

- 三段原创占位对话：继续、重读、进入迷宫。
- 原样读取 `godot/data/maze_01.json`，生成 19×19 迷宫、378 段墙与地面。
- 入口、出口、三个检查点；路线 A（60 步）/B（92 步）显示开关，默认隐藏。
- 正交镜头：左键旋转、滚轮缩放、右键平移、重置视角。
- “柔和配色”可预览奶油色墙体与淡紫色背景，并返回灰盒；此功能仅示意美术方向。
- 已建立墙体和地面碰撞形状，供后续人物移动使用。

角色建模、移动控制、阿尔吉侬 AI、计时、正式剧情、存档、报告与证据玩法仍待后续开发。

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
godot --headless --path godot --export-release Web exports/web/index.html
node scripts/serve-godot.mjs
```

本机便携版位于被 Git 忽略的 `.tools/godot/`。该目录不属于共享源码，也不需要放进 GitHub。已生成的网页压缩包位于 `godot/exports/flowers-godot-web.zip`；该文件需要构建后才存在。

## 网页表现与美术方向

开发与网页导出统一使用 Compatibility 渲染；Web 预设使用单线程，不要求跨源隔离响应头。主要目标为电脑键鼠浏览器，当前已用 Edge 实际验证。其他浏览器、移动设备和低性能设备仍需要单独测试，不能承诺所有设备完全一致。

等距/正交构图、简洁几何建筑、奶油色与淡紫色、定向光影、角色动画等可以围绕这个配置制作。以网页导出的实际表现为验收依据，不依赖只有其他渲染模式才有的特效。视错觉、可旋转建筑、楼梯机关等属于后续专门的关卡设计，本次迁移尚未实现。

中文字体随资源包嵌入，减少不同电脑上字体与换行的差异。思源黑体许可证保存在 `godot/assets/fonts/LICENSE.txt`。

网页首次需要加载引擎与素材。本次导出的原始引擎 WASM 约 39.5 MB、资源包约 7.8 MB（未计网络压缩）。正式发布应启用服务端压缩与缓存，并继续控制纹理、模型和音频大小。

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

## 历史原型与团队协作

根目录的 `src/`、`public/`、`package.json` 等 React + Three.js 文件保留为历史原型参考。原型可通过 `启动旧版原型.cmd` 或原 npm 命令运行；后续正式开发以 `godot/` 为准。

旧 README 已完整保留为 [网页版原型说明](docs/README.web-prototype.md)，最初的仓库说明保存在 [初始化前 README](docs/README.before-initialization.md)。原始地图资料仍在 `D:\maze_01`，运行不再依赖这个目录。

`main` 为稳定分支。迁移在 `feature/godot-migration` 开发，提交 Pull Request，由负责人审阅后合并。后续成员从最新主分支创建各自功能分支，避免同时编辑共享场景、主题和配置。

- [团队协作流程](docs/TEAM_WORKFLOW.md)
- [Codex 项目协作规则](AGENTS.md)
