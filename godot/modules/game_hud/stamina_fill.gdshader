shader_type canvas_item;
render_mode unshaded;
uniform float fill : hint_range(0.0,1.0) = 1.0;
varying vec4 item_tint;
void vertex(){item_tint=COLOR;}
float gold(vec3 c){return smoothstep(0.14,0.30,c.r-c.b)*smoothstep(0.06,0.18,c.g-c.b);}
void fragment(){
    vec4 source=texture(TEXTURE,UV);
    float yellow=gold(source.rgb);
    vec2 px=fwidth(UV)*3.0;
    float edge=max(max(gold(texture(TEXTURE,UV+vec2(px.x,0)).rgb),gold(texture(TEXTURE,UV-vec2(px.x,0)).rgb)),max(gold(texture(TEXTURE,UV+vec2(0,px.y)).rgb),gold(texture(TEXTURE,UV-vec2(0,px.y)).rgb)));
    edge=max(edge,max(max(gold(texture(TEXTURE,UV+px*0.7071).rgb),gold(texture(TEXTURE,UV-px*0.7071).rgb)),max(gold(texture(TEXTURE,UV+vec2(px.x,-px.y)*0.7071).rgb),gold(texture(TEXTURE,UV+vec2(-px.x,px.y)*0.7071).rgb))));
    float filled=1.0-smoothstep(fill-0.002,fill+0.002,UV.x);
    if(fill>=0.9999)filled=1.0;
    if(fill<=0.0001)filled=0.0;
    float alpha=source.a*mix(edge,filled,yellow);
    COLOR=vec4(source.rgb,alpha)*item_tint;
}
