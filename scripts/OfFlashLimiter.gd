class_name OfFlashLimiter
extends RefCounted

## Global flash limiter (GDD 9, DESIGN 6b, rule 37): at most
## MAX_FLASHES_PER_S glow spikes in any 1 s window. Events past the limit
## still get sound and particles, only the glow spike is skipped.

var granted: int = 0
var denied: int = 0
var _times: Array[float] = []


func allow(now_s: float) -> bool:
	while not _times.is_empty() and now_s - _times[0] >= 1.0:
		_times.pop_front()
	if _times.size() >= OfBalance.MAX_FLASHES_PER_S:
		denied += 1
		return false
	_times.append(now_s)
	granted += 1
	return true
