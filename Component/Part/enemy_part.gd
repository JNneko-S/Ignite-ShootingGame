extends Node2D
class_name EnemyPart
## 敵の部位(分離型の中ボスの砲台など)。自分の HP を持ち、壊れると、その部位の砲口(EnemyShooter)が止まる。
##
## 使い方:
##   敵のシーンに Node2D を追加して、このスクリプトをアタッチする。子に次を置く
##     ・Hurtbox(Hurtbox か ArmorHurtbox。子に CollisionShape2D と Timer)
##     ・EnemyShooter(この部位の砲口。いくつでも)
##     ・Sprite2D(見た目。壊れると暗くなって消える)

signal destroyed(part : EnemyPart)

@export var max_hp : int = 40
## 部位が受けたダメージのうち、この割合を本体(Enemy の HPComponent)にも与える
@export_range(0.0, 1.0, 0.05) var damage_to_body : float = 0.25

var hp : int = 0
var _destroyed : bool = false
var _flash_tween : Tween

func _ready() -> void:
	hp = max_hp
	for node in find_children("*", "Area2D", true, false):
		if node is Hurtbox:
			node.recieved_damage.connect(_on_damage)
			if not node.area_entered.is_connected(node._on_area_entered):
				node.area_entered.connect(node._on_area_entered)

func is_destroyed() -> bool:
	return _destroyed

func _on_damage(damage : float, _knockback_dir : Vector2 = Vector2.ZERO) -> void:
	if _destroyed:
		return
	hp -= ceili(damage)
	var body := _body()
	if body and damage_to_body > 0.0:
		body.hp_component.apply_damage(ceili(damage * damage_to_body))
	if hp <= 0:
		_destroy()
	else:
		_flash()

func _destroy() -> void:
	_destroyed = true
	for node in find_children("*", "", true, false):
		if node is EnemyShooter:
			node.enabled = false
			node.stop()
		elif node is Hurtbox:
			node.set_deferred("monitoring", false)
			node.set_deferred("monitorable", false)
	destroyed.emit(self)
	# 光ってから、暗くなって縮む
	var tween := create_tween()
	modulate = Color(2.0, 1.6, 1.2)
	tween.tween_property(self, "modulate", Color(0.35, 0.3, 0.3, 0.0), 0.5)
	tween.parallel().tween_property(self, "scale", scale * 0.6, 0.5)

func _flash() -> void:
	if _flash_tween and _flash_tween.is_running():
		return
	_flash_tween = create_tween()
	modulate = Color(1.8, 1.8, 1.8)
	_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.08)

func _body() -> Enemy:
	var node := get_parent()
	while node:
		if node is Enemy:
			return node
		node = node.get_parent()
	return null
