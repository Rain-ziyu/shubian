shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform int pattern_style = 0;
uniform float pattern_count = 6.0;
uniform float pattern_strength : hint_range(0.0,1.0) = 0.24;
uniform float slant = 0.5;
// Facial skin carries finer contrast so the eyes and attack direction stay legible.
instance uniform float fine_scale_weight : hint_range(0.0,1.0) = 1.0;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash(cell),hash(cell+vec2(1,0)),f.x),mix(hash(cell+vec2(0,1)),hash(cell+vec2(1,1)),f.x),f.y);
}
void fragment() {
	vec2 wrapped = vec2(sin(UV.x*6.2831853),cos(UV.x*6.2831853));
	float mottling = noise(wrapped*2.3+UV.y*pattern_count);
	float pattern = smoothstep(0.35,0.75,mottling);
	if (pattern_style==1) {
		float stripe = sin(UV.y*pattern_count*6.2831853+wrapped.x*slant*3.0+(mottling-0.5)*3.0);
		// Broken dorsal markings leave the belly clear instead of encircling it
		// like stacked tubes. Fade toward the underside without a hard boundary.
		float dorsal = smoothstep(-0.55,0.25,wrapped.y);
		float broken = smoothstep(0.25,0.60,noise(wrapped*5.0+UV.y*pattern_count*1.7));
		pattern = smoothstep(0.12,0.7,stripe)*dorsal*mix(0.3,1.0,broken);
	} else if (pattern_style==2) {
		vec2 spots = vec2(UV.x*16.0,UV.y*pattern_count);
		spots.x += mod(floor(spots.y),2.0)*0.5;
		pattern = 1.0-smoothstep(0.16,0.34,length(fract(spots)-0.5));
	}
	float end_fade = smoothstep(0.02,0.10,UV.y)*(1.0-smoothstep(0.90,0.98,UV.y));
	vec2 scales = UV*vec2(72.0,60.0);
	float footprint = max(length(dFdx(scales)),length(dFdy(scales)));
	float detail = 1.0-smoothstep(0.3,0.9,footprint);
	scales.x += mod(floor(scales.y),2.0)*0.5;
	vec2 scale_cell = floor(scales);
	vec2 scale_center = vec2(hash(scale_cell),hash(scale_cell+vec2(19.7,7.3)));
	vec2 scale_point = fract(scales)-0.5-(scale_center-0.5)*0.16;
	float scale_size = mix(0.86,1.12,hash(scale_cell+vec2(3.1,41.7)));
	float plate = 1.0-smoothstep(0.26,0.49,length(scale_point*vec2(1.0,1.2))/scale_size);
	// Small irregular scales support the broad markings instead of reading as dots.
	float grain = (plate-0.5)*0.07*detail*end_fade*fine_scale_weight;
	ALBEDO = COLOR.rgb*(1.0-pattern*pattern_strength*end_fade+grain);
	ROUGHNESS = clamp(0.82+(1.0-plate)*0.10*detail*fine_scale_weight,0.0,1.0);
	SPECULAR = 0.25;
}
