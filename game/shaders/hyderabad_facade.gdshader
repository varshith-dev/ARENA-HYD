shader_type spatial;
render_mode cull_disabled;
uniform vec4 wall_color : source_color = vec4(0.8,0.77,0.7,1.0);
uniform sampler2D wall_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool office=false;
uniform float night=0.0;
void fragment() {
    vec2 cell=fract(UV/vec2(3.1,3.2));
    vec2 aa=max(fwidth(UV/vec2(3.1,3.2)),vec2(0.001));
    vec2 lo=office?vec2(0.025,0.08):vec2(0.18,0.27);
    vec2 hi=office?vec2(0.975,0.93):vec2(0.82,0.76);
    vec2 pane=smoothstep(lo-aa,lo+aa,cell)*(1.0-smoothstep(hi-aa,hi+aa,cell));
    float window=pane.x*pane.y;
    vec3 wall=wall_color.rgb*mix(vec3(0.86),texture(wall_tex,UV/3.0).rgb,0.35);
    ALBEDO=mix(wall,vec3(0.18,0.27,0.31),window);
    METALLIC=window*0.45;
    ROUGHNESS=mix(0.91,0.25,window);
    EMISSION=vec3(0.8,0.65,0.4)*window*night*0.22;
}
