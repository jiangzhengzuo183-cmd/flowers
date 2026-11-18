shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform vec4 powder_tint : source_color = vec4(0.65,0.73,0.77,0.36);
void vertex(){
	// Camera-facing world particles, with explicit soft alpha rather than a texture card.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(INV_VIEW_MATRIX[0].xyz*length(MODEL_MATRIX[0].xyz),0.0),
		vec4(INV_VIEW_MATRIX[1].xyz*length(MODEL_MATRIX[1].xyz),0.0),
		vec4(INV_VIEW_MATRIX[2].xyz*length(MODEL_MATRIX[2].xyz),0.0),MODEL_MATRIX[3]);
}
void fragment(){
	vec2 p=UV*2.0-1.0;
	float edge=1.0-smoothstep(0.12,1.0,length(p*vec2(0.90,1.0)));
	float wisps=0.76+0.12*sin(p.x*7.0+p.y*5.0)+0.12*sin(p.y*9.0-p.x*3.0);
	ALBEDO=powder_tint.rgb;
	ALPHA=clamp(edge*wisps*powder_tint.a*COLOR.a,0.0,0.65);
}

