shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 iris_tint : source_color = vec4(0.42,0.31,0.23,1.0);

void fragment() {
    vec2 point = UV*2.0-1.0;
    float radius = length(point);
    float angle = atan(point.y,point.x);
    float footprint = max(length(dFdx(UV)),length(dFdy(UV)));
    float detail = 1.0-smoothstep(0.012,0.045,footprint);
    float fibers = sin(angle*64.0+radius*24.0+sin(angle*13.0)*1.4);
    float fine = sin(angle*113.0-radius*17.0);
    float collarette = exp(-pow((radius-0.48)/0.09,2.0));
    vec3 iris = iris_tint.rgb*(0.80+detail*(fibers*0.10+fine*0.035)+collarette*0.12);
    float edge = smoothstep(0.82,0.99,radius);
    iris = mix(iris,iris_tint.rgb*0.27,edge);
    float pupil = 1.0-smoothstep(0.30,0.37,radius);
    ALBEDO = mix(iris,vec3(0.008,0.006,0.005),pupil);
    ROUGHNESS = 0.36;
    SPECULAR = 0.35;
}
