shader_type canvas_item;
// Win card picture window: rounded corners and an ink frame.

uniform vec2 size_px = vec2(780.0, 650.0);
uniform float radius_px = 36.0;
uniform float border_px = 5.0;
uniform vec4 ink : source_color = vec4(0.141, 0.129, 0.114, 1.0);
uniform float reveal = 1.0;

varying vec2 local_uv;

void vertex() {
	local_uv = VERTEX / size_px;
}

float rbox(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = (local_uv - 0.5) * size_px;
	float d = rbox(p, size_px * 0.5, radius_px);
	vec4 c = texture(TEXTURE, UV);
	c.rgb = mix(c.rgb * 0.0 + vec3(0.30, 0.45, 0.85), c.rgb, reveal);
	float inside = 1.0 - smoothstep(-0.5, 0.5, d);
	float frame = smoothstep(-border_px - 0.5, -border_px + 0.5, d);
	COLOR = vec4(mix(c.rgb, ink.rgb, frame), inside);
}
