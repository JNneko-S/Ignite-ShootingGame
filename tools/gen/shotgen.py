"""Write ShotPattern .tres files from Python dicts.

P(**props) builds a pattern. Special keys:
  bullet   : short bullet scene name ("E_Blue_Cian") or None (auto by the documented rules)
  motion   : list of S(...) steps
  split    : nested P (split_pattern)
  with_    : list of nested P or "res://..." paths (with_patterns)
  normal / easy / another / black : nested P or path (difficulty versions)
"""
import os

ROOT = __import__("os").path.abspath(__import__("os").path.join(__import__("os").path.dirname(__file__), "..", ".."))
SHOT_UID = "uid://ct8u3n22w477n"
STEP_UID = "uid://bh3bd44efapvd"

TURN = {"keep": 0, "add": 1, "aim": 2, "abs": 3, "group": 4, "random": 5}
TRANS = {"linear": 0, "sine": 1, "quint": 2, "quart": 3, "quad": 4, "expo": 5, "elastic": 6,
         "cubic": 7, "circ": 8, "bounce": 9, "back": 10, "spring": 11}
EASE = {"in": 0, "out": 1, "in_out": 2, "out_in": 3}


class S(dict):
    """BulletStep. S(dur, speed=None(keep)|float, turn='keep', angle=0, trans='sine', ease='out', av=0)"""
    def __init__(self, duration, speed=None, turn="keep", angle=0.0, trans="sine", ease="out", av=0.0):
        super().__init__(duration=duration, speed=speed, turn=turn, angle=angle, trans=trans, ease=ease, av=av)


class P(dict):
    pass


def _fmt(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        r = repr(round(v, 4))
        return r if ("." in r or "e" in r) else r + ".0"
    if isinstance(v, tuple) and len(v) == 2:
        return "Vector2(%s, %s)" % (_fmt(float(v[0])), _fmt(float(v[1])))
    if isinstance(v, str):
        return '"%s"' % v
    raise TypeError(v)


def _auto_bullet(p):
    """Bullet look by the rules in shot_pattern.gd."""
    if p.get("split") is not None or p.get("split_vanish"):
        return "E_Spiky_Split" if not p.get("split_vanish") else "E_Pink_Medium"
    motion = p.get("motion") or []
    if any(s["speed"] is not None and s["speed"] <= 20 for s in motion):
        return "E_Pink_Medium"
    if p.get("bullet_accel", 0) < 0:
        return "E_Pink_Medium"
    if any(s["av"] for s in motion):
        return "E_Green_Curve"
    if p.get("aim_at_player", True) and p.get("spread_angle", 0) <= 60 and not p.get("rotate_per_shot"):
        return "E_Magenta_Aim"
    if p.get("bullet_accel", 0) > 0:
        return "E_medium_flamy"
    if (not p.get("aim_at_player", True) and not p.get("spread_angle") and not p.get("base_angle")
            and not p.get("rotate_per_shot")):
        return "E_Bermuda"
    return "E_Blue_Cian"


class _Writer:
    def __init__(self, res_path):
        self.res_path = res_path
        self.ext = {}        # path -> (type, id)
        self.subs = []       # text blocks
        self.n = 0

    def ext_id(self, rtype, path):
        if path not in self.ext:
            self.ext[path] = (rtype, "e%d" % (len(self.ext) + 1))
        return self.ext[path][1]

    def new_id(self, prefix):
        self.n += 1
        return "%s%d" % (prefix, self.n)

    def step(self, s):
        sid = self.new_id("st")
        lines = ['[sub_resource type="Resource" id="%s"]' % sid, 'script = ExtResource("%s")' % self.ext_id("Script", "step")]
        lines.append("duration = %s" % _fmt(float(s["duration"])))
        if TURN[s["turn"]]:
            lines.append("turn_mode = %d" % TURN[s["turn"]])
        if s["angle"]:
            lines.append("turn_angle = %s" % _fmt(float(s["angle"])))
        if s["speed"] is None:
            lines.append("change_speed = false")
        else:
            lines.append("target_speed = %s" % _fmt(float(s["speed"])))
            if TRANS[s["trans"]] != 1:
                lines.append("speed_trans = %d" % TRANS[s["trans"]])
            if EASE[s["ease"]] != 1:
                lines.append("speed_ease = %d" % EASE[s["ease"]])
        if s["av"]:
            lines.append("angular_velocity = %s" % _fmt(float(s["av"])))
        self.subs.append("\n".join(lines))
        return 'SubResource("%s")' % sid

    def ref(self, v):
        if isinstance(v, str):
            return 'ExtResource("%s")' % self.ext_id("Resource", v)
        sid = self.new_id("p")
        body = self.body(v)
        self.subs.append('[sub_resource type="Resource" id="%s"]\n%s' % (sid, body))
        return 'SubResource("%s")' % sid

    def body(self, p):
        p = dict(p)
        lines = ['script = ExtResource("%s")' % self.ext_id("Script", "shot")]
        bullet = p.pop("bullet", "auto")
        if bullet == "auto":
            bullet = _auto_bullet(p)
        if bullet:
            lines.append('bullet_scene = ExtResource("%s")' % self.ext_id("PackedScene", "res://GameScene/Bullet/%s.tscn" % bullet))
        for key, prop in (("normal", "normal_version"), ("easy", "easy_version"), ("another", "another_version"), ("black", "black_version")):
            v = p.pop(key, None)
            if v is not None:
                lines.append("%s = %s" % (prop, self.ref(v)))
        with_ = p.pop("with_", None)
        motion = p.pop("motion", None)
        split = p.pop("split", None)
        offsets = p.pop("muzzle_offsets", None)
        for k, v in p.items():
            lines.append("%s = %s" % (k, _fmt(v)))
        if offsets:
            lines.append("muzzle_offsets = Array[Vector2]([%s])" % ", ".join(_fmt(o) for o in offsets))
        if with_:
            lines.append('with_patterns = Array[ExtResource("%s")]([%s])' % (self.ext_id("Script", "shot"), ", ".join(self.ref(w) for w in with_)))
        if motion:
            lines.append('motion = Array[ExtResource("%s")]([%s])' % (self.ext_id("Script", "step"), ", ".join(self.step(s) for s in motion)))
        if split is not None:
            lines.append("split_pattern = %s" % self.ref(split))
        return "\n".join(lines)


def write(res_path, p):
    """res_path: res://... .tres"""
    w = _Writer(res_path)
    w.ext_id("Script", "shot")
    body = w.body(p)
    out = ['[gd_resource type="Resource" script_class="ShotPattern" format=3]', ""]
    for path, (rtype, rid) in w.ext.items():
        if path == "shot":
            out.append('[ext_resource type="Script" uid="%s" path="res://Resources/ShotPatterns/shot_pattern.gd" id="%s"]' % (SHOT_UID, rid))
        elif path == "step":
            out.append('[ext_resource type="Script" uid="%s" path="res://Resources/ShotPatterns/bullet_step.gd" id="%s"]' % (STEP_UID, rid))
        else:
            out.append('[ext_resource type="%s" path="%s" id="%s"]' % (rtype, path, rid))
    out.append("")
    for block in w.subs:
        out.append(block)
        out.append("")
    out.append("[resource]")
    out.append(body)
    out.append("")
    fs = os.path.join(ROOT, res_path.replace("res://", ""))
    os.makedirs(os.path.dirname(fs), exist_ok=True)
    # keep an existing uid line if the file exists (so references stay valid)
    text = "\n".join(out)
    if os.path.exists(fs):
        old = open(fs, encoding="utf-8").read().split("\n", 1)[0]
        if 'uid="' in old:
            text = old + text[text.index("\n"):]
    open(fs, "w", encoding="utf-8", newline="\n").write(text)
    return res_path
