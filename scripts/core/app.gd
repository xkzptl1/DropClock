extends Node2D
## DropClock entry point.
##
## Command line:
##   --dev                 windowed 1280x720 with a visible cursor
##   --screen=N            put the fullscreen window on screen N (default 0)
##   --list-screens        print connected screens and quit
##   --autostart=on|off|status   register or unregister "start with Windows",
##                         then quit. Only works in an exported build.
##   --glyph-test=TEXT     hold TEXT still at its target height instead of
##                         running the clock, to check the pattern is readable
##   --cycle=SECONDS       override the cycle length
##   --dev=WxH             dev window size (default 1280x720)
##   --mode=NAME           renderer: segments (default) or drops
##   --pattern=ID          preview one pattern (still, unless --live)
##   --live                preview in motion rather than frozen at formation
##   --list-patterns       print the pattern library and quit
##   --season=NAME         force spring/summer/autumn/winter
##   --look=NAME           drop appearance: luminous (default) or lens
##   --seed=N              fix the size/brightness jitter, so two captures
##                         differ only by what you actually changed
##   --capture=FILE        save a PNG and quit, for checking the look
##   --capture-after=SEC   when to capture (default 1.0s)
##   --capture-at-align    capture at the instant the glyph forms
##   --settings            open the settings overlay at startup
##
## Ctrl+Alt+D opens the settings overlay. Esc closes it, or quits if it is
## already closed.
##
## Command line options override the saved config for that run only; they are
## never written back to user://config.cfg.

const WEEKDAY_NAMES := [
	"SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY",
]
const MONTH_NAMES := [
	"JAN", "FEB", "MAR", "APR", "MAY", "JUN",
	"JUL", "AUG", "SEP", "OCT", "NOV", "DEC",
]

var settings := DropSettings.new()

var _config := AppConfig.new()
var _patterns := PatternLibrary.new()
var _season := ""
## DropField or SegmentField, chosen by settings.render_mode.
var _field: Node2D
var _field_mode := ""
var _overlay: SettingsOverlay
var _scheduler := Scheduler.new()
var _dev_mode := false
var _glyph_test := ""
var _pattern_test := ""
var _live_preview := false
var _capture_path := ""
var _capture_deadline := -1.0
var _capture_at_align := false
var _captured := false

## Frame timing, collected in dev mode. Average alone is not interesting when
## max_fps caps it at 60; the worst frame is what shows a stall.
const STAT_WARMUP := 0.5
const SLOW_FRAME := 0.033  ## two vsync intervals at 60Hz
const PATTERN_HEADER := "\n"
var _stat_time := 0.0
var _stat_frames := 0
var _worst_delta := 0.0
var _peak_drops := 0


func _ready() -> void:
	var args := _parse_args()

	if args.has("list-screens"):
		print("DropClock: connected screens\n%s" % DisplayManager.describe_screens())
		get_tree().quit()
		return

	# Handled before any window is created, so it can be scripted.
	if args.has("autostart"):
		_run_autostart_command(str(args["autostart"]))
		get_tree().quit()
		return

	_patterns.load_all()
	if args.has("list-patterns"):
		print("DropClock: pattern library" + PATTERN_HEADER + _patterns.describe())
		get_tree().quit()
		return

	_dev_mode = args.has("dev")
	var dev_size := Vector2i.ZERO
	if _dev_mode and typeof(args["dev"]) == TYPE_STRING:
		var wh: PackedStringArray = str(args["dev"]).split("x")
		if wh.size() == 2:
			dev_size = Vector2i(int(wh[0]), int(wh[1]))
	# A bare "--glyph-test" with no value falls back to a sample string.
	var glyph_arg: Variant = args.get("glyph-test", "")
	_glyph_test = "14:07" if typeof(glyph_arg) == TYPE_BOOL else str(glyph_arg)
	if args.has("pattern"):
		_pattern_test = str(args["pattern"])
	_live_preview = args.has("live")
	# Saved preferences first, command line on top. The overrides are not
	# persisted, so experimenting from a terminal cannot corrupt the config.
	var had_config := _config.load_file()
	if not had_config:
		# Write the defaults out on first run so there is a real file to look at
		# and hand-edit, rather than an empty settings directory.
		_config.save_file()
	_config.apply_to(settings, _scheduler)

	if args.has("seed"):
		seed(int(str(args["seed"])))
	if args.has("mode"):
		settings.render_mode = "drops" if str(args["mode"]) == "drops" else "segments"
	if args.has("look"):
		settings.look = DropLook.named(str(args["look"]))
	if args.has("cycle"):
		settings.cycle_seconds = maxf(float(args["cycle"]), 1.0)
		_scheduler.cycle_seconds = settings.cycle_seconds

	var screen_index := _config.screen_index
	if args.has("screen") and typeof(args["screen"]) != TYPE_BOOL:
		screen_index = int(args["screen"])
	DisplayManager.apply(_dev_mode, screen_index, dev_size)

	_rebuild_field()

	if args.has("capture"):
		_capture_path = str(args["capture"])
		_capture_at_align = args.has("capture-at-align") and _glyph_test.is_empty()
		if not _capture_at_align:
			_capture_deadline = float(str(args.get("capture-after", "1.0")))

	_overlay = SettingsOverlay.new()
	_overlay.name = "SettingsOverlay"
	_overlay.setup(_config)
	_overlay.changed.connect(_on_settings_changed)
	add_child(_overlay)

	if args.has("settings"):
		_toggle_overlay()

	_season = str(args["season"]) if args.has("season") else season_now()
	_rebuild_sequence()
	_scheduler.prime(1.0)

	if _dev_mode:
		print("  season: %s, %d patterns loaded" % [_season, _patterns.ids().size()])
		print("  sequence: %s" % _scheduler.describe())

	if _dev_mode:
		print("DropClock: dev mode, Esc quits, Ctrl+Alt+D for settings")
		print("  config: %s" % ("loaded from " + AppConfig.PATH if had_config else "defaults (no file yet)"))
		print("  renderer: %s, drop look: %s"
			% [settings.render_mode, str(args.get("look", _config.look_name))])
		print(DisplayManager.describe_screens())

	if _has_preview():
		# Let the viewport settle after the window mode change before laying out.
		await get_tree().process_frame
		await get_tree().process_frame
		if not _pattern_test.is_empty():
			_show_pattern(_pattern_test)
		else:
			_show_text(_glyph_test)


func _process(delta: float) -> void:
	_stat_time += delta
	if _stat_time > STAT_WARMUP:
		_stat_frames += 1
		_worst_delta = maxf(_worst_delta, delta)
		_peak_drops = maxi(_peak_drops, _field.live_count())
		# A stall is only actionable if you know when it happened.
		if _dev_mode and delta > SLOW_FRAME:
			print("DropClock: slow frame %.1f ms at t=%.2fs (%d drops)"
				% [delta * 1000.0, _stat_time, _field.live_count()])

	if not _captured and not _capture_path.is_empty() and _capture_deadline >= 0.0:
		if _field.now() >= _capture_deadline:
			_captured = true
			_capture_and_quit()
			return

	if _has_preview():
		return
	var step := _scheduler.tick(delta)
	if not step.is_empty():
		_show_step(step)


## Uses _input rather than _unhandled_input so the hotkeys still work while a
## slider in the overlay has focus.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	if event.keycode == KEY_D and event.ctrl_pressed and event.alt_pressed:
		_toggle_overlay()
		get_viewport().set_input_as_handled()
		return

	if event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if _overlay != null and _overlay.visible:
			_toggle_overlay()
			return
		if _dev_mode:
			print("DropClock: %s" % _frame_report())
		get_tree().quit()


## The two renderers are separate nodes, so switching mode swaps the node.
func _rebuild_field() -> void:
	if _field != null:
		remove_child(_field)
		_field.queue_free()

	if settings.render_mode == "drops":
		var drops := DropField.new()
		drops.name = "DropField"
		drops.settings = settings
		drops.static_preview = _is_static_preview()
		_field = drops
	else:
		var segments := SegmentField.new()
		segments.name = "SegmentField"
		segments.settings = settings
		segments.static_preview = _is_static_preview()
		_field = segments

	add_child(_field)
	_field_mode = settings.render_mode


func _toggle_overlay() -> void:
	_overlay.toggle()
	# The cursor has to come back to use the overlay, and go away again after.
	DisplayManager.set_cursor_visible(_overlay.visible or _dev_mode)


## Preferences were edited: push them in, persist, and show something soon so
## the change is visible without waiting out a whole cycle.
func _on_settings_changed() -> void:
	_config.apply_to(settings, _scheduler)
	_config.save_file()
	if settings.render_mode != _field_mode:
		_rebuild_field()
	elif _field is DropField:
		_field.set_look(settings.look)
	_rebuild_sequence()
	_scheduler.prime(1.0)


func _rebuild_sequence() -> void:
	var pool: Array[String] = []
	if _config.show_patterns:
		pool = _patterns.for_season(_season)
	_scheduler.rebuild(pool)


func _show_step(step: Dictionary) -> void:
	var kind := str(step.get("kind", ""))
	if kind == Scheduler.KIND_PAUSE:
		# Showing nothing is a step, not a gap. Do not fill it.
		return
	if kind == Scheduler.KIND_PATTERN:
		_show_pattern(str(step.get("value", "")))
		return
	_show_text(_text_for(kind))


func _show_text(text: String) -> void:
	if text.is_empty():
		return
	_show_mask(text, GlyphBuilder.build(text, 1), -1.0, -1.0)


func _show_pattern(id: String) -> void:
	var pattern := _patterns.get_pattern(id)
	if pattern == null:
		push_warning("DropClock: no pattern named %s" % id)
		return
	if pattern.is_scatter():
		_show_scatter(pattern)
		return
	_show_mask(pattern.id, pattern.mask, pattern.height_ratio, pattern.top_ratio)


## A scattered motif shown as several overlapping generations.
##
## Each generation is an ordinary plan; the only difference is that their
## formation times are staggered, so a later group is already falling before the
## earlier one has left. That is what docs/SAKURA_PATTERN.md means by multiple
## generations coexisting vertically, and it needs no new renderer: the water is
## still emitted from the top and still only falls.
func _show_scatter(pattern: PatternLibrary.Pattern) -> void:
	var viewport := get_viewport_rect().size
	var lanes: int = maxi(settings.nozzle_count, 1)
	var rng := RandomNumberGenerator.new()
	# Drawn from the global RNG so --seed makes a scatter reproducible, which is
	# what lets the resize check compare two runs frame for frame.
	rng.seed = randi()

	var plans: Array = []
	var longest_lead := 0.0
	for generation in pattern.generations:
		var composite := MotifScatter.build(
			pattern.mask, lanes, pattern.band_rows, pattern.per_generation,
			pattern.lane_min, pattern.lane_max,
			pattern.scale_min, pattern.scale_max, rng,
			float(generation) / float(maxi(pattern.generations, 1)))
		if composite.is_empty():
			continue
		var plan := ValvePlanner.plan_mask(
			composite, settings, viewport,
			pattern.height_ratio, pattern.top_ratio, 1)
		if plan.is_empty():
			continue
		plans.append(plan)
		longest_lead = maxf(longest_lead, plan.lead)

	if plans.is_empty():
		push_warning("DropClock: scatter produced nothing for %s" % pattern.id)
		return

	# One base formation for the first generation, then a fixed stagger. Basing
	# it on the longest lead keeps every generation's valves opening in the
	# future no matter which one happens to reach furthest down.
	# Explicitly typed: _field is a Node2D, so now() has no inferable return type.
	var base: float = _field.now() + longest_lead + settings.lead_seconds
	var total_segments := 0
	var total_cells := 0
	for i in plans.size():
		var plan: ValvePlanner.Plan = plans[i]
		_field.emit_plan_at(plan, base + float(i) * pattern.stagger)
		total_segments += plan.segments.size()
		total_cells += plan.cell_count

	if _capture_at_align and _capture_deadline < 0.0:
		_capture_deadline = base

	if _verbose():
		print("DropClock: %s -> %d generations x %d motifs, %d pulses from %d cells, stagger %.2fs, lanes %d..%d"
			% [pattern.id, plans.size(), pattern.per_generation, total_segments,
				total_cells, pattern.stagger, pattern.lane_min, pattern.lane_max])


## The one place water gets scheduled, whether it spells the time or draws a
## flower. Text and patterns reach here as the same kind of cell mask.
func _show_mask(label: String, unit: GlyphBuilder.GlyphData,
		height_ratio: float, top_ratio: float) -> void:
	var viewport := get_viewport_rect().size
	var align_time := 0.0

	if settings.render_mode == "drops":
		var drop_plan := DropPlanner.plan_mask(unit, settings, viewport, height_ratio, top_ratio)
		if drop_plan.is_empty():
			push_warning("DropClock: nothing to draw for %s" % label)
			return
		if _verbose():
			var drop_problems := DropPlanner.verify_no_overtake(drop_plan)
			if drop_problems.is_empty():
				print("DropClock: %s -> %d drops, %d x %d cells at %.1f px, scale %d, lead %.2fs"
					% [label, drop_plan.specs.size(), drop_plan.cols, drop_plan.rows,
						drop_plan.cell_px, drop_plan.scale, drop_plan.lead])
			else:
				push_error("DropClock: overtake check failed for %s:\n%s"
					% [label, "\n".join(drop_problems)])
		align_time = _field.emit_plan(drop_plan)
	else:
		var valve_plan := ValvePlanner.plan_mask(unit, settings, viewport, height_ratio, top_ratio)
		if valve_plan.is_empty():
			push_warning("DropClock: nothing to draw for %s" % label)
			return
		if _verbose():
			var valve_problems := ValvePlanner.verify_no_overlap(valve_plan)
			if valve_problems.is_empty():
				print("DropClock: %s -> %d pulses from %d cells (%.1fx), %d x %d cells, scale %d, lead %.2fs"
					% [label, valve_plan.segments.size(), valve_plan.cell_count,
						float(valve_plan.cell_count) / maxf(valve_plan.segments.size(), 1.0),
						valve_plan.cols, valve_plan.rows, valve_plan.scale, valve_plan.lead])
			else:
				push_error("DropClock: valve overlap check failed for %s:\n%s"
					% [label, "\n".join(valve_problems)])
		align_time = _field.emit_plan(valve_plan)

	if _capture_at_align and _capture_deadline < 0.0:
		_capture_deadline = align_time


func _verbose() -> bool:
	return _dev_mode or _has_preview()


## True when --glyph-test or --pattern is previewing something, which also
## means the scheduler stays out of the way.
func _has_preview() -> bool:
	return not _glyph_test.is_empty() or not _pattern_test.is_empty()


## Whether that preview is frozen at its formation extents. --live renders it in
## motion instead; a pattern whose point is continuous flow cannot be judged
## from a frozen frame.
func _is_static_preview() -> bool:
	return _has_preview() and not _live_preview


## Motifs are chosen by season; "all" patterns are always eligible.
static func season_now() -> String:
	var month: int = int(Time.get_datetime_dict_from_system().month)
	if month >= 3 and month <= 5:
		return "spring"
	if month >= 6 and month <= 8:
		return "summer"
	if month >= 9 and month <= 11:
		return "autumn"
	return "winter"


## Debug aid: save what is on screen right now, then quit. Used to check the
## drop shader without having to sit and watch a 20 second cycle.
func _capture_and_quit() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(_capture_path)
	if err == OK:
		print("DropClock: captured %s (%dx%d, %d drops live, %s)"
			% [_capture_path, image.get_width(), image.get_height(),
				_field.live_count(), _frame_report()])
	else:
		push_error("DropClock: capture failed, error %d" % err)
	get_tree().quit()


func _run_autostart_command(command: String) -> void:
	var reason := Autostart.unsupported_reason()
	if not reason.is_empty():
		print("DropClock: autostart unavailable (%s)" % reason)
		return

	match command:
		"status":
			pass
		"on", "off":
			if not Autostart.set_enabled(command == "on"):
				print("DropClock: autostart %s FAILED" % command)
				return
		_:
			print("DropClock: autostart expects on, off or status (got %s)" % command)
			return

	if Autostart.is_enabled():
		print("DropClock: autostart is now on -> %s" % Autostart.registered_command())
	else:
		print("DropClock: autostart is now off")


func _frame_report() -> String:
	var elapsed := _stat_time - STAT_WARMUP
	if _stat_frames < 2 or elapsed <= 0.0:
		return "no frame data"
	return ("%.1f fps average, worst frame %.1f ms over %d frames, peak %d drops"
		% [_stat_frames / elapsed, _worst_delta * 1000.0, _stat_frames, _peak_drops])


## Kinds come from Scheduler; the constants are shared so a renamed step
## cannot silently start producing empty text.
func _text_for(kind: String) -> String:
	var now := Time.get_datetime_dict_from_system()
	match kind:
		Scheduler.KIND_CLOCK:
			return "%02d:%02d" % [now.hour, now.minute]
		Scheduler.KIND_WEEKDAY:
			return WEEKDAY_NAMES[int(now.weekday) % 7]
		Scheduler.KIND_DATE:
			return "%s %d" % [MONTH_NAMES[(int(now.month) - 1) % 12], int(now.day)]
	push_warning("DropClock: no text for step kind '%s'" % kind)
	return ""


## Accepts "--flag" and "--key=value". Godot's own arguments are ignored
## because nothing here matches them.
func _parse_args() -> Dictionary:
	var out := {}
	var argv := OS.get_cmdline_args()
	argv.append_array(OS.get_cmdline_user_args())
	for arg in argv:
		if not arg.begins_with("--"):
			continue
		var body := arg.substr(2)
		var eq := body.find("=")
		if eq == -1:
			out[body] = true
		else:
			out[body.substr(0, eq)] = body.substr(eq + 1)
	return out
