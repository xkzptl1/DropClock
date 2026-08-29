class_name PatternLibrary
extends RefCounted
## Loads the pattern files in assets/patterns and hands out cell masks.
##
## A pattern is a plain text file so it can be edited without touching code and
## without a binary asset pipeline. Everything above the "---" line is metadata,
## everything below is the mask: "#" is a lit cell, anything else is empty.
##
##   id: sakura
##   name: 桜
##   origin: osaka_water_clock_reference
##   season: spring
##   height: 0.50
##   top: 0.18
##   ---
##   ....####....
##   ..########..
##
## The mask becomes the same GlyphData the font produces, so from the planners'
## point of view a flower and the string "14:07" are the same kind of thing.
##
## `origin` is deliberately part of the format. The concept doc requires that
## patterns derived from the Osaka machine stay distinguishable from DropClock's
## own; recording it per file is the only way that survives contact with someone
## adding patterns later.

const DIR := "res://assets/patterns"
const REFERENCE_ORIGIN := "osaka_water_clock_reference"
const ORIGINAL_ORIGIN := "dropclock_original"


class Pattern extends RefCounted:
	var id := ""
	var display_name := ""
	var origin := ORIGINAL_ORIGIN
	var season := "all"
	## -1 means "use the global setting".
	var height_ratio := -1.0
	var top_ratio := -1.0
	var mask: GlyphBuilder.GlyphData = null

	## "mask" draws the file as-is. "scatter" treats the file as one motif and
	## repeats it across the canvas in staggered generations, which is what
	## docs/SAKURA_PATTERN.md requires of the spring sequence.
	var mode := "mask"
	var generations := 3
	var per_generation := 7
	var stagger := 0.2
	var lane_min := 7
	var lane_max := 377
	var band_rows := 46
	var scale_min := 0.85
	var scale_max := 1.35

	func is_scatter() -> bool:
		return mode == "scatter"

	func is_valid() -> bool:
		return mask != null and not mask.is_empty()


var _by_id := {}
var _ids: Array[String] = []


## Returns how many patterns were loaded.
func load_all() -> int:
	_by_id.clear()
	_ids.clear()

	var dir := DirAccess.open(DIR)
	if dir == null:
		push_warning("DropClock: no pattern directory at %s" % DIR)
		return 0

	var names := dir.get_files()
	names.sort()
	for name in names:
		# Exported builds can append .remap to packed files.
		var clean := name.trim_suffix(".remap")
		if not clean.ends_with(".txt"):
			continue
		var path := "%s/%s" % [DIR, clean]
		var text := FileAccess.get_file_as_string(path)
		if text.is_empty():
			push_warning("DropClock: could not read pattern %s" % path)
			continue
		var pattern := parse(text, clean.trim_suffix(".txt"))
		if not pattern.is_valid():
			push_warning("DropClock: pattern %s has no lit cells" % path)
			continue
		_by_id[pattern.id] = pattern
		_ids.append(pattern.id)

	return _ids.size()


func has(id: String) -> bool:
	return _by_id.has(id)


func get_pattern(id: String) -> Pattern:
	return _by_id.get(id)


func ids() -> Array[String]:
	return _ids.duplicate()


## Patterns tagged for this season, plus the all-year ones.
func for_season(season: String) -> Array[String]:
	var out: Array[String] = []
	for id in _ids:
		var pattern: Pattern = _by_id[id]
		if pattern.season == season or pattern.season == "all":
			out.append(id)
	return out


func describe() -> String:
	var lines: Array[String] = []
	for id in _ids:
		var pattern: Pattern = _by_id[id]
		var extra := ""
		if pattern.is_scatter():
			extra = "  scatter %dx%d stagger %.2fs" % [
				pattern.generations, pattern.per_generation, pattern.stagger]
		lines.append("  %-10s %-14s %-6s %s (%d x %d cells)%s"
			% [pattern.id, pattern.display_name, pattern.season,
				pattern.origin, pattern.mask.cols, pattern.mask.rows, extra])
	if lines.is_empty():
		return "  (no patterns loaded)"
	return "\n".join(lines)


static func parse(text: String, fallback_id: String) -> Pattern:
	var pattern := Pattern.new()
	pattern.id = fallback_id

	var body := text
	var split := text.split("---", false, 1)
	if split.size() == 2:
		body = split[1]
		for line in split[0].split("\n"):
			var trimmed := line.strip_edges()
			if trimmed.is_empty():
				continue
			var colon := trimmed.find(":")
			if colon == -1:
				continue
			var key := trimmed.substr(0, colon).strip_edges().to_lower()
			var value := trimmed.substr(colon + 1).strip_edges()
			match key:
				"id":
					pattern.id = value
				"name":
					pattern.display_name = value
				"origin":
					pattern.origin = value
				"season":
					pattern.season = value.to_lower()
				"height":
					pattern.height_ratio = float(value)
				"top":
					pattern.top_ratio = float(value)
				"mode":
					pattern.mode = value.to_lower()
				"generations":
					pattern.generations = maxi(int(value), 1)
				"per_generation":
					pattern.per_generation = maxi(int(value), 1)
				"stagger":
					pattern.stagger = maxf(float(value), 0.0)
				"lane_min":
					pattern.lane_min = int(value)
				"lane_max":
					pattern.lane_max = int(value)
				"band_rows":
					pattern.band_rows = maxi(int(value), 1)
				"scale_min":
					pattern.scale_min = float(value)
				"scale_max":
					pattern.scale_max = float(value)

	if pattern.display_name.is_empty():
		pattern.display_name = pattern.id

	var mask := GlyphBuilder.GlyphData.new()
	var row := 0
	for raw in body.split("\n"):
		var line := raw.strip_edges(false, true)  # keep leading spaces, drop trailing
		if line.is_empty() and mask.cells.is_empty():
			continue  # skip blank lines before the mask starts
		for column in line.length():
			if line[column] == "#":
				mask.cells.append(Vector2i(column, row))
		mask.cols = maxi(mask.cols, line.length())
		row += 1
	mask.rows = row

	# Trailing blank rows would push the mask off centre.
	var lowest := 0
	for cell in mask.cells:
		lowest = maxi(lowest, cell.y)
	mask.rows = mini(mask.rows, lowest + 1)

	pattern.mask = mask
	return pattern
