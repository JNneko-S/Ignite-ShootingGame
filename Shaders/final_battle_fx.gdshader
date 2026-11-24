shader_type canvas_item;
// 最終決戦の画面効果(FinalBattleIntro が使う)。後ろのゲーム画面を読んで、次のことをする:
//   ・衝撃波: Wave Center から広がる輪のところだけ、画面をゆがめて光らせる
//   ・色ずれ(Aberration): 赤と青を外側へずらす
//   ・赤い縁取り(Vignette): 画面の端を、Vignette Color に染める(Pulse で脈打つ)
//   ・陽炎(Heat): 画面が横にゆらゆら揺れる
//   ・色を抜く(Desaturate)

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 wave_center = vec2(0.5, 0.5);
uniform float wave_radius = 0.0;
uniform float wave_width = 0.07;
uniform float wave_strength = 0.0;
uniform float aberration : hint_range(0.0, 0.05) = 0.0;
uniform float vignette : hint_range(0.0, 1.0) = 0.0;
uniform vec4 vignette_color : source_color = vec4(0.55, 0.03, 0.0, 1.0);
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform float heat : hint_range(0.0, 1.0) = 0.0;
uniform float desaturate : hint_range(0.0, 1.0) = 0.0;
// 画面の 幅 / 高さ(輪を真円にするため)
uniform float aspect = 0.75;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - wave_center;
	d.x *= aspect;
	float dist = length(d);
	float ring = 1.0 - smoothstep(0.0, wave_width, abs(dist - wave_radius));
	vec2 dir = dist > 0.0001 ? d / dist : vec2(0.0);
	dir.x /= aspect;
	uv -= dir * ring * wave_strength;
	uv.x += sin(uv.y * 70.0 + TIME * 7.0) * heat * 0.004;
	vec2 shift = (uv - 0.5) * aberration;
	float r = texture(screen_tex, uv + shift).r;
	vec4 base = texture(screen_tex, uv);
	float b = texture(screen_tex, uv - shift).b;
	vec3 col = vec3(r, base.g, b);
	float gray = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(gray), desaturate);
	vec2 v = SCREEN_UV - 0.5;
	float edge = smoothstep(0.22, 0.78, length(v * vec2(1.0, 0.85)));
	float beat = 0.75 + 0.25 * sin(TIME * 5.0) * pulse;
	col = mix(col, vignette_color.rgb, edge * vignette * beat);
	col += ring * wave_strength * 4.0 * vec3(1.0, 0.55, 0.35);
	COLOR = vec4(col, 1.0);
}
