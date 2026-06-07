# Roblox — Breaking Changes Log

> **Last verified**: 2026-04-29
> **Scope**: Notable behavior changes since LLM training cutoff that affect commonly-used APIs.
> Roblox is a live platform — this document is a living reference, not a complete changelog.

---

## Luau New Type Solver — GA November 2025

**Change**: New type solver and Non-Strict by Default mode moved out of Studio Beta to general availability.

**Impact**:
- Type inference is stricter and catches more errors at edit time
- Some previously-accepted code patterns now produce type errors
- `--!strict` annotation strongly recommended for all new scripts

**Migration**:
- Add `--!strict` to the top of new scripts
- Annotate function parameter types and return types explicitly
- Use `type` aliases for shared shapes

---

## Character Controller Library — Full Release

**Change**: New `CharacterController` system replaces some `Humanoid`-driven movement patterns for new projects.

**Impact**:
- Older tutorials using `Humanoid:MoveTo()` and similar may not represent current best practice for new movement systems
- `Humanoid` still works — this is additive, not a removal
- New movement rigs should use the Character Controller Library for finer control (jump curves, slope handling, custom states)

**Migration**:
- Existing projects using `Humanoid` need not migrate
- New projects should evaluate Character Controller Library first
- Reference: https://devforum.roblox.com/t/full-release-the-future-of-character-movement-character-controller-library/4565267

---

## `task` Library Replacements (long-standing, but still mis-cited in pre-2024 tutorials)

**Change**: Legacy globals `wait()`, `spawn()`, `delay()` are deprecated in favor of `task.wait()`, `task.spawn()`, `task.delay()`.

**Impact**:
- Legacy globals still work but are slower and less precise
- All new code MUST use `task.*` equivalents

**Migration**:
- `wait(t)` → `task.wait(t)`
- `spawn(f)` → `task.spawn(f)`
- `delay(t, f)` → `task.delay(t, f)`

---

## FilteringEnabled is Mandatory

**Change** (long-standing — for completeness): All Roblox experiences are FilteringEnabled. Client→server communication requires `RemoteEvent`/`RemoteFunction`. Direct client modifications to server state never replicate.

**Impact**:
- Any tutorial showing client scripts directly modifying server state is wrong
- All gameplay-affecting actions must round-trip through a server-side validator

**Migration**:
- Audit every client-initiated action — must go through `RemoteEvent:FireServer()` with server validation

---

## Studio Built-in MCP Server (April 2026)

**Change**: Roblox now ships an official MCP server inside Studio. The standalone open-source `studio-rust-mcp-server` (used by this project) is being superseded for most use cases.

**Impact**:
- New API surface for agent-driven workflows: `run_code`, `insert_model`, `get_console_output`, `start_stop_play`, `run_script_in_play_mode`
- This project currently uses the standalone version per user setup

**Migration**:
- Optional: switch to the built-in Studio MCP server if Roblox Assistant integration is desired
- Reference: https://devforum.roblox.com/t/assistant-updates-studio-built-in-mcp-server-and-playtest-automation/4474643

---

## How to Add New Entries

When a Roblox API change is discovered during development:

1. Add a section here with: change name, date verified, impact, migration steps, source URL
2. If the change deprecates a specific API, also add an entry to `deprecated-apis.md`
3. If the change introduces a new idiomatic pattern, add an entry to `current-best-practices.md`
4. Update `Last verified` date at top of this file
