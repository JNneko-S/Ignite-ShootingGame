extends Node
class_name TrackMarks
## 戦車の通った跡(履帯の跡)を地面に残す部品。敵(Enemy)の子に置く。
##   ・地面("ground" グループ。なければ "background_scroller")に対して動いた分だけ、履帯の跡を置いていく
##     (地面と一緒に流れているだけなら残さない。ボスのように画面の上で止まっていても、地面が流れていれば跡が伸びる)
##   ・跡は地面の子に描くので、背景と一緒に流れる。地面の上・残骸と戦車の下に描かれる
##   ・跡は Life 秒で薄くなって消える。戦車が倒されたり消えたりしても、跡はしばらく残る
##   ・向きは動いた向きから決める(曲がれば跡も曲がる)

## 履帯の中心の、車体の中心からの横のずれ(px、画面の上の大きさ)。2本なら [-17, 17] のように並べる
@export var tread_offsets : PackedFloat32Array = PackedFloat32Array([-17.0, 17.0])
## 履帯の跡1本の幅(px)
@export var tread_width : float = 9.0
## 跡を置く間隔(px)。跡はこの長さの Cleat Ratio 倍の長さの四角で、すき間が履帯の模様になる
@export var spacing : float = 6.0
@export_range(0.1, 1.0, 0.05) var cleat_ratio : float = 0.65
## 跡の色(アルファが一番濃いときの濃さ)
@export var color : Color = Color(0.12, 0.09, 0.06, 0.38)
## 跡が消えるまでの時間(秒)。最後の Fade Time 秒で薄くなる
@export var life : float = 6.0
@export var fade_time : float = 2.5
## 1両が残す跡の数の上限(古いものから消す)
@export var max_marks : int = 120
## 1フレームでこれより大きく動いたら(ワープなど)、跡をつながない(px)
@export var max_jump : float = 60.0

var _enemy : Node2D
var _layer : _MarkLayer
var _last : Vector2
var _has_last : bool = false
var _stopped : bool = false

func _ready() -> void:
	_enemy = get_parent() as Node2D
	if _enemy == null:
		push_warning("TrackMarks: 親が Node2D ではありません")
		return
	process_priority = 200 # GroundUnit(100)が位置を合わせたあとで見る
	if _enemy is Enemy:
		(_enemy as Enemy).died.connect(func(_e : Enemy) -> void: _stopped = true)
	_make_layer.call_deferred()

func _make_layer() -> void:
	var ground := get_tree().get_first_node_in_group("ground") as Node2D
	if ground == null:
		ground = get_tree().get_first_node_in_group("background_scroller") as Node2D
	if ground == null:
		return
	_layer = _MarkLayer.new()
	_layer.name = "TrackMarks"
	_layer.owner_node = self
	_layer.color = color
	_layer.life = life
	_layer.fade_time = fade_time
	_layer.max_marks = max_marks
	ground.add_child(_layer)
	ground.move_child(_layer, 0) # 残骸・地上の敵より下に描く
	# 画面の px で描けるよう、回転と拡大を打ち消しておく(そのあとは地面と一緒に動く)
	_layer.global_rotation = 0.0
	_layer.global_scale = Vector2.ONE

func _process(_delta : float) -> void:
	if _layer == null or not is_instance_valid(_layer) or _stopped or not is_instance_valid(_enemy):
		return
	var here := _layer.to_local(_enemy.global_position)
	if not _has_last:
		_last = here
		_has_last = true
		return
	var moved := here - _last
	var length := moved.length()
	if length > max_jump:
		_last = here
		return
	if length < spacing:
		return
	var dir := moved / length
	var side := dir.orthogonal()
	# 動いた分を Spacing ごとに区切って置く(速く走っても跡が途切れない)
	var steps := floori(length / spacing)
	for i in steps:
		var center := _last + dir * spacing * (i + 0.5)
		for offset in tread_offsets:
			_layer.add_mark(center + side * offset, dir, spacing * cleat_ratio, tread_width)
	_last += dir * spacing * steps

func _exit_tree() -> void:
	if _layer and is_instance_valid(_layer):
		_layer.owner_node = null

## 地面の子に置いて、跡をまとめて描くノード
class _MarkLayer extends Node2D:
	var owner_node : Node
	var color : Color
	var life : float
	var fade_time : float
	var max_marks : int
	var _time : float = 0.0
	## 1つの跡: [位置, 向き, 長さ, 幅, 置いた時刻]
	var _marks : Array = []

	func add_mark(pos : Vector2, dir : Vector2, length : float, width : float) -> void:
		_marks.append([pos, dir, length, width, _time])
		if _marks.size() > max_marks:
			_marks.pop_front()

	func _process(delta : float) -> void:
		_time += delta
		while not _marks.is_empty() and _time - (_marks[0][4] as float) >= life:
			_marks.pop_front()
		if _marks.is_empty() and owner_node == null:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		for mark in _marks:
			var age : float = _time - (mark[4] as float)
			var alpha := clampf((life - age) / maxf(fade_time, 0.01), 0.0, 1.0)
			if alpha <= 0.0:
				continue
			var dir : Vector2 = mark[1]
			var length : float = mark[2]
			var width : float = mark[3]
			draw_set_transform(mark[0], dir.angle(), Vector2.ONE)
			draw_rect(Rect2(-length * 0.5, -width * 0.5, length, width), Color(color, color.a * alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
