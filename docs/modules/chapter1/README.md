# 第一章内容测试 / 罗夏墨迹测试

基于仓库默认分支接入，正式技术栈仍是 Godot 4.7.2 Standard / Compatibility，面向电脑浏览器。完整流程为 DAY01 → DAY02 → DAY03–15 → DAY16–46；后续共24个运行节点，含两次原生墨迹观察、三次原迷宫体验、报告与可选探索。没有改动 `src/` 历史原型、地图数据或其他成员的迷宫脚本。

## 入口、运行、预览

1. Godot 导入仓库 `godot/project.godot`，按 F5。开场为合并页面，点击先显示完整文字，再点翻页；空格、Enter、右方向键也可翻阅。
2. 原生直达：`godot --path godot -- --preview-day02`、`--preview-part3` 或 `--preview-chapter4`。直达创建新的演示状态，不伪造前章报告已解锁；正式串联请使用F5普通入口。
3. 安装对应 Godot Web 导出模板后：

```powershell
godot --headless --path godot --editor --import --quit
New-Item -ItemType Directory -Path godot/exports/web -Force
godot --headless --path godot --export-release Web exports/web/index.html
node scripts/serve-godot.mjs
```

使用仓库原有 `启动游戏.cmd` 或服务提示的本机地址。网页查询参数 `?chapter=day02`、`?chapter=part3`、`?chapter=chapter4` 对应直达预览。保留导出生成的整个 `godot/exports/web/` 目录，兼容GitHub Pages子目录；不要用文件协议双击HTML。

引擎、导出包、`.godot`、`node_modules`、本地验证截图均不随本PR提交。根目录既有运行脚本和依赖清单保持原样。

## 目录与接口

| 目录／入口 | 作用 |
|---|---|
| `godot/scripts/story/story_scene.gd` | 现有主剧情路由，负责DAY01、正式报告与后续章节衔接 |
| `godot/scenes/bakery.tscn`、`scripts/story/bakery_*.gd`、`day01_scene_view.gd` | 面包店、人物／真实物件探索、夜校、交接本子、结束与报告 |
| `godot/data/bakery*.json`、`day01_extension.json` | DAY01原稿与已确认删减；夜校自动进入16句对话 |
| `godot/data/continuation.json`、`chapter4.json` | DAY02–46主线、可选对话、报告与素材映射；已补原缺失的四场和报告5–7 |
| `scripts/story/continuation_flow.gd` | 阅读、探索、迷宫、墨迹、报告状态；报告解锁与历史记录 |
| `scripts/story/ink_observation.gd`、`ink_field.gd`、`ink_flow.gdshader` | 原生四卡桌面及Flowmap；原已确认模块的移植 |
| `godot/web/ink-observation/` | 已确认小游戏的原始源码、许可证与素材；网页版由独立 iframe 加载原版效果，Godot 编辑器保留原生实现 |
| `scripts/story/report1_page.gd`、`designed_report.gd`、`data/report_artwork.json` | 按剧情日期直接展示用户提供的13张成品双页PNG；未提供新图的3月3／4日报告保留原排版 |
| `scripts/story/maze_gateway.gd`、`data/maze_slots.json` | 三次迷宫的独立场景接入接口，未配置时沿用原迷宫 |
| `assets/bakery`、`continuation`、`experience`、`report`、`audio` | 仅本模块所需人物、背景、物件、装饰、报告和本地音频 |
| `godot/ui/chapter1_theme.tres` | 第一章专用暖黄色主题；不替换全局 `game_theme.tres` |

主入口继续使用现有 `Main.show_scene("story")` 和 `StoryScene.enter_maze`。共享主脚本只增加剧情全画布布局，迷宫路由保留原工具栏；工程设计画布调整为1600×900，按16:9等比适配。

需要从其他剧情调用墨迹时，新建 `ink_observation.gd` 的Control实例并添加到内容宿主，暂时隐藏／禁用宿主输入；连接 `completed(result)`，在回调恢复原宿主。结果包含 `viewed` 和 `source`，不含分数、正确答案或强制看完条件。见 `ContinuationChapter.start_object()` 与 `_ink_completed()` 的实际接入。

- 单卡点击放大、鼠标Flowmap、滚轮缩放；点击卡片外或Esc仅放回四卡桌面。
- 只有桌面“结束观察”发出 `completed`，随后释放Control、Tween、事件和纹理／Shader引用。
- `ContinuationFlow.ink_observations` 按场景ID区分两次测试；每次首次结束接自己的后续独白，重复进入不重播、不重置章节。
- 切换小游戏无需新标签或整页重载。样式与键盘事件限于本Control生命周期。

网页版的实际接入、资源打包、完成回调与最新验证结果见 [已确认墨迹网页接入](../../已确认墨迹网页接入-20261120.md)。网页模式沿用同一个 `completed(result)` 接口，结束观察后恢复原场景树、画布和焦点；模块内部事件及 CSS 隔离在 iframe 生命周期内。

## 本次确认的视觉与交互

- 合并开场、右方向键；查理的独白显示查理。时间／离店旁白在画面中间显示，离店伴随逐渐走远的脚步声。
- 左上使用新纸条素材，面包店人物交谈的任务提示已删除，该阶段只显示地点。右上使用最新透明纸艺PNG：对话气泡、书本、齿轮；删除自动播放和重新开始的右上控件，保留底层功能。齿轮缩小约12%，间距收紧到10个设计像素；悬停轻微放大倾斜，点击短促回弹。夹子跨住黄色纸签与米白对话纸。
- 后续以Godot原生运行验收。纸艺设置独立封装：三个真实音频总线、静音、全屏／窗口、等比16:9／16:10适配、逐字速度、设置保存与恢复默认。详细文件清单与原生验证见[纸艺UI与设置系统交付](../../纸艺UI与设置系统交付-20261120.md)。
- 对话画面最多两人，包含切换过程；说话人保持亮色，对方明显压暗。夜校开头不提前显示爱丽丝，直接接入对话，删除原17–18句。
- 面包店真实物件热点、病房原物体探索、幸运物演出、新食堂与查理住处昼夜背景、便装、脚印书页、杂志、旋钮等必要素材已接入。
- 实验室音乐改为Morsi的CC0 `calm music`；来源与许可见 `godot/assets/audio/LICENSE-SOURCES.md`。音量、淡入淡出、自动阅读、只读历史与报告回看延续现有实现。
- 报告以 `report_artwork.json` 对应用户最新13张成品图，保持整张原图与原日期；合并日期的成品图映射到对应的各个报告节点。删除原深色报告中间菜单，剧情直接打开报告；继续进入后续剧情，回看关闭后留在原剧情，末章读完停留最后一页。
- 电视机剧情使用新的昼／夜房间背景，直接使用背景里的电视机，移除旧的独立电视叠图；电视和旋钮热点已对应新位置。实验室角落的小尼姆探索入口已移除，主线对白人物保留。
- 墨迹桌面删除顶部标题，底部显示操作提示；网页版通过宿主适配层注入，不修改原小游戏源码。

## 验证

```powershell
godot --headless --path godot --script res://tests/check_project.gd
godot --headless --path godot --script res://tests/check_unified_chapter1.gd
godot --headless --path godot --script res://tests/check_report_and_maze.gd
```

第一个检查保留原地图／碰撞／路线／镜头断言，适配正式剧情的开场和路由；第二个覆盖24场与全部可选对白、报告5–7补齐、两次墨迹状态、右方向键、夜校直连、双人上限和报告回看。浏览器检查还应覆盖：咨询室进入 → 任意单卡 → Flowmap → Esc放回 → 结束观察 → 原场景续读 → 重复进入。

开发走查按钮由 `godot/data/experience.json` 的 `development` 控制。迷宫开发按钮调用真实完成回调，结果 `development_skip=true`、`seconds=null`、`score_valid=false`，不能当作正式计分；发布前可关闭。

## 小组接入注意

- 本模块不合并其他迷宫功能分支；三次迷宫从下述独立接口接入，空槽位继续使用原迷宫。第三次比赛的“查理胜／输／连赢”来自剧本，和玩家体验的实际计时数据分别保存，没有伪造多局成绩。
- 范妮、乔、弗兰克、艾伦没有明确确认的对应透明立绘时，保留原台词与简洁入口，不拿其他人物冒充；童年回忆用黑底文字，待明确素材后再换图。
- 数据来自用户整套梳理图，保留刻意错字和日期。报告9的“3月29日”与前章3月31日顺序存在原稿冲突，当前没有擅自改日期；组员可在统一剧本时确认。
- 沿用会话内状态，不宣称已经实现跨关闭窗口的剧情存档。
- 思源黑体附带OFL；手写字体为用户指定并要求随模块提交的原文件，原有授权核查在 `assets/fonts/REPORT-FONT-LICENSE.md`，未伪造新许可证。正式公开发行前请团队核对对应授权范围。
- 本次共享变更仅为正式剧情入口、Web启动参数、16:9画布和原基线测试的剧情断言；其他模块脚本、全局主题与npm依赖保持原样。

## 三个迷宫的接入方法

| 轮次 | 槽位 | 剧情节点 |
|---|---|---|
| 1 | `maze_01` | `d2-maze` |
| 2 | `maze_02` | `p3-maze` |
| 3 | `maze_03` | `p4-maze` |

将 `godot/data/maze_slots.json` 对应轮次的 `scene_path` 填为自己的 `.tscn` 资源路径，例如 `res://scenes/maze/round_01.tscn`。也可以在进入对应迷宫前调用 `ContinuationChapter.register_maze_scene(1, packed_scene)`；运行时注册优先。空路径保留旧迷宫，不阻断目前剧情。

自有场景根节点继承 `Control`，提供 `signal finished(result: Dictionary)`。可选 `configure(context: Dictionary)` 在加入场景树前调用，收到 `round_number`、`slot_id`、`story_scene`；根节点铺满宿主区域。提供 `paused` 属性时，设置／历史弹窗的暂停状态会传给它。

完成时发送真实结果，例如 `finished.emit({"seconds": elapsed, "score_valid": true, "player_finished": true})`。网关补上轮次与槽位，防止重复完成。没有实际计时时传 `seconds: null, score_valid: false`；开发跳过也必须标记 `development_skip: true`。只有第二轮接受 `withdrawn: true`。自有场景可发出无参数 `cancelled` 返回探索，不提交成绩、不推进剧情。网关释放当前场景；自有模块负责清理自身事件和临时资源。
