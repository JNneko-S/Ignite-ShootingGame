shader_type canvas_item;
// 上から下へ降りてくる霧の帯。ColorRect に付けて使う(テクスチャ不要)。FogBand が値を入れる。
//   front … 霧の先頭(下の端)の高さ(画面の上 = 0、下 = 1)。これより上が霧
//   back  … 霧の終わり(上の端)の高さ。これより下が霧(霧を抜けると、上から晴れていく)
// scroll を増やすと、霧の模様が上から下へ流れる(霧の中を進んでいるように見える)。

uniform float front = 0.0;
uniform float back = -0.5;
uniform float scroll = 0.0;
uniform vec4 fog_color : source_color = vec4(0.84, 0.87, 0.90, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.60, 0.64, 0.68, 1.0);
// 霧の濃さ(1 で下が見えなくなる。ステージの切り替えを隠すので 1 にしておく)
uniform float density : hint_range(0.0, 1.0) = 1.0;
// 霧の端のギザギザの大きさ(画面の高さに対する割合)
uniform float edge_noise = 0.10;
uniform float cloud_scale = 2.2;
uniform float aspect = 0.75;
uniform float pixel_size = 2.0;
uniform vec2 rect_size = vec2(448.0, 597.0);
uniform float color_steps = 6.0;

float hash(vec2 p) {
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
	vec2 cell = floor(UV * rect_size / pixel_size) * pixel_size / rect_size;
	vec2 p = vec2(cell.x * aspect, cell.y) * cloud_scale;
	// 霧の模様(手前は速く、奥はゆっくり流れる)
	float a = fbm(p + vec2(0.0, -scroll * cloud_scale));
	float b = fbm(p * 1.6 + vec2(4.1, -scroll * cloud_scale * 0.6));
	float cloud = clamp(a * 0.65 + b * 0.55, 0.0, 1.0);
	cloud = floor(cloud * color_steps) / color_steps;
	// 端のギザギザ(横の位置と、流れで揺れる)
	float wobble = (fbm(vec2(cell.x * 6.0, scroll * 0.5)) - 0.5) * 2.0 * edge_noise;
	float y = cell.y + wobble;
	float below_back = smoothstep(back - 0.06, back + 0.06, y);
	float above_front = 1.0 - smoothstep(front - 0.06, front + 0.06, y);
	float mask = below_back * above_front;
	vec3 color = mix(shadow_color.rgb, fog_color.rgb, cloud);
	COLOR = vec4(color, mask * density);
}
