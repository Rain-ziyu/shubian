shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 iris_tint : source_color = vec4(0.72,0.45,0.16,1.0);
uniform bool integrated_pupil = false;
uniform float gaze_forward_angle = 0.0;
uniform float eye_side = 1.0;
varying vec3 eye_point;
void vertex() {
    eye_point = VERTEX * 2.0;
}
void fragment() {
    // Both eyes face the lateral X axis. The pattern stays on the eyeball
    // when the head turns; it has no screen-space or time-driven animation.
    float tangent = eye_point.z*cos(gaze_forward_angle)
        + eye_point.x*eye_side*sin(gaze_forward_angle);
    vec2 disc = vec2(eye_point.y,tangent);
    float radius = length(disc);
    float angle = atan(disc.y,disc.x);
    float fiber = sin(angle*47.0 + sin(angle*13.0)*1.8 + radius*11.0);
    float fine = sin(angle*103.0 - radius*19.0);
    float strands = 0.5 + fiber*0.32 + fine*0.18;
    float pupil_rim = exp(-pow((radius-0.31)/0.075,2.0));
    vec3 iris = iris_tint.rgb * (0.52 + strands*0.42 + pupil_rim*0.15);
    float limbus = smoothstep(0.70,0.94,radius);
    ALBEDO = mix(iris,iris_tint.rgb*0.13,limbus);
    if (integrated_pupil) {
        float slit = length(vec2(disc.x/0.60,disc.y/0.16));
        float pupil = 1.0-smoothstep(0.87,1.0,slit);
        ALBEDO = mix(ALBEDO,vec3(0.008,0.012,0.010),pupil);
    }
    ROUGHNESS = mix(0.22,0.36,limbus);
    SPECULAR = 0.60;
}
