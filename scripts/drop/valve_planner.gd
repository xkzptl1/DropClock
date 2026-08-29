class_name ValvePlanner
extends RefCounted
## Glyph cells -> valve open/close intervals. The core of the v4 model.
##
## The unit of water is not a drop. Each nozzle has a valve, and what it emits
## between OPEN and CLOSE is one continuous body of water: a bead if the pulse
## is short, a thread if it is long, a curtain if it never closes.
##
## So a vertical run of six lit cells in one column is NOT six drops. It is one
## valve pulse long enough to produce a six-cell thread. That merge is the whole
## point: it is what makes beads, threads and curtains fall out of a single
## mechanism instead of being three separate effects.
##
## Water emitted first has fallen furthest, so within one pulse the FIRST water
## out is the BOTTOM of the segment:
##
##   open_time  = formation - time_to_fall(y_bottom)   (earlier)
##   close_time = formation - time_to_fall(y_top)      (later)
##
## Times here are relative to the formation instant, so both are negative.

## One valve pulse.
class Segment extends RefCounted:
	var nozzle := 0
	var x := 0.0
	var open_time := 0.0   ## negative: seconds before formation
	var close_time := 0.0  ## negative, and always later than open_time
	var y_top := 0.0       ## where the trailing end sits at formation
	var y_bottom := 0.0    ## where the leading end sits at formation
	var width := 0.0
	var brightness := 1.0


class Plan extends RefCounted:
	var segments: Array[Segment] = []
	var pitch := 0.0
	var cols := 0
	var rows := 0
	var scale := 1
	var lead := 0.0
	var cell_count := 0  ## lit cells before merging, for the compression figure

	func is_empty() -> bool:
		return segments.is_empty()


static func plan(text: String, s: DropSettings, viewport: Vector2) -> Plan:
	if text.is_empty():
		return Plan.new()
	return plan_mask(GlyphBuilder.build(text, 1), s, viewport)


## Plan any cell mask, from the font or from a pattern file.
##
## [param height_ratio] and [param top_ratio] override the settings when a
## pattern wants a different footprint. A curtain needs the full height; a
## glyph does not.
static func plan_mask(unit: GlyphBuilder.GlyphData, s: DropSettings, viewport: Vector2,
		height_ratio := -1.0, top_ratio := -1.0, fixed_scale := 0) -> Plan:
	var result := Plan.new()
	if unit == null or unit.is_empty():
		return result

	var height_limit: float = s.glyph_height_ratio if height_ratio <= 0.0 else height_ratio
	var top_fraction: float = s.glyph_top_ratio if top_ratio < 0.0 else top_ratio

	var pitch := viewport.x / float(maxi(1, s.nozzle_count))
	result.pitch = pitch

	# One cell per nozzle, so the mask is scaled by growing each source pixel
	# rather than by spreading cells across more nozzles. That keeps strokes
	# solid and gives the merge something to work with.
	var by_width: int = int(floor(viewport.x * s.glyph_fill_ratio / (float(unit.cols) * pitch)))
	var by_height: int = int(floor(viewport.y * height_limit / (float(unit.rows) * pitch)))
	var scale: int = clampi(mini(by_width, by_height), 1, s.max_segment_scale)
	if fixed_scale > 0:
		# A composite built directly in lane space is already at the canonical
		# resolution; scaling it again would push it off the canvas.
		scale = fixed_scale

	var glyph := GlyphBuilder.scale_mask(unit, scale)
	if glyph.is_empty():
		return result

	result.scale = scale
	result.cols = glyph.cols
	result.rows = glyph.rows
	result.cell_count = glyph.cells.size()

	var glyph_w := float(glyph.cols) * pitch
	var first_nozzle := int(round((viewport.x - glyph_w) * 0.5 / pitch))
	var top_y := viewport.y * top_fraction
	var width := pitch * s.thread_width_ratio

	# Gather lit rows per column, then merge each column's contiguous runs.
	var columns := {}
	for cell in glyph.cells:
		if not columns.has(cell.x):
			columns[cell.x] = PackedInt32Array()
		columns[cell.x].append(cell.y)

	var lead := 0.0
	for gx in columns:
		var rows: PackedInt32Array = columns[gx]
		rows.sort()

		var run_start: int = rows[0]
		var run_end: int = rows[0]
		for i in range(1, rows.size()):
			var gy: int = rows[i]
			if gy == run_end + 1:
				run_end = gy
				continue
			lead = maxf(lead, _emit(result, s, gx, run_start, run_end,
				first_nozzle, pitch, top_y, width))
			run_start = gy
			run_end = gy
		lead = maxf(lead, _emit(result, s, gx, run_start, run_end,
			first_nozzle, pitch, top_y, width))

	result.lead = lead
	return result


## Build one segment from a contiguous run and return how early it must open.
static func _emit(result: Plan, s: DropSettings, gx: int, run_start: int, run_end: int,
		first_nozzle: int, pitch: float, top_y: float, width: float) -> float:
	var segment := Segment.new()
	segment.nozzle = first_nozzle + gx
	segment.x = (float(segment.nozzle) + 0.5) * pitch
	segment.y_top = top_y + float(run_start) * pitch
	segment.y_bottom = top_y + float(run_end) * pitch

	var open_fall: float = maxf(segment.y_bottom - s.nozzle_y, 0.0)
	var close_fall: float = maxf(segment.y_top - s.nozzle_y, 0.0)
	segment.open_time = -s.time_to_fall(open_fall)
	segment.close_time = -s.time_to_fall(close_fall)

	segment.width = width
	segment.brightness = 1.0 - randf() * s.brightness_jitter

	result.segments.append(segment)
	return -segment.open_time


## A valve cannot be open twice at once. Runs in a column are disjoint by
## construction, but anything that later varies motion per segment could break
## it, so the check stays available.
static func verify_no_overlap(plan_result: Plan) -> Array[String]:
	var problems: Array[String] = []
	var by_nozzle := {}
	for segment in plan_result.segments:
		if not by_nozzle.has(segment.nozzle):
			by_nozzle[segment.nozzle] = []
		by_nozzle[segment.nozzle].append(segment)

	for nozzle in by_nozzle:
		var column: Array = by_nozzle[nozzle]
		column.sort_custom(func(a, b): return a.open_time < b.open_time)
		for i in range(1, column.size()):
			var earlier: Segment = column[i - 1]
			var later: Segment = column[i]
			if earlier.close_time > later.open_time:
				problems.append(
					"nozzle %d: pulse %.3f..%.3f overlaps the next opening at %.3f"
					% [nozzle, earlier.open_time, earlier.close_time, later.open_time]
				)
	return problems
