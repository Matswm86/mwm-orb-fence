shader_type canvas_item;
// Win card backdrop: the scene blurred (mip read) and dimmed (wincard mock).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float dim = 0.5;
uniform float lod = 3.0;
uniform float amount = 1.0;

void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, lod * amount).rgb;
	COLOR = vec4(c * (1.0 - dim * amount), 1.0);
}
