shader_type spatial;
// White rim line along every crystal edge that meets open field (DESIGN 7b).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 rim : source_color = vec4(0.902, 0.953, 1.000, 1.0);
uniform float gain = 1.6;
uniform float fade = 1.0;

void fragment() {
	float across = abs(UV.y - 0.5) * 2.0;
	float a = 1.0 - smoothstep(0.55, 1.0, across);
	ALBEDO = rim.rgb * gain;
	ALPHA = a * fade;
}
