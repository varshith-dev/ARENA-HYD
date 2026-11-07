shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color = vec4(0.58,0.57,0.53,1.0);
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float seam=1.0-smoothstep(0.0,0.025,abs(fract(world.y/1.25)-0.5));
 ALBEDO=tint.rgb*(1.0-seam*0.08);
 ROUGHNESS=0.92;
}
