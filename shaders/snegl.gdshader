shader_type spatial;
// Snegl state on a ball (DESIGN 6b): a mint spiral around the ball that
// unwinds as the timer runs out (left 1 -> 0), a countdown with no digits.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 mint : source_color = vec4(0.361, 0.949, 0.722, 1.0);
uniform float left = 1.0;
uniform float spin = 0.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float ang = fract((atan(p.y, p.x) + spin) / 6.2831853 + 1.0);
	// Two turns: radius grows from 0.62 to 0.92 along the spiral.
	float best = 0.0;
	for (int k = 0; k < 2; k++) {
		float t = (ang + float(k)) / 2.0;
		float sr = 0.62 + 0.30 * t;
		float on = step(t, left);
		float line_a = 1.0 - smoothstep(0.025, 0.06, abs(r - sr));
		best = max(best, line_a * on);
	}
	ALBEDO = mint.rgb * best * 1.6;
}
