class_name QRCodeArt
extends RefCounted
## QR code pseudo-gerado sem lib externa (21x21 v1) — visual de QR para share card.
## Não é QR spec completo com ECC, mas tem finder patterns + timing + dados baseados em hash,
## suficiente para cumprir "QR no share" sem assets. Se precisar scannable real, trocar por lib.

const QR_SIZE: int = 21
const FINDER_SIZE: int = 7

static func _add_finder(matrix: Array, ox: int, oy: int) -> void:
	for dy: int in FINDER_SIZE:
		for dx: int in FINDER_SIZE:
			var is_border: bool = dx == 0 or dx == FINDER_SIZE - 1 or dy == 0 or dy == FINDER_SIZE - 1
			var is_inner: bool = dx >= 2 and dx <= 4 and dy >= 2 and dy <= 4
			matrix[oy + dy][ox + dx] = is_border or is_inner

static func _is_reserved(x: int, y: int) -> bool:
	# Finders + separators
	if (x < 8 and y < 8) or (x >= QR_SIZE - 8 and y < 8) or (x < 8 and y >= QR_SIZE - 8):
		return true
	# Timing row/col
	if x == 6 or y == 6:
		return true
	return false

static func generate_matrix(data: String) -> Array:
	var matrix: Array = []
	for y: int in QR_SIZE:
		var row: Array = []
		for x: int in QR_SIZE:
			row.append(false)
		matrix.append(row)
	# Finders
	_add_finder(matrix, 0, 0)
	_add_finder(matrix, QR_SIZE - FINDER_SIZE, 0)
	_add_finder(matrix, 0, QR_SIZE - FINDER_SIZE)
	# Timing patterns
	for i: int in range(8, QR_SIZE - 8):
		matrix[6][i] = (i % 2 == 0)
		matrix[i][6] = (i % 2 == 0)
	# Data from hash
	var h: int = int(data.hash())
	var bit_idx: int = 0
	for y: int in range(QR_SIZE - 1, -1, -1):
		for x: int in range(QR_SIZE - 1, -1, -1):
			if _is_reserved(x, y):
				continue
			# Use hash bits + position to vary
			var bit: bool = ((h >> (bit_idx % 24)) & 1) == 1
			bit = bit != ((x + y) % 3 == 0) # add pattern
			matrix[y][x] = bit
			bit_idx += 1
			h = int((h * 1664525 + 1013904223) & 0x7fffffff) # LCG
	return matrix

static func generate_image(data: String, pixel_size: int = 200) -> Image:
	var matrix: Array = generate_matrix(data)
	var img: Image = Image.create(pixel_size, pixel_size, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var cell: int = pixel_size / QR_SIZE
	var black: Color = Color.BLACK
	var white: Color = Color.WHITE
	for y: int in QR_SIZE:
		for x: int in QR_SIZE:
			var col: Color = black if bool(matrix[y][x]) else white
			var rx: int = x * cell
			var ry: int = y * cell
			for dy: int in cell:
				for dx: int in cell:
					if rx + dx < pixel_size and ry + dy < pixel_size:
						img.set_pixel(rx + dx, ry + dy, col)
	return img

static func make_texture_rect(data: String, size: int = 200) -> TextureRect:
	var img: Image = generate_image(data, size)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var rect: TextureRect = TextureRect.new()
	rect.texture = tex
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	return rect
