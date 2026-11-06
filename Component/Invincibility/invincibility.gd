extends Node
class_name Invincibility
## 無敵時間の部品。持ち主の子に置いて start(秒) を呼ぶ。無敵のあいだ、target を点滅させる。
## すでに無敵で、残りの方が長ければ何もしない(短い無敵で、長い無敵を上書きしない)。

signal ended

## 点滅させるノード。未設定なら親
@export var target : CanvasItem
## 1回の点滅の時間(秒)と、薄くなったときの透明度
@export var blink_interval : float = 0.2
@export_range(0.0, 1.0, 0.05) var blink_alpha : float = 0.3

var _active : bool = false
var _end_msec : int = 0
var _tween : Tween

func _ready() -> void:
	if target == null:
		target = get_parent() as CanvasItem

func start(seconds : float) -> void:
	if seconds <= 0.0:
		return
	var end_msec := Time.get_ticks_msec() + int(seconds * 1000.0)
	if _active and end_msec <= _end_msec:
		return
	_active = true
	_end_msec = end_msec
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_loops(maxi(int(seconds / blink_interval), 1))
	_tween.tween_property(target, "modulate:a", blink_alpha, blink_interval * 0.5)
	_tween.tween_property(target, "modulate:a", 1.0, blink_interval * 0.5)
	_tween.finished.connect(stop)

## 無敵を終える
func stop() -> void:
	if _tween:
		_tween.kill()
	var was_active := _active
	_active = false
	if target:
		target.modulate.a = 1.0
	if was_active:
		ended.emit()

func is_active() -> bool:
	return _active
