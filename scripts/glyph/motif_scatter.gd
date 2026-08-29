class_name MotifScatter
extends RefCounted
## Places one motif many times across the canonical emitter lanes.
##
## docs/SAKURA_PATTERN.md rejects both failure modes explicitly: one enormous
## centred flower, and a tidy evenly spaced grid. So placement is stratified —
## the lane range is divided into as many bands as there are motifs and each
## motif is jittered inside its own band. That guarantees full-width coverage
## (no huge empty fields) while never landing on a regular pitch.
##
## Everything here is in canonical lane/cell space, so a window resize cannot
## rearrange or regenerate anything.

## Build one generation: [param count] motifs scattered across the lane range.
## [param phase] (0..1) shifts this generation's bands so generations interleave.
##
## [param cols] is the full canonical lane count, so the composite always spans
## the canvas and the planner has nothing left to scale.
static func build(motif: GlyphBuilder.GlyphData, cols: int, band_rows: int,
		count: int, lane_min: int, lane_max: int,
		scale_min: float, scale_max: float,
		rng: RandomNumberGenerator, phase := 0.0) -> GlyphBuilder.GlyphData:
	var out := GlyphBuilder.GlyphData.new()
	out.cols = cols
	out.rows = band_rows
	if motif == null or motif.is_empty() or count <= 0:
		return out

	var span: int = maxi(lane_max - lane_min, 1)
	var band: float = float(span) / float(count)
	var occupied := {}

	for i in count:
		var factor := rng.randf_range(scale_min, scale_max)
		var shape := _resample(motif, factor)
		if shape.is_empty():
			continue

		# One motif per band, jittered inside it: irregular, but never clumped
		# into a corner and never on a regular pitch. The phase offset shifts a
		# whole generation sideways, so successive generations interleave with
		# each other instead of landing in the same slots.
		var band_start := float(lane_min) + band * (float(i) + phase)
		if band_start > float(lane_max):
			band_start -= float(span)
		var slack: float = maxf(band - float(shape.cols), 0.0)
		var x0 := int(round(band_start + rng.randf() * slack))
		x0 = clampi(x0, lane_min, maxi(lane_max - shape.cols, lane_min))

		var y_slack: int = maxi(band_rows - shape.rows, 0)
		var y0 := rng.randi_range(0, y_slack)

		for cell in shape.cells:
			var placed := Vector2i(cell.x + x0, cell.y + y0)
			if placed.x < 0 or placed.x >= cols or placed.y < 0 or placed.y >= band_rows:
				continue
			occupied[placed] = true

	for key in occupied:
		out.cells.append(key)
	return out


## Nearest-neighbour resample, so motifs can vary in size without needing a
## separate mask per size.
static func _resample(motif: GlyphBuilder.GlyphData, factor: float) -> GlyphBuilder.GlyphData:
	var out := GlyphBuilder.GlyphData.new()
	if factor <= 0.0:
		return out
	if is_equal_approx(factor, 1.0):
		out.cols = motif.cols
		out.rows = motif.rows
		out.cells = motif.cells.duplicate()
		return out

	out.cols = maxi(int(round(float(motif.cols) * factor)), 1)
	out.rows = maxi(int(round(float(motif.rows) * factor)), 1)

	var lit := {}
	for cell in motif.cells:
		lit[cell] = true

	for y in out.rows:
		var sy: int = clampi(int(floor(float(y) / factor)), 0, motif.rows - 1)
		for x in out.cols:
			var sx: int = clampi(int(floor(float(x) / factor)), 0, motif.cols - 1)
			if lit.has(Vector2i(sx, sy)):
				out.cells.append(Vector2i(x, y))
	return out
