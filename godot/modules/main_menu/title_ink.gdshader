shader_type canvas_item;
uniform float seed = 0.0;
uniform float settled : hint_range(0.0, 1.0) = 0.0;
varying vec4 vertex_tint;
void vertex() {
	vertex_tint = COLOR;
	float frame = mod(floor(TIME * 8.0 + seed * 0.41),3.0);
	vec2 jitter = frame < 0.5 ? vec2(-0.4,0.1) : (frame < 1.5 ? vec2(0.3,-0.25) : vec2(0.1,0.15));
	VERTEX += jitter * settled * 4.5;
}
void fragment() {
	float frame = mod(floor(TIME * 8.0 + seed * 0.41), 3.0);
	vec2 source_pixels = vec2(sin(UV.y * 23.0 + frame * 2.1 + seed), cos(UV.x * 19.0 + frame * 2.4 + seed * 0.7));
	vec2 shift = source_pixels * TEXTURE_PIXEL_SIZE * 0.95 * settled;
	vec4 ink = texture(TEXTURE, UV + shift);
	COLOR = ink * vertex_tint;
}
