shader_type canvas_item;
uniform float blur_radius=12.0;
uniform float opacity=0.22;
void fragment() {
	float shade=0.0;
	for(int x=-1;x<=1;x++) {
		for(int y=-1;y<=1;y++) shade+=texture(TEXTURE,UV+vec2(float(x),float(y))*blur_radius*TEXTURE_PIXEL_SIZE).a;
	}
	COLOR=vec4(0.32,0.22,0.13,shade/9.0*opacity);
}
