# Accessibility Requirements: Terranova

> **Status**: Committed
> **Author**: producer + gameplay-programmer (authored during Pre-Production, standing in for an unstaffed ux-designer/accessibility-specialist role)
> **Last Updated**: 2026-07-06
> **Accessibility Tier Target**: Standard
> **Platform(s)**: PC, Mobile (iOS/Android), Console (Roblox handles per-platform automatically)
> **External Standards Targeted**:
> - WCAG 2.1 Level AA (the project's own HUD GDD already cites WCAG 2.3.1 for flash limits)
> - AbleGamers CVAA Guidelines
> - Xbox Accessibility Guidelines (XAG): N/A — Roblox is not distributed via ID@Xbox
> - PlayStation Accessibility (Sony Guidelines): N/A — Roblox does not currently ship natively on PlayStation
> - Apple / Google Accessibility Guidelines: Partial — Roblox's own client provides OS-level accessibility passthrough; this document covers what Terranova's own UI must do on top of that
> **Accessibility Consultant**: None engaged
> **Linked Documents**: `design/gdd/systems-index.md`, `design/gdd/hud.md`, `design/art/art-bible.md` (predator-hue-exclusion system), `docs/architecture/control-manifest.md`

> **Note on authorship**: This document was written during Pre-Production to close a
> carried `/gate-check` obligation, not by a dedicated `ux-designer` in a design-first
> pass. Its Per-Feature Matrix and Test Plan should be treated as a first draft —
> revisit once `design/ux/hud.md` (a real UX spec, not the mechanics-focused GDD) exists.

---

## Accessibility Tier Definition

### Tier Definitions

| Tier | Core Commitment | Typical Effort |
|------|----------------|----------------|
| **Basic** | Critical player-facing text is readable at standard resolution. No feature requires color discrimination alone. Volume controls exist for music, SFX, and voice independently. The game is completable without photosensitivity risk. | Low |
| **Standard** | All of Basic, plus: full input remapping on all platforms, subtitle support with speaker identification, adjustable text size, at least one colorblind mode, and no timed input that cannot be extended or toggled. | Medium |
| **Comprehensive** | All of Standard, plus: screen reader support for menus, mono audio option, difficulty assist modes, HUD element repositioning, reduced motion mode, and visual indicators for all gameplay-critical audio. | High |
| **Exemplary** | All of Comprehensive, plus full subtitle customization, high contrast mode, cognitive load assist tools, tactile/haptic alternatives, and external audit. | Very High |

### This Project's Commitment

**Target Tier**: Standard

**Rationale**: Terranova is a fast-twitch co-op survival/horror game whose entire differentiator ("quiet beats loud") depends on players reading the world — bioluminescent saturation, predator eye-shine, a HUD disturbance meter — under time pressure. That combination creates real visual and cognitive barriers (color-coded threat information, timed grace windows, a stealth mechanic that punishes players who can't perceive escalation cues) but comparatively few motor barriers unique to the genre (no combos, no rhythm inputs; sprint/gather/lantern are hold-or-tap actions already designed with touch/gamepad/KB+M parity in `technical-preferences.md`). Standard tier — full remapping, at least one colorblind mode, adjustable text/UI scale, and no un-extendable timed input — directly addresses the barriers this specific game creates, at a cost this solo-dev project can actually carry through Pre-Production and Production. Comprehensive tier (screen reader menus, mono audio, HUD repositioning) would be a genuine improvement but is not achievable without a dedicated accessibility engineer or specialist consultant, neither of which exists on this project yet. Two facts already push this project toward Standard rather than Basic: the art bible's own predator-hue-exclusion system (§4.2/§4.5, currently under an open contradiction — see Known Intentional Limitations) already assumes colorblind-safe design is load-bearing, not optional; and HUD's own GDD (UI.7, H.6, H.26) already writes reduced-motion and WCAG 2.3.1 flash-limit rules into its acceptance criteria — both are Standard-tier-adjacent commitments the design has already made informally. This document makes that commitment formal and traceable.

**Features explicitly in scope (beyond tier baseline)**:
- Combined-flash WCAG 2.3.1 ceiling (≤3 onsets/sec) enforced project-wide via a single `FlashArbiter` module (HUD's own D.6/H.6/H.26) — elevated because this project's disturbance-meter and beacon-window mechanics are flash-heavy by design.
- Reduced-motion flag read by every animated HUD element, classifying each as load-bearing (degrade to a minimal functional form) vs. decorative (static fallback) — already a HUD GDD requirement (UI.7).

**Features explicitly out of scope** (see Known Intentional Limitations for rationale):
- Screen reader support for menus (Comprehensive tier) — no accessibility specialist or platform API integration budget exists yet.
- Mono audio option and closed captions for gameplay-critical SFX (Comprehensive tier) — this project's own systems index cut "Adaptive Audio" and defers most audio design; revisit once an audio-direction pass exists.

---

## Visual Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Minimum text size — HUD | Standard | In-game HUD | Not Started | 20px-equivalent minimum for critical info (oxygen, disturbance tier, beacon window), scaled via `UIScale`/`UIAspectRatioConstraint` per `technical-preferences.md`. |
| Text contrast — UI text on backgrounds | Standard | All UI text | Not Started | Minimum 4.5:1 (WCAG AA body text), 3:1 for large text. Test against the art bible's dark-pool/unlit-zone contrast rule (§1) — HUD text must remain legible over both lit and unlit backgrounds. |
| Colorblind mode — at least Protanopia/Deuteranopia | Standard | All color-coded gameplay (disturbance meter, oxygen state, node tiers) | Not Started | The art bible's predator-hue-exclusion system (§4.2) already reserves a hue no ambient asset may use — this is the right foundation for a colorblind-safe palette, but the mode itself (a client-side color remap) is unimplemented. |
| Color-as-only-indicator audit | Basic | All UI and gameplay | Not Started | See table below — populated with Terranova's actual color-coded systems. |
| UI scaling | Standard | All UI elements | Not Started | 75%–150% range; HUD scaling independent from menu scaling, per `technical-preferences.md`'s platform notes. |
| Screen flash / strobe warning | Basic | Disturbance spike VFX, beacon-window flash cues | Not Started | HUD's own `FlashArbiter` (D.6/H.6/H.26) already targets the Harding FPA ≤3-flashes/sec standard — this document adopts that as the project-wide commitment, not just a HUD-internal one. |
| Motion/animation reduction mode | Standard | HUD transitions, disturbance meter tween, camera effects | Not Started | HUD's UI.7 reduced-motion flag (read-only, external) already specifies load-bearing-vs-decorative classification — this is the Standard-tier feature it satisfies. |

### Color-as-Only-Indicator Audit

| Location | Color Signal | What It Communicates | Non-Color Backup | Status |
|----------|-------------|---------------------|-----------------|--------|
| Disturbance meter (HUD) | Tier color (calm/tense/hunt bands) | Current ecological disturbance level | Numeric/bar-fill readout + distinct pip shapes per tier (per HUD GDD's own pip system) | Not Started |
| Oxygen state (HUD) | Healthy/Critical/Empty color coding | Squad oxygen pool state | Numeric value + `OnOxygenStateChanged` triggers a distinct icon change, not color alone | Not Started |
| Predator distance band (HUD chevron) | Color intensity by distanceBand | How close the predator is | Chevron size/pulse-rate change + eye-shine screen-space cue, not color alone | Not Started |
| Node tier (Resource Node) | Tier-coded node glow color | Light/Medium/Heavy node yield tier | Distinct node silhouette/size per tier (already implied by RN's per-tier config) | Not Started |
| Beacon charge tier | BC1–BC4 color-coded UI state | Escalation stage of the win-condition | Numeric tier label + distinct icon per stage | Not Started |

---

## Motor Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Full input remapping | Standard | All gameplay inputs, all platforms | Not Started | PC GDD already designs per-platform bindings (touch toggle / KB+M hold / gamepad L3-hold for sprint) — remapping UI on top of these bindings is the remaining work. |
| Input method switching | Standard | PC | Not Started | Player must switch keyboard/mouse <-> gamepad without restarting; UI prompts must update dynamically. |
| Hold-to-press alternatives | Standard | Sprint, lantern-raise, gather | Not Started | PC's own GDD already treats sprint as touch-toggle OR KB+M-hold OR gamepad-hold — the toggle alternative already exists for touch; extend it to all platforms as an explicit accessibility option, not just a touch-specific design choice. |
| Input timing adjustments | Standard | Gather tap-hold (500ms), two-finger ping gesture (150ms window), oxygen grace window | Not Started | PC's `PING_TWO_FINGER_WINDOW=150ms` and the 500ms gather hold are both short enough to be a real motor barrier; provide a timing-multiplier setting (0.5x–3.0x) covering both. |
| Auto-sprint / movement assists | Standard | Movement | Not Started | Evaluate an auto-run toggle alongside the existing sprint-toggle option. |

---

## Cognitive Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Pause anywhere | Basic | All gameplay states | Not Started | Co-op survival design tension: pausing in a multiplayer session cannot pause the whole squad. Document as a Known Intentional Limitation (single-player pause is not meaningful in a 2-4 player co-op run) rather than silently omitting it. |
| Visual indicators for audio-only information | Standard | Predator audio cues, disturbance alert stingers | Not Started | PA's `PREDATOR_AUDIO_RANGE`/eye-shine and HUD's bearing chevron already provide a visual channel for the predator's presence — extend the same principle to any future audio-only warning stinger. |
| Reading time for UI | Standard | Death/respawn captions, beacon-window banners | Not Started | RunController's `RunEnded` banner and PC's death captions must not auto-dismiss faster than 5s or without confirmation. |
| Navigation assists | Standard | World navigation | Not Started | Terranova is a single hand-built map (no procedural generation) — a simple objective/beacon-direction indicator is likely sufficient; full waypoint/fast-travel systems are probably out of scope for a 5–20 minute session game. |

---

## Auditory Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Independent volume controls | Basic | Music / SFX / Voice / UI audio buses | Not Started | Standard Roblox `SoundGroup` volume sliders; no custom audio architecture exists yet (this project's own systems index defers most audio design). |
| Visual representations for directional audio | Standard | Predator proximity/direction | Not Started | Already substantially covered by PA/HUD's bearing chevron + eye-shine design — confirm it satisfies this requirement once implemented, rather than treating it as a separate feature. |

---

## Platform Accessibility API Integration

| Platform | API / Standard | Features Planned | Status | Notes |
|----------|---------------|-----------------|--------|-------|
| Roblox client (all platforms) | Roblox's own built-in accessibility passthrough (client-level, not exposed to experience code) | None planned beyond Roblox's own client features | N/A | Roblox does not currently expose a per-experience accessibility API comparable to Godot's AccessKit or platform-native screen-reader hooks; this project's accessibility commitments are therefore implemented entirely in Terranova's own UI (HUD, menus), not via a platform API integration layer. |
| iOS / Android (Roblox mobile client) | Roblox mobile client accessibility settings | None planned — relies on Roblox client-level text scaling/contrast where available | N/A | Revisit if Roblox ships a documented in-experience accessibility API during this project's live-service lifetime (flagged as a live-platform risk per `docs/engine-reference/roblox/VERSION.md`). |

---

## Per-Feature Accessibility Matrix

| System | Visual Concerns | Motor Concerns | Cognitive Concerns | Auditory Concerns | Addressed | Notes |
|--------|----------------|---------------|-------------------|------------------|-----------|-------|
| Player Controller | Lantern/dark-zone contrast; sprint-state HUD readout | Sprint hold/toggle, gather tap-hold, two-finger ping gesture, HapticService rumble (motor-supported guard already in GDD) | Low — mostly reactive movement | None significant | Partial | Touch-toggle sprint alternative already exists; extend to all platforms; timing multiplier needed for gather/ping. |
| Resource Management | Oxygen state color-coding | None | Tracking squad-wide oxygen state under time pressure | Low health/critical audio stinger (if added) needs a visual equivalent | Partial | Oxygen state already has a numeric readout per RM's GDD; colorblind-safe recheck needed once implemented. |
| Resource Node | Node-tier color-coding, dynamic light flicker (photosensitivity) | Gather-lock proximity (no unusual motor demand) | Low | Node completion audio cue | Not Started | `MAX_NODE_POINTLIGHTS_IN_FRUSTUM` cap + WCAG completion-flash ceiling already named in RN's GDD (H.30/OQ.12) — reuse for this matrix once implemented. |
| Ecological Disturbance | Disturbance meter color/tier, bioluminescence saturation as a gameplay signal | None (pure signal system) | Reading the meter under time pressure is the core design tension (Pillar 1) | Alert stinger audio | Partial | This system's entire fantasy depends on visual+cognitive legibility — highest-priority audit target once implemented. |
| Predator AI | Eye-shine, bearing chevron color intensity | None (no player-controlled predator input) | Reading bearing+distance under stress | Predator audio-range cues | Partial | Chevron/eye-shine already designed as the non-color backup for predator proximity; confirm colorblind-safe in practice. |
| Crafting & Items | Recipe/item icons, beacon-tier color-coding | Bench interaction, placement (no unusual motor demand) | Recipe/inventory tracking | Beacon hold-state audio cue | Not Started | No accessibility pass yet — flag when Crafting's UX spec is authored. |
| HUD | All of the above surfaces render here — see FlashArbiter, colorblind, and reduced-motion rows above | Touch-target sizing (44pt minimum, per HUD's own UI.2/UI.3) | Highest cognitive load in the game — HUD consolidates ~279 cross-GDD obligations | Central point for any audio-visual redundancy | Partial | HUD's own GDD already carries several Standard-tier-equivalent ACs (reduced-motion, WCAG flash) — this document formalizes them as project-wide commitments, not HUD-internal choices. |

---

## Accessibility Test Plan

| Feature | Test Method | Test Cases | Pass Criteria | Responsible | Status |
|---------|------------|------------|--------------|-------------|--------|
| Text contrast ratios | Automated — contrast analyzer on HUD/menu screenshots | All HUD text over both lit and unlit backgrounds | Body text ≥4.5:1, large text ≥3:1 | ui-programmer | Not Started |
| Colorblind modes | Manual — Coblis simulator on HUD screenshots (all color-coded systems) | Disturbance meter, oxygen state, predator chevron, node tiers, beacon tier — in Protanopia/Deuteranopia/Tritanopia | No essential information lost in any mode | ui-programmer | Not Started |
| Input remapping + toggle alternatives | Manual — remap all inputs, enable all toggle alternatives, complete a full run | Sprint, lantern, gather, ping | All actions completable after remapping; toggle modes functional | qa-tester | Not Started |
| Combined-flash ceiling (WCAG 2.3.1) | Automated — `FlashArbiter` unit test with a fake clock (already specced in HUD's own GDD as unit-testable) | Simultaneous disturbance-spike + beacon-window + node-completion flashes | Combined onset rate never exceeds 3/sec regardless of source overlap | gameplay-programmer | Not Started |
| Reduced-motion mode | Manual — enable flag, verify HUD animations | All HUD tweens/interpolations classified load-bearing vs. decorative | Decorative animations replaced with static fallback; load-bearing ones degrade to minimal functional form | ui-programmer | Not Started |

---

## Known Intentional Limitations

| Feature | Tier Required | Why Not Included | Risk / Impact | Mitigation |
|---------|--------------|-----------------|--------------|------------|
| Screen reader support for menus | Comprehensive | Roblox exposes no in-experience accessibility API comparable to Godot/Unity/Unreal platform integrations; no specialist budget | Affects blind/low-vision players entirely | Revisit if Roblox ships a documented accessibility API during this project's live-service lifetime |
| Mono audio option, closed captions for gameplay-critical SFX | Comprehensive | Adaptive Audio was cut for MVP (systems-index); no audio-direction pass exists yet | Affects deaf/hard-of-hearing players relying on audio cues (predator proximity, oxygen critical) | Predator proximity already has a visual channel (bearing chevron/eye-shine) independent of audio; revisit dedicated captions post-MVP |
| Full pause during co-op runs | Basic-adjacent | Pausing one player's screen cannot meaningfully pause a 2-4 player live session; this is a co-op-design constraint, not a scope cut | Players needing a mid-session break must rely on squadmates or accept losing progress | Document clearly in onboarding; consider a "ready check" soft-pause at the lobby/loadout stage only (pre-run, not mid-run) |
| ~~Predator-hue-exclusion contradiction (`#FFD060` oxygen-warning color vs. art bible §4.2)~~ **RESOLVED 2026-07-06** | N/A | Flagged by the Art Director in the 2026-07-06 gate-check; the oxygen-warning color was changed to `#FFF860` (hue ≈57°, clears the ±15° exclusion band by 9°) rather than carving an exception into the reserved-hue rule | No longer a risk — see `design/art/art-bible.md` §4.2/§4.5 for the corrected value | Resolved same-session; `production/gate-checks/technical-setup-to-pre-production-2026-07-06.md` has the original finding |

---

## Audit History

| Date | Auditor | Type | Scope | Findings Summary | Status |
|------|---------|------|-------|-----------------|--------|
| 2026-07-06 | Internal (this authoring pass) | Initial commitment | Tier selection + first-draft feature matrix, no implementation exists yet | Document authored against design intent only; no implementation to audit | In Progress |

---

## External Resources

| Resource | URL | Relevance |
|----------|-----|-----------|
| WCAG 2.1 (Web Content Accessibility Guidelines) | https://www.w3.org/TR/WCAG21/ | Foundational accessibility standard — contrast ratios, text sizing, the 2.3.1 flash-limit rule HUD's GDD already cites |
| Game Accessibility Guidelines | https://gameaccessibilityguidelines.com | Comprehensive game-specific checklist organized by category and cost |
| AbleGamers Player Panel | https://ablegamers.org/player-panel/ | User testing service and consulting with disabled gamers |
| Colour Blindness Simulator (Coblis) | https://www.color-blindness.com/coblis-color-blindness-simulator/ | Free tool for simulating colorblind modes on HUD screenshots |
| Roblox Creator Docs — Accessibility | https://create.roblox.com/docs/ | Check periodically for a future in-experience accessibility API (live-platform risk per `docs/engine-reference/roblox/VERSION.md`) |

---

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Does Roblox plan to ship an in-experience accessibility API (screen reader hooks, OS-level text scaling passthrough) during this project's live-service lifetime? | technical-director | Re-check at each `/architecture-review` | Unresolved |
| Should a real `ux-designer`/accessibility-specialist pass replace this first-draft matrix before Production begins? | producer | Before Production gate-check | Unresolved — recommended |
| ~~Does the `#FFD060` oxygen-warning-color contradiction affect this document's colorblind-mode commitment?~~ | art-director | — | **Resolved 2026-07-06** — color changed to `#FFF860`; no revision to the Color-as-Only-Indicator Audit needed since the audit didn't depend on the specific hex value, only on the non-color backup (numeric readout) already specified |
