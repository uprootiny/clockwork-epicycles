# Clockwork Epicycles

## Quick start
- Engine: Godot 4.2.2
- Main scene: `main.tscn` → `scripts/clockwork_world.gd`
- Run tests: `godot --headless --path . --script res://scripts/tests/test_suite.gd`

## Architecture
```
model/rotor.gd          — state for each rotating component
constraints/*.gd         — gear mesh, belt, escapement velocity constraints
solver/mechanism_solver.gd — iterative solver with convergence check
mechanism_model.gd       — composes all rotors + constraints + auxiliary subsystems
clockwork_world.gd       — visualization and input handling (Node2D)
```

## Key design decisions
- Constraint-based velocity solver, not contact geometry — intentionally a toy
- 4 substeps per physics frame (120 Hz physics = 480 solver ticks/sec)
- Solver has early-exit on convergence (threshold 0.001)
- NaN/Inf sanitization on every rotor every frame
- Omega hard-clamped at 120 rad/s

## Test layers
1. `godot --headless --quit --path .` — project loads
2. `physics_test_runner.gd` — scene-level 7s motion test
3. `tests/test_suite.gd` — invariant checks at 2s and 6s marks
4. Docker container build + run

## Tuning parameters
Magic numbers in `mechanism_model.gd` are empirically tuned for stability.
Constraint compliance values (0.86–0.97) control how aggressively velocity
errors are corrected per iteration. Lower = softer coupling.
