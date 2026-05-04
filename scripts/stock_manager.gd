extends RefCounted
class_name StockManager

var stock := {}
var critical := ["cheese", "chicken"]

func load_station(path: String) -> void:
	var raw = FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(raw)
	stock = parsed.get("initial_stock", {}) if parsed is Dictionary else {}

func has(item: String, amount: int) -> bool:
	return int(stock.get(item, 0)) >= amount

func consume(item: String, amount: int) -> bool:
	if not has(item, amount):
		return false
	stock[item] = int(stock.get(item, 0)) - amount
	return true

func summary() -> String:
	var chunks: Array[String] = []
	for k in stock.keys():
		chunks.append("%s:%s" % [k, stock[k]])
	return " | ".join(chunks)
