shader_type canvas_item;
// 空中戦(ステージ3)の雲。上から見下ろした、もこもこの積雲。ColorRect に付けて使う(テクスチャ不要)。
// scrolling_clouds.gdshader と同じ uniform で動かせる(SkyBackground が使う)。
// 見た目の手本は、夕暮れのドット絵の積雲: 小さな丸いこぶがたくさん重なり、こぶ1つずつが平らな色で塗られている。
//   形: 雲のある場所(大きな塊。fbm)に、大・中・小の丸いこぶを重ねて並べる。
//       塊の芯ほど大きなこぶ、ふちほど小さなこぶ → 輪郭が、こぶの連なりでギザギザ(スカラップ)になる
//   重なり: 1つの点に重なるこぶのうち、いちばん「上」(塊の芯に近い・手前)のこぶの色を使う。
//           こぶどうしの境目がくっきり出て、丸の重なりが見える(なめらかに溶かさない: 卵のように見えないように)
//   色: こぶの色は、こぶ1つで1色。塊のどちら側にあるか(塊の外向きの向き)が光の来る向きなら桃色、
//       反対なら藤色、塊のふちの陰は暗い紫。こぶごとに少し色をばらして、まだらにする。
//       こぶのふちの、光と反対側だけ1段暗くして、こぶの輪郭を出す
//   ドット絵: pixel_size のマスに揃え、色は5段(深い陰・陰・中間・日なた・いちばん明るい)だけ

uniform vec4 sky_color : source_color = vec4(0.4, 0.47, 0.66, 1.0);
// いちばん明るい日なた(夕日の桃色)
uniform vec4 highlight_color : source_color = vec4(0.99, 0.76, 0.6, 1.0);
// 日なたの色
uniform vec4 cloud_color : source_color = vec4(0.96, 0.66, 0.52, 1.0);
// 日なたと陰のあいだ(サーモン)
uniform vec4 mid_color : source_color = vec4(0.85, 0.55, 0.5, 1.0);
// 陰の色(藤色)
uniform vec4 shadow_color : source_color = vec4(0.69, 0.5, 0.53, 1.0);
// いちばん暗い陰(塊のふちの、光と反対側)
uniform vec4 deep_color : source_color = vec4(0.48, 0.29, 0.36, 1.0);
// 縦スクロール量(画面の高さ = 1)
uniform float scroll = 0.0;
// 雲の量。0 で雲なし、1 で全面が雲
uniform float coverage : hint_range(0.0, 1.0) = 0.6;
// 雲の隙間(空)の不透明度。0 なら隙間から下の画面が見える
uniform float sky_alpha : hint_range(0.0, 1.0) = 1.0;
// 全体の不透明度
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
// 雲の塊の細かさ(大きいほど小さな塊がたくさん)
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
// こぶの細かさ。大きいほど小さなこぶがたくさん(塊の大きさに対して)
uniform float puff_density = 9.0;
// 夕日の来る向き(画面の向き。上が -y)。手本と同じく、右上から
uniform vec2 light_dir = vec2(0.75, -0.55);
// 日なた・陰を決めるときに見る距離(雲の座標)。大きいほど、塊ごとの大きな明暗になる
uniform float light_reach = 0.3;
// 1 なら、雲の塊の濃さを白黒で出す(調整用)
uniform float debug_view = 0.0;
// 描く場所(画面の px)→ 雲の置き場(回転・傾けた背景の中の座標)の変換。SkyBackground が毎フレーム入れる。
// 四角形は回さずに描画範囲いっぱいに置き、回転・傾き・寄りはここで座標だけ変える
// (四角形ごと回すと、ずれたところで描画範囲の端が見えて、雲が切れてしまう)
uniform vec2 inv_x = vec2(1.0, 0.0);
uniform vec2 inv_y = vec2(0.0, 1.0);
uniform vec2 inv_o = vec2(0.0, 0.0);

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

// 勾配ノイズ(0〜1)。値ノイズより丸い塊になり、格子に沿った箱のような形が出ない
vec2 grad_dir(vec2 c) {
	float a = hash(c) * 6.2831853;
	return vec2(cos(a), sin(a));
}

float gnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = dot(grad_dir(i), f);
	float b = dot(grad_dir(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
	float c = dot(grad_dir(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
	float d = dot(grad_dir(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
	return 0.5 + 0.75 * mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// 段ごとに向きを回して重ねる(格子に沿った、まっすぐな縁ができないように)
float fbm3(vec2 p) {
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	float v = gnoise(p) * 0.55;
	p = rot * p * 2.03 + vec2(1.7, 9.2);
	v += gnoise(p) * 0.3;
	p = rot * p * 2.01 + vec2(5.3, 2.1);
	v += gnoise(p) * 0.15;
	return v;
}

// 雲の塊の「中ほどらしさ」(0 = 雲の外、1 = 塊の芯)。p は雲の座標
float fullness(vec2 p, float edge, float bias) {
	// 形をゆがめて、塊の輪郭をうねらせる
	p += (vec2(gnoise(p * 0.9 + 4.7), gnoise(p * 0.9 + 12.1)) - 0.5) * 0.5;
	float m = (fbm3(p * 0.95) - 0.5) * 4.2 + 0.5 + bias;
	return clamp((m - edge) / 0.45, 0.0, 1.0);
}

// 雲を左右に寄せるための濃さの足し引き。こぶの真ん中(雲の座標)の、画面の左右の位置で決める。
// 描いている点の位置で決めると、1つのこぶが点ごとに出たり消えたりして、まっすぐ切れた形(ギザギザ)になる
float side_bias_at(vec2 c) {
	if (side_bias == 0.0) {
		return 0.0;
	}
	float x = c.x / max(aspect * cloud_scale, 0.0001) - drift;
	float side = 1.0 - smoothstep(0.0, side_width, min(x, 1.0 - x));
	return side_bias * (side - 0.5);
}

// 1段ぶんのこぶを調べて、この点を覆うこぶのうち、いちばん上のものを best に入れる。
// best = (上にある度合い, 色の明るさ 0〜1, こぶのふちで光と反対側か 0/1, 1 = 見つかった)
void puff_layer(vec2 p, float freq, float size, float lift, float min_full, float max_full, float edge, float seed, inout vec4 best) {
	vec2 i = floor(p * freq);
	vec2 light = normalize(light_dir);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 cell = i + vec2(float(x), float(y));
			vec2 jitter = hash2(cell + seed);
			vec2 center = (cell + 0.1 + jitter * 0.8) / freq;
			float bias = side_bias_at(center);
			float full = fullness(center, edge, bias);
			// この段のこぶは、塊の決まった深さ(芯〜ふち)にだけ置く
			if (full <= min_full || full > max_full) {
				continue;
			}
			float r = (0.5 + hash(cell + seed + 3.7) * 0.32) * size / freq;
			vec2 d = p - center;
			float dist = length(d);
			if (dist >= r) {
				continue;
			}
			// 上にある度合い: 塊の芯に近いほど上。少しばらして、重なり方をまだらにする
			float top = full * lift + hash(cell + seed + 8.1) * 0.18 + (1.0 - dist / r) * 0.04;
			if (top <= best.x) {
				continue;
			}
			// 塊の、光の側にあるか: 光の来る向きへ少し進むと塊が薄くなるなら、日なたの側。濃くなるなら、陰の側
			float ahead = fullness(center + light * light_reach, edge, bias);
			float behind = fullness(center - light * light_reach, edge, bias);
			float lit = clamp((behind - ahead) * 2.6, -0.7, 1.0);
			// 光の向きの影響は、塊のふちほど強い(芯は中間の色のまだら)
			float tone = 0.5 + lit * (0.5 + (1.0 - full) * 0.25) + (hash(cell + seed + 5.3) - 0.5) * 0.24;
			// こぶのふちの、光と反対側(こぶの陰)
			float rim = (dist / r > 0.8 && dot(d / max(dist, 0.0001), light) < -0.35) ? 1.0 : 0.0;
			best = vec4(top, clamp(tone, 0.0, 1.0), rim, 1.0);
		}
	}
}

void fragment() {
	// ドット絵のマスに揃える(マスは画面に対してまっすぐ。回っている背景でも、マスは斜めにならない)
	vec2 px = (floor(UV * rect_size / pixel_size) + 0.5) * pixel_size;
	// 画面の点 → 雲の置き場(回転・傾けた背景の中。真ん中が 0)→ 0〜1 の位置(背景の外にはみ出してもよい)
	vec2 local = inv_x * px.x + inv_y * px.y + inv_o;
	vec2 cell = local / rect_size + 0.5;
	vec2 p = vec2((cell.x + drift) * aspect, cell.y) * cloud_scale + vec2(0.0, -scroll * cloud_scale);
	// 形を少しゆがめて、こぶの並びが格子に見えないように
	p += (vec2(noise(p * 2.3 + 3.1), noise(p * 2.3 + 8.3)) - 0.5) * 0.08;

	float edge = mix(1.1, 0.35, coverage);

	// 大きなこぶ(芯)・中くらいのこぶ・小さなこぶ(ふち)を重ねる
	vec4 best = vec4(-1.0, 0.0, 0.0, 0.0);
	puff_layer(p, puff_density * 1.2, 0.95, 1.0, 0.4, 1.01, edge, 0.0, best);
	puff_layer(p, puff_density * 1.8, 1.1, 0.85, 0.15, 0.75, edge, 11.0, best);
	puff_layer(p, puff_density * 2.9, 1.05, 0.7, 0.07, 0.38, edge, 23.0, best);

	if (debug_view > 0.5) {
		float f = fullness(p, edge, side_bias_at(p));
		COLOR = vec4(vec3(f), 1.0);
	} else if (best.w < 0.5) {
		COLOR = vec4(sky_color.rgb, sky_alpha * opacity);
	} else {
		// 5段の色に分ける。こぶのふちの陰は、1段暗く
		// いちばん暗い色は、こぶの陰のふちにだけ使う(広い面をのっぺり暗くしない)
		float level = max(floor(best.y * 4.99), 1.0) - best.z;
		vec3 col = deep_color.rgb;
		if (level >= 4.0) {
			col = highlight_color.rgb;
		} else if (level >= 3.0) {
			col = cloud_color.rgb;
		} else if (level >= 2.0) {
			col = mid_color.rgb;
		} else if (level >= 1.0) {
			col = shadow_color.rgb;
		}
		COLOR = vec4(col, opacity);
	}
}
