shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// mode 0 = flowing ley line, 1 = portal swirl, 2 = bubbling liquid, 3 = rune ring / danger ring
uniform vec4 col : source_color = vec4(1.0);
uniform int mode = 0;
uniform float power = 1.0;
uniform float fill = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float a = atan(p.y, p.x);
	float v = 1.0;
	float al = 0.0;
	if (mode == 0) {
		float e = 1.0 - abs(UV.x - 0.5) * 2.0;
		float pu = 0.5 + 0.5 * sin(UV.y * 5.0 - TIME * 5.0);
		v = 0.5 + 1.6 * pu;
		al = pow(max(e, 0.0), 1.5) * (0.3 + 0.7 * pu);
	} else if (mode == 1) {
		float s = sin(a * 3.0 + r * 9.0 - TIME * 3.0) * 0.5 + 0.5;
		v = 0.6 + 2.0 * s * (1.0 - r) + 1.6 * pow(max(1.0 - r, 0.0), 3.0);
		al = (1.0 - smoothstep(0.8, 1.0, r)) * (0.5 + 0.5 * s);
	} else if (mode == 2) {
		float n = noise(p * 9.0 + vec2(TIME * 0.5, TIME * 0.3));
		float n2 = noise(p * 17.0 - vec2(TIME * 0.7, 0.0));
		v = 0.7 + 1.5 * smoothstep(0.55, 0.9, n * 0.6 + n2 * 0.5);
		al = 1.0 - smoothstep(0.9, 1.0, r);
	} else {
		float ring = smoothstep(0.06, 0.0, abs(r - 0.9));
		float ring2 = smoothstep(0.04, 0.0, abs(r - 0.6));
		float sp = smoothstep(0.75, 1.0, sin(a * 8.0 + TIME * 1.5) * 0.5 + 0.5) * step(r, 0.9) * step(0.6, r);
		float f = step(r, fill * 0.9) * 0.45;
		v = 1.6;
		al = ring + ring2 + sp * 0.7 + f;
	}
	ALBEDO = col.rgb * v * power;
	ALPHA = clamp(al, 0.0, 1.0) * col.a;
}
