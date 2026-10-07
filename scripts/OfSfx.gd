class_name OfSfx
extends Node

## Sound effects (GDD 9), space themed: pre-rendered .ogg files in
## res://assets/sfx/, made by tools/render_sfx.py (own synthesis plus one
## Kenney CC0 layer, see CREDITS.md). Keys are game events, files are the
## sounds (wall_start = laser fire, the riser = humming beam, lock = force-
## field seal, bounce = sonar blip, pop = shield fizzle, milestone = comms
## beep, intro = warp-in, win = flyby + fanfare, pass_by = rare ambient
## ship). One fixed pool of players, no allocation per event. Each play
## picks a random variant and a small random pitch shift so repeats do not
## tire the ear. The wall riser has its own player so it can stop when the
## wall ends. Ball bounces are rate-limited (at most 6 per second). Players
## stay on the "Master" bus (MWM Play routes streams outside a "music" path
## to its Sfx bus).

## Emitted when the win stinger starts, with its length in seconds, so the
## music can duck under it.
signal stinger_started(seconds: float)

const POOL: int = 12
const DIR := "res://assets/sfx/"
## Pentatonic steps (F# major pentatonic, same scale as the files).
const PENTA: Array[float] = [1.0, 1.1225, 1.2599, 1.4983, 1.6818, 2.0]
## Call-site name -> [files (variants), random pitch spread (+- share),
## level in dB]. The files peak at -3 dBFS; tools/audio_preview.py reads
## this table to render docs/audio_preview.ogg at the default volumes.
const SOUNDS: Dictionary = {
	"tap": [["of_tap_1", "of_tap_2", "of_tap_3"], 0.03, -4.0],
	"dir_pick": [["of_dir_1", "of_dir_2"], 0.03, -10.0],
	"tick_in": [["of_tick_in"], 0.04, -10.0],
	"ghost_tick": [["of_tick_in"], 0.08, -20.0],
	"notyet": [["of_notyet"], 0.0, -8.0],
	"wall_start": [["of_laser_1", "of_laser_2", "of_laser_3"], 0.02, -4.0],
	"grow_tick": [["of_grow_tick_1", "of_grow_tick_2", "of_grow_tick_3"], 0.03, -20.0],
	"lock": [["of_seal_1", "of_seal_2"], 0.02, -4.0],
	"capture_s": [["of_capture_s_1", "of_capture_s_2"], 0.0, -3.0],
	"capture_m": [["of_capture_m"], 0.0, -2.0],
	"capture_l": [["of_capture_l"], 0.0, -1.0],
	"bounce": [["of_sonar_1", "of_sonar_2", "of_sonar_3", "of_sonar_4"], 0.03, -20.0],
	"mirror": [["of_mirror"], 0.03, -14.0],
	"pop": [["of_fizzle_1", "of_fizzle_2", "of_fizzle_3"], 0.06, -6.0],
	"crack": [["of_crack"], 0.03, -12.0],
	"rewind": [["of_rewind"], 0.0, -5.0],
	"milestone": [["of_comms"], 0.0, -6.0],
	"snegl": [["of_snegl"], 0.0, -3.0],
	"lyn": [["of_lyn"], 0.0, -3.0],
	"skjold": [["of_skjold"], 0.0, -4.0],
	"win": [["of_win"], 0.0, -1.0],
	"star_land": [["of_star_ping"], 0.0, -7.0],
	"shimmer": [["of_shimmer"], 0.0, -16.0],
	"intro": [["of_warp_in"], 0.0, -13.0],
	"pass_by": [["of_pass_1", "of_pass_2"], 0.04, -16.0],
}
const ZIP_FILE := "of_beam"
const ZIP_DB: float = -18.0
const WIN_DUCK_S: float = 3.5
## Level of every effect before the player's slider: with the default
## slider (0.7) the loudest events peak near -12 dBFS (GDD 9).
const BASE_DB: float = -5.0

var enabled: bool = true
## Effects slider, 0..1 (linear), from OrbFence.sfx_volume.
var volume: float = 1.0
## Snegl pitches effects down slightly (GDD 5.2).
var pitch_mult: float = 1.0
var _streams: Dictionary = {}
var _spread: Dictionary = {}
var _level: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _rng := RandomNumberGenerator.new()
var _zip: AudioStreamPlayer
var _zip_tween: Tween
var _bounce_times: Array[float] = []
var _clock: float = 0.0


func _ready() -> void:
	_rng.randomize()
	for i: int in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for key: String in SOUNDS:
		var entry: Array = SOUNDS[key]
		var list: Array[AudioStream] = []
		for file: String in entry[0]:
			var s: AudioStream = load(DIR + file + ".ogg") as AudioStream
			if s != null:
				list.append(s)
			else:
				push_warning("OfSfx: missing " + file)
		_streams[key] = list
		_spread[key] = float(entry[1])
		_level[key] = float(entry[2])
	_zip = AudioStreamPlayer.new()
	_zip.stream = load(DIR + ZIP_FILE + ".ogg") as AudioStream
	add_child(_zip)


func _process(delta: float) -> void:
	_clock += delta


func play(name: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if not enabled or volume <= 0.01 or not _streams.has(name):
		return
	var list: Array[AudioStream] = _streams[name]
	if list.is_empty():
		return
	var spread: float = _spread[name]
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = list[_rng.randi() % list.size()]
	var pm: float = pitch * pitch_mult * (1.0 + _rng.randf_range(-spread, spread))
	p.pitch_scale = clampf(pm, 0.25, 4.0)
	p.volume_db = vol_db + float(_level[name]) + BASE_DB + linear_to_db(volume)
	p.play()
	if name == "win":
		stinger_started.emit(WIN_DUCK_S)


## Ball bounce: very soft, at most BOUNCE_SOUNDS_PER_S per second in total;
## the rest are dropped. Bigger balls sound lower.
func bounce(radius: float) -> void:
	while not _bounce_times.is_empty() and _clock - _bounce_times[0] >= 1.0:
		_bounce_times.pop_front()
	if _bounce_times.size() >= OfBalance.BOUNCE_SOUNDS_PER_S:
		return
	_bounce_times.append(_clock)
	play("bounce", OfBalance.BALL_RADIUS / maxf(radius, 1.0))


## Mirror bounce (W5-6): glassy ping, shares the bounce rate limit; pitch
## follows the ball size like the bounce.
func mirror(radius: float) -> void:
	while not _bounce_times.is_empty() and _clock - _bounce_times[0] >= 1.0:
		_bounce_times.pop_front()
	if _bounce_times.size() >= OfBalance.BOUNCE_SOUNDS_PER_S:
		return
	_bounce_times.append(_clock)
	play("mirror", OfBalance.BALL_RADIUS / maxf(radius, 1.0))


## Capture sound key by room size; thresholds in cells come from the grid
## (14 / 40 on 14 x 16, 32 / 90 on 21 x 24: same area, GDD 9).
static func capture_key(cells: int, m_at: int = 14, l_at: int = 40) -> String:
	if cells >= l_at:
		return "capture_l"
	if cells >= m_at:
		return "capture_m"
	return "capture_s"


## Room captured: crystal chime, bigger for bigger rooms.
func capture(cells: int, m_at: int = 14, l_at: int = 40) -> void:
	play(capture_key(cells, m_at, l_at))


## % milestone: one pentatonic step higher per milestone.
func milestone(index: int) -> void:
	play("milestone", PENTA[clampi(index, 0, PENTA.size() - 1)])


func zip_start() -> void:
	if not enabled or volume <= 0.01:
		return
	if _zip_tween:
		_zip_tween.kill()
	_zip.pitch_scale = pitch_mult
	_zip.volume_db = ZIP_DB + BASE_DB + linear_to_db(volume)
	_zip.play()


func zip_stop() -> void:
	if not _zip.playing:
		return
	if _zip_tween:
		_zip_tween.kill()
	_zip_tween = create_tween()
	_zip_tween.tween_property(_zip, "volume_db", -60.0, 0.08)
	_zip_tween.tween_callback(_zip.stop)
