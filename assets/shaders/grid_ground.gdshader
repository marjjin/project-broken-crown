// Cheap world-space grid so movement speed and direction are easy to read.
// No textures, so it costs nothing in download size for the web build.
shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.30, 0.31, 0.28);
uniform vec3 line_color : source_color = vec3(0.20, 0.21, 0.19);
uniform float cell_size = 2.0;
uniform float line_width = 0.05;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 cell = abs(fract(world_position.xz / cell_size - 0.5) - 0.5) * cell_size;
	float line = 1.0 - step(line_width, min(cell.x, cell.y));
	ALBEDO = mix(base_color, line_color, line);
	ROUGHNESS = 0.95;
}
