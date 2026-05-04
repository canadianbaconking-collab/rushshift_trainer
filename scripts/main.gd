extends Control

const TICKET_MANAGER = preload("res://scripts/ticket_manager.gd")
const STOCK_MANAGER = preload("res://scripts/stock_manager.gd")
const RECIPE_VALIDATOR = preload("res://scripts/recipe_validator.gd")

var ticket_manager := TICKET_MANAGER.new()
var stock_manager := STOCK_MANAGER.new()
var validator := RECIPE_VALIDATOR.new()

var ingredient_defs := {}
var selected_ticket_id := ""
var build_state := {}
var oven_remaining := 0.0

var stats := {
	"completed_tickets": 0,
	"correct_builds": 0,
	"missed_ingredients": 0,
	"wrong_ingredients": 0,
	"wrong_sequence_errors": 0,
	"missed_post_oven_steps": 0,
	"wrong_size_errors": 0,
	"stockouts": 0,
	"total_time": 0.0,
	"highest_time": 0.0
}

func _ready() -> void:
	ticket_manager.load_tickets("res://data/tickets/sample_tickets_v1.json")
	stock_manager.load_station("res://data/stations/nacho_station_v1.json")
	validator.load_recipes("res://data/recipes/nacho_recipes_v1.json")
	ingredient_defs = JSON.parse_string(FileAccess.get_file_as_string("res://data/recipes/nacho_ingredients_v1.json")).get("ingredients", {})
	wire_signals()
	build_ingredient_buttons()
	reset_build()
	refresh_all()

func wire_signals() -> void:
	$GameTimer.timeout.connect(_on_tick)
	$RootMargin/MainVBox/MainPanel/StationPanel/PlateButtons/PlateRegular.pressed.connect(func(): choose_plate("regular"))
	$RootMargin/MainVBox/MainPanel/StationPanel/PlateButtons/PlateLarge.pressed.connect(func(): choose_plate("large"))
	$RootMargin/MainVBox/MainPanel/StationPanel/Actions/SendToOven.pressed.connect(send_to_oven)
	$RootMargin/MainVBox/MainPanel/StationPanel/Actions/SendToService.pressed.connect(send_to_service)
	$RootMargin/MainVBox/MainPanel/StationPanel/Actions/ResetBuild.pressed.connect(reset_build)

func build_ingredient_buttons() -> void:
	var container = $RootMargin/MainVBox/MainPanel/StationPanel/IngredientButtons
	for key in ingredient_defs.keys():
		var b := Button.new()
		b.text = key
		b.pressed.connect(func(): add_ingredient(key))
		container.add_child(b)

func _on_tick() -> void:
	ticket_manager.tick(1.0)
	if oven_remaining > 0.0:
		oven_remaining -= 1.0
		if oven_remaining <= 0.0:
			build_state["oven_done"] = true
	refresh_all()

func choose_ticket(order_id: String) -> void:
	selected_ticket_id = order_id
	reset_build(false)

func choose_plate(size: String) -> void:
	if build_state["plate_size"] != "":
		return
	var plate_key = "regular_plate" if size == "regular" else "large_plate"
	if not stock_manager.consume(plate_key, 1):
		stats.stockouts += 1
		return
	build_state["plate_size"] = size

func add_ingredient(ingredient: String) -> void:
	if selected_ticket_id == "":
		return
	var amount = 2 if build_state["plate_size"] == "large" else 1
	if not stock_manager.consume(ingredient, amount):
		stats.stockouts += 1
		return
	if build_state["sent_to_oven"]:
		build_state["post_oven_added"].append(ingredient)
	else:
		build_state["pre_oven_added"].append(ingredient)
	if ingredient == "wing_sauce":
		build_state["wing_sauce_heat"] = build_state["selected_wing_heat"]

func send_to_oven() -> void:
	if selected_ticket_id == "" or build_state["sent_to_oven"]:
		return
	build_state["sent_to_oven"] = true
	oven_remaining = 24.0 if build_state["plate_size"] == "large" else 18.0

func send_to_service() -> void:
	if selected_ticket_id == "":
		return
	var ticket = ticket_manager.find_ticket(selected_ticket_id)
	if ticket.is_empty() or not bool(build_state["oven_done"]):
		return
	var result = validator.validate(ticket, build_state)
	stats.completed_tickets += 1
	if result.correct:
		stats.correct_builds += 1
	stats.missed_ingredients += result.missed.size()
	stats.wrong_ingredients += result.wrong.size()
	stats.wrong_sequence_errors += result.sequence_errors.size()
	stats.missed_post_oven_steps += 1 if result.missed_post_oven else 0
	stats.wrong_size_errors += 1 if result.wrong_size else 0
	stats.total_time += float(ticket.get("elapsed", 0.0))
	stats.highest_time = max(stats.highest_time, float(ticket.get("elapsed", 0.0)))
	ticket["completed"] = true
	selected_ticket_id = ""
	reset_build(false)
	refresh_all()

func reset_build(clear_selected := true) -> void:
	if clear_selected:
		selected_ticket_id = ""
	build_state = {
		"plate_size": "",
		"pre_oven_added": [],
		"post_oven_added": [],
		"sent_to_oven": false,
		"oven_done": false,
		"wing_sauce_heat": "mild",
		"selected_wing_heat": "hot"
	}
	oven_remaining = 0.0

func refresh_all() -> void:
	render_tickets()
	update_labels()

func render_tickets() -> void:
	var cards = $RootMargin/MainVBox/TicketScroll/TicketCards
	for child in cards.get_children():
		child.queue_free()
	for ticket in ticket_manager.active_tickets():
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(220, 160)
		var v := VBoxContainer.new()
		panel.add_child(v)
		var mods = ticket.get("modifiers", {})
		var flags: Array[String] = []
		if bool(ticket.get("rush", false)): flags.append("RUSH")
		if bool(ticket.get("recalled", false)): flags.append("RECALLED")
		v.add_child(_label("%s | %s" % [ticket.get("source",""), ticket.get("order_id","")]))
		v.add_child(_label("%ss | %s" % [int(ticket.get("elapsed",0.0)), str(ticket.get("station", "S1"))]))
		v.add_child(_label("%s (%s)" % [ticket.get("item_name",""), ticket.get("size","")]))
		v.add_child(_label("Mods: %s" % [mods]))
		v.add_child(_label("Flags: %s" % [", ".join(flags)]))
		var button := Button.new()
		button.text = "Select"
		button.pressed.connect(func(): choose_ticket(str(ticket.get("order_id", ""))))
		v.add_child(button)
		cards.add_child(panel)

func _label(text_value: String) -> Label:
	var l := Label.new()
	l.text = text_value
	return l

func update_labels() -> void:
	var avg = stats.total_time / max(1, stats.completed_tickets)
	$RootMargin/MainVBox/StatusBar.text = "Avg: %.1fs | Highest: %.1fs | Active: %s | Score: %s" % [avg, stats.highest_time, ticket_manager.active_tickets().size(), stats.correct_builds]
	$RootMargin/MainVBox/MainPanel/StationPanel/SelectedTicketLabel.text = "Selected Ticket: %s" % [selected_ticket_id if selected_ticket_id != "" else "None"]
	$RootMargin/MainVBox/MainPanel/StationPanel/StationState.text = "Plate:%s Oven:%s Remaining:%.0f Pre:%s Post:%s" % [build_state["plate_size"], build_state["sent_to_oven"], max(0.0, oven_remaining), build_state["pre_oven_added"], build_state["post_oven_added"]]
	$RootMargin/MainVBox/MainPanel/StationPanel/StockLabel.text = "Stock => %s" % stock_manager.summary()
	$RootMargin/MainVBox/MainPanel/DebriefPanel.text = debrief_text()

func debrief_text() -> String:
	var accuracy = float(stats.correct_builds) / max(1.0, float(stats.completed_tickets))
	var worst = "clean"
	var worst_count = 0
	for key in ["missed_ingredients", "wrong_ingredients", "wrong_sequence_errors", "wrong_size_errors", "stockouts"]:
		if int(stats[key]) > worst_count:
			worst = key
			worst_count = int(stats[key])
	return "Completed: %s\nAccuracy: %.0f%%\nSpeed Avg: %.1fs\nMissed/Wrong: %s/%s\nStockouts: %s\nWorst: %s" % [stats.completed_tickets, accuracy * 100.0, stats.total_time / max(1, stats.completed_tickets), stats.missed_ingredients, stats.wrong_ingredients, stats.stockouts, worst]
