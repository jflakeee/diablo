extends RefCounted
# 절차적 픽셀 자산 생성기(제작기) PoC — 코드로 타일/캐릭터/아이콘/몬스터 생성.
# 장점: 라이선스 청정(자체 제작) · 무한 변형(시드) · 초경량(코드만) · 저사양 친화.
# preload로 사용: const PixelGen := preload("res://art/pixel_gen.gd")
const VERSION := 3

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

static func _clear_border(img: Image) -> void:
	var transparent := Color(0, 0, 0, 0)
	for x in img.get_width():
		img.set_pixel(x, 0, transparent)
		img.set_pixel(x, img.get_height() - 1, transparent)
	for y in img.get_height():
		img.set_pixel(0, y, transparent)
		img.set_pixel(img.get_width() - 1, y, transparent)

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

# 클래스·방향·걷기 프레임이 실루엣에 반영되는 영웅 스프라이트.
# direction: 0=남, 1=동, 2=북, 3=서 / frame: 0=idle, 1·2=walk
static func hero(kind: String, robe: Color, seed: int, direction: int = 0, frame: int = 0) -> Texture2D:
	var dir := posmod(direction, 4)
	var walk := posmod(frame, 3)
	var key := "hero:%s:%s:%d:%d:%d" % [kind, robe.to_html(), posmod(seed, 8), dir, walk]
	var hit := _cached(key)
	if hit != null:
		return hit
	var img := _img(32, 40)
	var skin := Color(0.85, 0.66, 0.47)
	var step := -1 if walk == 1 else (1 if walk == 2 else 0)
	if kind == "barbarian":
		_fill_rect(img, 8, 15, 16, 13, robe)                         # 넓은 흉곽
		_fill_ellipse(img, 7, 18, 4, 8, skin.darkened(0.08))         # 맨팔
		_fill_ellipse(img, 25, 18, 4, 8, skin.darkened(0.16))
		_fill_ellipse(img, 16, 9, 6, 7, skin)
		_fill_rect(img, 10, 27, 5, 9 + step, robe.darkened(0.35))
		_fill_rect(img, 18, 27, 5, 9 - step, robe.darkened(0.35))
		_fill_rect(img, 24, 7, 2, 21, Color(0.35, 0.22, 0.1))       # 도끼 자루
		_fill_rect(img, 21, 5, 7, 5, Color(0.72, 0.76, 0.8))
	elif kind == "sorceress":
		_fill_ellipse(img, 16, 25, 8, 12, robe)                      # 좁고 긴 로브
		_fill_ellipse(img, 16, 9, 5, 6, skin)
		_fill_ellipse(img, 16, 6, 7, 4, robe.darkened(0.22))         # 후드
		_fill_rect(img, 26, 7, 2, 28, Color(0.38, 0.25, 0.12))      # 지팡이
		_fill_ellipse(img, 27, 6, 2, 3, Color(0.3, 0.75, 1.0))
		_fill_rect(img, 11 + step, 34, 3, 4, robe.darkened(0.35))
		_fill_rect(img, 19 - step, 34, 3, 4, robe.darkened(0.35))
	else: # rogue mercenary
		_fill_rect(img, 10, 15, 12, 15, robe)
		_fill_ellipse(img, 16, 9, 5, 6, skin)
		_fill_rect(img, 11 + step, 29, 4, 8, robe.darkened(0.4))
		_fill_rect(img, 18 - step, 29, 4, 8, robe.darkened(0.4))
		for y in range(8, 30):
			var bx := 5 + absi(y - 19) / 4
			_px(img, bx, y, Color(0.55, 0.32, 0.12))                  # 활
	if dir == 2:
		_fill_rect(img, 12, 8, 8, 3, robe.darkened(0.3))            # 등 방향 표식
	elif dir in [1, 3]:
		_fill_rect(img, 15, 8, 5, 2, skin.lightened(0.12))
	_shade_right(img, 0.13)
	_outline(img, Color(0.07, 0.05, 0.06))
	if dir == 3:
		img.flip_x()
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

static func monster_named(name: String, body: Color, seed: int, frame: int = 0) -> Texture2D:
	var family := name.to_lower()
	var walk := posmod(frame, 3)
	var key := "monster_named:%s:%s:%d:%d" % [family, body.to_html(), posmod(seed, 8), walk]
	var hit := _cached(key)
	if hit != null:
		return hit
	var img := _img(34, 42)
	var step := -1 if walk == 1 else (1 if walk == 2 else 0)
	if "bone" in family:
		var bone := Color(0.86, 0.84, 0.72)
		_fill_ellipse(img, 17, 8, 6, 6, bone)
		_fill_rect(img, 15, 14, 4, 15, bone)
		_fill_rect(img, 9, 16, 6, 3, bone); _fill_rect(img, 19, 16, 7, 3, bone)
		_fill_rect(img, 12 + step, 27, 3, 11, bone); _fill_rect(img, 20 - step, 27, 3, 11, bone)
		_px(img, 14, 8, Color(0.05, 0.02, 0.02)); _px(img, 20, 8, Color(0.05, 0.02, 0.02))
	elif "raptor" in family:
		_fill_ellipse(img, 17, 20, 6, 8, body)
		_fill_ellipse(img, 9, 17 + step, 6, 4, body.darkened(0.1))
		_fill_ellipse(img, 25, 17 - step, 6, 4, body.darkened(0.18))
		_fill_rect(img, 15, 6, 4, 8, body.lightened(0.1))
	elif "horned" in family:
		_fill_ellipse(img, 17, 21, 10, 12, body)
		_fill_ellipse(img, 17, 8, 6, 6, body.lightened(0.08))
		_fill_rect(img, 9, 2, 3, 8, body.darkened(0.25)); _fill_rect(img, 23, 2, 3, 8, body.darkened(0.25))
		_fill_rect(img, 10 + step, 31, 4, 9, body.darkened(0.25)); _fill_rect(img, 21 - step, 31, 4, 9, body.darkened(0.25))
	elif "brood" in family:
		_fill_ellipse(img, 17, 23, 12, 14, body)
		_fill_ellipse(img, 17, 9, 6, 6, body.lightened(0.15))
		for x in [6, 10, 22, 26]:
			_fill_rect(img, x, 3, 2, 22, body.darkened(0.3))
		_fill_rect(img, 8 + step, 31, 5, 7, body.darkened(0.28)); _fill_rect(img, 22 - step, 31, 5, 7, body.darkened(0.28))
	elif "ash" in family:
		_fill_ellipse(img, 17, 22, 9, 11, body)
		_fill_ellipse(img, 17, 9, 7, 7, body.lightened(0.08))
		_fill_rect(img, 8, 2, 3, 8, body.darkened(0.3)); _fill_rect(img, 24, 2, 3, 8, body.darkened(0.3))
		_fill_rect(img, 10 + step, 31, 4, 8, body.darkened(0.25)); _fill_rect(img, 21 - step, 31, 4, 8, body.darkened(0.25))
	else:
		_fill_ellipse(img, 17, 22, 10, 13, body)
		_fill_ellipse(img, 17, 8, 6, 7, body.lightened(0.08))
		_fill_rect(img, 9 + step, 32, 5, 8, body.darkened(0.25)); _fill_rect(img, 21 - step, 32, 5, 8, body.darkened(0.25))
	_fill_ellipse(img, 14, 10, 1, 1, Color(1, 0.72, 0.15)); _fill_ellipse(img, 20, 10, 1, 1, Color(1, 0.72, 0.15))
	_shade_right(img, 0.14)
	_outline(img, Color(0.05, 0.035, 0.045))
	_clear_border(img)
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
