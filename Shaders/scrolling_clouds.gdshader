shader_type canvas_item;
// 縦に流れる雲。ColorRect に付けて使う(テクスチャ不要)。
// scroll をスクリプトから増やすと、雲が上から下へ流れる(画面の高さ = 1)。
// coverage を下げると雲が薄れ、sky_alpha を下げると雲の隙間から下の画面が見える。

uniform vec4 sky_color : source_color = vec4(0.17, 0.21, 0.23, 1.0);
uniform vec4 cloud_color : source_color = vec4(0.94, 0.95, 0.97, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.42, 0.46, 0.50, 1.0);
// 縦スクロール量(画面の高さ = 1)
uniform float scroll = 0.0;
// 雲の量。0 で雲なし、1 で全面が雲
uniform float coverage : hint_range(0.0, 1.0) = 0.6;
// 雲の隙間(空)の不透明度。0 なら隙間から下の画面が見える
uniform float sky_alpha : hint_range(0.0, 1.0) = 1.0;
// 全体の不透明度
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
// 雲の細かさ(大きいほど小さな雲がたくさん)
uniform float cloud_scale = 1.8;
// 画面の縦横比(幅 / 高さ)。スクリプトが設定する
uniform float aspect = 0.75;
// ドット絵に合わせて、この大きさ(px)のマスで塗る。rect_size はスクリプトが設定する
uniform float pixel_size = 2.0;
uniform vec2 rect_size = vec2(448.0, 597.0);
// 色の段階数(ドット絵らしく、階調を減らす)
uniform float color_steps = 6.0;

float hash(vec2 p) {
	// sin を使うハッシュは GPU によって精度が落ち、雲が四角く崩れるので、fract だけで作る
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int k = 0; k < 5; k++) {
		value += amplitude * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	// ドット絵のマスに揃える
	vec2 cell = floor(UV * rect_size / pixel_size) * pixel_size / rect_size;
	vec2 p = vec2(cell.x * aspect, cell.y) * cloud_scale;

	// 手前の雲(速い)と奥の雲(遅い)を重ねて、流れに奥行きを出す
	float front = fbm(p + vec2(0.0, -scroll * cloud_scale));
	float back = fbm(p * 1.7 + vec2(5.2, -scroll * cloud_scale * 0.55));
	float d = front * 0.65 + back * 0.35;

	float edge = 1.0 - coverage;
	float density = smoothstep(edge, edge + 0.22, d);
	density = floor(density * color_steps + 0.5) / color_steps;

	// 光の来る方向に少しずらして読んだ値との差で、雲の陰影をつける
	float lit = fbm(p + vec2(0.05, -0.06) + vec2(0.0, -scroll * cloud_scale));
	float shade = clamp((front - lit) * 5.0 + 0.65, 0.0, 1.0);
	shade = floor(shade * color_steps + 0.5) / color_steps;

	vec3 cloud = mix(shadow_color.rgb, cloud_color.rgb, shade);
	vec3 color = mix(sky_color.rgb, cloud, density);
	float alpha = mix(sky_alpha, 1.0, density) * opacity;
	COLOR = vec4(color, alpha);
}
