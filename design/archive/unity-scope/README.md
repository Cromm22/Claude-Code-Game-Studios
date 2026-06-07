# Unity-Scope Archive

These files were authored when Terranova targeted Unity 6.3 LTS as a single-player/co-op
Steam game with a 3-4 year multi-planet vision. The project pivoted to Roblox on
**2026-04-29** with a substantially reduced scope (single map, co-op from day one,
2-4 month MVP, ~9 systems).

## Why archived (not deleted)

Some of the design thinking is engine-agnostic and may inform the Roblox-era
work — particularly:

- **game-concept.md** lives in place at `design/gdd/game-concept.md` (rewritten in place, not archived)
- **biome.md** — the player-experience principles for a survival biome can be salvaged when designing the Roblox map
- **item-database.md** — schema thinking around Component/Tool/Structure category exemptions, durability models, and modifier semantics is largely engine-agnostic
- **art-bible.md** — visual principles (penumbra, scale-speaks-before-color, biological color = information) may carry over with adjustments for Roblox's stylized aesthetic
- **entities.yaml** — formula and constant registrations from the Unity scope; useful as reference when authoring the new registry

## Why pivoted

User decision 2026-04-29: switch to Roblox to (a) leverage Roblox's built-in
multiplayer and platform infrastructure, (b) reduce overall scope to a 2-4 month
MVP rather than a multi-year project, and (c) work with the official Roblox
Studio MCP server for AI-assisted development.

## What was NOT archived

- `design/gdd/game-concept.md` — staying in place, being rewritten for Roblox scope
- `design/gdd/systems-index.md` — staying in place, being rewritten for the reduced MVP
- `CLAUDE.md` and `.claude/docs/technical-preferences.md` — overwritten in place with Roblox config
- `docs/engine-reference/unity/` — moved to `docs/engine-reference/unity-archived/` for the same reasons (preserve, don't delete)

## Structure

```
design/archive/unity-scope/
├── README.md                                 # this file
├── gdd/
│   ├── biome.md                              # Biome system GDD (revised, re-review pending at archive)
│   ├── item-database.md                      # Item DB GDD (3rd revision pending at archive)
│   └── reviews/
│       ├── biome-review-log.md
│       └── item-database-review-log.md
├── art/
│   └── art-bible.md                          # 9-section art bible
└── registry/
    └── entities.yaml                         # formula + constant registry
```
