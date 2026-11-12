shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.x += sin(TIME * 1.4 + wp.x * 0.6 + wp.z * 0.5) * 0.05 * VERTEX.y;
	VERTEX.z += cos(TIME * 1.1 + wp.x * 0.4) * 0.03 * VERTEX.y;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
	EMISSION = COLOR.rgb * 0.03;
}
