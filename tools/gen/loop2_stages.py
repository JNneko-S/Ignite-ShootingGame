"""二周目のタイムライン(StageN の二周目版)を、一周目のタイムラインから作る。Run: python loop2_stages.py
作り直す内容(作者の方針):
  ・雑魚の数を増やす(1機の弾は、二周目用の少ない自機狙い Z_AIR / Z_GROUND に替える)
  ・難易度ごとの数(Count By Difficulty): EASY は少なめ、HARD は全部
  ・出てくる順番を変える: 近い時間に出る空の雑魚どうしで出る時刻を入れ替え、1つおきに左右を反転する
  ・切り返しの隊列(左右の縦列。Z_COLUMN)を、各ステージの決まった時刻に足す
  ・ボス・中ボス・イグナイトのおとり・列車・小道具・特別な弾幕(グレイズ・イグナイト用)の雑魚は、そのまま
できたタイムラインは、一周目の StageData の Second Loop に入れる(手で直してもよい。もう一度実行すると作り直す)。
"""
import os
import re
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import loop2 as L

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
COLUMN_MOVE = "res://Resources/MovePatterns/Loop2/m_l2_column.tres"

ZAKO_HP = 1.2
BOSS_HP = 1.12
AIR = {"formation", "formation_kai", "sniper", "charger", "bomber", "bomber_kai", "bee_worker"}
GROUND = {"tank_small", "tank_squad"}

STAGES = [
    # (一周目, 二周目, 地上の雑魚の数も増やすか, 縦列の雑魚, 縦列を出す時刻)
    ("Resources/StageData/Stage1TankRush.tres", "Resources/StageData/Loop2/Stage1_Loop2.tres", True,
     "res://GameScene/Enemy/Zako/formation.tscn", [19.0, 37.5, 64.0, 86.0, 109.5]),
    ("Resources/StageData/Stage2.tres", "Resources/StageData/Loop2/Stage2_Loop2.tres", False,
     "res://GameScene/Enemy/Zako/formation.tscn", [11.0, 30.0, 46.5, 66.0, 87.0],
     # 2面の道中は弾幕戦: 中型機はグレイズしやすい弾幕、重戦車は中ボス戦車として何度も出る
     dict(mid_scenes={"gunship", "armored", "absorber"}, heavy_times=[14.0, 31.0, 47.5, 66.5, 77.5, 83.5], heavy_hp=2200)),
    ("Resources/StageData/Stage3.tres", "Resources/StageData/Loop2/Stage3_Loop2.tres", False,
     "res://GameScene/Enemy/Zako/formation.tscn", [10.5, 47.5, 67.0, 86.0, 116.0]),
    ("Resources/StageData/Stage4.tres", "Resources/StageData/Loop2/Stage4_Loop2.tres", False,
     "res://GameScene/Enemy/Stage4/formation_kai.tscn", [4.0, 30.0, 67.5, 95.0, 134.5, 172.0]),
]

BLOCK = re.compile(r'\[sub_resource type="Resource" id="([^"]+)"\]\n(.*?)(?=\n\n\[|\n\[|\Z)', re.S)


def kv_get(body, key):
    m = re.search(r'^%s = (.*)$' % re.escape(key), body, re.M)
    return m.group(1) if m else None


def kv_set(body, key, value):
    pat = re.compile(r'^%s = .*$' % re.escape(key), re.M)
    if value is None:
        return pat.sub("", body).replace("\n\n", "\n").strip("\n")
    if pat.search(body):
        return pat.sub("%s = %s" % (key, value), body, count=1)
    return body.rstrip("\n") + "\n%s = %s" % (key, value)


def vec(v):
    if v is None:
        return (0.0, 0.0)
    a, b = re.findall(r'-?[\d.]+(?:e-?\d+)?', v.replace("Vector2", ""))[:2]
    return (float(a), float(b))


def fvec(x, y):
    def f(n):
        r = repr(round(n, 3))
        return r[:-2] if r.endswith(".0") else r
    return "Vector2(%s, %s)" % (f(x), f(y))


def ffloat(n):
    r = repr(round(n, 3))
    return r if "." in r else r + ".0"


def write_text(path, text):
    """書き込む(Godot のエディタが読んでいる最中だと、Windows で開けないことがあるので、少し待って書き直す)"""
    import time
    for attempt in range(20):
        try:
            tmp = path + ".tmp"
            with open(tmp, "w", encoding="utf-8", newline="\n") as f:
                f.write(text)
            os.replace(tmp, path)
            return
        except OSError:
            time.sleep(0.3)
    raise OSError("書けません: " + path)


def build(src, dst, ground_more, column_scene, column_times, extra=None):
    extra = extra or {}
    s = open(os.path.join(ROOT, src), encoding="utf-8").read()
    # 一周目につないだ二周目(自分自身)への参照は、写さない
    s = re.sub(r'^\[ext_resource [^\n]*id="l2_second_loop"\]\n', "", s, flags=re.M)
    s = re.sub(r'^second_loop = .*\n?', "", s, flags=re.M)
    ext = {m.group(2): m.group(1) for m in re.finditer(r'\[ext_resource [^\]]*path="([^"]+)" id="([^"]+)"\]', s)}
    pid = {v: k for k, v in ext.items()}
    spawn_id = pid["res://spawn_event.gd"]
    shot_id = pid.get("res://Resources/ShotPatterns/shot_pattern.gd")
    added = []

    def ext_id(rtype, path, want):
        nonlocal s, shot_id
        if path in pid:
            return pid[path]
        line = '[ext_resource type="%s" path="%s" id="%s"]\n' % (rtype, path, want)
        last = list(re.finditer(r'^\[ext_resource [^\n]*\n', s, re.M))[-1]
        s = s[:last.end()] + line + s[last.end():]
        pid[path] = want
        ext[want] = path
        return want

    if shot_id is None:
        shot_id = ext_id("Script", "res://Resources/ShotPatterns/shot_pattern.gd", "l2_shot_script")

    def pattern_array(paths):
        refs = ['ExtResource("%s")' % ext_id("Resource", p, "l2_" + os.path.basename(p)[:-5]) for p in paths]
        return 'Array[ExtResource("%s")]([%s])' % (shot_id, ", ".join(refs))

    # 使うリソースを先に足しておく(あとで足すと、下で覚えた位置がずれる)
    for p in L.Z_AIR + L.Z_GROUND + L.Z_COLUMN + L.Z2_TANK + L.Z2_MID:
        ext_id("Resource", p, "l2_" + os.path.basename(p)[:-5])
    ext_id("PackedScene", column_scene, "l2_column_scene")
    ext_id("Resource", COLUMN_MOVE, "l2_column_move")

    blocks = []
    for m in BLOCK.finditer(s):
        rid, body = m.group(1), m.group(2)
        if kv_get(body, "script") != 'ExtResource("%s")' % spawn_id or kv_get(body, "enemy_scene") is None:
            continue
        scene_path = ext[re.search(r'"([^"]+)"', kv_get(body, "enemy_scene")).group(1)]
        blocks.append(dict(id=rid, body=body, start=m.start(2), end=m.end(2),
                           scene=os.path.basename(scene_path)[:-5], time=float(kv_get(body, "time") or 0.0)))
    boss_time = min([b["time"] for b in blocks if kv_get(b["body"], "is_boss") == "true"] + [9999.0])
    last_boss = max([b["time"] for b in blocks if kv_get(b["body"], "boss_time_bonus") == "true" or
                     kv_get(b["body"], "tag") in ('"boss"', '"final"')] + [9999.0])

    def special(b):
        body = b["body"]
        if kv_get(body, "is_boss") == "true" or kv_get(body, "tag") or kv_get(body, "flight_curve"):
            return True
        sp = kv_get(body, "shot_patterns") or ""
        ids = re.findall(r'ExtResource\("([^"]+)"\)', sp)[1:]
        return any(("graze" in ext[i] or "ignite" in ext[i]) for i in ids)

    same_time = {}
    for b in blocks:
        same_time.setdefault((b["scene"], b["time"]), []).append(b)

    # ---- 数を増やして、弾を替える
    for b in blocks:
        if special(b):
            continue
        air = b["scene"] in AIR
        ground = b["scene"] in GROUND
        if not (air or ground):
            continue
        body = b["body"]
        n = int(kv_get(body, "count") or 1)
        if air or ground_more:
            if n >= 2:
                add = min(n, 8)   # 倍(多い隊列は +8 まで)
                new = n + add
                step = vec(kv_get(body, "offset_step"))
                interval = float(kv_get(body, "interval") or 0.3)
                if step != (0.0, 0.0):
                    k = (n - 1) / float(new - 1)
                    body = kv_set(body, "offset_step", fvec(step[0] * k, step[1] * k))
                    if interval > 0.0:
                        body = kv_set(body, "interval", ffloat(interval * k))
                elif interval > 0.0:
                    body = kv_set(body, "interval", ffloat(interval * n / float(new) * 1.15))
                body = kv_set(body, "count", str(new))
                cbd = [max(1, round(new * 0.7)), max(1, round(new * 0.85)), new]
                body = kv_set(body, "count_below_another", None)
                body = kv_set(body, "count_by_difficulty", "Array[int]([%s])" % ", ".join(str(c) for c in cbd))
        body = kv_set(body, "shot_patterns", pattern_array(L.Z_AIR if air else L.Z_GROUND))
        b["body"] = body

    # ---- 弾幕戦のステージ: 中型機の弾幕と、中ボス戦車
    heavy_body = None
    for b in blocks:
        if special(b):
            continue
        if b["scene"] in extra.get("mid_scenes", ()):
            sp = kv_get(b["body"], "shot_patterns") or ""
            ids = re.findall(r'ExtResource\("([^"]+)"\)', sp)[1:]
            if not any("bonus" in ext.get(i, "") for i in ids):
                b["body"] = kv_set(b["body"], "shot_patterns", pattern_array(L.Z2_MID))
        elif b["scene"] == "tank_heavy" and "heavy_hp" in extra:
            b["body"] = kv_set(b["body"], "shot_patterns", pattern_array(L.Z2_TANK))
            b["body"] = kv_set(b["body"], "hp_override", str(extra["heavy_hp"]))
            heavy_body = heavy_body or b["body"]

    # ---- 出てくる順番を変える(空の雑魚)
    air = sorted([b for b in blocks if b["scene"] in AIR and not special(b) and b["time"] < boss_time - 4.0
                  and b["time"] < last_boss - 6.0], key=lambda b: b["time"])
    i = 0
    while i + 1 < len(air):
        a, c = air[i], air[i + 1]
        if abs(a["time"] - c["time"]) <= 6.0 and (a["scene"], a["time"]) != (c["scene"], c["time"]):
            a["new_time"], c["new_time"] = c["time"], a["time"]
            i += 2
        else:
            i += 1
    for k, b in enumerate(air):
        if "new_time" in b:
            b["body"] = kv_set(b["body"], "time", ffloat(b["new_time"]))
        if k % 2 == 0 and len(same_time[(b["scene"], b["time"])]) == 1:
            mirrored = kv_get(b["body"], "mirror_x") == "true"
            b["body"] = kv_set(b["body"], "mirror_x", None if mirrored else "true")

    # ---- 書き戻す(後ろから)
    for b in sorted(blocks, key=lambda b: -b["start"]):
        s = s[:b["start"]] + b["body"] + s[b["end"]:]

    # ---- 切り返しの隊列(左右の縦列)
    col_scene = ext_id("PackedScene", column_scene, "l2_column_scene")
    col_move = ext_id("Resource", COLUMN_MOVE, "l2_column_move")
    new_blocks = []
    for j, t in enumerate(column_times):
        for side, mirror in (("l", False), ("r", True)):
            rid = "l2_column_%d_%s" % (j, side)
            lines = ['script = ExtResource("%s")' % spawn_id,
                     'enemy_scene = ExtResource("%s")' % col_scene,
                     'move_pattern = ExtResource("%s")' % col_move,
                     "shot_patterns = %s" % pattern_array(L.Z_COLUMN),
                     "count = 5", "interval = 0.0", "offset_step = Vector2(0, -32)",
                     "count_by_difficulty = Array[int]([3, 4, 5])",
                     "power_drop_chance = 0.0",
                     "time = %s" % ffloat(t + (0.35 if mirror else 0.0))]
            if mirror:
                lines.insert(3, "mirror_x = true")
            new_blocks.append((rid, "\n".join(lines)))
    if heavy_body:
        for j, t in enumerate(extra.get("heavy_times", [])):
            new_blocks.append(("l2_heavy_%d" % j, kv_set(heavy_body, "time", ffloat(t))))
    i = s.find("\n[resource]")
    s = s[:i] + "".join('\n\n[sub_resource type="Resource" id="%s"]\n%s' % (rid, body) for rid, body in new_blocks) + s[i:]
    m = re.search(r'^(events = Array\[[^\]]+\]\(\[)(.*?)(\]\))$', s, re.M)
    inner = m.group(2) + "".join(', SubResource("%s")' % rid for rid, _ in new_blocks)
    s = s[:m.start(2)] + inner + s[m.end(2):]

    # ---- ステージの設定: 二周目の雑魚の弾は手で決めたので、間をのばさない。名前に印
    s = re.sub(r'^zako_fire_interval_scale = .*\n', "", s, flags=re.M)
    # 硬さ: 雑魚 ×1.2、ボス・中ボス ×1.12(一周目の倍率に掛ける。やりすぎない程度)
    for key, k in (("zako_hp_scale_below_another", ZAKO_HP), ("boss_hp_scale_below_another", BOSS_HP)):
        m = re.search(r'^%s = (.*)$' % key, s, re.M)
        base = float(m.group(1)) if m else 1.0
        s = re.sub(r'^%s = .*\n' % key, "", s, flags=re.M)
        s = s.rstrip("\n") + "\n%s = %s\n" % (key, ffloat(min(base * k, 2.0)))
    s = re.sub(r'^second_loop = .*\n', "", s, flags=re.M)
    s = re.sub(r'^(stage_name = ")(.*)(")$', lambda mm: mm.group(1) + mm.group(2) + " (2nd)" + mm.group(3), s, count=1, flags=re.M)
    # uid は付けない(新しいリソース)
    s = re.sub(r'^(\[gd_resource [^\]]*?) uid="[^"]*"', r'\1', s, count=1)
    out = os.path.normpath(os.path.join(ROOT, dst))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    if os.path.exists(out):
        old = open(out, encoding="utf-8").read().split("\n", 1)[0]
        if 'uid="' in old:
            s = old + s[s.index("\n"):]
    write_text(out, s)

    # ---- 一周目のタイムラインに、二周目のタイムラインをつなぐ
    base_path = os.path.normpath(os.path.join(ROOT, src))
    base = open(base_path, encoding="utf-8").read()
    res_path = "res://" + dst.replace("\\", "/")
    if res_path not in base:
        line = '[ext_resource type="Resource" path="%s" id="l2_second_loop"]\n' % res_path
        last = list(re.finditer(r'^\[ext_resource [^\n]*\n', base, re.M))[-1]
        base = base[:last.end()] + line + base[last.end():]
    base = re.sub(r'^second_loop = .*\n', "", base, flags=re.M)
    base = base.rstrip("\n") + '\nsecond_loop = ExtResource("l2_second_loop")\n'
    write_text(base_path, base)
    return sum(1 for b in blocks if b["scene"] in AIR | GROUND), len(new_blocks)


if __name__ == "__main__":
    for row in STAGES:
        print(row[1], build(*row))
