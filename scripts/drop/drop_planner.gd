class_name DropPlanner
extends RefCounted
## Turns glyph cells into launch instructions: which nozzle, and when to fire.
##
## The core of DropClock. Drops are launched at staggered times so that, at one
## chosen instant, they are all simultaneously at the height their cell needs.
## See PLAN.md section 2.2.
##
##   t_fall   = sqrt(2 * (y_target - nozzle_y) / gravity)
##   t_launch = t_align - t_fall
##
## Launch times here are RELATIVE to the align moment, so they are negative.
## DropField adds the absolute align time when the drops are emitted.

## One planned drop.
class DropSpec extends RefCounted:
	var x := 0.0            ## nozzle X in pixels
	var nozzle := 0         ## nozzle index, kept for the overtake check
	var y_target := 0.0     ## height this drop must be at when the glyph forms
	var t_launch := 0.0     ## negative: seconds before the align moment
	var width := 0.0
	var height := 0.0
	var brightness := 1.0


## The result of planning one glyph.
class Plan extends RefCounted:
	var specs: Array[DropSpec] = []
	var cell_px := 0.0
	var cols := 0
	var rows := 0
	var scale := 1
	## Most negative t_launch, i.e. how long before the align moment the first
	## drop must be fired.
	var lead := 0.0

	func is_empty() -> bool:
		return specs.is_empty()


static func plan(text: String, s: DropSettings, viewport: Vector2) -> Plan:
	if text.is_empty():
		return Plan.new()
	return plan_mask(GlyphBuilder.build(text, 1), s, viewport)


## Plan any cell mask, from the font or from a pattern file.
static func plan_mask(unit: GlyphBuilder.GlyphData, s: DropSettings, viewport: Vector2,
		height_ratio := -1.0, top_ratio := -1.0, fixed_scale := 0) -> Plan:
	var result := Plan.new()
	if unit == null or unit.is_empty():
		return result

	var height_limit: float = s.glyph_height_ratio if height_ratio <= 0.0 else height_ratio
	var top_fraction: float = s.glyph_top_ratio if top_ratio < 0.0 else top_ratio
	var pitch := viewport.x / float(maxi(1, s.nozzle_count))

	# Pick the largest cell size that fits. If even one nozzle pitch per cell
	# overflows, drop the dot scale and retry with a coarser mask.
	var scale: int = fixed_scale if fixed_scale > 0 else maxi(1, s.dot_scale)
	var glyph: GlyphBuilder.GlyphData = null
	var step := 0
	while true:
		glyph = GlyphBuilder.scale_mask(unit, scale)
		if glyph.is_empty():
			return result
		step = _fit_step(glyph, s, viewport, pitch, height_limit)
		if step > 0 or scale <= 1:
			break
		scale -= 1
	if step <= 0:
		step = 1

	var cell_px := pitch * float(step)
	result.cell_px = cell_px
	result.cols = glyph.cols
	result.rows = glyph.rows
	result.scale = scale

	# Centre the glyph, then snap its left edge onto a nozzle so every column
	# lands exactly on one.
	var glyph_w := float(glyph.cols) * cell_px
	var first_nozzle := int(round((viewport.x - glyph_w) * 0.5 / pitch))
	var top_y := viewport.y * top_fraction

	var base_w := cell_px * s.drop_width_ratio * s.drop_scale
	var base_h := cell_px * s.drop_height_ratio * s.drop_scale
	var lead := 0.0

	for cell in glyph.cells:
		var spec := DropSpec.new()
		spec.nozzle = first_nozzle + cell.x * step
		spec.x = (float(spec.nozzle) + 0.5) * pitch
		spec.y_target = top_y + float(cell.y) * cell_px

		var fall_distance: float = maxf(spec.y_target - s.nozzle_y, 0.0)
		var t_fall := sqrt(2.0 * fall_distance / maxf(s.gravity, 1.0))
		spec.t_launch = -t_fall
		lead = maxf(lead, t_fall)

		var jitter := 1.0 + randf_range(-s.size_jitter, s.size_jitter)
		spec.width = base_w * jitter
		spec.height = base_h * jitter
		spec.brightness = 1.0 - randf() * s.brightness_jitter

		result.specs.append(spec)

	result.lead = lead
	return result


## Largest cell size (in nozzle pitches) that keeps the glyph inside the fit
## limits, or 0 if even a single pitch per cell is too wide.
static func _fit_step(glyph: GlyphBuilder.GlyphData, s: DropSettings, viewport: Vector2,
		pitch: float, height_limit: float) -> int:
	var max_w := viewport.x * s.glyph_fill_ratio
	var max_h := viewport.y * height_limit
	for step in range(s.max_cell_step, 0, -1):
		var cell := pitch * float(step)
		if float(glyph.cols) * cell <= max_w and float(glyph.rows) * cell <= max_h:
			return step
	return 0


## Drops sharing a nozzle must never overtake each other: a lower cell is
## launched earlier and therefore stays below. Free fall guarantees this, but
## anything that varies motion per drop (sway, per-drop gravity, splitting in
## v0.3) can break it, so this stays available as a check.
static func verify_no_overtake(plan_result: Plan) -> Array[String]:
	var problems: Array[String] = []
	var by_nozzle := {}
	for spec in plan_result.specs:
		if not by_nozzle.has(spec.nozzle):
			by_nozzle[spec.nozzle] = []
		by_nozzle[spec.nozzle].append(spec)

	for nozzle in by_nozzle:
		var column: Array = by_nozzle[nozzle]
		column.sort_custom(func(a, b): return a.t_launch < b.t_launch)
		for i in range(1, column.size()):
			var earlier: DropSpec = column[i - 1]
			var later: DropSpec = column[i]
			# Fired earlier, so it must be aiming lower.
			if later.y_target > earlier.y_target:
				problems.append(
					"nozzle %d: drop fired at %.3fs targets y=%.1f, below the later drop at %.3fs targeting y=%.1f"
					% [nozzle, earlier.t_launch, earlier.y_target, later.t_launch, later.y_target]
				)
	return problems
