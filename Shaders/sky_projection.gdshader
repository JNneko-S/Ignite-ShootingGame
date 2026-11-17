shader_type canvas_item;
// 空中戦(ステージ3)の背景を、2Dのまま擬似3Dに映す。SkyBackground が SubViewport に描いた背景の絵を、
// 画面いっぱいの Sprite2D に貼って、このシェーダーで次の2つをかける:
//   1. 遠近(tilt): 背景を、奥へ倒れた板のように見せる。画面の上ほど遠く(小さく・霞む)、下ほど近い(大きい)
//   2. 筒(curve): 背景を、進む向きを軸にした筒の表面に貼ったように見せる。左右の端ほど縮み、暗くなる。
//      筒を回す(ロール)ときは、SkyBackground が雲や海を横へ流す(このシェーダーは曲げるだけ)
// 画面の点 → 背景の絵の点 の計算は、SkyBackground.screen_to_local と同じ式(逆向きは local_to_screen)。
//   画面の点を、画面の真ん中を 0 とした (X, Y)(単位: 画面の幅・高さ)にして、
//   V  = Y / (1 + tilt * Y)            … 遠近をほどく
//   Xc = X * (1 - tilt * V)
//   U  = asin(Xc * curve) / curve      … 筒をほどく(curve が 0 なら U = Xc)
//   背景の絵の点 = 0.5 + (U, V) / oversize

uniform float tilt : hint_range(0.0, 0.9) = 0.0;
uniform float curve : hint_range(0.0, 1.5) = 0.0;
// 背景の絵が、画面の何倍の大きさか(SkyBackground が入れる)
uniform vec2 oversize = vec2(1.8, 1.8);
// 遠く(画面の上)を霞ませる色と強さ
uniform vec4 haze_color : source_color = vec4(0.98, 0.72, 0.6, 1.0);
uniform float haze : hint_range(0.0, 1.0) = 0.6;
// 筒の左右の端を暗くする色と強さ
uniform vec4 edge_color : source_color = vec4(0.32, 0.2, 0.36, 1.0);
uniform float edge_shade : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	vec2 s = UV - 0.5;
	float v = s.y / (1.0 + tilt * s.y);
	float xc = s.x * (1.0 - tilt * v);
	float u = xc;
	float facing = 1.0; // 筒の面が、こちらを向いている度合い(端ほど 0)
	if (curve > 0.001) {
		float q = clamp(xc * curve, -1.0, 1.0);
		u = asin(q) / curve;
		facing = sqrt(max(1.0 - q * q, 0.0));
	}
	vec2 buv = 0.5 + vec2(u, v) / oversize;
	vec4 c = texture(TEXTURE, buv);
	// 遠いほど霞む(遠近の分母が大きいほど遠い)
	float far = clamp(-tilt * v * 1.6, 0.0, 1.0);
	c.rgb = mix(c.rgb, haze_color.rgb, far * haze);
	// 筒の端ほど暗く
	c.rgb = mix(c.rgb, edge_color.rgb, (1.0 - facing) * edge_shade);
	COLOR = vec4(c.rgb, 1.0);
}
