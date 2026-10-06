shader_type spatial;
// Finished wall that captured nothing (DESIGN 7b): a solid ice bar with a
// thin gold core line, one quad per cell in a MultiMesh; UV.y runs across
// the bar so neighbouring cells join into one continuous bar.
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled, shadows_disabled;

uniform vec4 ice : source_color = vec4(0.812, 0.894, 1.000, 1.0);
uniform vec4 gold : source_color = vec4(1.000, 0.788, 0.302, 1.0);
uniform float half_w = 0.24;

void fragment() {
	float across = abs(UV.y - 0.5) * 2.0;
	float body = 1.0 - smoothstep(half_w - 0.04, half_w, across);
	float edge = smoothstep(half_w - 0.12, half_w - 0.03, across);
	float core_l = 1.0 - smoothstep(0.03, 0.06, across);
	vec3 col = mix(ice.rgb * 1.05, ice.rgb * 0.72, edge);
	col = mix(col, gold.rgb * 1.3, core_l);
	ALBEDO = col;
	ALPHA = body;
}
