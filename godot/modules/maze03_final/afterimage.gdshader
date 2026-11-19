shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float life : hint_range(0.0,1.0) = 1.0;
uniform float phase = 0.0;
varying vec3 local_point;
void vertex(){local_point=VERTEX;}
void fragment(){
    float rim=pow(1.0-clamp(abs(dot(normalize(NORMAL),normalize(VIEW))),0.0,1.0),2.2);
    float grain=fract(sin(dot(floor(local_point*18.0),vec3(12.9898,78.233,39.425))+phase)*43758.5453);
    float dissolve=smoothstep((1.0-life)*0.88,(1.0-life)*0.88+0.10,grain);
    float fade=life*life;
    ALBEDO=mix(vec3(0.18,0.62,0.83),vec3(0.70,0.94,1.0),rim);
    EMISSION=vec3(0.28,0.75,0.95)*rim*0.75*life;
    ALPHA=(0.13+rim*0.62)*fade*dissolve;
}

