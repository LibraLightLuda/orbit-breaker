extends SceneTree

var count := 0
var failures := 0

func check(value: bool, message: String) -> void:
	count += 1
	if not value:
		failures += 1
		push_error(message)

func _init() -> void:
	call_deferred("verify")

func verify() -> void:
	var catalog = load("res://scripts/audio_catalog.gd")
	for cue: String in catalog.CUES:
		for path: String in catalog.CUES[cue].paths:
			check(ResourceLoader.exists(path), "Exported cue missing: " + path)
			var stream: AudioStream = load(path)
			check(stream != null and stream.get_length() > .02, "Invalid exported cue: " + path)
	for key: String in catalog.TRACKS:
		check(ResourceLoader.exists(catalog.TRACKS[key].path), "Exported track missing: " + key)
	check(not FileAccess.file_exists("res://audio_source/manifest.json"), "Authoring source leaked into export")
	check(not FileAccess.file_exists("res://tests/test_audio.gd"), "Test source leaked into export")
	print("AUDIO EXPORT SELF-CHECK: %d / %d assertions passed" % [count-failures,count])
	quit(0 if failures == 0 else 1)
