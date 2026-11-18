// Keep original pigment and white contour; soften only the exposed white edge.
vec4 hud_sticker_finish(sampler2D art, vec2 uv, vec4 source, vec2 pixel) {
    float left=texture(art,uv-vec2(pixel.x*1.25,0.0)).a;
    float right=texture(art,uv+vec2(pixel.x*1.25,0.0)).a;
    float top=texture(art,uv-vec2(0.0,pixel.y*1.25)).a;
    float bottom=texture(art,uv+vec2(0.0,pixel.y*1.25)).a;
    float edge=1.0-min(min(left,right),min(top,bottom));
    float white=smoothstep(0.93,0.985,min(source.r,min(source.g,source.b)));
    float alpha=source.a*(1.0-white*edge*0.12);
    float shadow=texture(art,uv-vec2(0.0,pixel.y*1.8)).a;
    shadow+=texture(art,uv-vec2(pixel.x*0.7,pixel.y*1.5)).a;
    shadow+=texture(art,uv-vec2(-pixel.x*0.7,pixel.y*1.5)).a;
    shadow=shadow/3.0*0.055*(1.0-texture(art,uv).a);
    float behind=shadow*(1.0-alpha);
    float result_alpha=alpha+behind;
    vec3 rgb=(source.rgb*alpha+vec3(0.24,0.21,0.17)*behind)/max(result_alpha,0.00001);
    return vec4(rgb,result_alpha);
}
