# 电视机特效原型

独立模块，供迷宫后续接入。入口是 `tv_fx_preview.tscn`；可复用道具是 `tv_fx.tscn`。

## 模型检查结果（先检查后实施）

- 来源：用户在原会话上传的 `复古显示器3d模型.glb`，复制为 `assets/retro_monitor.glb`，二进制不变。
- 文件 3,613,480 字节；glTF 2.0；生成器标记为 Beijing VAST / Tripo。
- 层级：`RootNode → tripo_node_0b78e457`。一个网格 `tripo_mesh_0b78e457`，一个三角形 surface，没有骨骼或动画。
- 56,623 个顶点、291,312 个索引，即 97,104 个三角面。
- 一个材质 `tripo_mat_0b78e457`：金属度 0、粗糙度约 0.9；一张嵌入的 4096×4096 JPEG 色彩贴图，无独立法线贴图。
- 一套 TEXCOORD_0，U 范围约 0.000428–0.999572，V 范围约 0.028756–0.999572。屏幕、机壳、按钮共用图集，屏幕跨多个 UV 岛，并非独立的 0–1 矩形 UV。
- 原始包围盒：X -44.1832–44.1832；Y 0–99.9741；Z -49.1466–49.1466。屏幕朝 **+X**，正面看向屏幕时右方是 **-Z**。所有原始变换、尺寸与比例保留，未擅自假定这些数值是米或厘米。
- 实际导入并检查了前、后、两侧视图。玻璃表面有曲率，不能把普通平面直接放到最大 X 位置，否则会浮在边框前。

结论：不能直接替换“独立屏幕材质”，因为模型没有这个材质槽；可以增加独立屏幕 Shader 层。原屏幕的警告图案和粉绿配色保留。

## 实现范围和接口

仅新增本目录。不改共享入口、全局主题、项目配置、依赖或其他成员模块。

`tv_fx.tscn` 实例中的 Model 原样引用 GLB。运行时从原曲面复制正面屏幕候选三角形，沿法线偏移 0.055 原始单位；保留原 UV 采样原图，新增 UV2 用连续的屏幕坐标驱动噪点与扫描线。Shader 在曲面上裁出略向内收的圆角边界，外壳与背面不使用 Shader。偏移量约为模型高度的 0.055%。

噪音符号为左右两枚偏明黄的荧光黄色、再次放大约 60% 的独立 Sprite3D 闪电，深色描边由 8 缩细至 4 个 SVG 单位；左侧上移并进一步向左倾斜、尺寸微调，右侧较低、向左靠近屏幕且斜向横展、尺寸缩小，使用本目录 SVG，执行弹出、轻微抖动、缩放、浮动与明暗变化。它们位于屏幕附近的 3D 空间，遵守遮挡，转到背面不会透过外壳显示。

屏幕内的原警示图案还会轻微横向抖动，局部横带偶尔错位。位移发生在原贴图采样上；可用“画面抖动”独立开关。

蓝色发光由屏幕 Emission、柔边加色光晕和一个无阴影局部蓝色 OmniLight3D 组合实现。闪烁使用统一动画时间，爆发时增强，暂停时一起冻结。关闭“蓝光”会同时关闭三部分。它不修改模型材质；开启时会让较明亮的蓝光照到屏幕周围边框和附近机壳。光晕是 Compatibility 下的局部近似，不依赖全局 Bloom/Glow，也不是完整的镜头后期泛光。

调用方式（实例加入场景后）：

```gdscript
var tv = preload("res://modules/tv_fx/tv_fx.tscn").instantiate()
add_child(tv)
tv.set_intensity(0.45)       # 0–1；0 恢复原屏幕
tv.set_symbols_enabled(true)
tv.set_blue_glow_enabled(true)
tv.blue_glow_strength = 1.45 # 0–2，独立发光倍率
tv.set_effects_enabled(true) # false 显示完整原模型
tv.trigger_burst(0.8)        # 单次爆发，自动恢复；时长限制 0.1–3 秒
tv.animation_paused = true  # 冻结全部效果的统一时间
```

Inspector 可设置默认强度、总开关、符号开关、雪花/扫描线/闪烁/画面抖动/蓝光开关、蓝光倍率与暂停。实例各自拥有 ShaderMaterial 与动画状态，可同时放置多台。接入迷宫时可在父节点进行等比缩放；原始 GLB 不需要编辑。无新增 InputMap、Autoload、音频、游戏逻辑或依赖包。

## 运行

1. 在现有 Godot 工程打开 `res://modules/tv_fx/tv_fx_preview.tscn`。
2. 按 **F6（运行当前场景）**。F5 仍运行原游戏。
3. 拖动旋转、滚轮缩放；R 返回正面；1 切换原模型对比；空格暂停；B 触发干扰爆发。底栏可分别切换效果、调整强度。

从仓库根目录运行（可将引擎路径替换为自己的 Godot 4.x）：

```powershell
& '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --path godot --editor --headless --import --quit
& '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --path godot res://modules/tv_fx/tv_fx_preview.tscn
& '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path godot --script res://modules/tv_fx/tests/check_tv_fx.gd
```

图形验证可去掉 `--headless` 并在末尾添加 `-- --capture`，截图写入 Git 忽略的 `.verification/tv_fx/`。

## 依赖与限制

- 道具仅依赖本目录资源；预览 UI 复用现有 `res://ui/game_theme.tres` 与其中文字体。
- 基于 Godot 4.x 的空间 Shader 与 Sprite3D，使用 Compatibility 所支持的普通材质流程，不依赖屏幕读取、深度纹理、Glow 或计算 Shader。实际引擎验收版本为本机 Godot 4.7.2，其他 4.x 版本未逐一运行。
- 屏幕边界是针对这份模型测量的保守内缩遮罩，并非通用自动识别器。原模型若更换或重拓扑，需要重新检查选择范围。
- 原 GLB 没有减面或重新压缩贴图；近 9.7 万三角面与 4K 贴图在场景中大量重复时，需另做性能评估。本原型不擅自修改美术资产。
- 未接入三个迷宫、反向操作、触发距离或声音；当前只交付视觉原型。

实现参考：[Godot 4.7 Spatial shaders](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html)。

## 本次验证与变更清单

- 新增：本目录的 GLB 副本、Godot 导入产生的原贴图、一个 SVG 闪电符号、两个 Shader、三份运行脚本、两个场景、检查脚本和本说明，以及引擎生成的 `.uid` / `.import` 元数据。
- 修改/删除已有项目文件：无。`godot/project.godot` 的既有未提交内容保持原校验值。
- 分支：`feature/tv-fx`，为保留当前查理试玩及未提交配置，从工作中的 `feature/charlie-rig` 建立；未切换或回退工作区到 main，未提交、推送或合并。
- 已运行 Godot 4.7.2 导入、模块无窗口检查、实际 OpenGL Compatibility 渲染检查和原工程 `check_project.gd`，检查通过。
- 曲面特效层 7,888 个三角面；原始 GLB 的 SHA-256 与用户附件一致。关闭蓝光时，截图采样的下机壳、按钮、底脚像素完全一致；屏幕 14,000 个采样点随动画时间变化；仅开启画面抖动时，警示图案区域有 6,291 个采样点发生变化。蓝光开关、随机变化、暂停、爆发恢复、独立实例、原貌对比与缩放均已检查。
- 图形运行环境报告无法写入 `user://` Shader 缓存，渲染与截图成功，未出现 Shader 编译失败；未修改共享配置去绕过缓存目录限制。
- Web 导出和其他 Godot 4.x 版本未实测；本次验收范围为桌面 Compatibility 原型。
