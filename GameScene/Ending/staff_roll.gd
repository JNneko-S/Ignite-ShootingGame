extends Control
class_name StaffRoll
## エンディング(スタッフロール)。シーン(GameScene/Ending/staff_roll.tscn)。ラストステージのクリアのあとに出る。
##   1. 白から明けて、真ん中にクリアの合図(banner)が出る(NORMAL ROUND CLEAR! など)
##   2. 合図が上へ消えると、スタッフロール(Credits の中のラベル)が下から上へ流れる
##   3. 流れ終わったら暗くなって、Next Scene へ(タイトル。二周目へ進むときは、タイトルが合図を見せて一面へ)
## ショットを押しているあいだは、速く流れる。
##
## スタッフロールの中身は、シーンの Credits(VBoxContainer)の子のラベルを書き換える・足す:
##   ・Heading … 役割の見出し(朱)。テーマの型 "CreditHeading"
##   ・Name    … 名前(墨)。テーマの型 "CreditName"
##   ・Spacer  … 間をあける(Control。高さは Custom Minimum Size)
## 見出し・名前のラベルを複製して文字を変えれば、そのまま並ぶ。

## 合図の文字。ラストステージ(EndingSequence)が入れる
static var banner : String = "NORMAL ROUND CLEAR!"
## 合図の色。二周目は赤
static var banner_color : Color = Color(0.86, 0.62, 0.0)
## 終わったら進むシーン
static var next_scene : String = "res://title.tscn"

## 合図を見せる時間(秒)・スタッフロールが流れる速さ(px/秒)・押しているときの倍率
@export var banner_time : float = 3.5
@export var scroll_speed : float = 34.0
@export var fast_scale : float = 4.0

@onready var _banner : Label = $Banner
@onready var _band : ColorRect = $BannerBand
@onready var _credits : Control = $Credits
@onready var _white : ColorRect = $White
@onready var _black : ColorRect = $Black

var _rolling : bool = false
var _leaving : bool = false

func _ready() -> void:
	_banner.text = banner
	_banner.label_settings = _banner.label_settings.duplicate()
	_banner.label_settings.font_color = banner_color
	# 横に収まる大きさにする
	_banner.label_settings.font_size = clampi(int(290.0 / maxf(banner.length() * 0.82, 1.0)), 14, 30)
	_banner.modulate.a = 0.0
	_band.modulate.a = 0.0
	_black.color.a = 0.0
	_credits.position.y = size.y + 20.0
	_play.call_deferred()

func _play() -> void:
	# 白から明ける
	var dawn := create_tween()
	dawn.tween_property(_white, "color:a", 0.0, 1.6)
	await get_tree().create_timer(0.8).timeout
	# 合図
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2(1.6, 1.6)
	var show := create_tween().set_parallel(true)
	show.tween_property(_banner, "modulate:a", 1.0, 0.4)
	show.tween_property(_band, "modulate:a", 1.0, 0.3)
	_band.scale.y = 0.0
	_band.pivot_offset = _band.size * 0.5
	show.tween_property(_band, "scale:y", 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	show.tween_property(_banner, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(banner_time).timeout
	var hide := create_tween().set_parallel(true)
	hide.tween_property(_banner, "modulate:a", 0.0, 0.8)
	hide.tween_property(_band, "modulate:a", 0.0, 0.8)
	hide.tween_property(_banner, "position:y", _banner.position.y - 40.0, 0.8)
	await hide.finished
	_rolling = true

func _process(delta : float) -> void:
	if not _rolling or _leaving:
		return
	var speed := scroll_speed
	if Input.is_action_pressed("UI_Shoot") or Input.is_action_pressed("ui_accept"):
		speed *= fast_scale
	_credits.position.y -= speed * delta
	if _credits.position.y + _credits.size.y < -20.0:
		_leave()

func _leave() -> void:
	_leaving = true
	var fade := create_tween()
	fade.tween_property(_black, "color:a", 1.0, 1.2)
	await fade.finished
	await get_tree().create_timer(0.5).timeout
	SceneSwitcher.change(next_scene, 0.8)
