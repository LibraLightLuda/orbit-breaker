class_name GhostReplay
extends RefCounted

const VERSION := 1
const MAX_FRAMES := 3002
var frames: Array = []

func capture(run: RunModel, force: bool = false) -> void:
	if not frames.is_empty() and (run.elapsed <= float(frames.back()[0]) or (not force and run.elapsed - float(frames.back()[0]) < 0.2)):
		return
	if frames.size() < MAX_FRAMES:
		frames.append([snappedf(run.elapsed, 0.0001), snappedf(run.player.x, 0.01), snappedf(run.player.y, 0.01), run.facing.angle(), snappedf(run.hp, 0.01), run.ranked_score(), run.orbit_count, run.orbit_radius, run.orbit_angle, int(run.dash_time > 0), int(run.overdrive_time > 0), int(run.upgrades.get("blade", 0)), int(run.upgrades.get("frost", 0))])

static func valid(value: Variant) -> bool:
	if not value is Array or value.is_empty() or value.size() > MAX_FRAMES:
		return false
	var last := -1.0
	for frame: Variant in value:
		if not frame is Array or frame.size() != 13:
			return false
		for number: Variant in frame:
			if not (number is int or number is float) or not is_finite(float(number)):
				return false
		if float(frame[0]) <= last or float(frame[0]) > 600.01 or absf(float(frame[1])) > 10000 or absf(float(frame[2])) > 10000 or float(frame[6]) < 1 or float(frame[6]) > 12 or float(frame[7]) < 0 or float(frame[7]) > 200:
			return false
		last = float(frame[0])
	return float(value[0][0]) == 0.0

static func write(path: String, value: Array) -> bool:
	if not valid(value):
		return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"version": VERSION, "frames": value}))
	file.flush()
	var error := file.get_error()
	file.close()
	return error == OK and DirAccess.rename_absolute(path + ".tmp", path) == OK

static func read(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 2_000_000:
		return []
	var value: Variant = JSON.parse_string(file.get_as_text())
	if not value is Dictionary or value.get("version") != VERSION or not valid(value.get("frames")):
		return []
	return value.frames

static func sample(value: Array, time: float) -> Array:
	var low := 0
	var high := value.size() - 1
	while low < high:
		var middle := (low + high + 1) / 2
		if float(value[middle][0]) <= time:
			low = middle
		else:
			high = middle - 1
	var a: Array = value[low]
	var b: Array = value[mini(low + 1, value.size() - 1)]
	var result := a.duplicate()
	var weight := clampf((time - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0])), 0.0, 1.0)
	for index: int in [1, 2, 4]:
		result[index] = lerpf(float(a[index]), float(b[index]), weight)
	for index: int in [3, 8]:
		result[index] = lerp_angle(float(a[index]), float(b[index]), weight)
	return result
