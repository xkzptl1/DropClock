class_name SettingsOverlay
extends CanvasLayer
## The only UI in DropClock, and it is hidden unless summoned with Ctrl+Alt+D.
##
## Design rule 1 forbids permanent chrome, so nothing here draws while the clock
## is running. Built in code rather than as a .tscn: it is a plain list of rows,
## and a scene file would only add a second place to keep the wiring in step.

signal changed  ## a preference was edited; the app applies and saves

const PANEL_ALPHA := 0.88
const LABEL_WIDTH := 170
const SLIDER_WIDTH := 220
const READOUT_WIDTH := 80

const RENDER_MODES := ["segments", "drops"]
const RENDER_LABELS := ["水糸 / セグメント", "水滴"]
const LOOK_NAMES := ["luminous", "lens"]
const FPS_VALUES := [30, 60, 120, 0]
const FPS_LABELS := ["30", "60", "120", "無制限"]

var _config: AppConfig
var _rows: GridContainer

## Controls are held by name. An earlier version looked them up by their index
## in the grid, which broke silently the moment a row had a different shape.
var _mode: OptionButton
var _cycle: HSlider
var _gravity: HSlider
var _nozzles: HSlider
var _thread_width: HSlider
var _min_segment: HSlider
var _drop_size: HSlider
var _brightness: HSlider
var _look: OptionButton
var _weekday: CheckBox
var _date: CheckBox
var _patterns_on: CheckBox
var _fps: OptionButton
var _screen: OptionButton
var _autostart: CheckBox

## slider -> its value Label, and slider -> its printf format.
var _readouts := {}
var _formats := {}

## Guards against value_changed firing while we are pushing values in.
var _syncing := false


func setup(config: AppConfig) -> void:
	_config = config
	layer = 100
	visible = false
	_build()
	sync_from_config()


func toggle() -> void:
	visible = not visible
	if visible:
		sync_from_config()


func _build() -> void:
	# CenterContainer rather than a centre anchor preset: the preset positions
	# the panel's corner at the centre, because the panel has no size yet when
	# the preset is applied.
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.06, PANEL_ALPHA)
	style.border_color = Color(0.45, 0.55, 0.7, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	centre.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var title := Label.new()
	title.text = "DropClock"
	title.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	column.add_child(title)

	_rows = GridContainer.new()
	_rows.columns = 3
	_rows.add_theme_constant_override("h_separation", 14)
	_rows.add_theme_constant_override("v_separation", 8)
	column.add_child(_rows)

	_mode = _add_options("描画モード", RENDER_LABELS,
		func(i: int) -> void: _config.render_mode = RENDER_MODES[i])

	_cycle = _add_slider("一巡の長さ", 10.0, 900.0, 5.0, "%.0f 秒",
		func(v: float) -> void: _config.cycle_seconds = v)
	_gravity = _add_slider("落下速度", 200.0, 1500.0, 10.0, "%.0f",
		func(v: float) -> void: _config.gravity = v)
	_nozzles = _add_slider("ノズル数", 64.0, 512.0, 8.0, "%.0f 本",
		func(v: float) -> void: _config.nozzle_count = int(v))
	_thread_width = _add_slider("水糸の太さ", 0.3, 4.0, 0.05, "%.2f",
		func(v: float) -> void: _config.thread_width_ratio = v)
	_min_segment = _add_slider("最短セグメント長", 1.0, 40.0, 1.0, "%.0f px",
		func(v: float) -> void: _config.min_segment_px = v)
	_drop_size = _add_slider("水滴サイズ（水滴モード）", 0.3, 3.0, 0.05, "%.2f",
		func(v: float) -> void: _config.drop_scale = v)
	_brightness = _add_slider("明るさ", 0.1, 2.0, 0.05, "%.2f",
		func(v: float) -> void: _config.brightness = v)

	_look = _add_options("見た目", LOOK_NAMES,
		func(i: int) -> void: _config.look_name = LOOK_NAMES[i])
	_weekday = _add_check("曜日を表示",
		func(on: bool) -> void: _config.show_weekday = on)
	_date = _add_check("日付を表示",
		func(on: bool) -> void: _config.show_date = on)
	_patterns_on = _add_check("柄・季節演出を表示",
		func(on: bool) -> void: _config.show_patterns = on)
	_fps = _add_options("FPS", FPS_LABELS,
		func(i: int) -> void: _config.max_fps = FPS_VALUES[i])
	_screen = _add_options("ディスプレイ", _screen_names(),
		func(i: int) -> void: _config.screen_index = i)
	_autostart = _add_check("Windows 起動時に開始",
		func(on: bool) -> void: Autostart.set_enabled(on))

	column.add_child(_hint("見た目 / 水滴サイズは「水滴」モードのみに効く"))
	column.add_child(_hint("Ctrl+Alt+D または Esc で閉じる ／ 変更は自動保存"))
	column.add_child(_hint("ディスプレイの変更は次回起動から反映"))


func _hint(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.55, 0.62, 0.72))
	return label


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = LABEL_WIDTH
	return label


func _add_slider(text: String, low: float, high: float, step: float,
		format: String, apply: Callable) -> HSlider:
	_rows.add_child(_label(text))

	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.custom_minimum_size.x = SLIDER_WIDTH
	_rows.add_child(slider)

	var readout := Label.new()
	readout.custom_minimum_size.x = READOUT_WIDTH
	_rows.add_child(readout)

	_readouts[slider] = readout
	_formats[slider] = format

	slider.value_changed.connect(func(v: float) -> void:
		_refresh_readout(slider)
		if _syncing:
			return
		apply.call(v)
		changed.emit()
	)
	return slider


func _refresh_readout(slider: HSlider) -> void:
	var readout: Label = _readouts.get(slider)
	if readout != null:
		readout.text = str(_formats[slider]) % slider.value


func _add_options(text: String, items: Array, apply: Callable) -> OptionButton:
	_rows.add_child(_label(text))
	var options := OptionButton.new()
	for item in items:
		options.add_item(str(item))
	_rows.add_child(options)
	_rows.add_child(Control.new())

	options.item_selected.connect(func(index: int) -> void:
		if _syncing:
			return
		apply.call(index)
		changed.emit()
	)
	return options


func _add_check(text: String, apply: Callable) -> CheckBox:
	_rows.add_child(_label(text))
	var box := CheckBox.new()
	_rows.add_child(box)
	_rows.add_child(Control.new())

	box.toggled.connect(func(pressed: bool) -> void:
		if _syncing:
			return
		apply.call(pressed)
		changed.emit()
	)
	return box


func _screen_names() -> Array:
	var names := []
	for i in DisplayServer.get_screen_count():
		var size := DisplayServer.screen_get_size(i)
		names.append("%d:  %dx%d" % [i, size.x, size.y])
	if names.is_empty():
		names.append("0")
	return names


## Push the config into the controls. Readout labels are written directly
## rather than left to value_changed, which does not fire when the value
## happens to already match.
func sync_from_config() -> void:
	_syncing = true

	_mode.selected = maxi(RENDER_MODES.find(_config.render_mode), 0)
	_cycle.value = _config.cycle_seconds
	_gravity.value = _config.gravity
	_nozzles.value = float(_config.nozzle_count)
	_thread_width.value = _config.thread_width_ratio
	_min_segment.value = _config.min_segment_px
	_drop_size.value = _config.drop_scale
	_brightness.value = _config.brightness
	for slider in _readouts:
		_refresh_readout(slider)

	_look.selected = maxi(LOOK_NAMES.find(_config.look_name), 0)
	_weekday.button_pressed = _config.show_weekday
	_date.button_pressed = _config.show_date
	_patterns_on.button_pressed = _config.show_patterns
	_fps.selected = FPS_VALUES.find(_config.max_fps)
	_screen.selected = clampi(_config.screen_index, 0, _screen.item_count - 1)
	_autostart.button_pressed = Autostart.is_enabled()

	var reason := Autostart.unsupported_reason()
	_autostart.disabled = not reason.is_empty()
	_autostart.tooltip_text = reason

	_syncing = false
