class_name Scheduler
extends RefCounted
## Decides what appears and when.
##
## Builds a Sequence: an ordered list of steps walked one per slot. The concept
## doc's observed sequences interleave the clock with patterns rather than
## grouping them (音符 → 時刻 → 時刻 → 時刻 → 桜), and they end in nothing, so
## that is the shape here.
##
## The empty step is a real step, not a gap left over from arithmetic. The empty
## time is part of the piece, so there is deliberately no rule anywhere that
## fills it.

const KIND_CLOCK := "clock"
const KIND_WEEKDAY := "weekday"
const KIND_DATE := "date"
const KIND_PATTERN := "pattern"
const KIND_PAUSE := "pause"

## Full rotation. The reference machine cycles its motifs in about five minutes;
## 90s over ~9 steps keeps the concept doc's 10-second spacing between items.
var cycle_seconds := 90.0
var show_weekday := true
var show_date := true
var show_patterns := true

var _steps: Array[Dictionary] = []
var _index := 0
var _t := 0.0


func _init() -> void:
	rebuild()


## [param pattern_ids] is the pool to draw motifs from, usually the ones tagged
## for the current season. Order is shuffled so a long session does not repeat
## the same pairing every rotation.
func rebuild(pattern_ids: Array[String] = []) -> void:
	_steps.clear()
	_index = 0
	_t = 0.0

	var pool := pattern_ids.duplicate()
	pool.shuffle()
	var taken := 0

	_steps.append({"kind": KIND_CLOCK})
	taken = _append_pattern(pool, taken)
	_steps.append({"kind": KIND_CLOCK})
	if show_weekday:
		_steps.append({"kind": KIND_WEEKDAY})
	taken = _append_pattern(pool, taken)
	_steps.append({"kind": KIND_CLOCK})
	if show_date:
		_steps.append({"kind": KIND_DATE})
	taken = _append_pattern(pool, taken)
	_steps.append({"kind": KIND_PAUSE})


func _append_pattern(pool: Array, taken: int) -> int:
	if not show_patterns or pool.is_empty():
		return taken
	_steps.append({"kind": KIND_PATTERN, "value": str(pool[taken % pool.size()])})
	return taken + 1


func step_count() -> int:
	return _steps.size()


func slot_seconds() -> float:
	return cycle_seconds / float(maxi(_steps.size(), 1))


## Human-readable sequence, for dev logging.
func describe() -> String:
	var parts: Array[String] = []
	for step in _steps:
		parts.append(str(step.get("value", step.kind)))
	return " -> ".join(parts)


## Fire the first step [param seconds] from now instead of a full slot away, so
## startup is not a long wait at an empty screen.
func prime(seconds: float) -> void:
	_t = maxf(slot_seconds() - seconds, 0.0)


## Returns the step to display this frame, or an empty Dictionary for nothing.
func tick(delta: float) -> Dictionary:
	if _steps.is_empty():
		return {}
	_t += delta
	var slot := slot_seconds()
	if _t < slot:
		return {}
	_t -= slot
	var step: Dictionary = _steps[_index]
	_index = (_index + 1) % _steps.size()
	return step
