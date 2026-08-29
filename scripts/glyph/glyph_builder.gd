class_name GlyphBuilder
extends RefCounted
## Turns a string into a grid of lit cells.
##
## This layer knows nothing about physics or the screen; it works purely in
## grid coordinates. See PLAN.md section 2.1.
##
## GlyphData is the common currency between text and patterns: PatternLibrary
## produces the same type from a file, so the planners never learn whether a
## mask came from the font or from a drawing.

## A rasterised string: lit cells plus the grid extents they occupy.
class GlyphData extends RefCounted:
	var cells: Array[Vector2i] = []
	var cols := 0
	var rows := 0

	func is_empty() -> bool:
		return cells.is_empty()


## Expand every cell into a scale x scale block.
##
## The planners call this after they have chosen how large the mask may be, so
## scaling is a layout decision rather than something baked into the source.
static func scale_mask(mask: GlyphData, scale: int) -> GlyphData:
	var s: int = maxi(1, scale)
	if s == 1:
		return mask

	var out := GlyphData.new()
	out.cols = mask.cols * s
	out.rows = mask.rows * s
	for cell in mask.cells:
		var base_x: int = cell.x * s
		var base_y: int = cell.y * s
		for sy in s:
			for sx in s:
				out.cells.append(Vector2i(base_x + sx, base_y + sy))
	return out


## Rasterise text into grid cells.
## [param scale] repeats each font pixel scale x scale times, which raises the
## drop count without needing a higher-resolution font.
static func build(text: String, scale: int = 1) -> GlyphData:
	var data := GlyphData.new()
	var s: int = maxi(1, scale)
	var chars := text.to_upper()
	if chars.is_empty():
		return data

	data.cols = (chars.length() * Font5x7.ADVANCE - 1) * s
	data.rows = Font5x7.HEIGHT * s

	for i in chars.length():
		var rows: Array = Font5x7.rows_for(chars[i])
		var col_offset: int = i * Font5x7.ADVANCE
		for py in Font5x7.HEIGHT:
			var line: String = rows[py]
			for px in Font5x7.WIDTH:
				if line[px] != "#":
					continue
				var base_x: int = (col_offset + px) * s
				var base_y: int = py * s
				for sy in s:
					for sx in s:
						data.cells.append(Vector2i(base_x + sx, base_y + sy))

	return data
