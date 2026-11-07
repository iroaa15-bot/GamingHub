shader_type canvas_item;
render_mode unshaded;
void fragment() {
 vec2 p = UV - vec2(0.5);
 float radius = length(p);
 vec4 photo = texture(TEXTURE, UV);
 float rim = smoothstep(0.435, 0.455, radius);
 vec3 metal = mix(vec3(0.07, 0.36, 0.7), vec3(0.64, 1.0, 1.0), clamp(0.6 - p.y, 0.0, 1.0));
 COLOR = vec4(mix(photo.rgb, metal, rim), (1.0 - smoothstep(0.485, 0.5, radius)) * mix(photo.a, 1.0, rim));
}
