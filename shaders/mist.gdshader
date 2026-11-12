shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 c1 : source_color = vec3(0.22, 0.10, 0.45);
uniform vec3 c2 : source_color = vec3(0.08, 0.42, 0.52);
uniform float seed = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) { float a = 0.5; float s = 0.0; for (int i = 0; i < 5; i++) { s += a * noise(p); p *= 2.03; a *= 0.5; } return s; }

void fragment() {
	vec2 p = UV * 16.0 + seed;
	float n = fbm(p + vec2(TIME * 0.035, TIME * 0.012));
	float n2 = fbm(p * 2.3 - vec2(TIME * 0.02, 0.0));
	float d = length(UV - 0.5) * 2.0;
	ALBEDO = mix(c1, c2, n2) * (0.3 + n * 1.1);
	ALPHA = smoothstep(0.28, 0.72, n) * (1.0 - smoothstep(0.5, 1.0, d)) * 0.9;
}
