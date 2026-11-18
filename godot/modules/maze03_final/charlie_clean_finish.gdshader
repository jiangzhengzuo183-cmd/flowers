// Continuous authored albedo and original skinned normals. No moving position masks.
shader_type spatial;
render_mode cull_disabled,diffuse_lambert_wrap,specular_disabled;
uniform sampler2D base_color : source_color,filter_linear_mipmap,repeat_enable;
vec3 similar(vec3 center,vec3 other){
 float weight=exp(-dot(center-other,center-other)*100.0);
 return mix(center,other,weight);
}
void fragment(){
 vec3 original=texture(base_color,UV).rgb;
 vec2 pixel=1.0/vec2(textureSize(base_color,0));
 vec3 average=original*4.0;
 average+=similar(original,texture(base_color,UV+pixel*vec2(2.0,0.0)).rgb);
 average+=similar(original,texture(base_color,UV-pixel*vec2(2.0,0.0)).rgb);
 average+=similar(original,texture(base_color,UV+pixel*vec2(0.0,2.0)).rgb);
 average+=similar(original,texture(base_color,UV-pixel*vec2(0.0,2.0)).rgb);
 vec3 color=average/8.0;
 float tone=dot(color,vec3(0.2126,0.7152,0.0722));
 // Lift only painted mid-dark creases; protect eyes, outlines and original color boundaries.
 float lift=smoothstep(0.025,0.09,tone)*(1.0-smoothstep(0.15,0.48,tone))*0.034;
 vec3 clean=color*(1.0+lift/max(tone,0.035));
 float grey=dot(clean,vec3(0.2126,0.7152,0.0722));
 ALBEDO=mix(clean,vec3(grey),0.035);
 ROUGHNESS=0.86;
 EMISSION=ALBEDO*0.065;
}
