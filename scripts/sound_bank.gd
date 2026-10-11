class_name SoundBank
extends Node

const SAMPLE_RATE: int = 22_050
const VOICE_LIMIT: int = 10
const CUES: Dictionary = {
	"shoot": [660.0, 230.0, 0.075, 0.0, -24.0],
	"hit": [180.0, 75.0, 0.07, 0.3, -20.0],
	"hurt": [190.0, 48.0, 0.24, 0.2, -15.0],
	"dash": [160.0, 880.0, 0.16, 0.1, -20.0],
	"pickup": [740.0, 1100.0, 0.085, 0.0, -26.0],
	"level": [440.0, 1320.0, 0.48, 0.0, -16.0],
	"select": [520.0, 780.0, 0.095, 0.0, -19.0],
	"win": [330.0, 990.0, 0.85, 0.0, -13.0],
	"lose": [330.0, 65.0, 0.7, 0.03, -14.0],
	"boss": [90.0, 55.0, 0.75, 0.04, -13.0],
	"event_warning": [880.0, 440.0, 0.23, 0.0, -15.0],
	"event_start": [70.0, 210.0, 0.55, 0.18, -17.0],
	"hazard_start": [250.0, 40.0, 0.32, 0.4, -21.0],
	"boundary_hit": [140.0, 70.0, 0.12, 0.18, -24.0],
}

var muted: bool = false
var _music_enabled: bool = true
var _voices: Array[AudioStreamPlayer] = []
var _sounds: Dictionary = {}
var _last_played: Dictionary = {}
var _music: AudioStreamPlayer


func _ready() -> void:
	_initialize()


func _initialize() -> void:
	if not _voices.is_empty():
		return
	for i: int in range(VOICE_LIMIT):
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(voice)
		_voices.append(voice)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -22.0
	add_child(_music)


func play(cue: String) -> void:
	if muted or not is_inside_tree() or not CUES.has(cue):
		return
	_initialize()
	var now: int = Time.get_ticks_msec()
	var interval: int = 70 if cue in ["shoot", "hit", "pickup"] else 45
	if now - int(_last_played.get(cue, -1000)) < interval:
		return
	if not _sounds.has(cue):
		_sounds[cue] = _make_effect(CUES[cue])
	var available: AudioStreamPlayer = null
	for voice: AudioStreamPlayer in _voices:
		if not voice.playing:
			available = voice
			break
	if available == null and cue in ["event_warning", "event_start", "hurt"]:
		available = _voices[0]
		available.stop()
	if available == null:
		return
	_last_played[cue] = now
	available.stream = _sounds[cue]
	available.volume_db = float(CUES[cue][4])
	available.play()


func start_music() -> void:
	if not is_inside_tree():
		return
	_initialize()
	if muted or not _music_enabled:
		return
	if _music.stream == null:
		_music.stream = _make_music()
	if not _music.playing:
		_music.play()


func set_muted(value: bool) -> void:
	muted = value
	if muted:
		for voice: AudioStreamPlayer in _voices:
			voice.stop()
		if is_instance_valid(_music):
			_music.stop()
	else:
		start_music()


func set_music_enabled(value: bool) -> void:
	_music_enabled = value
	if value:
		start_music()
	elif is_instance_valid(_music):
		_music.stop()


func _make_effect(spec: Array) -> AudioStreamWAV:
	var duration: float = float(spec[2])
	var sample_count: int = int(duration * SAMPLE_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(sample_count * 2)
	var phase: float = 0.0
	for i: int in range(sample_count):
		var progress: float = float(i) / sample_count
		var frequency: float = lerpf(float(spec[0]), float(spec[1]), progress)
		phase += TAU * frequency / SAMPLE_RATE
		var envelope: float = minf(progress * 40.0, 1.0) * pow(1.0 - progress, 2.0)
		var tone: float = sin(phase) * 0.75 + sin(phase * 2.0) * 0.15
		tone += randf_range(-1.0, 1.0) * float(spec[3])
		bytes.encode_s16(i * 2, int(clampf(tone * envelope, -1.0, 1.0) * 32767.0))
	return _stream(bytes)


func _make_music() -> AudioStreamWAV:
	# Eight seconds at 120 BPM: a restrained four-chord loop with a soft pulse.
	var duration: float = 8.0
	var sample_count: int = int(duration * SAMPLE_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(sample_count * 2)
	var roots: Array[int] = [45, 41, 48, 43]
	var chords: Array = [[0, 3, 7], [0, 4, 7], [0, 4, 7], [0, 4, 7]]
	var arpeggio: Array[int] = [0, 1, 2, 1, 0, 1, 2, 1]
	for i: int in range(sample_count):
		var t: float = float(i) / SAMPLE_RATE
		var bar: int = mini(int(t / 2.0), 3)
		var bar_t: float = fmod(t, 2.0)
		var step: int = int(bar_t / 0.25)
		var step_t: float = fmod(bar_t, 0.25)
		var chord_envelope: float = minf(bar_t / 0.12, 1.0) * minf((2.0 - bar_t) / 0.16, 1.0)
		var note: int = roots[bar] + int(chords[bar][arpeggio[step]]) + 24
		var lead_envelope: float = minf(step_t / 0.012, 1.0) * exp(-step_t * 17.0)
		var sample_value: float = sin(TAU * _frequency(note) * step_t) * lead_envelope * 0.25
		for interval: int in chords[bar]:
			sample_value += sin(TAU * _frequency(roots[bar] + interval + 12) * bar_t) * chord_envelope * 0.085
		var beat_t: float = fmod(t, 0.5)
		var bass_envelope: float = minf(beat_t / 0.016, 1.0) * exp(-beat_t * 7.0)
		sample_value += sin(TAU * _frequency(roots[bar] - 12) * beat_t) * bass_envelope * 0.22
		var edge_fade: float = minf(t / 0.015, 1.0) * minf((duration - t) / 0.025, 1.0)
		bytes.encode_s16(i * 2, int(clampf(sample_value * edge_fade, -1.0, 1.0) * 32767.0))
	var stream: AudioStreamWAV = _stream(bytes)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	return stream


func _frequency(midi_note: int) -> float:
	return 440.0 * pow(2.0, float(midi_note - 69) / 12.0)


func _stream(bytes: PackedByteArray) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
