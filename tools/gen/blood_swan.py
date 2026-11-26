"""ブラッドスワン(4面の中ボス)の専用弾幕。Run: python blood_swan.py
グレイズしにくい弾幕: 弾のすぐそばが危ない(枝分かれ・ばらばらの急な飛び出し・近くで弾ける棘)。
一周目と二周目(少し濃く速い)を、それぞれ EASY / NORMAL / HARD の限定弾幕で作る。
"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from shotgen import P, S, write

OUT = "res://Resources/ShotPatterns/Stage4/BloodSwan/Unique/"
LV = "enha"
ALL = {}

## 作者の指示で、全体を難しくする(数 ×BOOST_COUNT、速さ ×BOOST_SPEED、間 ×BOOST_TIME)
BOOST_COUNT = 1.45
BOOST_SPEED = 1.2
BOOST_TIME = 0.75
## ANOTHER(4つ目の版): HARD から、NORMAL → HARD の差の EXTRA 倍ぶん先へ伸ばす(間は HARD の FLOOR 倍まで)
EXTRA = 0.8
FLOOR = 0.7


class D:
    def __init__(self, lv, loop):
        self.lv = lv
        self.loop = loop

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

    def c(self, e, n, h):
        """数(二周目は 15% 多い)"""
        v = self(e, n, h) * BOOST_COUNT
        return int(round(v * 1.15)) if self.loop == 2 else int(round(v))

    def s(self, e, n, h):
        """速さ(二周目は 6% 速い)"""
        v = self(e, n, h) * BOOST_SPEED
        return v * 1.06 if self.loop == 2 else v

    def t(self, e, n, h):
        """間(二周目は 12% 短い)"""
        v = self(e, n, h) * BOOST_TIME
        return v * 0.88 if self.loop == 2 else v


def tri(name, fn):
    """一周目(EASY / NORMAL / HARD / ANOTHER)と二周目(EASY / NORMAL / HARD)の版を作る。
    ANOTHER は二周目の差し替えを使わないので、ANOTHER 用は一周目の並びにだけ入る"""
    out = {1: [], 2: []}
    for loop in (1, 2):
        for lv in range(4 if loop == 1 else 3):
            p = fn(D(lv, loop))
            if lv < 3:
                p.update(min_difficulty=lv, max_difficulty=lv, skip_auto_tuning=True)
            else:
                p.update(another_only=True, another_made=True, skip_auto_tuning=True)
            for w in p.get("with_") or []:
                w["skip_auto_tuning"] = True
            path = OUT + "%s%s_%s.tres" % (name, "" if loop == 1 else "_l2", LV[lv])
            ALL[path] = p
            out[loop].append(path)
    return out


# 血脈: 左右に揺れる3本の針の流れ。流れに沿って、枝(真横へ割れる弾)が生える。流れに寄り添うと枝に刺さる
VEINS = tri("bsx_veins", lambda d: P(
    bullet="E_Magenta_Aim", start_delay=0.4, shot_count=d.c(18, 24, 30), interval=d.t(0.11, 0.09, 0.075),
    pause=d.t(1.4, 1.15, 0.95), bullet_count=3, spread_angle=d(70.0, 80.0, 90.0), aim_at_player=True,
    aim_once_per_burst=True, angle_wave_amplitude=d(18.0, 20.0, 22.0), angle_wave_shots=20,
    bullet_speed=d.s(145.0, 170.0, 195.0), soften_others=2.0,
    with_=[P(bullet="E_Red_Normal", start_delay=0.3, shot_count=d.c(3, 4, 6), interval=d.t(0.55, 0.45, 0.36), pause=0.0,
             bullet_count=3, spread_angle=d(70.0, 80.0, 90.0), aim_at_player=True, bullet_speed=d.s(110.0, 125.0, 140.0),
             split_time=d(0.75, 0.7, 0.65), split_follow_direction=True,
             split=P(bullet="E_Red_Normal", bullet_count=2, spread_angle=180.0, aim_at_player=False,
                     bullet_speed=d.s(48.0, 56.0, 64.0)))]))

# 瀉血: 輪がゆっくり止まりかけてから、1発ずつ、ばらばらの向きへ急に飛び出す。近くでかすめると、どれが来るか読めない
BLOODLET = tri("bsx_bloodlet", lambda d: P(
    bullet="E_Pink_Medium", start_delay=0.4, shot_count=d.c(2, 3, 3), interval=d.t(0.6, 0.5, 0.45),
    pause=d.t(1.7, 1.4, 1.15), bullet_count=d.c(14, 18, 22), spread_angle=360.0, aim_at_player=True,
    rotate_per_shot=9.0, bullet_speed=d.s(90.0, 100.0, 110.0), random_speed_ratio=0.15, random_seed=13,
    motion=[S(0.8, 22.0, trans="quad"), S(d(0.6, 0.5, 0.4), None),
            S(0.35, d.s(115.0, 135.0, 155.0), turn="random", angle=d(55.0, 65.0, 75.0), trans="expo", ease="in")],
    soften_others=2.0))

# 紅い棘: 速さの違う槍の列が自機を狙い、途中で棘(四方への小さな弾)に弾ける。槍の近くは、棘で危ない
THORNS = tri("bsx_thorns", lambda d: P(
    bullet="E_Purple_Revenge", start_delay=0.4, shot_count=d.c(3, 4, 5), interval=d.t(0.55, 0.48, 0.42),
    pause=d.t(1.5, 1.2, 1.0), bullet_count=d(1, 1, 3), spread_angle=d(0.0, 0.0, 34.0), aim_at_player=True,
    line_count=d(4, 5, 5), line_speed_ratio=0.14, bullet_speed=d.s(130.0, 150.0, 165.0),
    split_time=d(0.75, 0.7, 0.65), split_follow_direction=True,
    split=P(bullet="E_Red_Normal", bullet_count=4, spread_angle=360.0, aim_at_player=False, base_angle=45.0,
            bullet_speed=d.s(34.0, 40.0, 46.0), bullet_accel=d.s(30.0, 38.0, 46.0))))

# 鮮血の暴走(暴走中だけ): 逆に回る速い二重の渦と、狙ってくる棘
RAMPAGE = tri("bsx_rampage", lambda d: P(
    bullet="E_Red_Normal", start_delay=0.3, shot_count=d.c(40, 50, 60), interval=d.t(0.1, 0.085, 0.072),
    pause=d.t(1.4, 1.15, 0.95), bullet_count=d(4, 5, 6), spread_angle=360.0, aim_at_player=False,
    rotate_per_shot=d(13.0, 14.0, 15.0), bullet_speed=d.s(100.0, 115.0, 130.0), soften_others=2.0,
    with_=[P(bullet="E_Purple_Revenge", start_delay=0.05, shot_count=d.c(40, 50, 60), interval=d.t(0.1, 0.085, 0.072),
             pause=0.0, bullet_count=d(3, 4, 5), spread_angle=360.0, aim_at_player=False, base_angle=30.0,
             rotate_per_shot=d(-9.0, -10.0, -11.0), bullet_speed=d.s(70.0, 80.0, 90.0)),
           P(bullet="E_Magenta_Aim", start_delay=0.8, shot_count=d(2, 3, 4), interval=0.9, pause=0.0,
             bullet_count=1, line_count=3, line_speed_ratio=0.15, aim_at_player=True, bullet_speed=d.s(130.0, 150.0, 170.0),
             split_time=0.7, split_follow_direction=True,
             split=P(bullet="E_Red_Normal", bullet_count=4, spread_angle=360.0, aim_at_player=False, base_angle=45.0,
                     bullet_speed=d.s(34.0, 40.0, 46.0), bullet_accel=36.0))]))

# ---- 3面ボス(ブラックスワン改)のオマージュ
# 血の十字砲火: 左右の砲口から、速い流しが自機へ向かって交差する(十字砲火のオマージュ)。流れはゆっくり首を振る
CROSSFIRE = tri("bsx_crossfire", lambda d: P(
    bullet="E_Red_Normal", start_delay=0.4, shot_count=d.c(16, 22, 28), interval=d.t(0.1, 0.085, 0.072), pause=d.t(1.4, 1.15, 0.95),
    bullet_count=d(1, 1, 2), spread_angle=d(0.0, 0.0, 8.0), aim_at_player=True, muzzle_offsets=[(-82.0, -10.0), (80.0, -10.0)],
    angle_wave_amplitude=d(8.0, 10.0, 12.0), angle_wave_shots=14, bullet_speed=d.s(190.0, 215.0, 240.0), soften_others=2.0))
# 血の散弾: 速さのばらつく自機狙いの散弾を、左右に少しずらして連射する(5way 散弾のオマージュ)
SHOTGUN = tri("bsx_shotgun", lambda d: P(
    bullet="E_Purple_Revenge", start_delay=0.3, shot_count=d.c(3, 4, 5), interval=d.t(0.3, 0.26, 0.22), pause=d.t(1.3, 1.05, 0.9),
    bullet_count=d.c(5, 7, 9), spread_angle=d(40.0, 50.0, 60.0), aim_at_player=True, rotate_per_shot=6.0, reverse_every_shots=1,
    random_speed_ratio=0.3, random_seed=81, bullet_speed=d.s(170.0, 195.0, 220.0)))
# 血の花火: 上へ打ち上げた弾が止まり、速い輪に弾けて降ってくる(バルカンの花火のオマージュ)
FIREWORK = tri("bsx_firework", lambda d: P(
    bullet="E_Spiky_Split", start_delay=0.4, shot_count=d.c(3, 4, 5), interval=d.t(0.35, 0.3, 0.26), pause=d.t(1.5, 1.25, 1.05),
    bullet_count=d(2, 3, 4), spread_angle=d(100.0, 120.0, 140.0), aim_at_player=False, base_angle=180.0,
    random_shot_angle=20.0, random_seed=83, bullet_speed=d.s(170.0, 185.0, 200.0),
    motion=[S(0.7, 0.0, trans="quad")], split_time=0.8,
    split=P(bullet="E_Red_Normal", bullet_count=d.c(8, 10, 12), spread_angle=360.0, aim_at_player=True,
            bullet_speed=d.s(120.0, 140.0, 160.0))))
# 血の風車: 4本の腕の風車が回り、ときどき回る向きが入れ替わる(ANOTHER の風車のオマージュ)
WINDMILL = tri("bsx_windmill", lambda d: P(
    bullet="E_Red_Normal", start_delay=0.3, shot_count=d.c(36, 46, 56), interval=d.t(0.075, 0.065, 0.056), pause=d.t(1.3, 1.05, 0.9),
    bullet_count=4, spread_angle=360.0, aim_at_player=False, rotate_per_shot=d(7.0, 8.0, 9.0), reverse_every_shots=d(24, 20, 16),
    line_count=2, line_speed_ratio=0.2, bullet_speed=d.s(150.0, 170.0, 190.0)))


def phases(loop):
    """形態ごとの、順番に撃つ弾幕(第三形態は暴走)"""
    def flat(*groups):
        out = []
        for g in groups:
            out.extend(g[loop] if isinstance(g, dict) else [g])
        return out
    return [flat(CROSSFIRE, VEINS, SHOTGUN, THORNS),
            flat(FIREWORK, BLOODLET, CROSSFIRE, VEINS, SHOTGUN),
            flat(RAMPAGE, WINDMILL, BLOODLET, CROSSFIRE, THORNS, FIREWORK)]


if __name__ == "__main__":
    for path, p in ALL.items():
        write(path, p)
    print("wrote", len(ALL))
