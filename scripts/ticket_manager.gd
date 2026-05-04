extends RefCounted
class_name TicketManager

var tickets: Array = []

func load_tickets(path: String) -> void:
	var raw = FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(raw)
	tickets = parsed.get("tickets", []) if parsed is Dictionary else []
	for t in tickets:
		t["elapsed"] = 0.0
		t["selected"] = false
		t["completed"] = false

func active_tickets() -> Array:
	return tickets.filter(func(t): return not bool(t.get("completed", false)))

func find_ticket(id: String) -> Dictionary:
	for t in tickets:
		if str(t.get("order_id", "")) == id:
			return t
	return {}

func tick(delta: float) -> void:
	for t in tickets:
		if not bool(t.get("completed", false)):
			t["elapsed"] = float(t.get("elapsed", 0.0)) + delta
