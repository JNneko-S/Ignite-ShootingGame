extends RefCounted
## いま遊んでいるプラクティスのミッション(シーンを切り替えても残る)。
## begin() でステージを読み込み、ステージの中の PracticeDirector が、これを見てミッションを進める。

const PRACTICE_MENU := "res://GameScene/Practice/practice_menu.tscn"
## プラクティスの戦闘曲(どのミッションでも、これだけを流す)
const BATTLE_MUSIC := "res://Assets/Sounds/Music/AS_1746358_シューティング・近未来＿戦闘曲＿激しい_プラクティス.mp3"

static var active : bool = false
## ミッション(PracticeCatalog が作る辞書)
static var mission : Dictionary = {}
## 残機(0 がふつう。変えるとアシストクリア)と、プラクティス+(イグナイトなし)
static var lives : int = 0
static var plus : bool = false
## 一覧へ戻ったとき、同じ所を選ぶため
static var last_stage : int = 0
static var last_difficulty : int = 1
static var last_loop : int = 1
static var last_key : String = ""

## ミッションを始める(ステージのシーンへ)
static func begin(tree : SceneTree, m : Dictionary, start_lives : int, practice_plus : bool, ship : ShipData) -> void:
	active = true
	mission = m
	lives = start_lives
	plus = practice_plus
	last_key = m.get("key", "")
	RunConfig.has_selection = true
	RunConfig.difficulty = int(m["difficulty"])
	RunConfig.loop = int(m["loop"])
	RunConfig.continues_used = 1 # 二周目へは進まない
	RunConfig.consecutive_game_overs = 0
	if ship:
		RunConfig.ship = ship
	HazardRank.reset_run()
	StageBGM.override_music = load(BATTLE_MUSIC) as AudioStream
	HazardRank.carriers_off = str(m.get("kind", "")) != "zako" # ボスのミッションでは、ハザードキャリアを出さない
	if RunConfig.difficulty == 3 and RunConfig.loop >= 2:
		HazardRank.black_loop = true # 2nd ANOTHER は BLACK ANOTHER(ボス・中ボスは BLACK 用、雑魚は ANOTHER 用の弾幕)
	ScoreBoard.begin_run()
	DebugTools.pending_start_time = maxf(float(m.get("start_time", 0.0)), 0.1)
	DebugTools.skip_intro_once = true
	StageIntro.skip_next = true
	SceneSwitcher.change(str(m["scene"]))

## ミッションを終える(一覧へ戻る)
static func finish(tree : SceneTree) -> void:
	active = false
	StageBGM.override_music = null
	HazardRank.carriers_off = false
	RunConfig.loop = 1
	RunConfig.continues_used = 0
	Engine.time_scale = 1.0
	tree.paused = false
	SceneSwitcher.change(PRACTICE_MENU)

## タイトルなどへ戻った(ミッションを途中でやめた)
static func abort() -> void:
	active = false
	StageBGM.override_music = null
	HazardRank.carriers_off = false
	RunConfig.loop = 1
	RunConfig.continues_used = 0
