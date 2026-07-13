# Claude Code Game Studios -- Game Studio Agent Architecture

Indie game development managed through 49 coordinated Claude Code subagents.
Each agent owns a specific domain, enforcing separation of concerns and quality.

## Technology Stack

- **Engine**: Roblox Studio (live platform — auto-updating)
- **Language**: Luau (typed Lua dialect, `--!strict` for new scripts)
- **Version Control**: Git + Rojo (file-based sync to/from Studio)
- **Build System**: Roblox Cloud / Studio Publish
- **Asset Pipeline**: Roblox Creator Store + Asset Manager
- **Architecture Framework**: Knit (services + controllers + networking helpers)

> **Note**: This template ships engine specialists for Godot, Unity, and Unreal.
> No native Roblox specialist exists — all Luau code review falls back to
> `gameplay-programmer`. See `.claude/docs/technical-preferences.md` for routing.

## Project Structure

@.claude/docs/directory-structure.md

## Engine Version Reference

@docs/engine-reference/roblox/VERSION.md

## Technical Preferences

@.claude/docs/technical-preferences.md

## Coordination Rules

@.claude/docs/coordination-rules.md

## Collaboration Protocol

**User-driven collaboration, not autonomous execution.**
Every task follows: **Question -> Options -> Decision -> Draft -> Approval**

- Agents MUST ask "May I write this to [filepath]?" before using Write/Edit tools
- Agents MUST show drafts or summaries before requesting approval
- Multi-file changes require explicit approval for the full changeset
- No commits without user instruction

See `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` for full protocol and examples.

> **First session?** If the project has no engine configured and no game concept,
> run `/start` to begin the guided onboarding flow.

## Coding Standards

@.claude/docs/coding-standards.md

## Context Management

@.claude/docs/context-management.md
