extends RefCounted
## Reuse the provided HTML/WebGL module through the Web shell, never recreate it.
signal completed(result: Dictionary)
signal failed(message: String)
var callback: JavaScriptObject
var bridge: JavaScriptObject
var opened := false

func open() -> bool:
	if opened: return false
	if not OS.has_feature("web"):
		failed.emit("墨迹观察使用已确认的 HTML/WebGL 模块。请从“启动整合网页版.cmd”打开整体游戏，再进入本环节。")
		return false
	bridge = JavaScriptBridge.get_interface("FlowerInk")
	if bridge == null:
		failed.emit("网页壳缺少 ink-host.js。请使用包含小游戏文件的整合导出。")
		return false
	callback = JavaScriptBridge.create_callback(_returned)
	opened = true
	bridge.open(callback)
	return true

func _returned(arguments: Array) -> void:
	if not opened: return
	opened = false
	var result: Variant = JSON.parse_string(str(arguments[0]))
	if result is Dictionary and result.get("status") == "completed": completed.emit(result.get("result",{}))
	else: failed.emit(str(result.get("message","小游戏未能加载。")) if result is Dictionary else "小游戏返回值无效。")
	callback = null
	bridge = null

func cancel() -> void:
	if opened and bridge != null: bridge.cancel()
	opened = false
	callback = null
	bridge = null
