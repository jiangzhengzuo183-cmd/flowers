shader_type canvas_item;
render_mode unshaded;
uniform sampler2D masks : filter_linear;
uniform sampler2D empty_art : filter_linear;
uniform vec4 empty_pill;
uniform vec4 pill_a;
uniform vec4 pill_b;
uniform vec4 pill_c;
uniform float liquid_strength : hint_range(0.0,1.0) = 0.0;
uniform float fill : hint_range(0.0,1.0) = 1.0;
void fragment(){
    vec4 source=texture(TEXTURE,UV);
    vec3 mask=texture(masks,UV).rgb;
    float region=max(mask.r,max(mask.g,mask.b));
    vec4 bounds=mask.r>0.5 ? pill_a : (mask.g>0.5 ? pill_b : pill_c);
    float index=mask.r>0.5 ? 0.0 : (mask.g>0.5 ? 1.0 : 2.0);
    vec2 local=clamp((UV-bounds.xy)/bounds.zw,vec2(0.02),vec2(0.98));
    // Reuse the supplied filled and empty interiors; preserve its brown contour.
    vec4 paper=texture(empty_art,empty_pill.xy+mix(vec2(0.24),vec2(0.76),local)*empty_pill.zw);
    float amount=clamp(fill*3.0-index,0.0,1.0);
    float edge=max(fwidth(local.x),0.001);
    float wave=sin(local.y*9.0+TIME*2.0+index*1.7)*0.008+sin(local.y*17.0-TIME*1.3)*0.003;
    float painted=amount<=0.0 ? 0.0 : (amount>=1.0 ? 1.0 : 1.0-smoothstep(amount-edge,amount+edge,local.x+wave*liquid_strength));
    vec3 interior=mix(paper.rgb,source.rgb,painted);
    // Restrained liquid highlights are confined to yellow interiors, away from the paper and bolt.
    float soft_border=smoothstep(0.0,0.12,local.y)*(1.0-smoothstep(0.88,1.0,local.y));
    float ribbon=exp(-pow((local.y-(0.24+0.025*sin(local.x*7.0+TIME*1.4+index)))/0.055,2.0));
    float sheen=(0.035*sin(local.y*3.14159)+ribbon*0.16)*soft_border;
    vec3 liquid=mix(interior,vec3(1.0,0.89,0.35),sheen*painted*liquid_strength);
    // Two tiny warm bubbles per cell rise slowly; no particles or extra light sources.
    for(int i=0;i<2;i++){
        vec2 center=vec2(0.30+float(i)*0.40,0.88-fract(TIME*0.12+float(i)*0.46+index*0.2)*0.74);
        float bubble=exp(-pow(length((local-center)*vec2(1.0,0.42))/0.013,2.0));
        liquid=mix(liquid,vec3(1.0,0.94,0.62),bubble*0.24*painted*soft_border*liquid_strength);
    }
    COLOR=vec4(mix(source.rgb,liquid,region),source.a);
}
