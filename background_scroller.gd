extends Node2D
class_name BackgroundScroller
## 縦に長い背景を、下から上の端までスクロールさせて、上の端がカメラの上端に着いたら止める。
## (Parallax2D のループとは違い、1枚の長いマップを最後まで見せるためのもの)
##
## 使い方:
##   1. このスクリプトを付けた Node2D を置き、その子に背景(Sprite2D / TileMapLayer)を並べる
##   2. 開始時に背景の下の端がカメラの下端にそろうので、背景はどの位置に描いてもよい
##   3. StageRunner があれば、ScrollSpeedEvent の速度倍率(0 で停止など)もそのまま効く
##
## 背景の上下の端は、子の Sprite2D / TileMapLayer から自動で求める。
## それ以外のノード(ColorRect など)を使うときは、auto_detect_bounds をオフにして手で入れる。

## 上の端に着いたときに出る(ボス出現の合図などに使える)
signal reached_top

## 1秒あたりに進む距離(px)。StageRunner のスクロール倍率が掛かる
@export var scroll_speed : float = 60.0
## 0 より大きければ、ステージの経過時間がこの秒数になったときに、ちょうど上の端に着くように動かす。
## (scroll_speed とスクロール倍率は使わない。ボスの出現時刻に合わせたいときに便利)
@export var arrive_at_time : float = 0.0
## 上の端の手前、この距離(px)から減速して、ふわっと止まる。0 なら急に止まる
@export var stop_ease_distance : float = 80.0
## true なら、開始時に背景の下の端をカメラの下端にそろえる
@export var align_bottom_on_start : bool = true
## 設定すると、上の端に着いても止まらず、この絵(子の Sprite2D。背景の上の端に置いておく)を上へ繰り返し並べて、
## スクロールを続ける(ボス戦で、地面が流れ続けるように)。絵のテクスチャは縦につながる絵にする
@export var loop_sprite : Sprite2D

@export_group("背景の範囲")
## true なら、子の Sprite2D / TileMapLayer から背景の上下の端を求める
@export var auto_detect_bounds : bool = true
## auto_detect_bounds がオフのときの、背景の上の端(このノードから見た y)
@export var manual_top : float = -2000.0
## auto_detect_bounds がオフのときの、背景の下の端(このノードから見た y)
@export var manual_bottom : float = 0.0

## 0.0(スタート位置)〜1.0(上の端に着いた)
var progress : float = 0.0
var is_at_top : bool = false

var _start_y : float = 0.0
var _end_y : float = 0.0
var _initialized : bool = false
var _runner : StageRunner
## 上の端を過ぎて、繰り返しの絵で流れ続けているか
var _looping : bool = false
## 繰り返しの絵の、下の端(このノードから見た y)と、1枚の大きさ(テクスチャの px)
var _loop_bottom : float = 0.0
var _loop_tile : Vector2 = Vector2.ONE

func _ready() -> void:
	add_to_group("background_scroller")

func _process(delta : float) -> void:
	if not _initialized:
		_initialize() # カメラの位置が決まってから測るため、最初のフレームで行う
		return
	if _looping:
		# 上の端を過ぎたあとは、繰り返す絵を上へ足しながら、流れ続ける
		position.y += scroll_speed * (_runner.scroll_multiplier if _runner else 1.0) * delta
		_update_loop()
		return
	if is_at_top:
		return

	if arrive_at_time > 0.0:
		var time := _runner.stage_time if _runner else 0.0
		_set_progress(clampf(time / arrive_at_time, 0.0, 1.0))
	else:
		var multiplier := _runner.scroll_multiplier if _runner else 1.0
		var remaining := _end_y - position.y
		var speed := scroll_speed * multiplier
		if stop_ease_distance > 0.0 and loop_sprite == null: # 繰り返すときは、止まらないので減速しない
			speed *= clampf(remaining / stop_ease_distance, 0.1, 1.0)
		position.y = minf(position.y + speed * delta, _end_y)
		progress = _progress_of(position.y)

	if position.y >= _end_y - 0.01:
		position.y = _end_y
		progress = 1.0
		is_at_top = true
		reached_top.emit()
		if loop_sprite:
			_start_loop()

## 繰り返しの準備: 絵の下の端(背景の上の端とのつなぎ目)を固定して、上へ伸ばせるようにする
func _start_loop() -> void:
	_looping = true
	var s := loop_sprite
	var tex_size := s.texture.get_size()
	var rect := s.get_rect() # 今の見た目の範囲(絵のローカル座標)
	_loop_bottom = s.position.y + rect.end.y * s.scale.y
	var left := s.position.x + rect.position.x * s.scale.x
	s.centered = false
	s.offset = Vector2.ZERO
	s.region_enabled = true
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.position.x = left
	_loop_tile = tex_size
	_update_loop()

## 絵を、つなぎ目からカメラの上の端の少し上まで、1枚分ずつ伸ばす(下の端は動かさない)
func _update_loop() -> void:
	var s := loop_sprite
	var view := CameraView.visible_rect(self)
	var top_local := (global_transform.affine_inverse() * view.position).y - _loop_tile.y * s.scale.y
	var tiles := maxi(ceili((_loop_bottom - top_local) / (_loop_tile.y * s.scale.y)), 1)
	var height := tiles * _loop_tile.y
	s.region_rect = Rect2(0.0, _loop_tile.y - height, _loop_tile.x, height) # 下の段が、もとの絵の位置になる
	s.position.y = _loop_bottom - height * s.scale.y

## 今の位置を記録しなおす(背景の中身やカメラを途中で変えたときに呼ぶ)
func _initialize() -> void:
	_initialized = true
	_runner = get_tree().get_first_node_in_group("stage_runner") as StageRunner
	var bounds := _content_bounds()
	var view := CameraView.visible_rect(self)
	var scale_y := global_scale.y
	var parent_y := (get_parent() as Node2D).global_position.y if get_parent() is Node2D else 0.0
	# position.y を変えると、背景の端のワールド座標は (parent_y + position.y + 端 * scale_y) になる
	if align_bottom_on_start:
		position.y = view.end.y - parent_y - bounds.y * scale_y
	_start_y = position.y
	_end_y = maxf(view.position.y - parent_y - bounds.x * scale_y, _start_y)
	if _end_y - _start_y < 1.0:
		push_warning("BackgroundScroller: 背景がカメラより短いので、スクロールしません")

	# 「ここから試遊」などで途中から始めたときは、その時刻までに進んだはずの分だけ先に進める
	if _runner and _runner.stage_time > 0.0:
		if arrive_at_time > 0.0:
			_set_progress(clampf(_runner.stage_time / arrive_at_time, 0.0, 1.0))
		else:
			position.y = minf(position.y + scroll_speed * _runner.scroll_multiplier * _runner.stage_time, _end_y)
			progress = _progress_of(position.y)

func _set_progress(value : float) -> void:
	progress = value
	position.y = lerpf(_start_y, _end_y, value)

func _progress_of(y : float) -> float:
	if _end_y <= _start_y:
		return 1.0
	return clampf((y - _start_y) / (_end_y - _start_y), 0.0, 1.0)

## 背景の (上の端, 下の端) を、このノードから見た y で返す
func _content_bounds() -> Vector2:
	if not auto_detect_bounds:
		return Vector2(manual_top, manual_bottom)
	var rect := Rect2()
	var found := false
	var inverse := global_transform.affine_inverse()
	for node in find_children("*", "", true, false):
		var local_rect := Rect2()
		if node is Sprite2D and (node as Sprite2D).texture:
			local_rect = (node as Sprite2D).get_rect()
		elif node is TileMapLayer and (node as TileMapLayer).tile_set:
			var layer := node as TileMapLayer
			var used := layer.get_used_rect()
			if used.size == Vector2i.ZERO:
				continue
			var tile_size := Vector2(layer.tile_set.tile_size)
			local_rect = Rect2(layer.map_to_local(used.position) - tile_size / 2.0, Vector2(used.size) * tile_size)
		else:
			continue
		var r := inverse * (node as Node2D).global_transform * local_rect
		rect = r if not found else rect.merge(r)
		found = true
	if not found:
		push_warning("BackgroundScroller: 子に Sprite2D / TileMapLayer がありません。manual_top / manual_bottom を使います")
		return Vector2(manual_top, manual_bottom)
	return Vector2(rect.position.y, rect.end.y)
