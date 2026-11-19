extends Node
class_name TextureCycle
## 親の Sprite2D の絵(Texture)を、Textures の順に切り替え続ける(別々の画像に分かれたアニメーション用)。
## 例) Tank Mid Boss の車輪(3枚)・車体(4枚)・ライト(4枚)
## Textures が空なら、親の Sprite2D のコマ(Hframes で分けた横並びの絵)を順に送る(ヌクレオの背景など)

@export var textures : Array[Texture2D] = []
## 1秒あたりの枚数
@export var fps : float = 10.0
## オンなら、行ったり来たり(1 2 3 2 1 …)で切り替える
@export var ping_pong : bool = false

var _sprite : Sprite2D
var _time : float = 0.0

func _ready() -> void:
	_sprite = get_parent() as Sprite2D
	if _sprite and not textures.is_empty():
		_sprite.texture = textures[0]

func _process(delta : float) -> void:
	if _sprite == null or fps <= 0.0:
		return
	var count := textures.size() if not textures.is_empty() else _sprite.hframes * _sprite.vframes
	if count < 2:
		return
	_time += delta
	var step := int(_time * fps)
	var index := step % count
	if ping_pong:
		var cycle := count * 2 - 2
		var k := step % cycle
		index = k if k < count else cycle - k
	if textures.is_empty():
		_sprite.frame = index
	else:
		_sprite.texture = textures[index]
