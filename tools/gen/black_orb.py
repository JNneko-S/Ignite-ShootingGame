"""真っ黒のオーブ弾の絵(4コマの横並び)を書く。Run: python black_orb.py
芯は真っ黒、ふちは脈打つ深紅、外側は暗い紫の光。標準ライブラリだけで PNG を書く。
"""
import math
import os
import struct
import zlib

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "Assets", "SECRET", "black_orb.png")
SIZE = 18
FRAMES = 4


def pixel(x, y, frame):
    c = (SIZE - 1) / 2.0
    r = math.hypot(x - c, y - c)
    pulse = 0.65 + 0.35 * math.sin(frame / FRAMES * math.tau)
    if r < 4.6:
        # 真っ黒な芯(ふちに向かって、ほんの少し紫)
        t = r / 4.6
        col = (int(4 + 30 * t ** 3), 0, int(8 + 40 * t ** 3), 255)
        # 左上の小さな光
        h = math.hypot(x - (c - 1.6), y - (c - 1.8))
        if h < 1.2:
            k = 1.0 - h / 1.2
            col = (int(col[0] + 150 * k), int(60 * k), int(col[2] + 170 * k), 255)
        return col
    if r < 6.0:
        # 脈打つ深紅のふち(当たり判定のふちと同じくらい)
        t = 1.0 - abs(r - 5.3) / 0.7
        return (int((150 + 100 * pulse) * (0.6 + 0.4 * t)), int(10 * pulse), int(40 + 30 * pulse), 255)
    if r < 8.4:
        # 外側の暗い紫の光(うすく、細く)
        t = 1.0 - (r - 6.0) / 2.4
        return (int(90 + 40 * pulse), 0, int(110 + 30 * pulse), int(150 * t ** 2.0 * (0.7 + 0.3 * pulse)))
    return (0, 0, 0, 0)


def main():
    w, h = SIZE * FRAMES, SIZE
    rows = []
    for y in range(h):
        row = bytearray([0])  # フィルタなし
        for x in range(w):
            row.extend(pixel(x % SIZE, y, x // SIZE))
        rows.append(bytes(row))
    raw = b"".join(rows)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    open(OUT, "wb").write(png)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
