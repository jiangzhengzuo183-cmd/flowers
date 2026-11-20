// Composite the generated correction ONLY over the four original paw patches.
// The original face, texture, body, whiskers and tail are sampled unchanged everywhere else.
uniform sampler2D pawless_art : source_color,filter_linear_mipmap;
float paw_patch(vec2 p,vec2 low,vec2 high) {
	vec2 fade=smoothstep(low,low+vec2(2.0),p)*(1.0-smoothstep(high-vec2(2.0),high,p));
	return fade.x*fade.y;
}
vec4 mouse_without_paws(vec4 original,vec2 uv) {
	vec2 pixel=uv*vec2(1024.0,1536.0);
	float patch=paw_patch(pixel,vec2(292.0,514.0),vec2(345.0,573.0));
	patch=max(patch,paw_patch(pixel,vec2(679.0,514.0),vec2(733.0,573.0)));
	patch=max(patch,paw_patch(pixel,vec2(290.0,908.0),vec2(351.0,963.0)));
	patch=max(patch,paw_patch(pixel,vec2(676.0,908.0),vec2(736.0,963.0)));
	if(patch<0.001) return original;
	vec4 correction=texture(pawless_art,uv);
	correction.a=smoothstep(0.20,0.95,correction.a);
	return mix(original,correction,patch);
}
