class_name BlueprintSnapshot
extends RefCounted

var rotors: Array = []
var links: Array = []
var annotations: Array = []
var energy: float = 0.0
var constraint_error: float = 0.0

func rotor_by_id(id: String) -> Dictionary:
	for r in rotors:
		if r.get("id", "") == id:
			return r
	return {}
