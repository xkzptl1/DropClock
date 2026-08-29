class_name DropField
extends Node2D
## Holds and draws the live drops. Knows nothing about text or clocks.
##
## Position is analytic rather than integrated: a drop's Y is derived from the
## time since its launch, so it can never drift away from the height the
## planner intended, and a drop that has not been fired yet costs nothing.
##
## Drops live in parallel packed arrays with swap-removal, so nothing is
## allocated per frame. If this stops holding 60fps, the next steps are
## MultiMeshInstance2D and then GPUParticles2D (PLAN.md section 2.3).
##
## Shape comes from shaders/drop.gdshader. Per-drop values reach it through the
## modulate colour, which is all draw_texture_rect can carry: rgb is the tint
## times the brightness jitter, and alpha is the normalised fall speed. Moving
## to MultiMesh later would allow real per-instance custom data instead.

const CAPACITY_STEP := 512
const DROP_SHADER := preload("res://shaders/drop.gdshader")

var settings: DropSettings

## When true, drops are drawn at their target height instead of falling.
## Used by --glyph-test to check that a pattern is readable.
var static_preview := false

var _tex: Texture2D
var _t := 0.0
var _count := 0

var _x := PackedFloat32Array()
var _y := PackedFloat32Array()
var _y_target := PackedFloat32Array()
var _t_launch := PackedFloat32Array()
var _w := PackedFloat32Array()
var _h := PackedFloat32Array()
var _bright := PackedFloat32Array()
var _speed := PackedFloat32Array()  ## normalised 0..1, drives stretch and taper

## The first draw with this material makes the driver compile the pipeline,
## which measured ~90ms and landed in the middle of the first glyph. Drawing a
## throwaway quad up front moves that cost into the blank startup window.
## Additive blending means a black quad contributes nothing, so it cannot be
## seen even though the shader really runs.
var _warmup_frames := 2


func _ready() -> void:
	if settings == null:
		settings = DropSettings.new()
	_tex = _make_drop_texture()
	# The shader additively blends, so overlapping drops accumulate: they are
	# light, not objects.
	var mat := ShaderMaterial.new()
	mat.shader = DROP_SHADER
	settings.look.apply_to(mat)
	material = mat
	_reserve(CAPACITY_STEP)


## Swap the drop's appearance without restarting.
func set_look(look: DropLook) -> void:
	settings.look = look
	if material is ShaderMaterial:
		look.apply_to(material)


## Field clock, in seconds since startup.
func now() -> float:
	return _t


func live_count() -> int:
	return _count


func clear() -> void:
	_count = 0
	queue_redraw()


## Fire a planned glyph so that it forms lead_seconds from now.
func emit_plan(plan: DropPlanner.Plan) -> float:
	var align_time := _t + plan.lead + settings.lead_seconds
	emit_plan_at(plan, align_time)
	return align_time


func emit_plan_at(plan: DropPlanner.Plan, align_time: float) -> void:
	_reserve(_count + plan.specs.size())
	for spec in plan.specs:
		var i := _count
		_x[i] = spec.x
		_y[i] = NAN
		_y_target[i] = spec.y_target
		_t_launch[i] = align_time + spec.t_launch
		_w[i] = spec.width
		_h[i] = spec.height
		_bright[i] = spec.brightness
		_speed[i] = 0.0
		_count += 1
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _count == 0:
		if _warmup_frames > 0:
			queue_redraw()
		return

	var gravity := settings.gravity
	var nozzle_y := settings.nozzle_y
	var kill_y := get_viewport_rect().size.y + settings.kill_margin
	# Terminal speed for this fall, used to normalise the stretch so the look
	# does not change when gravity is retuned.
	var reference_speed: float = maxf(sqrt(2.0 * gravity * (kill_y - nozzle_y)), 1.0)

	if static_preview:
		# Hold each drop at its target height, but give it the speed it would
		# have had on arrival so the shape matches the moving version.
		for i in _count:
			_y[i] = _y_target[i]
			var v := sqrt(2.0 * gravity * maxf(_y_target[i] - nozzle_y, 0.0))
			_speed[i] = clampf(v / reference_speed, 0.0, 1.0)
		queue_redraw()
		return

	var i := 0
	while i < _count:
		var dt := _t - _t_launch[i]
		if dt < 0.0:
			# Not fired yet.
			_y[i] = NAN
			i += 1
			continue
		var y := nozzle_y + 0.5 * gravity * dt * dt
		if y > kill_y:
			_swap_remove(i)
			continue
		_y[i] = y
		_speed[i] = clampf(gravity * dt / reference_speed, 0.0, 1.0)
		i += 1

	queue_redraw()


func _draw() -> void:
	if _warmup_frames > 0:
		_warmup_frames -= 1
		draw_texture_rect(_tex, Rect2(0.0, 0.0, 4.0, 6.0), false, Color(0.0, 0.0, 0.0, 0.5))

	var base := settings.drop_color * settings.brightness
	var stretch := settings.speed_stretch
	for i in _count:
		var y := _y[i]
		if is_nan(y):
			continue
		var w := _w[i]
		var h := _h[i]
		var b := _bright[i]
		var speed := _speed[i]
		# The leading edge stays where the physics put it; the quad grows
		# upward, so the tail trails behind the direction of travel.
		var drawn_h := h * (1.0 + stretch * speed)
		var bottom := y + h * 0.5
		draw_texture_rect(
			_tex,
			Rect2(_x[i] - w * 0.5, bottom - drawn_h, w, drawn_h),
			false,
			Color(base.r * b, base.g * b, base.b * b, speed)
		)


func _swap_remove(i: int) -> void:
	var last := _count - 1
	if i != last:
		_x[i] = _x[last]
		_y[i] = _y[last]
		_y_target[i] = _y_target[last]
		_t_launch[i] = _t_launch[last]
		_w[i] = _w[last]
		_h[i] = _h[last]
		_bright[i] = _bright[last]
		_speed[i] = _speed[last]
	_count = last


func _reserve(n: int) -> void:
	if _x.size() >= n:
		return
	var target: int = int(ceil(float(n) / CAPACITY_STEP)) * CAPACITY_STEP
	_x.resize(target)
	_y.resize(target)
	_y_target.resize(target)
	_t_launch.resize(target)
	_w.resize(target)
	_h.resize(target)
	_bright.resize(target)
	_speed.resize(target)


## The shader ignores this texture and works from UV alone; draw_texture_rect
## just needs something to stretch across the quad. It is kept as a soft blob
## so the drops still look sane if the shader is ever detached.
func _make_drop_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.5),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 32
	tex.height = 32
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex
