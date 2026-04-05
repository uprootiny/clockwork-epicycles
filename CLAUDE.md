# Clockwork Epicycles

## Quick start
- Engine: Godot 4.2.2
- Main scene: `main.tscn` → 2D clockwork visualization
- Armillary: `armillary.tscn` → 3D orrery with exact gear ratios
- Run tests: `godot --headless --path . --script res://scripts/tests/test_suite.gd`

## Architecture
```
main.tscn → clockwork_world.gd
  └─ mechanism_model.gd (constraint-based 2D simulation)
      ├─ model/rotor.gd
      ├─ solver/mechanism_solver.gd
      └─ constraints/{mesh,belt,escapement}_constraint.gd

armillary.tscn → armillary_orrery.gd
  └─ mechanism/exact/orrery_mechanism.gd (tooth-count-derived simulation)
      ├─ gear_geometry.gd    (pitch radius, contact ratio from module+teeth)
      ├─ bevel_geometry.gd   (cone angles, ω·sin(δ) law)
      └─ contact_solver.gd   (velocity-level Baumgarte, Willis equation)
```

## Two simulation cores

1. **mechanism_model.gd** — original constraint solver, 7 subsystems
   (sun, carrier, planets, ring, dial, escapement, balance, flywheel,
   cam/follower, hammer/bell, ratchet, Geneva). Velocity-projection
   with 20 iterations.

2. **mechanism/exact/** — tooth-count-derived model. All geometry from
   `module=0.04` and tooth counts. Willis equation enforced by contact
   dynamics. Bevel gear chain for armillary ring outputs.

## Key invariants
- Willis: (ω_sun - ω_carrier)/(ω_ring - ω_carrier) = -N_ring/N_sun
- Tooth constraint: N_ring = N_sun + 2·N_planet (48 = 24 + 2×12)
- Energy bounded, sanitized each frame
- Delta clamped to 100ms max

## Test layers
1. `physics_test_runner.gd` — scene-level 7s motion test
2. `tests/test_suite.gd` — invariant checks at 2s and 6s (synchronous)
3. `tests/test_exact_epicyclic.gd` — geometry, Willis, energy validation

## Web deploy
Exported to GitHub Pages via `deploy-web.yml`. Service worker handles
COOP/COEP for SharedArrayBuffer. Renderer patched to gl_compatibility
for WebGL. Text-mode script export (not compiled bytecode).
