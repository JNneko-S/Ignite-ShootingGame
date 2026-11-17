shader_type canvas_item;
// 空中戦(ステージ3)の雲。上から見下ろした、もこもこの積雲。ColorRect に付けて使う(テクスチャ不要)。
// scrolling_clouds.gdshader と同じ uniform で動かせる(SkyBackground が使う)。
//   形: 雲のある場所(大きな塊。fbm)に、大小の丸い球(こぶ)をたくさん並べる。塊の中ほどほど球が大きく、ふちほど小さい
//       → 輪郭が丸いこぶの連なりになる(カリフラワーのような積雲)
//   光: 球の面の向きで、夕日の来る側(light_dir)を明るく、反対側を暗くする。球と球のあいだが、自然に陰になる
//       日の当たる側のふちは、夕日の色(rim_color)に光らせる
//   ドット絵: pixel_size のマスに揃え、明るさを color_steps 段に減らす

uniform vec4 sky_color : source_color = vec4(0.17, 0.21, 0.23, 1.0);
// 日の当たる面の色
uniform vec4 cloud_color : source_color = vec4(1.0, 0.95, 0.9, 1.0);
// 陰の色(夕日がかった色)
uniform vec4 shadow_color : source_color = vec4(0.96, 0.7, 0.6, 1.0);
// 雲のふちの、夕日に照らされた色
uniform vec4 rim_color : source_color = vec4(1.0, 0.8, 0.52, 1.0);
// いちばん暗い陰の色(夕暮れの紫)
uniform vec4 deep_color : source_color = vec4(0.74, 0.52, 0.6, 1.0);
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
// ドット絵のマスの大きさ(px)。rect_size はスクリプトが設定する
uniform float pixel_size = 2.0;
uniform vec2 rect_size = vec2(448.0, 597.0);
// 横の流れ(画面の幅 = 1)
uniform float drift = 0.0;
// 雲を画面の左右に寄せる強さ(0 で寄せない)と、寄せる幅(画面の幅に対する割合)
uniform float side_bias = 0.0;
uniform float side_width = 0.3;
// 明るさの段階数(ドット絵らしく、階調を減らす)
uniform float color_steps = 4.0;
// こぶ(球)の細かさ。大きいほど小さな球がたくさん
uniform float puff_density = 3.4;
// 夕日の来る向き(画面の向き。上が -y)
uniform vec2 light_dir = vec2(-0.6, -0.8);

float hash(vec2 p) {
	// sin を使うハッシュは GPU によって精度が落ちるので、fract だけで作る
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash2(vec2 p) {
	return vec2(hash(p), hash(p + vec2(19.19, 7.31)));
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm3(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.03 + vec2(1.7, 9.2)) * 0.3 + noise(p * 4.1 + vec2(5.3, 2.1)) * 0.15;
}

// 雲の塊の「中ほどらしさ」(0 = 雲の外、1 = 塊の芯)。p は雲の座標
float fullness(vec2 p, float edge, float bias) {
	float m = (fbm3(p * 1.1) - 0.47) * 2.4 + 0.5 + bias;
	return clamp((m - edge) / 0.32, 0.0, 1.0);
}

// なめらかな max(k が大きいほど、なだらかにつながる)
float smax(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(a, b, h) + k * h * (1.0 - h);
}

// 1段ぶんの、ふくらみ(球)を並べて、雲の高さに溶け合わせる。
// 光の向きを測るために、少しずらした3点(p、右、下)の高さを、いっしょに求める(マスを調べるのが1回ですむ)。
// 球は「なめらかな max」でつなぐので、ひとつひとつの丸が目立たず、ひと続きのうねりになる
void puff_layer(vec2 p, float e, float freq, float size, float lift, float edge, float bias, inout vec3 height) {
	vec2 i = floor(p * freq);
	float k = 0.6 / freq;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 cell = i + vec2(float(x), float(y));
			vec2 center = (cell + 0.15 + hash2(cell) * 0.7) / freq;
			float full = fullness(center, edge, bias);
			if (full <= 0.15) { // ふちに、ぽつんと離れた小さな丸を出さない
				continue;
			}
			// 塊の芯ほど大きく高いふくらみ(となりのマスまでで収まる大きさ)
			float r = min((0.55 + hash(cell + 3.7) * 0.35) * (0.35 + full * 0.8) * size, 1.0) / freq;
			float base = full * lift / freq;
			vec2 d0 = p - center;
			vec2 d1 = d0 + vec2(e, 0.0);
			vec2 d2 = d0 + vec2(0.0, e);
			// 球より平たい、なだらかなふくらみ(ふちは 0)
			vec3 q = vec3(dot(d0, d0), dot(d1, d1), dot(d2, d2)) / (r * r);
			// ふくらみの内側は正、外側は負になる、切れ目のない高さ(外側で 0 にすると、何もないところが持ち上がる)
			vec3 f = vec3(1.0) - q;
			vec3 h = sqrt(max(f, vec3(0.0))) * r * 0.7 + base * f + min(f, vec3(0.0)) * r * 0.5;
			height = vec3(smax(height.x, h.x, k), smax(height.y, h.y, k), smax(height.z, h.z, k));
		}
	}
}

void fragment() {
	// ドット絵のマスに揃える
	vec2 cell = floor(UV * rect_size / pixel_size) * pixel_size / rect_size;
	vec2 p = vec2((cell.x + drift) * aspect, cell.y) * cloud_scale + vec2(0.0, -scroll * cloud_scale);
	// 形をゆがめて、ふくらみの輪郭が真円にならないように
	p += (vec2(noise(p * 1.7 + 3.1), noise(p * 1.7 + 8.3)) - 0.5) * 0.3;

	float side = 1.0 - smoothstep(0.0, side_width, min(cell.x, 1.0 - cell.x));
	float bias = side_bias * (side - 0.5);
	float edge = mix(1.1, 0.35, coverage);

	// 大きなふくらみに、中くらいのふくらみを溶け合わせる(小さな丸を並べない: 集合体に見えないように)
	float e = 0.6 / (puff_density * 10.0);
	vec3 height = vec3(-1.0);
	puff_layer(p, e, puff_density, 1.15, 0.5, edge, bias, height);
	puff_layer(p + vec2(0.37, 0.61), e, puff_density * 1.9, 1.0, 0.35, edge, bias, height);
	float limit = 0.0;

	if (height.x <= limit) {
		COLOR = vec4(sky_color.rgb, sky_alpha * opacity);
	} else {
		// 高さの傾きから面の向きを出して、夕日の側を明るく、反対側を暗くする
		vec3 normal = normalize(vec3(height.x - height.y, height.x - height.z, e * 1.4));
		vec3 sun = normalize(vec3(light_dir, 0.8));
		float lambert = clamp(dot(normal, sun), 0.0, 1.0);
		float shade = clamp(lambert * 0.75 + normal.z * 0.3, 0.0, 1.0);
		shade = floor(shade * color_steps + 0.5) / color_steps;

		vec3 col = mix(deep_color.rgb, shadow_color.rgb, smoothstep(0.15, 0.5, shade));
		col = mix(col, cloud_color.rgb, smoothstep(0.5, 0.9, shade));
		// 雲のふち(低いところ)で、日の当たる側を、夕日の色に光らせる
		float low = 1.0 - smoothstep(0.0, 0.05 / puff_density, height.x);
		float rim = low * smoothstep(0.45, 0.8, lambert);
		rim = floor(rim * 2.0 + 0.5) / 2.0;
		col = mix(col, rim_color.rgb, rim * 0.6);
		COLOR = vec4(col, opacity);
	}
}
