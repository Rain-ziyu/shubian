shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform int pattern_style = 0;
uniform float pattern_count = 6.0;
uniform float pattern_strength : hint_range(0.0,1.0) = 0.24;
uniform float slant = 0.5;
uniform vec4 ventral_tint : source_color = vec4(0.55,0.56,0.43,1.0);
instance uniform float ventral_weight : hint_range(0.0,1.0) = 0.0;
// Facial skin carries finer contrast so the eyes and attack direction stay legible.
instance uniform float fine_scale_weight : hint_range(0.0,1.0) = 1.0;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash(cell),hash(cell+vec2(1,0)),f.x),mix(hash(cell+vec2(0,1)),hash(cell+vec2(1,1)),f.x),f.y);
}
// Medium scutes remain readable after the submillimetre grain is filtered out.
// Return height and its analytic UV slopes; differentiating a wrapped cell
// directly would produce false normals along pixel-quad boundaries.
vec3 scute_relief(vec2 uv) {
	vec2 count = vec2(28.0,24.0);
	vec2 cells = uv*count;
	cells.x += mod(floor(cells.y),2.0)*0.5;
	vec2 id = floor(cells);
	vec2 offset = vec2(hash(id+vec2(7.3,2.1)),hash(id+vec2(31.4,6.8)));
	vec2 p = fract(cells)-0.5-(offset-0.5)*0.10;
	float size = mix(0.92,1.06,hash(id+vec2(2.3,17.9)));
	vec2 f = abs(p)*vec2(1.0,1.15)/size;
	float edge = max(max(f.x,f.y),(f.x+f.y)*0.72);
	vec2 slope = f.x>f.y ? vec2(1.0,0.0) : vec2(0.0,1.0);
	if ((f.x+f.y)*0.72>max(f.x,f.y)) slope = vec2(0.72);
	slope *= sign(p)*vec2(1.0,1.15)/size;
	float t = clamp((edge-0.24)/0.25,0.0,1.0);
	float rise = mix(0.75,1.10,hash(id+vec2(11.8,3.2)));
	float height = (1.0-smoothstep(0.24,0.49,edge))*rise;
	return vec3(height,slope*count*(-6.0*t*(1.0-t)/0.25)*rise);
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
	float detail = 1.0-smoothstep(0.15,0.45,footprint);
	scales.x += mod(floor(scales.y),2.0)*0.5;
	vec2 scale_cell = floor(scales);
	vec2 scale_center = vec2(hash(scale_cell),hash(scale_cell+vec2(19.7,7.3)));
	vec2 scale_point = fract(scales)-0.5-(scale_center-0.5)*0.16;
	float scale_size = mix(0.86,1.12,hash(scale_cell+vec2(3.1,41.7)));
	vec2 facet = abs(scale_point*vec2(1.0,1.2))/scale_size;
	float plate_edge = max(max(facet.x,facet.y),(facet.x+facet.y)*0.72);
	float plate = 1.0-smoothstep(0.32,0.48,plate_edge);
	vec2 edge_slope = facet.x>facet.y ? vec2(1.0,0.0) : vec2(0.0,1.0);
	if ((facet.x+facet.y)*0.72>max(facet.x,facet.y)) edge_slope = vec2(0.72);
	edge_slope *= sign(scale_point)*vec2(1.0,1.2)/scale_size;
	// Quiet colour variation; most fine-scale definition comes from light on
	// the raised plate instead of dark isolated spots painted onto smooth skin.
	vec2 medium_cells = UV*vec2(28.0,24.0);
	float medium_footprint = max(length(dFdx(medium_cells)),length(dFdy(medium_cells)));
	float medium_detail = 1.0-smoothstep(0.20,0.65,medium_footprint);
	vec3 scute = scute_relief(UV);
	float medium_weight = mix(0.30,1.0,fine_scale_weight);
	float grain = ((plate-0.5)*0.03*detail*fine_scale_weight+(scute.x-0.5)*0.075*medium_detail*medium_weight)*end_fade;
	// Broad countershading makes the jaw and underside readable through turns.
	float underside = 1.0-smoothstep(-0.65,0.15,wrapped.y);
	float skin_variation = mix(0.92,1.05,mottling);
	vec3 skin_color = mix(COLOR.rgb,ventral_tint.rgb*skin_variation,underside*ventral_weight);
	ALBEDO = skin_color*(1.0-pattern*pattern_strength*end_fade+grain);
	float seam_fade = smoothstep(0.0,0.02,UV.x)*(1.0-smoothstep(0.98,1.0,UV.x));
	float height_strength = 0.0006*detail*detail*end_fade*seam_fade*fine_scale_weight;
	float bevel_t = clamp((plate_edge-0.32)/0.16,0.0,1.0);
	vec2 height_slope = edge_slope*vec2(72.0,60.0)*(-6.0*bevel_t*(1.0-bevel_t)/0.16)*height_strength;
	height_slope += scute.yz*(0.003*medium_detail*medium_detail*medium_weight*end_fade*seam_fade);
	vec3 dx = dFdx(VERTEX);
	vec3 dy = dFdy(VERTEX);
	vec3 normal = normalize(NORMAL);
	vec3 across_y = cross(dy,normal);
	vec3 across_x = cross(normal,dx);
	float determinant = dot(dx,across_y);
	// Analytic scale slopes avoid differentiating wrapped cells across a pixel
	// quad, which otherwise makes the tiny bevels look like stair steps.
	vec3 gradient = sign(determinant)*(dot(height_slope,dFdx(UV))*across_y+dot(height_slope,dFdy(UV))*across_x);
	vec3 bump = gradient/max(abs(determinant),0.00000001);
	bump *= min(1.0,0.20/max(length(bump),0.00001));
	NORMAL = normalize(normal-bump);
	ROUGHNESS = clamp(0.78+(1.0-plate)*0.07*detail*fine_scale_weight+(1.0-scute.x)*0.06*medium_detail,0.0,1.0);
	SPECULAR = 0.25;
}
