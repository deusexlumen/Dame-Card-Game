extends RefCounted
class_name StatsService

# Statistik des lokalen Spielers in user://stats.json. Felder wie die Web-Version.

const JsonStoreScript = preload("res://scripts/services/json_store.gd")

const DEFAULTS := {
	"games_played": 0,
	"games_won": 0,
	"rounds_played": 0,
	"dame_calls": 0,
	"successful_dame_calls": 0,
	"total_penalty_cards": 0,
	"best_round_score": -1,
	"last_played_at": "",
}

var path := "user://stats.json"
var values: Dictionary = {}

func _init(p_path: String = "user://stats.json") -> void:
	path = p_path
	values = DEFAULTS.duplicate(true)
	var stored := JsonStoreScript.read_json(path)
	for key in stored:
		if not DEFAULTS.has(key):
			continue
		var v = stored[key]
		if typeof(DEFAULTS[key]) == TYPE_INT and (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT):
			values[key] = int(v)
		elif typeof(DEFAULTS[key]) == TYPE_STRING and typeof(v) == TYPE_STRING:
			values[key] = v


# Eine gewertete Ausgabe aus Sicht des lokalen Spielers.
func record_round(round_score: int, called_dame: bool, call_correct: bool, penalty_cards: int) -> void:
	values.rounds_played = int(values.rounds_played) + 1
	if called_dame:
		values.dame_calls = int(values.dame_calls) + 1
		if call_correct:
			values.successful_dame_calls = int(values.successful_dame_calls) + 1
	values.total_penalty_cards = int(values.total_penalty_cards) + penalty_cards
	if int(values.best_round_score) < 0 or round_score < int(values.best_round_score):
		values.best_round_score = round_score
	_touch()


func record_game(won: bool) -> void:
	values.games_played = int(values.games_played) + 1
	if won:
		values.games_won = int(values.games_won) + 1
	_touch()


func win_rate() -> float:
	if int(values.games_played) == 0:
		return 0.0
	return float(values.games_won) / float(values.games_played)


func reset() -> void:
	values = DEFAULTS.duplicate(true)
	JsonStoreScript.write_json(path, values)


func _touch() -> void:
	values.last_played_at = Time.get_datetime_string_from_system(false, true)
	JsonStoreScript.write_json(path, values)
