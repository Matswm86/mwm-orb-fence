shader_type spatial;
// Force-field glass + grid in one unshaded quad (DESIGN 7c): field_glass at
// alpha 0.70, anti-aliased grid lines (emission 0.9, under the glow
// threshold) and bright dots at the crossings.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 glass : source_color = vec4(0.039, 0.078, 0.188, 0.70);
uniform vec4 grid : source_color = vec4(0.239, 0.482, 1.000, 1.0);
uniform vec4 dot_color : source_color = vec4(0.612, 0.769, 1.000, 1.0);
uniform vec2 cells = vec2(14.0, 16.0);
uniform float line_px = 1.6;
uniform float dot_px = 4.2;
uniform float cell_px = 72.0;
uniform float grid_gain = 0.9;
uniform float dot_gain = 1.6;
// Dot strength (1 = full; the 21 x 24 grid uses less, QA finding 4).
uniform float dot_mix = 1.0;
uniform float fade = 1.0;

void fragment() {
	vec2 c = UV * cells;
	vec2 f = abs(fract(c + 0.5) - 0.5) * cell_px;
	vec2 w = fwidth(c) * cell_px;
	vec2 inner = step(vec2(0.5), c) * step(c, cells - 0.5);
	float lx = (1.0 - smoothstep(line_px * 0.5 - w.x * 0.5, line_px * 0.5 + w.x * 0.5, f.x)) * inner.x;
	float ly = (1.0 - smoothstep(line_px * 0.5 - w.y * 0.5, line_px * 0.5 + w.y * 0.5, f.y)) * inner.y;
	float line_a = max(lx, ly);
	float d = length(f);
	float dot_a = (1.0 - smoothstep(dot_px - w.x, dot_px + w.x, d)) * inner.x * inner.y;
	vec3 col = glass.rgb;
	col = mix(col, grid.rgb * grid_gain, line_a * 0.85);
	dot_a *= dot_mix;
	col = mix(col, dot_color.rgb * dot_gain, dot_a);
	float a = max(glass.a, max(line_a * 0.9, dot_a));
	ALBEDO = col;
	ALPHA = a * fade;
}
