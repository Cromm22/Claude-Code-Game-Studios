# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Roblox Studio (live platform — auto-updating)
- **Language**: Luau (typed dialect of Lua, `--!strict` annotation required for new scripts)
- **Rendering**: Roblox built-in renderer (no SRP choice; per-instance Material and Lighting properties)
- **Physics**: Roblox built-in physics (constraint-based, server-authoritative)
- **Architecture Framework**: Knit (Service/Controller pattern with built-in networking)
- **Sync Tool**: Rojo (file-based sync between this repo and Roblox Studio)

## Input & Platform

<!-- Written by /setup-engine. Read by /ux-design, /ux-review, /test-setup, /team-ui, and /dev-story -->
<!-- to scope interaction specs, test helpers, and implementation to the correct input methods. -->

- **Target Platforms**: Roblox (PC, Mobile iOS/Android, Console — Roblox handles per-platform automatically)
- **Input Methods**: Keyboard/Mouse, Touch, Gamepad
- **Primary Input**: Keyboard/Mouse on PC; Touch on mobile (cross-platform from day one)
- **Gamepad Support**: Full (Roblox auto-detects and routes via `UserInputService` / `ContextActionService`)
- **Touch Support**: Full (mobile is a primary target — Roblox audience skews mobile)
- **Platform Notes**: All UI must scale via `UIScale` and aspect-ratio constraints. Test on lowest-tier mobile device (iPhone SE-class). No hover-only interactions. All interactive prompts must work with touch tap, mouse click, and gamepad button.

## Naming Conventions

- **Modules / Services / Controllers**: PascalCase (e.g., `PlayerService`, `EcologicalDisturbanceController`)
- **Public Methods**: PascalCase (e.g., `TakeDamage()`, `GetDisturbanceLevel()`)
- **Public Properties**: PascalCase (e.g., `MoveSpeed`, `OxygenLevel`)
- **Local Variables**: camelCase (e.g., `currentHealth`, `disturbanceLevel`)
- **Private Members** (table fields with underscore convention): `_camelCase` (e.g., `_internalState`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_OXYGEN`, `DEFAULT_MOVE_SPEED`)
- **Files**: PascalCase matching the module name (e.g., `PlayerController.luau`)
- **Knit Services**: `<Domain>Service` (e.g., `ResourceService`, `PredatorService`) — server-side
- **Knit Controllers**: `<Domain>Controller` (e.g., `HUDController`) — client-side
- **RemoteEvents / RemoteFunctions**: PascalCase verb-form (e.g., `RequestGather`, `OnDisturbanceChanged`)
- **Folders in Studio Explorer**: PascalCase per Roblox convention

## Performance Budgets

- **Target Framerate**: 60fps on mid-range PC; 30fps mobile baseline (lowest-tier device)
- **Server tick rate**: 60Hz (Roblox default Heartbeat)
- **Network bandwidth**: < 50 KB/s per client (Roblox advisory ceiling)
- **Memory Ceiling**: < 1GB total client memory on lowest-tier mobile
- **Asset budget**: < 200MB total place asset weight for fast initial load

## Testing

- **Framework**: TestEZ (de-facto Luau unit test framework)
- **Test runner**: TestService inside Studio (interactive) + Lemur for headless CI
- **Minimum Coverage**: All server-authoritative gameplay systems (resource management, ecological disturbance, predator AI, datastore writes)
- **Required Tests**: Balance formulas, server authority verification, exploit-resistance for all RemoteEvents, datastore retry/backoff logic
- **Type Checking**: `--!strict` on all new scripts — counts as a baseline correctness gate

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- Trusting client-supplied values for gameplay-critical state (always validate server-side)
- Direct `DataStoreService` writes without retry/backoff (use ProfileStore or equivalent wrapper)
- `wait()` (deprecated) — use `task.wait()` instead
- `spawn()` / `delay()` (deprecated) — use `task.spawn()` / `task.delay()` instead
- Synchronous `:GetAsync()` / `:SetAsync()` on hot paths (always wrap in `pcall` + retry)
- `_G` global tables for cross-script communication (use ModuleScripts or Knit Services)

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here. Only add when actively integrating — not speculatively. -->
- **Knit** (architecture framework) — confirmed at engine setup
- **Rojo** (file sync) — confirmed at engine setup

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- [No ADRs yet — use /architecture-decision to create one]

## Engine Specialists

<!-- Written by /setup-engine when engine is configured. -->
<!-- Read by /code-review, /architecture-decision, /architecture-review, and team skills -->
<!-- to know which specialist to spawn for engine-specific validation. -->

- **Primary**: gameplay-programmer (no native Roblox specialist exists in this template)
- **Language/Code Specialist**: gameplay-programmer (Luau review — generalist fallback)
- **Shader Specialist**: N/A (Roblox has no custom shader system; use built-in Material/Lighting properties)
- **UI Specialist**: ui-programmer (Roblox UI uses built-in `ScreenGui`/`Frame`/`UICorner` etc.)
- **Additional Specialists**: network-programmer (RemoteEvent/RemoteFunction architecture, server-authority enforcement, exploit resistance)
- **Routing Notes**: All Luau gameplay code routes to `gameplay-programmer`. UI work routes to `ui-programmer`. Networking and server-authority review routes to `network-programmer`. When the template adds a `roblox-specialist` or `roblox-luau-specialist` in future, update this section.

### File Extension Routing

<!-- Skills use this table to select the right specialist per file type. -->
<!-- If a row says [TO BE CONFIGURED], fall back to Primary for that file type. -->

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.luau, .lua files) | gameplay-programmer |
| Server services (`*Service.luau`) | gameplay-programmer (consult network-programmer for RemoteEvent surface) |
| UI scripts (`*Controller.luau` for UI, ScreenGui-related) | ui-programmer |
| Rojo project files (default.project.json) | gameplay-programmer |
| Studio binary (.rbxlx, .rbxl) | (manual — should not be tracked as text in git; export/diff with Rojo) |
| General architecture review | gameplay-programmer |
