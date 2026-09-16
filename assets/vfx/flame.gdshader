shader_type canvas_item;
render_mode unshaded;
uniform float clock = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float waves = sin(p.y * 15.0 + clock * 17.0) * 0.07 + sin(p.y * 27.0 - clock * 23.0) * 0.04;
	float width = 0.08 + (1.0 - UV.x) * 0.3;
	float flame = smoothstep(width, 0.0, abs(p.y + waves)) * smoothstep(1.0, 0.25, UV.x);
	vec3 tint = mix(vec3(1.0,0.12,0.015),vec3(1.0,0.91,0.43),pow(flame,2.0));
	COLOR = vec4(tint, flame * strength);
}
