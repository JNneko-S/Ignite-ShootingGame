shader_type canvas_item;
// イグナイト中の、画面の四辺の光。ふちが一番明るく、内側へ向かって消える
uniform vec4 glow_color : source_color = vec4(1.0, 0.45, 0.1, 1.0);
// 光の強さ(0 で見えない)
uniform float intensity = 0.0;
// 光の太さ(画面の幅に対する割合)
uniform float thickness = 0.12;
// 大きいほど、ふちに寄った鋭い光になる
uniform float sharpness = 1.8;

void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 px = UV * size;
	// ふちからの距離(px)を、画面の幅で割る。縦横で太さがそろう
	float d = min(min(px.x, size.x - px.x), min(px.y, size.y - px.y)) / size.x;
	float g = 1.0 - clamp(d / max(thickness, 0.0001), 0.0, 1.0);
	g = pow(g, sharpness);
	// 角を少し明るく
	float corner = 1.0 - clamp(length(min(px, size - px)) / (size.x * thickness * 2.0), 0.0, 1.0);
	COLOR = vec4(glow_color.rgb * (1.0 + corner), glow_color.a * clamp(g + corner * 0.3, 0.0, 1.0) * intensity);
}
