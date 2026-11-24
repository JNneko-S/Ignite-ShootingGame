"""All new barrages for this task. Run: python barrages.py  (writes the .tres files)."""
import sys
sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__)))
from shotgen import P, S, write

EX = "res://Resources/ShotPatterns/Exclusive/"
FIN = "res://Resources/ShotPatterns/Stage4/Final/"
GD = "res://Resources/ShotPatterns/Stage4/Guard/"
BS = "res://Resources/ShotPatterns/Stage4/BloodSwan/"
WG = "res://Resources/ShotPatterns/Stage4/Wagon/"

EASY, NORMAL, HARD = 0, 1, 2


def only(level, **kw):
    """限定弾幕(選んだ難易度が level のときだけ撃つ。自動の調整はしない)"""
    return dict(min_difficulty=level, max_difficulty=level, skip_auto_tuning=True, **kw)


ALL = {}


def reg(path, p):
    ALL[path] = p
    return path


# =============================================================== 限定弾幕: ボス

# --- EASY: 流星群(1面ボス)。画面の上から大きな隕石が落ちてきて、真ん中あたりでゆっくり砕ける
reg(EX + "ex_e_meteor_shower.tres", P(
    bullet="E_Spiky_Split", **only(EASY),
    start_delay=0.6, shot_count=3, interval=0.85, pause=2.2,
    bullet_count=7, parallel_spacing=64.0, aim_at_player=False, from_screen_top=True,
    gap_size=5, gap_random=True, random_seed=7, random_shot_angle=10.0,
    bullet_speed=78.0, bullet_scale=1.6,
    split_time=3.0, split_time_random=0.5, split_follow_direction=False,
    split=P(bullet="E_Blue_Cian", bullet_count=5, spread_angle=360.0, aim_at_player=False,
            random_shot_angle=25.0, random_seed=3, bullet_speed=34.0, bullet_accel=18.0),
))

# --- NORMAL: ジャイロスコープ(1面ボス)。でんぐり返る立体の輪。輪が正面を向いた瞬間に、真ん中をくぐれる
reg(EX + "ex_n_gyroscope.tres", P(
    bullet="E_Blue_Cian", **only(NORMAL),
    start_delay=0.5, shot_count=2, interval=0.8, pause=1.9,
    bullet_count=3, spread_angle=64.0, aim_at_player=True,
    ring3d_count=6, ring3d_radius=12.0, ring3d_grow=16.0, ring3d_max_radius=36.0,
    ring3d_spin=150.0, ring3d_tilt=70.0, ring3d_tumble=85.0,
    bullet_speed=80.0,
))

# --- HARD: プリズムブレイク(1面ボス)。大きな結晶が広がって止まり、砕けて、曲がる小さなひし形のかけらになる
reg(EX + "ex_h_prism_break.tres", P(
    bullet="E_Spiky_Split", **only(HARD),
    start_delay=0.4, shot_count=2, interval=0.9, pause=1.5,
    bullet_count=5, spread_angle=360.0, aim_at_player=True, base_angle=36.0, rotate_per_shot=36.0,
    bullet_speed=230.0, bullet_scale=1.5,
    motion=[S(0.75, 0.0, trans="quad"), S(0.45, None)],
    split_time=1.2,
    split=P(bullet="E_Green_Curve", bullet_count=3, spread_angle=56.0, aim_at_player=False,
            cluster_layers=1, cluster_spacing=7.0, mirror_curve_by_side=True,
            bullet_speed=40.0, motion=[S(1.4, 115.0, trans="quad", ease="in", av=26.0)]),
))


def worm(level, count, ways, spread, speed, av, length, pause, ribs=False):
    """ワーム(2面ボスの列車): 同じ道をたどる弾の列が、くねりながら這ってくる。先頭は大玉(焼くと得)"""
    wiggle = [S(0.35, None, av=av)] + [S(0.7, None, av=(-av if i % 2 == 0 else av)) for i in range(5)]
    interval = 0.05
    body = dict(
        bullet="E_Green_Curve", **only(level), replaces_others=True,
        start_delay=0.8, shot_count=length, interval=interval, pause=pause,
        bullet_count=ways, spread_angle=spread, aim_at_player=True, aim_once_per_burst=True,
        mirror_curve_by_side=ways >= 2, bullet_speed=speed, motion=wiggle,
    )
    head = P(bullet="E_Massive_Light_Green", **only(level),
             start_delay=0.75, shot_count=1, interval=interval * length, pause=pause,
             bullet_count=ways, spread_angle=spread, aim_at_player=True, aim_once_per_burst=True,
             mirror_curve_by_side=ways >= 2, bullet_speed=speed, motion=wiggle)
    body["with_"] = [head]
    if ribs:
        # 這ったあとに、体の節から、横へ肋骨のような弾を落とす
        body["split_time"] = 1.9
        body["split_time_random"] = 0.15
        body["split"] = P(bullet="E_Blue_Cian", bullet_count=2, spread_angle=180.0, base_angle=90.0,
                          aim_at_player=False, bullet_speed=30.0, bullet_accel=24.0)
        body["bullet"] = "E_Spiky_Split"
    return P(**body)


reg(EX + "ex_e_worm.tres", worm(EASY, 1, 1, 0.0, 100.0, 70.0, 14, 2.4))
reg(EX + "ex_n_worm_twin.tres", worm(NORMAL, 2, 2, 60.0, 118.0, 90.0, 18, 2.0))
reg(EX + "ex_h_sandworm.tres", worm(HARD, 3, 3, 84.0, 138.0, 100.0, 20, 1.8, ribs=True))

# --- NORMAL: カウンターウォール(最終面の改タンク)。ゆっくり迫る壁の、細い通り道。壁に混ざった大玉をイグナイトで返すと、壁ごと押し返せる
reg(EX + "ex_n_counter_wall.tres", P(
    bullet="E_Red_Normal", **only(NORMAL),
    start_delay=0.5, shot_count=6, interval=0.34, pause=1.4,
    bullet_count=23, spread_angle=150.0, aim_at_player=False,
    gap_size=4, gap_wave_amplitude=0.55, gap_wave_shots=10,
    bullet_speed=72.0,
    with_=[P(bullet="E_Massive_Light_Green", **only(NORMAL), start_delay=0.9, shot_count=1, interval=2.04,
             pause=1.4, bullet_count=3, spread_angle=70.0, aim_at_player=True, bullet_speed=62.0)],
))

# --- HARD: ダブルヘリックス(最終面の改タンク)。2本のらせんがねじれながら飛ぶ立体弾幕
reg(EX + "ex_h_double_helix.tres", P(
    bullet="E_Blue_Cian", **only(HARD),
    start_delay=0.5, shot_count=18, interval=0.075, pause=1.3,
    bullet_count=3, spread_angle=56.0, aim_at_player=True, aim_once_per_burst=True,
    ring3d_count=2, ring3d_radius=16.0, ring3d_spin=330.0, ring3d_tilt=82.0, ring3d_depth_scale=0.45,
    bullet_speed=128.0,
))

# --- HARD: フローズンタイム(最終兵器ヌクレオ、氷の段階)。ばらまいた弾が一斉に凍り、狙い弾のあと、ばらばらの向きに動き出す
reg(EX + "ex_h_frozen_time.tres", P(
    bullet="E_Pink_Medium", **only(HARD),
    start_delay=0.5, shot_count=5, interval=0.1, pause=2.2,
    bullet_count=22, spread_angle=360.0, aim_at_player=False, random_angle=180.0,
    random_speed_ratio=0.55, random_seed=5, bullet_speed=150.0,
    motion=[S(1.25, None), S(0.12, 0.0, trans="linear"), S(1.7, None), S(1.2, 72.0, turn="random", trans="quad", ease="in")],
    with_=[P(bullet="E_Magenta_Aim", **only(HARD), start_delay=1.95, shot_count=2, interval=0.32, pause=4.0,
             bullet_count=5, spread_angle=26.0, line_count=3, line_speed_ratio=0.14, aim_at_player=True,
             bullet_speed=200.0)],
))

# =============================================================== 限定弾幕: 雑魚(その難易度では、雑魚のいつもの弾幕と差し替える)

# --- EASY: 立体の輪(ガンシップ)。ゆっくり回る輪がひとつずつ飛んでくる
reg(EX + "ex_e_zako_ring3d.tres", P(
    bullet="E_Blue_Cian", **only(EASY), replaces_others=True,
    start_delay=0.9, shot_count=1, pause=2.4, aim_at_player=True,
    ring3d_count=6, ring3d_radius=9.0, ring3d_grow=6.0, ring3d_max_radius=17.0,
    ring3d_spin=170.0, ring3d_tilt=68.0, ring3d_tumble=60.0, bullet_speed=62.0,
))

# --- NORMAL: 二色の帯(編隊。斑鳩風)。速い白と遅い赤の扇を、互い違いに重ねて撃つ。帯と帯のあいだを抜ける
reg(EX + "ex_n_zako_twotone.tres", P(
    bullet="E_Blue_Cian", **only(NORMAL), replaces_others=True,
    start_delay=0.7, start_delay_per_unit=0.12, shot_count=1, interval=0.14, pause=2.1,
    bullet_count=5, spread_angle=64.0, aim_at_player=True, aim_once_per_burst=True, bullet_speed=96.0,
    with_=[P(bullet="E_Red_Normal", **only(NORMAL), start_delay=0.7, start_delay_per_unit=0.12,
             shot_count=1, interval=0.14, pause=2.1, bullet_count=4, spread_angle=48.0,
             aim_at_player=True, aim_once_per_burst=True, bullet_speed=70.0)],
))

# --- NORMAL: カウンタークラスター(装甲機)。ひし形の弾の塊が止まってから突っ込んでくる。イグナイトで塊ごと返せる
reg(EX + "ex_n_zako_counter.tres", P(
    bullet="E_Red_Normal", **only(NORMAL), replaces_others=True,
    start_delay=1.0, shot_count=1, pause=2.6, aim_at_player=True,
    cluster_layers=2, cluster_spacing=10.0, bullet_speed=120.0,
    motion=[S(0.6, 0.0), S(0.7, None), S(1.0, 105.0, turn="group", trans="sine", ease="in_out")],
))

# --- HARD: 絆地獄(戦車。ケツイ風)。至近距離の高速な3連の針弾と、少し遅れて逃げ道をふさぐ扇
reg(EX + "ex_h_zako_ketsui.tres", P(
    bullet="E_Magenta_Aim", **only(HARD), replaces_others=True,
    start_delay=0.5, shot_count=3, interval=0.09, pause=1.7,
    bullet_count=1, line_count=3, line_speed_ratio=0.12, aim_at_player=True, bullet_speed=235.0,
    with_=[P(bullet="E_Red_Normal", **only(HARD), start_delay=0.8, shot_count=1, interval=0.1, pause=1.87,
             bullet_count=4, spread_angle=44.0, aim_at_player=True, bullet_speed=150.0)],
))

# =============================================================== 最終兵器ヌクレオ(全難易度。EASY・NORMAL は自動で調整)
# 主砲の砲口(0.7, 3.9)から見た、副砲などの位置
CANNON_L, CANNON_R = (-32.6, 8.4), (30.5, 7.8)
WING_L, WING_R = (-137.2, -11.1), (135.8, -11.1)
CRYSTAL_L, CRYSTAL_R = (-41.7, 30.6), (42.2, 29.2)
CORE_POINT = (0.0, 96.0)
# ラスボスの大きさ(シーンのルートの Scale)。砲口の位置は、これを掛けた画面の上の位置で撃つ
BOSS_SCALE = 1.15
CANNON_L, CANNON_R, WING_L, WING_R, CRYSTAL_L, CRYSTAL_R, CORE_POINT = [
    (x * BOSS_SCALE, y * BOSS_SCALE) for (x, y) in (CANNON_L, CANNON_R, WING_L, WING_R, CRYSTAL_L, CRYSTAL_R, CORE_POINT)]


def giga(path, bursts=2, ring=30):
    """超巨大弾: 副砲・翼砲・結晶砲が1点へ弾を送り込み、そこから主砲の巨大弾が生まれて、ゆっくり自機へ向かって炸裂する"""
    gather = P(bullet="E_Pink_Medium", muzzle_offsets=[CANNON_L, CANNON_R, WING_L, WING_R, CRYSTAL_L, CRYSTAL_R],
               aim_at_point=True, aim_point=CORE_POINT, arrive_time=1.05, start_delay=0.2, shot_count=8,
               interval=0.09, pause=4.0, bullet_count=1, aim_at_player=False, bullet_speed=200.0,
               split_vanish=True, split_time=1.25, skip_auto_tuning=True)
    burst = P(bullet="E_Blue_Cian", bullet_count=ring, spread_angle=360.0, aim_at_player=False,
              shot_count=bursts, interval=0.14, rotate_per_shot=360.0 / ring / 2.0,
              bullet_speed=36.0, bullet_accel=48.0)
    return reg(path, P(
        bullet="E_Massive_Light_Green", muzzle_offsets=[CORE_POINT], start_delay=2.15, shot_count=1, pause=1.6,
        bullet_count=1, aim_at_player=True, bullet_speed=52.0, bullet_accel=14.0, bullet_scale=4.5,
        split_time=2.1, split_follow_direction=False, split=burst, with_=[gather]))


giga(FIN + "fin_giga_core.tres")


def hydra(path, necks, ring=3, length=15, speed=148.0, av=72.0):
    """ヒュドラ: 主砲と副砲から、回る輪でできた首が、くねりながら自機へ伸びる(先頭は大玉の頭)"""
    wiggle = [S(0.35, None, av=av)] + [S(0.7, None, av=(-av if i % 2 == 0 else av)) for i in range(5)]
    head = P(bullet="E_Massive_Light_Green", muzzle_offsets=necks, start_delay=0.35, shot_count=1,
             interval=0.07 * length, pause=1.5, aim_at_player=True, aim_once_per_burst=True,
             bullet_speed=speed, bullet_scale=1.5, motion=wiggle)
    return reg(path, P(
        bullet="E_Green_Curve", muzzle_offsets=necks, start_delay=0.4, shot_count=length, interval=0.07, pause=1.5,
        aim_at_player=True, aim_once_per_burst=True, ring3d_count=ring, ring3d_radius=10.0, ring3d_spin=300.0,
        ring3d_tilt=76.0, bullet_speed=speed, motion=wiggle, with_=[head]))


hydra(FIN + "fin_hydra.tres", [(0.0, 0.0), CANNON_L, CANNON_R, WING_L, WING_R])


def hexagram(path, count=21, shots=5, interval=0.36, speed=90.0, turn=7.0, square=False):
    """幾何学: 逆に回る2つの三角形が重なって、六芒星が次々に広がる"""
    tri_b = P(bullet="E_Red_Normal", start_delay=0.5, shot_count=shots, interval=interval, pause=1.3,
              bullet_count=count, spread_angle=360.0, aim_at_player=False, polygon_sides=3, polygon_phase=60.0,
              rotate_per_shot=-turn, bullet_speed=speed)
    with_ = [tri_b]
    if square:
        with_.append(P(bullet="E_Pink_Medium", start_delay=0.65, shot_count=shots // 2, interval=interval * 2.0,
                       pause=1.3, bullet_count=count, spread_angle=360.0, aim_at_player=False, polygon_sides=4,
                       polygon_phase=45.0, rotate_per_shot=turn * 1.5, bullet_speed=speed * 0.62))
    return reg(path, P(
        bullet="E_Blue_Cian", start_delay=0.5, shot_count=shots, interval=interval, pause=1.3,
        bullet_count=count, spread_angle=360.0, aim_at_player=False, polygon_sides=3, polygon_phase=0.0,
        rotate_per_shot=turn, bullet_speed=speed, with_=with_))


hexagram(FIN + "fin_hexagram.tres")
hexagram(FIN + "fin_hexagram_rage.tres", count=21, shots=5, interval=0.32, speed=100.0, turn=10.0, square=True)


def web(path, spokes=11, rings=30, hold=2.0, spider=True, hydra_necks=None, lines=6, ring_lines=5, light=None):
    """蜘蛛の巣: 放射状の糸(止まる弾の列)と、同心円の糸が一度に張られ、しばらく止まってから、ゆっくり外へ広がる。
    張っているあいだに、巣の真ん中から蜘蛛(狙い弾)が飛んでくる。巣の目の中で待ち、目を通して避ける"""
    T = 1.6
    spoke = P(bullet="E_Pink_Medium", start_delay=0.4, shot_count=1, pause=3.6,
              bullet_count=spokes, spread_angle=360.0, aim_at_player=False, line_count=lines, line_speed_ratio=0.5 * 6.0 / lines,
              bullet_speed=130.0, motion=[S(T, 0.0, trans="linear"), S(hold, None), S(2.4, 17.0, trans="sine", ease="in")])
    ring = P(bullet="E_Pink_Medium", start_delay=0.4, shot_count=1, pause=3.6,
             bullet_count=rings, spread_angle=360.0, aim_at_player=False, base_angle=360.0 / spokes / 2.0,
             line_count=ring_lines, line_speed_ratio=0.4615 * 5.0 / ring_lines, bullet_speed=162.5,
             motion=[S(T, 0.0, trans="linear"), S(hold, None), S(2.4, 21.0, trans="sine", ease="in")])
    with_ = [ring]
    if spider:
        with_.append(P(bullet="E_Magenta_Aim", start_delay=0.4 + T + 0.3, shot_count=3, interval=0.4, pause=3.0,
                       bullet_count=3, spread_angle=18.0, aim_at_player=True, bullet_speed=165.0))
    if hydra_necks:
        wiggle = [S(0.35, None, av=60.0)] + [S(0.7, None, av=(-60.0 if i % 2 == 0 else 60.0)) for i in range(5)]
        with_.append(P(bullet="E_Green_Curve", muzzle_offsets=hydra_necks, start_delay=0.4 + T + 0.4, shot_count=12,
                       interval=0.08, pause=3.0, aim_at_player=True, aim_once_per_burst=True, ring3d_count=3,
                       ring3d_radius=9.0, ring3d_spin=300.0, ring3d_tilt=76.0, bullet_speed=120.0, motion=wiggle))
    spoke["with_"] = with_
    if light:
        # EASY を選んだとき(最終面では NORMAL の弾幕になる)は、目の粗い巣にする(手で作った NORMAL 用)
        spoke["normal"] = web(None, **light)
    if path is None:
        spoke["skip_auto_tuning"] = True
        return spoke
    return reg(path, spoke)


web(FIN + "fin_spider_web.tres", light=dict(spokes=8, rings=22, lines=4, ring_lines=4, hold=1.6))
# 組み合わせ: 巣が張られて動ける場所が狭まったところへ、ヒュドラの首が巣の目を縫って伸びてくる
web(FIN + "fin_web_hydra.tres", spokes=9, rings=26, spider=False, hydra_necks=[WING_L, WING_R, (0.0, 0.0)],
    light=dict(spokes=7, rings=20, lines=4, ring_lines=4, hold=1.6, spider=False, hydra_necks=[WING_L, WING_R]))

# --- 美しい自機狙い: 左右に開いた弾の列が、内側へ曲がりながら自機の位置で交わり、花びらの形を描く。
#     まっすぐの狙い針も一緒に来るので、少しだけ横へずれてよける
reg(FIN + "fin_aim_lace.tres", P(
    bullet="E_Green_Curve", start_delay=0.5, shot_count=9, interval=0.09, pause=1.4,
    bullet_count=6, spread_angle=104.0, aim_at_player=True, aim_once_per_burst=True, mirror_curve_by_side=True,
    bullet_speed=150.0, motion=[S(0.35, None), S(1.6, None, av=-62.0)],
    with_=[P(bullet="E_Magenta_Aim", start_delay=0.8, shot_count=3, interval=0.12, pause=1.9,
             bullet_count=1, line_count=4, line_speed_ratio=0.13, aim_at_player=True, aim_once_per_burst=True,
             bullet_speed=200.0)]))

# --- やさしい洗濯機: 4本の腕が回って、ときどき回る向きが変わる
reg(FIN + "fin_washer_easy.tres", P(
    bullet="E_Blue_Cian", start_delay=0.4, shot_count=64, interval=0.075, pause=1.2,
    bullet_count=4, spread_angle=360.0, aim_at_player=False, rotate_per_shot=7.5, reverse_every_shots=32,
    bullet_speed=110.0))

# --- 第三形態の洗濯機: 逆に回る2層。内側は速く、外側の層はゆっくり。向きの変わり目が速い
reg(FIN + "fin_washer_hard.tres", P(
    bullet="E_Blue_Cian", start_delay=0.4, shot_count=72, interval=0.07, pause=1.0,
    bullet_count=5, spread_angle=360.0, aim_at_player=False, rotate_per_shot=7.0, reverse_every_shots=28,
    bullet_speed=122.0,
    with_=[P(bullet="E_Red_Normal", start_delay=0.4, shot_count=24, interval=0.21, pause=1.0,
             bullet_count=3, spread_angle=360.0, aim_at_player=False, base_angle=36.0, rotate_per_shot=-11.0,
             bullet_speed=68.0)]))

# --- 重ねる弾幕(副砲・中央・三連砲が、主砲と一緒に撃ち続ける。主砲の重い攻撃のあいだは、ゆずって控えめになる)
def side_spray(path, angle):
    """左右へのばらまき: 副砲が、外側の下へ向けて、速さのばらばらな弾をまき続ける"""
    return reg(path, P(
        bullet="E_Red_Normal", start_delay=1.0, shot_count=10, interval=0.075, pause=0.7, yields=True,
        bullet_count=2, aim_at_player=False, base_angle=angle, random_angle=32.0, random_speed_ratio=0.35,
        random_seed=17, bullet_speed=118.0))


side_spray(FIN + "fin_side_spray_L.tres", 52.0)
side_spray(FIN + "fin_side_spray_R.tres", -52.0)

# 後ろの弾ほど速い列: 続けて撃つ扇の、後の弾ほど速いので、前の弾に追いついて詰まった列になって迫る
reg(FIN + "fin_rush_rows.tres", P(
    bullet="E_Blue_Cian", start_delay=1.4, shot_count=7, interval=0.07, pause=1.9, yields=True,
    bullet_count=5, spread_angle=54.0, aim_at_player=True, aim_once_per_burst=True,
    launch_speed_step=0.17, bullet_speed=88.0))

# ランダムな方向に撃つ長い弾: 細長い列弾を、ばらばらの向きに撃ちまくる(改タンクの暴れ撃ちと同じ)
reg(FIN + "fin_rampage_lines.tres", P(
    bullet="E_Magenta_Aim", start_delay=1.6, warning_time=0.35, shot_count=10, interval=0.2, pause=1.6, yields=True,
    aim_at_player=False, swing_barrel=True, line_count=8, line_speed_ratio=0.1,
    random_shot_angle=72.0, random_seed=29, bullet_speed=8.0, bullet_accel=200.0))

# --- 残留弾(自分からグレイズしにいく弾幕): 止まった弾が残り、そのあいだを細い道で抜ける。抜けるとグレイズがたまり、イグナイトで返せる

# 残留の段々畑: 止まる弾の弧が段に重なり、くねる細い通り道が1本だけ開く。しばらく残ってから、ゆっくり下へ流れる
reg(FIN + "fin_residue_terraces.tres", P(
    bullet="E_Pink_Medium", start_delay=0.4, shot_count=6, interval=0.12, pause=3.2, soften_others=2.5,
    bullet_count=24, spread_angle=150.0, aim_at_player=False, gap_size=3, gap_wave_amplitude=0.55, gap_wave_shots=6,
    launch_speed_step=0.28, bullet_speed=150.0,
    motion=[S(1.8, 0.0, trans="linear"), S(3.2, None), S(2.2, 58.0, turn="abs", trans="sine", ease="in")],
    with_=[P(bullet="E_Magenta_Aim", start_delay=2.6, shot_count=4, interval=0.6, pause=3.0,
             bullet_count=3, spread_angle=20.0, aim_at_player=True, bullet_speed=150.0)]))

# 残留の渦: 2本の腕の渦巻きが、だんだん遠くで止まって迷路になる。残ったあと、外へゆっくり広がる
reg(FIN + "fin_residue_spiral.tres", P(
    bullet="E_Pink_Medium", start_delay=0.4, shot_count=46, interval=0.045, pause=3.0, soften_others=2.5,
    bullet_count=2, spread_angle=360.0, aim_at_player=False, rotate_per_shot=13.0,
    launch_speed_step=0.045, bullet_speed=110.0,
    motion=[S(1.6, 0.0, trans="linear"), S(3.0, None), S(2.4, 30.0, trans="sine", ease="in")],
    with_=[P(bullet="E_Magenta_Aim", start_delay=2.4, shot_count=3, interval=0.7, pause=3.0,
             bullet_count=1, line_count=3, line_speed_ratio=0.15, aim_at_player=True, bullet_speed=170.0)]))

# NORMAL 限定: 斜めに交わる止まる線で、ひし形の網を張る(網の目は、グレイズしながら抜ける広さ)
reg(EX + "ex_n_residue_net.tres", P(
    bullet="E_Pink_Medium", **only(NORMAL), start_delay=0.4, shot_count=5, interval=0.14, pause=3.0,
    bullet_count=9, spread_angle=0.0, parallel_spacing=50.0, aim_at_player=False, base_angle=28.0,
    launch_speed_step=0.32, bullet_speed=150.0,
    motion=[S(1.6, 0.0, trans="linear"), S(3.0, None), S(2.0, 60.0, turn="abs", trans="sine", ease="in")],
    with_=[P(bullet="E_Pink_Medium", **only(NORMAL), start_delay=0.4, shot_count=5, interval=0.14, pause=3.0,
             bullet_count=9, spread_angle=0.0, parallel_spacing=50.0, aim_at_player=False, base_angle=-28.0,
             launch_speed_step=0.32, bullet_speed=150.0,
             motion=[S(1.6, 0.0, trans="linear"), S(3.0, None), S(2.0, 60.0, turn="abs", trans="sine", ease="in")])]))

# HARD 限定(応用1): 足跡。自機狙いの弾が、通ったところに止まる弾を落としていく。逃げた道すじが壁になって残る
reg(EX + "ex_h_footprint.tres", P(
    bullet="E_Spiky_Split", **only(HARD), start_delay=0.4, shot_count=16, interval=0.16, pause=1.8,
    bullet_count=3, spread_angle=26.0, aim_at_player=True, bullet_speed=165.0,
    split_time=0.75, split_follow_direction=True,
    split=P(bullet="E_Pink_Medium", bullet_count=2, spread_angle=180.0, base_angle=90.0, aim_at_player=False,
            bullet_speed=26.0, motion=[S(0.5, 0.0), S(2.8, None), S(1.6, 80.0, turn="random", angle=40.0, trans="quad", ease="in")])))

# HARD 限定(応用2): 豹変する残留弾。止まった格子が、時間差で一斉に自機の方へ動き出して迫る(イグナイトで崩す)
reg(EX + "ex_h_residue_turncoat.tres", P(
    bullet="E_Pink_Medium", **only(HARD), start_delay=0.4, shot_count=5, interval=0.15, pause=2.6,
    bullet_count=20, spread_angle=140.0, aim_at_player=False, launch_speed_step=0.3, bullet_speed=150.0,
    random_angle=2.0, random_seed=31,
    motion=[S(1.8, 0.0, trans="linear"), S(1.6, None), S(1.8, 62.0, turn="aim", trans="sine", ease="in_out")],
    with_=[P(bullet="E_Massive_Light_Green", **only(HARD), start_delay=2.0, shot_count=2, interval=0.6, pause=3.0,
             bullet_count=2, spread_angle=50.0, aim_at_player=True, bullet_speed=60.0)]))

# =============================================================== イグナイトのチャンス(全ステージの雑魚)
# おとり: 遅くて濃い弾の幕と、焼くと得な大玉。グレイズでゲージをためて、イグナイトで返すと、おとりが落ちてアイテムがたくさん出る
# ANOTHER 用(濃い幕): ANOTHER では、こちらを撃つ
_bait_another = P(
    bullet="E_Red_Normal", another_made=True, start_delay=1.0, shot_count=4, interval=0.35, pause=0.9,
    bullet_count=13, spread_angle=100.0, aim_at_player=True, aim_once_per_burst=True, gap_size=2, gap_random=True,
    random_seed=41, bullet_speed=62.0,
    with_=[P(bullet="E_Massive_Light_Green", start_delay=1.6, shot_count=1, interval=0.1, pause=2.3,
             bullet_count=1, aim_at_player=True, bullet_speed=55.0)])
# ふつう(EASY〜HARD): 薄めの幕。グレイズでゲージをためて、大玉ごと返す練習になる量
reg(EX + "ig_bait_curtain.tres", P(
    bullet="E_Red_Normal", start_delay=1.2, shot_count=2, interval=0.5, pause=2.4, another=_bait_another,
    bullet_count=7, spread_angle=76.0, aim_at_player=True, aim_once_per_burst=True, gap_size=2, gap_random=True,
    random_seed=41, bullet_speed=56.0,
    with_=[P(bullet="E_Massive_Light_Green", start_delay=1.8, shot_count=1, interval=0.1, pause=3.3,
             bullet_count=1, aim_at_player=True, bullet_speed=50.0)]))

# =============================================================== 中枢防衛艦(全難易度)

reg(GD + "g_cross_spiral.tres", P(
    bullet="E_Blue_Cian", start_delay=0.4, shot_count=34, interval=0.085, pause=1.2,
    bullet_count=3, spread_angle=360.0, aim_at_player=False, rotate_per_shot=11.0, bullet_speed=118.0,
    with_=[P(bullet="E_Red_Normal", start_delay=0.4, shot_count=34, interval=0.085, pause=1.2,
             bullet_count=3, spread_angle=360.0, aim_at_player=False, base_angle=60.0, rotate_per_shot=-11.0,
             bullet_speed=100.0)]))

reg(GD + "g_gatling_sweep.tres", P(
    bullet="E_Lines_Yellow", start_delay=0.6, warning_time=0.6, shot_count=24, interval=0.12, pause=1.4,
    bullet_count=2, parallel_spacing=14.0, aim_at_player=True, aim_once_per_burst=True,
    angle_wave_amplitude=36.0, angle_wave_shots=24, bullet_speed=220.0))

reg(GD + "g_shell_burst.tres", P(
    bullet="E_Spiky_Split", start_delay=0.4, shot_count=2, interval=0.6, pause=1.4,
    bullet_count=5, spread_angle=84.0, aim_at_player=True, bullet_speed=170.0,
    motion=[S(1.0, 55.0, trans="quad")], split_time=1.05, split_follow_direction=False,
    split=P(bullet="E_Blue_Cian", bullet_count=12, spread_angle=360.0, aim_at_player=False,
            bullet_speed=48.0, bullet_accel=40.0)))

reg(GD + "g_scissor.tres", P(
    bullet="E_Magenta_Aim", start_delay=0.4, shot_count=19, interval=0.15, pause=1.3,
    bullet_count=1, aim_at_player=False, base_angle=62.0,
    rotate_per_shot=-6.6, bullet_speed=170.0,
    with_=[P(bullet="E_Magenta_Aim", start_delay=0.4, shot_count=19, interval=0.15, pause=1.3,
             bullet_count=1, aim_at_player=False, base_angle=-62.0,
             rotate_per_shot=6.6, bullet_speed=170.0)]))

reg(GD + "g_star_burst.tres", P(
    bullet="E_Blue_Cian", start_delay=0.4, shot_count=3, interval=0.5, pause=1.3,
    bullet_count=32, spread_angle=360.0, aim_at_player=False, petal_count=5, petal_depth=0.45,
    rotate_per_shot=9.0, bullet_speed=86.0,
    with_=[P(bullet="E_Red_Normal", start_delay=0.65, shot_count=3, interval=0.5, pause=1.3,
             bullet_count=20, spread_angle=360.0, aim_at_player=False, polygon_sides=5, polygon_phase=36.0,
             rotate_per_shot=-9.0, bullet_speed=62.0)]))

reg(GD + "g_wing_needle.tres", P(
    bullet="E_Magenta_Aim", start_delay=1.0, shot_count=4, interval=0.1, pause=1.8,
    bullet_count=3, parallel_spacing=8.0, aim_at_player=True, aim_once_per_burst=True, bullet_speed=225.0))

reg(GD + "g_wing_arc.tres", P(
    bullet="E_Green_Curve", start_delay=1.2, shot_count=3, interval=0.22, pause=1.9,
    bullet_count=6, spread_angle=76.0, aim_at_player=True, mirror_curve_by_side=True, bullet_speed=135.0,
    motion=[S(1.6, None, av=-38.0)]))

reg(GD + "g_wing_rain.tres", P(
    bullet="E_Bermuda", start_delay=1.0, shot_count=12, interval=0.13, pause=1.2,
    bullet_count=1, aim_at_player=False, random_angle=7.0, random_seed=13, bullet_speed=165.0))

reg(GD + "g_stack_flak.tres", P(
    bullet="E_Spiky_Split", start_delay=1.4, shot_count=2, interval=0.45, pause=2.2,
    bullet_count=1, aim_at_player=True, random_angle=22.0, random_seed=9, bullet_speed=190.0,
    motion=[S(0.8, 40.0, trans="quad")], split_time=0.85, split_follow_direction=False,
    split=P(bullet="E_Blue_Cian", bullet_count=7, spread_angle=360.0, aim_at_player=False, bullet_speed=60.0,
            bullet_accel=30.0)))

reg(GD + "g_stack_fountain.tres", P(
    bullet="E_Bermuda", start_delay=1.2, shot_count=4, interval=0.16, pause=1.8,
    bullet_count=3, spread_angle=110.0, aim_at_player=False, base_angle=180.0, random_angle=14.0, random_seed=21,
    bullet_speed=150.0, motion=[S(0.75, 0.0, trans="quad"), S(1.6, 165.0, turn="abs", trans="quad", ease="in")]))

reg(GD + "g_stack_mine.tres", P(
    bullet="E_Pink_Medium", start_delay=1.3, shot_count=2, interval=0.5, pause=2.3,
    bullet_count=5, spread_angle=140.0, aim_at_player=False, bullet_speed=160.0,
    motion=[S(0.8, 0.0), S(1.1, None), S(0.8, 170.0, turn="aim", trans="quad", ease="in")]))

# =============================================================== ブラッドスワン(翼のブラックスワンズが敷くワインダーの中で避ける)

reg(BS + "bs_wing_winder.tres", P(
    bullet="E_Lines_Yellow", start_delay=1.2, shot_count=60, interval=0.06, pause=0.0,
    bullet_count=4, spread_angle=96.0, aim_at_player=False, angle_wave_amplitude=13.0, angle_wave_shots=120,
    bullet_speed=215.0))

reg(BS + "bs_blood_lance.tres", P(
    bullet="E_Magenta_Aim", start_delay=0.5, warning_time=0.5, shot_count=5, interval=0.12, pause=1.2,
    bullet_count=1, line_count=4, line_speed_ratio=0.12, aim_at_player=True, aim_once_per_burst=True,
    bullet_speed=240.0))

reg(BS + "bs_crimson_fan.tres", P(
    bullet="E_Red_Normal", start_delay=0.4, shot_count=4, interval=0.22, pause=1.2,
    bullet_count=7, spread_angle=36.0, aim_at_player=True, bullet_speed=130.0))

reg(BS + "bs_blood_turncoat.tres", P(
    bullet="E_Red_Normal", start_delay=0.4, shot_count=3, interval=0.45, pause=1.4,
    bullet_count=6, spread_angle=360.0, aim_at_player=False, rotate_per_shot=30.0, cluster_layers=1,
    bullet_speed=420.0, motion=[S(0.7, 0.0, trans="cubic"), S(0.35, None), S(0.6, 300.0, turn="group", trans="quad", ease="in")]))

reg(BS + "bs_blood_rain.tres", P(
    bullet="E_Spiky_Split", start_delay=0.4, shot_count=6, interval=0.3, pause=1.3,
    bullet_count=2, spread_angle=120.0, aim_at_player=True, bullet_speed=150.0,
    motion=[S(0.9, 40.0, trans="quad")], split_time=0.95, split_follow_direction=False,
    split=P(bullet="E_Bermuda", bullet_count=3, spread_angle=24.0, aim_at_player=False, bullet_speed=60.0,
            bullet_accel=70.0)))

# =============================================================== ベルトコンベアのワゴン
reg(WG + "w_wagon_fan.tres", P(
    bullet="E_Blue_Cian", start_delay=0.8, shot_count=2, interval=0.28, pause=2.1,
    bullet_count=7, spread_angle=84.0, aim_at_player=False, bullet_speed=105.0,
    with_=[P(bullet="E_Magenta_Aim", start_delay=1.5, shot_count=3, interval=0.1, pause=2.08,
             bullet_count=1, aim_at_player=True, bullet_speed=190.0)]))


# ---- 1つずつ: 重い攻撃のあいだは、ほかの砲台(Yields の弾幕)をやさしくする
for _f, _k in [("fin_giga_core", 3.0), ("fin_hydra", 3.0), ("fin_hexagram", 3.0), ("fin_hexagram_rage", 2.5),
               ("fin_spider_web", 4.0), ("fin_web_hydra", 4.0), ("fin_aim_lace", 2.0), ("fin_washer_easy", 3.0),
               ("fin_washer_hard", 2.5)]:
    ALL[FIN + _f + ".tres"]["soften_others"] = _k
ALL[EX + "ex_h_frozen_time.tres"]["soften_others"] = 3.0
for _f in ["g_cross_spiral", "g_star_burst", "g_scissor", "g_gatling_sweep"]:
    ALL[GD + _f + ".tres"]["soften_others"] = 2.0
for _f in ["g_wing_needle", "g_wing_arc", "g_wing_rain", "g_stack_flak", "g_stack_fountain", "g_stack_mine"]:
    ALL[GD + _f + ".tres"]["yields"] = True
ALL[BS + "bs_wing_winder.tres"]["interval"] = 0.07


if __name__ == "__main__":
    only_paths = sys.argv[1:]
    for path, p in ALL.items():
        if only_paths and not any(o in path for o in only_paths):
            continue
        write(path, p)
    print("wrote", len(ALL) if not only_paths else "selected")
