shader_type canvas_item;
// Fill meter track (DESIGN 4): empty track colour, the fill in the world's
// crystal tint with diagonal facet stripes 36 px apart and a thin white
// highlight on the fill only, clipped to the rounded track.

uniform vec2 size_px = vec2(732.0, 52.0);
uniform float fill = 0.0;
uniform vec4 track : source_color = vec4(0.024, 0.047, 0.110, 1.0);
uniform vec4 tint : source_color = vec4(0.498, 0.714, 1.000, 1.0);
uniform vec4 stripe : source_color = vec4(0.70, 0.84, 1.000, 1.0);
uniform float shimmer = 0.0;

float rbox(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 px = UV * size_px;
	vec2 p = px - size_px * 0.5;
	float r = size_px.y * 0.5;
	float d = rbox(p, size_px * 0.5, r);
	float inside = 1.0 - smoothstep(-0.7, 0.7, d);
	float fill_x = fill * size_px.x;
	// Fill end is rounded too: a capsule from the left end to fill_x.
	vec2 fc = vec2(clamp(px.x, r, max(fill_x - r, r)), r);
	float df = length(px - fc) - r;
	float in_fill = (1.0 - smoothstep(-0.7, 0.7, df)) * step(0.001, fill);
	float s = fract((px.x + px.y) / 36.0);
	float st = smoothstep(0.0, 0.08, s) * (1.0 - smoothstep(0.45, 0.53, s));
	vec3 fc_col = mix(tint.rgb, stripe.rgb, st * 0.85);
	float hl = 1.0 - smoothstep(4.0, 7.0, abs(px.y - 12.0));
	fc_col = mix(fc_col, vec3(1.0), hl * 0.55);
	float sh = shimmer * (1.0 - smoothstep(0.0, 60.0, abs(px.x - (1.0 - shimmer) * fill_x)));
	fc_col += vec3(sh * 0.5);
	vec3 col = mix(track.rgb, fc_col, in_fill);
	COLOR = vec4(col, inside);
}
