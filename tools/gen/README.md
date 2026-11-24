# 弾幕の生成と測定(開発用)

- `barrages.py` … 限定弾幕・最終面(ヌクレオ / 中枢防衛艦 / ブラッドスワン / ワゴン)の弾幕の定義。`python tools/gen/barrages.py` で .tres を書き直す(uid は保たれる)。名前の一部を渡すと、その弾幕だけ書く。
- `shotgen.py` … ShotPattern の .tres を Python の dict から書く。
- `tres_edit.py` … .tres / .tscn を少しだけ書き換える道具。
- 測る: `godot --headless --path . --fixed-fps 60 res://tools/barrage_lab.tscn -- 設定.json`(使い方は barrage_lab.gd の先頭)。
