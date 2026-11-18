
float hash21(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise2(vec2 p) {
	vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1)),f.x),f.y);
}
vec3 trial_background(vec3 direction) {
	float h=clamp(direction.y,0.0,1.0);
	vec3 horizon=vec3(0.81,0.89,0.95);
	vec3 middle=vec3(0.43,0.68,0.88);
	vec3 zenith=vec3(0.22,0.43,0.73);
	vec3 color=mix(horizon,middle,smoothstep(0.0,0.42,h));
	color=mix(color,zenith,smoothstep(0.28,1.0,h));
	float sunward=pow(max(0.0,dot(direction,normalize(vec3(-0.42,0.38,-0.62)))),7.0);
	color=mix(color,vec3(0.94,0.92,0.84),sunward*0.33);
	// Broad directional wisps, never a dense tiled noise texture.
	vec2 p=direction.xz/max(direction.y+0.20,0.16);
	p=mat2(vec2(0.87,0.5),vec2(-0.5,0.87))*p;
	float n=noise2(p*1.8+vec2(TIME*0.0025,0.0))*0.7+noise2(p*4.1)*0.3;
	float bands=exp(-pow((p.y-0.28+sin(p.x*0.7)*0.16)*4.8,2.0));
	bands+=exp(-pow((p.y+0.85+sin(p.x*0.6)*0.23)*5.8,2.0))*0.65;
	bands+=exp(-pow((p.y-1.55+sin(p.x*0.43)*0.16)*3.6,2.0))*0.45;
	float cloud=bands*smoothstep(0.26,0.65,n)*smoothstep(0.025,0.16,h);
	return mix(color,vec3(0.91,0.94,0.97),cloud*0.62);
}

