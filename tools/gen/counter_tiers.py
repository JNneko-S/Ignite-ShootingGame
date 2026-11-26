"""カウンター大技を、難易度ごとに作り分ける。
今の大技の弾幕(.tres)を「NORMAL の基準」として、そこから EASY / NORMAL / HARD / ANOTHER 用の写しを作る。
  EASY    … 数を大きく減らし、遅く、間を広く
  NORMAL  … 今までの NORMAL と同じ(自動の調整と同じ減らし方を、先にかけておく)
  HARD    … 数・速さ・頻度を上げ、大技ごとの追加の弾幕を1つ足す
  ANOTHER … さらに上げて、追加の弾幕を2つ足す(ハザードランクでは、速さだけ上がる)
写しは Resources/ShotPatterns/Counter/Tiers/ に置き、限定弾幕(min/max_difficulty, another_only)として、
ボスの CounterSpell の Patterns に全部並べる(撃つときに、選んだ難易度のものだけが残る)。
元の .tres は変えない(ほかの攻撃でも使っているものがあるため)。
  python tools/gen/counter_tiers.py
"""
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
from shotgen import P, S, write, ROOT  # noqa: E402

OUT = "res://Resources/ShotPatterns/Counter/Tiers/"

# 大技: (シーン, ノード名, 元の弾幕, {難易度: 追加の弾幕の list})
def _fs(res):
    return os.path.join(ROOT, res.replace("res://", ""))


# ------------------------------------------------------------------ 数の変え方

# tier: 0 EASY, 1 NORMAL, 2 HARD, 3 ANOTHER
SCALE = {
    #     count  shot   ring  speed  interval pause  random
    0: (0.5, 0.55, 0.6, 0.82, 1.3, 1.55, 0.5),
    2: (1.3, 1.25, 1.25, 1.12, 0.88, 0.8, 1.0),
    3: (1.6, 1.45, 1.5, 1.18, 0.78, 0.66, 1.0),
}

# もともと濃い大技(大砂嵐)は、上げ幅を控えめにする
MILD_SCALE = {
    2: (1.15, 1.1, 1.1, 1.06, 0.95, 0.9, 1.0),
    3: (1.3, 1.2, 1.25, 1.1, 0.88, 0.8, 1.0),
}
MILD = ("sp3",)
_mild = False

DEFAULTS = {"bullet_count": "1", "shot_count": "1", "interval": "0.1", "pause": "1.5", "bullet_speed": "250.0",
            "bullet_accel": "0.0", "line_count": "1", "ring3d_count": "0", "random_angle": "0.0",
            "random_speed_ratio": "0.0", "start_delay": "0.5"}


def _num(props, key):
    return float(props.get(key, DEFAULTS.get(key, "0")))


def _set(props, key, value):
    if isinstance(value, bool):
        props[key] = "true" if value else "false"
    elif isinstance(value, int):
        props[key] = str(value)
    else:
        r = repr(round(value, 4))
        props[key] = r if ("." in r or "e" in r) else r + ".0"


def tune_pattern(props, tier, giant, normal_asis=False):
    """ShotPattern の1つ分(props: 名前 → 文字の値)を、tier 用に変える"""
    if tier == 1 and normal_asis:
        return 1.0
    bc = int(_num(props, "bullet_count"))
    sc = int(_num(props, "shot_count"))
    lc = int(_num(props, "line_count"))
    rc = int(_num(props, "ring3d_count"))
    if tier == 1:
        # 今までの NORMAL(DifficultyTuning._make の NORMAL と同じ)
        if bc >= 6:
            _set(props, "bullet_count", max(round(bc * 0.8), 5))
        if lc >= 4:
            _set(props, "line_count", lc - 1)
        if sc >= 8:
            _set(props, "shot_count", round(sc * 0.85))
        _set(props, "pause", _num(props, "pause") * 1.1)
        return 1.0
    count, shot, ring, speed, interval, pause, rnd = (MILD_SCALE if _mild and tier in MILD_SCALE else SCALE)[tier]
    if giant:
        # カウンター弾(大きい弾): 数は変えない。速さと間だけ、少し
        speed = 1.0 + (speed - 1.0) * 0.5
        pause = 1.0 + (pause - 1.0) * 0.5
    else:
        if bc >= 2 and props.get("spread_angle", "0.0") != "0.0" or bc >= 3:
            _set(props, "bullet_count", max(round(bc * count), 1 if bc < 3 else 2))
        if sc >= 3:
            _set(props, "shot_count", max(round(sc * shot), 2))
        if rc >= 3:
            _set(props, "ring3d_count", max(round(rc * ring), 3))
        if lc >= 2:
            _set(props, "line_count", max(lc + (1 if tier >= 2 else -1) * (1 if tier < 3 else 2), 1))
        _set(props, "interval", _num(props, "interval") * interval)
        if rnd != 1.0:
            for k in ("random_angle", "random_speed_ratio"):
                if k in props:
                    _set(props, k, _num(props, k) * rnd)
    _set(props, "pause", _num(props, "pause") * pause)
    for k in ("bullet_speed", "bullet_accel"):
        if k in props or k == "bullet_speed":
            _set(props, k, _num(props, k) * speed)
    return speed


# ------------------------------------------------------------------ .tres の写し

def parse(text):
    """[(見出し, [(名前, 値) ...]) ...]。最初は ('', ヘッダの行)"""
    sections = []
    cur = None
    for line in text.split("\n"):
        if line.startswith("["):
            cur = [line, []]
            sections.append(cur)
        elif cur is not None and line.strip():
            k, _, v = line.partition(" = ")
            cur[1].append([k, v])
    return sections


def make_tier(src_res, tier, dst_res, normal_asis=False):
    text = open(_fs(src_res), encoding="utf-8").read()
    sections = parse(text)
    shot_id = step_id = None
    for head, _ in sections:
        if "shot_pattern.gd" in head:
            shot_id = re.search(r' id="([^"]+)"]', head).group(1)
        if "bullet_step.gd" in head:
            step_id = re.search(r' id="([^"]+)"]', head).group(1)
    # 各 ShotPattern の速さの倍率(その弾の動き BulletStep も同じ倍率にする)
    step_speed = {}
    for head, lines in sections:
        props = dict(lines)
        if props.get("script") != 'ExtResource("%s")' % shot_id:
            continue
        giant = float(props.get("counter_hp_ratio", "0")) > 0.0
        speed = tune_pattern(props, tier, giant, normal_asis)
        props["skip_auto_tuning"] = "true"
        if head == "[resource]":
            if tier == 3:
                props["another_only"] = "true"
                props["another_made"] = "true"
            else:
                props["min_difficulty"] = str(tier)
                props["max_difficulty"] = str(tier)
        for sid in re.findall(r'SubResource\("([^"]+)"\)', props.get("motion", "")):
            step_speed[sid] = speed
        lines[:] = [[k, v] for k, v in props.items()]
    for head, lines in sections:
        m = re.search(r' id="([^"]+)"]', head)
        if not head.startswith("[sub_resource") or not m or m.group(1) not in step_speed:
            continue
        props = dict(lines)
        if "target_speed" in props:
            _set(props, "target_speed", float(props["target_speed"]) * step_speed[m.group(1)])
        lines[:] = [[k, v] for k, v in props.items()]
    out = []
    for head, lines in sections:
        if head.startswith("[gd_resource"):
            head = re.sub(r' uid="[^"]+"', "", head)
        out.append(head)
        for k, v in lines:
            out.append("%s = %s" % (k, v))
        out.append("")
    os.makedirs(os.path.dirname(_fs(dst_res)), exist_ok=True)
    open(_fs(dst_res), "w", encoding="utf-8", newline="\n").write("\n".join(out))
    return dst_res


# ------------------------------------------------------------------ 大技ごとの、追加の弾幕(HARD は1つ目、ANOTHER は全部)

def extra(p, tier):
    p = P(p)
    p["skip_auto_tuning"] = True
    if tier == 3:
        p["another_only"] = True
        p["another_made"] = True
    else:
        p["min_difficulty"] = tier
        p["max_difficulty"] = tier
    return p


def extras_freeze(tier):
    """凍結: 止まってから狙い直す氷の輪 / 回る氷の針"""
    sp = 1.0 if tier == 2 else 1.12
    out = [P(start_delay=1.6, pause=2.6 if tier == 2 else 2.0, bullet_count=18 if tier == 2 else 24, spread_angle=360.0,
             aim_at_player=False, rotate_per_shot=7.0, bullet_speed=150.0 * sp, bullet="E_Blue_Cian",
             motion=[S(0.45, 0.0, trans="quad"), S(0.5, None), S(0.6, 190.0 * sp, turn="aim", trans="quad", ease="in")])]
    if tier == 3:
        out.append(P(start_delay=2.4, shot_count=26, interval=0.06, pause=1.4, bullet_count=3, spread_angle=360.0,
                     aim_at_player=False, rotate_per_shot=11.0, reverse_every_shots=13, bullet_speed=205.0, bullet="E_Blue_Cian"))
    return out


def extras_antlion(tier):
    """蟻地獄: ゆっくり加速する砂の波紋 / 狙ってくる流れ弾"""
    out = [P(start_delay=1.0, shot_count=2, interval=0.3, pause=2.2 if tier == 2 else 1.7, bullet_count=28 if tier == 2 else 34,
             spread_angle=360.0, aim_at_player=False, rotate_per_shot=6.0, bullet_speed=55.0, bullet_accel=40.0 if tier == 2 else 52.0,
             bullet="E_Pink_Medium")]
    if tier == 3:
        out.append(P(start_delay=1.8, shot_count=6, interval=0.07, pause=1.5, bullet_count=3, spread_angle=26.0,
                     line_count=2, aim_at_player=True, bullet_speed=235.0, bullet="E_Magenta_Aim"))
    return out


def extras_sandstorm(tier):
    """大砂嵐: 上から吹き付ける砂の雨 / 狙う扇"""
    out = [P(start_delay=2.0, shot_count=34 if tier == 2 else 44, interval=0.07 if tier == 2 else 0.055, pause=1.6,
             bullet_count=1, aim_at_player=False, random_angle=48.0, random_speed_ratio=0.35, random_seed=79,
             bullet_speed=165.0 if tier == 2 else 185.0, bullet="E_Blue_Cian",
             muzzle_offsets=[(-150.0, -30.0), (-60.0, -40.0), (60.0, -40.0), (150.0, -30.0)])]
    if tier == 3:
        out.append(P(start_delay=1.4, shot_count=3, interval=0.16, pause=1.3, bullet_count=9, spread_angle=70.0,
                     aim_at_player=True, bullet_speed=225.0, bullet="E_Magenta_Aim"))
    return out


def extras_giga(tier):
    """ギガ・コア: 狙う3本の流れ / 加速する回る輪"""
    out = [P(start_delay=1.2, shot_count=5, interval=0.1, pause=1.7 if tier == 2 else 1.3, bullet_count=3, spread_angle=22.0,
             aim_at_player=True, bullet_speed=215.0 if tier == 2 else 240.0, bullet="E_Magenta_Aim")]
    if tier == 3:
        out.append(P(start_delay=2.6, shot_count=3, interval=0.2, pause=1.6, bullet_count=36, spread_angle=360.0,
                     aim_at_player=False, rotate_per_shot=5.0, bullet_speed=70.0, bullet_accel=70.0, bullet="E_Red_Normal"))
    return out


def extras_hydra(tier):
    """ヒュドラ: 左右に振れる洗濯機 / 狙う速い針"""
    out = [P(start_delay=1.5, shot_count=40, interval=0.065 if tier == 2 else 0.05, pause=1.6, bullet_count=4 if tier == 2 else 5,
             spread_angle=360.0, aim_at_player=False, rotate_per_shot=8.0, reverse_every_shots=20,
             bullet_speed=150.0 if tier == 2 else 170.0, bullet="E_Green_Curve")]
    if tier == 3:
        out.append(P(start_delay=2.2, shot_count=4, interval=0.09, pause=1.2, bullet_count=1, line_count=3,
                     aim_at_player=True, bullet_speed=265.0, bullet="E_Magenta_Aim"))
    return out


C = "res://Resources/ShotPatterns/Counter/"
F = "res://Resources/ShotPatterns/Stage4/Final/"
SPELLS = [
    ("res://GameScene/Enemy/BOSS_TANK.tscn", "CounterSpell", "sp1",
     [C + "sp1_freeze_scatter.tres", C + "sp1_light_aim.tres", C + "sp1_frozen_giant.tres"], extras_freeze),
    ("res://GameScene/Train/train_limited.tscn", "CounterSpell", "sp2",
     [C + "sp2_sand_slide.tres", C + "sp2_light_line.tres", C + "sp2_jaw.tres"], extras_antlion),
    ("res://GameScene/Enemy/Sky/blackswan_kai.tscn", "CounterSpell", "sp3",
     [C + "sp3_sand_wind_L.tres", C + "sp3_sand_wind_R.tres", C + "sp3_sand_swirl.tres", C + "sp3_sand_gust_L.tres",
      C + "sp3_sand_gust_R.tres", C + "sp3_debris.tres", C + "sp3_light_fan.tres", C + "sp3_storm_giant.tres"], extras_sandstorm),
    ("res://GameScene/Enemy/Stage4/nucleo_core_boss.tscn", "GigaSpell", "sp4g",
     [F + "fin_giga_core.tres", F + "fin_residue_spiral.tres", C + "sp1_light_aim.tres"], extras_giga),
    ("res://GameScene/Enemy/Stage4/nucleo_core_boss.tscn", "HydraSpell", "sp4h",
     [C + "sp4_hydra_heads.tres", F + "fin_residue_spiral.tres"], extras_hydra),
]
TIER_NAME = {0: "e", 1: "n", 2: "h", 3: "a"}


def build_spell(scene, node, prefix, sources, extras):
    global _mild
    _mild = prefix in MILD
    paths = []
    for tier in (0, 1, 2, 3):
        for src in sources:
            stem = os.path.basename(src)[:-5]
            # 最終面は弾幕を一段上に扱う(NORMAL でも HARD の弾幕だった)ので、NORMAL は元のまま
            paths.append(make_tier(src, tier, OUT + "%s_%s_%s.tres" % (prefix, stem, TIER_NAME[tier]), prefix.startswith("sp4")))
        if tier >= 2:
            for i, p in enumerate(extras(tier)):
                paths.append(write(OUT + "%s_extra%d_%s.tres" % (prefix, i + 1, TIER_NAME[tier]), extra(p, tier)))
    wire(scene, node, prefix, paths)
    return paths


def wire(scene, node, prefix, paths):
    """シーンの CounterSpell(node)の Patterns を、作った写しに置き換える"""
    fs = _fs(scene)
    text = open(fs, encoding="utf-8").read()
    ids = []
    new_ext = []
    for path in paths:
        rid = "ct_" + os.path.basename(path)[:-5]
        ids.append(rid)
        line = '[ext_resource type="Resource" path="%s" id="%s"]' % (path, rid)
        if 'id="%s"]' % rid not in text:
            new_ext.append(line)
    # ext_resource は、最後の ext_resource の後ろに足す
    if new_ext:
        last = [m.end() for m in re.finditer(r"^\[ext_resource[^\n]*\]$", text, re.M)][-1]
        text = text[:last] + "\n" + "\n".join(new_ext) + text[last:]
    head = re.search(r'^\[node name="%s"[^\n]*\]$' % re.escape(node), text, re.M)
    end = text.find("\n[", head.end())
    end = len(text) if end < 0 else end
    block = text[head.end():end]
    script_id = re.search(r'^patterns = Array\[ExtResource\("([^"]+)"\)\]', block, re.M).group(1)
    arr = 'patterns = Array[ExtResource("%s")]([%s])' % (script_id, ", ".join('ExtResource("%s")' % i for i in ids))
    block = re.sub(r"^patterns = .*$", lambda _: arr, block, count=1, flags=re.M)
    text = text[:head.end()] + block + text[end:]
    # load_steps は Godot が直すので、書いていれば消す
    text = re.sub(r"^(\[gd_scene[^\n]*?) load_steps=\d+", r"\1", text, count=1, flags=re.M)
    open(fs, "w", encoding="utf-8", newline="\n").write(text)


if __name__ == "__main__":
    total = 0
    for spell in SPELLS:
        total += len(build_spell(*spell))
    print("wrote %d patterns" % total)
