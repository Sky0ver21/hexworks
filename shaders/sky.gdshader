shader_type sky;
uniform vec3 moon_dir = vec3(0.45, 0.5, -0.74);

float hash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float noise(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1.0, 0.0, 0.0)), f.x), mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x), mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}
float fbm(vec3 p) { float a = 0.5; float s = 0.0; for (int i = 0; i < 4; i++) { s += a * noise(p); p *= 2.03; a *= 0.5; } return s; }

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = clamp(d.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 c = mix(vec3(0.07, 0.03, 0.17), vec3(0.008, 0.008, 0.035), smoothstep(0.45, 1.0, h));
	c = mix(vec3(0.17, 0.07, 0.30), c, smoothstep(0.28, 0.62, h));
	float n = fbm(d * 3.0);
	c += vec3(0.35, 0.08, 0.45) * pow(n, 3.0) * 0.9 * smoothstep(0.45, 0.9, h);
	c += vec3(0.0, 0.25, 0.3) * pow(fbm(d * 5.0 + 7.0), 4.0) * 0.8;
	float st = hash(floor(d * 240.0));
	float tw = 0.6 + 0.4 * sin(TIME * 2.0 + st * 90.0);
	c += vec3(1.0, 0.95, 0.9) * step(0.9975, st) * tw * smoothstep(0.5, 0.6, h) * 2.2;
	float m = dot(d, normalize(moon_dir));
	c += vec3(0.9, 0.95, 1.0) * smoothstep(0.9962, 0.9972, m) * 3.0;
	c += vec3(0.45, 0.5, 0.9) * pow(max(m, 0.0), 60.0) * 0.5;
	COLOR = c;
}
