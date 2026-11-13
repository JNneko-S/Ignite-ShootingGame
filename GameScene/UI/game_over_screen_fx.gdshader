shader_type canvas_item;
// ゲームオーバーの画面全体に掛けるノイズ。画面いっぱいの ColorRect に付けて、いちばん手前に置く。
//   ・砂あらしのような細かいノイズ
//   ・走査線
//   ・ときどき、横の帯がずれる(映像が乱れる)
//   ・少し色が抜ける
//   ・画面の周りが暗い(ビネット)
// strength を 0 → 1 にすると、だんだん掛かる。

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
// 全体の効き具合(0 で何もしない)
uniform float strength : hint_range(0.0, 1.0) = 1.0;
// 砂あらしの強さ
uniform float noise_amount : hint_range(0.0, 1.0) = 0.13;
// 走査線の濃さ
uniform float scanline_amount : hint_range(0.0, 1.0) = 0.18;
// 横の帯がずれる量(画面の幅に対する割合)と、ずれる頻度(0〜1。大きいほど多い)
uniform float tear_amount = 0.02;
uniform float tear_chance : hint_range(0.0, 1.0) = 0.04;
// 色の抜け具合
uniform float desaturate : hint_range(0.0, 1.0) = 0.35;
// 画面の周りの暗さ
uniform float vignette : hint_range(0.0, 1.0) = 0.6;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float tick = floor(TIME * 14.0);
	// 横の帯のずれ
	float row = floor(uv.y * 70.0);
	float tear = step(1.0 - tear_chance, hash(vec2(row, tick))) * (hash(vec2(tick, row)) - 0.5) * 2.0 * tear_amount;
	uv.x += tear * strength + sin(uv.y * 300.0 + TIME * 25.0) * 0.0008 * strength;
	// 少しだけ赤をずらす(映像のにじみ)
	vec3 col = texture(screen_tex, uv).rgb;
	col.r = texture(screen_tex, uv + vec2(0.002 * strength, 0.0)).r;
	// 色を抜く
	float gray = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(gray), desaturate * strength);
	// 砂あらし
	float n = hash(floor(FRAGCOORD.xy / 2.0) + vec2(tick * 7.3, tick * 3.1));
	col += (n - 0.5) * noise_amount * strength;
	// 走査線
	col *= 1.0 - scanline_amount * strength * (0.5 + 0.5 * sin(FRAGCOORD.y * 1.5708));
	// 周りを暗く
	vec2 d = (SCREEN_UV - 0.5) * vec2(1.0, 0.9);
	float v = smoothstep(0.78, 0.2, length(d));
	col *= mix(1.0, mix(1.0 - vignette, 1.0, v), strength);
	COLOR = vec4(col, 1.0);
}
