shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform float acceleration = 0.0;
void fragment(){
    float edge=pow(max(0.0,1.0-abs(UV.x-0.5)*2.0),1.5);
    float segment=smoothstep(0.0,0.08,UV.y)*(1.0-smoothstep(0.92,1.0,UV.y));
    float travel=pow(max(0.0,sin(UV.y*9.0-TIME*(2.2+acceleration*5.0))),5.0);
    ALBEDO=vec3(0.50,0.78,0.88);
    EMISSION=vec3(0.32,0.65,0.81)*(0.15+travel*0.60+acceleration*0.20);
    ALPHA=edge*segment*(0.30+travel*0.30+acceleration*0.12);
}

