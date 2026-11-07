shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform sampler2D leaves : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D mask : filter_linear_mipmap_anisotropic, repeat_disable;
void fragment() {
    vec2 uv = vec2(UV.x * 0.435, UV.y);
    ALBEDO = texture(leaves, uv).rgb * vec3(0.9,1.0,0.88);
    ALPHA = texture(mask, uv).r;
    ALPHA_SCISSOR_THRESHOLD = 0.45;
    ROUGHNESS = 0.92;
    BACKLIGHT = ALBEDO * 0.25;
}
