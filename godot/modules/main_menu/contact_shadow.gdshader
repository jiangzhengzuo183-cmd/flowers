shader_type canvas_item;
uniform float movement : hint_range(0.0,1.0) = 0.0;
uniform float indentation : hint_range(0.0,1.0) = 1.0;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
void fragment() {
	vec2 step_uv = TEXTURE_PIXEL_SIZE*3.0;
	float center = texture(TEXTURE,UV).a;
	float narrow = 0.0;
	float wide = 0.0;
	for (int x=-1;x<=1;x++) {
		for (int y=-1;y<=1;y++) {
			vec2 direction = vec2(float(x),float(y));
			narrow += texture(TEXTURE,UV+direction*step_uv).a;
			wide += texture(TEXTURE,UV+direction*step_uv*2.0).a;
		}
	}
	narrow /= 9.0;
	wide /= 9.0;
	float edge = max(narrow-center*0.45,0.0);
	float soft = max(wide-center*0.60,0.0);
	float left = texture(TEXTURE,UV+vec2(step_uv.x,0.0)).a;
	float right = texture(TEXTURE,UV-vec2(step_uv.x,0.0)).a;
	float up = texture(TEXTURE,UV+vec2(0.0,step_uv.y)).a;
	float down = texture(TEXTURE,UV-vec2(0.0,step_uv.y)).a;
	float paper_ridge = max((left-right)*0.55+(up-down)*0.75,0.0)*indentation;
	vec3 shade = mix(vec3(0.40,0.31,0.22),vec3(1.0,0.97,0.88),paper_ridge*0.60);
	float alpha = edge*(0.12+indentation*0.04)+soft*0.065;
	COLOR = vec4(shade,alpha)*vertex_tint;
}
