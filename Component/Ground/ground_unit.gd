extends Node
class_name GroundUnit
## 地上の敵の部品。敵(Enemy)の子に置く。
##   ・背景(地面)に乗って一緒に流れる。背景のスクロールや横揺れ(BackgroundSway)にもついていく
##   ・地面の上を、決めた向きと速さで走る(走っている間だけ、履帯の絵を切り替える)
##   ・前に障害物(建物・貨車など、"ground_obstacle" グループの絵)があると、曲がってよける
##   ・決めた時間だけ走って止まり、止まってから撃ち始める(迎え撃つ)こともできる
##   ・屋根(障害物)の下に入っている間は、自機の弾が当たらず、撃ってもこない(見えない敵に撃たれないように)
##   ・倒されると、残骸を地面に置いていく(残骸は背景と一緒に流れて、しばらくして消える)
##   ・画面の下へ流れきったら消える
##
## 敵シーン側の決まりごと:
##   ・Enemy の Pattern は空にする(移動パターンを使うと、地面に乗れない)。SpawnEvent の Move Pattern も空にする
##   ・出現位置は Spawn X(画面の横位置)。SpawnEvent の Offset / Offset Step / Mirror X もそのまま効く
##   ・絵の Z Index は 0 のままにする
##
## ステージのシーン側の決まりごと(重なり順: 地面 < 残骸 < 地上の敵 < 屋根(建物) < 空中の敵):
##   ・地面の絵(背景の下の層)を "ground" グループに入れる。残骸はその子になる
##   ・Scroller の子の、地面の絵と屋根の絵(上の層)のあいだに Node2D を置き、"ground_layer" グループに入れる。
##     地上の敵は StageRunner がそこに出すので、地面より上・屋根より下に描かれる(建物の下をくぐる)
##   ・グループが見つからなければ、"background_scroller"(Scroller)に乗り、移動はしない
##   ・よけさせたい絵(屋根の層、自分で置いた物)を "ground_obstacle" グループに入れる(GroundObstacles を参照)
##
## 戦車隊を斜めに並べて迎え撃たせる例(SpawnEvent):
##   Count 5 / Interval 0 / Offset (-160, 0) / Offset Step (80, -50)
##     → 1両ごとに右へ 80px・上へ 50px ずれて、斜めの列で出てくる
##   敵シーン(tank_squad.tscn): Drive Time 1.6 / Fire Only When Stopped オン
##     → 列のまま走って止まり、そこから一斉に撃ち始める

## 地面にするノード。空なら "ground" グループのノード
@export var ground_path : NodePath
## 出現する横の位置(画面の座標。480 幅の真ん中が 240)
@export var spawn_x : float = 240.0
## 画面の上の端から、どれだけ外に出すか(px)
@export var spawn_margin : float = 40.0

@export_group("走る")
## 地面に対する速さ(px/秒)。0 なら止まったまま(砲台)。背景と一緒に流れるのは別
@export var drive_speed : float = 0.0
## 走る向き(度)。0 で画面の下、90 で左、-90 で右(Mirror X のときは左右が逆になる)
@export var drive_angle_deg : float = 0.0
## 出てから走り始めるまでの時間と、走る時間(秒)。走る時間 0 ならずっと走る
@export var drive_delay : float = 0.0
@export var drive_time : float = 0.0
## 止まったあと、また走り出すまでの時間(秒)。0 なら止まったまま(Drive Time が 0 より大きいとき)
@export var resume_after : float = 0.0
## 走る向きへ向きを変える車体(空なら向きを変えない)と、車体の絵の前の向き(度。0 で絵の下が前)
@export var body : Node2D
@export var body_forward_deg : float = 0.0
## 走っている間だけ、Body(Sprite2D)の Texture を順番に切り替える(履帯の動き)。1秒あたりの枚数
@export var drive_textures : Array[Texture2D] = []
@export var drive_anim_fps : float = 10.0

@export_group("撃ち方")
## オンにすると、走っている間は撃たず、止まってから撃ち始める(弾幕は止まった時から数え直す)。
## 列で止まると一斉に撃つので「迎え撃つ」形になる
@export var fire_only_when_stopped : bool = false
## 撃ち始めをばらす時間(秒)。0〜この値のあいだでランダムに遅らせる(一斉射撃を少しばらしたいとき)
@export var fire_jitter : float = 0.0
## 画面の上の端から、画面の高さのこの割合より下へ流れたら、撃つのをやめる(自機の横や下から撃たれないように)。0 なら、ずっと撃つ
@export_range(0.0, 1.0, 0.05) var cease_fire_below : float = 0.6

@export_group("障害物をよける")
## オンにすると、前に障害物があれば曲がってよける
@export var avoid_obstacles : bool = true
## どれだけ先を見るか(px)と、左右の確認の幅(px)。車体の大きさに合わせる
@export var look_ahead : float = 30.0
@export var probe_width : float = 12.0
## 曲がる速さ(度/秒)
@export var steer_speed : float = 160.0
## 両方空いているときに、どちらへ曲がるか(オンで右。Mirror X のときは逆)
@export var prefer_right : bool = true
## この不透明さ以上の所を障害物とみなす(影を通れるようにしたいときは上げる)
@export_range(0.0, 1.0, 0.05) var obstacle_alpha : float = 0.6
## 屋根(障害物)の下にいる間は、弾が当たらず、撃たない
@export var hide_under_roof : bool = true
## オンなら、屋根(障害物)と重なる場所には出現せず、止まらない:
##   ・出現する場所が屋根なら、その高さで空いている一番近い横の位置へずらす
##   ・止まる時間になっても屋根の下なら、屋根を抜けるまで走り続ける
@export var keep_off_roof : bool = true

@export_group("重ならない")
## 車体の半径(px、画面の上での大きさ)。0 より大きければ、ほかの地上の敵と重ならないようにする:
##   ・出現する場所に、ほかの地上の敵がいれば、空いている横の位置へずらす
##   ・近づきすぎたら、離れる向きへ少しずつよける
@export var body_radius : float = 0.0
## オンなら、近づきすぎたときに自分がよける。オフなら動かない(重戦車・砲台など。相手がよける)
@export var yield_to_others : bool = true
## よける速さ(px/秒)
@export var separate_speed : float = 90.0

@export_group("残骸")
## 倒されたときに地面に残す絵。空なら残さない
@export var wreck_texture : Texture2D
## 残骸が消えるまでの時間(秒)
@export var wreck_life : float = 15.0
## 残骸の暗さ(1 でそのまま)
@export var wreck_tint : Color = Color(0.8, 0.8, 0.8)

## 画面の下の端から、これだけ外に出たら消える(px)
@export var free_margin : float = 80.0

var _enemy : Enemy
var _ground : Node2D
var _local : Vector2 # 地面のノードの中での位置
var _age : float = 0.0
var _anim_time : float = 0.0
var _anim_index : int = 0
var _dead : bool = false
var _heading : Vector2 = Vector2.DOWN # 今走っている向き(よけている間は Drive Angle からずれる)
var _was_driving : bool = false
var _shooters : Array[EnemyShooter] = []
var _firing : bool = true # 撃ち方(止まったら撃つ)で決まる、撃ってよいか
var _under_roof : bool = false
var _too_low : bool = false # 画面の下のほうまで流れたので、撃つのをやめた

func _ready() -> void:
	_enemy = get_parent() as Enemy
	add_to_group(&"ground_unit")
	if _enemy == null:
		push_warning("GroundUnit: 親が Enemy ではありません")
		return
	process_priority = 100 # 背景が動いたあとで、位置を合わせる(ずれて見えないように)
	var root := get_tree().current_scene
	if root and not ground_path.is_empty():
		_ground = root.get_node_or_null(ground_path) as Node2D
	if _ground == null:
		_ground = get_tree().get_first_node_in_group("ground") as Node2D
	if _ground == null:
		_ground = get_tree().get_first_node_in_group("background_scroller") as Node2D
	_heading = _drive_direction()
	_place_at_spawn()
	_enemy.died.connect(_on_died)
	for node in _enemy.find_children("*", "", true, false):
		if node is EnemyShooter:
			_shooters.append(node)
	if fire_only_when_stopped and drive_speed > 0.0:
		_set_firing(false)

## GroundUnit を持つ(地上の)敵か。StageRunner が、出現させる親を "ground_layer" にするのに使う
static func is_ground(enemy : Node) -> bool:
	for child in enemy.get_children():
		if child is GroundUnit:
			return true
	return false

## 画面の上の外に置く(Enemy の Mirror X と Path Offset を使う)
func _place_at_spawn() -> void:
	var area := CameraView.visible_rect(_enemy)
	var x := spawn_x
	if _enemy.mirror_x:
		x = area.position.x * 2.0 + area.size.x - x
	_enemy.global_position = Vector2(x, area.position.y - spawn_margin) + _enemy.path_offset
	if avoid_obstacles or keep_off_roof:
		_enemy.global_position = _nearest_free(_enemy.global_position)
	if _ground:
		_local = _ground.to_local(_enemy.global_position)
	if body and drive_speed > 0.0:
		body.global_rotation = _heading.angle() - PI * 0.5 - deg_to_rad(body_forward_deg)

## 出現位置が建物の上なら、左右の近い空いている所へずらす(見つからなければそのまま)
func _nearest_free(pos : Vector2) -> Vector2:
	var tree := get_tree()
	if not _spot_blocked(pos):
		return pos
	# いつもは 40px まで。Keep Off Roof なら、画面の幅いっぱいまで探す
	var max_step := 6
	if keep_off_roof:
		max_step = ceili(CameraView.visible_rect(_enemy).size.x / 8.0)
	var area := CameraView.visible_rect(_enemy)
	for step in range(1, max_step):
		for sign in [-1.0, 1.0]:
			var candidate := pos + Vector2(sign * step * 8.0, 0.0)
			if candidate.x < area.position.x + 16.0 or candidate.x > area.end.x - 16.0:
				continue # 画面の外へは、ずらさない
			if not _spot_blocked(candidate):
				return candidate
	return pos

func _drive_direction() -> Vector2:
	var angle := deg_to_rad(drive_angle_deg)
	if _enemy.mirror_x:
		angle = -angle
	return Vector2.DOWN.rotated(angle)

func _process(delta : float) -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		return
	_age += delta
	var driving := not _dead and _is_drive_time()
	if not driving and not _dead and keep_off_roof and drive_speed > 0.0 and _age >= drive_delay \
			and _spot_blocked(_enemy.global_position):
		driving = true # 止まる時間だが、屋根の下: 抜けるまで走り続ける
	var speed := 0.0
	if driving:
		speed = _steer(delta)
	if _ground:
		if speed > 0.0:
			# 画面の上での速さを、地面のノードの中の長さに直して足す
			var step := _heading * speed * delta
			_local += _ground.global_transform.affine_inverse().basis_xform(step)
		_enemy.global_position = _ground.to_global(_local)
	elif speed > 0.0:
		_enemy.global_position += _heading * speed * delta
	if body_radius > 0.0 and yield_to_others and not _dead:
		_separate(delta)
	if speed > 0.0:
		_animate_treads(delta)
		_face_body(delta)
	if fire_only_when_stopped and drive_speed > 0.0 and not _dead and driving != _was_driving:
		_set_firing(not driving)
	_was_driving = driving
	if hide_under_roof and not _dead:
		var roof := GroundObstacles.is_blocked(get_tree(), _enemy.global_position, obstacle_alpha)
		if roof != _under_roof:
			_set_under_roof(roof)
	var area := CameraView.visible_rect(_enemy)
	if cease_fire_below > 0.0 and not _dead:
		var low := _enemy.global_position.y > area.position.y + area.size.y * cease_fire_below
		if low != _too_low:
			_too_low = low
			_update_shooters()
	if _enemy.global_position.y > area.end.y + free_margin:
		_enemy.queue_free()

## 今が走る時間か(Drive Delay → Drive Time 走る → Resume After 止まる → また走る…)
func _is_drive_time() -> bool:
	if drive_speed <= 0.0 or _age < drive_delay:
		return false
	if drive_time <= 0.0:
		return true
	var t := _age - drive_delay
	if resume_after <= 0.0:
		return t < drive_time
	return fmod(t, drive_time + resume_after) < drive_time

## 前を見て、障害物があれば曲がる。今の速さを返す(曲がっている間は遅くなる。行き場がなければ 0)
func _steer(delta : float) -> float:
	var wanted := _drive_direction()
	if not avoid_obstacles:
		_heading = wanted
		return drive_speed
	var target := _heading
	if _ahead_blocked(_heading):
		target = _find_clear(_heading)
		if target == Vector2.ZERO:
			return 0.0 # 囲まれている: その場で待つ
	elif not _heading.is_equal_approx(wanted) and not _ahead_blocked(wanted):
		target = wanted # よけ終わったら、元の向きへ戻る
	var max_turn := deg_to_rad(steer_speed) * delta
	_heading = _heading.rotated(clampf(_heading.angle_to(target), -max_turn, max_turn))
	# 大きく曲がっている途中は減速する
	var turn := absf(_heading.angle_to(target))
	return drive_speed * clampf(cos(turn), 0.3, 1.0)

## 空いている向きを、今の向きに近い順に探す(右か左かは Prefer Right)
func _find_clear(from : Vector2) -> Vector2:
	var side := 1.0 if prefer_right else -1.0
	if _enemy.mirror_x:
		side = -side
	# 下向きに走っているときの「右」(画面の左)は、角度プラス側。走る向きから見た右に曲がる
	for degree in [30.0, 60.0, 90.0, 120.0, 150.0]:
		for sign in [side, -side]:
			var candidate := from.rotated(deg_to_rad(degree * sign))
			if not _ahead_blocked(candidate):
				return candidate
	return Vector2.ZERO

func _ahead_blocked(direction : Vector2) -> bool:
	var tree := get_tree()
	var pos := _enemy.global_position
	if GroundObstacles.is_blocked(tree, pos, obstacle_alpha):
		return false # もう中にいる(出現位置が建物の上など): よけずに抜ける
	var ahead := pos + direction * look_ahead
	var side := direction.orthogonal() * probe_width
	if GroundObstacles.is_blocked(tree, ahead, obstacle_alpha):
		return true
	if GroundObstacles.is_blocked(tree, ahead + side, obstacle_alpha):
		return true
	return GroundObstacles.is_blocked(tree, ahead - side, obstacle_alpha)

## 車体を走る向きへ向ける
func _face_body(delta : float) -> void:
	if body == null:
		return
	var wanted := _heading.angle() - PI * 0.5 - deg_to_rad(body_forward_deg)
	body.global_rotation = lerp_angle(body.global_rotation, wanted, 1.0 - exp(-10.0 * delta))

## 撃つ・撃たないを切り替える。撃ち始めるときは、弾幕を最初(Start Delay)から数え直す
func _set_firing(on : bool) -> void:
	_firing = on
	if on and fire_jitter > 0.0:
		await get_tree().create_timer(randf() * fire_jitter, false).timeout
		if _dead or not _firing:
			return
	for shooter in _shooters:
		if not is_instance_valid(shooter):
			continue
		shooter.enabled = on and not _under_roof and not _too_low
		if on:
			shooter.set_patterns(shooter.patterns)
		else:
			shooter.stop()

## 屋根の下に入った / 出た。下にいる間は弾が当たらず、撃たない
func _set_under_roof(on : bool) -> void:
	_under_roof = on
	if _enemy.hurtbox:
		_enemy.hurtbox.set_deferred("monitoring", not on)
		_enemy.hurtbox.set_deferred("monitorable", not on)
	_update_shooters()

func _animate_treads(delta : float) -> void:
	var sprite := body as Sprite2D
	if sprite == null or drive_textures.size() < 2:
		return
	_anim_time += delta
	if _anim_time >= 1.0 / maxf(drive_anim_fps, 0.1):
		_anim_time = 0.0
		_anim_index = (_anim_index + 1) % drive_textures.size()
		sprite.texture = drive_textures[_anim_index]

## 残骸を地面に置く(地面の子にするので、一緒に流れる)
func _on_died(_dead_enemy : Enemy) -> void:
	_dead = true # 爆発のあいだも地面には乗ったまま、走るのはやめる
	if wreck_texture == null:
		return
	var parent : Node2D = _ground if _ground else get_tree().current_scene as Node2D
	if parent == null:
		return
	var wreck := Sprite2D.new()
	wreck.texture = wreck_texture
	wreck.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wreck.modulate = wreck_tint
	parent.add_child(wreck)
	wreck.global_position = _enemy.global_position
	var shown : Node2D = body if body else _enemy
	wreck.global_rotation = shown.global_rotation
	wreck.global_scale = shown.global_scale # 背景が拡大されていても、敵と同じ大きさで残す
	get_tree().create_timer(wreck_life, false).timeout.connect(wreck.queue_free)

## 撃ってよいかを、砲口に伝える(撃ち方の都合・屋根の下・画面の下のほう、のどれかなら撃たない)
func _update_shooters() -> void:
	for shooter in _shooters:
		if is_instance_valid(shooter):
			shooter.enabled = _firing and not _under_roof and not _too_low

## pos に置いたとき、車体が屋根(障害物)に重なるか。Keep Off Roof なら、車体の幅(Probe Width)も見る
func _spot_blocked(pos : Vector2) -> bool:
	if _near_other(pos) != null:
		return true
	var tree := get_tree()
	if GroundObstacles.is_blocked(tree, pos, obstacle_alpha):
		return true
	if not keep_off_roof:
		return false
	for offset in [Vector2(probe_width, 0.0), Vector2(-probe_width, 0.0), Vector2(0.0, probe_width), Vector2(0.0, -probe_width)]:
		if GroundObstacles.is_blocked(tree, pos + offset, obstacle_alpha):
			return true
	return false

## pos に置いたとき、重なってしまう ほかの地上の敵(いなければ null)
func _near_other(pos : Vector2) -> GroundUnit:
	if body_radius <= 0.0:
		return null
	for node in get_tree().get_nodes_in_group(&"ground_unit"):
		var other := node as GroundUnit
		if other == null or other == self or other.body_radius <= 0.0 or other._dead:
			continue
		if not is_instance_valid(other._enemy):
			continue
		if pos.distance_to(other._enemy.global_position) < body_radius + other.body_radius:
			return other
	return null

## ほかの地上の敵に近づきすぎていたら、離れる向きへ少しよける(屋根の下へは、よけない)
func _separate(delta : float) -> void:
	var pos := _enemy.global_position
	var push := Vector2.ZERO
	for node in get_tree().get_nodes_in_group(&"ground_unit"):
		var other := node as GroundUnit
		if other == null or other == self or other.body_radius <= 0.0 or other._dead:
			continue
		if not is_instance_valid(other._enemy):
			continue
		var away := pos - other._enemy.global_position
		var gap := body_radius + other.body_radius - away.length()
		if gap <= 0.0:
			continue
		if away.length() < 0.5:
			away = Vector2.RIGHT.rotated(float(get_instance_id() % 628) / 100.0) # ぴったり重なったら、決まった向きへ
		# 相手もよけるなら半分ずつ、相手が動かないなら自分が全部よける
		push += away.normalized() * gap * (0.5 if other.yield_to_others else 1.0)
	if push == Vector2.ZERO:
		return
	var step := push.limit_length(separate_speed * delta)
	var target := pos + step
	if keep_off_roof and GroundObstacles.is_blocked(get_tree(), target, obstacle_alpha):
		return
	_enemy.global_position = target
	if _ground:
		_local = _ground.to_local(target)
