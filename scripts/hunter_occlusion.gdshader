shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, fog_disabled;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform bool enabled = false;
uniform float hurt_flash = 0.0;
instance uniform bool blocked_part : instance_index(0) = false;
instance uniform bool weapon_part : instance_index(1) = false;
uniform vec4 cue_color : source_color = vec4(0.66,0.95,0.86,0.42);
// Match hunter_occlusion_depth.gdshader. Reserve a near-camera depth range
// for the cue only, preserving nearest hunter surfaces across all mesh parts.
// Godot 4.3+ uses reversed Z (near=1); a tiny bias admits the color pass.
void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX,1.0);
	vec4 clip = PROJECTION_MATRIX * view;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	clip.z = (0.999002 - clamp(-view.z / 100.0,0.0,1.0)*0.08)*clip.w;
#else
	clip.z = (0.999002 - clamp(-view.z / 100.0,0.0,1.0)*0.04)*clip.w;
#endif
	POSITION = clip;
}
void fragment() {
	if ((!enabled || !blocked_part) && hurt_flash <= 0.0) { discard; }
	// Keep a faint interior, but emphasize the silhouette rather than stacking
	// opaque-looking fills from skin, underlayers and equipment.
	float facing = clamp(abs(dot(normalize(NORMAL),normalize(VIEW))),0.0,1.0);
	float edge = pow(1.0-facing,2.5);
	float depth = texture(scene_depth, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
	vec4 scene_view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float surface_z = scene_view.z / scene_view.w;
	// View-space Z is negative. CPU gating first requires a foreign obstruction.
	// NDC reconstruction: docs.godotengine.org/en/stable/tutorials/shaders/advanced_postprocessing.html
	if (VERTEX.z >= surface_z - 0.08) {
		if (hurt_flash <= 0.0) { discard; }
		ALBEDO = vec3(1.0, 0.34, 0.22);
		ALPHA = hurt_flash * mix(0.18,0.40,edge);
	} else {
		if (!enabled || !blocked_part) { discard; }
		vec3 blocked_color = weapon_part ? vec3(0.98,0.85,0.52) : cue_color.rgb;
		ALBEDO = mix(blocked_color, vec3(1.0, 0.34, 0.22), hurt_flash);
		ALPHA = weapon_part ? 0.68 : mix(0.28,cue_color.a,edge);
	}
}


