shader_type spatial;
// Ball core (DESIGN 7c): unshaded facing ramp orb_core -> orb_mid ->
// orb_shell; the core runs over 1.0 so the glow pass picks it up.
render_mode unshaded, shadows_disabled;

uniform vec4 core : source_color = vec4(1.000, 0.957, 0.925, 1.0);
uniform vec4 mid : source_color = vec4(1.000, 0.702, 0.651, 1.0);
uniform vec4 shell : source_color = vec4(1.000, 0.435, 0.380, 1.0);
uniform float core_gain = 1.7;

void fragment() {
	float f = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 col = mix(core.rgb * core_gain, mid.rgb * 1.2, smoothstep(0.05, 0.55, f));
	col = mix(col, shell.rgb, smoothstep(0.55, 0.95, f));
	ALBEDO = col;
}
