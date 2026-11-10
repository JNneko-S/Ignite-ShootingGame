extends Hitbox
class_name ContactHitbox
## 触れているあいだ当たり続ける Hitbox(ボスの体当たり・噴射の炎など)。
## 子の CollisionShape2D が全部、当たりの形になる(1つは "CollisionShape2D" という名前にしておく)。
## Active を切り替えると、全ての形が一緒に入/切される。
## 触れたままでも、自機の無敵が切れたらまた当たる。
## 敵の弾ではないので、Damage Source Type を Trap にすると、グレイズにならず、イグナイトでも消えない。

## はじめから当たるか(ボスの技で使うときは、オフにしておいて、技の間だけ部品がオンにする)
@export var start_active : bool = true
## 触れ続けているときに、何秒ごとに当てるか
@export var hit_interval : float = 0.1

var _active : bool = false
var _hit_timer : float = 0.0

var _applied : bool = false

func _ready() -> void:
	set_active(start_active)

## 当たりを入/切する
func set_active(on : bool) -> void:
	if on == _active and _applied:
		return
	_active = on
	_applied = true
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", not on)

func is_hitting() -> bool:
	return _active

func _physics_process(delta : float) -> void:
	_hit_timer -= delta
	if not _active or _hit_timer > 0.0:
		return
	_hit_timer = hit_interval
	for area in get_overlapping_areas():
		if area is Hurtbox:
			area._apply_damage(self)
