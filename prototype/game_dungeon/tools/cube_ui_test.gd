extends SceneTree

# Exercise the production UI and its actual button signal without starting a run
# or touching the player's save. Run with --headless --script res://tools/cube_ui_test.gd.
const Main := preload("res://main.gd")
const Item := preload("res://item.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := Main.new()
	var panel := VBoxContainer.new()
	root.add_child(panel)
	game._inv_vbox = panel
	game._inventory_view = "cube"
	game._automation.materials = {"ruby": 3, "rune_Ahn": 2, "ruby:perfect": 1, "topaz": 3}
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var reroll_target := Item.generate(rng, Item.WEAPON_BASES[0], 10, "magic")
	game._inventory.append(reroll_target)
	game._rebuild_inv()
	await process_frame
	var failures: Array[String] = []
	var combine: Button
	var insufficient: Button
	for child in panel.get_children():
		if child is Button and child.text == "Combine 3 -> Flawless Ruby x1":
			combine = child
		if child is Button and child.text == "Combine 3 -> Ahnor Sigil x1":
			insufficient = child
	if combine == null or combine.disabled:
		failures.append("available recipe button")
	if insufficient == null or not insufficient.disabled:
		failures.append("insufficient recipe disabled")
	if combine != null:
		combine.pressed.emit()
		# Simulate a queued second input from the old, now detached button.
		combine.pressed.emit()
	if game._automation.materials.has("ruby") or int(game._automation.materials.get("ruby:flawless", 0)) != 1:
		failures.append("button transaction / duplicate input")
	var reroll_btn: Button
	for child in panel.get_children():
		if child is Button and child.text == "Reroll":
			reroll_btn = child
	if reroll_btn == null or reroll_btn.disabled:
		failures.append("reroll button available")
	if reroll_btn != null:
		reroll_btn.pressed.emit()
	if game._automation.materials.has("topaz") or (reroll_target["affixes"] as Dictionary).is_empty():
		failures.append("reroll transaction")
	await process_frame
	game._accessibility.ui_scale = 1.4
	game._accessibility.text_scale = 1.25
	game._rebuild_inv()
	for width in [320, 640]:
		panel.size = Vector2(width, 0)
		await process_frame
		await process_frame
		if panel.size.x > width + 1:
			failures.append("panel overflow at %d" % width)
		for child in panel.get_children():
			if child is Button and child.size.y < 48:
				failures.append("touch target below 48px")
	game._automation.materials.clear()
	game._rebuild_inv()
	var empty_found := false
	for child in panel.get_children():
		if child is Label and child.text == "No materials collected yet.":
			empty_found = true
	if not empty_found:
		failures.append("empty state")
	print("[CUBE_UI] click=true stale_input=true reroll=true widths=320/640 failures=%s verdict=%s" % [failures, "PASS" if failures.is_empty() else "FAIL"])
	game.free()
	panel.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
