shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform float pattern_seed=0.0;

float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 id=floor(p);
	vec2 t=fract(p);
	t=t*t*(3.0-2.0*t);
	return mix(mix(hash(id),hash(id+vec2(1,0)),t.x),mix(hash(id+vec2(0,1)),hash(id+vec2(1,1)),t.x),t.y);
}
void fragment() {
	float across=UV.x*7.0+sin(UV.y*3.14159265)*0.40+pattern_seed*0.43;
	float groove=pow(0.5-0.5*cos(across*6.2831853),14.0);
	float edge=1.0-smoothstep(0.015,0.09,min(UV.y,1.0-UV.y));
	float weather=noise(UV*vec2(27.0,9.0));
	vec2 patch_uv=UV*vec2(57.0,21.0)+vec2(pattern_seed*3.7,pattern_seed*1.9);
	float lichen=smoothstep(0.60,0.77,noise(patch_uv)+noise(patch_uv*2.37)*0.12)*smoothstep(0.42,0.64,weather);
	vec3 keratin=COLOR.rgb*mix(0.86,1.04,weather)*(1.0-0.15*groove-0.14*edge);
	ALBEDO=mix(keratin,vec3(0.24,0.30,0.13),lichen*0.24);
	// Growth bands are fine enough to read as keratin rather than metal ribs;
	// suppress them when their screen footprint becomes too small.
	float footprint=max(length(dFdx(UV*vec2(7.0,46.0))),length(dFdy(UV*vec2(7.0,46.0))));
	float detail=1.0-smoothstep(0.18,0.65,footprint);
	float bands=sin((UV.y*46.0+weather*0.24)*6.2831853);
	ALBEDO*=1.0+bands*0.015*detail;
	ROUGHNESS=clamp(0.72+weather*0.15+lichen*0.06-groove*0.035,0.0,1.0);
	SPECULAR=0.28;
}
