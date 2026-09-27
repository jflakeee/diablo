extends RefCounted
## Temporary CC0-backed theme adapter. Public semantic IDs stay stable when
## these textures are replaced by locally generated Ashen Depths resources.

const BUTTON_PRIMARY := preload("res://assets/ui/template/button_primary.png")
const BUTTON_PRIMARY_PRESSED := preload("res://assets/ui/template/button_primary_pressed.png")
const BUTTON_SECONDARY := preload("res://assets/ui/template/button_secondary.png")
const PANEL := preload("res://assets/ui/template/panel_brown.png")
const PANEL_BORDER := preload("res://assets/ui/template/panel_border_double.png")

const TEXT := Color("e7e0d2")
const TEXT_MUTED := Color("a99f91")
const GOLD := Color("d6b56a")

static func _texture_style(texture: Texture2D, margin: float, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.modulate_color = tint
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, margin)
		style.set_content_margin(side, margin)
	return style

static func create() -> Theme:
	var theme := Theme.new()
	var normal := _texture_style(BUTTON_PRIMARY, 12.0, Color(0.52, 0.43, 0.34, 1.0))
	var hover := _texture_style(BUTTON_PRIMARY, 12.0, Color(0.70, 0.57, 0.40, 1.0))
	var pressed := _texture_style(BUTTON_PRIMARY_PRESSED, 12.0, Color(0.44, 0.34, 0.27, 1.0))
	var disabled := _texture_style(BUTTON_SECONDARY, 12.0, Color(0.30, 0.30, 0.33, 0.82))
	var focus := _texture_style(PANEL_BORDER, 15.0, Color(0.82, 0.64, 0.30, 0.95))
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", GOLD)
	theme.set_color("font_disabled_color", "Button", TEXT_MUTED.darkened(0.25))
	theme.set_constant("outline_size", "Button", 2)
	theme.set_color("font_outline_color", "Button", Color(0.04, 0.03, 0.03, 0.9))

	var panel := _texture_style(PANEL, 16.0, Color(0.17, 0.14, 0.13, 0.98))
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_color("font_color", "Label", TEXT)
	return theme

static func selftest() -> bool:
	var theme := create()
	return theme.has_stylebox("normal", "Button") \
		and theme.has_stylebox("pressed", "Button") \
		and theme.has_stylebox("panel", "Panel") \
		and BUTTON_PRIMARY.get_width() > 0 \
		and PANEL_BORDER.get_width() > 0
