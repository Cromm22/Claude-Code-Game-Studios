# Game Concept: Terranova

*Created: 2026-04-21 (original Unity scope) — Rewritten: 2026-04-29 (Roblox pivot, reduced scope) — Round-1 revision: 2026-04-29 (6 blockers resolved) — Round-2 revision: 2026-04-30 (25 blockers resolved across 7 themes: cosmetic-boundary regression, Fellowship pillar mechanics, predator FSM completeness, onboarding pre-death teaching, network/performance substrate, audio pillar coherence, AC independence)*
*Status: Draft (round-2 revisions applied; awaiting round-3 fresh-session re-review)*

---

## Elevator Pitch

> A co-op survival experience on a hostile alien map where you and your friends
> manage oxygen and gather resources to escape — but every action you take disturbs
> the planet's ecology, and an apex predator hunts you along that disturbance.
> The harder you push, the louder you become.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Co-op Survival / Light Crafting |
| **Platform** | Roblox (PC, Mobile, Console — Roblox handles per-platform) |
| **Target Audience** | Roblox survival/horror players (e.g., *Doors*, *Apeirophobia*, *Pressure* fans) plus survival-curious players who want a tighter session than premium survival sims |
| **Player Count** | Co-op 2–4 players per server (multiplayer from day one) |
| **Session Length** | 5–20 minutes per run |
| **Monetization** | F2P + cosmetic-only Robux purchases. Three permitted cosmetic categories: (1) **character skins** (suit/lantern/helmet variants), (2) **emotes** (pre-canned non-text gestures), (3) **lobby/hub decorations** (cross-run persistent profile-space items only — never in-run, per the "NOT base-building" anti-pillar). All purchases are direct (no random-pull / loot-box mechanics — see anti-pillars). All cosmetic items must pass the Cosmetic Boundary Rule (see Anti-Pillars). |
| **Estimated Scope** | 2–4 month MVP, then iterate as a live experience |
| **Comparable Titles (Roblox)** | *Doors*, *Apeirophobia*, *Pressure*, *Survive the Killer* |

---

## Core Fantasy

You are not powerful. You are not the hunter. You and your friends crash-landed on
a planet that already had something living on it — and your survival actions are
waking it up. The fantasy is shared fragility: the squad coordinates whispers and
gestures, takes risks together, and learns the world together. The horror is not
random — *you summoned it.*

---

## Unique Hook

> **The predator hunts you along the ecological disturbances your survival actions
> create.** Gather faster, build louder, light brighter — and you become easier to
> find. The only way to stay alive is to play quietly.

This is the entire differentiator. Every feature in the game serves it or is cut.

---

## Visual Identity Anchor

The Roblox-adapted visual identity is formalized in [`design/art/art-bible.md`](../art/art-bible.md).
Concept-level summary:

- **Stylized Roblox aesthetic**, not photoreal — leans into the platform's voxel/blocky strengths rather than fighting them
- **Strong contrast** between safe-light areas and unknown-dark areas
- **Scale contrast** — the predator silhouette dwarfs the player at first sighting
- **Bioluminescence** as a primary lighting source — alien color punching through earth tones
- **One-line visual rule**: *"The player should always know where safety ends."*

The previous Unity-era art bible is archived at `design/archive/unity-scope/art/art-bible.md`
for reference. Roblox-appropriate principles were re-derived rather than literally translated.

---

## Player Experience (MDA Highlights)

### Target Aesthetics — top 3

1. **Fellowship** (shared risk) — Co-op is core, not optional. The squad is the experience. This is the primary aesthetic per Pillar 2; Challenge is *how* Fellowship is experienced.
2. **Challenge** (mastery, learnable threat) — Predator behavior is readable; quiet players survive longer
3. **Sensation** (audio-driven dread) — Audio teaches the world; the predator is heard before seen. The predator's audio range exceeds its visual detection range — this is a binding design constraint on Predator AI perception tuning. **Minimal adaptive audio is in MVP scope**: a single ambient stem crossfade tied to disturbance tier (Calm → Tense → Hunt) plus per-state predator audio cues. Full adaptive scoring (multi-stem, intensity-driven mix, layered stingers) remains a v2 enhancement. Predator sonic identity is **biological/organic** (breathing + footstep cadence + low subsonic presence; non-vocalising) — refined in the Audio Direction document.

### Core Mechanics (the 7 MVP systems)

1. **Player Controller** — first-person movement, stamina, sprint cost
2. **Resource Management (oxygen-only for MVP)** — single resource tick. Food/water deferred to v2
3. **Resource Node** — gather points scattered around the map; gathering creates disturbance
4. **Ecological Disturbance** — the differentiator. Two layers in one GDD:
   - **Signal contract** (infrastructure): event schema, payload fields (position + magnitude + type), aggregation rule (**spatial-radius-merged** — see MVP Definition), update frequency, server/client authority
   - **Gameplay design**: what triggers a signal, decay curve, threshold semantics, player-legibility cues
   These two layers must be specified separately so Predator AI and HUD GDDs consume a stable contract while gameplay tuning iterates independently.
5. **Predator AI** — at GDD time, must split into Perception / Decision / Navigation submodules (data-driven so post-launch predator variants are cheap). State machine: patrol → investigate disturbance → hunt → retreat. Target selection rule, retreat trigger, and readability telegraphs (warning cue → state change → minimum state duration) are all required in the AI GDD, not deferred.
6. **Crafting & Items** — consolidated: item schema + inventory + recipes. Small recipe tree (~6–10 items) for MVP. Win-condition recipe (Escape Beacon) is a named section within this GDD with its own interface contract.
7. **HUD** — minimal: oxygen meter, **squad disturbance meter** (collective level), **zone-attributed spike alerts** (when ANY player crosses a threshold, the offending player receives a private personal alert AND all squad members see a zone-direction alert with NO player name attached — preserves coordination signal without inviting blame; supports Pillar 2), **respawn affordance** for spectating dead teammates (see in-run respawn rule in MVP Definition), simple inventory, and the **squad coordination affordances** below. Spike-alert flash rate is coalesced (max 1 zone-alert per 2 seconds globally; max 1 personal alert per 2 seconds per player) to defend against simultaneous 4-player threshold crosses violating WCAG 2.3.1 photosensitive thresholds.

---

## Core Loop

### Moment-to-Moment (30 seconds)

Move quietly through the map. Listen. Decide whether the next gather node is worth
the disturbance it creates. Watch teammates' lights — they advertise too.

### Run-Level (5–20 minutes)

A full session: spawn → gather oxygen and crafting materials → build minimal
shelter or upgrade gear → either escape (win) or be killed by the predator (lose).
Each run is a discrete session — Roblox-native rhythm, not a long-haul save game.

### Long-Term Engagement

- Cosmetic unlocks via play (and Robux purchase)
- Map variants and predator variants in post-launch updates
- Leaderboards for fastest escape / longest survival
- Daily challenges (e.g., "Survive 10 minutes with no crafting") to refresh the loop

---

## Game Pillars

1. **Quiet Is Power** — Stealth and restraint are mechanically rewarded. Loud play accelerates the predator.
2. **The Squad Is the Experience** — Multiplayer is core. Communication, role-splitting, and shared risk define the fantasy.
3. **The World Watches** — Every player action has an ecological consequence. Nothing is consequence-free.
4. **Rounds, Not Saves** — Each run is a complete experience. Roblox-native: drop in, play, leave.

### Anti-Pillars

- **NOT a single-player game** — co-op is the design center
- **NOT pay-to-win** — Robux purchases are cosmetic only.
  **Cosmetic Boundary Rule (principle + explicit list)**:
  An item qualifies as cosmetic ONLY IF it satisfies BOTH clauses:
  - **Clause 1 (predator-AI side)**: The item changes no input the predator AI consumes — including but not limited to: in-world audio emission (footstep volume, sound radius, additional sound-emitting accessories), light emission (lantern brightness, glow accessories, light radius), motion signature (movement speed, stamina drain rate that indirectly modifies sprint cadence), spatial signature (hitbox shape, model bounding volume, visual silhouette mass).
  - **Clause 2 (player-information side)**: The item changes no input the player reads to make survival decisions — including but not limited to: visual disturbance state legibility (no skins that obscure or alter the disturbance overlay), audio cue prominence (no audio swap that masks predator audio cues), oxygen meter readability, recipe/material/waypoint reveal (no skins that surface map intel), interaction range or feedback (no extended reach), HUD element visibility.
  - **Explicit rulings on Roblox-native cosmetic categories**:
    - Trail particles: PERMITTED only if no audio emission, no extended visual silhouette beyond the player's normal model, no measurable change to predator-visible footprint
    - Aura/glow accessories: FORBIDDEN if they emit ambient light (would change Light-emission cadence per Disturbance GDD); PERMITTED only as non-emissive visual flair
    - Audio emotes: emote audio is socially visible but mechanically silent — emotes generate ZERO disturbance and use fixed UI-only sound channels (never positional 3D audio that the predator AI could consume)
    - Footstep skins: PERMITTED only if footstep audio assets pass the Clause 1 audio-emission test (volume, sound radius equivalent to baseline)
    - Lantern brightness skins: FORBIDDEN — lantern brightness affects Light-emission cadence
    - UI sound cosmetics: PERMITTED only if they cannot be confused with gameplay-critical audio (no cosmetics that mimic predator audio or spike-alert tones)
  - **Enforcement**: Every cosmetic item requires a sign-off record naming the reviewer (game-designer + QA-lead), the date, and pass/fail per clause. Stored in `production/qa/evidence/cosmetic-review-[launch-version].md`. An automated TestEZ test asserts mechanical-equivalence (predator detection unchanged, oxygen rate unchanged, movement speed unchanged, disturbance generation unchanged, crafting speed unchanged) per equipped cosmetic vs. baseline.
- **NOT a long-haul save game** — sessions are bounded; **no in-run save**. Cross-run cosmetic and meta-progression persistence is allowed (and intentional — see Long-Term Engagement). The "Rounds, Not Saves" pillar means *no in-run save*, not *no persistence*.
- **NOT a difficulty slider game** — the predator's behavior cannot be tuned down; quiet play is the only "easy mode"
- **NOT procedural** — single hand-built map only at launch; map variants come post-launch as hand-authored content
- **NOT base-building** — no persistent structures within a run (separate from the v2 base-building cut)
- **NOT PvP** — players cannot harm each other; the predator is the only threat
- **NOT multi-predator at launch** — exactly one predator INSTANCE per server at launch (one variant, one instance — multiple instances of the same variant would equally harm readability and are equally excluded). Variants are post-launch only.
- **NOT random-pull / loot-box monetization** — all Robux purchases are direct (player selects the specific item before paying). No randomized cosmetic packs, lucky-draw mechanics, or paid gacha. Compliance commitment for the 13–25 audience including minors. Roblox Marketplace Policy alignment.

---

## Inspiration and References

| Reference | What We Take | What We Do Differently |
| ---- | ---- | ---- |
| *Doors* (Roblox) | Audio-driven dread, room-by-room tension, simple controls | Open map (not corridor); ecological/disturbance system replaces scripted scares |
| *Apeirophobia* (Roblox) | Co-op fragility, atmosphere over mechanics complexity | Survival/gather loop replaces walking-sim pacing |
| *Subnautica* (off-platform) | Single-intelligent-predator design philosophy | Heavily simplified for Roblox session length and platform fidelity |
| *Alien: Isolation* (off-platform) | Audio cues > direct sighting, predator as puzzle | Emergent ecological logic instead of scripted patrol routes |

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Primary**: Roblox survival/horror player | 13–25, plays in 15-min bursts, plays with friends, expects co-op |
| **Secondary**: Roblox-curious survival fan | Adult player who plays Subnautica/Valheim, drops into Roblox occasionally |
| **What they want** | Tight session, shared scary moments, learnable threat, no pay-to-win |
| **What turns them away** | Long onboarding, single-player only, hand-holding tutorials, paywalled gameplay |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Engine** | Roblox Studio (live platform). See `docs/engine-reference/roblox/VERSION.md`. |
| **Language** | Luau (`--!strict` for new scripts) |
| **Architecture** | Knit framework (Services + Controllers) |
| **Sync** | Rojo (file-based git ↔ Studio) |
| **Networking** | Roblox built-in, server-authoritative. All gameplay state validated server-side. |
| **Save** | DataStoreService via ProfileStore (cosmetic unlocks + meta-progression only — no per-run save) |
| **Audio** | Roblox built-in audio with positional sources. **Minimal adaptive audio in MVP**: single ambient stem crossfade tied to disturbance tier (Calm → Tense → Hunt) + per-state predator audio cues + gather-audio that scales with disturbance contribution (volume / pitch swell on high-contribution gathers). Implemented via `SoundService` volume groups + `TweenService`. Audio-priority hierarchy: predator audio + spike alerts (highest), gather/sprint audio (mid), ambient/music (lowest, ducked during Hunt state). Predator sonic identity: biological/organic, breathing + footsteps, non-vocalising. Full adaptive scoring (multi-stem layered mix, intensity-driven stingers) deferred to v2. Rough MVP audio asset count: ~60–80 clips (see Audio Direction document when authored). |
| **Map** | Single hand-built map for MVP (not procedural). Streamlined for Roblox StreamingEnabled. |
| **MCP** | `Roblox_Studio` stdio MCP server registered for AI-assisted Studio workflows |

---

## Risks and Open Questions

### Design Risks

- **Disturbance legibility** — if players can't read what creates disturbance and what doesn't, the loop feels random. Highest risk to validate via prototype. The Disturbance GDD must specify the legibility cue (numeric, color-state, or hybrid) with concrete update-frequency thresholds.
- **Co-op coordination without voice** — Roblox players (especially mobile) may not communicate. Mitigated by **four committed coordination affordances** in the MVP HUD/UI:
  1. **Squad disturbance meter** — every player sees the squad's collective disturbance level
  2. **Auto-broadcast spike alerts** — when any individual player crosses a disturbance threshold, the whole squad's HUD flashes
  3. **Quick-ping system** — tap a location/object/threat to ping it for the squad
  4. **Emote wheel** — pre-canned non-text gestures (e.g., "quiet", "follow me", "danger"); works on touch with no moderation surface
  All four work on touch, mouse, and gamepad. Voice chat is **not** a design assumption.
- **Onboarding paradox** — "quiet beats loud" is counter-intuitive and the audience rejects tutorials. Mitigated by **two layered teaching surfaces** (death-state alone fails Roblox's first-60-second mobile retention window):
  1. **Pre-first-death in-world cue** — the FIRST time the squad's collective disturbance crosses the Tense threshold (per Disturbance GDD's `TENSE_THRESHOLD = 0.30`), an ambient diegetic cue plays once: a low atmospheric shift + a single visual pulse of nearby flora reacting (per Disturbance GDD's flora overlay). No text, no tutorial — atmospheric framing communicates "the world is reacting." Fires only on first cross per session per squad. This is the pre-death teaching layer.
  2. **Death-state feedback** — when a player dies, the death screen surfaces the dominant disturbance signal that led the predator to them, formatted as plain language: "[Disturbance type: Sprint / Gather / Light / Beacon] at [time] before death made you loud enough for the predator to find you." NOT internal IDs — player-facing language only. This is the post-death teaching layer.

  Both layers are required. Death-state alone fired too late for Roblox mobile retention; the pre-death cue establishes "the world watches" before the player can fail. Specified in the HUD GDD and Predator AI GDD; pre-death cue specified in the Disturbance GDD's first-pulse semantics.
- **Session pacing** — 5–20 min is a tight window for a full survival arc. The Predator AI GDD must define the escalation curve, **aligned with the Ecological Disturbance GDD's tier thresholds as the source of truth** (Calm < 0.30, Tense 0.30–0.649, Hunt 0.65–0.999, Retreat-tier 1.00 — clamped, with hysteresis ±0.03 on every boundary).
  - **Predator state machine** (4 states, names disambiguated from Disturbance tier names): **Patrol → Investigate → Hunt → Disengage**. (The Disturbance tier "Retreat" at t=1.00 means *the squad must retreat*; the predator state "Disengage" was renamed from "Retreat" in this revision to eliminate the naming collision identified in round-2 review.)
  - **Patrol → Investigate**: triggered when a hotspot's field value crosses Tense (0.30) per the Disturbance GDD's `TierCrossedEvent`.
  - **Investigate → Hunt**: triggered when the hotspot field value crosses Hunt (0.65). **Minimum dwell time in Investigate before Hunt is eligible: 8 seconds** (concept-level shape constraint — prevents single-action instant-Hunt transitions; gives players a window to de-escalate).
  - **Hunt → Disengage**: triggered when the squad-aggregate disturbance (`squadT` per Disturbance GDD's `GetSquadAggregateT()`) drops below 0.30 sustained for **at least 20 seconds** (concept-level shape constraint — minimum acceptable sustained-quiet range is 20–60 seconds; prevents the AI GDD from setting a trivial 5s timeout that would break Pillar 1 "Quiet Is Power").
  - **Hunt timeout (Hunt → Patrol)**: when the predator pathfinds to a hotspot that has fully decayed before arrival and `GetHottestHotspot()` returns nil for 15 seconds, the predator transitions back to Patrol. This preserves the 4-state count (Disengage handles drop-below-threshold; Hunt-timeout handles target-vanishes); no fifth "Searching" state is needed.
  - **Tied-hotspot tie-break principle**: highest field value wins; ties broken by predator's current proximity (closest hotspot wins). No randomness — readability requires deterministic targeting.
  - **State-transition telegraphs (line 85's "warning cue → state change → minimum state duration")** are GLOBALLY broadcast to all connected players (not scoped to the triggering player's client) — all squad members must perceive predator state changes to coordinate.
  - **Predator instance count**: exactly 1 instance per server (anti-pillar above).
  - **Predator spawn**: predator exists from session start in Patrol state (it does not "spawn on threshold" — the world is already watching).

  Curve thresholds are tuning knobs (per Disturbance GDD safe ranges); the *shape* (4 states, named transitions, dwell-time floors) is a concept-level commitment.
- **Touch input mis-tap risk** — accidental gather taps create unintended disturbance and undermine the core mechanic on the primary platform (mobile). The Player Controller / Resource Node GDDs must specify a confirmation pattern: **tap-hold or proximity gate** ("confirm prompt" was disqualified at concept tier — modal prompts on a primary action are anti-pattern for the Roblox audience). Quick-ping (line 180) uses a **two-finger tap** on touch — distinct from the single-tap-hold gather gesture, eliminating gesture conflict.
- **Accessibility** — audio-driven dread excludes deaf/hard-of-hearing players; the "where safety ends" visual rule is colorblind-hostile by default. **Concept-level commitments (the floor the audit must verify)**:
  - All audio cues have visual redundancy
  - All color cues have shape/icon redundancy
  - **Spatial audio cues have directional visual equivalents** (predator audio direction → edge-screen indicator or compass arc — visual redundancy alone is insufficient for spatial info)
  - **Photosensitive flash policy**: no full-screen flashes; spike alerts use screen-edge vignette pulse (0.8–1.2s, 1 cycle); spike-alert coalescing rule above defends WCAG 2.3.1 (no more than 3 flashes/sec under any squad-size or threshold-cross pattern)
  - **Motion-reduction toggle** (player-side setting): disables vignette pulse, flora animation, lantern flicker; substitutes with static visual indicators
  - **Minimum touch target size**: 44×44pt (Apple HIG)
  - **Minimum font size**: legible at iPhone SE-class screen distance (specific value in `design/ux/accessibility-requirements.md`)
  - **No hover-only interactions** (CLAUDE.md / technical-preferences.md hard rule — surfaced here for HUD GDD inheritance)
  - **Captions for predator audio** — non-voice predator vocalisations (breathing, footsteps) are conveyed via visual indicators when "captions" mode is enabled
  - **Emote wheel alternative input path**: D-pad sequential navigation as fallback to hold-trigger + analog stick (single-input-mode accessibility)
  - **Colorblind palette**: art bible's color choices verified against deuteranopia / protanopia / tritanopia simulations; safe-zone vs. unsafe-zone identification cannot rely on hue alone

  Detailed audit standard, sign-off authority, and per-element checklist in `design/ux/accessibility-requirements.md` (to be authored). Audit standard: WCAG 2.1 AA where applicable; Roblox accessibility guidelines where WCAG does not apply; project-specific rules above. Sign-off authority: ux-designer + qa-lead at gold-master gate.

### Technical Risks

- **Predator AI on Roblox** — server-authoritative AI with LOS, pathfinding, and dynamic behavior on Roblox's PathfindingService. `PathfindingService:FindPathAsync()` is async-yielding and recompute-expensive; the Predator AI GDD must include a server tick budget breakdown:
  - **Recompute throttle**: minimum 0.5s between `FindPathAsync` calls regardless of target-delta gate; maximum 1 concurrent task in flight (discard previous task before issuing new call)
  - **Perception raycast cadence**: maximum 16 rays per check at 4 Hz (≤64 rays/sec/predator)
  - **RemoteEvent broadcast count**: predator state replicates **always to all clients** at MVP (no relevancy gating — eliminates timing-leak exploit; bandwidth is acceptable at 1 predator × ≤4 Hz state push to ≤4 clients)
  Needs prototyping early via `/prototype predator-ai` — this is the highest-risk system.
- **Disturbance simulation cost** — propagating signals across the map server-side without bandwidth blowup. Signal bus design matters. The Disturbance GDD defines event throttle, aggregation window, and per-client delta-broadcast policy to defend the 50 KB/s bandwidth budget under 4-player gather-spam. Authoritativeness: **disturbance signals are server-internal** — `DisturbanceService:Emit()` is server-only; no RemoteEvent, RemoteFunction, BindableEvent, or `*.Client` method may trigger or proxy emission. Clients signal *intent* (e.g., gather request); server validates and emits as a consequence. Emission aggregation: spatial-radius-merged at the read layer (`GetHottestHotspot` returns a single peak position) but additive at the source layer (each emission contributes independently per the Disturbance GDD's `INFLUENCE_RADIUS` falloff) — these are not contradictory; the GDD is authoritative on the math.
- **RemoteEvent trust boundary** — every RemoteEvent is an exploit surface. The architecture phase must produce an ADR enumerating: which events are client-initiated vs. server-pushed, what server-side validation each requires, and what rate-limit applies. **Concept-level enumeration of known surfaces** (the ADR may add more but must cover at minimum):
  1. Gather request (client → server; server validates physical proximity, rate limit, emits disturbance internally)
  2. Craft request (client → server; server validates inventory + recipe + range; emits disturbance internally)
  3. Beacon activation (client → server; server validates inventory + once-per-run; emits Beacon disturbance internally)
  4. Ping (client → server → broadcast; rate limit ≥1s/player; ≥1.5s burst-cap)
  5. Emote (client → server → broadcast; rate limit ≥3s/player; ≥5-emote burst cap; emotes generate ZERO disturbance — server-validated)
  6. Cosmetic purchase (Roblox `MarketplaceService:ProcessReceipt` callback — see below)
  7. Respawn / character-ready handshake (client → server; rate-limited; server is authoritative on spawn state)
  8. Squad join/leave (server-pushed only; no client-initiated squad-membership change)
  9. AFK kick signal (server → client only; no client keepalive that could suppress detection)
  10. Death confirmation (server-pushed only; client cannot fire its own death)
  11. Disturbance overlay / flora chunk subscription (server-pushed on chunk stream-in only — no client-callable subscription path per ED GDD C.3.5)
  - **Server validation principle (stronger than "validated server-side")**: server validates not just action legality but action *plausibility* given server-tracked state — e.g., gather requests verify the player is within range of the named node on the server, not trusting the client's `nodeId`.
  - **Per-event rate limits + per-player global RemoteEvent budget** must both apply (not just per-event — a misbehaving client can spam multiple low-rate-limited events to bypass per-event caps).
  No RemoteEvent ships without server validation.
- **Cosmetic purchase write path** — DataStore rate limits (60 req/min/server, 6/player) apply when 4-player squads purchase simultaneously. Architecture specifies: **`MarketplaceService:ProcessReceipt` callback** is the grant gate. The callback must store a per-receipt-id idempotency key in ProfileStore *before* returning `Enum.ProductPurchaseDecision.PurchaseGranted`. If the server crashes between DataStore write and `PurchaseGranted` return, Roblox retries the callback on next login — game must detect "already granted" via the idempotency key. **The "no charge without grant" semantic is a hard requirement**: Robux must not be deducted unless the cosmetic is durably granted. Player-facing failure state: visible "purchase failed — Robux not deducted" toast on any non-grant outcome; persistent failure ledger in `production/qa/evidence/purchase-failures.md` for support triage. **Cosmetic preview pane**: every Robux purchase shows a full-rotation preview on the player's character model before confirmation — MVP requirement.
- **Cross-platform tick interpolation** — mobile renders at 30fps while server runs 60Hz Heartbeat. Disturbance overlay, predator position, and oxygen meter must interpolate cleanly. **Client prediction scope is restricted to movement and visual feedback only** — gather outcomes, craft outcomes, disturbance signal generation, oxygen delta, and beacon activation are **server-confirmed only** (NOT predicted client-side). Predicting gameplay-consequential state would contradict server authority (line 164) and create exploit surfaces. HUD disturbance-meter latency chain (server tick → 5 Hz push → 0.25s tween at 30fps client = up to 600ms) is acceptable for the squad meter (it's a state indicator, not an input-responsive control); the offending player's *personal* spike alert may use a 1-frame client-side optimistic flash on local action that is reconciled with the next server push.

- **Roblox character replication baseline** — Roblox's built-in character replication (Humanoid, RootPart, motor joints, animations) is the largest bandwidth consumer in most Roblox games and consumes ~5–10 KB/s per remote player. With 3 remote players visible to a client, this baseline alone is 15–30 KB/s — 30–60% of the 50 KB/s/client budget — *before* any game-specific code runs. Architecture phase must profile this and investigate `NetworkOwnershipAuto` vs explicit `SetNetworkOwner(nil)`, animation replication suppression for non-essential motion, and selective replication of remote-player accessories. This is a primary budget consumer, not a marginal cost.

- **Mobile thermal budget** — sustained 5–20 min runs on iPhone SE-class devices induce thermal throttling that caps Roblox at ~25–28fps under load. The 30fps mobile baseline is aspirational; the architecture must specify a **graceful-degradation mode** (reduced flora animation, lower-res shadows, disabled motion blur) that activates when the client detects sustained frame-time above 40ms p95.

### Market Risks

- **Roblox survival/horror is crowded** — must launch with a clear, communicable hook in the thumbnail/title to cut through.

### Open Questions

- **Cosmetic shop strategy** — at-launch shop scope vs. drip-feed cadence vs. limited/rotating cosmetics for whale loop. Defer specifics to post-prototype playtest data, but a planning assumption (e.g., 2–4 new cosmetics per month post-launch) must be stated before launch budget is locked.
- **Crafting tree purpose** — 4–8 of the 6–10 craftable items have no defined function beyond the win-condition pair. Are they survival aids, disturbance reducers, or distractors? **Resolution required in the Crafting & Items GDD** (must respect the cosmetic boundary rule — disturbance reducers are gameplay, not cosmetic).
- **Cosmetic earn-rate curve** — play-time-to-cosmetic unlock pacing. Defer to playtest data, but bad-luck protection (guaranteed unlock every N runs) is a launch requirement.

### Resolved at Concept (was previously open)

- **Win condition** → **Escape Beacon (craft + activate + survive the window)**. The squad gathers materials, crafts a beacon item, activates it, and survives a short post-activation **survival window** (~49 s, derived from the beacon's Hunt-floor lure interval) during which the predator commits to the beacon at peak threat. Victory fires at window-end if ≥1 squad member is alive; a full-squad wipe during the window is defeat. No alternative route to victory in MVP. *(Updated 2026-06-01 to the survival-window model — the Crafting & Items round-2 redesign; activation alone no longer wins, which is what makes the aid items load-bearing. See `design/gdd/crafting-and-items.md` C.5.6a.)*
- **Voice chat** → **Designed for non-voice.** Coordination affordances (squad meter, spike alerts, ping, emote wheel) are the universal floor. Voice chat is permitted but never assumed.
- **MDA aesthetic ordering** → Fellowship #1, Challenge #2, Sensation #3 (aligns with Pillar 2).
- **Co-op disturbance aggregation** → **Spatial-radius merged at the read layer; additive at the source layer.** Disturbance is a spatial field, not a global scalar; nearby players' contributions sum within the `INFLUENCE_RADIUS` falloff (per Disturbance GDD), and `GetHottestHotspot` returns the single peak position. The predator targets the hottest hotspot. A spread squad creates multiple smaller hotspots; a clustered squad creates one large one. Locks the data model for the Disturbance signal contract.
- **Cosmetic boundary rule** → see Anti-Pillars (principle + explicit list per round-2 revision).
- **Spike alert framing** → **Zone-attributed only; no per-player names broadcast.** Offending player gets a private personal alert; squad sees zone-direction with no name. Coalesced (≤1 zone-alert per 2 sec; ≤1 personal alert per 2 sec/player). Resolves Pillar 2 / Fellowship-blame tension surfaced in round-2 review.
- **In-run respawn rule** → **Mid-run respawn at squad cost.** When a player dies and ≥1 squad member is still alive, the dead player respawns at the spawn zone after a 30-second delay; the revive costs the squad one shared oxygen pool unit (or equivalent material — exact cost in Resource Management GDD). Dead-while-respawning player can spectate, ping, and emote (no movement or gather). If the entire squad dies, the run ends. Resolves Pillar 2 dead-player-isolation surfaced in round-2 review.
- **Predator state names** → **Patrol, Investigate, Hunt, Disengage** (renamed from "Retreat" to eliminate naming collision with the Disturbance tier "Retreat" at t=1.00).
- **Predator instance count** → **exactly 1 per server at launch** (per anti-pillar — variants and additional instances are post-launch).
- **Predator escalation curve** → **aligned with Disturbance GDD tier thresholds as canonical** (Calm < 0.30, Tense 0.30–0.649, Hunt 0.65–0.999, Retreat-tier 1.00; ±0.03 hysteresis on every boundary). Concept-level shape commitments: Investigate min-dwell 8s; Disengage requires sustained `squadT < 0.30` for ≥20s; Hunt-timeout to Patrol on nil hotspot for ≥15s. Tied-hotspot tie-break: highest field value, ties by predator proximity (deterministic).
- **Disturbance signal authoritativeness** → **server-internal only.** No client-callable emission path.
- **Disconnect mid-run** → **disconnected player's emissions decay naturally** (no server-side "snap-lower" cleanup). Prevents strategic-disconnect exploit. Per Disturbance GDD E.4.
- **Cosmetic monetization mechanic** → **direct-purchase only; no random-pull / loot-box / gacha.**
- **Audio adaptive scope** → **minimal adaptive in MVP** (single ambient stem crossfade tied to Disturbance tier + per-state predator audio + gather audio scales with disturbance contribution). Full adaptive scoring v2.

---

## MVP Definition

### Core Hypothesis (testable)

A Roblox co-op squad finds the ecological-disturbance-driven predator loop
engaging and re-playable in 5–20 minute sessions, measured by the following
**measurable proxies**. **Aggregation rule: ALL FOUR proxies must pass for the MVP hypothesis to be confirmed.** A single-proxy failure halts the launch recommendation pending redesign of the relevant system.

**Test population**: ≥ 75 sessions (sample size raised from 20 to bring the binomial CI on an 80% target to ≤ ±9pp at 95% confidence). Sessions run as ≥ 4 simultaneous 4-player server instances per batch, ≥ 5 batches; each batch uses a fresh server instance. Maximum 5 of 75 sessions may use development-team members (calibration only); the remainder must be naive players with no prior exposure to Terranova.

| Proxy | Target | Measurement Method | Event Definition |
|-------|--------|--------------------|------------------|
| **Predator-encounter rate** | ≥ 1 encounter per run in ≥ 80% of sessions | Analytics event `PredatorEncountered` per `RunStarted` | `PredatorEncountered` fires server-side when the predator transitions into Hunt state with a specific player as the locked target. Engine-observable (not perception-subjective); fires once per Hunt-lock per session per player. |
| **Second-run rate (re-playability)** | ≥ 40% of naive test accounts start a second run within the same session | Count of `RunStarted` events grouped by `sessionId` | `sessionId` = server-session-scoped window with 60-minute idle cutoff. Rejoins to a different server count as a new session. Naive accounts only (excludes calibration runs). |
| **Session-length distribution** | ≥ 70% of *legitimate-exit* runs land in 5–20 min window | Distribution of `(RunEnded.timestamp − RunStarted.timestamp)` filtered to `RunEnded.exitReason ∈ {Escaped, PredatorKill}` only | `RunEnded.exitReason` enum: `{Escaped, PredatorKill, Disconnect, AFK, Timeout}`. Disconnect/AFK/Timeout exits tracked separately and excluded from this proxy. Runs >20 min and <5 min are both failures (track tail distribution as a secondary metric to distinguish "too easy" vs "too hard"). |
| **Disturbance-to-death traceability** | ≥ 95% of `PredatorKill`-exit deaths fire a legible-cause death screen | Two gates: (4a) **Design gate** (one-time): UX-designer + QA-lead sign-off that death-screen design names the dominant disturbance type (Gather/Light/Sprint/Beacon) AND approximate time before death AND uses player-facing plain language. (4b) **Runtime gate** (automated): TestEZ unit test asserts `DeathStatePayload` fields (`disturbanceType`, `disturbanceMagnitude`, `secondsBeforeDeath`) are non-null and within valid ranges in 100% of test-harness deaths. | "Legible cause" = the death screen displays a player-facing string of the form: "[Disturbance type] at ~[N] seconds before death made you loud enough for the predator to find you." NOT internal system IDs. |

The "communicable in 30-sec thumbnail" criterion is **owned by the marketing/positioning milestone**, not the gameplay MVP gate. Test method (when run): comprehension survey — ≥ 4/5 respondents identify the predator-disturbance hook unprompted from a 3-choice prompt. (Method specified here for cross-reference; scheduling/execution owned by marketing milestone, not QA.)

**Bug severity gate at launch**: zero open S1 bugs (crash/blocker), zero unmitigated S2 bugs (S2 may be mitigated with documented workarounds approved by producer + QA-lead).

### Required for MVP

1. Co-op for 2–4 players (multiplayer from day one). Integration test required: 4 simultaneous clients, server-authoritative oxygen tick, **no desync = client-displayed oxygen value matches server-authoritative oxygen value within ±0.5 units at every server heartbeat boundary, measured across a 60-second continuous gather session**. Test runs in TestEZ + Lemur headless harness.
2. Single hand-built map.
3. Oxygen-only resource pressure (single-resource economy with known flat-tension consequence — accepted as a deliberate scope constraint).
4. Ecological disturbance system: spatial-radius-merged signals, 3 trigger types (gathering, lighting, sprinting), with numeric thresholds defined in the Disturbance GDD.
5. Predator AI: 4-state machine (Patrol → Investigate → Hunt → Retreat) with split Perception/Decision/Navigation submodules, defined target-selection rule for 2–4 players, defined retreat trigger, and readability telegraphs per state. Data-driven parameters so post-launch variants are cheap.
6. Crafting & Items: 6–10 craftable items including the **Escape Beacon** (the win-condition item) plus survival/coordination aids whose function is defined in the Crafting & Items GDD.
7. HUD: oxygen meter, squad disturbance meter, per-player spike alerts, inventory, ping system, emote wheel. Designed for touch + mouse + gamepad parity. Tested on iPhone SE-class device.
8. **Win condition: craft the Escape Beacon, activate it, and HOLD it through the ~49 s survival window.** Activation opens the window (it does not win instantly); the session ends in **victory** if ≥1 squad member is alive **AND within ~30 studs (`BEACON_HOLD_RADIUS`) of the beacon** at window-end, or in **defeat** on a full-squad wipe *or* a scatter (members alive but all fled the hold radius) before/at window-end. No alternative route. *(Updated 2026-06-01: survival-window model per the Crafting & Items round-2 redesign, then proximity-hold per the round-3 B1 ruling — see `design/gdd/crafting-and-items.md` C.5.6a.)*
9. Cosmetic shop: 5–10 launch items. Each item passes the **Cosmetic Boundary Rule** (principle + explicit list — see Anti-Pillars). Item-by-item review with documented sign-off (game-designer + QA-lead) per item, stored in `production/qa/evidence/cosmetic-review-[launch-version].md`. Automated TestEZ regression test asserts mechanical-equivalence per equipped cosmetic vs. baseline. Cosmetic preview pane (full-rotation character-model preview) required before any Robux purchase confirmation.
10. **Two-layer onboarding teaching**:
    - **Pre-first-death cue** — first time the squad's collective disturbance crosses Tense (0.30) per session, a one-time ambient atmospheric shift + flora overlay pulse fires (no text, no tutorial). Specified in the Disturbance GDD's first-pulse semantics.
    - **Death-state feedback** — when a player dies, the death screen displays the dominant disturbance signal in player-facing plain language: "[Disturbance type] at ~[N] seconds before death made you loud enough for the predator to find you." Backed by automated test (Proxy 4b above).
11. **In-run respawn at squad cost**: dead player respawns at spawn zone after 30s delay, costing the squad one shared oxygen pool unit (or equivalent — exact cost in Resource Management GDD). Dead-while-respawning player can spectate, ping, and emote. If entire squad dies, run ends.
12. Touch input safety: every disturbance-creating action has a confirm pattern (**tap-hold or proximity gate** — confirm-prompt disqualified at concept tier) on touch. Quick-ping uses two-finger tap to avoid gather-gesture conflict.
13. **Accessibility floor** (concept-level commitments — full audit in `design/ux/accessibility-requirements.md`): audio cue → visual redundancy; color cue → shape/icon redundancy; spatial audio → directional visual indicator; photosensitive flash compliance (WCAG 2.3.1) via screen-edge vignette + alert coalescing; motion-reduction toggle; minimum 44×44pt touch targets; no hover-only interactions; emote wheel D-pad fallback for accessibility controllers; colorblind-verified palette. Audit standard: WCAG 2.1 AA where applicable + project-specific rules. Sign-off: ux-designer + qa-lead at gold-master gate.
14. **No in-run save (testable)**: scripted forced-disconnect-and-reconnect test. Verify reconnected player's run state is reset to initial spawn; no in-run progress is recoverable. Smoke check before launch.

**Explicitly NOT in MVP**:
- Food/water resources (oxygen-only for now)
- Base building (no persistent structures within a run)
- Multiple maps (single map at launch; variants post-launch)
- Multiple predator variants (one predator at launch)
- Scanner / radar tools (defer)
- Procedural generation (hand-built map only)
- Voice chat integration (design for text/emote)
- Random-pull / loot-box / gacha cosmetic mechanics (anti-pillar)
- Full adaptive audio scoring (minimal adaptive — single ambient stem crossfade — IS in MVP per Audio row above; full multi-stem layered scoring is v2)
- Predator instance count >1 per server (one instance, one variant — anti-pillar)
- Cosmetic gifting between players (architectural surface; defer until v2 with explicit gift atomic-write design)

### Scope Tiers

| Tier | Content | Features | Target Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | 1 map, 1 predator, ~8 items, 1 win condition | The 7 core systems above + cosmetic shop | 2–4 months |
| **Post-launch v1** | + 1 map variant, + 1 predator variant, + meta-progression | Refined predator AI, expanded cosmetics, daily challenges | +2 months |
| **Live ops** | Seasonal events, new maps, new predator variants, gameplay-tuning patches | Continuous | Indefinite |

---

## Next Steps

- [ ] `/design-review design/gdd/game-concept.md` — validate this rewrite
- [ ] `/art-bible` — re-derive visual identity for Roblox aesthetic (replaces archived Unity art bible)
- [ ] `/map-systems` — confirm the 7-system decomposition (already drafted in systems-index.md)
- [ ] `/design-system [each MVP system]` — author per-system GDDs in dependency order
- [ ] `/review-all-gdds` — cross-system consistency check after MVP GDDs are drafted
- [ ] `/gate-check` — phase gate before architecture
- [ ] `/create-architecture` — Roblox/Knit-aware architecture blueprint
- [ ] `/prototype predator-ai` — highest-risk system, prototype before architecture is finalized
- [ ] `/sprint-plan new` — first production sprint
