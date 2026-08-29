shader_type canvas_item;
render_mode blend_add, unshaded;

// One water drop, drawn into the quad DropField hands it.
//
// The quad's bottom edge stays pinned to the drop's actual position and grows
// upward with speed, so the taper doubles as motion blur: the shape leans back
// along the path the drop just travelled.
//
// Per-drop input arrives through the modulate colour:
//   COLOR.rgb  tint x brightness jitter
//   COLOR.a    normalised fall speed, 0..1
//
// UV is (0,0) at the top-left of the quad, so UV.y = 1 is the leading edge.

// Where the round body sits, at rest and at full speed.
uniform float body_center : hint_range(0.0, 1.0) = 0.66;
uniform float body_center_fast : hint_range(0.0, 1.0) = 0.78;

// Taper of the trailing edge. Higher is a thinner, sharper tail.
uniform float tail_power : hint_range(0.5, 6.0) = 1.8;
uniform float tail_power_fast : hint_range(0.5, 6.0) = 3.2;

// How far down the quad the tail fades in from nothing.
uniform float tail_fade : hint_range(0.01, 1.0) = 0.3;

// Silhouette softness. These drops are ~15px across, so the edge does most of
// the work of making them read as water rather than as dots.
uniform float edge_softness : hint_range(0.01, 1.0) = 0.55;

// Water is brighter at the rim than through the middle.
uniform float hollow : hint_range(0.0, 1.0) = 0.42;
uniform float rim_power : hint_range(0.5, 6.0) = 1.6;

// Specular glint, placed just below the widest point of the body so it sits on
// the drop's upper shoulder. Offset from the body centre rather than fixed, so
// it follows the body as the drop stretches.
uniform float highlight_strength : hint_range(0.0, 3.0) = 0.7;
uniform float highlight_offset : hint_range(-0.5, 0.5) = 0.08;
uniform vec2 highlight_size = vec2(0.15, 0.10);

void fragment() {
	float speed = clamp(COLOR.a, 0.0, 1.0);

	// Half-width of the drop at this height.
	float yc = mix(body_center, body_center_fast, speed);
	float half_w;
	if (UV.y < yc) {
		// Trailing taper.
		float t = UV.y / max(yc, 0.0001);
		half_w = 0.5 * pow(t, mix(tail_power, tail_power_fast, speed));
	} else {
		// Round leading edge.
		float t = (UV.y - yc) / max(1.0 - yc, 0.0001);
		half_w = 0.5 * sqrt(max(1.0 - t * t, 0.0));
	}
	half_w = max(half_w, 0.0001);

	float dx = abs(UV.x - 0.5);
	float body = 1.0 - smoothstep((1.0 - edge_softness) * half_w, half_w, dx);
	body *= smoothstep(0.0, tail_fade, UV.y);

	// Rim brightness comes from the absolute distance off the axis, not from
	// the distance normalised by the local width. Normalising made the narrow
	// tail count as "all rim" and turned it into the brightest part of the
	// drop, which read as a spike pointing the wrong way.
	float rim = mix(1.0 - hollow, 1.0, pow(clamp(dx / 0.5, 0.0, 1.0), rim_power));

	vec2 hv = (UV - vec2(0.5, yc + highlight_offset)) / highlight_size;
	float highlight = exp(-dot(hv, hv)) * highlight_strength;

	COLOR = vec4(COLOR.rgb * (rim + highlight), clamp(body, 0.0, 1.0));
}
