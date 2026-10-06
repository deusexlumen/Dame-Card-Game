extends RefCounted

# Kodiert Netzwerknachrichten. Binaer statt JSON, weil JSON Ganzzahlen zu
# Floats macht (str(3.0) == "3.0" bricht Vergleiche). Objekte sind verboten.

static func encode(msg: Dictionary) -> PackedByteArray:
	return var_to_bytes(msg)


# Liefert {} bei kaputten oder fremden Daten. Nie Objekte dekodieren.
static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty():
		return {}
	var value = bytes_to_var(bytes)
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return value
