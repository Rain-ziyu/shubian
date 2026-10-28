shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
void fragment() {
	float phase=UV.x*140.0+(UV.y-0.5)*(1.8-UV.x*3.6);
	float grain=fract(sin(dot(floor(UV*vec2(140.0,12.0)),vec2(127.1,311.7)))*43758.5453);
	float hairs=(1.0-smoothstep(0.18,0.49,abs(fract(phase)-0.5)))*mix(0.65,1.0,grain);
	float footprint=max(length(dFdx(UV*vec2(140.0,1.0))),length(dFdy(UV*vec2(140.0,1.0))));
	float detail=1.0-smoothstep(0.25,0.90,footprint);
	float edge=1.0-smoothstep(0.60,1.0,abs(UV.y*2.0-1.0));
	float ends=smoothstep(0.0,0.10,UV.x)*(1.0-smoothstep(0.80,1.0,UV.x));
	ALPHA=edge*mix(0.82,hairs,detail)*sqrt(ends);
	ALPHA_SCISSOR_THRESHOLD=0.28;
	ALBEDO=vec3(0.17,0.18,0.15)*(0.92+UV.y*0.08);
	ROUGHNESS=0.82;
	SPECULAR=0.16;
}
