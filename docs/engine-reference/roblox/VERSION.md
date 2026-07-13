# Roblox Studio — Version Reference

| Field | Value |
|-------|-------|
| **Engine** | Roblox Studio (live platform — auto-updating) |
| **Language** | Luau |
| **Project Pinned** | 2026-04-29 |
| **Last Docs Verified** | 2026-04-29 |
| **LLM Knowledge Cutoff** | January 2026 |
| **Risk Level** | HIGH — auto-updating platform; APIs evolve continuously |

## Knowledge Gap Warning

Roblox Studio is a **live platform** — there is no version to pin. Studio
auto-updates, the Luau language evolves on its own cadence, and the Roblox
service API surface gains new members every release. Treat all Roblox API
recommendations as "verify against current docs before using."

The LLM's training data covers Roblox up to ~early 2026. Significant
post-cutoff additions and changes exist:

- **Luau New Type Solver** — moved out of Studio Beta in November 2025; Non-Strict by Default mode also went GA. Strict typing is now a strong default for new scripts.
- **Character Controller Library** — full release. Replaces several older `Humanoid`-driven movement patterns.
- **`UIShadow`** component — drop shadows on UI instances.
- **Input Action System** — new keycodes including `TouchPosition`.
- **Studio MCP Server (built-in)** — official MCP server now ships inside Studio. Tools sync automatically with Roblox Assistant.
- **Studio "going agentic"** (April 2026) — Roblox is positioning Studio for AI-driven workflows. Expect API surface for agents to expand.

## Verification Workflow

Before suggesting any Roblox API:

1. Check `docs/engine-reference/roblox/breaking-changes.md` and `deprecated-apis.md` for known issues
2. Check `docs/engine-reference/roblox/current-best-practices.md` for the modern idiomatic approach
3. WebSearch the API name + "Roblox" if you are uncertain — APIs change quickly
4. Cross-reference Roblox Creator Docs: https://create.roblox.com/docs/

## Verified Sources

- Roblox Creator Docs: https://create.roblox.com/docs/
- Luau official site: https://luau.org/
- Luau GitHub releases: https://github.com/luau-lang/luau/releases
- Roblox Studio release notes: https://devforum.roblox.com/c/updates/release-notes/62
- Roblox Studio MCP docs: https://create.roblox.com/docs/studio/mcp
- Studio MCP server (open source, Rust): https://github.com/Roblox/studio-rust-mcp-server
- Knit framework: https://sleitnick.github.io/Knit/
- Rojo: https://rojo.space/
- TestEZ (testing): https://github.com/Roblox/testez
- ProfileStore (DataStore wrapper): https://madstudioroblox.github.io/ProfileStore/
