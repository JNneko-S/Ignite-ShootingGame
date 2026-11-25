"""裏ボス Union の弾幕と、Union のシーン(GameScene/Enemy/SECRET/union_boss.tscn)を作る。Run: python union.py
このゲームでいちばん難しいボス。EASY / NORMAL / HARD の限定弾幕(HARD 用は ANOTHER でも撃つ)。

第一形態「EVAC」   … ケツイのエヴァッカニアドゥーム戦のアレンジ。三重の針の壁、追い越しの輪、四連の流し、豹変、破滅の花
第二形態「緋」      … 怒首領蜂大往生の緋蜂のアレンジ。蜂の巣、十字架、七本腕の緋の渦、ジグザグの青の嵐、追い越しの渦
第三形態「UNION」  … 八岐大蛇・立体弾幕と、イグナイトを使い切る弾幕(カウンター弾・残留弾・点火の壁)
最期             … 倒れる直前のカウンター大技「終焉の産声」(撃ちきると倒れる)
"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from shotgen import P, S, write

OUT = "res://Resources/ShotPatterns/SECRET/Union/"
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LV = "enha"
ALL = {}

## ANOTHER(4つ目の版): HARD から、NORMAL → HARD の差の EXTRA 倍ぶん先へ伸ばす。
## 間・休みのように HARD で小さくなる値は、HARD の FLOOR 倍より小さくしない
EXTRA = 0.8
FLOOR = 0.7


class D:
    def __init__(self, lv):
        self.lv = lv

    def __call__(self, e, n, h):
        if self.lv < 3:
            return (e, n, h)[self.lv]
        if isinstance(h, bool) or not isinstance(h, (int, float)) or n == h:
            return h
        a = h + (h - n) * EXTRA
        if h < n:
            a = max(a, h * FLOOR)
        if isinstance(h, int) and isinstance(n, int):
            return max(1, int(round(a)))
        return a


# 裏ボスらしく: 全部の弾を速く(EASY ×1.15 / NORMAL ×1.2 / HARD ×1.25 / ANOTHER ×1.3)、休みを短く(×0.85)する。
# ただし、イグナイトの仕掛け(返すと削れるカウンター弾・その場に止まる残留弾)は、遅いまま
SPEED_UP = (1.0, 1.0, 1.0, 1.05)
PAUSE_SCALE = 1.0


def _is_gimmick(p):
    if p.get("counter_hp_ratio", 0.0) > 0.0:
        return True
    # 残留弾: 止まったあと、2 秒以上その場に残る弾(止まってすぐ飛び出す豹変などは、ふつうに速くする)
    steps = p.get("motion") or []
    for i, st in enumerate(steps[:-1]):
        if st["speed"] is not None and st["speed"] <= 12.0 and steps[i + 1]["speed"] is None and steps[i + 1]["duration"] >= 2.0:
            return True
    return False


def _speed_up(p, k):
    if not isinstance(p, dict) or _is_gimmick(p):
        return
    if "bullet_speed" in p:
        p["bullet_speed"] = p["bullet_speed"] * k
    if "bullet_accel" in p:
        p["bullet_accel"] = p["bullet_accel"] * k
    if p.get("motion"):
        p["motion"] = [S(s["duration"] / k, None if s["speed"] is None else s["speed"] * k, s["turn"], s["angle"],
                         s["trans"], s["ease"], s["av"] * k) for s in p["motion"]]
    if "pause" in p:
        p["pause"] = p["pause"] * PAUSE_SCALE
    _speed_up(p.get("split"), k)
    for w in p.get("with_") or []:
        _speed_up(w, k)


## ANOTHER 版を作り直さない(今のファイルのまま残す)攻撃の名前の頭。作者が「良い」と言った ANOTHER の第二形態
KEEP_ANOTHER = ("u2_",)


## 密度を上げる(連射の回数 ×DENSE_SHOTS、休み ×DENSE_PAUSE。弾の並びは変えない)。仕掛けの弾幕・最期の大技・突進は除く
DENSE_SHOTS = 1.5
DENSE_PAUSE = 0.6
DENSE_BULLETS = 1.3
DENSE_EXCLUDE = ("u4_", "u5_", "u3_counter_core")


def _densify(p):
    if not isinstance(p, dict) or _is_gimmick(p):
        return
    if p.get("shot_count", 1) >= 2:
        p["shot_count"] = int(round(p["shot_count"] * DENSE_SHOTS))
    # 扇・輪の本数も増やす(十字架の腕・洗濯機の腕のような、形を決める少ない本数は、そのまま)
    if p.get("bullet_count", 1) >= 5 and p.get("spread_angle", 0.0) > 0.0 and not p.get("parallel_spacing"):
        p["bullet_count"] = int(round(p["bullet_count"] * DENSE_BULLETS))
    if "pause" in p:
        p["pause"] = p["pause"] * DENSE_PAUSE
    for w in p.get("with_") or []:
        _densify(w)


def _densify_more(p):
    if not isinstance(p, dict) or _is_gimmick(p):
        return
    if p.get("shot_count", 1) >= 2:
        p["shot_count"] = int(round(p["shot_count"] * 1.2))
    if "pause" in p:
        p["pause"] = p["pause"] * 0.75
    for w in p.get("with_") or []:
        _densify_more(w)


def tri(name, fn):
    """EASY / NORMAL / HARD の限定弾幕と、ANOTHER だけが撃つ版(4つ)を作る。戻り値は4つのパス(順番に撃つ並びに全部入れる)"""
    paths = []
    for lv in range(4):
        if lv == 3 and name.startswith(KEEP_ANOTHER):
            path = OUT + "%s_%s.tres" % (name, LV[lv])
            if os.path.exists(os.path.join(ROOT, path.replace("res://", ""))):
                paths.append(path) # 今の ANOTHER 版を、そのまま使う
                continue
        p = fn(D(lv))
        _speed_up(p, SPEED_UP[lv])
        if not name.startswith(DENSE_EXCLUDE) and not (lv == 3 and name == "u3_gyro_wall"):
            _densify(p)
            if name.startswith(("u2_", "u3_")):
                _densify_more(p) # 第二・第三形態は、もう一段濃く
        if lv < 3:
            p.update(min_difficulty=lv, max_difficulty=lv, skip_auto_tuning=True)
        else:
            p.update(another_only=True, another_made=True, skip_auto_tuning=True) # ハザードランクでは、速さだけ上がる
        for w in p.get("with_") or []:
            if isinstance(w, dict):
                w["skip_auto_tuning"] = True
        path = OUT + "%s_%s.tres" % (name, LV[lv])
        ALL[path] = p
        paths.append(path)
    return paths


# ======================================================================= 第一形態「EVAC」(ケツイ: エヴァッカニアドゥーム)
# 作り直しの決まり: HARD の弾は 300〜450(後から出る弾ほど速いものも)。数は絞って、すき間をはっきり見せる。
# 遅い弾は画面に残って次の攻撃と重なるので使わない(イグナイトの仕掛けの弾だけ遅い)
P1 = [
    # 高速の針の束: 速さの違う3本ずつの針(後ろの針ほど速い)を、すき間の広い扇で、狙いを変えながら連射する
    tri("u1_needle_storm", lambda d: P(
        bullet="E_Blue_Cian", start_delay=0.4, shot_count=d(3, 4, 5), interval=d(0.2, 0.16, 0.13), pause=d(1.2, 1.0, 0.85),
        bullet_count=d(5, 7, 9), spread_angle=d(60.0, 66.0, 72.0), line_count=3, line_speed_ratio=0.14,
        aim_at_player=True, bullet_speed=d(270.0, 310.0, 350.0))),
    # 追い越し: 輪を続けて撃つが、あとの輪ほど速く、前の輪を追い越していく(すき間の半分ずつずれる)
    tri("u1_overtake", lambda d: P(
        bullet="E_Blue_Cian", start_delay=0.4, shot_count=d(5, 6, 7), interval=d(0.14, 0.12, 0.1), pause=d(1.5, 1.25, 1.05),
        bullet_count=d(10, 11, 12), spread_angle=360.0, aim_at_player=True, rotate_per_shot=d(18.0, 16.4, 15.0),
        bullet_speed=d(170.0, 190.0, 210.0), launch_speed_step=d(0.1, 0.11, 0.12))),
    # 四連の流し: 4つの砲口から、1本ずつの速い流しが、時間をずらして順に自機を追う
    tri("u1_quad_flow", lambda d: P(
        bullet="E_Magenta_Aim", start_delay=0.4, shot_count=d(10, 14, 18), interval=d(0.16, 0.13, 0.11), pause=d(1.3, 1.1, 0.9),
        bullet_count=1, aim_at_player=True, muzzle_offsets=[(-130.0, 0.0), (-60.0, 40.0)],
        bullet_speed=d(330.0, 380.0, 430.0),
        with_=[P(bullet="E_Magenta_Aim", start_delay=0.08, shot_count=d(10, 14, 18), interval=d(0.16, 0.13, 0.11), pause=0.0,
                 bullet_count=1, aim_at_player=True, muzzle_offsets=[(60.0, 40.0), (130.0, 0.0)],
                 bullet_speed=d(330.0, 380.0, 430.0))])),
    # 豹変の雨: 輪が少しずつ遠くで止まり、先に撃った輪から順に、自機の方へ速く向き直って飛んでくる
    tri("u1_turncoat_rain", lambda d: P(
        bullet="E_Pink_Medium", start_delay=0.4, shot_count=d(3, 4, 5), interval=d(0.36, 0.3, 0.26), pause=d(1.6, 1.35, 1.15),
        bullet_count=d(10, 12, 14), spread_angle=360.0, aim_at_player=True, base_angle=6.0, launch_speed_step=0.15,
        bullet_speed=200.0, motion=[S(0.45, 0.0, trans="quad"), S(d(1.0, 0.85, 0.75), None),
                                    S(0.35, d(320.0, 380.0, 440.0), turn="aim")],
        soften_others=2.0)),
    # 針の格子: ななめに交わる速い針の列。列の間は広く、格子の目を渡っていく
    tri("u1_needle_lattice", lambda d: P(
        bullet="E_Blue_Cian", start_delay=0.4, shot_count=d(5, 6, 7), interval=d(0.5, 0.42, 0.36), pause=d(1.3, 1.1, 0.95),
        bullet_count=d(6, 7, 8), parallel_spacing=d(66.0, 60.0, 56.0), aim_at_player=False, base_angle=24.0,
        bullet_speed=d(260.0, 300.0, 340.0),
        with_=[P(bullet="E_Blue_Cian", start_delay=0.25, shot_count=d(5, 6, 7), interval=d(0.5, 0.42, 0.36), pause=0.0,
                 bullet_count=d(6, 7, 8), parallel_spacing=d(66.0, 60.0, 56.0), aim_at_player=False, base_angle=-24.0,
                 bullet_speed=d(260.0, 300.0, 340.0))])),
    # ダイヤの豹変: ひし形の塊が広がって止まり、塊のまま自機へ向き直って速く突っ込んでくる
    tri("u1_diamond_turn", lambda d: P(
        bullet="E_Spiky_Split", start_delay=0.4, shot_count=d(3, 4, 4), interval=d(0.5, 0.42, 0.36), pause=d(1.5, 1.25, 1.05),
        bullet_count=d(4, 5, 6), spread_angle=d(140.0, 150.0, 160.0), aim_at_player=True,
        cluster_layers=1, cluster_spacing=8.0, bullet_speed=220.0,
        motion=[S(0.45, 0.0, trans="quad"), S(d(0.5, 0.4, 0.35), None),
                S(0.3, d(330.0, 380.0, 430.0), turn="group", trans="expo", ease="in")],
        soften_others=2.0)),
    # 黒い花火: 本体のまわりの6か所から、黒いオーブの輪が開き、すぐ速い針に割れて自機へ
    tri("u1_black_fireworks", lambda d: P(
        bullet="E_Black_Orb", start_delay=0.4, shot_count=d(2, 3, 3), interval=d(0.7, 0.6, 0.5), pause=d(1.5, 1.25, 1.05),
        bullet_count=d(5, 6, 7), spread_angle=360.0, aim_at_player=True, rotate_per_shot=15.0,
        muzzle_offsets=[(-120.0, -20.0), (-80.0, 50.0), (0.0, 80.0), (80.0, 50.0), (120.0, -20.0), (0.0, -60.0)],
        bullet_speed=d(220.0, 240.0, 260.0), split_time=0.4,
        split=P(bullet="E_Blue_Cian", bullet_count=1, aim_at_player=True, bullet_speed=d(300.0, 350.0, 400.0)))),
    # 破滅の花: 炎の花びらの輪が速く開き、その間を至近の3連の針が突き抜けてくる
    tri("u1_doom_bloom", lambda d: P(
        bullet="E_medium_flamy", start_delay=0.4, shot_count=d(3, 4, 5), interval=d(0.55, 0.48, 0.42), pause=d(1.3, 1.1, 0.95),
        bullet_count=d(14, 18, 22), spread_angle=360.0, aim_at_player=True, petal_count=6, petal_depth=0.35,
        rotate_per_shot=10.0, bullet_scale=1.2, bullet_speed=d(220.0, 250.0, 280.0),
        with_=[P(bullet="E_Magenta_Aim", start_delay=0.25, shot_count=3, interval=0.06, pause=d(0.7, 0.55, 0.45),
                 bullet_count=1, aim_at_player=True, bullet_speed=d(360.0, 410.0, 460.0))])),
]

P1.append(
    # 斑鳩の縞: 黒い弾の列と紫の弾の列を、半分ずつずらして交互に降らせる。列と列のあいだの細い道(必ずグレイズする幅)を、
    # ゆっくり左右に揺れる縞に合わせて渡っていく
    tri("u1_ikaruga_lanes", lambda d: P(
        bullet="E_Black_Orb", start_delay=0.4, shot_count=d(10, 12, 14), interval=d(0.13, 0.115, 0.1), pause=d(1.3, 1.1, 0.95),
        bullet_count=d(8, 9, 10), parallel_spacing=d(56.0, 54.0, 52.0), aim_at_player=False,
        angle_wave_amplitude=d(3.0, 3.5, 4.0), angle_wave_shots=30, bullet_speed=d(250.0, 280.0, 310.0),
        with_=[P(bullet="E_Purple_Revenge", start_delay=0.06, shot_count=d(10, 12, 14), interval=d(0.13, 0.115, 0.1), pause=0.0,
                 bullet_count=d(8, 9, 10), parallel_spacing=d(56.0, 54.0, 52.0), aim_at_player=False,
                 muzzle_offsets=[(d(28.0, 27.0, 26.0), 0.0)], angle_wave_amplitude=d(3.0, 3.5, 4.0), angle_wave_shots=30,
                 bullet_speed=d(250.0, 280.0, 310.0))])))

# ======================================================================= 第二形態「緋」(怒首領蜂大往生・大復活: 緋蜂)
# ANOTHER 版は、作者が良いと言った今のものを残す(KEEP_ANOTHER)。EASY / NORMAL / HARD だけ作り直す
P2 = [
    # 蜂の巣: 逆に回る2つの速い輪。網目がゆっくり回り、開いた目の中で、網と一緒に回る
    tri("u2_hive", lambda d: P(
        bullet="E_Blue_Cian", start_delay=0.4, shot_count=d(8, 10, 12), interval=d(0.42, 0.36, 0.32), pause=d(1.4, 1.15, 0.95),
        bullet_count=d(14, 16, 18), spread_angle=360.0, aim_at_player=False, rotate_per_shot=5.0,
        bullet_speed=d(230.0, 270.0, 310.0),
        with_=[P(bullet="E_Indigo_Slow", start_delay=0.16, shot_count=d(8, 10, 12), interval=d(0.42, 0.36, 0.32), pause=0.0,
                 bullet_count=d(14, 16, 18), spread_angle=360.0, aim_at_player=False, base_angle=10.0,
                 rotate_per_shot=-5.0, bullet_speed=d(210.0, 245.0, 280.0))])),
    # 十字架: 4本の腕の列が広がって止まり、巨大な十字になる。「+」と「×」が交互に来て、止まった十字は速く自機へ崩れ落ちる
    tri("u2_cross", lambda d: P(
        bullet="E_Lines_Yellow", start_delay=0.4, shot_count=d(3, 4, 4), interval=d(0.7, 0.6, 0.55), pause=d(1.6, 1.35, 1.15),
        bullet_count=4, spread_angle=360.0, aim_at_player=False, rotate_per_shot=45.0,
        line_count=d(6, 7, 8), line_speed_ratio=0.16, bullet_speed=d(110.0, 120.0, 130.0),
        motion=[S(0.6, 0.0, trans="quad"), S(d(0.6, 0.5, 0.45), None),
                S(0.35, d(320.0, 370.0, 420.0), turn="aim", trans="expo", ease="in")],
        soften_others=2.0)),
    # 緋の車輪(大復活の緋蜂): 速い針の輻(や)が回り、ときどき回る向きが入れ替わる。輻と輻のあいだは広い
    tri("u2_scarlet", lambda d: P(
        bullet="E_Red_Normal", start_delay=0.3, shot_count=d(30, 40, 50), interval=d(0.1, 0.085, 0.075), pause=d(1.3, 1.05, 0.9),
        bullet_count=d(4, 5, 6), spread_angle=360.0, aim_at_player=False, rotate_per_shot=d(7.0, 8.0, 9.0),
        reverse_every_shots=d(20, 18, 16), bullet_speed=d(300.0, 350.0, 400.0))),
    # 青の嵐: 広い扇を、すき間の半分ずつずらして交互に撃つ(ジグザグ)。扇のすき間を、左右に縫って前へ
    tri("u2_bluestorm", lambda d: P(
        bullet="E_Blue_Cian", start_delay=0.3, shot_count=d(6, 8, 10), interval=d(0.26, 0.22, 0.19), pause=d(1.3, 1.05, 0.9),
        bullet_count=d(7, 9, 11), spread_angle=d(100.0, 110.0, 120.0), aim_at_player=True,
        rotate_per_shot=d(8.3, 6.9, 6.0), reverse_every_shots=1, bullet_speed=d(280.0, 330.0, 380.0))),
    # 追い越しの渦(後から出る弾ほど速い): 渦を撃ちながら、撃ち出す速さをどんどん上げる。あとの腕が前の腕を追い越す
    tri("u2_overtake_spiral", lambda d: P(
        bullet="E_Purple_Revenge", start_delay=0.3, shot_count=d(20, 24, 28), interval=d(0.1, 0.085, 0.075), pause=d(1.5, 1.25, 1.05),
        bullet_count=d(3, 3, 4), spread_angle=360.0, aim_at_player=False, rotate_per_shot=d(13.0, 14.0, 15.0),
        bullet_speed=d(150.0, 165.0, 180.0), launch_speed_step=d(0.025, 0.028, 0.03))),
    # 蜂の群れ: 速い針を、広い向きへばらばらにばらまく(数は少なめ、速さで勝負)
    tri("u2_swarm", lambda d: P(
        bullet="E_Magenta_Aim", start_delay=0.3, shot_count=d(20, 28, 36), interval=d(0.11, 0.09, 0.075), pause=d(1.3, 1.05, 0.9),
        bullet_count=d(1, 2, 2), spread_angle=d(0.0, 100.0, 120.0), aim_at_player=True, random_angle=d(40.0, 30.0, 30.0),
        random_speed_ratio=0.15, random_seed=61, bullet_speed=d(300.0, 350.0, 400.0))),
    # 緋の翼: 左右の翼から、内へ曲がりながら首を振る速い流れ
    tri("u2_wings", lambda d: P(
        bullet="E_Red_Normal", start_delay=0.4, shot_count=d(18, 24, 30), interval=d(0.14, 0.12, 0.1), pause=d(1.4, 1.15, 0.95),
        bullet_count=d(2, 4, 4), spread_angle=d(150.0, 160.0, 170.0), aim_at_player=False, mirror_curve_by_side=True,
        angle_wave_amplitude=d(16.0, 20.0, 24.0), angle_wave_shots=18,
        bullet_speed=d(270.0, 310.0, 350.0), motion=[S(0.9, d(270.0, 310.0, 350.0), av=d(-50.0, -58.0, -66.0))],
        soften_others=2.0)),
    # 緋薔薇: 5枚と6枚の花びらの輪が、逆に回りながら交互に開く。花びらのくぼみが重なる所だけ通れる
    tri("u2_rose", lambda d: P(
        bullet="E_Red_Normal", start_delay=0.3, shot_count=d(3, 4, 5), interval=d(0.6, 0.5, 0.44), pause=d(1.3, 1.05, 0.9),
        bullet_count=d(15, 20, 25), spread_angle=360.0, aim_at_player=True, petal_count=5, petal_depth=0.5,
        rotate_per_shot=13.0, bullet_speed=d(220.0, 250.0, 280.0),
        with_=[P(bullet="E_Purple_Revenge", start_delay=0.3, shot_count=d(3, 4, 5), interval=d(0.6, 0.5, 0.44), pause=0.0,
                 bullet_count=d(18, 24, 30), spread_angle=360.0, aim_at_player=True, petal_count=6, petal_depth=0.45,
                 rotate_per_shot=-11.0, bullet_speed=d(190.0, 220.0, 250.0))])),
]

# ======================================================================= 第三形態「UNION」(立体弾幕 + 鬼畜 + イグナイト)
def blink_marker():
    """ANOTHER の立体の壁の代わり: 弾は撃たない目印。主砲がこれを撃ち始めたら、Union がリズムに合わせて5回瞬間移動し、
    そのたびに追い越す波動(BLINK_VOLLEY)を撃つ(UnionBoss の Blink Trigger)。Pause のあいだ、次の弾幕を待たせる"""
    return P(bullet="E_Blue_Cian", start_delay=0.2, shot_count=1, pause=3.6, bullet_count=1, gap_size=1, aim_at_player=False)  # 1発を隙間で抜く(弾は出ない)


# 追い越す波動: 輪を4重に撃ち、あとの輪ほど速い(1回撃ちきり)。輪はすき間の半分ずつずれる
BLINK_VOLLEY = OUT + "u6_blink_wave.tres"
ALL[BLINK_VOLLEY] = P(bullet="E_Blue_Cian", start_delay=0.0, shot_count=4, interval=0.07, loop=False, pause=0.0,
                      bullet_count=18, spread_angle=360.0, aim_at_player=True, rotate_per_shot=10.0,
                      bullet_speed=170.0, launch_speed_step=0.45, skip_auto_tuning=True)

NECKS = [(-150.0, -10.0), (-120.0, 40.0), (-80.0, 75.0), (-30.0, 95.0), (30.0, 95.0), (80.0, 75.0), (120.0, 40.0), (150.0, -10.0)]


def orochi(d, necks, length, speed, av, pause, rotate=0.0, reverse=0, arms=1):
    """八岐大蛇: 首(砲口)が、うねりながら伸びる。首の先頭は大きな頭の弾、胴は黒いオーブ。
    rotate を入れると、首が狙わずに回りながら伸びる(洗濯機)。reverse で回る向きが入れ替わる"""
    wiggle = [S(0.2, None, av=av)] + [S(0.4, None, av=(-av if i % 2 == 0 else av)) for i in range(6)]
    aimed = rotate == 0.0
    head = P(bullet="E_Black_Orb", muzzle_offsets=necks, start_delay=0.35, shot_count=1,
             interval=0.05 * length, pause=pause, aim_at_player=aimed, aim_once_per_burst=aimed,
             bullet_speed=speed, bullet_scale=2.0, motion=wiggle)
    body = dict(bullet="E_Black_Orb", muzzle_offsets=necks, start_delay=0.4, shot_count=length, interval=0.05, pause=pause,
                aim_at_player=aimed, aim_once_per_burst=aimed, bullet_speed=speed, motion=wiggle, soften_others=2.5,
                with_=[head])
    if not aimed:
        body.update(rotate_per_shot=rotate, reverse_every_shots=reverse, bullet_count=arms, spread_angle=360.0)
        head.update(bullet_count=arms, spread_angle=360.0)
        head.update(rotate_per_shot=rotate * length, reverse_every_shots=max(reverse // max(length, 1), 1) if reverse else 0)
    return P(**body)


P3 = [
    # 八岐大蛇: 8本の首が、ばらばらの場所から、うねりながら自機へ伸びる。首と首のあいだの、うねりで開いたすき間を読む
    tri("u3_orochi", lambda d: orochi(d, NECKS if d.lv >= 2 else (NECKS[1:7] if d.lv == 1 else NECKS[2:6]),
                                       d(10, 12, 14), d(280.0, 330.0, 380.0), d(110.0, 125.0, 140.0), d(1.6, 1.35, 1.15))),
    # 立体の壁: でんぐり返りながら回る立体の輪が、自機を狙って流れてくる。輪が正面を向いた瞬間、真ん中をくぐれる
    tri("u3_gyro_wall", lambda d: blink_marker() if d.lv == 3 else P(
        bullet="E_Blue_Cian", start_delay=0.4, shot_count=d(4, 5, 6), interval=d(0.45, 0.38, 0.33), pause=d(1.4, 1.15, 0.95),
        bullet_count=d(1, 3, 3), spread_angle=d(0.0, 40.0, 50.0), aim_at_player=True,
        ring3d_count=d(8, 9, 10), ring3d_radius=12.0, ring3d_grow=30.0, ring3d_max_radius=d(46.0, 50.0, 54.0),
        ring3d_spin=240.0, ring3d_tilt=70.0, ring3d_tumble=95.0, bullet_speed=d(220.0, 260.0, 300.0))),
    # 反撃の核(イグナイト): 巨大なカウンター弾(遅い)。イグナイトで返して当てると大きく削れる。まわりから速い針
    tri("u3_counter_core", lambda d: P(
        bullet="E_Giga", start_delay=0.5, shot_count=d(2, 2, 3), interval=0.9, pause=d(1.8, 1.5, 1.3),
        bullet_count=1, aim_at_player=True, bullet_scale=1.5,
        counter_hp_ratio=d(0.035, 0.03, 0.025), bullet_speed=d(55.0, 62.0, 70.0), soften_others=2.0,
        with_=[P(bullet="E_Magenta_Aim", start_delay=0.6, shot_count=d(3, 4, 5), interval=0.45, pause=0.0,
                 bullet_count=d(3, 3, 5), spread_angle=d(24.0, 22.0, 32.0), aim_at_player=True,
                 bullet_speed=d(320.0, 370.0, 420.0))])),
    # 立体の蜂の巣: 回る黒いオーブの立体の輪を、全方位に速く放つ(緋蜂の巣の立体版)
    tri("u3_hive3d", lambda d: P(
        bullet="E_Black_Orb", start_delay=0.4, shot_count=d(6, 8, 10), interval=d(0.5, 0.42, 0.36), pause=d(1.4, 1.15, 0.95),
        bullet_count=d(5, 6, 7), spread_angle=360.0, aim_at_player=False, rotate_per_shot=d(13.0, 14.0, 15.0),
        ring3d_count=5, ring3d_radius=12.0, ring3d_grow=12.0, ring3d_max_radius=26.0, ring3d_spin=280.0,
        ring3d_tilt=65.0, ring3d_tumble=60.0, bullet_speed=d(200.0, 235.0, 270.0))),
    # 点火の壁(イグナイト): 上から速く降る幕。切れ目は広めで、毎回ちがう所に開く。焼き切ってもよい
    tri("u3_ignite_wall", lambda d: P(
        bullet="E_Indigo_Slow", start_delay=0.4, shot_count=d(6, 8, 10), interval=d(0.6, 0.52, 0.46), pause=d(1.5, 1.25, 1.05),
        bullet_count=d(9, 10, 11), parallel_spacing=d(46.0, 42.0, 39.0), from_screen_top=True, aim_at_player=False,
        gap_size=d(3, 3, 2), gap_random=True, random_seed=41, bullet_speed=d(240.0, 280.0, 320.0), soften_others=2.0)),
    # 立体の十字架: 十字の腕に並んだ弾の1つ1つが、回る立体の輪になって広がる。「+」と「×」が交互に来る
    tri("u3_cross3d", lambda d: P(
        bullet="E_Lines_Yellow", start_delay=0.4, shot_count=d(3, 4, 5), interval=d(0.75, 0.65, 0.56), pause=d(1.4, 1.15, 0.95),
        bullet_count=4, spread_angle=360.0, aim_at_player=False, rotate_per_shot=45.0,
        line_count=d(3, 4, 5), line_speed_ratio=0.25, ring3d_count=d(4, 5, 5), ring3d_radius=8.0, ring3d_grow=8.0,
        ring3d_max_radius=16.0, ring3d_spin=300.0, ring3d_tilt=70.0, bullet_speed=d(190.0, 220.0, 250.0))),
    # 八岐大蛇・逆鱗: 画面の左右の端(上のほう)から首が伸びて、自機をはさむように、うねりながら迫る
    tri("u3_orochi_rage", lambda d: orochi(d, [(-230.0, 0.0), (-230.0, 70.0), (-230.0, 130.0), (230.0, 0.0), (230.0, 70.0), (230.0, 130.0)]
                                            if d.lv >= 1 else [(-230.0, 20.0), (-230.0, 110.0), (230.0, 20.0), (230.0, 110.0)],
                                            d(9, 11, 13), d(260.0, 310.0, 360.0), d(100.0, 115.0, 130.0), d(1.8, 1.5, 1.25))),
    # 黒い穴: 黒いオーブの輪が広がって止まり、Union へ吸い込まれるように戻って、そのまま反対側へ速く飛び出していく
    tri("u3_black_hole", lambda d: P(
        bullet="E_Black_Orb", start_delay=0.4, shot_count=d(2, 3, 3), interval=d(0.5, 0.42, 0.36), pause=d(1.8, 1.5, 1.25),
        bullet_count=d(12, 14, 16), spread_angle=360.0, aim_at_player=False, rotate_per_shot=11.0, launch_speed_step=0.12,
        bullet_speed=220.0, motion=[S(0.45, 0.0, trans="quad"), S(d(0.5, 0.4, 0.35), None),
                                    S(0.05, 0.0, turn="add", angle=180.0), S(1.0, d(300.0, 350.0, 400.0), trans="quad", ease="in")],
        soften_others=2.0)),
]

P3.append(
    # 斑鳩の螺旋: 黒と紫の、逆に回る4本腕の渦。交差する腕のあいだの細い所を、グレイズしながら抜ける
    tri("u3_ikaruga_helix", lambda d: P(
        bullet="E_Black_Orb", start_delay=0.3, shot_count=d(30, 40, 50), interval=d(0.09, 0.075, 0.065), pause=d(1.3, 1.1, 0.95),
        bullet_count=d(3, 4, 4), spread_angle=360.0, aim_at_player=False, rotate_per_shot=d(10.0, 11.0, 12.0),
        bullet_speed=d(250.0, 285.0, 320.0),
        with_=[P(bullet="E_Purple_Revenge", start_delay=0.045, shot_count=d(30, 40, 50), interval=d(0.09, 0.075, 0.065), pause=0.0,
                 bullet_count=d(3, 4, 4), spread_angle=360.0, aim_at_player=False, base_angle=45.0,
                 rotate_per_shot=d(-10.0, -11.0, -12.0), bullet_speed=d(250.0, 285.0, 320.0))])))

# ======================================================================= 最期のカウンター大技「終焉の産声」
SPELL = [
    tri("u4_residue", lambda d: P(   # 残留弾の渦(自分からグレイズしにいく。遅い)
        bullet="E_Pink_Medium", start_delay=0.3, shot_count=d(24, 30, 36), interval=0.14, pause=0.6,
        bullet_count=d(3, 3, 4), spread_angle=360.0, aim_at_player=False, rotate_per_shot=13.0,
        bullet_speed=90.0, motion=[S(0.9, 6.0, trans="quad"), S(3.0, None), S(1.2, 55.0, trans="quad", ease="in")])),
    tri("u4_giants", lambda d: P(    # カウンター弾: 巨大弾の輪。返すと、Union の命を削る
        bullet="E_Giga", start_delay=1.2, shot_count=1, pause=d(3.2, 2.8, 2.4),
        bullet_count=d(3, 4, 5), spread_angle=360.0, aim_at_player=True, bullet_scale=1.5,
        counter_hp_ratio=0.05, bullet_speed=48.0)),
    # 洗濯機の八岐大蛇: 首が狙わずに回りながら伸び、ときどき回る向きが入れ替わる
    tri("u4_orochi_washer", lambda d: orochi(d, [(0.0, 40.0)] * 1, d(40, 50, 60), d(240.0, 270.0, 300.0), d(60.0, 70.0, 80.0),
                                             d(1.6, 1.4, 1.2), rotate=d(9.0, 10.0, 11.0), reverse=d(30, 26, 22), arms=d(3, 4, 4))),
    # 逆洗濯機の八岐大蛇: 反対向きに回る首(洗濯機と交差して、網の目を作る)
    tri("u4_orochi_washer_rev", lambda d: orochi(d, [(0.0, 40.0)] * 1, d(40, 50, 60), d(220.0, 250.0, 280.0), d(-60.0, -70.0, -80.0),
                                                 d(1.6, 1.4, 1.2), rotate=d(-9.0, -10.0, -11.0), reverse=d(30, 26, 22), arms=d(3, 4, 4))),
]

# ======================================================================= 突進しながら撃つ弾幕(UnionBoss の Rush Patterns)
RUSH = [
    # 黒いオーブの幕: 横切る Union の下から、黒いオーブが落ちながら加速する(まばら)
    tri("u5_rush_curtain", lambda d: P(
        bullet="E_Black_Orb", start_delay=0.0, shot_count=60, interval=d(0.16, 0.13, 0.11), pause=0.0,
        bullet_count=1, aim_at_player=False, random_shot_angle=d(4.0, 6.0, 8.0), random_seed=51,
        bullet_speed=60.0, bullet_accel=d(260.0, 320.0, 380.0))),
    # 速い自機狙い: 突進しながら、自機へ3wayを撃ち下ろす
    tri("u5_rush_aim", lambda d: P(
        bullet="E_Magenta_Aim", start_delay=0.15, shot_count=5, interval=d(0.32, 0.27, 0.23), pause=0.0,
        bullet_count=d(1, 3, 3), spread_angle=d(0.0, 18.0, 16.0), aim_at_player=True, bullet_speed=d(320.0, 370.0, 420.0))),
]


def flat(groups):
    out = []
    for g in groups:
        out.extend(g)
    return out


# ======================================================================= シーン
SCENE = "GameScene/Enemy/SECRET/union_boss.tscn"
HP = 90000


def build_scene():
    ext = []
    ids = {}

    def ext_id(rtype, path, rid=None):
        if path in ids:
            return ids[path]
        rid = rid or "r%d" % (len(ids) + 1)
        ids[path] = rid
        ext.append('[ext_resource type="%s" path="%s" id="%s"]' % (rtype, path, rid))
        return rid

    base = ext_id("PackedScene", "res://GameScene/Enemy/Enemy.tscn", "base")
    shot = ext_id("Script", "res://Resources/ShotPatterns/shot_pattern.gd", "shot_script")
    sphase = ext_id("Script", "res://shooter_phase.gd", "shooter_phase")
    bphase = ext_id("Script", "res://boss_phase.gd", "boss_phase")
    ctrl = ext_id("Script", "res://boss_phase_controller.gd", "phase_controller")
    view = ext_id("Script", "res://Component/Boss/union_view.gd", "union_view")
    boss = ext_id("Script", "res://Component/Boss/union_boss.gd", "union_boss")
    rage = ext_id("Script", "res://Component/Boss/boss_rampage.gd", "boss_rampage")
    spell = ext_id("Script", "res://Component/Boss/counter_spell.gd", "counter_spell")
    aura = ext_id("Script", "res://Component/Boss/union_aura.gd", "union_aura")

    def arr(paths):
        return 'Array[ExtResource("%s")]([%s])' % (shot, ", ".join('ExtResource("%s")' % ext_id("Resource", p) for p in paths))

    subs = []
    for i, group in enumerate([P1, P2, P3]):
        subs.append('[sub_resource type="Resource" id="union_p%d"]\nscript = ExtResource("%s")\nsequence = %s'
                    % (i + 1, sphase, arr(flat(group))))
    for i, ratio in enumerate([1.0, 0.66, 0.33]):
        mod = ["Color(1, 1, 1, 1)", "Color(1, 0.85, 0.9, 1)", "Color(1, 0.6, 0.65, 1)"][i]
        subs.append('[sub_resource type="Resource" id="union_phase_%d"]\nscript = ExtResource("%s")\nhp_ratio = %s\nboss_modulate = %s'
                    % (i + 1, bphase, ratio, mod))
    subs.append('[sub_resource type="CircleShape2D" id="union_shape"]\nradius = 92.0')
    spell_arr = arr(flat(SPELL))
    rush_arr = arr(flat(RUSH))
    blink_trigger = 'ExtResource("%s")' % ext_id("Resource", OUT + "u3_gyro_wall_a.tres")
    blink_volley = 'ExtResource("%s")' % ext_id("Resource", BLINK_VOLLEY)

    nodes = f'''[node name="Union" instance=ExtResource("{base}")]
pattern = null

[node name="Sprite2D" parent="." index="0"]
visible = false

[node name="CollisionShape2D" parent="." index="1"]
shape = SubResource("union_shape")

[node name="CollisionShape2D" parent="Hurtbox" index="0"]
shape = SubResource("union_shape")

[node name="HPComponent" parent="." index="3"]
max_hp = {HP}
hp = {HP}

[node name="EnemyShooterComponent" parent="." index="4"]
position = Vector2(0, 40)
only_when_on_screen = false
phases = Array[ExtResource("{sphase}")]([SubResource("union_p1"), SubResource("union_p2"), SubResource("union_p3")])

[node name="DeathExplosion" parent="." index="6"]
area = Rect2(-120, -120, 240, 240)

[node name="ScoreReward" parent="." index="8"]
score_value = 300000

[node name="UnionAura" type="Node2D" parent="."]
script = ExtResource("{aura}")

[node name="UnionView" type="Node2D" parent="."]
z_index = 1
script = ExtResource("{view}")

[node name="UnionAuraFront" type="Node2D" parent="."]
z_index = 2
script = ExtResource("{aura}")
front = true
radius = 135.0

[node name="BossPhaseController" type="Node" parent="."]
script = ExtResource("{ctrl}")
phases = Array[ExtResource("{bphase}")]([SubResource("union_phase_1"), SubResource("union_phase_2"), SubResource("union_phase_3")])

[node name="UnionBoss" type="Node" parent="."]
script = ExtResource("{boss}")
rush_patterns = {rush_arr}
blink_trigger = {blink_trigger}
blink_volley = {blink_volley}

[node name="BossRampage" type="Node" parent="."]
script = ExtResource("{rage}")
title = "UNION"
subtitle = "暴走 -融合体の咆哮-"
pause_scale = 0.85

[node name="CounterSpell" type="Node" parent="."]
script = ExtResource("{spell}")
spell_name = "UNION -終焉の産声-"
lethal = true
duration = 18.0
patterns = {spell_arr}
'''
    text = "[gd_scene format=3]\n\n" + "\n".join(ext) + "\n\n" + "\n\n".join(subs) + "\n\n" + nodes
    path = os.path.join(ROOT, SCENE)
    if os.path.exists(path):
        first = open(path, encoding="utf-8").read().split("\n", 1)[0]
        if 'uid="' in first:
            text = first + text[text.index("\n"):]
    open(path, "w", encoding="utf-8", newline="\n").write(text)


if __name__ == "__main__":
    for path, p in ALL.items():
        write(path, p)
    build_scene()
    print("wrote", len(ALL), "patterns and", SCENE)
