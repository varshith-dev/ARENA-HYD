shader_type spatial;
uniform vec4 color_a : source_color = vec4(0.28,0.29,0.24,1.0);
varying vec3 world_pos;
void vertex(){world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;}
float hash(vec2 p){return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 float n=noise(world_pos.xz*0.12);
 ALBEDO=color_a.rgb*(0.98+n*0.035);
 ROUGHNESS=0.95;
}
