shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled,fog_disabled;
uniform float strength=0.0;
uniform float travel=0.0;
void fragment(){
 float u=UV.x/0.90;
 float centre=0.5+0.05*pow(1.0-clamp(u,0.0,1.0),2.0);
 float across=UV.y-centre;
 float run=smoothstep(0.0,0.35,u)*(1.0-smoothstep(0.975,1.02,u));
 float width=mix(0.060,0.023,clamp(u,0.0,1.0));
 float core=exp(-pow(across/width,2.0))*run;
 float halo=exp(-pow(across/(width*4.4),2.0))*run;
 float head=exp(-dot((UV-vec2(0.90,0.5))*vec2(64.0,7.0),(UV-vec2(0.90,0.5))*vec2(115.0,13.0)));
 float gleam=exp(-dot((UV-vec2(0.90,0.5))*vec2(135.0,20.0),(UV-vec2(0.90,0.5))*vec2(160.0,32.0)));
 float wisp_y=centre+0.115*pow(1.0-clamp(u,0.0,1.0),0.65);
 float wisp=exp(-pow((UV.y-wisp_y)/0.013,2.0))*run*(1.0-smoothstep(0.70,0.95,u));
 vec3 tint=mix(vec3(0.62,0.83,0.94),vec3(0.48,0.89,1.0),clamp(u,0.0,1.0));
 tint=mix(tint,vec3(0.96,1.0,1.0),clamp(core*0.78+head,0.0,1.0));
 ALBEDO=tint;
 EMISSION=tint*(0.65*core+2.1*gleam);
 ALPHA=clamp(core*0.97+halo*0.24+head*0.98+wisp*0.38,0.0,0.99)*strength;
}
