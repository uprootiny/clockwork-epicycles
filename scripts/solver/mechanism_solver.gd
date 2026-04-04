class_name MechanismSolver
extends RefCounted

var max_iterations: int = 20
var convergence_threshold: float = 0.001
var last_iteration_count: int = 0
var last_residual: float = 0.0
var divergence_detected: bool = false

func _init(p_max_iterations: int = 20, p_threshold: float = 0.001) -> void:
	max_iterations = max(p_max_iterations, 1)
	convergence_threshold = p_threshold

func solve(rotors: Dictionary, constraints: Array, dt: float) -> void:
	last_iteration_count = 0
	last_residual = 0.0
	divergence_detected = false
	var prev_residual: float = INF
	for i in range(max_iterations):
		var residual: float = 0.0
		for c in constraints:
			c.solve(rotors, dt)
			var err: float = c.measure_error(rotors)
			# NaN guard: if a constraint produces NaN, halt iteration
			if is_nan(err) or is_inf(err):
				divergence_detected = true
				last_iteration_count = i + 1
				last_residual = INF
				return
			residual += err
		last_iteration_count = i + 1
		last_residual = residual
		# Converged
		if residual < convergence_threshold:
			break
		# Divergence: residual increasing significantly across iterations
		if i > 2 and residual > prev_residual * 1.5:
			divergence_detected = true
			break
		prev_residual = residual
