class_name AppConfig
extends RefCounted
## The subset of state that survives a restart, stored in user://config.cfg.
##
## Deliberately a separate model from DropSettings. DropSettings holds every
## tunable including the ones that are design decisions (nozzle pitch ratios,
## fit limits, tail shape); this holds only what a person is meant to change,
## so a new internal knob never silently becomes a persisted preference.
##
## Missing or malformed files are not an error: the defaults here are the same
## ones DropSettings ships with, so a fresh install and a deleted config behave
## identically. The file is written on first run so there is something concrete
## to hand-edit, and every value is clamped on the way in so editing it badly
## cannot wedge the app.

const PATH := "user://config.cfg"

var screen_index := 0
var max_fps := 60

var cycle_seconds := 90.0
var show_weekday := true
var show_date := true
var show_patterns := true

var render_mode := "segments"
var gravity := 430.0
var nozzle_count := 384
var thread_width_ratio := 1.15
var min_segment_px := 5.0
var drop_scale := 1.0
var brightness := 1.0
var look_name := "luminous"


## True if a config file was found. False means defaults are in use.
func load_file() -> bool:
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return false

	screen_index = int(file.get_value("display", "screen", screen_index))
	max_fps = int(file.get_value("display", "max_fps", max_fps))

	cycle_seconds = float(file.get_value("schedule", "cycle_seconds", cycle_seconds))
	show_weekday = bool(file.get_value("schedule", "show_weekday", show_weekday))
	show_date = bool(file.get_value("schedule", "show_date", show_date))
	show_patterns = bool(file.get_value("schedule", "show_patterns", show_patterns))

	render_mode = str(file.get_value("drops", "render_mode", render_mode))
	gravity = float(file.get_value("drops", "gravity", gravity))
	thread_width_ratio = float(file.get_value("drops", "thread_width_ratio", thread_width_ratio))
	min_segment_px = float(file.get_value("drops", "min_segment_px", min_segment_px))
	nozzle_count = int(file.get_value("drops", "nozzle_count", nozzle_count))
	drop_scale = float(file.get_value("drops", "drop_scale", drop_scale))
	brightness = float(file.get_value("drops", "brightness", brightness))
	look_name = str(file.get_value("drops", "look", look_name))

	_clamp()
	return true


func save_file() -> void:
	_clamp()
	var file := ConfigFile.new()
	file.set_value("display", "screen", screen_index)
	file.set_value("display", "max_fps", max_fps)
	file.set_value("schedule", "cycle_seconds", cycle_seconds)
	file.set_value("schedule", "show_weekday", show_weekday)
	file.set_value("schedule", "show_date", show_date)
	file.set_value("schedule", "show_patterns", show_patterns)
	file.set_value("drops", "render_mode", render_mode)
	file.set_value("drops", "gravity", gravity)
	file.set_value("drops", "thread_width_ratio", thread_width_ratio)
	file.set_value("drops", "min_segment_px", min_segment_px)
	file.set_value("drops", "nozzle_count", nozzle_count)
	file.set_value("drops", "drop_scale", drop_scale)
	file.set_value("drops", "brightness", brightness)
	file.set_value("drops", "look", look_name)
	var err := file.save(PATH)
	if err != OK:
		push_error("DropClock: could not save %s, error %d" % [PATH, err])


## Push preferences into the live objects.
func apply_to(settings: DropSettings, scheduler: Scheduler) -> void:
	settings.render_mode = render_mode
	settings.gravity = gravity
	settings.thread_width_ratio = thread_width_ratio
	settings.min_segment_px = min_segment_px
	settings.nozzle_count = nozzle_count
	settings.drop_scale = drop_scale
	settings.brightness = brightness
	settings.cycle_seconds = cycle_seconds
	settings.look = DropLook.named(look_name)

	scheduler.cycle_seconds = cycle_seconds
	scheduler.show_weekday = show_weekday
	scheduler.show_date = show_date
	scheduler.show_patterns = show_patterns
	# The caller rebuilds: only it knows which patterns are in season.

	Engine.max_fps = max_fps


## A config file written by hand should not be able to wedge the app.
func _clamp() -> void:
	screen_index = maxi(screen_index, 0)
	max_fps = clampi(max_fps, 0, 240)
	cycle_seconds = clampf(cycle_seconds, 10.0, 900.0)
	gravity = clampf(gravity, 100.0, 4000.0)
	nozzle_count = clampi(nozzle_count, 32, 512)
	thread_width_ratio = clampf(thread_width_ratio, 0.3, 4.0)
	min_segment_px = clampf(min_segment_px, 1.0, 40.0)
	if render_mode != "drops":
		render_mode = "segments"
	drop_scale = clampf(drop_scale, 0.3, 3.0)
	brightness = clampf(brightness, 0.1, 2.0)
	if look_name != "lens":
		look_name = "luminous"
