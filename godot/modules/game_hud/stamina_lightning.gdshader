shader_type canvas_item;
render_mode unshaded;
uniform sampler2D masks : filter_linear;
uniform int line_frame = 0;
uniform vec2 display_size = vec2(200.0);
void fragment(){
    float key=line_frame==1 ? 1.0 : (line_frame==2 ? -1.0 : 0.0);
    vec2 wiggle=vec2(sin(UV.y*31.0+2.0),cos(UV.x*27.0+1.0))*key*0.42/display_size;
    vec4 stable=texture(masks,UV);
    vec4 shifted=texture(masks,UV+wiggle);
    float contour=max(stable.b*stable.a,shifted.b*shifted.a);
    COLOR=texture(TEXTURE,UV+wiggle*contour);
}
