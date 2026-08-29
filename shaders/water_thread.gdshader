shader_type canvas_item;
render_mode blend_add, unshaded;

// One valve pulse: a vertical capsule spanning the quad SegmentField hands it.
//
// The same shape covers the whole range the concept doc asks for. A long pulse
// makes a tall quad and reads as a thread; a short one makes a quad barely
// taller than it is wide and reads as a bead. Nothing switches; only the
// aspect ratio changes.
//
// Per-segment input arrives through the modulate colour:
//   COLOR.rgb  tint x brightness jitter
//   COLOR.a    cap radius as a fraction of quad height (0.5 = fully round)
//
// UV.y = 0 is the trailing end, UV.y = 1 is the leading end.

// Trailing width relative to the leading end. Water thins out behind the head.
uniform float back_taper : hint_range(0.2, 1.0) = 0.62;
uniform float taper_span : hint_range(0.05, 1.0) = 0.55;

uniform float edge_softness : hint_range(0.01, 1.0) = 0.6;
uniform float hollow : hint_range(0.0, 1.0) = 0.42;
uniform float rim_power : hint_range(0.5, 6.0) = 1.6;

// Glint sits just behind the leading cap.
uniform float highlight_strength : hint_range(0.0, 3.0) = 0.7;
uniform float highlight_inset : hint_range(0.0, 1.0) = 0.55;
uniform float highlight_length : hint_range(0.01, 1.0) = 0.16;

// Slow thickness variation so a long thread is not a perfectly straight tube.
uniform float wobble_amount : hint_range(0.0, 0.5) = 0.10;
uniform float wobble_frequency : hint_range(0.0, 40.0) = 9.0;

void fragment() {
	float cap = clamp(COLOR.a, 0.004, 0.5);
	float y = UV.y;

	// Capsule: straight sides, circular ends.
	float half_w = 0.5;
	if (y < cap) {
		float t = (cap - y) / cap;
		half_w = 0.5 * sqrt(max(1.0 - t * t, 0.0));
	} else if (y > 1.0 - cap) {
		float t = (y - (1.0 - cap)) / cap;
		half_w = 0.5 * sqrt(max(1.0 - t * t, 0.0));
	}

	half_w *= mix(back_taper, 1.0, smoothstep(0.0, taper_span, y));
	half_w *= 1.0 + wobble_amount * sin(y * wobble_frequency + COLOR.r * 40.0);
	half_w = max(half_w, 0.0001);

	float dx = abs(UV.x - 0.5);
	float body = 1.0 - smoothstep((1.0 - edge_softness) * half_w, half_w, dx);

	// Brightness from absolute offset, not offset normalised by local width, so
	// the thinned trailing end stays dim instead of reading as all rim.
	float rim = mix(1.0 - hollow, 1.0, pow(clamp(dx / 0.5, 0.0, 1.0), rim_power));

	float glint_y = 1.0 - cap * highlight_inset;
	float along = (y - glint_y) / highlight_length;
	float across = dx / 0.28;
	float highlight = exp(-(along * along + across * across)) * highlight_strength;

	COLOR = vec4(COLOR.rgb * (rim + highlight), clamp(body, 0.0, 1.0));
}
