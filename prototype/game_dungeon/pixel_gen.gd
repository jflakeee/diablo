extends RefCounted
# 절차적 픽셀 자산 생성기(제작기) PoC — 코드로 타일/캐릭터/아이콘/몬스터 생성.
# 장점: 라이선스 청정(자체 제작) · 무한 변형(시드) · 초경량(코드만) · 저사양 친화.
# preload로 사용: const PixelGen := preload("res://pixel_gen.gd")

# 같은 레시피를 여러 개체가 공유하도록 GPU 텍스처 생성을 캐시한다.
static var _cache := {}

static func _cached(key: String) -> Texture2D:
	return _cache.get(key) as Texture2D

static func _remember(key: String, texture: Texture2D) -> Texture2D:
	_cache[key] = texture
	return texture

static func cache_size() -> int:
	return _cache.size()

static func _hash01(x: int, y: int, seed: int) -> float:
	var h := (x * 374761393 + y * 668265263 + seed * 362437) & 0x7fffffff
	h = (h ^ (h >> 13)) * 1274126177
	return float((h & 0x7fffffff) % 1000) / 1000.0

static func _img(w: int, h: int) -> Image:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img

static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		img.set_pixel(x, y, c)

static func _fill_ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
	for y in range(cy - ry, cy + ry + 1):
		for x in range(cx - rx, cx + rx + 1):
			var nx: float = float(x - cx) / float(rx)
			var ny: float = float(y - cy) / float(ry)
			if nx * nx + ny * ny <= 1.0:
				_px(img, x, y, c)

static func _fill_rect(img: Image, x0: int, y0: int, w: int, h: int, c: Color) -> void:
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			_px(img, x, y, c)

static func _outline(img: Image, oc: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var snap := Image.new()
	snap.copy_from(img)
	for y in h:
		for x in w:
			if snap.get_pixel(x, y).a < 0.5:
				var touch := false
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nb: Vector2i = d
					var nx := x + nb.x
					var ny := y + nb.y
					if nx >= 0 and nx < w and ny >= 0 and ny < h and snap.get_pixel(nx, ny).a >= 0.5:
						touch = true
						break
				if touch:
					img.set_pixel(x, y, oc)

static func _shade_right(img: Image, amount: float) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in range(w / 2, w):
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				img.set_pixel(x, y, c.darkened(amount))

# ── 아이소 타일 (노이즈 텍스처 + 림/하이라이트) ──
static func iso_tile(w: int, h: int, base: Color, seed: int, speckle: bool) -> Texture2D:
	var key := "tile:%d:%d:%s:%d:%s" % [w, h, base.to_html(), seed, str(speckle)]
	var hit := _cached(key)
	if hit != null:
		return hit
	var img := _img(w, h)
	var cx := w / 2.0
	var cy := h / 2.0
	for y in h:
		for x in w:
			var d: float = absf(x - cx) / cx + absf(y - cy) / cy
			if d <= 1.0:
				var n := _hash01(x, y, seed) * 0.16 - 0.08
				var col := Color(clampf(base.r + n, 0, 1), clampf(base.g + n, 0, 1), clampf(base.b + n, 0, 1), 1.0)
				if d > 0.82:
					col = col.darkened(0.32)   # 가장자리 림
				elif float(y) < cy:
					col = col.lightened(0.08)  # 위쪽 하이라이트
				if speckle and _hash01(x * 3, y * 3, seed + 7) > 0.86:
					col = col.darkened(0.28)   # 돌 얼룩
				img.set_pixel(x, y, col)
	return _remember(key, ImageTexture.create_from_image(img))

# ── 캐릭터 (후드/로브 형태 휴머노이드 + 음영 + 외곽선) ──
static func character(robe: Color, seed: int) -> Texture2D:
	var variant := posmod(seed, 8)
	var key := "character:%s:%d" % [robe.to_html(), variant]
	var hit := _cached(key)
	if hit != null:
		return hit
	var w := 26
	var h := 34
	var img := _img(w, h)
	var skin := Color(0.85, 0.68, 0.5)
	# 로브(몸통, 아래로 넓어지는 사다리꼴 근사 = 큰 타원)
	_fill_ellipse(img, 13, 24, 9, 10, robe)
	_fill_rect(img, 6, 24, 14, 8, robe)
	# 어깨
	_fill_ellipse(img, 13, 17, 8, 5, robe.lightened(0.05))
	# 머리
	_fill_ellipse(img, 13, 9, 5, 6, skin)
	# 후드 테두리
	_fill_ellipse(img, 13, 7, 6, 4, robe.darkened(0.1))
	# 벨트
	_fill_rect(img, 6, 26, 14, 2, robe.darkened(0.35))
	# 약간의 시드 색 변주(장식)
	if _hash01(0, 0, seed) > 0.5:
		_fill_rect(img, 12, 18, 2, 8, robe.lightened(0.18))  # 로브 중앙 띠
	if variant in [2, 3, 6]:
		_fill_rect(img, 5, 16, 2, 7, robe.darkened(0.22))
		_fill_rect(img, 19, 16, 2, 7, robe.darkened(0.22))
	if variant in [4, 5, 6, 7]:
		_fill_rect(img, 9, 3, 2, 4, robe.darkened(0.3))
		_fill_rect(img, 16, 3, 2, 4, robe.darkened(0.3))
	_shade_right(img, 0.12)
	_outline(img, Color(0.08, 0.06, 0.08))
	return _remember(key, ImageTexture.create_from_image(img))

# ── 몬스터 (둥근 블롭 + 눈) ──
static func monster(body: Color, seed: int) -> Texture2D:
	var variant := posmod(seed, 8)
	var key := "monster:%s:%d" % [body.to_html(), variant]
	var hit := _cached(key)
	if hit != null:
		return hit
	var w := 26
	var h := 26
	var img := _img(w, h)
	_fill_ellipse(img, 13, 15, 10, 9, body)
	# 뿔/돌기(시드별)
	if _hash01(1, 1, seed) > 0.4:
		_fill_rect(img, 6, 5, 2, 5, body.darkened(0.2))
		_fill_rect(img, 18, 5, 2, 5, body.darkened(0.2))
	if variant in [1, 4, 7]:
		_fill_rect(img, 3, 15, 4, 3, body.darkened(0.15))
		_fill_rect(img, 20, 15, 4, 3, body.darkened(0.15))
	if variant in [3, 6]:
		_fill_rect(img, 11, 3, 4, 6, body.lightened(0.08))
	# 눈
	_fill_ellipse(img, 9, 13, 2, 2, Color(1, 0.9, 0.2))
	_fill_ellipse(img, 17, 13, 2, 2, Color(1, 0.9, 0.2))
	_px(img, 9, 13, Color(0.1, 0, 0))
	_px(img, 17, 13, Color(0.1, 0, 0))
	_shade_right(img, 0.12)
	_outline(img, Color(0.06, 0.05, 0.06))
	return _remember(key, ImageTexture.create_from_image(img))

# ── 아이템 아이콘 (sword/potion/shield/coin) ──
static func icon(kind: String, seed: int) -> Texture2D:
	var variant := posmod(seed, 4)
	var key := "icon:%s:%d" % [kind, variant]
	var hit := _cached(key)
	if hit != null:
		return hit
	var s := 32
	var img := _img(s, s)
	match kind:
		"sword":
			for i in 18:
				var x := 7 + i
				var y := 24 - i
				for t in [-1, 0, 1]:
					_px(img, x + t, y, Color(0.82, 0.85, 0.95))
			_px(img, 7 + 17, 24 - 17, Color(1, 1, 1))          # 팁 하이라이트
			_fill_rect(img, 5, 22, 8, 2, Color(0.5, 0.35, 0.15))  # 가드
			_fill_rect(img, 6, 24, 3, 5, Color(0.35, 0.22, 0.1))  # 손잡이
		"potion":
			_fill_ellipse(img, 16, 20, 8, 8, Color(0.75, 0.85, 0.95, 0.55))  # 유리
			_fill_ellipse(img, 16, 22, 6, 5, Color(0.85, 0.2, 0.25))          # 액체
			_fill_rect(img, 13, 6, 6, 6, Color(0.75, 0.85, 0.95, 0.6))        # 목
			_fill_rect(img, 12, 5, 8, 3, Color(0.5, 0.35, 0.2))               # 코르크
			_px(img, 13, 18, Color(1, 1, 1))                                   # 반사광
		"shield":
			_fill_ellipse(img, 16, 15, 10, 12, Color(0.55, 0.4, 0.2))
			_fill_ellipse(img, 16, 15, 7, 9, Color(0.75, 0.6, 0.3))
			_fill_ellipse(img, 16, 15, 3, 3, Color(0.9, 0.85, 0.6))
		"coin":
			_fill_ellipse(img, 16, 16, 10, 10, Color(0.9, 0.75, 0.2))
			_fill_ellipse(img, 16, 16, 7, 7, Color(1, 0.87, 0.35))
			_fill_rect(img, 14, 11, 4, 10, Color(0.8, 0.6, 0.1))
		"gem":
			var gem_cols := [Color(0.9, 0.15, 0.2), Color(0.2, 0.5, 1.0), Color(1.0, 0.8, 0.12), Color(0.15, 0.85, 0.4)]
			var gc: Color = gem_cols[variant]
			for y in range(7, 26):
				var half := mini(mini(y - 6, 26 - y), 9)
				_fill_rect(img, 16 - half, y, half * 2 + 1, 1, gc.darkened(float(y - 7) / 70.0))
			_fill_rect(img, 12, 10, 3, 6, gc.lightened(0.45))
		"rune":
			_fill_rect(img, 8, 5, 16, 23, Color(0.48, 0.43, 0.34))
			_fill_rect(img, 10, 7, 12, 19, Color(0.65, 0.58, 0.45))
			for i in range(5):
				_px(img, 12 + posmod(i * 3 + variant, 9), 10 + i * 3, Color(0.2, 0.85, 0.9))
		"material":
			_fill_ellipse(img, 16, 19, 9, 7, Color(0.55, 0.42, 0.3))
			_fill_ellipse(img, 12, 15, 4, 4, Color(0.78, 0.62, 0.4))
			_fill_ellipse(img, 20, 17, 3, 3, Color(0.7, 0.52, 0.34))
		_:
			_fill_ellipse(img, 16, 16, 8, 8, Color(0.6, 0.6, 0.6))
	_outline(img, Color(0.08, 0.06, 0.08))
	return _remember(key, ImageTexture.create_from_image(img))
