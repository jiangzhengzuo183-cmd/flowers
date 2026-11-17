# 墨迹卡片观察模块

本文件夹可整体提交到小组仓库，或放入 `modules/ink-observation/`。保留已确认的画面、卡片摆放、悬停、拿起／放回、增强 Flowmap、1—1.35 倍滚轮缩放和现有叙事流程，没有新增可见按钮或提示。原型仍是原生 HTML/CSS/JavaScript，不引入框架。

## 文件结构

| 文件 | 用途 |
| --- | --- |
| `index.html` | 单独运行的演示入口，也是模块 iframe 的内容页 |
| `module.js` | 对外 ES Module 入口：创建、挂载、退出、完成与销毁 |
| `integration.html` | 可直接运行的挂载示例，与独立演示具有相同画面 |
| `app.js` | 卡片状态、动画、键盘／点击／滚轮、叙事及生命周期 |
| `flow.js` | 保留的透明墨迹流场实现，包含显式 GPU 资源释放 |
| `style.css` | 原有样式，仅在 iframe 文档中生效 |
| `config.js` | 卡片、布局、动画、缩放和 Flowmap 集中配置 |
| `assets/` | 四张墨迹、桌面、纸纹、本地思源黑体及字体许可证 |
| `ASSETS.md` | 素材来源、AI 重制标注和来源记录的局限 |
| `server.cjs` / `start.cmd` / `start.ps1` | 可选的本机静态预览服务和 Windows 启动入口 |
| `package.json` | 预览和可选开发测试命令；没有运行时 npm 依赖 |
| `verify*.cjs` / `verification/` | 可选浏览器检查、结果与截图 |
| `CHANGES.md` / `TEAM-NOTE.md` | 本次文件整理清单、可转发的组员接入说明 |
| `.nojekyll` / `.gitignore` | GitHub Pages 与仓库忽略规则 |

## 启动和预览

安装 Node.js LTS 后，在本目录运行 `npm start`，或 Windows 双击 `start.cmd`。**预览不需要执行 npm install**，也不需要构建。默认打开／访问：

- 单独演示：http://127.0.0.1:4185/
- 接入示例：http://127.0.0.1:4185/integration.html

保持服务终端开启；Ctrl+C 停止。端口占用时，用 PowerShell `$env:PORT=4186; npm start` 或其他 shell 的相应环境变量写法。也可以用任意静态 HTTP 服务托管整个文件夹。请不要用 `file://` 双击 HTML：浏览器会限制 ES Module 和图片纹理的本地访问。

## 最小接入示例

只引入 `module.js`，**不要把 style.css、app.js 或 config.js 注入主项目文档**。模块采用同源 iframe，原有 document/window 事件、变量和 CSS 全部留在 iframe 内；不会设置宿主的 body、滚动、字体或全局快捷键。挂载容器必须有明确宽高。

```html
<div id="ink-scene" style="width:100%;height:100dvh"></div>
<script type="module">
  import {createInkObservation} from './modules/ink-observation/module.js';

  const observation = createInkObservation({
    onEnter() { console.log('模块就绪'); },
    onExit() { console.log('模块已退出'); },
    onComplete(result) {
      // result = { viewed: ['I', ...], missing: [], data: 自定义剧情数据 }
      // 在这里通知剧情系统；没有强制查看四张或正确答案。
      console.log(result);
    }
  });

  await observation.enter(document.querySelector('#ink-scene'));
  // 把 observation 保存在宿主当前场景对象中，供剧情系统调用。
</script>
```

如果整体项目使用 Godot：本包仍是网页模块，并非 Godot 原生节点。可由 WebView 或网页容器加载完整模块页面；纯网页宿主按上述示例挂载。本次没有改动 Godot 工程、章节路由或小组主项目。

## 进入、退出与接回剧情

```js
// 剧情系统决定何时完成观察；玩家界面不会新增“完成”按钮。
observation.complete({ nextScene: 'bert' });
observation.exit();
// 接着由宿主调用自己的后续剧情 API。

// 同一对象可再次进入，观察记录与缩放回到初始状态。
await observation.enter(document.querySelector('#ink-scene'));

// 宿主场景最终销毁时调用，之后不可再用这个对象进入。
observation.destroy();
```

- `enter(container): Promise`：等待素材加载；同一容器重复调用复用本次挂载，不重复绑定。切换容器前先 exit。
- `exit(): void`：可重复调用；清理定时器、RAF、ResizeObserver、事件、WebGL 纹理／缓冲／程序／着色器／上下文和 iframe。即使仍在加载，也会取消进入，进入 Promise 以 `AbortError` 拒绝，宿主需捕获。
- `complete(data): result | null`：每次进入只触发一次 `onComplete`，重复调用返回 null。只发出结果，不自动关闭或跳转，方便宿主决定后续剧情。未进入／未就绪时调用会报错。
- `destroy(): void`：退出并永久销毁适配器实例。
- `mounted: boolean`：当前是否存在挂载（包括加载过程）。

卡片外部点击是指**模块 iframe 视口内**的卡片外区域（含 16:9 留边）。宿主其他区域的点击和快捷键由宿主处理。如宿主希望离开整个模块，直接调用 exit。不要给 iframe 再添加阻止同源访问的 sandbox；模块入口会通过同源生命周期 API 管理资源。需要跨域时应另行实现明确的消息协议，本版同源使用。

## 调整参数与替换素材

只改 `config.js`：

- `cards`：固定中心位置 x/y（舞台百分比）、角度 angle、图片 src、透明模式 background。
- `layout`：桌面卡片大小、比例、观察大小和中心位置、悬停高度。
- `animation`：拿起／放回时长、自然缓动、减少动态效果时长。
- `zoom`：最小 1、最大 1.35、滚轮灵敏度、缩放时长、边缘留白；实际最大值随窗口自动收紧。
- `flow`：强度 0.80、半径 0.1875、位移上限 0.045、恢复系数 3.8、惯性 0.12、速度影响 0.65。当前确认效果保留。

素材位于 assets，相对路径从 `index.html` 所在目录解析。现有四张均带透明通道，使用 transparent，保持颜色、方向、比例和内部留白。替换后重新进入／刷新。字体路径在 style.css 的 @font-face 中。不要移动部分文件后保留错误的相对关系。

## GitHub Pages 仓库子路径

例如仓库为 `group-game`，本包位于 `modules/ink-observation/`，发布后：

`https://<组织或用户名>.github.io/group-game/modules/ink-observation/index.html`

本包不使用 `/assets/...` 根路径或本机路径。`module.js` 通过 `new URL('./index.html', import.meta.url)` 定位页面，页面素材和 CSS 字体继续使用相对路径，因此仓库前缀无需硬编码。**没有构建步骤，也无需设置 Vite base 或 publicPath。** 在 Pages 中发布包含此文件夹的仓库目录／静态产物即可；本包带 `.nojekyll`。如果小组已有打包器，将整个文件夹原样复制进静态公开目录，勿只打包 module.js 而漏掉它定位的 HTML 和 assets。不需要 server.cjs 或 Node 后端在线运行。

## 素材与许可

详见 ASSETS.md。四张墨迹使用用户提供的重制游戏图，按 AI 重制素材标注，非标准原版图版扫描件；本次整理没有生成或重画墨迹。原始生成记录、提示词和授权链未提供，不能把它们写成已核验的官方／公共领域扫描图。思源黑体的 SIL OFL 原文已随包保留。代码沿用现有原型，未替小组指定开源许可证。

## 验证

普通预览没有 npm 依赖。只有要运行开发检查时才执行：

```sh
npm install
npx playwright install chromium
npm test
```

三个检查依次覆盖四卡、Flowmap、返回与防穿透、缩放与鼠标坐标、窗口变化、静态降级、隔离与反复挂载释放、仓库子路径。报告和截图位于 verification。可通过环境变量 PLAYWRIGHT_CHROMIUM_EXECUTABLE 选择本机已有 Chromium 浏览器，不在文件中固定个人电脑路径。没有 build 命令，因为源码即静态产物。
