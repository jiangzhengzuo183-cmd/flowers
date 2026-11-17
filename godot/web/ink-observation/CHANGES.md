# 相对已确认原型的整理清单

原 `ink-observation/` 完整保留，本次交付在新增 `ink-observation-module/` 内完成。

## 新增

- module.js：同源 iframe 模块入口、enter/exit/complete/destroy 和回调。
- integration.html：实际可运行的宿主挂载入口，不新增玩家可见控制。
- package.json、.gitignore、.nojekyll：预览、可选测试和仓库整理。
- verify-lifecycle.cjs：隔离、反复进入退出、GPU 清理与静态子路径测试。
- README.md、ASSETS.md、TEAM-NOTE.md、CHANGES.md：中文接入、素材和交付说明。
- verification：本次实际检查生成的报告和截图。

## 复制后修改

- app.js：仅增加 ready/complete/destroy、事件和观察器的生命周期清理，直接相对加载静态素材，取消 Node 素材发现接口依赖；保持交互与渲染参数。
- flow.js：仅跟踪并释放 RAF、事件、纹理、缓冲、着色器、程序和上下文；保留流场算法。
- server.cjs：纯静态预览，默认端口 4185，不再需要素材发现 API。
- start.ps1：使用标准 Node.js，不依赖个人 Codex 运行时路径。
- verify.cjs、verify-zoom.cjs：移除个人电脑路径，改用可安装的开发依赖。
- assets/素材说明.md：改为引用 ASSETS.md，不保留个人素材目录绝对路径。

## 原样保留

- index.html、style.css、config.js、start.cmd。
- assets 中四张墨迹、木桌、纸卡、思源黑体和字体许可原始字节。

本次不含远程仓库操作，不合并章节或 Godot 工程。
