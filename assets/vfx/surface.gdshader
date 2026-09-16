shader_type canvas_item;
render_mode unshaded;
uniform float clock = 0.0;
uniform float corrosion = 0.0;
uniform float resonance = 0.0;
void fragment() {
	vec2 p = UV;
	float wave = sin(length(p-vec2(0.5))*65.0-clock*9.0);
	float veins = pow(abs(sin(p.x*29.0+sin(p.y*17.0+clock)*2.0)),18.0);
	float edge = smoothstep(0.25,0.49,max(abs(p.x-.5),abs(p.y-.5)));
	vec3 tint = mix(vec3(.22,1.0,.42),vec3(.4,.8,1.0),step(corrosion,resonance));
	float alpha = (veins*corrosion*.38 + max(0.0,wave)*resonance*.25)*edge;
	COLOR = vec4(tint,alpha);
}
