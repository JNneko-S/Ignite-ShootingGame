extends Control
class_name LivesLabel
## 残機の表示。自機の小さなアイコンを横に並べる(イグナイトゲージの下に置く)。GameManager から bind() で Player を受け取る。
##   ・Max Icons より多いときは、アイコン1つと「×数」で出す
##   ・増えたとき: 新しいアイコンが、ぽんと弾んで出てくる
##   ・減ったとき: いちばん右のアイコンが、赤く光ってから縮んで消える
## "hud" グループに入るので、HudFader で半透明にできる。

## アイコンの絵(自機の絵)。機体選択を通って出撃したときは、選んだ機体の絵に変わる
@export var icon : Texture2D = preload("res://Assets/PHOENIX.png")
## アイコンの大きさと間隔(px)
@export var icon_size : float = 16.0
@export var spacing : float = 2.0
## これより多いときは「アイコン ×数」で出す
@export var max_icons : int = 6
## 「×数」の文字
@export var font : Font = preload("res://Assets/Fonts/micronian.ttf")
@export var font_size : int = 16

var _lives : int = 0
var _bound : bool = false
## 増えたアイコンの弾み(0〜1、1 で弾み始め)と、減ったアイコンの消え方(0〜1、1 で消え始め)
var _pop : float = 0.0
var _lost : float = 0.0
var _anim : Tween

func _enter_tree() -> void:
    add_to_group("hud")

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func bind(player : Player) -> void:
    # 機体選択で選んだ機体の絵にする(BASTION なら BASTION の絵)
    if RunConfig.has_selection and RunConfig.ship and RunConfig.ship.texture:
        icon = RunConfig.ship.texture
    if not player.lives_changed.is_connected(_on_lives_changed):
        player.lives_changed.connect(_on_lives_changed)
    _bound = false
    _on_lives_changed(player.lives)

func _on_lives_changed(lives : int) -> void:
    var before := _lives
    _lives = maxi(lives, 0)
    if _bound and _anim:
        _anim.kill()
    if _bound and lives > before:
        _animate("_pop", 0.45)
    elif _bound and lives < before:
        _animate("_lost", 0.6)
    _bound = true
    queue_redraw()

func _animate(property : String, time : float) -> void:
    set(property, 1.0)
    _anim = create_tween()
    _anim.tween_method(func(v : float) -> void:
        set(property, v)
        queue_redraw(), 1.0, 0.0, time)

func _draw() -> void:
    if icon == null:
        return
    var step := icon_size + spacing
    var compact := _lives > max_icons
    var shown := 1 if compact else _lives
    for i in shown:
        var scale := 1.0
        var color := Color.WHITE
        if i == shown - 1 and _pop > 0.0 and not compact:
            # 弾んで出てくる(大きく出て、元の大きさに戻る)
            scale = 1.0 + 0.6 * sin(_pop * PI) * _pop
        _draw_icon(Vector2(i * step, 0.0), scale, color)
    # 減ったアイコン: いちばん右の空いたところで、赤く光って縮んで消える
    if _lost > 0.0 and not compact:
        var flash := Color(1.0, 0.35, 0.3, _lost)
        _draw_icon(Vector2(shown * step, 0.0), _lost, flash)
    if compact:
        var text := "x%d" % _lives # このフォントには「×」がないので x
        var y := icon_size * 0.5 + font_size * 0.35
        draw_string_outline(font, Vector2(step + 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color.BLACK)
        draw_string(font, Vector2(step + 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

## 左上 at に、scale 倍のアイコンを描く(大きさが変わっても、真ん中はずれない)。黒い縁取りを付ける
func _draw_icon(at : Vector2, scale : float, color : Color) -> void:
    var s := icon_size * scale
    var rect := Rect2(at + Vector2(icon_size - s, icon_size - s) * 0.5, Vector2(s, s))
    for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
        draw_texture_rect(icon, Rect2(rect.position + o, rect.size), false, Color(0, 0, 0, 0.8 * color.a))
    draw_texture_rect(icon, rect, false, color)
