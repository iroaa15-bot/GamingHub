shader_type canvas_item;
render_mode unshaded;
void fragment() {
 vec4 art=texture(TEXTURE,UV);
 float edges=smoothstep(0.0,0.045,UV.x)*(1.0-smoothstep(0.955,1.0,UV.x));
 float vertical=smoothstep(0.0,0.045,UV.y)*(1.0-smoothstep(0.94,1.0,UV.y));
 COLOR=vec4(art.rgb,art.a*edges*vertical);
}
