shader_type spatial;
// Captured cells (DESIGN 7c): faceted crystal tiles in one MultiMesh. Albedo
// is the hidden picture sampled at the field position, times a small
// per-instance tint (COLOR). INSTANCE_CUSTOM.x = picture reveal 0..1,
// INSTANCE_CUSTOM.y = extra glow (capture pulse). Lit by hand in an
// unshaded pass so it looks the same on the OpenGL fallback.
render_mode unshaded, cull_back, shadows_disabled;

uniform sampler2D picture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(0.498, 0.714, 1.000, 1.0);
uniform vec4 field_rect = vec4(-5.04, 16.64, 10.08, 11.52);
uniform vec3 light_dir = vec3(-0.45, 0.55, 0.70);
uniform float emission = 0.32;
uniform float pulse_gain = 0.0;

varying vec3 world_pos;
varying vec3 world_n;
varying vec4 custom;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	custom = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 uv = vec2((world_pos.x - field_rect.x) / field_rect.z, (field_rect.y - world_pos.y) / field_rect.w);
	vec3 pic = texture(picture, clamp(uv, vec2(0.002), vec2(0.998))).rgb;
	vec3 base = mix(tint.rgb, pic, custom.x) * COLOR.rgb;
	vec3 n = normalize(world_n);
	vec3 l = normalize(light_dir);
	float ndl = dot(n, l);
	float shade = 0.70 + 0.34 * ndl;
	vec3 h = normalize(l + vec3(0.0, 0.0, 1.0));
	float spec = pow(max(dot(n, h), 0.0), 48.0) * 0.28;
	// Facet edge darkening: side walls of the tile read as bevels.
	float side = 1.0 - smoothstep(0.2, 0.6, n.z);
	vec3 col = base * (shade - side * 0.25) + vec3(spec);
	col += base * (emission + custom.y * 0.9);
	ALBEDO = col;
}
