extends CanvasLayer
class_name DebugPanel
## デバッグパネル。GameManager がステージに1つ置く。
## ポーズ画面の隠しコマンドでデバッグ機能を解放すると(DebugTools.unlocked)、ゲーム中に F1 で開く / 閉じる。
## 開いているあいだ、数字のキーで機能を使う。一度でも使ったプレイは、ハイスコアを保存しない。
##   1 無敵 / 2 イグナイト Lv+1 / 3 Lv-1 / 4 全部最大(ゲージ・子機・ロック速度)
##   5 中ボスへ / 6 ボスへ(ステージを読み直して、その少し前から。出撃の演出はしない)
##   7 ボスを次の形態へ(最後の形態なら倒す) / 8 スロー(1 → 0.5 → 0.25) / 9 当たり判定の表示
##   0 画面の弾を消す / - 画面の雑魚を倒す / P 次のステージへ(点数・残機・ゲージなどを持ち越して、霧を抜けて入る)
## パネルには、FPS・弾と敵の数・ステージの時間・ボスの HP などを出し続ける。

## ジャンプしたときに、中ボス・ボスが出る何秒前から始めるか
const JUMP_LEAD : float = 2.0
const SLOW_STEPS : Array[float] = [1.0, 0.5, 0.25]

var game_manager : GameManager
var _box : ColorRect
var _label : Label
var _slow_index : int = 0
var _message : String = ""
var _message_left : float = 0.0

func _ready() -> void:
	layer = 70 # ポーズ画面(80)より奥
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_box = ColorRect.new()
	_box.color = Color(0.0, 0.03, 0.06, 0.78)
	_box.position = Vector2(4, 64)
	_box.size = Vector2(178, 262)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	_label = Label.new()
	_label.position = Vector2(8, 4)
	_label.size = Vector2(166, 242)
	var settings := LabelSettings.new()
	settings.font_size = 8
	settings.font_color = Color(0.75, 1.0, 0.8)
	settings.line_spacing = 0.0
	settings.outline_size = 2
	settings.outline_color = Color.BLACK
	_label.label_settings = settings
	_box.add_child(_label)

func _input(event : InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not DebugTools.unlocked:
		return
	if key.keycode == KEY_F1 and not key.shift_pressed:
		if get_tree().paused and not visible:
			return # ポーズ中(隠しコマンドの入力中も)は開かない
		visible = not visible
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	var viewport := get_viewport() # ジャンプでシーンを読み直すと、このあと取れなくなるので先に取る
	var handled := true
	match key.keycode:
		KEY_1: _toggle_invincible()
		KEY_2: _change_level(1)
		KEY_3: _change_level(-1)
		KEY_4: _max_all()
		KEY_5: _jump(false)
		KEY_6: _jump(true)
		KEY_7: _next_boss_phase()
		KEY_8: _toggle_slow()
		KEY_9: _toggle_hitboxes()
		KEY_0: _clear_bullets()
		KEY_MINUS: _kill_zako()
		KEY_P: _next_stage()
		_: handled = false
	if handled and viewport:
		viewport.set_input_as_handled()

func _process(delta : float) -> void:
	if _message_left > 0.0:
		_message_left -= delta
	if visible:
		_label.text = _build_text()

func _say(text : String) -> void:
	_message = text
	_message_left = 1.5
	DebugTools.used = true

func _build_text() -> String:
	var lines : PackedStringArray = ["== DEBUG (F1) =="]
	lines.append("1 無敵: %s" % ("ON" if DebugTools.invincible else "OFF"))
	lines.append("2/3 イグナイト Lv +1 / -1")
	lines.append("4 全部最大(ゲージ・子機・ロック)")
	lines.append("5 中ボスへ  6 ボスへ")
	lines.append("7 ボスを次の形態へ")
	lines.append("8 スロー: x%.2f" % SLOW_STEPS[_slow_index])
	lines.append("9 当たり判定: %s" % ("ON" if get_tree().debug_collisions_hint else "OFF"))
	lines.append("0 弾消し  - 雑魚を倒す")
	lines.append("P 次のステージへ")
	lines.append("")
	lines.append("FPS %d  弾 %d  敵 %d" % [Engine.get_frames_per_second(),
		get_tree().get_nodes_in_group("enemy_bullet").size(), get_tree().get_nodes_in_group("enemy").size()])
	var runner := _runner()
	if runner:
		lines.append("時間 %.1f 秒  スクロール x%.2f" % [runner.stage_time, runner.scroll_multiplier])
	if game_manager:
		var gauge := game_manager.ignite
		lines.append("イグナイト Lv%d (%d%%)" % [gauge.level, roundi(gauge.ratio() * 100.0)])
		var player := game_manager.player
		if is_instance_valid(player):
			lines.append("残機 %d  子機 %d  ロック %d" % [player.lives, player.options.size(), player.lock_speed_level])
	var boss := _boss()
	if boss:
		var controller := _controller(boss)
		var phase := controller.current_phase() + 1 if controller else 1
		lines.append("ボス HP %d / %d (%d%%)  形態 %d" % [boss.hp_component.hp, boss.hp_component.max_hp,
			roundi(100.0 * boss.hp_component.hp / maxf(boss.hp_component.max_hp, 1.0)), phase])
	if DebugTools.used:
		lines.append("(ハイスコアは保存しない)")
	if _message_left > 0.0:
		lines.append("> " + _message)
	return "\n".join(lines)

# ---------------------------------------------------------------- 機能

func _toggle_invincible() -> void:
	DebugTools.invincible = not DebugTools.invincible
	_say("無敵 " + ("ON" if DebugTools.invincible else "OFF"))

func _change_level(step : int) -> void:
	if game_manager == null:
		return
	var gauge := game_manager.ignite
	var level := clampi(gauge.level + step, IgniteGauge.MIN_LEVEL, IgniteGauge.MAX_LEVEL)
	gauge.value = gauge.threshold(level) + (0.01 if level < IgniteGauge.MAX_LEVEL else 0.0)
	gauge._update(true)
	_say("イグナイト Lv%d" % gauge.level)

func _max_all() -> void:
	if game_manager == null:
		return
	var gauge := game_manager.ignite
	gauge.value = gauge.max_value()
	gauge._update(true)
	var player := game_manager.player
	if is_instance_valid(player):
		while player.add_option():
			pass
		while player.upgrade_lock_speed():
			pass
	_say("全部最大")

## ステージを読み直して、中ボス(boss が false)かボスが出る少し前から始める
func _jump(boss : bool) -> void:
	var runner := _runner()
	if runner == null or runner.stage == null:
		return
	var time := -1.0
	for event in runner.stage.events:
		if event is SpawnEvent and event.is_boss and event.boss_time_bonus == boss:
			if time < 0.0 or event.time < time:
				time = event.time
	if time < 0.0:
		_say("見つかりません")
		return
	DebugTools.used = true
	DebugTools.pending_start_time = maxf(time - JUMP_LEAD, 0.1)
	DebugTools.skip_intro_once = true
	Engine.time_scale = 1.0 # 読み直すと、パネルのスローの表示も 1 倍に戻るので、合わせる
	get_tree().paused = false
	get_tree().reload_current_scene()

## 次のステージへ(StageTransition の Next Stage)。今の状態を持ち越して、霧の中から始める
func _next_stage() -> void:
	var scene := get_tree().current_scene
	var next := ""
	if scene:
		for node in scene.find_children("*", "", true, false):
			if node is StageTransition:
				next = node.next_stage
	if next == "":
		_say("次のステージがありません")
		return
	DebugTools.used = true
	Engine.time_scale = 1.0
	get_tree().paused = false
	StageCarry.save(get_tree())
	StageCarry.arriving = true
	StageCarry.cruise_height = 0.6
	SceneSwitcher.change(next)

func _next_boss_phase() -> void:
	var boss := _boss()
	if boss == null:
		_say("ボスがいません")
		return
	var hp := boss.hp_component
	var controller := _controller(boss)
	if controller and controller.current_phase() + 1 < controller.phases.size():
		var next := controller.phases[controller.current_phase() + 1]
		var target := maxi(int(hp.max_hp * next.hp_ratio) - 1, 1)
		if hp.hp > target:
			hp.apply_damage(hp.hp - target)
		_say("形態 %d へ" % (controller.current_phase() + 1))
		return
	# 最後の形態: 部位を全部壊して倒す
	var defeat := PartsDefeat.of(boss)
	if defeat:
		for part in defeat.parts:
			if is_instance_valid(part) and not part.is_destroyed():
				part._destroy()
	if hp.hp > 0:
		hp.apply_damage(hp.hp)
	_say("ボスを倒した")

func _toggle_slow() -> void:
	_slow_index = (_slow_index + 1) % SLOW_STEPS.size()
	Engine.time_scale = SLOW_STEPS[_slow_index]
	_say("スロー x%.2f" % SLOW_STEPS[_slow_index])

func _toggle_hitboxes() -> void:
	var tree := get_tree()
	tree.debug_collisions_hint = not tree.debug_collisions_hint
	for node in tree.root.find_children("*", "CollisionShape2D", true, false):
		node.queue_redraw()
	_say("当たり判定 " + ("ON" if tree.debug_collisions_hint else "OFF"))

func _clear_bullets() -> void:
	get_tree().call_group("enemy_bullet", "queue_free")
	_say("弾消し")

func _kill_zako() -> void:
	var count := 0
	var view := CameraView.visible_rect(game_manager)
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Enemy
		if enemy == null or enemy._is_dead or _controller(enemy) != null or not view.has_point(enemy.global_position):
			continue
		enemy.hp_component.apply_damage(enemy.hp_component.hp)
		count += 1
	_say("雑魚を %d 体倒した" % count)

# ---------------------------------------------------------------- 探す

func _runner() -> StageRunner:
	return get_tree().get_first_node_in_group("stage_runner") as StageRunner

## 今いるボス(いなければ中ボス)。段階のある敵
func _boss() -> Enemy:
	var found : Enemy = null
	for group in ["stage_boss", "stage_midboss"]:
		for node in get_tree().get_nodes_in_group(group):
			if node is Enemy and not node._is_dead:
				return node
	for node in get_tree().get_nodes_in_group("enemy"):
		if node is Enemy and not node._is_dead and _controller(node) != null:
			found = node
	return found

func _controller(enemy : Node) -> BossPhaseController:
	for child in enemy.get_children():
		if child is BossPhaseController:
			return child
	return null
