shader_type canvas_item;
uniform sampler2D flow_texture : filter_linear, repeat_disable;
uniform float encoding_range = 0.08;
void fragment(){
 vec4 f=texture(flow_texture,UV);
 vec2 d=(vec2(dot(f.rg,vec2(65280.0,255.0)),dot(f.ba,vec2(65280.0,255.0)))/65535.0*2.0-1.0)*encoding_range;
 vec2 q=UV-d;
 COLOR=(q.x<0.0||q.y<0.0||q.x>1.0||q.y>1.0)?vec4(0.0):texture(TEXTURE,q);
}
