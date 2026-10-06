shader_type spatial;
// Camera-facing additive glow: radial blob (mode 0), ring (mode 1) or
// 4-point diamond tip (mode 2). Used for ball halos, beam tips, the wall
// origin ring and the token halo.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.435, 0.380, 1.0);
uniform float gain = 1.0;
uniform int mode = 0;
uniform float ring_r = 0.32;
uniform float ring_w = 0.06;
uniform float alpha = 1.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a;
	if (mode == 1) {
		a = 1.0 - smoothstep(0.0, ring_w, abs(r - ring_r));
		a += (1.0 - smoothstep(0.0, ring_w * 4.0, abs(r - ring_r))) * 0.25;
	} else if (mode == 2) {
		float dm = abs(p.x) + abs(p.y);
		a = (1.0 - smoothstep(0.10, 0.34, dm)) * 1.6 + pow(max(1.0 - r, 0.0), 2.4) * 0.7;
	} else {
		a = pow(max(1.0 - r, 0.0), 2.2);
	}
	ALBEDO = color.rgb * a * gain * alpha;
}
