class_name SegmentField
extends Node2D
## Holds and draws valve pulses. The v4 counterpart to DropField.
##
## Each frame a pulse is two positions, both derived analytically from the time
## since its valve opened and closed:
##
##   y_front = fall(now - open_time)                 leading end
##   y_back  = fall(max(now - close_time, 0))        trailing end
##
## While the valve is still open, now - close_time is negative and the trailing
## end stays pinned at the nozzle, which is what draws a curtain still connected
## to the top edge. After it closes, the front keeps accelerating away from the
## back, so the thread stretches and thins on its own. That stretching IS the
## collapse of the glyph; nothing animates it.

const CAPACITY_STEP := 256
const THREAD_SHADER := preload("res://shaders/water_thread.gdshader")

var settings: DropSettings
var static_preview := false

var _tex: Texture2D
var _t := 0.0
var _count := 0
var _warmup_frames := 2

var _x := PackedFloat32Array()
var _open := PackedFloat32Array()
var _close := PackedFloat32Array()
var _w := PackedFloat32Array()
var _bright := PackedFloat32Array()
## Formation-time extents, used by the static preview.
var _y_top := PackedFloat32Array()
var _y_bottom := PackedFloat32Array()


func _ready() -> void:
	if settings == null:
		settings = DropSettings.new()
	_tex = _make_texture()
	var mat := ShaderMaterial.new()
	mat.shader = THREAD_SHADER
	material = mat
	_reserve(CAPACITY_STEP)


func now() -> float:
	return _t


func live_count() -> int:
	return _count


func clear() -> void:
	_count = 0
	queue_redraw()


func emit_plan(plan: ValvePlanner.Plan) -> float:
	var formation := _t + plan.lead + settings.lead_seconds
	emit_plan_at(plan, formation)
	return formation


func emit_plan_at(plan: ValvePlanner.Plan, formation: float) -> void:
	_reserve(_count + plan.segments.size())
	for segment in plan.segments:
		var i := _count
		_x[i] = segment.x
		_open[i] = formation + segment.open_time
		_close[i] = formation + segment.close_time
		_w[i] = segment.width
		_bright[i] = segment.brightness
		_y_top[i] = segment.y_top
		_y_bottom[i] = segment.y_bottom
		_count += 1
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _count == 0:
		if _warmup_frames > 0:
			queue_redraw()
		return

	if static_preview:
		queue_redraw()
		return

	var kill_y := get_viewport_rect().size.y + settings.kill_margin
	var i := 0
	while i < _count:
		# The trailing end is the last thing to leave the screen.
		var back_age: float = maxf(_t - _close[i], 0.0)
		if settings.nozzle_y + settings.fall_distance(back_age) > kill_y:
			_swap_remove(i)
			continue
		i += 1

	queue_redraw()


func _draw() -> void:
	if _warmup_frames > 0:
		_warmup_frames -= 1
		draw_texture_rect(_tex, Rect2(0.0, 0.0, 4.0, 8.0), false, Color(0.0, 0.0, 0.0, 0.3))

	var base := settings.drop_color * settings.brightness
	var nozzle_y := settings.nozzle_y
	var min_len := settings.min_segment_px

	for i in _count:
		var w := _w[i]
		var top := 0.0
		var bottom := 0.0

		if static_preview:
			top = _y_top[i]
			bottom = _y_bottom[i]
		else:
			var front_age := _t - _open[i]
			if front_age < 0.0:
				continue  # valve has not opened yet
			bottom = nozzle_y + settings.fall_distance(front_age)
			top = nozzle_y + settings.fall_distance(maxf(_t - _close[i], 0.0))

		# A single-cell pulse would otherwise be a sub-pixel sliver. Keep the
		# leading end where the physics put it and extend backwards.
		var length: float = maxf(bottom - top, maxf(min_len, w))
		top = bottom - length

		var cap: float = clampf(w * 0.5 / length, 0.004, 0.5)
		var b := _bright[i]
		draw_texture_rect(
			_tex,
			Rect2(_x[i] - w * 0.5, top, w, length),
			false,
			Color(base.r * b, base.g * b, base.b * b, cap)
		)


func _swap_remove(i: int) -> void:
	var last := _count - 1
	if i != last:
		_x[i] = _x[last]
		_open[i] = _open[last]
		_close[i] = _close[last]
		_w[i] = _w[last]
		_bright[i] = _bright[last]
		_y_top[i] = _y_top[last]
		_y_bottom[i] = _y_bottom[last]
	_count = last


func _reserve(n: int) -> void:
	if _x.size() >= n:
		return
	var target: int = int(ceil(float(n) / CAPACITY_STEP)) * CAPACITY_STEP
	_x.resize(target)
	_open.resize(target)
	_close.resize(target)
	_w.resize(target)
	_bright.resize(target)
	_y_top.resize(target)
	_y_bottom.resize(target)


## Only a UV carrier; the shader ignores the texture's content.
func _make_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 8
	tex.height = 8
	return tex
