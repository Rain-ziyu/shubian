shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, fog_disabled;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform bool enabled = false;
instance uniform bool blocked_part = false;
uniform vec4 cue_color : source_color = vec4(0.66,0.95,0.86,0.42);
void fragment() {
	if (!enabled || !blocked_part) { discard; }
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
	if (VERTEX.z >= surface_z - 0.08) { discard; }
	ALBEDO = cue_color.rgb;
	ALPHA = cue_color.a;
}


