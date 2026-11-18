shader_type canvas_item;
render_mode unshaded;
#include "res://modules/game_hud/sticker_finish.gdshaderinc"
varying vec4 item_tint;
void vertex(){item_tint=COLOR;}
void fragment(){COLOR=hud_sticker_finish(TEXTURE,UV,texture(TEXTURE,UV),fwidth(UV))*item_tint;}
