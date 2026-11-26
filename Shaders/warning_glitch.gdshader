shader_type canvas_item;
// WARNING の画面ぜんたいに掛けるグリッチ(裏ボスの WARNING)。画面いっぱいの ColorRect に付けて、いちばん手前に置く。
//   ・四角いかたまりが、横にずれる(映像が壊れる)
//   ・横の細い帯が裂ける
//   ・赤と青がずれる(色ずれ)
//   ・ときどき、かたまりの色が反転する
//   ・黒い線が抜け落ちる、細かい砂あらし
// amount を 0 → 1 にすると、だんだん強く掛かる(0 のときは、ノードを隠しておく)。

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float amount : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float tick = floor(TIME * 22.0);
	// 四角いかたまりのずれ
	vec2 block = floor(uv * vec2(7.0, 24.0));
	float on = step(1.0 - 0.28 * amount, hash(block + vec2(tick, tick * 0.37)));
	uv.x += on * (hash(block * 1.7 + tick) - 0.5) * 0.3 * amount;
	// 横の細い帯の裂け目
	float row = floor(uv.y * 140.0);
	uv.x += step(1.0 - 0.1 * amount, hash(vec2(row, tick * 1.3))) * (hash(vec2(tick, row)) - 0.5) * 0.12 * amount;
	// 色ずれ
	float split = 0.014 * amount * (0.4 + hash(vec2(tick, 3.0)));
	vec3 col;
	col.r = texture(screen_tex, uv + vec2(split, 0.0)).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - vec2(split, split * 0.3)).b;
	// かたまりの反転
	float invert = on * step(0.72, hash(block + vec2(tick * 2.1, 5.0)));
	col = mix(col, vec3(1.0) - col, invert * amount);
	// 黒く抜け落ちる線
	float drop = step(1.0 - 0.05 * amount, hash(vec2(row * 3.1, tick)));
	col *= 1.0 - drop * 0.92;
	// 砂あらし
	float n = hash(floor(FRAGCOORD.xy / 2.0) + vec2(tick * 5.3, tick * 1.9));
	col += (n - 0.5) * 0.28 * amount;
	COLOR = vec4(col, 1.0);
}
