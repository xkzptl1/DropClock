class_name DropSettings
extends RefCounted
## Tunable parameters shared by the planner and the drop field.
##
## Defaults are tuned for the v4 target: 1280x720, 384 nozzles. The concept doc
## makes 720p authoritative for look tuning, so numbers here are chosen at that
## size rather than scaled down from 1080p.

## Downward acceleration in px/s^2. This is a look parameter, not real gravity:
## it sets how long a drop takes to reach the glyph and how fast the glyph
## smears apart afterwards. Larger = faster and shorter-lived.
var gravity := 430.0

## Speed the water already has as it leaves the valve. The concept doc's fall
## model is y = v0*t + g*t^2/2; v0 = 0 is free fall, which is where the look was
## tuned, but pressure at the nozzle is a real knob on the reference machine.
var initial_velocity := 0.0

## Which renderer draws the water.
##   "segments"  valve open/close intervals drawn as water threads (v4 model)
##   "drops"     one rounded drop per glyph cell (the original v0.1 model)
## Both are kept: the thread model is what the reference machine does, but the
## drop model reads as a dot-matrix clock and is worth having on a real panel.
var render_mode := "segments"

## Virtual nozzles across the top edge. Drop X is always snapped to one of
## these, so this also caps the horizontal resolution of a glyph.
## 384 matches the reference machine. At 1280px wide that is a 3.33px pitch, so
## adjacent nozzles blend into a solid stroke rather than reading as dots.
var nozzle_count := 384

## Nozzles sit slightly above the top edge so drops enter frame already moving.
var nozzle_y := -16.0

## Vertical position of the glyph's top row, as a fraction of screen height.
## Trade-off: lower down looks more centred but shortens the fall from the
## glyph to the bottom edge, so the "crumble" phase gets shorter. At 0.25 with
## the default gravity a glyph forms 1.42s after the first drop is fired and is
## gone 0.98s later, which matches the cycle described in the concept doc.
var glyph_top_ratio := 0.25

## Fit constraints when choosing a cell size for a glyph.
var glyph_fill_ratio := 0.90    ## max fraction of screen width the glyph may use
var glyph_height_ratio := 0.34  ## max fraction of screen height

## "drops" mode: each font pixel becomes this many drops per side (2 = 2x2).
var dot_scale := 2

## "segments" mode: upper bound on how many cells a font pixel may expand to.
## The planner picks the largest scale that fits, so a glyph uses as many
## nozzles as it can; that is what turns vertical strokes into long threads
## instead of columns of separate dots.
var max_segment_scale := 24

## Thread width as a multiple of the nozzle pitch. Slightly over 1.0 so
## neighbouring threads touch and a filled stroke reads as one body of water.
var thread_width_ratio := 1.15

## Shortest drawn segment, in pixels. A single isolated cell would otherwise be
## a sub-pixel sliver; the reference machine's shortest valve pulse still makes
## a visible bead.
var min_segment_px := 5.0

## Upper bound on cell size, measured in nozzle pitches.
var max_cell_step := 8

## How much a drop stretches along its path at full speed, as a fraction of
## its resting height. This is the motion blur: the shape grows upward, away
## from the direction of travel, while the leading edge stays put.
var speed_stretch := 0.5

## Drop size relative to one cell.
var drop_width_ratio := 0.62
var drop_height_ratio := 0.82
var size_jitter := 0.18

## User-facing multiplier on top of the ratios above. Exposed in the overlay as
## "drop size" so the ratios stay a design decision and this stays a preference.
var drop_scale := 1.0

## Slightly blue-white reads as light rather than as a coloured object.
var drop_color := Color(0.82, 0.91, 1.0)

## Shader uniforms for the drop's shape and shading. Swap with
## DropLook.lens() / DropLook.luminous(), or --look=NAME on the command line.
var look := DropLook.luminous()
var brightness_jitter := 0.22

## Overall output level. On a transparent panel this is the one setting that
## has to be tuned to the room, so it is a preference, not a constant.
var brightness := 1.0

## How far below the bottom edge a drop travels before it is recycled.
var kill_margin := 40.0

## Fall model shared by both renderers, so the planner and the field can never
## disagree about where the water is.
func fall_distance(t: float) -> float:
	if t <= 0.0:
		return 0.0
	return initial_velocity * t + 0.5 * gravity * t * t


## Inverse of fall_distance: when to open a valve so water arrives at a height.
func time_to_fall(distance: float) -> float:
	if distance <= 0.0:
		return 0.0
	var g: float = maxf(gravity, 1.0)
	var v0 := initial_velocity
	return (-v0 + sqrt(v0 * v0 + 2.0 * g * distance)) / g


## Seconds between cycles, and the pause before the first drop of a cycle.
var cycle_seconds := 90.0
var lead_seconds := 0.35
