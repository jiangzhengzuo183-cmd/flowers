# 进步报告字体清单与授权核查

核查日期：2026-11-17（复核）。指定字体包中只有 1 个字体文件，没有随附授权书或许可证文本。

| 文件原名 | 字体内部中文名 | 内部英文家族名 | 字重／版本 |
| --- | --- | --- | --- |
| 叶利航九龄卡通（进步报告正文）.ttf | 叶利航九龄卡通 | YeLiHangJiuLinKaTong | Regular / Version 1.00 July 1, 2021, zitijia.com |

选用该字体制作正文预览。其字形具有手写笔触和较松弛的结构，适合查理初期报告的笔记语气；可读性请结合 font-preview.html 的真实排版判断。按钮、报告窗口标题栏、导航等系统文字仍使用原有思源黑体。

## 文件与加载

- 项目副本：`YeLiHangJiuLinKaTong.ttf`，3,110,884 字节；未修改、未转格式、未裁剪。
- SHA-256：`7688783adaa949cb3ecc276ccdae43aacc43efe348883ea80f46fb0f1e54a74e`。
- HTML 预览：`../../font-preview.html`，CSS 通过 `./assets/fonts/YeLiHangJiuLinKaTong.ttf` 加载，不含 `local()`，不会以本机安装字体冒充测试结果。
- 第二份报告 3 月 4 日预览：`../../report2-font-preview.html`，沿用同一个项目字体文件。正文原样取自 report2 的第一段，保留“图话”等写法；只为构图增加显示换行。
- 第二份预览已在 HTTP `/sample-project/` 子目录下实测，浏览器确实请求了相对路径下的 TTF 与 OTF，不依赖原始磁盘位置或已安装字体。部署该预览须同时保留 `font-preview-data.js`、`assets/fonts` 中两款字体、`assets/continuation/ink-1.png` 至 `ink-4.png`、`assets/report/ink-wood.png` 和 `assets/report/paper-grain.svg`。
- Godot：`res://assets/fonts/YeLiHangJiuLinKaTong.ttf`，仅覆盖报告 RichTextLabel 的 `normal_font`；沿用此报告窗口的后续章节也使用该字体。默认主题继续使用思源黑体。
- 技术上随项目保留字体目录即可移机；GitHub Pages 预览需要一并提交 `font-preview.html`、`font-preview-data.js` 和 `assets/fonts` 的依赖文件。Godot 游戏则需重新导出 Web，将生成的网页、PCK、WASM 等导出文件一起部署，不能直接将 Godot 源工程作为网页运行。本次没有发布或上传。

## 正文覆盖检查

直接读取字体 Unicode cmap（format 4 / 12），要求字符映射到非零字形，不以操作系统回退字体作为覆盖依据。扫描项目现有所有报告的标题、日期、全文，排除换行等空白。

| 报告 | 不重复汉字数 | 含标点和数字的不重复字符数 | 缺字 |
| --- | ---: | ---: | ---: |
| report1 | 138 | 143 | 0 |
| report2 | 164 | 172 | 0 |
| report3 | 106 | 111 | 0 |
| report4 | 107 | 113 | 0 |
| report8 | 119 | 128 | 0 |

2026-11-17 复核补充：第二份报告 3 月 4 日单页（report2-0304）含 49 个不重复汉字、54 个不重复非空白字符，缺字均为 0；第二份完整报告仍为 164 个不重复汉字、172 个不重复字符，缺字 0。重新扫描时包含项目新增的报告分页，完整当前结果以 `.verification/report-font-audit.json` 为准。

第二份预览等字体和图片加载后，通过 1920×1080、1280×720 和 1024×768 窗口检查：正文与原数据逐字一致（仅忽略为版式新增的换行）、无文字越界或图片遮挡、画布完整等比缩放。检查记录见 `.verification/report2-font-checks.json`，完整截图见 `.verification/report2-font-1920x1080.png`。木桌背景沿用用户提供的 `ink-observation-module/assets/wood.png`，墨迹沿用项目现有透明 PNG，未把正文合成进图片。

这只证明当前正文的覆盖情况，不表示覆盖所有汉字。预览正文原样取自 `data/day01_extension.json` 和 `data/continuation.json`，没有纠正任何错别字。更新数据后，在项目父目录运行 `node .verification/audit-report-font.cjs` 可重新检查并生成预览数据；完整元数据和逐报告结果见 `.verification/report-font-audit.json`。

## 是否允许网页嵌入

**目前不能确认此文件具备公开网页嵌入、游戏打包发行或公开 GitHub 仓库再分发许可。不要将“个人非商业用途免费”视为完整的 Webfont／再分发授权。**

字体内部 name 表的版权及商标字段说明：个人非商业用途免费，商业用途需要购买授权，作者为叶利航，官网为 www.yegenyou.com。没有发现明确的网页嵌入或再分发许可字段。

官网[常见问题](https://www.yegenyou.com/faq-132.htm)列出个人学习交流和个人网站用字范围；官网[字体授权方案](https://www.yegenyou.com/faq-208.htm)又将字体整体或部分嵌入网站、程序和游戏列为单独的授权类别。官网[使用相关问题通告](https://www.yegenyou.com/faq-127.htm)还说明未经许可发布下载链接的限制。个人网站“用字”不足以证明可以把完整字库公开提供下载。

该字体 OS/2 表的 `fsType = 0x0008`（Editable Embedding）是字体文件的技术嵌入标志，不能代替权利人对网页、游戏或公开再分发的许可。

本次依用户要求完成本地复制、接入和预览；在公开提交包含字体的 GitHub 仓库、发布 GitHub Pages 或发行游戏前，需有覆盖相应嵌入与分发方式的授权证据。思源黑体的 SIL OFL 1.1 许可证只适用于思源黑体，不适用于此手写字体。若没有对应授权，应在发布版本中换用明确允许网页和游戏嵌入的开放授权手写体。
