shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 spectral_color : source_color = vec3(0.50,0.86,0.73);
uniform float phase_offset = 0.0;
uniform float life_fade : hint_range(0.0,1.0) = 1.0;
uniform float gain_flash : hint_range(0.0,1.0) = 0.0;
varying vec3 world_point;
void vertex() {
    world_point = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}
void fragment() {
    float pulse = 0.5+0.5*sin(TIME*2.6+phase_offset);
    float flow = 0.5+0.5*sin(world_point.y*18.0-TIME*2.8+phase_offset);
    float rim = pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),2.0);
    ALBEDO = spectral_color*(0.8+0.3*flow);
    EMISSION = spectral_color*(0.45+0.4*pulse+0.2*rim+1.1*gain_flash);
    ALPHA = min(0.9,life_fade*(0.26+0.15*pulse+0.16*rim+0.06*flow)+0.28*gain_flash);
}
