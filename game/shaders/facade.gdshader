shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(0.32,0.37,0.39,1.0);
uniform float glassiness = 0.5;
uniform float night = 0.0;
float hash(vec2 p) {return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
 vec2 grid = UV / vec2(2.8,3.5);
 vec2 cell = fract(grid);
 vec2 aa=max(fwidth(grid),vec2(0.002));
 float pane = smoothstep(0.12-aa.x,0.12+aa.x,cell.x)*(1.0-smoothstep(0.88-aa.x,0.88+aa.x,cell.x))*smoothstep(0.18-aa.y,0.18+aa.y,cell.y)*(1.0-smoothstep(0.84-aa.y,0.84+aa.y,cell.y));
 float variation = hash(floor(grid));
 vec3 glass = mix(vec3(0.12,0.21,0.25),vec3(0.24,0.36,0.42),smoothstep(0.0,1.0,cell.y));
 if(UV.x < 0.0) {pane=0.0;}
 ALBEDO = mix(base_color.rgb,glass,pane*glassiness);
 ROUGHNESS = mix(0.85,0.26,pane*glassiness);
 METALLIC = pane*glassiness*0.4;
 EMISSION = vec3(1.0,0.71,0.32)*pane*step(0.65,variation)*night*0.8;
}
