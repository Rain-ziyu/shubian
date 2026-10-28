shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(0.3,0.36,0.27,1.0);
uniform float wetness : hint_range(0.0,1.0) = 0.2;
uniform float pattern_seed = 0.0;
uniform sampler2D canvas_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float canvas_weight : hint_range(0.0,1.0) = 0.0;
float hash21(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float fabric_noise(vec2 p) {
    vec2 cell=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash21(cell),hash21(cell+vec2(1.0,0.0)),f.x),mix(hash21(cell+vec2(0.0,1.0)),hash21(cell+vec2(1.0)),f.x),f.y);
}
void fragment() {
    vec2 yarn = UV*vec2(360.0,480.0);
    float detail = 1.0-smoothstep(0.25,0.85,max(fwidth(yarn.x),fwidth(yarn.y)));
    float weave = sin(yarn.x*6.283185)*sin(yarn.y*6.283185)*detail;
    float damp = fabric_noise(UV*6.0+vec2(pattern_seed));
    float edge = min(min(UV.x,1.0-UV.x),min(UV.y,1.0-UV.y));
    float seam = 1.0-smoothstep(0.005,0.018,edge);
    float stitch = (1.0-smoothstep(0.018,0.028,edge))*step(0.45,fract((UV.x+UV.y)*70.0));
    float shade = (0.97+0.06*(damp-0.5)+0.035*weave)*(1.0-wetness*0.08)*(1.0-seam*0.18)+stitch*0.045;
    float weathering = 1.0;
    if (canvas_weight>0.0) {
        // Mirrored boundaries are continuous even when the generated source
        // is not pixel-perfect tileable. Keep the authored garment hue.
        vec2 material_uv = UV*vec2(3.75,2.55)+vec2(pattern_seed*0.13,pattern_seed*0.07);
        material_uv = 1.0-abs(fract(material_uv*0.5)*2.0-1.0);
        // Keep the photographed weave physically fine; the mipmapped
        // anisotropic sampler handles distance instead of a fixed blur level.
        float canvas = dot(texture(canvas_map,material_uv).rgb,vec3(0.2126,0.7152,0.0722));
        float canvas_mid = OUTPUT_IS_SRGB ? 0.33 : 0.0984;
        weathering = mix(1.0,clamp(canvas/canvas_mid,0.85,1.15),canvas_weight);
    }
    ALBEDO = base_color.rgb*shade*weathering;
    // Millimetre-scale relief in view space; derivatives also work on meshes
    // without tangents. Filtered yarn fades before it can shimmer at distance.
    float fold = sin(UV.x*25.13274+fabric_noise(UV*3.0+vec2(pattern_seed))*1.8);
    float relief = weave*0.00005+fold*0.0007+damp*0.00035;
    vec3 dx = dFdx(VERTEX);
    vec3 dy = dFdy(VERTEX);
    vec3 normal = normalize(NORMAL);
    vec3 across_y = cross(dy,normal);
    vec3 across_x = cross(normal,dx);
    float determinant = dot(dx,across_y);
    vec3 gradient = sign(determinant)*(dFdx(relief)*across_y+dFdy(relief)*across_x);
    vec3 bump = gradient/max(abs(determinant),0.00000001);
    bump *= min(1.0,0.12/max(length(bump),0.00001));
    NORMAL = normalize(normal-bump);
    ROUGHNESS = clamp(0.92-wetness*0.16+weave*0.025+(weathering-1.0)*0.08,0.74,0.97);
    SPECULAR = 0.22;
}
