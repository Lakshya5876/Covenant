# Covenant demo repo

A tiny four-layer billing service, used by `demo.sh` / `demo.ps1` (at the Covenant
repo root) to show Covenant's core loop end to end: install governance, watch an
AI-shaped violation get caught and explained, fix it, watch it verify clean.

This is scaffolding for the demo — not meant to be run as a real service.
`src/domain/`, `src/application/`, `src/infrastructure/`, `src/presentation/`
mirror the four-layer architecture CovenantMac's greenfield basket scaffolds by
default (see `v1_release/basket-2-greenfield/`).
