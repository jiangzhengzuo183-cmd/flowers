# 《献给阿尔吉侬的花束》互动叙事游戏

三人小组课程项目。项目以丹尼尔·凯斯的《献给阿尔吉侬的花束》为灵感，尝试将小说中的人物关系、智力变化与阿尔吉侬的命运转化为可交互的叙事体验。

> 当前初始化版本已使用 Vite + React + TypeScript + Three.js。以下命令与目录对应本次提交的实际项目。初始化前的完整 README 保存在 [README.before-initialization.md](docs/README.before-initialization.md)。

## 项目模块（暂定）

- **叙事与场景**：开场、对话、剧情推进、横向探索场景与场景切换。
- **迷宫玩法**：多轮迷宫测试、阿尔吉侬移动、最终逃离与追逐。
- **进步报告与证据系统**：报告文本变化、退化线索、证据收集与组合。

模块边界和负责人以团队后续确认的分工文档为准。

## 协作规则

1. `main` 是稳定主分支，不直接在 `main` 上开发。
2. 每项功能从最新的 `main` 创建独立分支，完成后通过 Pull Request 合并。
3. 开始工作前先同步最新代码，并阅读根目录的 `AGENTS.md` 与 `docs/TEAM_WORKFLOW.md`。
4. 不要擅自修改其他成员负责的模块、共享入口、全局样式或项目配置。
5. 合并前至少确认项目能够启动，并检查本次改动没有破坏已有功能。
6. 不要提交 API 密钥、密码、个人令牌、私有配置或大型无关构建产物。

## 本地开发

1. 安装带有 npm 的 [Node.js](https://nodejs.org/) 22.18+（22 系列）或 24+。
2. 打开项目根目录：这个目录中同时有 `package.json`、`index.html` 和 `src`。
3. 在此目录打开终端，运行：

```powershell
npm install
npm run dev
```

按终端显示的地址访问，通常为 `http://127.0.0.1:5173`。关闭终端前按 `Ctrl+C` 停止。端口被占用时 Vite 会显示另一个端口。

Windows 下也可以双击根目录的 `启动游戏.cmd`：首次运行自动安装依赖，然后启动并打开浏览器。保留命令窗口即可继续使用。

本次确认的本机项目根目录为：

```text
C:\Users\30968\Documents\ChatGPT\献给阿尔吉侬的花束
```

`D:\maze_01` 是原始地图资料目录。已将其中的 `maze_01.json` 原样复制到 `src/maze/data/maze_01.json`，本项目启动不再依赖 D 盘目录。其他成员克隆后使用各自克隆目录作为根目录。

若提示找不到 npm，请安装 Node.js 后重新打开终端。本次 Codex 环境只有内置 Node，因此额外下载了被 Git 忽略的本地 npm；在此环境也可用：

```powershell
node .tools/package/bin/npm-cli.js run dev
```

`.tools` 不提交到 GitHub，其他成员使用正常的 `npm` 命令。

## 当前可以体验的内容

- 故事：三段原创占位对话，可继续、重读，并进入迷宫。它们用于验证流程，后续由团队替换为正式剧本。
- 迷宫：从真实地图数据生成 19×19 灰盒，显示入口、出口与检查点。
- 观察：鼠标左键旋转、滚轮缩放、右键平移；触屏支持单指旋转、双指缩放和平移。
- 调试：路线 A / B 显示开关、隐藏路线、重置视角。默认隐藏路线。

当前为工程初始化与预览版本。人物模型、移动碰撞、阿尔吉侬 AI、计时、存档、报告与证据玩法尚未实现。

## 检查与构建

```powershell
npm run check:maze
npm run build
npm run preview
```

`check:maze` 使用 Node 原生 TypeScript 类型擦除，验证矩阵尺寸、cellWalls 一致性、开口、检查点、路线合法性与可达性；并检查部分异常数据会被拒绝。`build` 先做严格 TypeScript 检查，再生成 `dist/`。`preview` 只预览构建结果。

## 源码目录与接口

```text
├── package.json / package-lock.json  依赖与 npm 脚本
├── index.html / vite.config.ts / tsconfig.json
├── public/assets/                   后续图片、音频、模型
├── scripts/check-maze.mjs            地图数据检查
└── src/
    ├── main.tsx / App.tsx            入口与场景切换
    ├── styles.css                   原型基础样式
    ├── scenes/                      StoryScene 与 MazeScene
    ├── story/prologue.ts            对话数据
    ├── characters/characters.ts     角色名称与类型
    ├── ui/DialogueBox.tsx           对话组件
    └── maze/
        ├── data/                    原始 JSON 与数据说明
        ├── types.ts                 地图类型与坐标约定
        ├── validateMaze.ts           数据验证与可达性检查
        ├── mazeData.ts               读取并验证地图
        ├── createMazeWorld.ts        生成墙、地面、标记与路线
        ├── createMazeView.ts         摄像机、渲染与资源释放
        └── MazeViewport.tsx          React / Three.js 连接
```

叙事入口接收 `onEnterMaze()` 事件；`DialogueBox` 接收一条对话与翻页/重读回调。`MazeViewport` 接收 `MazeData`、`RouteId`（`none/A/B`）和重置计数。三维模块退出时释放渲染器、控制器、几何体、材质与监听器。Three.js 随迷宫场景按需加载，无需 React Three Fiber。

本次共享入口、样式与配置由初始化任务统一创建；后续功能变更继续遵守团队协作规则。

## 团队获取初始化版本

本次开发使用 `feature/initialize-game` 分支，经 Pull Request 检查后再合并到 `main`。在合并前，其他成员可运行：

```powershell
git clone --branch feature/initialize-game https://github.com/jiangzhengzuo183-cmd/flowers.git
cd flowers
npm ci
npm run dev
```

合并后按团队流程同步 `main`。首次安装可用 `npm install`；按锁文件复现环境建议使用 `npm ci`。

## 文档

- [团队协作流程](docs/TEAM_WORKFLOW.md)
- [Codex 项目协作规则](AGENTS.md)
