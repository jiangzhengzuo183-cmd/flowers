vec2 mouse_tail_uv(vec2 uv,float movement) {
	float t=clamp((uv.y-0.66)/0.282,0.0,1.0);
	float wave=sin(TIME*2.05-t*3.7)+0.28*sin(TIME*3.45-t*6.1+1.2);
	float bend=t*t*0.040*(0.72+movement*0.55)*wave;
	return uv-vec2(bend,0.0);
}
