# 水晶吊灯暖光预览

独立的吊灯美术组件，尚未替换迷宫中的三盏灯。八个灯泡发出稳定暖白光，配少量柔和光晕和一盏无阴影的局部光源。原始几何、颜色贴图和桌面 GLB 均保留。

## 查看

在现有 Godot 工程打开 `res://modules/crystal_chandelier/preview.tscn`，等待首次资源导入完成，按 F6。

- 鼠标左键拖动：旋转视角。
- 滚轮：缩放。
- 空格：比较开灯和关灯。
- R：恢复初始视角。

## 接入接口（本次尚未接入迷宫）

实例化 `crystal_chandelier.tscn` 即可。根节点是顶部悬挂点，Y 轴朝上；默认约宽 1.36 米、高 1.47 米。原 GLB 自身单位很大，缩放只放在包装场景中。实例可整体等比缩放；光照范围另用 `light_range` 调整。

检查器中的 `lit` / `set_lit(bool)` 控制开关；`brightness` 调整亮度；`light_color` 调整光色；`halo_strength` 调整光晕；`illuminate_surroundings` 控制真实照明；`light_range` 控制照明范围。各实例材质独立，不需要主场景提供事件，也不修改其他模块的接口。

## 文件

- `crystal_chandelier.glb`：用户桌面模型的原样副本，81,414 顶点、100,455 三角形、1 个材质；未减面。
- `crystal_chandelier.tscn` / `.gd`：可复用组件、挂点、比例、开关及光照设置。
- `crystal_glow.gdshader`：保留原贴图，通过原模型坐标只让八个灯泡顶部发光。
- `soft_halo.gdshader`：八张小面片提供局部光晕，启用深度遮挡，不依赖全局 Bloom。
- `preview.tscn` / `.gd`：独立背景、相机和开关对比。
- 本文件：使用说明。Godot 首次导入还会生成 `.import`、`.uid` 及解包贴图。

## 验证和限制

使用本机 Godot 4.7.2 的 Compatibility 渲染，在隔离预览工程中实际运行并截取开灯、关灯与低视角图像；确认八个光晕和一个 OmniLight3D 正常创建，材质与脚本无加载错误。预览不修改全局环境或主项目配置。截图时运行环境提示用户目录的着色器缓存不可写，不影响本次渲染。尚未导出 Web、在真实迷宫中测试或做性能优化。

原模型把八个灯泡和整个灯架合并为同一网格，因此发光区域依赖这个模型的局部坐标；换模型或在建模软件中重置其坐标后，需要重新定位发光区域。当前局部光源关闭阴影，集成时需检查相邻墙面的漏光；多个实例可只保留一盏真实光源。预览的中文字体使用系统字体，Web 交付时可接入项目已有的嵌入字体。

材质采用 Godot 官方的 [Spatial shader EMISSION](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html) 输出；周围物体的照明由独立灯节点承担。
