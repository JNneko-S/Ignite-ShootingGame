shader_type canvas_item;
// ゲームオーバーのシャッター。金属の板(スラット)が横に並んだ絵を、絵を使わずに描く。
// 閉まる側のふち(上のシャッターは下のふち、下のシャッターは上のふち)に、黄色と黒の警告の帯を付ける。

// シャッターの大きさ(px)。GameOverScreen が入れる
uniform vec2 rect_size = vec2(336.0, 224.0);
// オンなら、警告の帯を下のふちに付ける(上から降りるシャッター)
uniform bool edge_at_bottom = true;
// 金属の色と、板1枚の高さ(px)
uniform vec4 metal_color : source_color = vec4(0.32, 0.34, 0.38, 1.0);
uniform float slat_height = 14.0;
// 警告の帯の高さ(px)と色
uniform float edge_height = 16.0;
uniform vec4 stripe_color : source_color = vec4(0.95, 0.72, 0.1, 1.0);
uniform vec4 stripe_dark : source_color = vec4(0.08, 0.08, 0.09, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 px = UV * rect_size;
	float from_edge = edge_at_bottom ? rect_size.y - px.y : px.y;
	vec3 col;
	if (from_edge < 3.0) {
		// いちばんふちのゴム
		col = vec3(0.04);
	} else if (from_edge < edge_height) {
		// 黄色と黒の斜めの帯。上下に少し丸みの陰を付ける
		float diag = (px.x + (edge_at_bottom ? px.y : -px.y)) / 10.0;
		float stripe = step(0.5, fract(diag));
		col = mix(stripe_dark.rgb, stripe_color.rgb, stripe);
		float t = (from_edge - 3.0) / (edge_height - 3.0);
		col *= 0.75 + 0.35 * sin(t * 3.14159);
	} else {
		// 金属の板: 板の上は明るく、下は暗く、板と板のすき間は黒い
		float s = mod(px.y - (edge_at_bottom ? rect_size.y : 0.0), slat_height) / slat_height;
		float shade = 0.82 + 0.3 * (1.0 - s);
		if (s < 0.1) shade += 0.25;
		if (s > 0.88) shade *= 0.45;
		// 横にこすったような細かいむら
		float grain = hash(vec2(floor(px.x / 3.0), floor(px.y))) * 0.07;
		col = metal_color.rgb * shade + grain;
		// 左右のはしは暗く(レールの影)
		float side = min(px.x, rect_size.x - px.x);
		col *= mix(0.55, 1.0, smoothstep(0.0, 14.0, side));
	}
	COLOR = vec4(col, 1.0);
}
