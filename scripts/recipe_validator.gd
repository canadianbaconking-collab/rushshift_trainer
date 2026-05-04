extends RefCounted
class_name RecipeValidator

var recipes := {}

func load_recipes(path: String) -> void:
	var raw = FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(raw)
	recipes = parsed.get("recipes", {}) if parsed is Dictionary else {}

func get_recipe(item_name: String) -> Dictionary:
	return recipes.get(item_name, {})

func validate(ticket: Dictionary, build: Dictionary) -> Dictionary:
	var result := {
		"correct": true,
		"missed": [],
		"wrong": [],
		"sequence_errors": [],
		"wrong_size": false,
		"missed_post_oven": false,
		"major_error": false,
		"critical_error": false
	}
	var recipe = get_recipe(str(ticket.get("item_name", "")))
	if recipe.is_empty():
		result.correct = false
		result.wrong.append("unknown_recipe")
		return result

	if str(build.get("plate_size", "")) != str(ticket.get("size", "")):
		result.correct = false
		result.wrong_size = true
		result.critical_error = true

	var required_pre: Array = recipe.get("pre_oven", [])
	var required_post: Array = recipe.get("post_oven", [])
	for ingredient in required_pre:
		if ingredient not in build.get("pre_oven_added", []):
			result.correct = false
			result.missed.append(ingredient)
			if ingredient == "cheese":
				result.critical_error = true

	for ingredient in required_post:
		if ingredient not in build.get("post_oven_added", []):
			result.correct = false
			result.missed.append(ingredient)
			result.missed_post_oven = true
			result.major_error = true

	for ingredient in build.get("pre_oven_added", []):
		if ingredient not in required_pre:
			result.correct = false
			result.wrong.append(ingredient)
			if ingredient.ends_with("sauce") or ingredient in ["chicken", "taco_beef"]:
				result.major_error = true

	for ingredient in build.get("post_oven_added", []):
		if ingredient not in required_post:
			result.correct = false
			result.wrong.append(ingredient)

	for ingredient in build.get("pre_oven_added", []):
		if ingredient in required_post:
			result.correct = false
			result.sequence_errors.append("post_oven_added_before_oven:%s" % ingredient)
	for ingredient in build.get("post_oven_added", []):
		if ingredient in required_pre:
			result.correct = false
			result.sequence_errors.append("pre_oven_added_after_oven:%s" % ingredient)

	if str(ticket.get("item_name", "")) == "Wing Nachos":
		var heat = ticket.get("modifiers", {}).get("wing_sauce_heat", "mild")
		if str(build.get("wing_sauce_heat", "mild")) != heat:
			result.correct = false
			result.wrong.append("wing_sauce_heat:%s" % str(build.get("wing_sauce_heat", "mild")))
			result.major_error = true

	return result
