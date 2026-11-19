shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 tint : source_color = vec3(0.96,0.95,0.94);
uniform float density = 0.22;
uniform float gain = 0.0;
uniform float phase = 0.0;
uniform vec2 drift = vec2(0.03,0.01);
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
float vapor(vec2 p){return noise(p)*0.58+noise(p*2.09+3.7)*0.28+noise(p*4.13-2.1)*0.14;}
void fragment(){
    vec2 p=UV*2.0-1.0;
    vec2 flow=TIME*drift+vec2(phase,phase*0.37);
    float body=vapor(UV*vec2(3.3,2.5)+flow);
    float wisps=vapor(UV*vec2(8.0,5.5)-flow*0.7);
    float feather=1.0-smoothstep(0.20,1.0,length(p+vec2((body-0.5)*0.30,0)));
    float fill=smoothstep(0.19,0.78,body*0.77+wisps*0.23);
    float depth=texture(scene_depth,SCREEN_UV).r;
    vec4 scene=INV_PROJECTION_MATRIX*vec4(SCREEN_UV*2.0-1.0,depth*2.0-1.0,1.0);
    float contact=smoothstep(0.02,1.8,VERTEX.z-scene.z/scene.w);
    // Let a wisp soften out as the lens crosses it, before its near plane can slice it.
    float near_fade=smoothstep(0.18,1.2,-VERTEX.z);
    ALBEDO=tint*mix(0.94,1.03,body);
    ALPHA=feather*fill*contact*near_fade*density*gain;
    if(ALPHA<0.002)discard;
}
