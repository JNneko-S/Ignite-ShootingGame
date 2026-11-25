"""二周目の弾幕を、ボス・中ボスのシーンの砲口へつなぐ。Run: python wire_loop2.py
ShooterPhase(段階ごと)か、EnemyShooter のノード(段階のない中ボス)に、
loop2_replace / loop2_patterns / loop2_sequence を書く。副砲には触らない。
"""
import os
import re
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tres_edit import Tres
import loop2 as L

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SHOT_PATH = "res://Resources/ShotPatterns/shot_pattern.gd"
SHOT_UID = "uid://ct8u3n22w477n"


def shot_id(t):
    m = re.search(r'\[ext_resource type="Script"[^\]]*path="%s" id="([^"]+)"\]' % re.escape(SHOT_PATH), t.s)
    if m:
        return m.group(1)
    line = '[ext_resource type="Script" uid="%s" path="%s" id="l2_shot_script"]\n' % (SHOT_UID, SHOT_PATH)
    last = list(re.finditer(r'^\[ext_resource [^\n]*\n', t.s, re.M))[-1]
    t.s = t.s[:last.end()] + line + t.s[last.end():]
    return "l2_shot_script"


def arr(t, sid, paths):
    refs = []
    for p in paths:
        rid = t.ext("Resource", p, "l2_" + os.path.basename(p).replace(".tres", ""))
        refs.append('ExtResource("%s")' % rid)
    return 'Array[ExtResource("%s")]([%s])' % (sid, ", ".join(refs))


def wire(scene, header, sequence, patterns=()):
    t = Tres(os.path.join(ROOT, scene))
    sid = shot_id(t)
    assert header in t.s, (scene, header)
    t.set_in_block(header, "loop2_replace", "true")
    t.set_in_block(header, "loop2_patterns", arr(t, sid, list(patterns)))
    t.set_in_block(header, "loop2_sequence", arr(t, sid, list(sequence)))
    t.save()


def sub(rid):
    return '[sub_resource type="Resource" id="%s"]' % rid


S = L.seq
# 1面
wire("GameScene/Enemy/Zako/midboss_split.tscn",
     '[node name="EnemyShooterComponent" parent="." index="4" unique_id=140393654]', S(L.MB1))
for i, phase in enumerate(L.TANK):
    wire("GameScene/Enemy/BOSS_TANK.tscn", sub("main_p%d" % (i + 1)), S(phase))
# 2面
for scene in ["GameScene/Train/train_rapid.tscn", "GameScene/Train/train_express.tscn"]:
    t = Tres(os.path.join(ROOT, scene))
    top = re.search(r'^\[node name="Gun_m_top"[^\n]*\]', t.s, re.M).group(0)
    mid = re.search(r'^\[node name="Gun_m_mid"[^\n]*\]', t.s, re.M).group(0)
    wire(scene, top, S([L.TRAIN_MB[0]]))
    wire(scene, mid, S([L.TRAIN_MB[1]]))
for i, phase in enumerate(L.TRAIN):
    wire("GameScene/Train/train_limited.tscn", sub("sp_m_top_%d" % i), S(phase))
    wire("GameScene/Train/train_limited.tscn", sub("sp_m_mid_%d" % i), S(L.TRAIN_MID))
# 3面
wire("GameScene/Enemy/Sky/black_swans.tscn",
     '[node name="EnemyShooterComponent" parent="." index="4" unique_id=140393654]', S(L.SWANS_MB))
for i, phase in enumerate(L.KAI):
    wire("Resources/ShotPatterns/Boss/BlackSwan/BlackSwan.tscn", sub("main_p%d" % (i + 1)), S(phase))
# 4面
for i, phase in enumerate(L.TKAI):
    wire("GameScene/Enemy/Stage4/tank_kai_boss.tscn", sub("main_p%d" % (i + 1)), S(phase))
# ブラッドスワン: 専用弾幕(blood_swan.py)。一周目の Sequence も専用弾幕に替える
import blood_swan as BS


def set_sequence(scene, header, paths):
    t = Tres(os.path.join(ROOT, scene))
    t.set_in_block(header, "sequence", arr(t, shot_id(t), paths))
    t.save()


for i, (one, two) in enumerate(zip(BS.phases(1), BS.phases(2))):
    set_sequence("GameScene/Enemy/Stage4/blood_swan.tscn", sub("bs_main_p%d" % (i + 1)), one)
    wire("GameScene/Enemy/Stage4/blood_swan.tscn", sub("bs_main_p%d" % (i + 1)), two)
for i, phase in enumerate(L.GUARD):
    wire("GameScene/Enemy/Stage4/final_weapon.tscn", sub("main_p%d" % (i + 1)), S(phase))
for i, phase in enumerate(L.NUCLEO):
    wire("GameScene/Enemy/Stage4/nucleo_core_boss.tscn", sub("main_p%d" % (i + 1)), S(phase))
print("wired")
