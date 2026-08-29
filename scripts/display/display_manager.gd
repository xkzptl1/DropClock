class_name DisplayManager
extends RefCounted
## Window and monitor placement.
##
## The product state is borderless fullscreen, pure black, no cursor. That is
## also unusable to develop against, so --dev gives back a normal window and a
## visible cursor. Esc always quits (handled in app.gd) so there is a way out
## of fullscreen regardless.

const DEV_WINDOW_SIZE := Vector2i(1280, 720)


static func apply(dev_mode: bool, screen_index: int, dev_size: Vector2i = Vector2i.ZERO) -> void:
	# Black is not a background colour here: on a transparent OLED it is the
	# absence of light, i.e. the real room behind the panel.
	RenderingServer.set_default_clear_color(Color.BLACK)

	if dev_mode:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(DEV_WINDOW_SIZE if dev_size.x <= 0 else dev_size)
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return

	var count := DisplayServer.get_screen_count()
	var index: int = clampi(screen_index, 0, maxi(count - 1, 0))
	if index != screen_index:
		push_warning("DropClock: screen %d not found (%d connected), using screen %d" % [screen_index, count, index])
	DisplayServer.window_set_current_screen(index)
	# WINDOW_MODE_FULLSCREEN is borderless fullscreen; EXCLUSIVE_FULLSCREEN
	# takes over the mode-set and is not what an always-on display wants.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


static func set_cursor_visible(visible: bool) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_HIDDEN)


## Human-readable list of connected screens, for --list-screens and dev logging.
static func describe_screens() -> String:
	var lines: Array[String] = []
	var count := DisplayServer.get_screen_count()
	var current := DisplayServer.window_get_current_screen()
	for i in count:
		var size := DisplayServer.screen_get_size(i)
		var pos := DisplayServer.screen_get_position(i)
		var hz := DisplayServer.screen_get_refresh_rate(i)
		lines.append(
			"  screen %d: %dx%d at (%d, %d), %.0f Hz%s"
			% [i, size.x, size.y, pos.x, pos.y, hz, "  <- current" if i == current else ""]
		)
	if lines.is_empty():
		return "  (no screens reported)"
	return "\n".join(lines)
