@tool
extends Resource
class_name FlightCurve
## 数式の曲線に沿って飛ぶ設定(ステージ3の爆撃機の編隊など)。SpawnEvent の Flight Curve に入れる。
## 何機かを、曲線の上に等間隔(Phase Step)で並べて同時に飛ばすと、編隊の通った跡(機雷)で図形が描ける。
##   例) 円 + 6機 + Phase Step 1/6 → 6機の輪が回りながら、機雷で円を描く
##       星形(5頂点・2つ飛ばし) + 5機 + Phase Step 1/5 → 星(五芒星)を描く
## 左右反転(Mirror X / Alternate Mirror)で出すと、図形も回る向きも左右反転する

enum Shape {
	CIRCLE,    ## 円(楕円)。真上から時計回り
	ROSE,      ## バラ曲線 r = cos(kθ)。k 枚の花びら(k が偶数なら 2k 枚)
	LISSAJOUS, ## リサージュ(x = sin θ, y = sin kθ)。k = 2 で横向きの8の字
	SINE,      ## 正弦波。左から右へ横切りながら、k 回うねる
	STAR,      ## 星形の多角形。k 個の頂点を、Star Skip 個飛ばしでつなぐ(k=5, 飛ばし 2 で五芒星)
}

@export var shape : Shape = Shape.CIRCLE
## 図形の中心(画面の座標)
@export var center : Vector2 = Vector2(240, 260)
## 図形の大きさ(横・縦の半径 px)。SINE は、横は端から端までの半分、縦はうねりの高さ
@export var radius : Vector2 = Vector2(130, 130)
## k(花びら・うねり・頂点の数)
@export var k : int = 3
## STAR のとき、頂点を何個飛ばしでつなぐか
@export var star_skip : int = 2
## 図形を1周するのにかかる秒数
@export var period : float = 4.0
## 何周するか(0.5 なら半周)。終わったら、その向きのまま画面の外へ抜けていく
@export var turns : float = 1.0
## 1機ごとに、曲線の上でどれだけずらすか(1 = 1周)。6機で 1/6 なら、等間隔の輪になる
@export var phase_step : float = 0.0
## 飛んでいるあいだに、図形の大きさをここまで変える(1 なら変えない。0.3 なら、内側へ巻きこむらせん)
@export var end_scale : float = 1.0
## 図形全体を、飛んでいるあいだに回す量(度/秒)。0 なら回さない
@export var spin : float = 0.0
## 画面の上から、曲線の上の自分の位置へ入ってくるまでの秒数
@export var enter_time : float = 1.0

## 曲線の上の点(中心からのずれ)。u は周の割合(1 で1周)
func point(u : float) -> Vector2:
	var th := u * TAU
	match shape:
		Shape.CIRCLE:
			return Vector2(sin(th) * radius.x, -cos(th) * radius.y)
		Shape.ROSE:
			var r := cos(k * th)
			return Vector2(sin(th) * r * radius.x, -cos(th) * r * radius.y)
		Shape.LISSAJOUS:
			return Vector2(sin(th) * radius.x, sin(k * th) * radius.y)
		Shape.SINE:
			var f := fposmod(u, 1.0)
			return Vector2(lerpf(-radius.x, radius.x, f), sin(f * TAU * k * 0.5) * radius.y)
		Shape.STAR:
			var n := maxi(k, 3)
			var f := fposmod(u, 1.0) * n
			var j := int(f)
			var a := _star_vertex(j, n)
			var b := _star_vertex(j + 1, n)
			return a.lerp(b, f - j)
	return Vector2.ZERO

func _star_vertex(j : int, n : int) -> Vector2:
	var th := TAU * float(j * star_skip) / n
	return Vector2(sin(th) * radius.x, -cos(th) * radius.y)
