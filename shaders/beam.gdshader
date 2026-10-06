shader_type spatial;
// Growing wall (DESIGN 7b/7c): dashed gold sleeve with a white-hot core,
// dashes scroll outward from the origin. UV.x runs along the wall (0..1
// over len_px), UV.y across it. Additive, unshaded.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 beam : source_color = vec4(1.000, 0.788, 0.302, 1.0);
uniform vec4 beam_core : source_color = vec4(1.000, 0.965, 0.855, 1.0);
uniform float len_px = 72.0;
uniform float origin_u = 0.5;
uniform float dash_px = 30.0;
uniform float speed_px = 140.0;
uniform float fade = 1.0;

void fragment() {
	float along = abs(UV.x - origin_u) * len_px;
	float across = abs(UV.y - 0.5) * 2.0;
	float dash = step(0.42, fract(along / dash_px - TIME * speed_px / dash_px));
	float sleeve = (1.0 - smoothstep(0.16, 0.36, across)) * mix(0.6, 1.0, dash);
	float glow = pow(max(1.0 - across, 0.0), 2.0) * 0.55;
	float core_l = 1.0 - smoothstep(0.05, 0.10, across);
	vec3 col = beam.rgb * (sleeve * 1.5 + glow) + beam_core.rgb * core_l * 2.4;
	ALBEDO = col * fade;
}
