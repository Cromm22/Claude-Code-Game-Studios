# Roblox — Deprecated APIs

> **Last verified**: 2026-04-29
> **Format**: "Don't use X → Use Y" for each deprecated or anti-pattern API.
> Roblox is a live platform — this document is a living reference. Add entries as discovered.

---

## Coroutine / Scheduling Primitives

| Don't Use | Use Instead | Reason |
|-----------|-------------|--------|
| `wait(t)` | `task.wait(t)` | Older `wait` has lower precision and higher overhead |
| `spawn(f)` | `task.spawn(f)` | `task.spawn` runs immediately; `spawn` defers to next resume |
| `delay(t, f)` | `task.delay(t, f)` | Same precision and overhead reasoning |
| `coroutine.wrap` for game logic | `task.spawn` | `task.*` integrates with Roblox scheduler properly |

---

## DataStore Patterns

| Don't Use | Use Instead | Reason |
|-----------|-------------|--------|
| Raw `:GetAsync()` / `:SetAsync()` | ProfileStore (wrapper) | Handles retry, backoff, session-locking, conflict resolution |
| `:UpdateAsync` without `pcall` | `pcall(function() store:UpdateAsync(...) end)` | DataStore calls fail; failures must be caught |
| Saving on every property change | Periodic save + `BindToClose` final save | DataStore has rate limits per key |

---

## Networking

| Don't Use | Use Instead | Reason |
|-----------|-------------|--------|
| Trusting client-supplied numbers | Server validation + clamping | Clients are fully untrusted |
| `RemoteFunction` for fire-and-forget | `RemoteEvent` | RemoteFunction yields the caller; only use when you need a return value |
| BindableEvent across client/server | RemoteEvent / RemoteFunction | BindableEvents do not cross network boundaries |

---

## Scripting / Architecture

| Don't Use | Use Instead | Reason |
|-----------|-------------|--------|
| `_G` for cross-script state | ModuleScripts + Knit Services | `_G` is global, untyped, race-prone |
| Polling `Workspace:WaitForChild` in tight loops | Signal-driven (`:GetPropertyChangedSignal`, attribute changed events) | Polling wastes Heartbeat budget |
| `script.Parent` chaining (3+ levels) | Top-level module reference | Fragile to scene reorganization |

---

## UI

| Don't Use | Use Instead | Reason |
|-----------|-------------|--------|
| Hardcoded pixel sizes | `UIScale`, `UIAspectRatioConstraint`, scale-based UDim2 | Fails on mobile / different aspect ratios |
| Hover-only affordances | Tap/click + visible state | Mobile and gamepad have no hover |
| Per-frame `Mouse:GetPosition()` | `UserInputService.InputChanged` events | Event-driven, no Heartbeat cost |

---

## Type System

| Don't Use | Use Instead | Reason |
|-----------|-------------|--------|
| Implicit `any` types in new scripts | Explicit type annotations | New type solver catches bugs at edit time |
| `--!nonstrict` (default) for new scripts | `--!strict` | Stricter inference is the project standard |

---

## How to Add New Entries

When you discover an API that is deprecated or that the team agrees is an anti-pattern:

1. Add a row to the relevant table above
2. Cross-link to `breaking-changes.md` if the deprecation came from a specific Roblox release
3. Update `Last verified` date at top of this file
