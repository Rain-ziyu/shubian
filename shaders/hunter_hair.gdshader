shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 hair_tint : source_color = vec4(1.0);
void fragment() {
	float flow=UV.x+0.018*sin(UV.y*3.14159265)*sin(UV.x*6.2831853+0.7);
	float footprint=max(length(dFdx(UV*vec2(240.0,1.0))),length(dFdy(UV*vec2(240.0,1.0))));
	float detail=1.0-smoothstep(0.16,0.65,footprint);
	float fibers=sin(flow*1507.9645);
	float locks=0.5+0.5*cos(flow*113.09734+sin(UV.y*4.0)*0.3);
	ALBEDO=COLOR.rgb*hair_tint.rgb*(0.91+0.09*locks+fibers*0.035*detail);
	ROUGHNESS=0.46+0.10*(1.0-locks)+0.03*fibers*detail;
	SPECULAR=0.38;
}
