extends Node
## Browser MP4 and desktop Theora playback share one completion callback.
signal completed
var callback: JavaScriptObject
var finished := false

func play(data: Dictionary, audio_options: Dictionary) -> void:
	if not OS.has_feature("web"):
		var desktop := preload("res://modules/visual_novel/scripts/story/native_story_video.gd").new()
		add_child(desktop)
		desktop.completed.connect(_finish.bind([]))
		desktop.play(data, audio_options)
		return
	callback = JavaScriptBridge.create_callback(_finish)
	var volume: float = 0.0 if audio_options.get("mute",false) else float(audio_options.get("master",0.7))
	JavaScriptBridge.get_interface("window").showFlowerStoryVideo(data.src,data.title,volume,callback)

func _finish(_arguments: Array) -> void:
	if finished: return
	finished = true
	completed.emit()
	queue_free()

func _exit_tree() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.get_interface("window").closeFlowerStoryVideo()
