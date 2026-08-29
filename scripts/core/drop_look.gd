class_name DropLook
extends RefCounted
## The drop's appearance: one bundle of uniforms for shaders/drop.gdshader.
##
## Two presets are kept because the choice depends on hardware nobody has
## measured yet. On a transparent OLED the panel competes with the light in the
## room, so the brighter preset may simply survive better than the more
## literally water-like one. Decide on the real panel, not on a monitor.
##
## Field names match the shader's uniform names exactly.

var body_center := 0.66
var body_center_fast := 0.78
var tail_power := 1.8
var tail_power_fast := 3.2
var tail_fade := 0.3
var edge_softness := 0.55
var hollow := 0.42
var rim_power := 1.6
var highlight_strength := 0.7
var highlight_offset := 0.08
var highlight_size := Vector2(0.15, 0.10)


## Soft glow filling the drop: a droplet of light. The brighter of the two.
static func luminous() -> DropLook:
	return DropLook.new()


## A tight glint high on the shoulder over a dimmer body, so the middle reads
## as something you can see through. Closer to the concept doc's
## "中央はやや透明 / 上部にハイライト".
static func lens() -> DropLook:
	var look := DropLook.new()
	look.hollow = 0.55
	look.rim_power = 1.2
	look.highlight_strength = 0.95
	look.highlight_offset = 0.02
	look.highlight_size = Vector2(0.11, 0.07)
	return look


static func named(look_name: String) -> DropLook:
	match look_name.to_lower():
		"lens", "b":
			return lens()
		"luminous", "a", "":
			return luminous()
	push_warning("DropClock: unknown drop look '%s', using luminous" % look_name)
	return luminous()


func as_dict() -> Dictionary:
	return {
		"body_center": body_center,
		"body_center_fast": body_center_fast,
		"tail_power": tail_power,
		"tail_power_fast": tail_power_fast,
		"tail_fade": tail_fade,
		"edge_softness": edge_softness,
		"hollow": hollow,
		"rim_power": rim_power,
		"highlight_strength": highlight_strength,
		"highlight_offset": highlight_offset,
		"highlight_size": highlight_size,
	}


func apply_to(mat: ShaderMaterial) -> void:
	var values := as_dict()
	for key in values:
		mat.set_shader_parameter(key, values[key])
