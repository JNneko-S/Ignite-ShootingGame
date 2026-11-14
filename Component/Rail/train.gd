extends Node2D
class_name Train
## 線路(RailGround)の上を走る列車。車両(Enemy のシーン)を縦につないで走らせる。TrainEvent が出す。
##
##   ・地面と一緒に流れながら、線路に沿って Speed で走る(プラスで画面の上へ進む。先頭は進む向きの端)
##   ・進む向きの、画面の外から入ってきて、反対側の外へ出たら消える
##   ・車両は Enemy なので、撃って壊せる(ロックオンもできる)。Wreck Texture を持つ車両は、壊れても残骸として走り続ける
##   ・車両の絵は、上(画面の上)を向いている前提。下へ進むときは、上下を反転する
##   ・車両の絵は、車体の真ん中が線路の真ん中に来るように、Sprite2D の Offset で合わせておく
##     (Small Train の絵は、右に影があるので Offset (3.5, 0))
##   ・向きは線路で決まる(Direction By Rail): 束(2本並んだ線路)の、左(偶数の番号)は上へ、右(奇数)は下へ走る
##   ・同じ線路の列車とは重ならない。前の列車がまだ入口にいるあいだは、画面の外で待ってから出てくる
##   ・全部の車両を壊すと、列車ごと爆発してボーナスのスコアアイテムを落とす(Bonus Score)
##   ・hurry() で、急いで画面の外へ去る(中ボスの前に StageRunner が呼ぶ)
##
## 車両の並び: Cars の順に、先頭から並べる。足りない分は Cars の最後の車両を繰り返す。

signal finished(train : Train)

## 先頭から並べる車両のシーン(ルートが Enemy)
@export var cars : Array[PackedScene] = []
## 車両の数(Cars より多ければ、最後の車両を繰り返す)
@export var car_count : int = 5
## 走る線路(RailGround の rail_x の番号)。-1 なら、このノードの x のまま
@export var rail : int = 4
## 線路に沿った速さ(px/秒)。プラスで画面の上へ、マイナスで下へ進む。地面の流れ(下向き)に足される。
## Direction By Rail がオンなら、向き(符号)は線路で決まり、大きさだけを使う
@export var speed : float = 140.0
## オンなら、左の線路(偶数の番号)は上へ、右の線路(奇数)は下へ走る
@export var direction_by_rail : bool = true
## 0 より大きければ、下へ走る線路ではこの速さを使う(地面が下へ流れているぶん、下りは速く見えるので遅めにする)
@export var down_speed : float = 0.0
## 急いで去る(hurry)ときの速さの倍率と、その速さになるまでの時間(秒)
@export var hurry_multiplier : float = 4.0
@export var hurry_time : float = 1.2

@export_group("全車両撃破ボーナス")
## 全部の車両を壊したら、列車ごと爆発して、この点のスコアアイテムを落とす(0 ならなし)
@export var bonus_score : int = 3000
@export var bonus_items : int = 12
## 爆発を車両ごとに順に起こす間隔(秒)
@export var bonus_explosion_interval : float = 0.07
@export_group("")
## 同じ線路の前の列車との、最小の間隔(px)
@export var min_spacing : float = 60.0
## 車両と車両のすき間(px、ワールド)
@export var gap : float = 4.0
## 出てくる前に、画面の外のどれだけ先に置くか(px)
@export var enter_margin : float = 20.0
## 画面の外へこれだけ出たら消す(px)
@export var exit_margin : float = 60.0
## 車両に付ける tag(StageRunner の待機イベントが数える)
@export var tag : String = ""

var _cars : Array[Node2D] = []
var _length : float = 0.0
## 前の列車が入口からいなくなるのを待っている
var _held : bool = true
## 急いで去っているときの、速さの倍率
var _speed_scale : float = 1.0
var _bonus_done : bool = false
## 出した順番(同じ線路で待っている列車は、先に出したものから入る)
var _serial : int = 0
static var _next_serial : int = 0

func _ready() -> void:
	add_to_group("train")
	_next_serial += 1
	_serial = _next_serial
	if direction_by_rail and rail >= 0:
		var up := rail % 2 == 0
		var s := absf(speed) if up or down_speed <= 0.0 else down_speed
		speed = s * (1.0 if up else -1.0)
	_build()
	_place_at_start()

func _build() -> void:
	if cars.is_empty():
		push_warning("Train: Cars に車両がありません")
		return
	var runner := get_tree().get_first_node_in_group("stage_runner") as StageRunner
	var down := speed < 0.0
	var y := 0.0
	for i in maxi(car_count, 1):
		var scene : PackedScene = cars[mini(i, cars.size() - 1)]
		var car := scene.instantiate() as Node2D
		if car == null:
			continue
		if car is Enemy:
			(car as Enemy).pattern = null # 列車が動かすので、移動パターンは使わない
		add_child(car)
		var h := _car_height(car)
		# 先頭が進む向きの端になるように並べる(上へ進むなら、先頭がいちばん上)
		var center := y + h * 0.5
		car.position = Vector2(0.0, center if not down else -center)
		if down:
			for sprite in car.find_children("*", "Sprite2D", true, false):
				(sprite as Sprite2D).flip_v = not (sprite as Sprite2D).flip_v
		y += h + gap
		_cars.append(car)
		if runner and tag != "":
			runner.register_tag(car, tag)
	_length = maxf(y - gap, 0.0)

## 車両の縦の長さ(ワールド)。Sprite2D の見た目から測る
func _car_height(car : Node2D) -> float:
	var sprite := car.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or sprite.texture == null:
		return 60.0
	return sprite.get_rect().size.y * absf(sprite.scale.y * car.scale.y)

## 画面の上で動く向きの手前、画面の外に置く(上へ動くなら画面の下の外、下へ動くなら上の外)
func _place_at_start() -> void:
	var ground := RailGround.of(self)
	if ground and rail >= 0:
		global_position.x = ground.rail_x(rail)
	var view := CameraView.visible_rect(self)
	var extent := _extent()
	if _net_speed() < 0.0:
		global_position.y = view.end.y + enter_margin - extent.x
	else:
		global_position.y = view.position.y - enter_margin - extent.y

## 列車の上の端と下の端(このノードからの y)。先頭が y = 0
func _extent() -> Vector2:
	return Vector2(0.0, _length) if speed >= 0.0 else Vector2(-_length, 0.0)

## 画面の上での縦の速さ(プラスで下へ)
func _net_speed() -> float:
	var ground := RailGround.of(self)
	return (ground.current_speed if ground else 0.0) - speed * _speed_scale

## 同じ線路で、先に出た列車と重ならないか(入口に置いたまま調べる)
func _rail_clear() -> bool:
	var extent := _extent()
	var my_top := global_position.y + extent.x - min_spacing
	var my_bottom := global_position.y + extent.y + min_spacing
	for node in get_tree().get_nodes_in_group("train"):
		var other := node as Train
		if other == null or other == self or other.rail != rail:
			continue
		if other._held and other._serial > _serial:
			continue # 後から来て待っている列車は気にしない
		if other._held:
			return false # 先に来た列車が、まだ待っている
		var e := other._extent()
		var top := other.global_position.y + e.x
		var bottom := other.global_position.y + e.y
		if bottom > my_top and top < my_bottom:
			return false
	return true

func _physics_process(delta : float) -> void:
	if _held:
		if not _rail_clear():
			return
		_held = false
	var net := _net_speed()
	global_position.y += net * delta
	_cars = _cars.filter(func(c : Node2D) -> bool: return is_instance_valid(c))
	if _cars.is_empty():
		_finish()
		return
	if not _bonus_done and bonus_score > 0 and alive_cars() == 0:
		_bonus_done = true
		_explode_all()
	# 画面の外へ出きったら消す
	var view := CameraView.visible_rect(self)
	var extent := _extent()
	var top := global_position.y + extent.x
	var bottom := global_position.y + extent.y
	# 縦だけで見る(横の別の画面の線路を走っていても、通り過ぎたら消える)
	if (net < 0.0 and bottom < view.position.y - exit_margin) or (net > 0.0 and top > view.end.y + exit_margin):
		_finish()

## 壊れていない車両の数
func alive_cars() -> int:
	return _cars.filter(func(c : Node2D) -> bool: return is_instance_valid(c) and not (c is Enemy and (c as Enemy).is_wreck())).size()

## 中ボスが来る前などに、急いで画面の外へ去る(速さを上げる)。まだ入ってきていない列車は、そのまま消える
func hurry() -> void:
	if _held:
		_finish()
		return
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "_speed_scale", hurry_multiplier, hurry_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## 全部の車両を壊した: 前から順に爆発して、まん中あたりにボーナスのスコアアイテムを落とす。
## 車両は消さずに、残骸のまま走り去る
func _explode_all() -> void:
	var tree := get_tree()
	var view := CameraView.visible_rect(self)
	var on_screen : Array[Vector2] = []
	var order := _cars.duplicate()
	if speed < 0.0:
		order.reverse() # 画面の上の車両から
	for car in order:
		if not is_instance_valid(car):
			continue
		if view.has_point(car.global_position):
			on_screen.append(car.global_position)
		Explosion.spawn(tree, Explosion.EXPLOSIVE, car.global_position, 1.8)
		Explosion.spawn(tree, Explosion.ZAKO, car.global_position + Vector2(randf_range(-20, 20), randf_range(-40, 40)), 1.2)
		var death := DeathExplosion.of(car)
		if death and death.sound:
			SoundManager.play(death.sound, randf_range(0.8, 0.95))
		# 光るだけで、消さない(残骸のまま走り去る)
		var flash : Tween = (car as Node2D).create_tween()
		var after : Color = car.modulate
		flash.tween_property(car, "modulate", Color(2.5, 2.0, 1.6, 1.0), 0.06)
		flash.tween_property(car, "modulate", after, 0.3)
		await tree.create_timer(bonus_explosion_interval, false).timeout
		if not is_inside_tree():
			return
	# ボーナス: 画面に見えていた車両のまん中に落とす(見えていなければ、画面の端の近く)
	var at := global_position
	if not on_screen.is_empty():
		at = Vector2.ZERO
		for p in on_screen:
			at += p
		at /= on_screen.size()
	at = at.clamp(view.position + Vector2(40, 60), view.end - Vector2(40, 60))
	var score_system := tree.get_first_node_in_group("score_system") as ScoreSystem
	if score_system:
		score_system.spawn_items(at, bonus_score, bonus_items, 1.4)
	FloatingText.spawn(tree, at, "全車両撃破 +%d" % bonus_score)
	# 列車はそのまま、残骸として画面の外へ走り去る

func _finish() -> void:
	set_physics_process(false)
	finished.emit(self)
	queue_free()
