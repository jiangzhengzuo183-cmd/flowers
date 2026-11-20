shader_type canvas_item;
void vertex() {
	float frame=mod(floor(TIME*7.0),3.0);
	VERTEX.y+=(frame<0.5?-0.36:(frame<1.5?0.33:0.05));
}
