extends RefCounted
## プラクティスで「出すか・解禁するか」を決める、遊んだ記録の判定。
##   ・難易度の選択肢: ANOTHER は解禁しているときだけ。「2nd ○○」は、その難易度で二周目をクリアしたときだけ
##   ・裏ボス Union のミッション: 次を全部満たすと解禁(一覧の特別な枠に、達成状況を出す)
##       1. 実績を UNION_ACHIEVEMENTS 個以上解除している
##       2. スコアボードで、RATE A 以上を 3 回以上、または RATE S を 1 回以上取っている
##       3. ANOTHER を二周目までクリアしている(ANOTHER を解禁していないときは、条件も「？？？」)
##       4. 次のどちらか: A. イグナイトだけでゲームをクリアする(難易度は問わない)
##                         B. 各機体で1回ずつ、NORMAL 以上でゲームをクリアする
## 記録は、実績の進み具合(Achievements)と、スコアボードの記録(ScoreBoard)の両方から数える(前のプレイの分も拾うため)。
## デバッグ機能が使えるときは、難易度の選択肢を全部出す

const UNION_ACHIEVEMENTS := 20
const UNION_RATE_A := 3
const UNION_RATE_S := 1
const IGNITE_ONLY := ["ignite_only_vespa", "ignite_only_bastion", "ignite_only_phoenix"]

## 難易度の選択肢(選んだ難易度, 周回)を出すか
static func mode_visible(difficulty : int, loop : int) -> bool:
	if DebugTools.unlocked:
		return true
	if difficulty == 3:
		return Achievements.another_unlocked
	if loop >= 2:
		if difficulty in Achievements.loop2_cleared:
			return true
		for e in ScoreBoard.load_entries():
			if int(e.get("loop", 1)) >= 2 and bool(e.get("cleared", false)) and int(e.get("difficulty", -1)) == difficulty:
				return true
		return false
	return true

## Union のミッションの解禁条件と、達成状況。[{ "text", "done", "hidden" }](4 つ目には "sub" に A・B)
static func union_conditions(ships : Array) -> Array:
	var entries := ScoreBoard.load_entries()
	var a_count := Achievements.rate_a_count
	var s_count := Achievements.rate_s_count
	var s_seen := 0
	var a_seen := 0
	for e in entries:
		var g := ScoreBoard.grade(e)
		if g == "S":
			s_seen += 1
		if g == "S" or g == "A":
			a_seen += 1
	a_count = maxi(a_count, a_seen)
	s_count = maxi(s_count, s_seen)
	var another_done := Achievements.another_loop2_cleared
	for e in entries:
		if int(e.get("difficulty", 0)) == 3 and int(e.get("loop", 1)) >= 2 and bool(e.get("cleared", false)):
			another_done = true
	var ignite_only := false
	for id in IGNITE_ONLY:
		if Achievements.is_unlocked(id):
			ignite_only = true
	var cleared_ships : Array = Achievements.ships_cleared.duplicate()
	for e in entries:
		if bool(e.get("cleared", false)) and int(e.get("difficulty", 0)) >= 1 and not str(e.get("ship", "")) in cleared_ships:
			cleared_ships.append(str(e.get("ship", "")))
	var ship_names : Array = []
	for s in ships:
		if s:
			ship_names.append(s.ship_name)
	var all_ships := not ship_names.is_empty()
	var ships_done := 0
	for n in ship_names:
		if n in cleared_ships:
			ships_done += 1
		else:
			all_ships = false
	var count := Achievements.unlocked_count()
	return [
		{"text": "実績を %d 個以上解除する  (%d / %d)" % [UNION_ACHIEVEMENTS, mini(count, UNION_ACHIEVEMENTS), UNION_ACHIEVEMENTS],
			"done": count >= UNION_ACHIEVEMENTS, "hidden": false},
		{"text": "RATE A を %d 回以上か、RATE S を %d 回以上取る  (A %d / S %d)" % [UNION_RATE_A, UNION_RATE_S, a_count, s_count],
			"done": a_count >= UNION_RATE_A or s_count >= UNION_RATE_S, "hidden": false},
		{"text": "ANOTHER を二周目までクリアする", "done": another_done, "hidden": not Achievements.another_unlocked},
		{"text": "次のどちらかを達成する", "done": ignite_only or all_ships, "hidden": false,
			"sub": [
				{"text": "A. イグナイトだけでゲームをクリアする", "done": ignite_only},
				{"text": "B. 各機体で NORMAL 以上をクリアする  (%d / %d)" % [ships_done, ship_names.size()], "done": all_ships},
			]},
	]

## Union のミッションを解禁しているか
static func union_unlocked(ships : Array) -> bool:
	for c in union_conditions(ships):
		if not c["done"]:
			return false
	return true
