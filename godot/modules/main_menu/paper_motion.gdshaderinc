vec2 paper_shift(float phase,float amount) {
	float frame=mod(floor(TIME*7.0+phase),3.0);
	return (frame<0.5?vec2(-0.6,0.22):(frame<1.5?vec2(0.48,-0.30):vec2(0.12,0.08)))*amount;
}
float paper_turn(float phase,float amount) {
	float frame=mod(floor(TIME*7.0+phase),3.0);
	return sin(frame*2.1+phase)*0.00017*amount;
}
vec2 paper_rotate(vec2 p,float angle) {
	return vec2(p.x*cos(angle)-p.y*sin(angle),p.x*sin(angle)+p.y*cos(angle));
}
vec2 paper_motion(vec2 p,vec2 size,float phase,float amount) {
	return size*0.5+paper_rotate(p-size*0.5,paper_turn(phase,amount))+paper_shift(phase,amount);
}
vec2 paper_unmotion(vec2 p,vec2 size,float phase,float amount) {
	return size*0.5+paper_rotate(p-size*0.5-paper_shift(phase,amount),-paper_turn(phase,amount));
}

vec2 paper_attached_vertex(vec2 local,mat4 model,vec2 origin,vec2 size) {
	vec4 world=model*vec4(local,0.0,1.0);
	world.xy=paper_motion(world.xy-origin,size,1.86,1.35)+origin;
	return (inverse(model)*world).xy;
}
