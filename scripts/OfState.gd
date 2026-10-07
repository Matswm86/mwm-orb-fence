class_name OfState
extends Node

## Autoload "OrbFence": save file, settings and the public hooks a host app
## (MWM Play) calls on enter(). The stand-alone build never calls the hooks,
## so it keeps every level open (the owner's own copy).
##
## Hooks: set_full_unlock(on), set_difficulty(easy), set_shell_inset(inset),
## set_sfx_on / set_music_on / set_haptics_on / set_less_motion, save_game().
## Signals up: level_card_shown(level_id), endless_card_shown(round),
## free_levels_finished().

signal level_card_shown(level_id: int)
## Uendelig round card (GDD 6.5); the shell treats it like level_card_shown.
signal endless_card_shown(round: int)
signal free_levels_finished
signal settings_changed

const SAVE_PATH := "user://orb_fence_save.json"
const SAVE_VERSION := 1
const SHELL_META := &"mwm_play_shell"

var full_unlock: bool = true
var easy: bool = true
var shell_inset: Vector2 = Vector2.ZERO
var sfx_on: bool = true
var music_on: bool = true
## Volume sliders, 0..1 (linear). The owner's music gets intense, so it
## starts well under the effects (see OfMusic.BASE_DB).
var sfx_volume: float = 0.7
var music_volume: float = 0.6
## Stored for the shell; the stand-alone build asks for no vibrate
## permission, so it never vibrates.
var haptics_on: bool = false
var less_motion: bool = false
var cleared: Array[int] = []
## Best Uendelig round per setting (GDD 6.5, 8.6).
var endless_best: Dictionary = {"lett": 0, "vanlig": 0}
## True when no save existed at start: the first launch opens level 1 directly.
var first_launch: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()


func in_shell() -> bool:
	return Engine.has_meta(SHELL_META) and bool(Engine.get_meta(SHELL_META))


# ---------------------------------------------------------------- hooks


func set_full_unlock(on: bool) -> void:
	full_unlock = on
	settings_changed.emit()


func set_difficulty(is_easy: bool) -> void:
	if easy == is_easy:
		return
	easy = is_easy
	save_game()
	settings_changed.emit()


## The shell's home square. Nothing of the game sits there, so this only
## stores the value.
func set_shell_inset(inset: Vector2) -> void:
	shell_inset = inset


func set_sfx_on(on: bool) -> void:
	sfx_on = on
	save_game()
	settings_changed.emit()


func set_music_on(on: bool) -> void:
	music_on = on
	save_game()
	settings_changed.emit()


## Slider drags call this with save = false on every step and save once
## when the drag ends.
func set_sfx_volume(v: float, save: bool = true) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	if save:
		save_game()
	settings_changed.emit()


func set_music_volume(v: float, save: bool = true) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	if save:
		save_game()
	settings_changed.emit()


func set_haptics_on(on: bool) -> void:
	haptics_on = on
	save_game()
	settings_changed.emit()


func set_less_motion(on: bool) -> void:
	less_motion = on
	save_game()
	settings_changed.emit()


# ---------------------------------------------------------------- progress


func is_cleared(level_id: int) -> bool:
	return cleared.has(level_id)


func mark_cleared(level_id: int) -> void:
	if not cleared.has(level_id):
		cleared.append(level_id)
		cleared.sort()
	save_game()


## Level ids the map shows: world 1 levels 1-3 only when the full game is
## locked by the host.
func visible_levels() -> Array[int]:
	var out: Array[int] = []
	var n: int = OfLevels.count()
	if not full_unlock:
		n = mini(n, OfBalance.FREE_LEVELS)
	for i: int in n:
		out.append(i + 1)
	return out


## Lowest uncleared visible level: the map pulses it as the suggestion.
func suggested_level() -> int:
	for id: int in visible_levels():
		if not is_cleared(id):
			return id
	return 0


## The Uendelig disc shows once level 5 is cleared and only in the full game.
func endless_unlocked() -> bool:
	return full_unlock and is_cleared(OfBalance.ENDLESS_UNLOCK_LEVEL)


func best_round(is_easy: bool) -> int:
	return int(endless_best.get("lett" if is_easy else "vanlig", 0))


## Saves when the round beats the best; true = new best.
func report_round(is_easy: bool, round_k: int) -> bool:
	var key: String = "lett" if is_easy else "vanlig"
	if round_k <= int(endless_best.get(key, 0)):
		return false
	endless_best[key] = round_k
	save_game()
	return true


func next_level_after(level_id: int) -> int:
	var nxt: int = level_id + 1
	if visible_levels().has(nxt):
		return nxt
	return 0


func save_game() -> void:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"cleared": cleared,
		"difficulty": "lett" if easy else "vanlig",
		"endless_best": {"lett": best_round(true), "vanlig": best_round(false)},
		"settings":
		{
			"sfx": sfx_on,
			"music": music_on,
			"sfx_volume": sfx_volume,
			"music_volume": music_volume,
			"haptics": haptics_on,
			"less_motion": less_motion,
		},
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("OrbFence: cannot write %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		first_launch = true
		return
	first_launch = false
	var txt: String = FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(txt)
	if not parsed is Dictionary:
		push_warning("OrbFence: save file unreadable, starting fresh")
		return
	var d: Dictionary = parsed
	cleared.clear()
	for v: Variant in d.get("cleared", []):
		if (v is float or v is int) and OfLevels.has_level(int(v)) and not cleared.has(int(v)):
			cleared.append(int(v))
	cleared.sort()
	easy = String(d.get("difficulty", "lett")) != "vanlig"
	# Older saves have no endless_best: both read as 0 (GDD 8.6).
	endless_best = {"lett": 0, "vanlig": 0}
	var eb: Variant = d.get("endless_best", {})
	if eb is Dictionary:
		for key: String in ["lett", "vanlig"]:
			var v: Variant = (eb as Dictionary).get(key, 0)
			if v is float or v is int:
				endless_best[key] = maxi(0, int(v))
	var s: Variant = d.get("settings", {})
	if s is Dictionary:
		var sd: Dictionary = s
		sfx_on = bool(sd.get("sfx", true))
		music_on = bool(sd.get("music", true))
		sfx_volume = clampf(float(sd.get("sfx_volume", sfx_volume)), 0.0, 1.0)
		music_volume = clampf(float(sd.get("music_volume", music_volume)), 0.0, 1.0)
		haptics_on = bool(sd.get("haptics", false))
		less_motion = bool(sd.get("less_motion", false))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
