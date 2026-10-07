extends Label
class_name LivesLabel
## 残機を表示するラベル。GameManager から bind() で Player を受け取る。

func bind(player : Player) -> void:
	player.lives_changed.connect(_on_lives_changed)
	_on_lives_changed(player.lives)

func _on_lives_changed(lives : int) -> void:
	text = "残機 %d" % lives
