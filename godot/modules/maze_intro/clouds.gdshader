shader_type canvas_item;
render_mode unshaded;
uniform float cover : hint_range(0.0,1.0) = 0.0;
uniform float opening : hint_range(0.0,1.0) = 0.0;
uniform float age = 0.0;
uniform float aspect = 1.777778;
float hash(vec2 p) {
    vec3 q=fract(vec3(p.xyx)*0.1031);
    q+=dot(q,q.yzx+33.33);
    return fract((q.x+q.y)*q.z);
}
float noise(vec2 p) {
    vec2 i=floor(p), f=fract(p);
    f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
float fbm(vec2 p) {
    float sum=0.0, weight=0.57;
    for(int i=0;i<4;i++) {sum+=noise(p)*weight;p=p*2.07+vec2(4.1,7.3);weight*=0.48;}
    return sum;
}
void fragment() {
    vec2 p=vec2(UV.x*aspect,UV.y);
    float slow=age*0.055;
    float billow=fbm(p*4.2+vec2(slow,-slow*0.4));
    float veil=fbm(p*7.0+vec2(-slow*0.6,slow*0.8)+vec2(8,3));
    // Four soft, differently paced fronts enter from the edges.
    float front=min(min(UV.x*1.06+billow*0.12,(1.0-UV.x)*0.94+veil*0.13),min(UV.y*0.88+veil*0.11,(1.0-UV.y)*1.12+billow*0.13));
    float dense=smoothstep(front-0.13,front+0.13,cover*0.88-0.11);
    float wisps=smoothstep(front-0.22,front+0.16,cover*0.84-0.16)*0.55;
    float a=(1.0-(1.0-dense)*(1.0-wisps))*smoothstep(0.0,0.18,cover);
    // Clearing opens an uneven window through the centre, then retreats out of frame.
    vec2 centre=(UV-0.5)*vec2(1.45,1.0);
    float radius=length(centre)+(billow-0.5)*0.18;
    float clear=1.0-smoothstep(opening*1.18-0.11,opening*1.18+0.12,radius);
    a*=1.0-clear*smoothstep(0.0,0.12,opening);
    a*=1.0-smoothstep(0.88,1.0,opening);
    vec3 milk=mix(vec3(0.935,0.936,0.921),vec3(1.0,0.997,0.979),smoothstep(0.1,0.88,billow*0.65+veil*0.35));
    COLOR=vec4(milk,clamp(a,0.0,1.0));
}
