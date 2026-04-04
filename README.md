# Clockwork Epicycles, Rube-Goldberg Edition

A Godot 4 project that renders a physically motivated clockwork core and fans that motion out into several additional modalities of mechanical interaction.

## Architecture

The mechanism is split into explicit layers:

| Layer | Path | Purpose |
|-------|------|---------|
| State | `scripts/model/rotor.gd` | Canonical rotor: theta, omega, inertia, torque |
| Constraints | `scripts/constraints/*.gd` | Gear mesh, belt, escapement velocity constraints |
| Solver | `scripts/solver/mechanism_solver.gd` | Iterative constraint solver with convergence check |
| Composition | `scripts/mechanism_model.gd` | Wires everything together + auxiliary subsystems |
| Visualization | `scripts/clockwork_world.gd` | 2D rendering, debug overlay, input |

## Mechanical modalities

1. **Epicyclic gear train** — sun, 2 planets, carrier, ring → dial
2. **Escapement & balance** — periodic impulse regulation
3. **Compliant belt drive** — dial → flywheel with slip model
4. **Cam + follower** — flywheel rotation → linear lift
5. **Hammer & bell** — follower drives hammer into bell oscillator
6. **One-way ratchet** — 12-tooth clickwheel, engages on downstroke
7. **Geneva output** — stepwise 90° increments from ratchet

## Controls

| Key | Action |
|-----|--------|
| `Space` | Pause / resume |
| `Up` / `Down` | Increase / decrease drive torque (4–80 N·m) |
| `Left` / `Right` | Add / release ring brake (0–0.9) |
| `D` | Toggle debug overlay |
| `R` | Reset simulation |

## Running tests

```bash
# Project loads
godot --headless --quit --path .

# Scene-level physics test (7 seconds)
godot --headless --path . --script res://scripts/physics_test_runner.gd

# Invariant test suite (6 seconds)
godot --headless --path . --script res://scripts/tests/test_suite.gd

# Docker
docker build -t clockwork-test . && docker run --rm clockwork-test
```

## CI/CD

GitHub Actions workflow (`.github/workflows/build.yml`) runs Linux tests, then builds and exports a macOS universal app as an artifact.

## Caveat

This is a physically motivated toy mechanism, not literal tooth-contact rigid-body simulation. The engineering focus is on coherence, modularity, and testability rather than full contact-geometry realism.
