# Test Infrastructure

**Engine**: Roblox Studio (live platform) + Luau
**Test Framework**: TestEZ (https://github.com/Roblox/testez)
**Headless CI runner**: Lune (https://github.com/lune-org/lune) — standalone Luau runtime with built-in Roblox API emulation
**Tool manager**: Foreman (https://github.com/Roblox/foreman) — installs and manages Lune and Rojo versions
**CI**: `.github/workflows/tests.yml`
**Setup date**: 2026-07-06, corrected 2026-07-07

## Directory Layout

```
tests/
  unit/           # Isolated unit tests (formulas, state machines, logic) — no Roblox services,
                  # no DataStore, no RemoteEvents. Pure Luau + Lune-emulated primitives only.
  integration/    # Cross-system tests (e.g. death/respawn reconciliation, RunController fan-in)
  smoke/          # Critical path checklist for /smoke-check (15-minute manual gate)
  evidence/       # Screenshot logs and manual test sign-off records (Visual/Feel, UI stories)
  run_tests.lua   # Headless test runner (Luau script, executed by Lune)
  results/        # Generated test results (created at runtime, .gitignored)
```

## Running Tests

**Interactively in Studio**: open the place, use `TestService` (or a TestEZ bootstrap
script pointed at `tests/`) to run all specs and view results in the Output window.

**Headlessly for CI**: TestEZ specs run under Lune (a standalone Luau runtime), which provides:
- Full Luau language support (--!strict, type annotations, union types, compound operators)
- Built-in Roblox API emulation (@lune/roblox): `game`, `Instance`, `game:GetService()`, `require()`
- No external Roblox runtime or Studio instance required

**Toolchain** (corrected 2026-07-07):
- **Tool manager**: Foreman (installs CLI tools listed in `foreman.toml`)
- **Luau runtime**: Lune (installed by Foreman; v0.8.9+ required to parse project code)
- **Test framework**: TestEZ (optional; tests fall back to direct function execution if unavailable)
- **Build tool**: Rojo (installed by Foreman; used for future Studio sync validation)
- **Runner script**: `tests/run_tests.lua` — Luau script that:
  1. Sets up a virtual Roblox environment (Instance tree, game:GetService())
  2. Discovers all `*_test.luau`, `*_test.lua`, `*.spec.luau`, `*.spec.lua` files
  3. Loads test files (which require() the modules under test)
  4. Executes tests via TestEZ (if available) or direct function calls
  5. Reports results to stdout and `tests/results/`
  6. Exits non-zero on any failure (CI gate)

See `.github/workflows/tests.yml` for the CI invocation. The workflow installs Foreman,
uses it to install Lune and Rojo (via `foreman.toml`), then runs `lune run tests/run_tests.lua`.

## Test Naming

- **Files**: `*_test.luau` or `*.spec.luau`, placed in `tests/unit/` or `tests/integration/`
  - Example: `tests/unit/player-controller/lantern-gather-gate_test.luau`
- **TestEZ blocks**: `describe("[System] — [behavior]", function() it("does X", function() ... end) end)`
- **Return value**: Each test file must return a function that receives TestEZ's describe/it/expect harness

## Story Type → Test Evidence

(Mirrors `.claude/docs/coding-standards.md` Testing Standards — restated here for
quick reference; that document is authoritative if the two ever drift.)

| Story Type | Required Evidence | Location | Gate Level |
|---|---|---|---|
| Logic (formulas, AI, state machines) | Automated unit test — must pass | `tests/unit/[system]/` | BLOCKING |
| Integration (multi-system) | Integration test OR documented playtest | `tests/integration/[system]/` | BLOCKING |
| Visual/Feel (animation, VFX, feel) | Screenshot + lead sign-off | `production/qa/evidence/` | ADVISORY |
| UI (menus, HUD, screens) | Manual walkthrough doc OR interaction test | `production/qa/evidence/` | ADVISORY |
| Config/Data (balance tuning) | Smoke check pass | `production/qa/smoke-[date].md` | ADVISORY |

Note: `tests/evidence/` (this directory) holds ad-hoc screenshot/sign-off artifacts
captured *during* test authoring; the dated, gate-facing smoke reports live in
`production/qa/` per the table above — the two are not the same thing.

## CI

Tests run automatically on every push to `main` and on every pull request via
`.github/workflows/tests.yml`. A failed test suite blocks merging.

## Future Enhancements

The current CI pipeline focuses on **logic validation via Lune** (pure Luau without
Roblox services or networked systems). To fully verify the Roblox build, the following
are needed (blocked for follow-up sessions, not for initial Sprint 1 CI):

1. **Rojo Build Verification**
   - Tool: Foreman (installs Rojo; already managed in `foreman.toml`)
   - File: `default.project.json` (already scaffolded)
   - Goal: Verify `rojo build` succeeds and produces valid `.rbxlx` Studio files
   - Blocker: Requires Knit, Signal, and TestEZ to be vendored via Wally (see below)

2. **Package Vendoring (Wally)**
   - Files needed: `wally.toml`, `wally.lock`, `Packages/` directory with Knit, RbxUtil (Signal), ProfileStore
   - Goal: Provide real implementations of vendored packages for Rojo builds
   - Current status: Deferred — the immediately-blocked test file
     (`lantern-gather-gate_test.luau`) has ZERO Knit/Signal/external dependencies and loads
     cleanly under Lune's built-in Roblox API emulation. Package vendoring is necessary for
     production Roblox builds and other tests that integrate with the Knit framework, but not
     for unblocking this sprint's pure-logic tests.

3. **Studio Smoke Test**
   - Tool: Rojo sync to Studio + TestService (manual or automated via Studio CLI)
   - Goal: Verify that synced code actually loads in Studio without errors
   - Blocker: Requires Rojo build to succeed (see #1)

4. **Integration Tests with Services**
   - Goal: Test modules that require Knit services, RemoteEvents, DataStore mocking
   - Blocker: Test harness injection seams (ADR-0013 mentions crafting-test-harness-injection-seam)
   - Current status: Deferred to after the core logic tests pass

## Troubleshooting

**"Lune: parse error" or "unexpected token"**: The version of Lune installed is too old to parse
Luau syntax. Check `foreman.toml` for the pinned version; consult https://github.com/lune-org/lune
for the latest. Luau syntax support (--!strict, type annotations, compound operators) is required.

**"game:GetService() failed"**: Lune's built-in Roblox API may not have initialized. Verify
that `tests/run_tests.lua` is calling `setup_roblox_environment()` before loading test files.

**"Cannot find module"**: Verify that the module under test exists at the path expected by
the test file's `require()` call (e.g., `src/gameplay/services/PlayerControllerLanternLogic.luau`).

**TestEZ not found**: TestEZ is optional. Tests will still run via direct function execution,
but without TestEZ's describe/it/expect harness. To use TestEZ, install it via:
`luarocks install testez` (for development) or add it to the project's package management.
