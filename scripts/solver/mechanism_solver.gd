class_name MechanismSolver
extends RefCounted

var max_iterations := 20
var convergence_threshold := 0.001
var last_iteration_count := 0
var last_residual := 0.0

func _init(p_max_iterations: int = 20, p_threshold: float = 0.001) -> void:
	max_iterations = max(p_max_iterations, 1)
	convergence_threshold = p_threshold

func solve(rotors: Dictionary, constraints: Array, dt: float) -> void:
	last_iteration_count = 0
	last_residual = 0.0
	for i in range(max_iterations):
		var residual := 0.0
		for c in constraints:
			c.solve(rotors, dt)
			residual += c.measure_error(rotors)
		last_iteration_count = i + 1
		last_residual = residual
		if residual < convergence_threshold:
			break
