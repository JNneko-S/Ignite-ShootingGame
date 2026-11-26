"""二周目(Another Round)のボス・中ボスの弾幕。Run: python loop2.py [名前の一部 ...]

方針(作者の指示):
  ・実力があれば避けられる弾幕。イグナイトは必須ではない(使うと削る速さが上がる)
  ・主砲と副砲は組み合わせてよいが、同時に撃って逃げ道をふさぎ、イグナイトを使わざるを得ない攻撃はしない
    (重い主砲の攻撃は Soften Others で、副砲の Yields の弾幕をやさしくする)
  ・弾数の上限ではなく、よけやすさ・綺麗さ・弾の幅・発射頻度・自機の当たり判定が通れるかで調整する
  ・形態ごとに「癖のある避け方」を要求する弾幕を1つ(Q_ の印。説明は QUIRKS)
難易度ごとに手で作った限定弾幕(EASY / NORMAL / HARD の3つ。選んだ難易度で撃つ。自動の調整はしない)。
"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from shotgen import P, S, write

L2 = "res://Resources/ShotPatterns/Loop2/"
LV = "enh"

ALL = {}
QUIRKS = {}


class D:
    def __init__(self, lv):
        self.lv = lv

    def __call__(self, e, n, h):
        return (e, n, h)[self.lv]


def only(lv):
    return dict(min_difficulty=lv, max_difficulty=lv, skip_auto_tuning=True)


def tri(name, fn, quirk=None):
    """name の弾幕を3つの難易度ぶん作る。戻り値: [e, n, h] のパス"""
    paths = []
    for lv in range(3):
        p = fn(D(lv))
        p.update(only(lv))
        for w in p.get("with_") or []:
            if isinstance(w, dict):
                w["skip_auto_tuning"] = True   # 一緒に撃つ弾幕も、手で決めた数と速さのまま
        path = L2 + "%s_%s.tres" % (name, LV[lv])
        ALL[path] = p
        paths.append(path)
    if quirk:
        QUIRKS[name] = quirk
    return paths


# ======================================================================= 1面 中ボス(分裂機)
MB1 = [
    tri("mb1_wave", lambda d: P(
        bullet="E_Magenta_Aim", start_delay=0.6, shot_count=3, interval=d(0.2, 0.16, 0.13), pause=d(1.5, 1.2, 0.95),
        bullet_count=d(3, 5, 7), spread_angle=d(36.0, 52.0, 66.0), aim_at_player=True, aim_once_per_burst=True,
        bullet_speed=d(115.0, 140.0, 165.0),
        with_=[P(bullet="E_Blue_Cian", start_delay=0.45, shot_count=1, pause=0.0, bullet_count=d(12, 16, 20),
                 spread_angle=360.0, aim_at_player=True, base_angle=180.0 / d(12, 16, 20), bullet_speed=d(55.0, 62.0, 70.0))])),
    tri("mb1_rotor", lambda d: P(
        bullet="E_Blue_Cian", start_delay=0.3, shot_count=d(14, 18, 22), interval=d(0.2, 0.16, 0.13), pause=d(1.4, 1.1, 0.9),
        bullet_count=d(4, 5, 6), spread_angle=360.0, aim_at_player=False, rotate_per_shot=d(13.0, 14.0, 15.0),
        reverse_every_shots=d(7, 9, 11), bullet_speed=d(80.0, 95.0, 110.0))),
]

# ======================================================================= 1面 ボス(戦車)
TANK = [
    # 第一形態
    [
        tri("t1_needle", lambda d: P(   # ケツイ風: 至近の高速3way針 + 少し遅れて広がる遅い扇
            bullet="E_Magenta_Aim", start_delay=0.5, shot_count=d(4, 6, 7), interval=d(0.18, 0.13, 0.1), pause=d(1.5, 1.15, 0.9),
            bullet_count=3, spread_angle=d(30.0, 24.0, 20.0), aim_at_player=True, bullet_speed=d(150.0, 185.0, 215.0),
            with_=[P(bullet="E_Blue_Cian", start_delay=0.55, shot_count=2, interval=0.55, pause=0.0,
                     bullet_count=d(7, 11, 15), spread_angle=d(110.0, 140.0, 160.0), aim_at_player=True,
                     bullet_speed=d(58.0, 68.0, 78.0))])),
        tri("t1_flower", lambda d: P(
            bullet="E_Red_Normal", start_delay=0.4, shot_count=d(3, 4, 5), interval=0.4, pause=d(1.4, 1.1, 0.9),
            bullet_count=d(20, 28, 36), spread_angle=360.0, aim_at_player=True, petal_count=5, petal_depth=0.35,
            rotate_per_shot=7.0, bullet_speed=d(64.0, 76.0, 88.0))),
        tri("t1_q_tapstream", lambda d: P(   # 癖: チョン避けの釘
            bullet="E_Magenta_Aim", start_delay=0.5, shot_count=d(10, 14, 18), interval=d(0.14, 0.11, 0.085), pause=d(1.5, 1.2, 1.0),
            bullet_count=1, aim_at_player=True, bullet_speed=d(160.0, 190.0, 215.0), soften_others=2.0,
            with_=[P(bullet="E_Indigo_Slow", start_delay=0.2, shot_count=3, interval=d(0.8, 0.7, 0.62), pause=0.0,
                     bullet_count=d(20, 26, 32), spread_angle=360.0, aim_at_player=True, gap_size=d(6, 5, 4), gap_random=True,
                     random_seed=11, bullet_speed=d(46.0, 52.0, 58.0))]),
            quirk=("1面ボス・第一形態「チョン避けの釘」",
                   "自機をずっと狙う速い1本の弾の列と、ゆっくり広がる穴あきの輪を重ねる。大きく動くと輪の弾にぶつかるので、"
                   "釘(自機狙い)は小刻みに横へずれて(チョン避け)流し、輪の穴が来たら、そこで向きを変えて(切り返して)くぐる。",
                   "ケツイの、ボスが撃つ速い自機狙いの連射。ケツイでは高速弾をチョン避けでかわすのが基本なので、それを"
                   "遅い輪と組み合わせ、「小さく動く」「穴で切り返す」を同時に要求する形にした")),
    ],
    # 第二形態
    [
        tri("t2_rows", lambda d: P(   # 列弾(速さの違う弾を重ねた扇)
            bullet="E_Blue_Cian", start_delay=0.4, shot_count=d(3, 4, 4), interval=d(0.55, 0.48, 0.42), pause=d(1.3, 1.05, 0.85),
            bullet_count=d(5, 7, 9), spread_angle=d(64.0, 78.0, 90.0), line_count=d(2, 3, 4), line_speed_ratio=0.14,
            aim_at_player=True, bullet_speed=d(90.0, 108.0, 125.0))),
        tri("t2_spiral", lambda d: P(
            bullet="E_Red_Normal", start_delay=0.3, shot_count=d(30, 40, 48), interval=d(0.12, 0.095, 0.08), pause=d(1.2, 1.0, 0.8),
            bullet_count=d(3, 4, 5), spread_angle=360.0, aim_at_player=False, rotate_per_shot=d(11.0, 12.5, 14.0),
            bullet_speed=d(78.0, 92.0, 106.0),
            with_=[P(bullet="E_Magenta_Aim", start_delay=1.0, shot_count=d(2, 3, 4), interval=1.0, pause=0.0,
                     bullet_count=1, aim_at_player=True, bullet_speed=d(130.0, 150.0, 170.0))])),
        tri("t2_q_pendulum", lambda d: P(   # 癖: 振り子スパイラル
            bullet="E_Green_Curve", start_delay=0.4, shot_count=d(44, 56, 66), interval=d(0.1, 0.085, 0.072), pause=d(1.5, 1.2, 1.0),
            bullet_count=d(4, 5, 6), spread_angle=360.0, aim_at_player=False, rotate_per_shot=d(9.0, 10.5, 12.0),
            reverse_every_shots=d(16, 14, 12), bullet_speed=d(76.0, 88.0, 100.0), soften_others=2.0),
            quirk=("1面ボス・第二形態「振り子スパイラル」",
                   "回る渦が、決まった数を撃つごとに逆回りに切り替わる。渦の腕と腕の間に入って一緒に回っていると、"
                   "切り替わった瞬間に腕が戻ってくるので、反転を見てすぐ逆へ切り返す。回る向きに合わせて小さく回り続けるのがコツ。",
                   "怒首領蜂大往生のボスの、回る向きが入れ替わる渦(いわゆる洗濯機)。反転の間隔を短めにして、"
                   "腕の間で「回る→止まる→逆へ」のリズムを刻ませる形にした")),
    ],
    # 第三形態
    [
        tri("t3_burst", lambda d: P(
            bullet="E_Spiky_Split", start_delay=0.4, shot_count=2, interval=0.85, pause=d(1.5, 1.2, 1.0),
            bullet_count=d(4, 5, 6), spread_angle=360.0, aim_at_player=True, bullet_speed=150.0,
            motion=[S(0.7, 0.0, trans="quad")], split_time=1.0,
            split=P(bullet="E_Blue_Cian", bullet_count=d(7, 9, 11), spread_angle=360.0, aim_at_player=False,
                    bullet_speed=d(46.0, 54.0, 62.0), bullet_accel=d(18.0, 24.0, 30.0)))),
        tri("t3_lace", lambda d: P(   # 左右に開いて内側へ曲がり、自機の位置で交わる
            bullet="E_Green_Curve", start_delay=0.3, shot_count=d(5, 7, 9), interval=d(0.24, 0.19, 0.15), pause=d(1.4, 1.1, 0.9),
            bullet_count=2, spread_angle=d(100.0, 110.0, 120.0), aim_at_player=True, mirror_curve_by_side=True,
            bullet_speed=d(120.0, 140.0, 160.0), motion=[S(1.3, d(110.0, 125.0, 140.0), av=d(-46.0, -52.0, -58.0))],
            with_=[P(bullet="E_Magenta_Aim", start_delay=0.2, shot_count=d(5, 7, 9), interval=d(0.24, 0.19, 0.15), pause=0.0,
                     bullet_count=1, aim_at_player=True, bullet_speed=d(120.0, 140.0, 160.0))])),
        tri("t3_q_turncoat", lambda d: P(   # 癖: 豹変弾
            bullet="E_Pink_Medium", start_delay=0.4, shot_count=d(2, 3, 3), interval=d(0.9, 0.75, 0.6), pause=d(1.6, 1.3, 1.1),
            bullet_count=d(9, 13, 17), spread_angle=d(130.0, 150.0, 170.0), aim_at_player=True,
            bullet_speed=160.0, motion=[S(0.6, 0.0, trans="quad"), S(0.35, None), S(0.5, d(150.0, 175.0, 200.0), turn="aim")],
            soften_others=2.5),
            quirk=("1面ボス・第三形態「豹変弾」",
                   "扇に広がった弾がいったん止まり、止まった直後にいっせいに自機の方へ向き直って飛んでくる。向き直るのは"
                   "「その瞬間の自機の位置」なので、止まっている間はじっとして弾を引きつけ、向き直った直後に小さく横へずれると、"
                   "全部の弾が元いた場所に集まって抜けられる。焦って大きく動くと、狙いがばらけて逃げ道がなくなる。",
                   "ケツイの豹変弾(止まってから自機狙いに変わる弾)。ケツイでは弾の向きが変わる瞬間に動くのが要なので、"
                   "扇いっぱいの弾を一度に豹変させ、「引きつけてから最小限ずれる」動きを要求する形にした")),
    ],
]

# ======================================================================= 2面 中ボス(快速・急行の列車)
TRAIN_MB = [
    tri("tm_fan", lambda d: P(
        bullet="E_Blue_Cian", start_delay=0.8, shot_count=d(2, 3, 3), interval=0.3, pause=d(1.8, 1.45, 1.2),
        bullet_count=d(5, 7, 9), spread_angle=d(60.0, 76.0, 90.0), aim_at_player=True, bullet_speed=d(95.0, 112.0, 128.0))),
    tri("tm_aim", lambda d: P(
        bullet="E_Magenta_Aim", start_delay=1.2, shot_count=d(3, 4, 5), interval=d(0.16, 0.12, 0.1), pause=d(2.0, 1.6, 1.3),
        bullet_count=1, aim_at_player=True, bullet_speed=d(140.0, 165.0, 190.0))),
]

# ======================================================================= 2面 ボス(特急列車)。主砲 Gun_m_top の弾幕(Gun_m_mid は、隙に撃つ補助)
TRAIN = [
    [
        tri("tr1_spread", lambda d: P(
            bullet="E_Red_Normal", start_delay=0.4, shot_count=d(3, 4, 5), interval=0.32, pause=d(1.3, 1.05, 0.85),
            bullet_count=d(7, 9, 11), spread_angle=d(80.0, 96.0, 110.0), aim_at_player=True, rotate_per_shot=6.0,
            reverse_every_shots=2, bullet_speed=d(92.0, 108.0, 124.0))),
        tri("tr1_q_railgap", lambda d: P(   # 癖: うねる線路
            bullet="E_Lines_Yellow", start_delay=0.4, shot_count=d(16, 20, 24), interval=d(0.36, 0.3, 0.26), pause=d(1.5, 1.2, 1.0),
            bullet_count=d(9, 11, 13), parallel_spacing=d(44.0, 38.0, 33.0), aim_at_player=False,
            gap_size=d(3, 2, 2), gap_wave_amplitude=d(0.45, 0.55, 0.6), gap_wave_shots=d(14, 12, 10),
            bullet_speed=d(82.0, 96.0, 110.0), soften_others=2.0),
            quirk=("2面ボス・第一形態「うねる線路」",
                   "横一列の弾の壁が続けて流れてきて、壁の切れ目(線路)が左右にくねくね動く。切れ目は少しずつしか動かないので、"
                   "壁が来るたびに切れ目へ寄せていくと、曲がりくねった1本の道になる。大きく先回りすると、次の壁の切れ目から外れてしまう。",
                   "東方永夜抄の、弾の壁にできた通り道をたどる弾幕(慧音の弾幕のような、道が動く壁)。列車のボスに合わせて、"
                   "通り道を線路のようにうねらせた")),
    ],
    [
        tri("tr2_ring", lambda d: P(
            bullet="E_Blue_Cian", start_delay=0.3, shot_count=d(4, 5, 6), interval=d(0.5, 0.42, 0.36), pause=d(1.3, 1.05, 0.85),
            bullet_count=d(18, 24, 30), spread_angle=360.0, aim_at_player=True, base_angle=6.0, rotate_per_shot=6.0,
            bullet_speed=d(70.0, 82.0, 94.0))),
        tri("tr2_q_crossfire", lambda d: P(   # 癖: 交差砲火
            bullet="E_Magenta_Aim", start_delay=0.4, shot_count=d(6, 8, 10), interval=d(0.3, 0.24, 0.2), pause=d(1.5, 1.2, 1.0),
            bullet_count=d(3, 3, 5), spread_angle=d(10.0, 12.0, 20.0), muzzle_offsets=[(-150.0, 0.0), (150.0, 0.0)],
            aim_at_player=True, bullet_speed=d(115.0, 135.0, 155.0), soften_others=2.0,
            with_=[P(bullet="E_Blue_Cian", start_delay=0.6, shot_count=d(2, 3, 3), interval=1.1, pause=0.0,
                     bullet_count=d(5, 7, 9), spread_angle=d(50.0, 60.0, 70.0), aim_at_player=True,
                     bullet_speed=d(70.0, 80.0, 90.0))]),
            quirk=("2面ボス・第二形態「交差砲火」",
                   "列車の左右の端から、自機狙いの細い弾の列が交互に飛んでくる。2本の列は自機の場所で交わるので、"
                   "交わる点の手前で止まらず、交わったあとに開く「X の奥」へ抜けるように、片方の列に沿って小さく流す。"
                   "真ん中から撃つ遅い扇の隙間も、同じ向きに流れながら探す。",
                   "怒首領蜂大往生の、左右の砲台がそれぞれ自機を狙って撃つ挟み撃ち。2つの砲口が同時に狙うと逃げ道が"
                   "なくなるので、撃つ時間を交互にずらし、主砲の扇も遅らせて、流せば必ず抜けられるようにした")),
    ],
    [
        tri("tr3_burst", lambda d: P(
            bullet="E_Spiky_Split", start_delay=0.4, shot_count=d(2, 3, 3), interval=0.7, pause=d(1.5, 1.2, 1.0),
            bullet_count=d(3, 3, 5), spread_angle=d(50.0, 60.0, 90.0), aim_at_player=True, bullet_speed=120.0,
            motion=[S(0.8, 30.0, trans="quad")], split_time=0.9,
            split=P(bullet="E_Red_Normal", bullet_count=d(6, 8, 10), spread_angle=360.0, aim_at_player=True,
                    bullet_speed=d(60.0, 70.0, 80.0)))),
        tri("tr3_q_boomerang", lambda d: P(   # 癖: ブーメラン
            bullet="E_Purple_Revenge", start_delay=0.4, shot_count=d(3, 4, 5), interval=d(0.7, 0.6, 0.5), pause=d(1.6, 1.3, 1.1),
            bullet_count=d(10, 14, 18), spread_angle=d(150.0, 170.0, 190.0), aim_at_player=True,
            bullet_speed=d(120.0, 135.0, 150.0),
            motion=[S(0.9, 0.0, trans="quad"), S(0.3, None, turn="add", angle=180.0), S(1.2, d(70.0, 82.0, 95.0), trans="quad", ease="in")],
            with_=[P(bullet="E_Magenta_Aim", start_delay=1.1, shot_count=d(2, 3, 3), interval=0.6, pause=0.0,
                     bullet_count=1, aim_at_player=True, bullet_speed=d(130.0, 150.0, 170.0))],
            soften_others=2.5),
            quirk=("2面ボス・第三形態「ブーメラン」",
                   "大きな扇が広がって止まり、くるりと向きを変えて、来た道を列車の方へ戻っていく。戻る弾は撃った時の扇の形の"
                   "まま縮むので、扇が広がっている間は扇の外側(下)で待ち、戻り始めたら弾がいなくなった広い場所へ前に出る。"
                   "戻る途中の自機狙いは、扇の外で小さくよける。",
                   "東方永夜抄の、いったん広がった弾が戻ってくる弾幕(行って戻る弾)。行きと帰りで安全な場所が入れ替わるので、"
                   "前後に動く避けを要求する形にした")),
    ],
]
TRAIN_MID = [   # Gun_m_mid: 主砲の隙に撃つ、ゆずる補助(主砲の重い攻撃のあいだは、やさしくなる)
    tri("tr_mid_aim", lambda d: P(
        bullet="E_Magenta_Aim", start_delay=1.6, shot_count=d(2, 3, 3), interval=0.18, pause=d(3.2, 2.6, 2.2),
        bullet_count=d(1, 3, 3), spread_angle=d(0.0, 18.0, 16.0), aim_at_player=True, bullet_speed=d(120.0, 140.0, 160.0),
        yields=True)),
]

# ======================================================================= 3面 中ボス(ブラックスワンズ)
SWANS_MB = [
    tri("sw_wave", lambda d: P(
        bullet="E_Blue_Cian", start_delay=0.5, shot_count=d(10, 14, 18), interval=d(0.16, 0.13, 0.11), pause=d(1.5, 1.2, 1.0),
        bullet_count=d(3, 5, 5), spread_angle=d(40.0, 60.0, 56.0), aim_at_player=True, angle_wave_amplitude=d(18.0, 22.0, 26.0),
        angle_wave_shots=d(10, 12, 14), bullet_speed=d(110.0, 130.0, 150.0))),
    tri("sw_ring", lambda d: P(
        bullet="E_Red_Normal", start_delay=0.4, shot_count=d(2, 3, 4), interval=0.45, pause=d(1.6, 1.3, 1.1),
        bullet_count=d(14, 18, 22), spread_angle=360.0, aim_at_player=True, base_angle=180.0 / 18.0,
        bullet_speed=d(66.0, 78.0, 90.0))),
]

# ======================================================================= 3面 ボス(ブラックスワン改)
KAI = [
    [
        tri("k1_aimfan", lambda d: P(
            bullet="E_Magenta_Aim", start_delay=0.4, shot_count=d(3, 4, 5), interval=d(0.2, 0.16, 0.13), pause=d(1.3, 1.05, 0.85),
            bullet_count=d(3, 5, 5), spread_angle=d(24.0, 36.0, 30.0), aim_at_player=True, bullet_speed=d(150.0, 175.0, 200.0))),
        tri("k1_q_rainbow", lambda d: P(   # 癖: 三重の輪(二段避け)
            bullet="E_Red_Normal", start_delay=0.4, shot_count=d(2, 3, 3), interval=1.0, pause=d(1.6, 1.3, 1.1),
            bullet_count=d(18, 22, 26), spread_angle=360.0, aim_at_player=True, base_angle=7.0, bullet_speed=d(105.0, 120.0, 135.0),
            with_=[P(bullet="E_Blue_Cian", start_delay=0.18, shot_count=d(2, 3, 3), interval=1.0, pause=0.0,
                     bullet_count=d(14, 18, 22), spread_angle=360.0, aim_at_player=True, base_angle=0.0,
                     bullet_speed=d(72.0, 82.0, 92.0)),
                   P(bullet="E_medium_flamy", start_delay=0.36, shot_count=d(2, 3, 3), interval=1.0, pause=0.0,
                     bullet_count=d(10, 12, 16), spread_angle=360.0, aim_at_player=True, base_angle=12.0,
                     bullet_speed=d(44.0, 50.0, 56.0))],
            soften_others=2.0),
            quirk=("3面ボス・第一形態「三重の輪」",
                   "速い赤・ふつうの青・遅い炎の、速さの違う3つの輪を少しずつずらして撃つ。速い輪から順に追い越していくので、"
                   "まず速い輪の隙間をくぐって前(ボス側)へ出て、それから遅い輪の隙間が来るのを待ってもう一度くぐる「二段避け」になる。"
                   "1つの輪を下がりながらよけ続けると、後ろの遅い輪に追いつかれて挟まれる。",
                   "東方永夜抄の輝夜「蓬莱の玉の枝 -夢色の郷-」の、色ごとに速さの違う弾が重なって広がる弾幕。"
                   "色の層を3つに整理して、層ごとに隙間の位置をずらし、層の間に入り直す避け方にした")),
    ],
    [
        tri("k2_band", lambda d: P(
            bullet="E_Blue_Cian", start_delay=0.3, shot_count=d(20, 26, 32), interval=d(0.2, 0.16, 0.13), pause=d(1.2, 1.0, 0.8),
            bullet_count=d(10, 12, 14), spread_angle=360.0, aim_at_player=False, rotate_per_shot=d(5.0, 6.0, 7.0),
            window_width_deg=d(50.0, 60.0, 70.0), window_speed_deg=d(70.0, 85.0, 100.0), window_big_scale=1.9,
            bullet_speed=d(72.0, 84.0, 96.0))),
        tri("k2_q_snake", lambda d: P(   # 癖: 蛇行流
            bullet="E_Lines_Yellow", start_delay=0.4, shot_count=d(40, 52, 64), interval=d(0.085, 0.07, 0.06), pause=d(1.6, 1.3, 1.1),
            bullet_count=d(3, 3, 4), spread_angle=d(70.0, 84.0, 108.0), aim_at_player=True, aim_once_per_burst=True,
            angle_wave_amplitude=d(26.0, 30.0, 34.0), angle_wave_shots=d(26, 24, 22), bullet_speed=d(120.0, 140.0, 160.0),
            soften_others=2.0),
            quirk=("3面ボス・第二形態「蛇行流」",
                   "何本かの弾の流れが、蛇のように左右へゆらゆら揺れながら降ってくる。流れと流れの間に入り、揺れに合わせて"
                   "同じ向きに動き、揺れが折り返す瞬間に一緒に切り返す。流れを横切ろうとすると、揺れの山にぶつかる。",
                   "怒首領蜂最大往生のボスの、左右に振れる弾の流れ(首を振る砲台の連射)。流れの本数を絞り、"
                   "揺れの周期をゆっくりにして、揺れに乗る避け方にした")),
    ],
    [
        tri("k3_needle", lambda d: P(
            bullet="E_Magenta_Aim", start_delay=0.3, shot_count=d(6, 8, 10), interval=d(0.16, 0.13, 0.1), pause=d(1.2, 1.0, 0.8),
            bullet_count=d(3, 5, 5), spread_angle=d(36.0, 48.0, 40.0), aim_at_player=True, aim_once_per_burst=True,
            random_shot_angle=d(4.0, 6.0, 8.0), bullet_speed=d(150.0, 175.0, 200.0))),
        tri("k3_q_dragon", lambda d: P(   # 癖: 五色の弧
            bullet="E_Green_Curve", start_delay=0.4, shot_count=d(22, 28, 34), interval=d(0.16, 0.13, 0.11), pause=d(1.6, 1.3, 1.1),
            bullet_count=5, spread_angle=360.0, aim_at_player=False, rotate_per_shot=d(8.0, 9.0, 10.0),
            bullet_speed=d(110.0, 125.0, 140.0), motion=[S(0.6, 40.0, trans="quad"), S(1.4, d(90.0, 105.0, 120.0), av=d(34.0, 40.0, 46.0))],
            with_=[P(bullet="E_Purple_Revenge", start_delay=0.08, shot_count=d(22, 28, 34), interval=d(0.16, 0.13, 0.11), pause=0.0,
                     bullet_count=5, spread_angle=360.0, aim_at_player=False, base_angle=36.0, rotate_per_shot=d(-8.0, -9.0, -10.0),
                     bullet_speed=d(110.0, 125.0, 140.0),
                     motion=[S(0.6, 40.0, trans="quad"), S(1.4, d(90.0, 105.0, 120.0), av=d(-34.0, -40.0, -46.0))])],
            soften_others=2.5),
            quirk=("3面ボス・第三形態「五色の弧」",
                   "5方向へ出た弾がいったん遅くなってから、左回りと右回りに曲がりながら加速する。2色の弧が交差して、回る網の目に"
                   "なる。網の目は外へ流れながら回るので、目の1つに入ったら、その目と一緒に回り込むように動き続ける。止まると目の"
                   "ふちに当たる。",
                   "東方永夜抄の輝夜「難題『龍の頸の玉 -五色の弾丸-』」の、曲がる弾の弧が重なる弾幕。色を2つに絞り、"
                   "逆向きに曲げて網の目を作り、目ごと回り込む避け方にした")),
    ],
]

# ======================================================================= 4面 ボス1(タンク改)
TKAI = [
    [
        tri("tk1_ring", lambda d: P(
            bullet="E_Blue_Cian", start_delay=0.3, shot_count=d(3, 4, 5), interval=0.45, pause=d(1.3, 1.05, 0.85),
            bullet_count=d(18, 24, 30), spread_angle=360.0, aim_at_player=True, gap_size=d(5, 4, 4), gap_random=True,
            random_seed=5, bullet_speed=d(72.0, 84.0, 96.0))),
        tri("tk1_q_diamond", lambda d: P(   # 癖: ダイヤの塊
            bullet="E_Spiky_Split", start_delay=0.4, shot_count=d(4, 5, 6), interval=d(0.42, 0.36, 0.3), pause=d(1.5, 1.2, 1.0),
            bullet_count=d(1, 3, 3), spread_angle=d(0.0, 44.0, 36.0), aim_at_player=True, cluster_layers=d(1, 1, 2),
            cluster_spacing=8.0, bullet_speed=d(120.0, 140.0, 160.0), soften_others=2.0,
            with_=[P(bullet="E_Magenta_Aim", start_delay=0.2, shot_count=d(4, 5, 6), interval=d(0.42, 0.36, 0.3), pause=0.0,
                     bullet_count=2, spread_angle=d(70.0, 80.0, 90.0), aim_at_player=True, bullet_speed=d(110.0, 125.0, 140.0))]),
            quirk=("4面ボス1・第一形態「ダイヤの塊」",
                   "ひし形に固まった弾の塊が、自機を狙って続けて飛んでくる。塊は大きいので、毎回「塊1つ分」だけ横にずれて、"
                   "同じ向きに少しずつ流す。塊の外側を狙う2発の弾が、大きく動いたときの逃げ道をふさぐので、ずれ幅は小さく。",
                   "ケツイ4面ボスのような、ひし形の集合弾。塊の大きさと間隔を一定にして、決まった幅のチョン避けを"
                   "くり返すリズムの弾幕にした")),
    ],
    [
        tri("tk2_lines", lambda d: P(
            bullet="E_Red_Normal", start_delay=0.3, shot_count=d(3, 4, 4), interval=0.5, pause=d(1.3, 1.05, 0.85),
            bullet_count=d(3, 5, 7), spread_angle=d(40.0, 60.0, 76.0), line_count=d(3, 4, 5), line_speed_ratio=0.12,
            aim_at_player=True, bullet_speed=d(86.0, 100.0, 114.0))),
        tri("tk2_q_moire", lambda d: P(   # 癖: ずれる網目
            bullet="E_Blue_Cian", start_delay=0.4, shot_count=d(18, 22, 26), interval=d(0.3, 0.26, 0.22), pause=d(1.6, 1.3, 1.1),
            bullet_count=d(8, 10, 12), spread_angle=360.0, aim_at_player=False, rotate_per_shot=d(6.0, 7.0, 8.0),
            bullet_speed=d(68.0, 78.0, 88.0), soften_others=2.0,
            with_=[P(bullet="E_Indigo_Slow", start_delay=0.15, shot_count=d(18, 22, 26), interval=d(0.3, 0.26, 0.22), pause=0.0,
                     bullet_count=d(8, 10, 12), spread_angle=360.0, aim_at_player=False, rotate_per_shot=d(-4.0, -4.5, -5.0),
                     bullet_speed=d(54.0, 62.0, 70.0))]),
            quirk=("4面ボス1・第二形態「ずれる網目」",
                   "逆に回る2つの渦を、速さを変えて重ねる。2つの渦が重なった網の目のうち、大きく開いた目が、ゆっくり横へ"
                   "流れていく。開いた目を見つけたら、その流れについていくように少しずつ横へ動く。目の流れる向きは、"
                   "2つの渦の回る速さの差で決まる。",
                   "怒首領蜂大往生の緋蜂の、回る向きと速さの違う弾が重なる網の目。網目の「開いた所が動く」性質を"
                   "主役にして、目を追いかける避け方にした")),
    ],
    [
        tri("tk3_burst", lambda d: P(
            bullet="E_Spiky_Split", start_delay=0.4, shot_count=2, interval=0.8, pause=d(1.4, 1.1, 0.9),
            bullet_count=d(5, 6, 7), spread_angle=360.0, aim_at_player=True, bullet_speed=140.0,
            motion=[S(0.7, 0.0, trans="quad")], split_time=0.9,
            split=P(bullet="E_Red_Normal", bullet_count=d(5, 7, 9), spread_angle=d(60.0, 80.0, 100.0), aim_at_player=True,
                    bullet_speed=d(70.0, 82.0, 95.0)))),
        tri("tk3_q_scissor", lambda d: P(   # 癖: 鋏
            bullet="E_Green_Curve", start_delay=0.4, shot_count=d(14, 18, 22), interval=d(0.17, 0.14, 0.12), pause=d(1.6, 1.3, 1.1),
            bullet_count=2, spread_angle=d(130.0, 140.0, 150.0), aim_at_player=False, mirror_curve_by_side=True,
            bullet_speed=d(115.0, 130.0, 145.0), motion=[S(1.6, d(100.0, 115.0, 130.0), av=d(-40.0, -46.0, -52.0))],
            angle_wave_amplitude=d(10.0, 12.0, 14.0), angle_wave_shots=d(18, 16, 14), soften_others=2.0,
            with_=[P(bullet="E_Magenta_Aim", start_delay=0.6, shot_count=d(3, 4, 5), interval=0.7, pause=0.0,
                     bullet_count=d(1, 3, 3), spread_angle=d(0.0, 20.0, 16.0), aim_at_player=True,
                     bullet_speed=d(120.0, 140.0, 160.0))]),
            quirk=("4面ボス1・第三形態「鋏」",
                   "左右に大きく開いた2本の弾の流れが、内側へ曲がって、鋏の刃のように閉じてくる。閉じる刃の先は少しずつ揺れる。"
                   "刃と刃の間(真ん中)に入ると、刃が交わる所で挟まれるので、刃の外側(画面の端寄り)から、刃の根元が開いた"
                   "所へ入り込むように回り込む。真ん中から撃つ自機狙いは、その途中で小さくよける。",
                   "ケツイの、内側へ曲がる弾で囲む攻撃。曲がる量と揺れを抑えて、「外から回り込む」が必ず通るようにした")),
    ],
]

# ======================================================================= 4面 中ボス(ブラッドスワン)
BLOOD = [
    tri("bs2_fan", lambda d: P(
        bullet="E_Red_Normal", start_delay=0.4, shot_count=d(3, 4, 5), interval=0.3, pause=d(1.4, 1.1, 0.9),
        bullet_count=d(7, 9, 11), spread_angle=d(80.0, 96.0, 110.0), aim_at_player=True, line_count=2, line_speed_ratio=0.18,
        bullet_speed=d(90.0, 105.0, 120.0))),
    tri("bs2_spiral", lambda d: P(
        bullet="E_Purple_Revenge", start_delay=0.3, shot_count=d(26, 34, 42), interval=d(0.12, 0.1, 0.085), pause=d(1.3, 1.05, 0.85),
        bullet_count=d(3, 4, 5), spread_angle=360.0, aim_at_player=False, rotate_per_shot=d(12.0, 13.0, 14.0),
        rotate_accel=d(0.1, 0.12, 0.14), bullet_speed=d(80.0, 94.0, 108.0))),
    tri("bs2_aim", lambda d: P(
        bullet="E_Magenta_Aim", start_delay=0.3, shot_count=d(5, 7, 9), interval=d(0.18, 0.14, 0.11), pause=d(1.4, 1.1, 0.9),
        bullet_count=d(1, 3, 3), spread_angle=d(0.0, 22.0, 18.0), aim_at_player=True, bullet_speed=d(150.0, 175.0, 200.0))),
]

# ======================================================================= 4面 中枢防衛艦
GUARD = [
    [
        tri("g1_spread", lambda d: P(
            bullet="E_Blue_Cian", start_delay=0.3, shot_count=d(3, 3, 4), interval=0.4, pause=d(1.6, 1.3, 1.05),
            bullet_count=d(7, 9, 11), spread_angle=d(96.0, 112.0, 126.0), aim_at_player=True, line_count=2,
            line_speed_ratio=0.2, bullet_speed=d(80.0, 94.0, 108.0))),
        tri("g1_q_lattice", lambda d: P(   # 癖: 格子
            bullet="E_Blue_Cian", start_delay=0.4, shot_count=d(7, 8, 10), interval=d(0.66, 0.58, 0.52), pause=d(1.8, 1.5, 1.3),
            bullet_count=d(7, 8, 10), parallel_spacing=d(60.0, 55.0, 49.0), aim_at_player=False, base_angle=26.0,
            bullet_speed=d(70.0, 80.0, 90.0), soften_others=6.0,
            with_=[P(bullet="E_Blue_Cian", start_delay=0.3, shot_count=d(7, 8, 10), interval=d(0.66, 0.58, 0.52), pause=0.0,
                     bullet_count=d(7, 8, 10), parallel_spacing=d(60.0, 55.0, 49.0), aim_at_player=False, base_angle=-26.0,
                     bullet_speed=d(70.0, 80.0, 90.0))]),
            quirk=("4面中枢防衛艦・第一形態「格子」",
                   "左ななめと右ななめに傾いた平行な弾の列が、互いに交わって、ひし形のマス目の格子になって降りてくる。"
                   "マス目は格子と一緒に下へ流れるので、1つのマスに入ったら、格子に合わせて少しずつ上(前)へ動いて同じマスに"
                   "とどまり、次の列が来たら隣のマスへななめに乗り移る。",
                   "怒首領蜂最大往生の、ななめの列弾が交わって格子になる弾幕。格子の目を大きめにそろえて、"
                   "マスからマスへ乗り移る避け方にした")),
    ],
    [
        tri("g2_aim", lambda d: P(
            bullet="E_Magenta_Aim", start_delay=0.3, shot_count=d(4, 6, 8), interval=d(0.2, 0.16, 0.13), pause=d(1.3, 1.05, 0.85),
            bullet_count=d(3, 3, 5), spread_angle=d(20.0, 16.0, 28.0), aim_at_player=True, bullet_speed=d(150.0, 175.0, 200.0))),
        tri("g2_q_fireworks", lambda d: P(   # 癖: 近くで弾ける花火
            bullet="E_Massive_Light_Green", start_delay=0.4, shot_count=d(3, 4, 5), interval=d(0.9, 0.75, 0.62), pause=d(1.6, 1.3, 1.1),
            bullet_count=d(1, 2, 2), spread_angle=d(0.0, 40.0, 36.0), aim_at_player=True, bullet_speed=d(70.0, 80.0, 90.0),
            split_time=d(2.0, 1.8, 1.6), split_time_random=d(0.4, 0.5, 0.6), split_follow_direction=False, soften_others=2.0,
            split=P(bullet="E_Red_Normal", bullet_count=d(10, 14, 18), spread_angle=360.0, aim_at_player=True, base_angle=10.0,
                    bullet_speed=d(55.0, 64.0, 72.0), bullet_accel=d(16.0, 20.0, 24.0))),
            quirk=("4面中枢防衛艦・第二形態「近くで弾ける花火」",
                   "大きな玉がゆっくり自機の方へ来て、少しばらばらの時間に、輪になって弾ける。弾ける直前の玉のそばにいると、"
                   "広がる前の密な輪に巻き込まれるので、玉とは距離を取り、玉が弾けたら輪が広がって隙間が開くのを待ってから"
                   "くぐる。玉は自機を狙うので、引きつけてから横へ外すと、弾ける場所を選べる。",
                   "東方永夜抄の鈴仙「幻爆『近眼花火』」の、近づいてから弾ける大玉。弾けるまでの時間に幅を持たせて、"
                   "1つずつ見て対処させる形にした")),
    ],
    [
        tri("g3_ring", lambda d: P(
            bullet="E_Blue_Cian", start_delay=0.3, shot_count=d(5, 6, 7), interval=0.4, pause=d(1.2, 1.0, 0.8),
            bullet_count=d(20, 26, 32), spread_angle=360.0, aim_at_player=True, polygon_sides=d(4, 5, 6),
            rotate_per_shot=9.0, bullet_speed=d(70.0, 82.0, 94.0))),
        tri("g3_q_arch", lambda d: P(   # 癖: 閉じるアーチ
            bullet="E_Green_Curve", start_delay=0.4, shot_count=d(16, 20, 24), interval=d(0.24, 0.2, 0.17), pause=d(1.6, 1.3, 1.1),
            bullet_count=d(6, 8, 10), spread_angle=d(150.0, 160.0, 170.0), aim_at_player=False, mirror_curve_by_side=True,
            gap_size=2, gap_wave_amplitude=d(0.35, 0.45, 0.5), gap_wave_shots=d(16, 14, 12),
            bullet_speed=d(100.0, 112.0, 124.0), motion=[S(1.5, d(84.0, 96.0, 108.0), av=d(-24.0, -28.0, -32.0))],
            soften_others=2.0),
            quirk=("4面中枢防衛艦・第三形態「閉じるアーチ」",
                   "左右に広がった扇が内側へ曲がって、アーチの形に閉じながら降りてくる。アーチの真ん中には1か所だけ"
                   "切れ目があり、切れ目は撃つたびに少しずつ左右へずれる。アーチの外は曲がった弾が閉じてくるので、"
                   "切れ目の下で待ち、ずれる向きに合わせて切れ目をくぐり続ける。",
                   "怒首領蜂大往生の、曲がる扇で囲う弾幕に、動く切れ目を組み合わせた。囲む弾と通り道の両方を"
                   "見せて、「囲まれる前に切れ目へ入る」判断を要求する形にした")),
    ],
]

# ======================================================================= 4面 最終兵器ヌクレオ(4形態)
NUCLEO = [
    [
        tri("n1_aim", lambda d: P(
            bullet="E_Magenta_Aim", start_delay=0.3, shot_count=d(4, 6, 8), interval=d(0.2, 0.15, 0.12), pause=d(1.3, 1.05, 0.85),
            bullet_count=d(3, 5, 7), spread_angle=d(30.0, 44.0, 56.0), aim_at_player=True, bullet_speed=d(140.0, 165.0, 190.0))),
        tri("n1_q_star", lambda d: P(   # 癖: 星の檻
            bullet="E_Red_Normal", start_delay=0.4, shot_count=d(4, 5, 6), interval=d(0.75, 0.65, 0.55), pause=d(1.6, 1.3, 1.1),
            bullet_count=d(25, 30, 35), spread_angle=360.0, aim_at_player=False, polygon_sides=5, polygon_phase=0.0,
            rotate_per_shot=36.0, bullet_speed=d(62.0, 72.0, 82.0), soften_others=2.0,
            with_=[P(bullet="E_Blue_Cian", start_delay=0.35, shot_count=d(4, 5, 6), interval=d(0.75, 0.65, 0.55), pause=0.0,
                     bullet_count=d(25, 30, 35), spread_angle=360.0, aim_at_player=False, polygon_sides=5, polygon_phase=36.0,
                     rotate_per_shot=-36.0, bullet_speed=d(50.0, 58.0, 66.0))]),
            quirk=("最終兵器ヌクレオ・第一形態「星の檻」",
                   "赤と青の五角形の輪が、交互に向きを変えて広がる。多角形の輪は角ほど速く、辺の真ん中ほど遅いので、"
                   "角の通り道は早く過ぎ、辺の真ん中に弾がたまる。赤い輪の「角」が通り過ぎた直後の場所に入り、"
                   "あとから来る青い輪の角(赤とずれた向き)が来る前に、少しだけ横へ動いてかわす。",
                   "東方永夜抄の、図形の形に並んだ弾が広がる弾幕(永琳の幾何学的な弾幕)。2つの五角形の向きをずらして、"
                   "角と辺の速さの違いを読む避け方にした")),
    ],
    [
        tri("n2_rows", lambda d: P(
            bullet="E_Blue_Cian", start_delay=0.3, shot_count=d(3, 4, 5), interval=0.45, pause=d(1.3, 1.05, 0.85),
            bullet_count=d(5, 7, 9), spread_angle=d(60.0, 74.0, 88.0), line_count=d(3, 3, 4), line_speed_ratio=-0.1,
            aim_at_player=True, bullet_speed=d(120.0, 136.0, 152.0))),
        tri("n2_q_freezering", lambda d: P(   # 癖: 順に目覚める輪
            bullet="E_Pink_Medium", start_delay=0.4, shot_count=d(4, 5, 6), interval=d(0.5, 0.42, 0.36), pause=d(2.0, 1.7, 1.4),
            bullet_count=d(14, 18, 22), spread_angle=360.0, aim_at_player=True, base_angle=10.0, launch_speed_step=0.18,
            bullet_speed=110.0, motion=[S(0.8, 0.0, trans="quad"), S(d(1.6, 1.4, 1.2), None),
                                        S(0.6, d(110.0, 130.0, 150.0), turn="aim")],
            soften_others=2.5),
            quirk=("最終兵器ヌクレオ・第二形態「順に目覚める輪」",
                   "輪をいくつか続けて撃ち、少しずつ大きくなる輪のまま止める。止まった輪は、先に撃った輪から順に、"
                   "その瞬間の自機の方へ向き直って飛んでくる。1つの輪が向き直るたびに、少しだけ横へずれて弾を外す。"
                   "ずれる向きを毎回同じにすると壁に追い詰められるので、何回かずれたら逆へ切り返す。",
                   "ケツイの豹変弾を、時間差でくり返す形にアレンジした(1面ボスの豹変弾の応用)")),
    ],
    [
        tri("n3_web", lambda d: P(
            bullet="E_Red_Normal", start_delay=0.3, shot_count=d(4, 5, 6), interval=0.5, pause=d(1.3, 1.05, 0.85),
            bullet_count=d(16, 22, 28), spread_angle=360.0, aim_at_player=True, petal_count=d(4, 6, 6), petal_depth=0.45,
            rotate_per_shot=d(10.0, 12.0, 14.0), bullet_speed=d(72.0, 84.0, 96.0))),
        tri("n3_q_galaxy", lambda d: P(   # 癖: 銀河の腕
            bullet="E_Blue_Cian", start_delay=0.4, shot_count=d(20, 24, 28), interval=d(0.22, 0.19, 0.16), pause=d(1.6, 1.3, 1.1),
            bullet_count=d(16, 20, 24), spread_angle=360.0, aim_at_player=False, spiral_speed_ratio=1.2,
            rotate_per_shot=d(5.0, 6.0, 7.0), bullet_speed=d(40.0, 46.0, 52.0), bullet_accel=d(10.0, 12.0, 14.0),
            soften_others=2.0),
            quirk=("最終兵器ヌクレオ・第三形態「銀河の腕」",
                   "輪の弾の速さを、1周の中で少しずつ変えて撃つので、輪ではなく、ねじれた銀河の腕(渦)の形に広がる。"
                   "腕は外へ広がりながら回るので、腕と腕の間に入ったら、腕の回る向きに合わせて円を描くように回り込む。"
                   "腕の内側(ボスの近く)ほど隙間が細いので、下がって広い所で回る。",
                   "怒首領蜂大往生の緋蜂の、速さの違う弾でできる渦巻き。腕の数を減らして、"
                   "腕の間を回り込む避け方にした")),
    ],
    [
        tri("n4_aim", lambda d: P(
            bullet="E_Magenta_Aim", start_delay=0.3, shot_count=d(6, 8, 10), interval=d(0.16, 0.12, 0.1), pause=d(1.2, 1.0, 0.8),
            bullet_count=d(3, 5, 5), spread_angle=d(28.0, 40.0, 34.0), aim_at_player=True, aim_once_per_burst=True,
            bullet_speed=d(160.0, 185.0, 210.0))),
        tri("n4_q_curtain", lambda d: P(   # 癖: 降りる帳と自機狙い
            bullet="E_Indigo_Slow", start_delay=0.4, shot_count=d(10, 13, 16), interval=d(0.55, 0.48, 0.42), pause=d(1.6, 1.3, 1.1),
            bullet_count=d(9, 11, 13), parallel_spacing=d(46.0, 40.0, 36.0), from_screen_top=True, aim_at_player=False,
            gap_size=d(3, 2, 2), gap_random=True, random_seed=23, bullet_speed=d(60.0, 70.0, 80.0), soften_others=2.0,
            with_=[P(bullet="E_Magenta_Aim", start_delay=0.5, shot_count=d(8, 11, 14), interval=d(0.55, 0.48, 0.42), pause=0.0,
                     bullet_count=1, aim_at_player=True, bullet_speed=d(130.0, 150.0, 170.0))]),
            quirk=("最終兵器ヌクレオ・第四形態「降りる帳と自機狙い」",
                   "画面の上から、切れ目のある弾の幕(すだれ)がゆっくり降りてきて、同時にボスが速い自機狙いを撃つ。"
                   "すだれの切れ目は毎回ちがう所に開くので、次の切れ目を見て先に移り、そこで自機狙いを1発ずつ"
                   "小さくよける。自機狙いを大きくよけると、すだれの弾にぶつかる。",
                   "東方永夜抄の「インペリシャブルシューティング」の、画面の外からも弾が来る形を、上から降る幕に絞って"
                   "アレンジした。降る幕と自機狙いを同時に見る、最後の形態らしい弾幕")),
    ],
]


# ======================================================================= 二周目の雑魚(数が倍になるぶん、1機の弾は一周目1面の 1/3 くらい)
# 一周目1面の雑魚は、1機あたり毎秒 1.4〜1.6 発(HARD)。二周目は、その 1/3(HARD 0.5 / NORMAL 0.43 / EASY 0.3 発)。
# 何機もの雑魚が少しずつ時間をずらして自機を狙うので、弾が自機の後ろへ流れる(流して、壁際で切り返す)。
# NORMAL は少し流す程度、HARD は流しと切り返しが必須になる間隔と速さ。
Z_AIR = tri("z_air", lambda d: P(
    bullet="E_Magenta_Aim", start_delay=d(0.9, 0.75, 0.6), start_delay_per_unit=d(0.16, 0.13, 0.11),
    shot_count=1, pause=d(3.3, 2.3, 2.0), bullet_count=1, aim_at_player=True,
    bullet_speed=d(110.0, 135.0, 160.0)))
Z_GROUND = tri("z_ground", lambda d: P(
    bullet="E_Tank_Aim", start_delay=d(1.1, 0.9, 0.7), start_delay_per_unit=d(0.2, 0.16, 0.12),
    shot_count=1, pause=d(3.3, 2.3, 2.0), bullet_count=1, aim_at_player=True, bullet_speed=d(100.0, 120.0, 140.0)))
# 左右の縦列(切り返しの隊列): 両端の列から、順に自機を狙う。大きく横へ動くと、反対の列の流れに飛び込む
Z_COLUMN = tri("z_column", lambda d: P(
    bullet="E_Magenta_Aim", start_delay=d(1.0, 0.9, 0.8), start_delay_per_unit=d(0.3, 0.24, 0.2),
    shot_count=d(1, 2, 2), interval=0.2, pause=d(1.9, 1.45, 1.1), bullet_count=1, aim_at_player=True,
    bullet_speed=d(110.0, 132.0, 155.0)))

# ======================================================================= 二周目2面の道中は弾幕戦(グレイズしやすい、遅くて密で、隙間の広い弾幕)
# 中ボス戦車(重戦車): 花びらの形に広がる遅い輪と、遅い自機狙いの3way
Z2_TANK = tri("z2_tank_bloom", lambda d: P(
    bullet="E_Red_Normal", start_delay=1.0, shot_count=d(3, 4, 5), interval=0.35, pause=d(2.0, 1.6, 1.3),
    bullet_count=d(16, 22, 28), spread_angle=360.0, aim_at_player=True, petal_count=4, petal_depth=0.4,
    rotate_per_shot=11.0, bullet_speed=d(55.0, 65.0, 75.0),
    with_=[P(bullet="E_Magenta_Aim", start_delay=0.6, shot_count=d(1, 2, 2), interval=0.5, pause=0.6,
             bullet_count=3, spread_angle=d(30.0, 26.0, 22.0), aim_at_player=True, bullet_speed=d(85.0, 95.0, 105.0))]))
# 中型機(ガンシップ・装甲機・吸収機): 遅い二重の渦
Z2_MID = tri("z2_mid_spiral", lambda d: P(
    bullet="E_Blue_Cian", start_delay=0.8, shot_count=d(16, 22, 26), interval=d(0.16, 0.13, 0.11), pause=d(2.0, 1.6, 1.3),
    bullet_count=d(3, 4, 5), spread_angle=360.0, aim_at_player=False, rotate_per_shot=12.0,
    bullet_speed=d(60.0, 70.0, 80.0)))

# ======================================================================= 二周目のヌクレオ: 一周目の残留弾を、さらに鬼畜にしたもの(2つ × 形態)
# 止まった弾が長く残り、その上に、強めた元の弾幕(NUCLEO)が重なる。並びは「残留弾 → 元の弾幕 → 残留弾 → 元の弾幕」
def _stay(stop, hold, go_speed, turn="abs", go_time=2.0, angle=0.0):
    return [S(stop, 0.0, trans="linear"), S(hold, None), S(go_time, go_speed, turn=turn, angle=angle, trans="sine", ease="in")]


NUCLEO_RESIDUE = [
    [   # 第一形態
        # 段々畑・改: 止まる弧の段を増やし、くねる道を細く、うねりを速く。道の出口へ速い自機狙い
        tri("nr1_terraces", lambda d: P(
            bullet="E_Pink_Medium", start_delay=0.4, shot_count=d(6, 7, 8), interval=0.11, pause=d(2.8, 2.5, 2.2), soften_others=2.5,
            bullet_count=d(24, 28, 32), spread_angle=d(150.0, 160.0, 170.0), aim_at_player=False, gap_size=d(4, 3, 3),
            gap_wave_amplitude=d(0.6, 0.65, 0.7), gap_wave_shots=d(6, 5, 4), launch_speed_step=0.26, bullet_speed=150.0,
            motion=_stay(1.6, d(3.4, 3.8, 4.2), d(70.0, 80.0, 90.0)),
            with_=[P(bullet="E_Magenta_Aim", start_delay=2.2, shot_count=d(4, 6, 8), interval=d(0.5, 0.4, 0.32), pause=2.4,
                     bullet_count=d(1, 3, 3), spread_angle=d(0.0, 16.0, 14.0), aim_at_player=True,
                     bullet_speed=d(190.0, 220.0, 250.0))])),
        # 渦・改: 3本腕の渦が、だんだん遠くで止まって迷路になる。残ったあと、回りながら外へ流れる
        tri("nr1_spiral", lambda d: P(
            bullet="E_Pink_Medium", start_delay=0.4, shot_count=d(46, 54, 62), interval=d(0.045, 0.04, 0.036), pause=d(2.6, 2.3, 2.0),
            soften_others=2.5, bullet_count=3, spread_angle=360.0, aim_at_player=False, rotate_per_shot=d(13.0, 12.0, 11.0),
            launch_speed_step=d(0.045, 0.042, 0.04), bullet_speed=110.0,
            motion=_stay(1.5, d(3.2, 3.6, 4.0), d(50.0, 60.0, 70.0), turn="add", go_time=2.2, angle=25.0),
            with_=[P(bullet="E_Magenta_Aim", start_delay=2.2, shot_count=d(3, 4, 5), interval=0.6, pause=2.4,
                     bullet_count=1, line_count=d(3, 4, 5), line_speed_ratio=0.15, aim_at_player=True,
                     bullet_speed=d(200.0, 230.0, 260.0))])),
    ],
    [   # 第二形態
        # 網・改: ななめ2方向と縦の、3方向の止まる線で、三角の網を張る。網の目はグレイズしながら抜ける広さ
        tri("nr2_net", lambda d: P(
            bullet="E_Pink_Medium", start_delay=0.4, shot_count=d(4, 5, 6), interval=0.14, pause=d(2.8, 2.5, 2.2),
            bullet_count=d(8, 9, 10), parallel_spacing=d(56.0, 52.0, 48.0), aim_at_player=False, base_angle=30.0,
            launch_speed_step=0.32, bullet_speed=150.0, motion=_stay(1.5, d(3.2, 3.6, 4.0), d(60.0, 70.0, 80.0)),
            with_=[P(bullet="E_Pink_Medium", start_delay=0.4, shot_count=d(4, 5, 6), interval=0.14, pause=0.0,
                     bullet_count=d(8, 9, 10), parallel_spacing=d(56.0, 52.0, 48.0), aim_at_player=False, base_angle=-30.0,
                     launch_speed_step=0.32, bullet_speed=150.0, motion=_stay(1.5, d(3.2, 3.6, 4.0), d(60.0, 70.0, 80.0))),
                   P(bullet="E_Pink_Medium", start_delay=0.55, shot_count=d(3, 4, 5), interval=0.16, pause=0.0,
                     bullet_count=d(6, 7, 8), parallel_spacing=d(64.0, 60.0, 56.0), aim_at_player=False,
                     launch_speed_step=0.35, bullet_speed=140.0, motion=_stay(1.4, d(3.2, 3.6, 4.0), d(60.0, 70.0, 80.0)))])),
        # 足跡・改: 自機狙いの弾が、通った跡に止まる弾を5方向に落とす。長く残り、ばらばらの向きへ速く動き出す
        tri("nr2_footprint", lambda d: P(
            bullet="E_Spiky_Split", start_delay=0.4, shot_count=d(14, 18, 22), interval=d(0.18, 0.15, 0.13), pause=d(1.6, 1.4, 1.2),
            bullet_count=d(3, 3, 5), spread_angle=d(26.0, 24.0, 40.0), aim_at_player=True, bullet_speed=d(170.0, 190.0, 210.0),
            split_time=0.7, split_follow_direction=True,
            split=P(bullet="E_Pink_Medium", bullet_count=d(3, 4, 5), spread_angle=360.0, aim_at_player=False,
                    bullet_speed=30.0, motion=[S(0.4, 0.0), S(d(3.0, 3.4, 3.8), None),
                                               S(1.2, d(110.0, 130.0, 150.0), turn="random", angle=50.0, trans="quad", ease="in")]))),
    ],
    [   # 第三形態(第四形態にも使う)
        # 豹変する残留弾・改: 止まる格子を2段に張り、内側の段と外側の段が、時間をずらして自機の方へ動き出す
        tri("nr3_turncoat", lambda d: P(
            bullet="E_Pink_Medium", start_delay=0.4, shot_count=d(4, 5, 6), interval=0.14, pause=d(2.6, 2.3, 2.0),
            bullet_count=d(18, 22, 26), spread_angle=d(140.0, 150.0, 160.0), aim_at_player=False, launch_speed_step=0.3,
            bullet_speed=150.0, random_angle=2.0, random_seed=31,
            motion=[S(1.6, 0.0, trans="linear"), S(d(1.6, 1.4, 1.2), None), S(1.4, d(80.0, 95.0, 110.0), turn="aim", trans="sine", ease="in_out")],
            with_=[P(bullet="E_Pink_Medium", start_delay=0.6, shot_count=d(3, 4, 5), interval=0.14, pause=0.0,
                     bullet_count=d(16, 20, 24), spread_angle=d(130.0, 140.0, 150.0), aim_at_player=False, launch_speed_step=0.3,
                     bullet_speed=120.0, random_angle=2.0, random_seed=37,
                     motion=[S(1.5, 0.0, trans="linear"), S(d(2.6, 2.4, 2.2), None),
                             S(1.4, d(80.0, 95.0, 110.0), turn="aim", trans="sine", ease="in_out")])])),
        # 残留の檻(新): 輪が少しずつ遠くで止まり、内側の輪から順に、その時の自機の方へ迫ってくる。輪の切れ目を順にくぐる
        tri("nr3_cage", lambda d: P(
            bullet="E_Pink_Medium", start_delay=0.4, shot_count=d(4, 5, 6), interval=0.2, pause=d(2.4, 2.1, 1.8),
            bullet_count=d(16, 20, 24), spread_angle=360.0, aim_at_player=True, base_angle=8.0, gap_size=d(4, 3, 3),
            gap_random=True, random_seed=43, launch_speed_step=0.22, bullet_speed=130.0,
            motion=[S(1.2, 0.0, trans="linear"), S(d(1.4, 1.2, 1.0), None), S(0.6, d(120.0, 140.0, 160.0), turn="aim")])),
    ],
]


def _boost(p, count=1.2, speed=1.12, pause=0.85):
    """元の二周目の弾幕を強める(数・速さ・休み)。一緒に撃つ弾幕も"""
    if not isinstance(p, dict):
        return
    if p.get("bullet_count", 1) >= 3 and not p.get("muzzle_offsets"):
        p["bullet_count"] = int(round(p["bullet_count"] * count))
    if p.get("shot_count", 1) >= 2:
        p["shot_count"] = int(round(p["shot_count"] * count))
    for key in ("bullet_speed", "bullet_accel"):
        if key in p:
            p[key] = p[key] * speed
    if "pause" in p:
        p["pause"] = p["pause"] * pause
    for w in p.get("with_") or []:
        _boost(w, count, speed, pause)


# 元のヌクレオの弾幕(n1_〜n4_)を強める
for _path, _p in ALL.items():
    if any("/%s_" % k in _path for k in ("n1", "n2", "n3", "n4")):
        _boost(_p)


def nucleo_loop2_sequence(i):
    """ヌクレオの二周目の、i 番目(0 から)の形態の並び: 残留弾 → 元の弾幕 → 残留弾 → 元の弾幕"""
    res = NUCLEO_RESIDUE[min(i, 2)]
    orig = NUCLEO[i]
    out = []
    for k in range(max(len(res), len(orig))):
        if k < len(res):
            out.extend(res[k])
        if k < len(orig):
            out.extend(orig[k])
    return out


def seq(group):
    """[[e,n,h], [e,n,h], …] を、順番に撃つ並び(難易度ごとに1つずつ撃つ)に広げる"""
    out = []
    for paths in group:
        out.extend(paths)
    return out


if __name__ == "__main__":
    only_paths = sys.argv[1:]
    for path, p in ALL.items():
        if only_paths and not any(o in path for o in only_paths):
            continue
        write(path, p)
    print("wrote", len(ALL) if not only_paths else "selected")
