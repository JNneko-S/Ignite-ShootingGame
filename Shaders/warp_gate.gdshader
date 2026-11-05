shader_type canvas_item;
// ワープゲート。正方形の ColorRect に付けて使う(テクスチャ不要)。
// open を 0 → 1 にするとゲートが開き、1 → 0 で閉じる。

// 開き具合(0 で閉じている、1 で全開)
uniform float open : hint_range(0.0, 1.0) = 0.0;
// 縦横の比。0.55 なら、上から見た横長の楕円になる
uniform float squash = 0.55;
uniform vec4 ring_color : source_color = vec4(0.55, 0.9, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(0.35, 0.2, 0.9, 1.0);
uniform vec4 deep_color : source_color = vec4(0.03, 0.02, 0.12, 1.0);
// 渦の回る速さ
uniform float spin = 5.0;
// ドット絵に合わせて、この大きさ(px)のマスで塗る。rect_size はスクリプトが設定する
uniform float pixel_size = 2.0;
uniform vec2 rect_size = vec2(256.0, 256.0);

void fragment() {
	vec2 cell = (floor(UV * rect_size / pixel_size) + 0.5) * pixel_size / rect_size;
	vec2 uv = cell * 2.0 - 1.0;
	uv.y /= squash;
	float r = length(uv);
	float a = atan(uv.y, uv.x);
	float radius = open * 0.9;

	// 縁の光る輪(少し揺らぐ)
	float wobble = sin(a * 7.0 + TIME * 3.0) * 0.015;
	float ring = smoothstep(0.07, 0.0, abs(r - radius - wobble));
	float glow = smoothstep(0.35, 0.0, abs(r - radius)) * 0.35;

	// 内側の渦: 中心ほど暗く深い
	float t = clamp(r / max(radius, 0.001), 0.0, 1.0);
	float swirl = sin(a * 5.0 - t * 10.0 + TIME * spin) * 0.5 + 0.5;
	vec3 inner = mix(deep_color.rgb, core_color.rgb, t * (0.55 + 0.45 * swirl));
	float inside = step(r, radius);

	vec3 color = inner * inside + ring_color.rgb * (ring + glow);
	float alpha = clamp(inside * 0.95 + ring + glow, 0.0, 1.0) * step(0.001, open);
	COLOR = vec4(color, alpha);
}
