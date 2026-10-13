extends RefCounted

const TAP_WINDOW := 0.24
const DASH_HOLD := 0.3
const DASH_DRAG := 48.0
var contacts := {}
var drag_id := -1
var direction := Vector2.ZERO
var origin := Vector2.ZERO
var finger := Vector2.ZERO
var pending := false
var remaining := 0.0
var tap_position := Vector2.ZERO
var tap_scale := 1.0
var dash_position := Vector2.ZERO
var dash_direction := Vector2.ZERO

func reset() -> void:
	contacts.clear()
	drag_id = -1
	direction = Vector2.ZERO
	pending = false
	remaining = 0.0
	dash_direction = Vector2.ZERO

func press(index: int, at: Vector2, pixels: float) -> void:
	contacts[index] = {"start": at, "at": at, "age": 0.0, "moved": false, "pixels": pixels}

func drag(index: int, at: Vector2) -> void:
	if not contacts.has(index): return
	var contact: Dictionary = contacts[index]
	contact.at = at
	var offset: Vector2 = at - contact.start
	if offset.length() * float(contact.pixels) < 12 and not contact.moved: return
	if not contact.moved: pending = false
	contact.moved = true
	if drag_id == -1: drag_id = index
	if drag_id == index:
		origin = contact.start
		finger = at
		direction = offset.normalized() * clampf(offset.length() * float(contact.pixels) / 48.0, 0, 1)

func release(index: int, at: Vector2, canceled: bool = false) -> String:
	if not contacts.has(index): return ""
	var contact: Dictionary = contacts[index]
	contacts.erase(index)
	if drag_id == index:
		drag_id = -1
		direction = Vector2.ZERO
	if canceled: return ""
	var offset: Vector2 = at - contact.start
	if contact.moved:
		pending = false
		if float(contact.age) >= DASH_HOLD and offset.length() * float(contact.pixels) >= DASH_DRAG:
			dash_direction = offset.normalized()
			return "dash"
		return ""
	if float(contact.age) > 0.3 or offset.length() * float(contact.pixels) >= 12: return ""
	if pending and remaining > 0 and at.distance_to(tap_position) * tap_scale <= 52:
		pending = false
		return "overdrive"
	# Single taps are inert; only a second nearby tap spends overdrive.
	pending = true
	remaining = TAP_WINDOW
	tap_position = at
	tap_scale = float(contact.pixels)
	return ""

func advance(delta: float) -> String:
	for contact: Dictionary in contacts.values(): contact.age += delta
	if not pending: return ""
	remaining -= delta
	if remaining > 0: return ""
	pending = false
	return ""
