extends Hurtbox
class_name ArmorHurtbox
## 装甲の Hurtbox。反射弾(イグナイトで跳ね返した敵弾)のダメージだけを受けて、自機の通常ショットは弾く。
## 敵の Hurtbox のスクリプトを、これに差し替えて使う(子の CollisionShape2D と Timer はそのまま)。

## 通常ショットを弾いたときに出る
signal blocked(hitbox : Hitbox)

## 通常ショットのダメージの倍率。0 なら全く効かない
@export_range(0.0, 1.0, 0.05) var normal_damage_scale : float = 0.0
## true なら、弾いた通常ショットを消す(弾かれたのが分かるように)
@export var destroy_blocked_shots : bool = true
## 弾いたときに光らせるもの。空なら、親の Sprite2D
@export var flash_target : CanvasItem

var _flash_tween : Tween

func _apply_damage(hitbox : Hitbox) -> void:
	if hitbox == null:
		return
	if hitbox is EnemyBullet and hitbox.is_ignited():
		super(hitbox) # 反射弾はそのまま効く
		return
	if normal_damage_scale > 0.0:
		recieved_damage.emit(ceili(hitbox.damage * normal_damage_scale))
	blocked.emit(hitbox)
	_flash()
	if destroy_blocked_shots and hitbox is Bullet:
		hitbox.queue_free()

## 弾いたことが分かるように、青白く光らせる
func _flash() -> void:
	var target := flash_target
	if target == null and get_parent():
		target = get_parent().get_node_or_null("Sprite2D") as CanvasItem
	if target == null:
		return
	if _flash_tween and _flash_tween.is_running():
		return
	_flash_tween = create_tween()
	target.self_modulate = Color(0.6, 0.85, 1.6)
	_flash_tween.tween_property(target, "self_modulate", Color.WHITE, 0.12)
