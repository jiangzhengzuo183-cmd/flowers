shader_type canvas_item;
render_mode unshaded;
uniform sampler2D fill_mask : filter_linear;
uniform sampler2D pigment : filter_linear;
uniform vec2 ring_center;
uniform vec2 art_size;
uniform int line_frame = 0;
uniform vec2 display_size = vec2(200.0);
uniform float start_angle = -0.7853981634;
uniform float fill : hint_range(0.0,1.0) = 1.0;
uniform float boosted : hint_range(0.0,1.0) = 0.0;
uniform float activation : hint_range(0.0,1.0) = 0.0;
uniform float activation_age = 1.0;
uniform vec4 yellow : source_color = vec4(0.96470588,0.78431373,0.23921569,1.0);
uniform vec4 blue : source_color = vec4(0.50196078,0.74117647,0.89803922,1.0);
void fragment(){
    float key=line_frame==1 ? 1.0 : (line_frame==2 ? -1.0 : 0.0);
    vec2 wiggle=vec2(sin(UV.y*31.0+2.0),cos(UV.x*27.0+1.0))*key*0.42/display_size;
    vec4 stable_mask=texture(fill_mask,UV);
    vec4 shifted_mask=texture(fill_mask,UV+wiggle);
    float contour=max(stable_mask.b*stable_mask.a,shifted_mask.b*shifted_mask.a);
    vec2 sample_uv=UV+wiggle*contour;
    vec4 base=texture(TEXTURE,sample_uv);
    vec4 region=texture(fill_mask,sample_uv);
    float mask=region.r*region.a;
    vec2 offset=(UV-ring_center)*art_size;
    float turn=mod(atan(offset.y,offset.x)-start_angle+6.28318530718,6.28318530718)/6.28318530718;
    float pixel=max(fwidth(turn),0.0005);
    float amount=fill<=0.0 ? 0.0 : (fill>=1.0 ? 1.0 : 1.0-smoothstep(fill-pixel,fill+pixel,turn));
    vec3 paint=mix(yellow.rgb,blue.rgb,boosted);
    // Reuse the authored cream paper grain instead of changing the brown outline.
    float grain=clamp(texture(pigment,UV).r/0.98,0.94,1.035);
    paint*=grain;
    float travel=abs(turn-clamp(activation_age/0.45,0.0,1.0));
    float soft_sweep=exp(-travel*travel*550.0)*activation*0.065;
    paint=mix(paint,blue.rgb*1.04,soft_sweep);
    COLOR=vec4(mix(base.rgb,paint,mask*amount),base.a);
}
