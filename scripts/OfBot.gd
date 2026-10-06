class_name OfBot
extends RefCounted

## Test and capture-bot player: after each wall it waits think_s, then
## builds the hint rule's best line (GDD 8.3, danger check on). Never used
## in normal play.

var think_s: float = 0.35
var _wait: float = 0.0


func tick(sim: OfSim, dt: float) -> Dictionary:
	if not sim.can_start_wall():
		_wait = think_s
		return {}
	_wait -= dt
	if _wait > 0.0:
		return {}
	var pick: Dictionary = sim.best_line(-1, true)
	if pick.is_empty():
		return {}
	_wait = think_s
	if sim.start_wall(pick["origin"], bool(pick["vertical"])):
		return pick
	return {}
