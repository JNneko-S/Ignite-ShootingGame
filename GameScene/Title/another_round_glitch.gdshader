shader_type canvas_item;
// 二周目の合図: 画面が横にずれて裂け、色がずれる(Another Round の演出)
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float time_seed = 0.0;

float rand(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	// 横の帯ごとに、ばらばらにずらす
	float band = floor(uv.y * 28.0);
	float r = rand(vec2(band, floor(time_seed * 18.0)));
	float shift = (r - 0.5) * 0.12 * strength * step(0.55, r);
	uv.x += shift;
	// 色ずれ(赤と青を左右に)
	float split = 0.012 * strength;
	vec4 c;
	c.r = texture(screen_tex, uv + vec2(split, 0.0)).r;
	c.g = texture(screen_tex, uv).g;
	c.b = texture(screen_tex, uv - vec2(split, 0.0)).b;
	c.a = 1.0;
	// 走査線と、ときどき白く光る筋
	float scan = 0.9 + 0.1 * sin(uv.y * 900.0);
	float flash = step(0.985, rand(vec2(band, floor(time_seed * 30.0)))) * strength;
	c.rgb = c.rgb * mix(1.0, scan, strength) + vec3(flash * 0.6);
	COLOR = c;
}
