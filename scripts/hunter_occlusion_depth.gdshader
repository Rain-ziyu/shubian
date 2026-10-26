shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_always, fog_disabled, shadows_disabled;
uniform bool enabled = false;
uniform float hurt_flash = 0.0;
instance uniform bool blocked_part : instance_index(0) = false;
// Invisible pass at priority 9; the color pass runs at 10. This depth range
// is reached only after ordinary transparent effects have already rendered.
// Keep the mapping synchronized with hunter_occlusion.gdshader.
void vertex() {
    vec4 view = MODELVIEW_MATRIX * vec4(VERTEX,1.0);
    vec4 clip = PROJECTION_MATRIX * view;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
    clip.z = (0.999 - clamp(-view.z / 100.0,0.0,1.0)*0.08)*clip.w;
#else
    clip.z = (0.999 - clamp(-view.z / 100.0,0.0,1.0)*0.04)*clip.w;
#endif
    POSITION = clip;
}
void fragment() {
    if ((!enabled || !blocked_part) && hurt_flash <= 0.0) { discard; }
    ALBEDO = vec3(0.0);
    ALPHA = 0.0;
}
