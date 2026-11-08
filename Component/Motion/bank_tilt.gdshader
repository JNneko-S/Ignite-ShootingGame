shader_type canvas_item;
// 上から見た戦闘機を、機首〜機尾の軸のまわりに傾けて(ロール)見せる。roll は MotionTilt が入れる。
// 絵を「板」とみなして傾けるので:
//   ・奥へ倒れた側は小さく暗く、手前に起きた側は大きく明るくなる
//   ・全体の横幅は cos(roll) 倍に細くなる
// 頂点を動かすので、hframes やアトラスの絵でもそのまま使える。

// 傾き(ラジアン)。プラスで、絵の +x 側(右)が奥へ倒れる
uniform float roll = 0.0;
// 遠近感の強さ(px)。小さいほど、手前と奥の大きさの差が大きい
uniform float focal = 140.0;
// 明るさの変わり方
uniform float shade = 0.6;

varying vec2 uv_q;
varying float q;
varying float depth;

void vertex() {
	float s = sin(roll);
	float c = cos(roll);
	float z = VERTEX.x * s; // プラスが奥
	float f = focal / max(focal + z, 1.0);
	depth = z / focal;
	VERTEX = vec2(VERTEX.x * c * f, VERTEX.y * f);
	// 遠近を正しく補間する(UV*f と f は画面上で直線的に変わる)
	uv_q = UV * f;
	q = f;
}

void fragment() {
	vec4 tex = texture(TEXTURE, uv_q / q);
	float light = clamp(1.0 - depth * shade * 2.0, 0.6, 1.4);
	COLOR = vec4(tex.rgb * light, tex.a) * COLOR;
}
