# Player Controller

> **Status**: NEEDS REVISION (round-1 review verdict 2026-05-01) — **Round-2 Theme 1 (Pillar 1 closure) APPLIED 2026-05-01**; **Round-3 patch (B1–B5 + H.22d) APPLIED 2026-05-02**; **Round-4 patch (B6–B11 + IMPORTANT cluster) APPLIED 2026-05-02**; Round-5 design-review PENDING in fresh session; Themes 2/3/4 + OQ.3 camera decision PENDING in fresh sessions
> **Author**: chrusht + claude-opus-4-7
> **Last Updated**: 2026-05-02 (round-4 patch applied)
> **Implements Pillar**: 1 (Quiet Is Power), 2 (The Squad Is the Experience), 4 (Rounds Not Saves)
> **Engine**: Roblox Studio + Luau + Knit + Rojo
>
> **Round-2 Theme 1 closures**: G1 (grace-window first-pulse exploit, Sprint + Light) — closed via per-axis `GRACE_REENTRY_COOLDOWN = 6.0 s`. N1 (disconnect-before-death cost finalization) — closed via Path B `Players.PlayerRemoving` handler with composite imminent-death predicate (`HP_IMMINENT_THRESHOLD = 25` OR `DAMAGE_RECENT_WINDOW = 3.0 s`). N2 (`SPRINT_CLIENT_TIMEOUT` undefined heartbeat) — closed via dedicated zero-payload `PlayerHeartbeat` RemoteEvent at `HEARTBEAT_SEND_RATE = 1 Hz`. Au2 (sprint-audio mental model) — V/A.3 design note + footstep row revision; OQ.1 closed.
>
> **Round-3 closures**: B1 (`HP_ARM_RECENT_WINDOW = 30 s` time-bound on arm 1), B2 (H.22b setup), B3 (E.E line 504 predicate summary), B4 (V/A.3 line 706 governing prose), B5 (entities.yaml `t_entry`→`t_0` rename + `HP_ARM_RECENT_WINDOW` registered), H.22d (new AC for arm 2 in isolation).
>
> **Round-4 closures (2026-05-02)**: B6 (`_deathCostPaid[player] = false` cleared on T6 — Pillar 2 multi-life closure; `H.22e` AC). B7 (PlayerRemoving teardown-order race — read-and-cache discipline mandated; F.4 cross-service ordering contract). B8 (`RequestSquadOxygenSpend` rollback path — `pcall` + flag rollback; `H.22f` AC). B9 (D.4 grace-window jitter exploit — anchor-on-eligibility fix; `H.11h` AC). B10 (clock-injection seam mandated as new C.11 Testability Contract; H.22b/c/d/e/f + H.33a/b reference `getServerTime()`). B11 (boundary semantics — strict `<` documented for `HP_IMMINENT_THRESHOLD`, `HP_ARM_RECENT_WINDOW`, `DAMAGE_RECENT_WINDOW`; aligned in C.5.3, G.6, entities.yaml). IMPORTANT cluster: V/A.3 line 706 antecedent disambiguated; C.5.3 30s first-pass design intent + Scenario C false-negative class acknowledged; D.4 `t_lastGracePulse[axis]` anchored-at-`t_0` semantics clarified; H.11f/H.11g Light-axis cooldown ACs added.
>
> **Round-2/3/4 specialists consulted (cumulative)**: game-designer, systems-designer, network-programmer, ai-programmer, audio-director, qa-lead, creative-director (round-4 senior synthesis). Round-4 patch is single-session-applied per `.claude/docs/context-management.md` "one theme per session" guidance. **Round-5 design-review must run in a fresh session** before advancing to Theme 2 (Roblox API verification).

## Overview

**Player Controller** is the player-side input and movement surface for Terranova: a thin customization layer over Roblox `Humanoid` that owns first-person locomotion (walk, sprint, jump, crouch-equivalent), the **lantern raise/lower** state, the **squad coordination affordances** (quick-ping and emote wheel), and the death/respawn input flow. From the player's seat, it is the body — every loud action (sprinting, raising the lantern) and every quiet action (walking, pinging, emoting) is routed through this controller. From the system seat, it is the **publisher of `Sprint` and `Light` emissions** to the Ecological Disturbance service (per `ED.C.3.2`), the **owner of the movement-delta and state-entry-grace timers** that gate stationary-attenuation (per `ED.C.1.1` / `ED.G.5`), and the **cross-platform input router** that makes touch, mouse, and gamepad first-class. Because Pillar 1 (Quiet Is Power) is enforced by what counts as loud, and because Pillar 2 (The Squad Is the Experience) is enforced by what coordination affordances exist on every platform, Player Controller is where two of the four game pillars are mechanically realised. The rest of the game watches the controller's outputs.

## Player Fantasy

**The Loud Choice.**

You walk. Walking is the default because walking is survival — every footfall the predator doesn't hear is a footfall you bought. But your friend is bleeding out two ridges away and the oxygen pool is shrinking, so you sprint. The sprint is loud. You feel it leave you: the sound your body is making is now somewhere on the map, and something is listening to it. You ping your friend's location for the squad. You flash the "follow me" emote. Nobody has spoken. The lantern stays down until you absolutely need it. Loudness is a transaction, not a movement option, and you are the one signing.

**Anchor moment** — the 2–5 seconds this controller must deliver: you're crouched at chest-high cover, lantern lowered, friend three meters ahead in the dark. You hear the predator drag itself across stone two valleys over — *a sound your sprint, ten seconds ago, put there.* You tap a quick-ping on the cave mouth ahead, mash the "quiet" emote, and watch your friend freeze mid-step. Ninety seconds without anyone speaking aloud.

**Pillars served**

- **Pillar 1 — Quiet Is Power**: *"Stealth and restraint are mechanically rewarded. Loud play accelerates the predator."* Player Controller is where the contest between quiet and loud is fought every input. Walk vs. sprint, lantern down vs. lantern up, gather here vs. one zone over — every decision routes through this controller, and the controller publishes the consequence.
- **Pillar 2 — The Squad Is the Experience**: *"Multiplayer is core. Communication, role-splitting, and shared risk define the fantasy."* Quick-ping and the emote wheel are not accessories to the body — they *are* the body when voice chat is not assumed. Coordination on every platform (touch, mouse, gamepad) lives here, or it lives nowhere.
- **Pillar 3 — The World Watches**: every Sprint and Light emission this controller publishes is the world watching. The controller is the seam where player intent becomes ecological consequence.

**Reference grounding**

| Reference | What this controller takes |
|---|---|
| *Alien: Isolation* | The body is a liability that publishes you to a listener; sound radius is a survival statistic, not a feature. |
| *Doors* (Roblox) | Restraint over reflex; the input pace the player chooses is the survival pace. |
| *Apeirophobia* (Roblox) | Co-op fragility expressed through the *absence* of action — walking together, lantern down, no one spending silence carelessly. |
| *Subnautica* | The single-intelligent-predator philosophy means every input is evaluated against a watcher you respect. |

**What the player should feel** — that the controller is not a power fantasy. The body is slow. Sprinting and lighting are deliberate transactions paid in disturbance. The squad coordinates without voice and trusts the controller to make that coordination first-class on whatever device they're on. The horror, when it comes, is not random — *you summoned it.*

## Detailed Design

### Core Rules

#### C.1 — Locomotion

1. **Walk speed** (default move) = `WALK_SPEED = 12 studs/s`. The player's quiet floor; **walk publishes no Sprint emission**. Roblox `Humanoid` default of 16 was rejected as too brisk for the "fragile body" fantasy.
2. **Sprint speed** = `SPRINT_SPEED = 20 studs/s` (1.67× walk). Engages on sprint-state entry; **publishes Sprint emissions** to Ecological Disturbance per `ED.C.3.2`.
3. **Sprint binding** is **per-platform**:
   - **Touch**: toggle (single tap of sprint button starts; tap again to stop). Avoids two-thumb hold fatigue over 5–20 min sessions on iPhone SE-class hardware.
   - **Keyboard/Mouse**: hold (`Left Shift`). Genre-universal convention.
   - **Gamepad**: hold (`L3` press-and-hold, NOT click-toggle). L3-click-as-toggle misfires under grip stress in predator encounters.
   *Rationale*: same intent (sprint costs effort), different friction per platform.
4. **Jump**: enabled (Roblox `Humanoid` default). **Allowed mid-sprint**. Jump does not suppress, reset, or rate-limit Sprint or Light pulse intervals — pulse timers are server-clock interval-based, not reset-on-interrupt. Bunny-hop exploits are precluded by the interval timer's authority.
5. **Fall damage**: **none**. Oxygen and predator contact are the only health/death vectors. Adding fall damage would create "unfair death" friction conflicting with Pillar 4 (Rounds Not Saves — every death must feel earned).
6. **Crouch**: **not in MVP**. Walk is the quiet floor; a third locomotion tier is deferred to v2.

#### C.2 — Stamina

1. **Stamina is server-authoritative**. Maximum = `STAMINA_MAX = 100` units; abstract units (not seconds) preserve drain/regen tuning independence.
2. **Drain** while sprinting = `STAMINA_DRAIN_RATE = 12.5 units/s` → 8 seconds of full sprint at maximum stamina.
3. **Regen** while not sprinting = `STAMINA_REGEN_RATE = 10 units/s`. Regen is intentionally slower than drain (ratio 0.8) — an 8-second sprint requires 10 seconds of walking to fully restore, which makes "sprint everywhere, walk on empty" a losing strategy.
4. **Regen delay** after sprint stops = `STAMINA_REGEN_DELAY = 1.5 s`. Prevents bar-twitch on partial-sprint inputs and makes sprint-burst micro-management feel committed.
5. **At 0 stamina**: forced walk (server reverts `Humanoid.WalkSpeed` to `WALK_SPEED`; sprint input is ignored until stamina > 0). No additional cooldown — slow regen is the natural drain-floor; a cooldown on top of slow regen would be double-punishment.
6. **No final pulse on depletion**: when sprint state exits because stamina hit 0 mid-frame, the next pulse interval does not fire. Per `ED.C.1.1`, pulses fire while sprint state is *active*; exiting state stops the timer.
7. **HUD coupling**: server pushes `OnStaminaChanged` (current stamina, normalized 0.0–1.0) at ≤5 Hz to the owning client only — for the HUD bar. The client never uses this value to gate input; the server gates everything.

#### C.3 — Lantern

1. **Toggle binding**: single press/tap toggles between `LanternLowered` and `LanternRaised`. Defaults: `F` (PC); `D-pad Down` (gamepad); dedicated lantern button in HUD upper-left zone (touch — physically separated from sprint+stick zone to defend against predator-encounter mis-tap, per pitfall flagged in `Section E.6`).
2. **Raised state**: server publishes `LightEmission` to Ecological Disturbance per `ED.C.3.2` (`magnitude = MAGNITUDE_LIGHT_PULSE = 0.08`, interval `LIGHT_PULSE_INTERVAL = 4 s`). Visual rendering: `LANTERN_VISIBILITY_RADIUS = 20 studs` (player-side rendering only — not a gameplay mechanic; HUD/art-bible owns visuals).
3. **Lowered state**: silent. No emissions.
4. **Lantern is orthogonal to sprint state** — both can be active simultaneously. Sprint and Light pulses fire on independent intervals with independent movement-delta trackers and independent grace-window timers. **Concurrent use is the maximum-loud state by design** — the cost is additive; the squad has a reason to say "lantern down" while sprinting.
5. **No fuel mechanic**. The lantern is a binary state owner, not a resource. Two simultaneous resources (oxygen + lantern) would exceed MVP complexity ceiling.

#### C.4 — Squad Coordination

1. **Quick-ping**:
   - **Input**: two-finger simultaneous tap (touch); `G` (PC); `L1 / LB` (gamepad).
   - **What is pinged**: client raycasts from camera center on input. If the ray hits a tagged entity (`enemy`, `resource`, `door`, `exit`) within `PING_RAYCAST_RANGE = 80 studs`, ping carries location + entity type. Otherwise location only.
   - **Server validation**: server validates raycast origin/destination against player's server-tracked position and camera angle before broadcasting (per game-concept's "server validates plausibility" rule).
   - **Persistence**: `PING_DISPLAY_DURATION = 8 s`.
   - **Rate limit**: per-player `PING_COOLDOWN_PER_PLAYER = 1.0 s`; burst cap `PING_BURST_CAP = 3` pings per `PING_BURST_WINDOW = 1.5 s`.
   - **Categories**: Danger (red, enemy tag), Resource (green, resource tag), Navigate (yellow, terrain/door/exit), Untagged (white, location-only).
   - **Not a disturbance source**: pings publish nothing to Ecological Disturbance.
2. **Emote wheel**:
   - **Input**: `T` hold (PC); `D-pad Up` hold ≥0.3 s (gamepad); dedicated emote button (touch, lower-right HUD zone). Wheel closes on release (PC/gamepad) or second tap (touch).
   - **Slot count**: 6. Slot ordering by predicted use frequency: (1) Quiet, (2) Follow me, (3) Danger, (4) All clear, (5) Wait, (6) Help/SOS. Slots 1–3 are functionally locked; slots 4–6 are cosmetically replaceable via Robux purchases (animation-swap with semantic preservation — cosmetic-boundary compliant per game-concept's anti-pillars).
   - **Rate limit**: per-player `EMOTE_COOLDOWN_PER_PLAYER = 3.0 s`; burst cap `EMOTE_BURST_CAP = 5` emotes per `EMOTE_BURST_WINDOW = 15.0 s`.
   - **Display**: `EMOTE_DISPLAY_DURATION = 4 s` on-screen indicator; animation plays to completion (~1.5–2.5 s).
   - **D-pad fallback (accessibility)**: `D-pad Up` (hold 0.3 s) opens; `D-pad Left/Right` cycles slots; `A / Cross` commits; `D-pad Down` cancels. Fully operable without right stick.
   - **Emotes generate ZERO disturbance**. Server-validated. (Per game-concept anti-pillar: emote audio uses fixed UI-only channels, never positional 3D audio.)
3. **Mutual exclusion**: while emote wheel is open on touch, tap-hold gather is **locked out** on the right thumb side (gesture-conflict mitigation). Player must close the wheel before gathering. *This is a state-machine rule, not a feel knob — see C.7 transition T9.*

#### C.5 — Death and Respawn

1. **Trigger conditions** (authoritative list — any one fires the death flow):
   - `Humanoid.Health` reaches 0 (predator kill — primary mechanism in MVP)
   - Squad oxygen pool reaches 0 *and* the per-player oxygen-grace timer expires (the grace timer is owned by the Resource Management GDD — Player Controller subscribes to an `OnPlayerOxygenExpired` signal from that service, when authored)
2. **Server-authoritative respawn timer**: 30 s (`RESPAWN_DELAY = 30 s`). Timer begins on the server at the moment `Humanoid.Died` fires. **Idempotent guard**: the death handler MUST refuse re-entry — `Humanoid.Died` can fire twice in pathological replication races, and the timer must not reset.
3. **Squad oxygen cost**: 1 shared-oxygen-pool unit (exact unit defined by Resource Management GDD). Cost is triggered by **two server-side paths** that converge on the same idempotent T5 death procedure:

   - **Path A — `Humanoid.Died`**: deducted at the moment `Humanoid.Died` fires, not at respawn arrival. Rationale: cost is the *act* of dying; deducting at death rather than at respawn prevents the disconnect-mid-respawn-timer exploit.
   - **Path B — `Players.PlayerRemoving` while imminent-death predicate satisfied**: server evaluates the predicate when an alive player disconnects. If satisfied, server invokes the same T5 procedure on behalf of the disconnecting player: 1 squad oxygen deducted, `OnPlayerDied(playerId, deathCause="disconnect-while-damaged")` broadcast, sprint state cleared. The player is removed immediately after T5 completes — **no respawn timer is started** (they are no longer present to receive it).

     **Read-and-cache discipline (load-bearing for predicate validity under cross-service teardown)**: PC's `Players.PlayerRemoving` handler MUST read `lastPredatorDamageTimestamp[player]` into a local variable **AS THE FIRST STATEMENT of the handler, before any yield-capable call** (no `task.wait`, no `RemoteFunction:InvokeServer`, no `Knit:GetService(...)` round-trip, no `Signal:Wait`). The cached local — not the live table read — is what the predicate evaluates. Knit-service `PlayerRemoving` connection ordering across services is **non-deterministic by Knit framework contract**; if PredatorService's own `PlayerRemoving` handler runs before PC's and clears the entry (per F.4 belt-and-braces clearance rule), a naive live-read predicate would observe `nil` and silently fail to fire on a legitimate predator-induced disconnect. The cache-first ordering closes this race independent of the cross-service teardown order.

     ```luau
     -- C.5.3 Path B handler skeleton (illustrative, not normative implementation):
     Players.PlayerRemoving:Connect(function(player)
         -- FIRST STATEMENT — no yield before this line.
         local cachedDamageTs = lastPredatorDamageTimestamp[player]
         local cachedHealth = player.Character and player.Character:FindFirstChild("Humanoid")
                              and player.Character.Humanoid.Health or nil
         -- Now safe to evaluate the predicate against cached locals
         -- and to yield within the T5 procedure (RequestSquadOxygenSpend, etc.)
         if isImminentDeath_cached(cachedHealth, cachedDamageTs) then
             invokeT5(player, "disconnect-while-damaged")
         end
     end)
     ```

     This is normative for the **ordering only**; the implementation is free to refactor the cache into a single struct, a Knit-service helper, or a per-player snapshot table. The invariant is: **no yield-capable Luau call may sit between handler entry and the cache reads.**

   **Imminent-death predicate** (server-evaluated at `PlayerRemoving` time, no client involvement):
   ```
   isImminentDeath(player) =
       (Humanoid.Health < HP_IMMINENT_THRESHOLD
        AND lastPredatorDamageTimestamp[player] ~= nil
        AND (workspace:GetServerTimeNow() - lastPredatorDamageTimestamp[player]) < HP_ARM_RECENT_WINDOW)
       OR
       (lastPredatorDamageTimestamp[player] ~= nil
        AND (workspace:GetServerTimeNow() - lastPredatorDamageTimestamp[player]) < DAMAGE_RECENT_WINDOW)
   ```
   where `HP_IMMINENT_THRESHOLD = 25` (default; range 10–50), `DAMAGE_RECENT_WINDOW = 3.0 s` (default; range 1.5–5.0), and `HP_ARM_RECENT_WINDOW = 30.0 s` (default; range 15–60).

   **Boundary semantics (B11 — comparators are strict `<`, not `<=`)**: the HP comparison is `Humanoid.Health < HP_IMMINENT_THRESHOLD`, NOT `<=`. A player at exactly `Humanoid.Health = 25.0` does NOT satisfy arm 1 (the HP value must be strictly less than 25). The same strict-less-than semantics apply to both window comparators: `(now - lastPredatorDamageTimestamp[player]) < HP_ARM_RECENT_WINDOW` and `(now - lastPredatorDamageTimestamp[player]) < DAMAGE_RECENT_WINDOW`. A player whose predator-damage timestamp is exactly 30.0 s ago does NOT satisfy arm 1's recency check (the elapsed time must be strictly less than 30 s); a player whose predator-damage timestamp is exactly 3.0 s ago does NOT satisfy arm 2 (the elapsed time must be strictly less than 3 s). **The strict comparators are intentional** — they bias the predicate toward false-negatives at exact boundaries (favoring "no oxygen deducted" when the inputs are at the precise edge), consistent with E.F's precedent at line 515 where the ping cooldown uses `>=` for the inclusive direction (acceptance at exact boundary). The asymmetry across these two cases is principled: ping-cooldown UX favors *acceptance* at the boundary (off-by-one denials are bad UX); imminent-death cost attribution favors *rejection* at the boundary (off-by-one over-charges are worse than off-by-one under-charges for Pillar 2 cost legitimacy).

   **Practical implication for tuning**: when authoring an AC or playtest scenario at a boundary value (HP=25, 30s elapsed, 3s elapsed), use HP=24.99 or 25.01 / 29.99 s or 30.01 s / 2.99 s or 3.01 s to exercise the actual branch; testing at the exact boundary value is testing the edge case where neither side fires, which is a separate edge-case test class. G.6 and `entities.yaml` mirror this strict-less-than annotation.

   **Pillar 2 (cost attribution) — both arms are predator-scoped AND time-bounded**: each arm of the OR requires `lastPredatorDamageTimestamp[player] ~= nil` AND a recency check against the predator timestamp. A player whose HP fell below `HP_IMMINENT_THRESHOLD` from non-predator damage (oxygen-depletion ticks, environmental hazard, fall damage) and who then disconnects pays NO squad oxygen. The predicate fires only when the predator demonstrably and recently contributed to the player's near-death state. This closes the Theme-1-round-2 ai-programmer Pillar 2 finding ("a player at HP=24 from oxygen-depletion who disconnects pays squad oxygen even though the predator was never near") AND the round-3 stale-graze defect (a 600 s-old predator brush followed by oxygen-depletion no longer triggers Path B). The OR is intentional given the predator-scope and time-scope: arm 1 catches "predator hit me within the last `HP_ARM_RECENT_WINDOW = 30 s` AND I'm disconnecting at low HP" (the recent graze plus current low HP makes the predator the credible proximate cause of the imminent death); arm 2 catches "lethal predator combo in flight from high HP within `DAMAGE_RECENT_WINDOW = 3 s`" (predator damage recent enough that HP may not yet reflect it). The 30 s upper bound on arm 1 is the round-3 patch: too low (<15 s) misclassifies legitimate "lethal combo in flight" disconnects (player took heavy graze, ran 20 s, disconnected at low HP — predator IS proximate cause but window already expired); too high (>60 s) re-opens the stale-graze false-positive class for slow oxygen-depletion deaths after a long-ago predator brush.

   **Design-intent note (round-4 IMPORTANT, game-designer F1)**: the 30 s value of `HP_ARM_RECENT_WINDOW` is **first-pass design intent**, not playtest-validated. The 15–60 s range in G.6 is the analytical envelope between the two failure modes above; the precise default within that envelope will be revisited after first-prototype playtest data per G.8.1 ("Default values shipped here are first-pass design intent, not playtest-validated"). Tuning this knob without playtest evidence is premature.

   **Acknowledged false-negative class — "Scenario C" (round-4 IMPORTANT, game-designer F1 + ai-programmer F3 convergent)**: the strict `<` upper bound on arm 1 means the following is currently classified as a non-payable disconnect: a player takes a serious predator graze, panic-flees for 30+ seconds (long enough to escape the recency window), enters slow oxygen-depletion at low HP, and disconnects. The predator was the *originating* cause of the low-HP state but is no longer the *recent* cause. Under the current rule the squad pays nothing; under a wider window the squad would over-pay on legitimate post-encounter deaths (the round-3 false-positive class). **This false-negative class is acknowledged as the chosen trade-off** — the alternative (window > 60 s) re-opens the round-3 false-positive class for any death following any predator brush in the run, which is worse for Pillar 2 cost legitimacy. Future revisions may tier the predicate (e.g., arm 1 with a long window AND a "predator hit was non-trivial" magnitude gate) to recover this class, but doing so would require an ADR on damage-magnitude classification — out of scope for round-4. **Scenario C is therefore an explicit, named design choice, not an oversight.**

   **Init-order safety — nil-guard explicit**: `lastPredatorDamageTimestamp[player]` is `nil` for any player who has not yet received predator damage this life, including (a) players who joined before `PredatorService` fired any damage event (or before its bootstrap completed — see F.4 PredatorService init mandate), and (b) freshly-respawned players whose entry was cleared on T6. The predicate handles `nil` explicitly: both arms short-circuit on `~= nil` BEFORE any subtraction. **No `nil - number` arithmetic ever evaluates** — the AND in arm 2 left-evaluates the nil-check first, and Luau's short-circuit semantics guarantee the subtraction runs only when the timestamp is non-nil. F.4 separately mandates that `PredatorService` initializes the table to `{}` (not `nil`) before any player can join, so even table-level `nil` indexing is safe.

   **Idempotency**: T5 maintains a per-player boolean `_deathCostPaid` (init `false` at session start **AND cleared back to `false` on every T6 (respawn) transition** — see T6 side-effects in the C.6 transition table). Both paths check this flag before acting. **Without the T6 clearance, the second death of a session pays zero squad oxygen** — `_deathCostPaid` set on the first death persists across respawn, the next T5 reads `true` at step 1 below, and no oxygen is deducted. T6 clearance is load-bearing for Pillar 2 across multi-life squad runs.

   **Set-before-yield discipline (atomicity rule — load-bearing for the entire idempotency claim)**: Luau is cooperatively scheduled — any function that may yield (`RemoteFunction:InvokeServer`, `Signal:Wait`, `task.wait`, `pcall(:GetAsync)`, `:InvokeServer` round-trips, `Knit:GetService(...):Method()` if the service performs a remote call internally) creates a yield boundary across which other coroutines (including the OTHER path's handler) can run. The check-and-set on `_deathCostPaid` MUST therefore complete in a single non-yielding span. **The implementation order is mandatory**:

   1. Read `_deathCostPaid[player]`.
   2. If `true`, return immediately (no-op — the other path got there first).
   3. If `false`, set `_deathCostPaid[player] = true` **BEFORE** invoking `RequestSquadOxygenSpend` or any other call that may yield.
   4. Invoke `RequestSquadOxygenSpend(amount=1, reason="death")` **wrapped in `pcall`**. This is a yield boundary; the flag is already `true` at step 3, so a concurrent path's read in step 1 will return at step 2.
   5. **Failure-mode rollback path**: if `pcall` returned `(false, errMsg)` OR the RemoteFunction's resolved result indicates failure (per Resource Management's `RequestSquadOxygenSpend` contract — e.g., `{success = false, reason}`), **clear `_deathCostPaid[player] = false`** to roll back the flag, surface the failure to a server log channel (`warn("[PlayerController] RequestSquadOxygenSpend failed for " .. player.Name .. ": " .. tostring(errMsg))`), and **do NOT broadcast `OnPlayerDied`** for this attempt. The squad oxygen ledger is unchanged.

      **Why the rollback alone is not sufficient (R5-B2 round-5 closure)**: in the concurrent-path race, by the time the `pcall` resolves both `Humanoid.Died` and `Players.PlayerRemoving` may have already returned. Whichever path fires first (call it Path X) sets the flag at step 3 and yields at step 4; while Path X is yielded, the OTHER path (Path Y) reads the flag at step 1, observes `true`, short-circuits at step 2, and returns synchronously. Path X's `pcall` then fails at step 5 and rolls the flag back — but no in-line retry path is reachable because Path Y has already completed and exited and Path X is mid-rollback with no remaining synchronous work. Without a retry surface beyond the rollback itself, this race silently zeroes the squad cost and never broadcasts `OnPlayerDied`. **The round-4 prose claimed three retry surfaces ("next Heartbeat re-evaluation, operator-driven retry, or the OTHER death path firing"); under the concurrent-path race none of the three is reachable in-process, so the claim was factually false.**

      **The reconciliation tick is the authoritative retry surface (R5-B2 option (a) — CD-recommended, user-confirmed 2026-05-04).** PlayerController owns a server-side **death-cost reconciliation tick** that runs every `RECONCILIATION_TICK_INTERVAL = 5.0 s` on `RunService.Heartbeat`. The tick scans all players whose row matches:

      ```
      reconcile_eligible(player) =
          (player ∈ S4 (Dead-Respawning) OR player no longer in Players service)
          AND _deathCostPaid[player] == false
          AND deathDeductionCommitted[player] ~= true
      ```

      where `deathDeductionCommitted[player]` is a per-player boolean set to `true` ONLY at step 6's success path (after BOTH a successful `RequestSquadOxygenSpend` AND a successful `OnPlayerDied` broadcast). The reconciliation tick re-invokes the T5 deduction procedure for any matching player with the same set-before-yield discipline, the same `pcall`, and the same rollback path on failure (which simply re-arms for the next reconciliation tick). On success, the tick sets `deathDeductionCommitted[player] = true` and broadcasts `OnPlayerDied(playerId, deathCause="reconciliation-recovery")` so HUD / squad communication can distinguish a delayed death notification from a normal one. **The flag rollback at step 5 is therefore the handoff to the reconciliation tick, not the end of the recovery path.**

      **Bound on retry latency**: a player whose initial deduction failed is recovered within at most `2 × RECONCILIATION_TICK_INTERVAL = 10.0 s` of the original death event (worst case: the tick fired immediately before the failure; the next tick observes the rollback state and retries successfully). For Path A players (Dead-Respawning), 10 s is well within the 30 s `RESPAWN_DELAY` window — the squad cost is reconciled before respawn arrival. For Path B players (already removed from the server), the `Player` instance is destroyed but the reconciliation rows persist on the server keyed by `userId` snapshotted at `PlayerRemoving` time (`_deathCostPaid` and `deathDeductionCommitted` use a per-server-session userId index for removed players). Rows are cleared on successful reconciliation OR at server shutdown.

      **Reconciliation tick lifecycle**:

      - **Bootstrap**: `PlayerControllerService` starts the tick connection inside `Knit:Start()` lifecycle, after all dependencies' tables are initialized. The first tick fires no earlier than `RECONCILIATION_TICK_INTERVAL` after server start.
      - **Per-tick scan**: O(active players + recently-removed players this session) — a single linear pass over the small per-server table; <0.01 ms per tick at H.28's 4-player budget.
      - **Termination**: each scanned row is removed from the reconciliation working-set on success (deathDeductionCommitted set true) OR retained for the next tick on failure. No row is reconciled more than once per tick interval.
      - **Persistence boundary**: reconciliation state is in-memory per server session — it does NOT cross `BindToClose` or server-instance boundaries. Resource Management owns the durable squad-oxygen ledger via ProfileStore; reconciliation is the in-session bridge between PC's death event and RM's persisted decrement.

      **HUD forward obligation**: the gap between the original death event and the reconciliation broadcast (up to 10 s) is a player-experience gap — a surviving squad member observes a teammate vanish without an `OnPlayerDied` for up to 10 s, then receives a delayed `OnPlayerDied(deathCause="reconciliation-recovery")`. HUD GDD owes the player-experience prose for this delayed-notification class (see F.4 row).

   6. **Success path**: if `pcall` returned `(true, ...)` AND the resolved result indicates success, broadcast `OnPlayerDied(...)`, **set `deathDeductionCommitted[player] = true`** (anchors the reconciliation tick's "already committed" exit per step 5), and **invoke the full T5 transition side-effects per the C.6 T5 row**, which is normative for both Path A and Path B and includes:

      - (a) the C.5.5 **sprint hard-reset** (force T2 if S2 active — stop the sprint pulse interval timer; clear sprint authorization);
      - (b) the **lantern force-T4 if S3b active** — stop the Light pulse interval timer (R5-B1 round-5 closure: without this, a player in S3b at disconnect-time on Path B would continue emitting Light pulses for up to `LIGHT_PULSE_INTERVAL = 4 s` on a `HumanoidRootPart` that is about to be destroyed — Pillar 1 phantom-emission class);
      - (c) freeze stamina at current value;
      - (d) reset `t_lastGracePulse_sprint = nil` and `t_lastGracePulse_light = nil` (Pillar 4 fairness — fresh grace slate post-respawn; **Path A only** — Path B player is removed, so there is no "next life" for the cooldown to gate);
      - (e) activate spectator camera (**Path A only** — Path B player is removed, no camera to attach);
      - (f) lock client-side movement / lantern / sprint / gather inputs (**Path A only** — Path B player is removed, no client to send the lock to).

      **Path B's invocation of T5 is identical to Path A's at the rule level except where the player's removal makes a side-effect inapplicable (rows e and f). The locomotion-axis and lantern-axis pulse-timer resets (rows a and b) are mandatory in both paths.** Items (a) and (b) close phantom-emission classes against `HumanoidRootPart` instances that no longer exist (Pillar 1).

   Steps 1–3 are a single atomic span — **no yield-capable Luau call may sit between the read and the set**. This ordering ensures that whichever path fires second (across `Humanoid.Died` and `PlayerRemoving`) reads `true` at step 1 and returns at step 2, even if the first path is mid-yield in steps 4–6. Without this discipline (e.g., if the implementation invoked `RequestSquadOxygenSpend` before setting the flag), both paths could observe `false` across the yield boundary and double-deduct under a lethal-damage-plus-disconnect race.

   **Without the step 5 rollback**, a transient RemoteFunction failure (RM service crashed, restart, or transient routing failure) would permanently mark the player as having paid the cost while the squad ledger never decremented — silently zeroing the cost on any retry path. **Rollback is the inverse of the set-before-yield invariant**: the flag set is a *commitment* that the deduction will be attempted; the rollback releases that commitment when the attempt provably failed. The two together form a try-or-rollback transaction at the rule level. Idempotency holds against the lethal-damage-plus-disconnect race because step 3 fires before any yield; **rollback safety holds against the RemoteFunction-failure case because step 5 reverts the flag when the deduction provably did not happen.**

   Idempotency holds against: (a) `Humanoid.Died` and `PlayerRemoving` firing in the same or adjacent Heartbeat (race under lethal-damage-plus-disconnect — set-before-yield discipline above closes this), (b) `PlayerRemoving` for a player already in S4 (`_deathCostPaid` already `true`), (c) network-desync replay of either event. **Exactly one squad oxygen unit is deducted per player-death-event regardless of path.**

   **Cross-system dependency**: `lastPredatorDamageTimestamp` is a **server-internal table written by `PredatorService` on every damage application**. Player Controller reads it; PredatorService owns it. Forward obligation flagged in F.4.

   **Implementation requirement**: T5 MUST be a callable procedure independent of the `Humanoid.Died` signal path so Path B can invoke it from `PlayerRemoving`. Flagged as a new ADR ("Death-Cost Attribution") in F.4.
4. **Inputs accepted while dead** (`Dead-Respawning` state):
   - **Quick-ping**: YES (dead players still mark locations for the squad)
   - **Emote wheel**: YES (dead players still signal the squad)
   - **Spectator camera**: YES (free-roam within squad proximity — owned by a future Camera GDD; Player Controller surfaces the input affordance only)
   - **Movement / sprint**: NO (no body)
   - **Lantern toggle**: NO (no body)
   - **Gather / interact / craft**: NO (no body)
5. **Sprint state hard-reset on death**: when the death flow triggers, the server MUST clear sprint state (force-walk, stop sprint timer, stop Sprint emission interval). On respawn, the player spawns in `Alive-Walking` with stamina restored to `STAMINA_MAX` and lantern in `LanternLowered`. *Pitfall mitigation: prevents the player from respawning already-sprinting and broadcasting disturbance before they've oriented.*
6. **Spectator camera and StreamingEnabled**: dead-player spectate camera following a teammate into an unloaded chunk MUST guard against missing geometry. Recommended fallback: freeze the camera until `workspace:HasChunkLoaded()` confirms (verify API name against current Roblox docs before architecture). *Alternative behavior is OK; the requirement is "no spectator falls into the void" — see Section E for edge case.*
7. **Respawn anchor**: a level-design-flagged spawn point (NOT random, NOT the death point). Specific anchors are level-design's responsibility.
8. **Whole-squad-dead → run end**: if all 2–4 squad members enter `Dead-Respawning` simultaneously *and* the squad oxygen pool is too low to fund any respawn, server transitions all players to `Dead-Permanent` and broadcasts `RunEnded` (per game-concept "If the entire squad dies, the run ends"). The round-results screen takes over.

### States and Transitions

#### C.6 — State Machine

Player Controller runs **two orthogonal state machines** that compose freely. The locomotion-axis (walk/sprint) and the lantern-axis (lowered/raised) are independent; both may be active simultaneously, each with its own emission interval timer and movement-delta tracker. The death-axis is a top-level state that pre-empts both.

**States:**

| State ID | Axis | Name | Description |
|---|---|---|---|
| S1 | Locomotion | Alive-Walking | Default. WalkSpeed = `WALK_SPEED`. No Sprint emission. |
| S2 | Locomotion | Alive-Sprinting | WalkSpeed = `SPRINT_SPEED`. Stamina draining. Sprint emission on interval. |
| S3a | Lantern | LanternLowered | Default. No Light emission. |
| S3b | Lantern | LanternRaised | Light emission on interval. Composable with S1 or S2. |
| S4 | Death | Dead-Respawning | 30 s countdown. Movement / lantern / gather denied. Ping + emote + spectate allowed. |
| S5 | Death | Dead-Permanent | Whole-squad-dead terminal. All inputs locked. Run-results screen. |

**Jump** is treated as a transient physics event, not a discrete state — it does not affect emission timing or the locomotion axis.

**Transitions:**

| ID | Trigger | From | To | Side Effects |
|---|---|---|---|---|
| T1 | Sprint input asserted + stamina > 0 + alive | S1 | S2 | Server: WalkSpeed → SPRINT_SPEED; first SprintEmission at full magnitude (within `FIRST_PULSE_GRACE_WINDOW`); start sprint pulse interval timer |
| T2 | Sprint input released OR stamina hits 0 | S2 | S1 | Server: WalkSpeed → WALK_SPEED; stop sprint pulse interval timer; start `STAMINA_REGEN_DELAY` timer |
| T3 | Lantern toggle input + alive | S3a | S3b | Server: first LightEmission at full magnitude (within `FIRST_PULSE_GRACE_WINDOW`); start light pulse interval timer |
| T4 | Lantern toggle input | S3b | S3a | Server: stop light pulse interval timer; no emission on exit |
| T5 | `Humanoid.Died` fires (idempotent) | S1 or S2 | S4 | Server: stamina frozen at current value; force T4 if S3b active; force T2 if S2 active; deduct 1 squad oxygen unit (set `_deathCostPaid = true`); reset `t_lastGracePulse_sprint = nil` and `t_lastGracePulse_light = nil` (Pillar 4 fairness — fresh grace slate post-respawn); spectator camera activated; client receives `OnPlayerDied`; client's local input handler locks movement+lantern+sprint+gather |
| T6 | Respawn timer = 30 s elapsed AND squad oxygen pool ≥ 1 | S4 | S1 (with S3a) | Server: respawn at level-flagged anchor; stamina = `STAMINA_MAX`; lantern = `LanternLowered`; sprint state cleared; emit no disturbance; camera returns to player; **clear `_deathCostPaid[player] = false`** (load-bearing for Pillar 2 — without this, the second death of the session pays zero squad oxygen because the prior T5 left the flag at `true`, see C.5.3 idempotency prose) |
| T7 | All squad in S4 AND squad oxygen < 1 | S4 (all players) | S5 (all players) | Server: broadcast `RunEnded`; round-results screen; lock all inputs |
| T8 | Squad escapes (Beacon-driven, owned by Crafting & Items GDD) | any alive | S5 | Server: broadcast `RunEnded(victory)`; lock all inputs |
| T9 | Emote wheel opened (touch only) | any | (locks tap-hold gather) | Client: gather input on right-thumb zone is suppressed until wheel closes. Not a state transition — a temporary input lock orthogonal to the state axes. |

**Concurrency invariants:**

- S2 (Alive-Sprinting) is mutually exclusive with S1 (Alive-Walking).
- S3a (LanternLowered) is mutually exclusive with S3b (LanternRaised).
- S2 + S3b is the maximum-loud state (both pulse streams active concurrently).
- S4 (Dead-Respawning) and S5 (Dead-Permanent) pre-empt the locomotion axis: while in S4 or S5, the locomotion state is implicitly S1 (the body is absent; the value is held but unused).

### Interactions with Other Systems

#### C.7 — Touch-Input Detail

**Tap-hold gather** (PC + mobile contextual):

- Hold duration to commit = `TAP_HOLD_COMMIT_DURATION = 500 ms` *wall-clock* (not frames). 500 ms is the Apple HIG long-press floor; sits inside both 30 fps thermal-throttled mobile and 60 fps PC tolerances.
- **Wall-clock, not frame count, is mandatory** — defining in frames would make PC gather fire twice as fast as mobile.
- Progress ring fills client-side from T = 0 of the hold; completes at T = 500 ms. Releasing early cancels (no commit fired).
- On commit, client fires `RequestGather` to the server (server-confirmed). If the server rejects (out-of-range, depleted, dead), the ring animates to a "fail" state (brief red flash + dismiss).
- **The ring is the only client-predicted UI state in the controller.** All other feedback is server-confirmed.

**Proximity gate** (mobile contextual):

- Server-side Euclidean distance from `HumanoidRootPart.Position` to nearest gather-node center; threshold `GATHER_PROXIMITY_RADIUS = 4 studs`.
- Server fires `GatherNodeArmed` to the owning client when within range. Client renders a contextual prompt.
- Commit: single tap (touch) or `E` (PC) once the gate is armed. Fires `RequestGather` (server-confirmed).
- If the player moves out of range during the arm window, server fires `GatherNodeDisarmed`; client dismisses the prompt. No partial state is created.

**Two-finger quick-ping**:

- Detection window = `PING_TWO_FINGER_WINDOW = 150 ms`. Client tracks `UserInputService.TouchStarted` events; if two `TouchStarted` events land within this window (count, not position), the ping fires.
- **A third touch contact within the window cancels and suppresses the ping** — defends against frantic multi-finger sequences during predator encounters.
- Gesture detection lives in the client `PlayerControllerController` because `ContextActionService` does not natively express multi-touch gestures. Per-frame accumulator pattern.

**Mobile-touch analog-drift threshold**:

- The mobile thumbstick can output sub-perceptible drift values when held but unmoved. Per `ED.F.2a row 8` (Tier-2 #17), the stationary classifier MUST treat XZ-distance below `MOBILE_ANALOG_DRIFT_THRESHOLD = 2 studs` (over the previous pulse interval) as **not moving** for emission-attenuation purposes.
- This threshold is **distinct from `EMITTER_MOVEMENT_DELTA_FLOOR = 1 stud`** — the latter is the ED-side stationary gate; the former is a Player-Controller-side input-cleanup floor that filters drift before the position is used for the ED gate. **Rule**: on mobile, if the player's XZ-displacement over the previous pulse interval is below `MOBILE_ANALOG_DRIFT_THRESHOLD`, treat the player's effective displacement for emission-purposes as zero.
- **Silent classification** — no UI indicator for sub-threshold drift. Showing "you're not actually moving" would imply the player is trying to move and failing; visual character animation is sufficient feedback.

#### C.8 — Disturbance System Contract (publisher)

Player Controller is the **publisher of two emission types** to Ecological Disturbance per `ED.C.3.2` and `ED.F.2a` (canonical contract). The contract here is normative — any drift between this section and the ED GDD is a defect against ED, not against this GDD.

1. **Sprint emission** — fired by the server when:
   - The player enters S2 (Alive-Sprinting) — the **first pulse** fires within `FIRST_PULSE_GRACE_WINDOW = 1.0 s` of state-entry. Whether this first pulse is **grace-exempt** (full magnitude regardless of movement-delta) depends on the per-axis re-entry cooldown:
     - If `t_lastGracePulse_sprint` is `nil` (first sprint of this life) OR `(t_0 - t_lastGracePulse_sprint) >= GRACE_REENTRY_COOLDOWN`: **grace-exempt**. First pulse fires at `MAGNITUDE_SPRINT_PULSE = 0.10`. Server records `t_lastGracePulse_sprint = t_0`.
     - Otherwise (cooldown active): first pulse is **not grace-exempt**; falls through to magnitude-attenuation. Full magnitude fires if moving; attenuated magnitude fires if stationary.
   - Every `SPRINT_PULSE_INTERVAL = 2 s` thereafter while S2 is active.
   - Call: `DisturbanceService:Emit(emissionType="Sprint", position=playerWorldPosition, initialMagnitude=MAGNITUDE_SPRINT_PULSE, sourcePlayerId=playerId)`.
   - **Magnitude attenuation**: if XZ-displacement over the previous pulse interval is below `EMITTER_MOVEMENT_DELTA_FLOOR = 1 stud` AND the pulse is **NOT currently grace-exempt** (per the rule above — i.e., outside `FIRST_PULSE_GRACE_WINDOW` OR within it but cooldown-blocked), multiply `initialMagnitude` by `STATIONARY_EMISSION_FACTOR = 0.30`.

   **Cooldown rationale (Pillar 1 closure)**: without `GRACE_REENTRY_COOLDOWN`, a player can toggle sprint ON for 0.9 s (grace-exempt first pulse), toggle OFF, wait 1.5 s `STAMINA_REGEN_DELAY` + ~0.225 s for stamina to regen, and toggle ON again for a fresh grace-exempt pulse — cycling at ~31% of continuous-sprint cost per disturbance unit (round-1 G1 exploit). The 6.0 s cooldown closes this cadence: legitimate sprint-rest-sprint patterns naturally exceed 6 s of walk; only micro-cadence exploits hit the cooldown.
2. **Light emission** — fired by the server when:
   - The player enters S3b (LanternRaised) — first pulse within `FIRST_PULSE_GRACE_WINDOW = 1.0 s`. Grace-exemption follows the same per-axis cooldown rule as Sprint, applied to the Light axis:
     - If `t_lastGracePulse_light` is `nil` OR `(t_0 - t_lastGracePulse_light) >= GRACE_REENTRY_COOLDOWN`: **grace-exempt**. First pulse fires at `MAGNITUDE_LIGHT_PULSE = 0.08`. Server records `t_lastGracePulse_light = t_0`.
     - Otherwise: not grace-exempt; falls through to magnitude-attenuation.
   - Every `LIGHT_PULSE_INTERVAL = 4 s` thereafter while S3b is active.
   - Call: `DisturbanceService:Emit(emissionType="Light", position=playerWorldPosition, initialMagnitude=MAGNITUDE_LIGHT_PULSE, sourcePlayerId=playerId)`.
   - Same magnitude-attenuation rule as Sprint (the gate applies whenever the pulse is not currently grace-exempt).

   **Cooldown rationale (Pillar 1 closure, Light parallel)**: without the cooldown, a player can toggle lantern on (grace pulse 0.08 fires) → off → on at the 200 ms `RequestLanternToggle` rate-limit floor → on again, producing up to ~2.5 grace pulses/s versus 1 pulse / 4 s for continuous lantern — round-1 review identified this as a **10× exploit factor**, worse than Sprint because the lantern has no stamina-coupled self-limit. The same 6.0 s cooldown closes both axes.

   **Per-axis independence**: `t_lastGracePulse_sprint` and `t_lastGracePulse_light` are tracked independently. Sprinting and raising the lantern within the same window do not interfere — each axis gates its own cooldown. The maximum-loud opening (sprint + lantern simultaneously on a fresh life) is permitted by design.
3. **Position semantics**: `playerWorldPosition` is the SERVER-observed `HumanoidRootPart.Position` at pulse-fire time. Client-predicted positions MUST NOT be used for emission position — the server's view is the authoritative input to Ecological Disturbance.
4. **Server clock**: pulse intervals and grace-window timers MUST use `workspace:GetServerTimeNow()` (per `ED.D.1` — `os.clock()`, `os.time()`, `tick()` are forbidden).

#### C.9 — RemoteEvent Surface (introduced by this controller)

| Event | Direction | Payload | Rate Limit | Server Validation |
|---|---|---|---|---|
| `RequestSprintToggle` | C → S | `{sprint: boolean}` | 10/s/player (debounced — same-state ignored; this event-specific guard does NOT apply to `PlayerHeartbeat`, which is a separate event with no payload) | Player alive; not in S4/S5; if requesting `sprint=true`, stamina > 0 |
| `RequestLanternToggle` | C → S | `{raised: boolean}` | 5/s/player | Player alive; not in S4/S5 |
| `RequestPing` | C → S | `{rayOriginPos, rayDirection, candidateTargetId?}` | per-player 1.0 s + burst 3/1.5 s (per C.4.1) | Alive OR in S4 (dead-spectating); ray origin matches server-tracked position within tolerance; raycast result matches client claim; rate-limit |
| `RequestEmote` | C → S | `{slot: 1..6}` | per-player 3.0 s + burst 5/15 s (per C.4.2) | Alive OR dead-spectating; slot ∈ [1, 6]; rate-limit |
| `PlayerHeartbeat` | C → S | `{}` (no payload) | `HEARTBEAT_SEND_RATE = 1 Hz` per player (server drops excess silently) | Player must be in S2 (Alive-Sprinting); if received while in S1/S4/S5, drop silently. **No same-state guard** — this event is not a state toggle. |
| `OnSprintStateChanged` | S → C (broadcast) | `{playerId, sprinting: boolean}` | On transition only | n/a (server-pushed) |
| `OnLanternStateChanged` | S → C (broadcast) | `{playerId, raised: boolean}` | On transition only | n/a (server-pushed) |
| `OnStaminaChanged` | S → owning C only | `{stamina: 0.0..1.0}` | ≤ 5 Hz | n/a (server-pushed; HUD-only) |
| `OnPingBroadcast` | S → C (squad) | `{playerId, position, category, ttl}` | On valid ping only | n/a (validated before broadcast) |
| `OnEmoteBroadcast` | S → C (squad) | `{playerId, slot, ttl}` | On valid emote only | n/a |
| `OnPlayerDied` | S → C (squad + dead) | `{playerId, deathTimestamp, deathCause}` | On death only | n/a |
| `OnPlayerRespawned` | S → C (squad) | `{playerId, anchorPosition}` | On respawn only | n/a |

**The trust-boundary RemoteEvent registry from game-concept enumerates RE #4 (Ping), #5 (Emote), #7 (Respawn handshake), #10 (Death confirmation).** This GDD's `RequestPing` corresponds to #4; `RequestEmote` to #5; `OnPlayerRespawned` overlaps #7; `OnPlayerDied` overlaps #10. The architecture phase will reconcile via an ADR — see `Section F`.

#### C.10 — Cross-System Interactions Summary

| System | Direction | Interface | Notes |
|---|---|---|---|
| **Ecological Disturbance** | Player Controller → ED | `DisturbanceService:Emit` (Sprint, Light) | Server-side only; per `ED.C.3.2` |
| **Resource Management** | Resource Management → Player Controller | `OnPlayerOxygenExpired` signal triggers death flow | Resource Management GDD owns the trigger; PC subscribes |
| **Resource Management** | Player Controller → Resource Management | Squad oxygen-pool deduction on death | PC fires `RequestSquadOxygenSpend(amount=1)`; RM validates and deducts |
| **Crafting & Items** | Crafting → Player Controller | Beacon-activation triggers victory T8 | Crafting GDD owns the beacon; PC consumes the `OnEscapeBeaconActivated` signal |
| **Predator AI** | Player Controller → Predator AI | Server-tracked player position is the perception input | No new interface — Predator AI reads from the same server state PC writes |
| **HUD** | Player Controller → HUD | Stamina, sprint state, lantern state, ping/emote events | Server-pushed via the C.9 events |
| **Resource Node** | Player Controller → Resource Node | Tap-hold or proximity-gate fires `RequestGather` | RN owns the receive side |

#### C.11 — Testability Contract (clock-injection seam)

**Normative for all time-sensitive logic in this controller**: every read of "current server time" inside Player Controller's services and timers MUST go through a single dependency-injected function reference (the **clock seam**), NOT direct `workspace:GetServerTimeNow()` calls inline at the call site. This is a binding rule for testability.

**The seam:**

```luau
-- Knit service construction (production wiring):
PlayerControllerService.getServerTime = function() return workspace:GetServerTimeNow() end
-- Test wiring (TestEZ / Lemur):
PlayerControllerService.getServerTime = function() return mockedTime end
```

**Why this is mandatory (not optional)**: TestEZ unit tests and Lemur integration tests cannot mock `workspace:GetServerTimeNow()` directly — Roblox's `workspace` global is not patchable from a TestEZ environment, and Lemur shims do not include a per-test override of `GetServerTimeNow`. Without the clock seam, every AC whose GIVEN clause depends on a controlled time value (H.22b, H.22c, H.22d, H.22e, H.22f, H.33a, H.33b — the entire round-3 Path B AC cluster, the round-4 B6 second-death AC, the B8 rollback AC, and the heartbeat-timeout ACs) is **paper-only — it cannot be written into TestEZ as worded**. ACs that cannot be written into TestEZ are not ACs.

**Scope of the seam — every consumer of `workspace:GetServerTimeNow()` inside PC code paths**:

| Call site | Section | Notes |
|---|---|---|
| Sprint pulse interval timer | C.8.1, D.4 | `t_0`, `t_lastGracePulse[Sprint]`, pulse-fire `t` |
| Light pulse interval timer | C.8.2, D.4 | `t_0`, `t_lastGracePulse[Light]`, pulse-fire `t` |
| Stamina regen-delay timer | C.2, D.2 | `t_sprint_end` |
| Respawn timer | C.5.2 | T6 elapsed-30 s computation |
| `_lastHeartbeatTime` updates | E.D | Implicit-first-heartbeat T1 seed; subsequent heartbeat receipts |
| `SPRINT_CLIENT_TIMEOUT` evaluation | E.D | Timeout predicate |
| `lastPredatorDamageTimestamp` writes | F.4 (PredatorService — cross-service) | PredatorService MUST also use a clock seam (same DI pattern, owned by that service); the F.4 row mandates this for consistency |
| C.5.3 imminent-death predicate | C.5.3 | `(now - lastPredatorDamageTimestamp[player]) < HP_ARM_RECENT_WINDOW` and equivalent for `DAMAGE_RECENT_WINDOW` |
| C.5.3 read-and-cache snippet | C.5.3 | The `cachedNow = getServerTime()` first-statement read mirrors the timestamp cache |

**Forbidden after this contract**: any inline `workspace:GetServerTimeNow()` call inside Player Controller's services or any service code path that PC's ACs verify. The architecture phase will enforce this via a code-review rule and a TestEZ helper that throws if any such inline call exists in the indexed paths (cross-service grep gate).

**ED.D.1 alignment**: the existing ED rule "pulse intervals and grace-window timers MUST use `workspace:GetServerTimeNow()`" remains in force at the underlying *primitive* level — the clock seam is a thin wrapper, not a replacement. `getServerTime() = workspace:GetServerTimeNow()` in production. The wrapper's only purpose is to provide a single test-injection point.

**Performance**: a Lua function-pointer indirection per pulse adds <0.001 ms on Roblox VMs — negligible against H.28's 0.1 ms per-frame budget.

## Formulas

### D.1 — Stamina Drain

Per-Heartbeat stamina deduction while in S2 (Alive-Sprinting).

`stamina_new = clamp(stamina - STAMINA_DRAIN_RATE * dt, 0, STAMINA_MAX)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Current stamina | `stamina` | float | 0–100 | Stamina at start of this Heartbeat tick |
| Drain rate | `STAMINA_DRAIN_RATE` | float | 12.5 (locked) | Units drained per second while sprinting |
| Frame delta | `dt` | float | typical 1/60 s on server; up to 1/30 s on slow servers | Seconds elapsed since previous Heartbeat (from `RunService.Heartbeat` event arg) |
| Max stamina | `STAMINA_MAX` | float | 100 (locked) | Upper bound |
| Result | `stamina_new` | float | 0–100 | Stamina after this tick |

**Output Range:** 0 to 100 under normal play; clamp to 0 prevents negative values on lag-spike `dt`.

**Example:** From `stamina = 100` at 60 Hz: each tick drains `12.5 × 1/60 ≈ 0.208` units. Time to deplete: `100 / 12.5 = 8.0 s` exactly.

### D.2 — Stamina Regen

Per-Heartbeat stamina recovery while NOT in S2 AND `(t - t_sprint_end) > STAMINA_REGEN_DELAY`.

`stamina_new = clamp(stamina + STAMINA_REGEN_RATE * dt, 0, STAMINA_MAX)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Current stamina | `stamina` | float | 0–100 | Stamina at start of this Heartbeat tick |
| Regen rate | `STAMINA_REGEN_RATE` | float | 10.0 (locked) | Units recovered per second |
| Frame delta | `dt` | float | typical 1/60 s | Seconds since previous Heartbeat |
| Regen delay | `STAMINA_REGEN_DELAY` | float | 1.5 s (locked) | Wait window before regen begins; gated by caller, not by this formula |
| Result | `stamina_new` | float | 0–100 | Stamina after this tick |

**Output Range:** 0 to 100; upper clamp prevents overshoot.

**Example:** From `stamina = 0`: full recovery takes `100 / 10.0 = 10.0 s` of active regen, plus the 1.5 s delay = **11.5 s wall-clock** from sprint-end to full.

### D.3 — Effective Sprint Duration (derived)

Seconds of uninterrupted sprint until forced-walk, given starting stamina.

`T_sprint(s_0) = s_0 / STAMINA_DRAIN_RATE`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Starting stamina | `s_0` | float | 0–100 | Stamina at the moment of sprint-entry |
| Drain rate | `STAMINA_DRAIN_RATE` | float | 12.5 (locked) | Units/s |
| Result | `T_sprint` | float | 0.0–8.0 s | Seconds until stamina hits 0 |

**Output Range:** 0 to 8.0 s under normal play. At `s_0 = 0`, sprint is blocked immediately (per C.2 rule); the formula returns 0 consistently.

**Example:** `s_0 = 100` → 8.0 s; `s_0 = 50` → 4.0 s; `s_0 = 25` → 2.0 s.

### D.4 — Pulse Emission Magnitude (with stationary gate)

The actual magnitude sent to `DisturbanceService:Emit` for a Sprint or Light pulse. Encodes the grace-window exemption, mobile-drift floor, and stationary attenuation in evaluation order.

```
-- Step 0: Resolve grace eligibility for this pulse (per-axis cooldown)
axis = emissionType  -- "Sprint" or "Light"
grace_eligible = (t_lastGracePulse[axis] == nil)
  OR ((t_0 - t_lastGracePulse[axis]) >= GRACE_REENTRY_COOLDOWN)

-- Step 0a: ANCHOR the cooldown on grace eligibility, NOT on grace-window pass
-- (B9 — closes the missed-grace-window jitter exploit class).
-- If this state-entry resolves as grace_eligible, record t_lastGracePulse[axis] = t_0
-- regardless of whether (t - t_0) is within FIRST_PULSE_GRACE_WINDOW. Under server
-- jitter (thermally-throttled mobile servers), the first pulse of an axis can arrive
-- AFTER the grace window has expired — without this anchor, the cooldown was never
-- recorded, grace_eligible stays true on the next state-entry, and the G1 exploit
-- class re-opens (toggle axis off/on faster than the natural pulse cadence to harvest
-- repeated grace exemptions).
if grace_eligible:
    t_lastGracePulse[axis] = t_0    -- Anchor consumed on eligibility, not on grace-pulse fire

effective_d = (d_xz < MOBILE_ANALOG_DRIFT_THRESHOLD AND platform == "touch") ? 0 : d_xz

if grace_eligible AND (t - t_0) <= FIRST_PULSE_GRACE_WINDOW:
    magnitude_out = magnitude_base
elif effective_d < EMITTER_MOVEMENT_DELTA_FLOOR:
    magnitude_out = magnitude_base * STATIONARY_EMISSION_FACTOR
else:
    magnitude_out = magnitude_base
```

**B9 anchor-on-eligibility rationale (Pillar 1 anti-exploit invariant)**: prior to this fix, the cooldown anchor was recorded only inside the `grace AND grace-window` branch — meaning a state-entry that resolved `grace_eligible = true` but whose first pulse arrived AFTER `FIRST_PULSE_GRACE_WINDOW = 1.0 s` (e.g., server lag-spike pushed the next Heartbeat past `t_0 + 1.0 s`) consumed no anchor. The next state-entry on that axis would still observe `grace_eligible = true` regardless of how soon it fired. **Under thermally-throttled mobile servers — a realistic Roblox condition — this re-opens G1.** Anchoring on eligibility, not on grace-window pass, makes the cooldown a function of *when the player became eligible*, not *whether the server delivered a grace pulse in time*. The cost of an unfortunate jitter pulse is that the player loses one grace exemption they were entitled to; the benefit is that the G1 invariant holds under any server delivery latency.

*Note: the mobile-drift floor applies only when `platform == "touch"` — PC and gamepad players do not have analog-drift to filter, so applying the 2-stud floor on those platforms would create a player-unfriendly false-stationary classification.*

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Server time at pulse | `t` | float | 0–∞ | `workspace:GetServerTimeNow()` at pulse fire |
| State-entry timestamp | `t_0` | float | 0–∞ | `workspace:GetServerTimeNow()` at S2 / S3b entry |
| XZ displacement (raw) | `d_xz` | float | 0–∞ studs | Output of D.6 |
| Effective displacement | `effective_d` | float | 0–∞ studs | `d_xz` after mobile-drift floor applied (touch only) |
| Mobile drift threshold | `MOBILE_ANALOG_DRIFT_THRESHOLD` | float | 2.0 studs (locked) | Touch-only floor below which `effective_d := 0` |
| Movement floor | `EMITTER_MOVEMENT_DELTA_FLOOR` | float | 1.0 stud (locked, ED registry) | Below this, attenuation applies |
| Grace window | `FIRST_PULSE_GRACE_WINDOW` | float | 1.0 s (locked, ED registry) | Post-state-entry window during which gate is bypassed |
| Base magnitude | `magnitude_base` | float | 0.10 (Sprint) or 0.08 (Light) | `MAGNITUDE_SPRINT_PULSE` / `MAGNITUDE_LIGHT_PULSE` from ED registry |
| Attenuation factor | `STATIONARY_EMISSION_FACTOR` | float | 0.30 (locked, ED registry) | Multiplier when stationary gate fires |
| Platform | `platform` | enum | {"pc", "touch", "gamepad"} | Source of the player's input — used to gate the mobile-drift floor |
| Last grace pulse per axis | `t_lastGracePulse[axis]` | float or nil | 0–∞ or nil | The state-entry timestamp `t_0` (NOT the pulse-fire time `t`) at the most recent state-entry on this axis that resolved `grace_eligible == true`. **Anchored on eligibility, not on pulse fire** (B9 round-4 closure) — recorded at the moment the eligibility check passes, even if the grace pulse itself never fires within `FIRST_PULSE_GRACE_WINDOW` due to server jitter. Source: the seam-injected `getServerTime()` per C.11, captured at state-entry. `nil` on first state-entry of this axis this life. Reset to `nil` for both axes on `Humanoid.Died` (T5 side-effect). |
| Grace re-entry cooldown | `GRACE_REENTRY_COOLDOWN` | float | 6.0 s (default; range 4.0–12.0) | Minimum elapsed time from last grace-exempt pulse on this axis before a new state-entry on the same axis qualifies for grace exemption. Per-axis independent. |
| Axis | `axis` | enum | {"Sprint", "Light"} | Identifies which axis this pulse evaluates against. Used for per-axis cooldown lookup. |
| Result | `magnitude_out` | float | {0.024, 0.03, 0.08, 0.10} | Magnitude forwarded to ED |

**Output Range:** Discrete set of four possible values. Sprint full = 0.10; Sprint stationary = 0.03. Light full = 0.08; Light stationary = 0.024. No other values are possible. **Cooldown semantics**: when `grace_eligible = false` and player is moving, output is full; when `grace_eligible = false` and player is stationary, output is attenuated. The cooldown does not introduce new output values; it shifts which branch evaluates for the first pulse of state-entry.

**Example (four cases):**

| # | Type | `t - t_0` | `d_xz` | Platform | `effective_d` | Branch | `magnitude_out` |
|---|---|---|---|---|---|---|---|
| (a) | Sprint | 0.3 s | 0.4 stud | any | 0.4 | grace | **0.10** (full) |
| (b) | Sprint | 4.0 s | 12 studs | pc | 12 | moving | **0.10** (full) |
| (c) | Sprint | 4.0 s | 0.5 stud | pc | 0.5 | stationary | **0.03** (attenuated) |
| (d) | Light | 8.0 s | 0.2 stud | touch | 0 (floor) | stationary | **0.024** (attenuated) |
| (e) | Sprint | 0.3 s | 0.4 stud | any | 0.4 | stationary (cooldown blocked grace) | **0.03** (attenuated) |
| (f) | Light | 0.3 s | 5 stud | pc | 5 | moving (cooldown blocked grace) | **0.08** (full) |

*Examples (e) and (f) demonstrate cooldown-active behavior: the pulse is within `FIRST_PULSE_GRACE_WINDOW` of state-entry (`t - t_0 = 0.3 s`), but `grace_eligible = false` because `(t_0 - t_lastGracePulse[axis]) < GRACE_REENTRY_COOLDOWN` (e.g., 3 s elapsed since last grace pulse vs. 6 s cooldown). The first pulse falls through to the movement-delta gate.*

### D.5 — Stamina-State Joint System (30 s trace)

Validates the player-fantasy intent: "sprint-rest-sprint" rhythm feels sustainable in short bursts but eventually catches up under aggressive repetition.

Pattern: Sprint 4 s → Walk 1 s → Sprint 4 s → Walk 5 s → Sprint 4 s → Walk 12 s.

| Time (s) | State | Event | Stamina | Note |
|---|---|---|---|---|
| 0.0 | Sprint | sprint-1 entry | 100.0 | Full bar at run-start |
| 4.0 | Walk | sprint-1 exit | 50.0 | Drained 50 over 4 s |
| 5.0 | Sprint | sprint-2 entry | 50.0 | Walk-1 was 1 s; regen never started (delay 1.5 s, walk only 1 s) |
| 9.0 | Walk | sprint-2 forced-exit | 0.0 | Sprint-2 lasted exactly 4 s; stamina hit 0 at the 4 s mark — forced-walk engages |
| 10.5 | Walk | regen delay expires | 0.0 | 1.5 s after sprint-2 end |
| 14.0 | Sprint | sprint-3 entry | 35.0 | Walk-2 ran 5 s total; regen for last 3.5 s × 10 = 35 units |
| 16.8 | Walk | sprint-3 forced-exit | 0.0 | Sprint-3 only sustained 2.8 s before forced-walk |
| 18.3 | Walk | regen delay expires | 0.0 | 1.5 s after sprint-3 end |
| 28.3 | Walk | full recovery | 100.0 | 10 s of regen at 10/s |
| 30.0 | Walk | end of trace | 100.0 | Pattern can repeat from here, identically |

**Conclusion:** The pattern repeats stably with a 12 s walk-3 buffer. Cutting walk-3 to <11.5 s would prevent full recovery and cascade the next cycle into earlier forced-walks. This validates the design intent: aggressive sprint-rest-sprint is *temporarily* viable but rewards the player who plans for recovery over the player who chains sprints reflexively.

### D.6 — Movement-Delta Sampling (XZ displacement)

XZ-plane distance of `HumanoidRootPart` between consecutive pulse fire events. Y/vertical motion is discarded — a jump-in-place produces `d_xz = 0`.

`d_xz = sqrt((x_n - x_{n-1})^2 + (z_n - z_{n-1})^2)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Current position | `(x_n, y_n, z_n)` | Vector3 | world space | Server-observed `HumanoidRootPart.Position` at pulse-fire time `t_n` |
| Previous position | `(x_{n-1}, y_{n-1}, z_{n-1})` | Vector3 | world space | Cached position from previous pulse fire; **first-pulse special case** below |
| Result | `d_xz` | float | 0–∞ studs | XZ distance; Y discarded |

**Output Range:** 0 to unbounded under normal play. Teleport-like deltas (e.g., from a Roblox StreamingEnabled chunk-load shift) are bounded only by the engine's actual displacement; the grace-window exemption covers the first pulse and subsequent oversized values pass the gate as "moving" — conservative and safe (oversized values cannot accidentally classify as stationary).

**First-pulse special case:** for the first pulse on state-entry (sprint or light), set `(x_{n-1}, z_{n-1})` to the `HumanoidRootPart.Position` recorded at state-entry timestamp `t_0`. The first pulse fires within `FIRST_PULSE_GRACE_WINDOW`, so D.4's grace-window branch consumes the result regardless of its value. No sentinel needed.

**Examples:**

| # | `(x_{n-1}, y_{n-1}, z_{n-1})` | `(x_n, y_n, z_n)` | Computation | `d_xz` |
|---|---|---|---|---|
| (a) Flat run | (10, 4, 5) | (15, 4, 5) | √(5² + 0²) | 5.0 studs |
| (b) Jump-in-place | (10, 4, 5) | (10, 100, 5) | √(0² + 0²) | 0.0 studs |
| (c) Diagonal run | (10, 4, 5) | (13, 4, 9) | √(3² + 4²) | 5.0 studs |

## Edge Cases

Edge cases are organised by category. Each starts with `**If [condition]**: [exact outcome]. [rationale]` per project edge-case standard.

### E.A — State-Machine Boundary Cases

- **If `Humanoid.Died` fires on the same Heartbeat as a `RequestSprintToggle(sprint=true)`**: T5 (death) takes priority and runs first; T1 (sprint) is discarded. Death pre-empts the locomotion axis. The idempotent death guard runs before any input handler that tick.
- **If `RequestLanternToggle` and `Humanoid.Died` arrive on the same Heartbeat**: T5 fires first; if the player was already in S3b, T4 is fired as part of T5's side-effects (stops the light pulse timer). The toggle request is silently dropped. No light emission fires on that pulse boundary.
- **If sprint and lantern-toggle inputs arrive on the same Heartbeat from S1 + S3a**: both transitions fire. Order: T1 first (locomotion → S2; start sprint pulse timer), then T3 (lantern → S3b; start light pulse timer). Result is the maximum-loud state. Both axes are independent — no conflict.
- **If the server receives `RequestSprintToggle(sprint=true)` while already in S2**: same-state guard rejects silently (per C.9 "debounced — same-state ignored"). No emission, no timer reset, no rate-limit increment.
- **If S2 → S1 (sprint ends) and the lantern pulse interval fires on the same Heartbeat**: the light pulse fires normally — S3b is independent of locomotion. Sprint timer stops; light timer is unaffected. The two timers never share a reset event.

### E.B — Stamina Edge Cases

- **If stamina is 0.4 units and the player sends `RequestSprintToggle(sprint=true)`**: server evaluates `stamina > 0`; 0.4 passes; T1 fires. Player gets ≈ 2 Heartbeat frames (~33 ms at 60 Hz) of sprint before forced-walk. **No special guard needed** — this is correct by the rules; the sprint was legitimately authorized.
- **If the player releases sprint and re-presses sprint within the 1.5 s `STAMINA_REGEN_DELAY` window**: regen delay timer resets to 0 from the most recent sprint-end timestamp. **No "banking" of partial delay progress** — prevents delay-skipping via tap-sprint micro-inputs.
- **If stamina regen would overshoot 100 at the clamp boundary**: D.2's `clamp(s + 10*dt, 0, 100)` handles this; HUD bar receives normalized `1.0`. No floating-point overflow risk.
- **If the server's `dt` spikes to 0.5 s (extreme server lag)**: D.1's `clamp(stamina - 12.5 × 0.5, 0, 100)` is safe regardless of lag magnitude. Sprint state transitions remain valid; server-side lag does not falsely trigger forced-walk.

### E.C — Disturbance Emission at State Boundaries

- **If the player toggles sprint off 0.5 s into a 1.0 s grace window and re-enters sprint 0.3 s later**: re-entry starts a new S2 with a fresh `t_0`. The grace window resets — first pulse on re-entry fires at full magnitude. **Grace is per state-entry, not per session** — the partial grace from the abandoned sprint is discarded.
- **If a touch player spams sprint-toggle faster than 10/s**: `RequestSprintToggle` is rate-limited to 10/s server-side (C.9). Inputs beyond that are dropped. Sprint state reflects only accepted transitions; grace window is anchored to the last accepted T1, so spam cannot manufacture rapid first-pulse sequences. **At most one first-pulse per accepted sprint-entry.**
- **If `FIRST_PULSE_GRACE_WINDOW` is misconfigured to 0.0 s at runtime**: the grace branch `(t - t_0) <= 0.0` is false for every pulse (since `t > t_0` by at least one Heartbeat). Every pulse falls through to the movement-delta gate; the first pulse attenuates if the player has not moved 1 stud since state entry. **Behavior degrades gracefully — no crash. QA tuning validation should flag a grace window of 0 as out-of-range.**
- **If a player is simultaneously in S2 + S3b and both pulse timers fire on the same Heartbeat**: both emissions submit independently — one Sprint, one Light. They share `playerWorldPosition` but are distinct sources in ED's live-source list with distinct `emissionType`. **No deduplication** — concurrent use is the maximum-loud state.
- **If a player enters S2 within `GRACE_REENTRY_COOLDOWN` of their last Sprint-axis grace-exempt pulse**: the first pulse is not grace-exempt. D.4 falls through to the movement-delta gate. If the player is moving (`d_xz >= EMITTER_MOVEMENT_DELTA_FLOOR`), the first pulse fires at full magnitude 0.10 — the predator still hears the sprint commitment. If the player is stationary, the first pulse fires at 0.03. **The G1 exploit is closed because the stationary-bypass that created it is withheld; a moving sprinter pays the correct cost either way.**
- **If a player enters S3b within `GRACE_REENTRY_COOLDOWN` of their last Light-axis grace-exempt pulse**: same rule as above, applied to the Light axis. Moving: first pulse 0.08; stationary: first pulse 0.024. **Closes the lantern toggle-cycle exploit (10× factor identified in round-1 review).**
- **If a player enters S2 (or S3b) on a NEW LIFE (post-respawn)**: `t_lastGracePulse_sprint` and `t_lastGracePulse_light` are both `nil` (reset on `Humanoid.Died` per T5 side-effect). The player's first sprint and first lantern raise post-respawn are both grace-exempt. **Per Pillar 4 (Rounds Not Saves)**: each life is its own experience; carrying grace-cooldown across a respawn would be opaque and feel unfair.
- **If a player enters S2 and S3b in rapid succession (e.g., sprint + lantern within 2 seconds, both on a fresh life)**: each axis evaluates its own cooldown independently. Both axes fire grace-exempt first pulses. **Sprint and Light grace-exemptions are not coupled** — entering one axis does not trigger the cooldown on the other. The maximum-loud opening (sprint + lantern at the same time) is permitted by design; the controller publishes both pulses, and the predator hears both commitments.
- **If `GRACE_REENTRY_COOLDOWN` is tuned below `max(SPRINT_PULSE_INTERVAL + STAMINA_REGEN_DELAY, LIGHT_PULSE_INTERVAL) = 4.0 s`**: the exploit partially reopens — a player could re-enter the axis with a fresh grace-exempt pulse before the natural pulse cadence has even fired once. **QA tuning validation MUST enforce `GRACE_REENTRY_COOLDOWN >= 4.0 s`.** Default 6.0 s provides 2.0 s safety margin.

### E.D — Cross-Platform Input Edge Cases

- **If a PC player plugs in a gamepad mid-session while sprinting**: the platform classifier updates on the next input event. Both KB+M and gamepad use sprint-hold semantics (no behavioral change). The controller does not need to reconcile mid-sprint platform transitions — sprint state is server-authoritative; release fires regardless of source device.
- **If a touch-screen PC (Surface-class hybrid) receives both a touch input and a simultaneous keyboard input**: Roblox `UserInputService` treats them as independent streams. Server accepts the first valid `RequestSprintToggle` / `RequestLanternToggle`; same-state dedup drops the second. **Platform classifier uses the most-recent input event type** to determine drift-floor logic — touch inputs use `MOBILE_ANALOG_DRIFT_THRESHOLD`; keyboard inputs do not.
- **If a Bluetooth gamepad disconnects mid-sprint (L3 released by disconnect)**: the Roblox client receives `GamepadDisconnected` and MUST synthesize `RequestSprintToggle(sprint=false)`. This is the **cooperative path**.

  **Server-side timeout safety (independent of client cooperation)**: the server maintains a per-player timestamp `_lastHeartbeatTime` updated by each valid `PlayerHeartbeat` receipt. While a player is in S2 (Alive-Sprinting), the client MUST send `PlayerHeartbeat` at `HEARTBEAT_SEND_RATE = 1 Hz`. If `(workspace:GetServerTimeNow() - _lastHeartbeatTime[player]) > SPRINT_CLIENT_TIMEOUT = 3 s`, the server forces transition T2 (WalkSpeed → `WALK_SPEED`; stop sprint pulse timer; start `STAMINA_REGEN_DELAY` timer). This prevents ghost-sprint from zombie clients (frozen process, suspended mobile app, or lost `GamepadDisconnected` synthesis).

  **`_lastHeartbeatTime` lifecycle (load-bearing for the timeout-safety rule above)**:

  - **Init on T1 entry (sprint-start) — the implicit first heartbeat**: when T1 fires, the server sets `_lastHeartbeatTime[player] = workspace:GetServerTimeNow()` **before** the timeout check arms. The state-entry timestamp counts as the implicit first heartbeat. Without this rule, every legitimate sprint-after-walk-pause longer than `SPRINT_CLIENT_TIMEOUT = 3 s` would force-revert immediately because the timeout predicate would compare `now` against either `nil` or a stale prior-sprint timestamp.
  - **First-heartbeat grace window**: because T1 seeds the timestamp to `now`, the player has the full `SPRINT_CLIENT_TIMEOUT` window (3 s) to send their first explicit `PlayerHeartbeat` after sprint entry before timeout fires. No additional grace window beyond this is required — the implicit first heartbeat IS the grace window.
  - **Clearance on T2 (sprint exit, any path)**: when T2 fires (input release, stamina = 0, force-walk, server timeout itself), the server sets `_lastHeartbeatTime[player] = nil`. Subsequent `PlayerHeartbeat` events from this player are dropped per the S2-only validation rule (next paragraph).
  - **Clearance on T5 (death)**: T5's sprint-state hard-reset side-effect (per C.5.5 / C.6 transition table) sets `_lastHeartbeatTime[player] = nil`. Prevents a stale timestamp from blocking the next life's first sprint.
  - **Clearance on `Players.PlayerRemoving`**: the `PlayerRemoving` handler clears `_lastHeartbeatTime[player] = nil` alongside other per-player state cleanup. Ensures no stale entry survives into a subsequent session under the same userId.
  - **No write on `Players.PlayerAdded`**: the table entry is created lazily by T1; before T1 the player is in S1 and the timeout check is irrelevant. The table itself is initialized to `{}` (empty, not `nil`) at `PlayerControllerService` bootstrap so lookups never throw on `nil` indexing.

  This lifecycle closes the Theme-1-round-2 network-programmer finding ("`_lastHeartbeatTime` initialization on T1 unspecified — every legitimate sprint-after-walk-pause >3 s would force-revert immediately"). T1 always seeds a fresh timestamp; T2/T5/`PlayerRemoving` always clear it; the table is bootstrap-initialized to defend the lookup.

  **`PlayerHeartbeat` is NOT a sprint-authorization signal** — it carries no payload, performs no stamina reset, executes no state mutation other than updating `_lastHeartbeatTime`. **Sprint terminates at stamina = 0 regardless of heartbeat continuity** (T2 still fires from the stamina drain loop). Heartbeats MUST NOT be sent while in S1, S4, or S5 — server drops any `PlayerHeartbeat` received from a player not in S2.

  **Pillar 1 closure**: round-1 review found the heartbeat signal was undefined, leaving `SPRINT_CLIENT_TIMEOUT` either unenforceable (if heartbeat = `RequestSprintToggle` under same-state guard) or exploitable (if no same-state guard, attacker chains toggles every 2.9 s for indefinite sprint). The dedicated zero-payload `PlayerHeartbeat` event closes both interpretations.
- **If a third finger contacts the screen within `PING_TWO_FINGER_WINDOW = 150 ms`**: per C.7 rules, a third touch within the window cancels and suppresses the ping. **No cooldown is charged** — suppressed pings do not consume the rate-limit budget. Defends against palm-rest false-pings during predator encounters.

### E.E — Death and Respawn Edge Cases

- **If a player dies while in S2 (sprinting) + S3b (lantern) + tap-hold gather in progress**: T5 fires; side-effect order is (1) stop sprint pulse timer, (2) stop light pulse timer, (3) freeze stamina, (4) NO additional emission fires (death does not emit), (5) deduct 1 squad oxygen, (6) cancel in-progress gather (the gather node stays un-gathered — no `RequestGather` completes), (7) client receives `OnPlayerDied` and locks movement/lantern/gather inputs. **The gather ring UI animates to a "cancelled" state client-side.**
- **If a player disconnects during their 30 s respawn timer**: the squad oxygen cost was deducted at death (per C.5.3). Disconnect does not trigger a second deduction. **Server does NOT refund the oxygen on disconnect** — the cost was the act of dying, not the act of returning. The respawn timer is abandoned; the disconnected player is not counted toward squad-survives in subsequent run-end evaluation.
- **If a player who is ALIVE disconnects and the imminent-death predicate is satisfied** (`(Humanoid.Health < HP_IMMINENT_THRESHOLD AND lastPredatorDamageTimestamp[player] ~= nil AND (now - lastPredatorDamageTimestamp[player]) < HP_ARM_RECENT_WINDOW)` OR `(lastPredatorDamageTimestamp[player] ~= nil AND (now - lastPredatorDamageTimestamp[player]) < DAMAGE_RECENT_WINDOW)` — both arms predator-scoped via the nil-check, both arms time-bounded against the predator timestamp; full predicate spec lives in C.5.3): server invokes T5 from the `PlayerRemoving` handler. 1 squad oxygen deducted; `OnPlayerDied(deathCause="disconnect-while-damaged")` broadcast; sprint state cleared. The player is removed immediately after T5 completes — no respawn timer, no spectator camera, no death animation (the player is no longer present to receive them). **The exploit "disconnect before `Humanoid.Died` fires to avoid the cost" is closed at the rule level**, AND non-predator near-death disconnects (oxygen-depletion ticks at low HP, fall damage, environmental hazard) pay nothing because both arms require a non-nil predator timestamp within the relevant recency window.
- **If `Humanoid.Died` and `Players.PlayerRemoving` fire in the same or adjacent Heartbeat** (lethal damage and network disconnect detected at the same tick): the idempotent `_deathCostPaid` guard ensures exactly one oxygen deduction. Whichever path runs first sets the flag; the second is a no-op. **No ordering assumption is required across the two events** — the guard alone resolves the race.
- **If a player in S4 (Dead-Respawning) disconnects**: `_deathCostPaid` is already `true` (set when T5 ran at death). The `PlayerRemoving` handler checks the flag and is a no-op. Squad oxygen is NOT deducted a second time. The respawn timer is abandoned. Behavior is identical to the rule for mid-respawn disconnect above — this case is now **subsumed by the idempotency guarantee** rather than a special-case rule.
- **If a player disconnects and reconnects within seconds (Wi-Fi flap)**: the disconnecting session's `PlayerRemoving` runs the predicate; if satisfied + `_deathCostPaid == false`, oxygen is deducted ONCE for that session. The reconnecting session via `PlayerAdded` initializes a fresh `_deathCostPaid = false` for the new session-instance. **The reconnecting player is NOT re-charged for the prior session's imminent-death state** — the flag is per-session, not per-userId. Cost is paid exactly once if the predicate fired; not at all if it didn't.
- **If the server crashes between `RequestSquadOxygenSpend` firing and Resource Management's DataStore write completing**: the oxygen deduction may not persist. This is a ProfileStore write-path concern owned by **Resource Management GDD**. Player Controller's obligation is limited to firing `RequestSquadOxygenSpend` before the player's data context closes — `PlayerRemoving` in PC fires before ProfileStore's own `PlayerRemoving` handler (Roblox event ordering: game-script connections run before framework teardown for the same signal). The durability guarantee lives in Resource Management.
- **If two players die on the same Heartbeat (e.g., predator sweep)**: each death handler fires independently (idempotent guard is per-player). Each deducts 1 squad oxygen. **Two oxygen units are deducted**, not one shared. If the second deduction would reduce oxygen below 0, Resource Management clamps at 0 and T7 (run-end) evaluates after both deaths resolve.
- **If a player in S4 (Dead-Respawning) sends `RequestPing`**: **ALLOWED** per C.5.4. (C.9 validation reads "Alive OR in S4 (dead-spectating)".)
- **If the spectator camera attempts to follow a teammate into a chunk that has not loaded**: camera freezes at the chunk boundary per C.5.6 until chunk-load confirmation. Dead player's spectate input continues to be accepted (they can re-target to a teammate in a loaded chunk). **No void-fall occurs.**

### E.F — Squad Coordination Edge Cases

- **If `RequestPing` arrives on the exact Heartbeat the cooldown timer expires**: server evaluates `(now - lastPingTime) >= PING_COOLDOWN_PER_PLAYER`. Using `>=` (not `>`), a request at the exact boundary is **accepted**. Off-by-one-frame denials at the exact boundary are poor UX and the burst cap already governs abuse.
- **If a player opens the emote wheel and is killed before selecting**: T5 fires; the emote wheel state is client-local (server does not track "wheel is open"). **Client `OnPlayerDied` handler MUST close the emote wheel UI.** No partial emote fires. No cooldown charged for the abandoned open.
- **If two players send `RequestPing` targeting the same entity in the same Heartbeat**: server broadcasts both independently. **No deduplication.** Two overlapping ping markers appear on the squad UI — by design, two players independently flagging the same threat reinforces urgency rather than silencing one.
- **If a quick-ping raycast hits two tagged entities whose bounding volumes overlap at the ray's hit point**: server uses Roblox's first-hit ordering (front-most by ray distance). If the client's `candidateTargetId` matches the server's raycast result, the tagged ping fires. **If they disagree (replication lag), the server's result wins** — the client's candidate is advisory only.
- **If a player on touch opens the emote wheel and a `GatherNodeArmed` event arrives**: the wheel-open state suppresses tap-hold gather per T9. The contextual prompt is rendered (server armed it), but right-thumb gather input is locked. **Player must close the wheel first.** Arm state persists until the player moves out of range.

## Dependencies

Per `ED.F.3a` (Cross-GDD Author Checklist, round-3 addition), this section embeds the bidirectional dependency contract.

### F.1 — Hard Dependencies (Player Controller cannot function without)

| Upstream System | What this GDD consumes | Status |
|---|---|---|
| **Roblox `Humanoid`** | Movement primitive (`WalkSpeed`, `MoveTo`, `Died` event, jump). Engine built-in — no GDD; verified against `docs/engine-reference/roblox/`. | Built-in |
| **Roblox `UserInputService` + `ContextActionService`** | Cross-platform input routing (touch/mouse/gamepad). Engine built-in. | Built-in |
| **Ecological Disturbance** (`design/gdd/ecological-disturbance.md`) | `DisturbanceService:Emit("Sprint" \| "Light", position, magnitude, sourcePlayerId)` per `ED.C.3.2`. Locked constants: `EMITTER_MOVEMENT_DELTA_FLOOR`, `STATIONARY_EMISSION_FACTOR`, `FIRST_PULSE_GRACE_WINDOW`, `SPRINT_PULSE_INTERVAL`, `LIGHT_PULSE_INTERVAL`, `MAGNITUDE_SPRINT_PULSE`, `MAGNITUDE_LIGHT_PULSE`. | **GDD exists** — round-6 fresh-session re-review pending |
| **Knit framework** | Service/Controller pattern; `Service:Client` bridge for RemoteEvents. Confirmed at engine setup. | Built-in framework |

### F.2 — Soft Dependencies (Player Controller is enhanced by, but is not blocked on, these — provisional contracts apply until the dependency GDD is authored)

| System | Direction | Interface | Status |
|---|---|---|---|
| **Resource Management** | RM → PC | `OnPlayerOxygenExpired(playerId)` signal triggers death flow per C.5.1 (oxygen-empty + grace expiry) | Not Started — provisional contract |
| **Resource Management** | PC → RM | `RequestSquadOxygenSpend(amount=1, reason="death")` on T5 fire per C.5.3 | Not Started — provisional contract |
| **Crafting & Items** | Crafting → PC | `OnEscapeBeaconActivated()` fires T8 (squad escape → victory) per C.6 | Not Started — provisional contract |
| **Crafting & Items** | PC → Crafting | `RequestInteract(targetId)` for beacon, crafting bench. Crafting GDD owns receive-side validation. | Not Started — provisional contract |
| **Resource Node** | PC → RN | `RequestGather(nodeId)` fired on tap-hold complete (C.7) or proximity-gate commit. RN owns receive-side. | Not Started — provisional contract |
| **Resource Node** | RN → PC | `GatherNodeArmed(nodeId)` / `GatherNodeDisarmed(nodeId)` for the proximity-gate prompt UI per C.7 | Not Started — provisional contract |
| **Predator AI** | PC → Predator AI | Server-tracked player position (`HumanoidRootPart.Position` on server) is the perception input — **no new interface**; Predator AI reads from the same server state PC writes. Player Controller does not push position; it just is the position. | Not Started — provisional contract |
| **HUD** | PC → HUD | `OnSprintStateChanged`, `OnLanternStateChanged`, `OnStaminaChanged`, `OnPingBroadcast`, `OnEmoteBroadcast`, `OnPlayerDied`, `OnPlayerRespawned` (per C.9). HUD owns the rendering. | Not Started — provisional contract |
| **Camera** (future GDD — not in current systems-index) | PC → Camera | Spectator-camera input affordance during S4 (dead-respawning). PC fires the input; Camera owns the visual. | Not in systems-index — flagged as a missing system |

### F.3 — Reverse-Cite to ED.F.2a (Predator AI Deferred Contracts)

Per `ED.F.2a`, the Ecological Disturbance GDD lists obligations the Predator AI GDD must reverse-cite when authored. Player Controller has its own row in that table — Q9 movement-delta detection, Q11 Calm-tier first-zone teaching beat, F.3a author-checklist obligations, `EMITTER_MOVEMENT_DELTA_FLOOR` interval-sampling logic, Tier-2 #17 mobile-touch analog-drift threshold (≥ 2 studs), Tier-2 #16 `FIRST_PULSE_GRACE_WINDOW` state-entry timer.

**All of these are resolved in this GDD:**

| ED.F.2a obligation | Resolution in this GDD |
|---|---|
| Q9 movement-delta detection logic | C.7 (mobile drift floor); C.8.1 + C.8.2 (stationary attenuation in emission contract); D.4 (formula); D.6 (sampling) |
| Q11 Calm-tier first-zone teaching beat | F.4 row (level-design dependency, not coded in PC) — see below |
| F.3a author-checklist obligations | This section — F |
| `EMITTER_MOVEMENT_DELTA_FLOOR` interval-sampling logic | D.6; C.7 |
| Tier-2 #17 mobile-touch analog-drift threshold | C.7 (`MOBILE_ANALOG_DRIFT_THRESHOLD = 2 studs`); D.4 platform gate |
| Tier-2 #16 `FIRST_PULSE_GRACE_WINDOW` state-entry timer | C.8.1 + C.8.2; D.4 grace branch |

### F.4 — Open Cross-System Obligations Player Controller Owes Forward

| Receiving System | Obligation Player Controller owes | Notes |
|---|---|---|
| **Level Design** | Q11 Calm-tier first-zone authoring beat. The first zone of a fresh run MUST be Calm-tier (Disturbance < `TENSE_THRESHOLD = 0.30`). PC does not implement this — PC's role is to ensure the first sprint/light emission in the first zone is *teachable*, i.e., the player can connect "I sprinted" to "the disturbance level rose." | Level-design responsibility; called out here so the obligation is bidirectionally visible. |
| **Predator AI** | Server-tracked player positions are the canonical perception input. Player Controller MUST NOT introduce client-predicted positions into any cross-system perception path. | Server-authoritative position is the only valid input for Predator AI. |
| **Predator AI** | `PredatorService` MUST maintain a server-internal `lastPredatorDamageTimestamp` table — **keyed by `Player` instance object, not `userId`** (a rejoining player under the same userId is a fresh `Player` instance and therefore a fresh key — defends against stale-entry false-positives across a Wi-Fi flap reconnect). Readable by Player Controller's `PlayerRemoving` handler for the C.5.3 Path B imminent-death predicate. **PC reads but does not write this table.** Lifecycle is load-bearing for C.5.3 Path B correctness:<br>• **Bootstrap init**: `PredatorService` MUST initialize the table to `{}` (empty, NOT `nil`) before any `Players.PlayerAdded` can fire — i.e., during PredatorService construction, before `Knit:Start()` returns. The C.5.3 predicate's nil-guard depends on the table itself existing; `nil` table indexing would crash the predicate.<br>• **On `Players.PlayerAdded`**: do NOT write — leave the entry as `nil` for new joiners. The C.5.3 predicate treats a `nil` entry as "no recent predator damage" via the short-circuit AND (`lastPredatorDamageTimestamp[player] ~= nil`).<br>• **On predator-damage application**: write `lastPredatorDamageTimestamp[player] = getServerTime()` (via the C.11 clock-injection seam, NOT direct `workspace:GetServerTimeNow()`). This is the ONLY writer of the table (Pillar 2 — non-predator damage MUST NOT write here).<br>• **On T6 (respawn)**: clear the entry — `lastPredatorDamageTimestamp[player] = nil`. Each new life starts with no predator damage history. Without this, a player respawning after a death where the predator hit them within `DAMAGE_RECENT_WINDOW` would still satisfy the predicate's time arm, double-charging on a subsequent disconnect-while-low-HP from non-predator causes.<br>• **On `Players.PlayerRemoving`**: clear the entry — `lastPredatorDamageTimestamp[player] = nil`. Belt-and-braces against any indirect retention path; the `Player` keying already prevents userId-level rejoin staleness, but explicit clearance is mandatory.<br>• **Cross-service teardown ordering contract (load-bearing for C.5.3 Path B)**: Knit's `PlayerRemoving` connection ordering across services is non-deterministic. PredatorService's own `PlayerRemoving` handler may run before, concurrently with, or after PC's `PlayerRemoving` handler. **PC must not depend on PredatorService having NOT cleared the entry yet at PC's handler entry.** PC closes this by reading-and-caching `lastPredatorDamageTimestamp[player]` as the first statement of its handler (per C.5.3 read-and-cache discipline). Belt-and-braces option: PredatorService MAY defer its clearance to the next Heartbeat after `PlayerRemoving` (e.g., `task.defer(...)` the clear) so PC's same-frame read is guaranteed to see the live value — but this is OPTIONAL; the binding contract is on PC's cache-first ordering, not on PredatorService's deferral.<br>• **Player instance key validity on `PlayerRemoving`**: the `player` argument passed to the `PlayerRemoving` callback is still a valid `Player` instance for the duration of the handler — Roblox guarantees the instance is not destroyed until all `PlayerRemoving` connections have run (one source of the cross-service connection-ordering non-determinism). PC's read of `lastPredatorDamageTimestamp[player]` and `player.Character.Humanoid.Health` are both safe within the handler's synchronous span; the `Character` model and `Humanoid` MAY be `nil` (e.g., after `LoadCharacter`/`Destroy` interleaving), so the C.5.3 read-and-cache snippet uses a `FindFirstChild` + nil-coalesce to protect the health read. | Cross-system invariant for cost attribution; lifecycle expanded in Theme-1-round-2 patch + round-4 cross-service ordering contract (closes ai-programmer + performance-analyst convergent finding on stale-rejoin entries, ai-programmer + network-programmer convergent finding on init-order race, AND network-programmer C2 + ai-programmer F2 round-4 convergence on PlayerRemoving teardown-order race). |
| **HUD** | Stamina HUD bar must update at ≤ 5 Hz (per C.9 `OnStaminaChanged` rate limit). HUD MUST NOT request a higher refresh rate. | Bandwidth budget defence. |
| **Architecture (`/create-architecture`)** | Four ADRs flagged for authorship (per gameplay-programmer feasibility consult): (1) Sprint-State Authority Model, (2) Stamina Drain/Regen Lifecycle, (3) Player Controller RemoteEvent Trust Boundary, (4) Dead-Player Input Lock and Spectator State. | Architecture phase deliverable. |
| **All future GDDs** | The cosmetic-boundary rule (game-concept) means no equipped cosmetic may change WalkSpeed, lantern brightness, sprint-emission magnitude, light-emission magnitude, or any other input the predator AI consumes. Cosmetic items that touch this controller MUST pass the cosmetic-boundary checklist. | Live-ops + monetization defence. |

### F.5 — Engine and Library Dependencies

| Dependency | Used For | Verification |
|---|---|---|
| `Humanoid.WalkSpeed`, `Humanoid.Died`, `Humanoid.Health` | Locomotion + death | Engine built-in; verified |
| `HumanoidRootPart.Position` | Movement-delta sampling, emission position, ping raycast origin | Engine built-in; verified |
| `RunService.Heartbeat` | Stamina drain/regen tick | Engine built-in; verified |
| `workspace:GetServerTimeNow()` | All server-side timing (pulse intervals, grace window, regen delay, respawn timer) per ED.D.1 | Engine built-in; verified |
| `UserInputService` | Touch / mouse / gamepad input | Engine built-in; verified |
| `UserInputService.TouchStarted` | Two-finger ping gesture detection (per-frame accumulator pattern in client controller) | Engine built-in; verified |
| `ContextActionService` | Cross-platform action binding | Engine built-in; verified — but does NOT natively express multi-touch gestures (per gameplay-programmer flag) |
| `HapticService` | Optional gamepad rumble for state transitions / death feedback | Engine built-in; **wrap calls in `IsMotorSupported()` guard** per gameplay-programmer flag |
| `workspace:HasChunkLoaded()` (or current-name equivalent) | Spectator camera StreamingEnabled chunk-load gate per C.5.6 + E.E | **Verify API name against current Roblox Creator Docs before architecture** — flagged as knowledge-gap risk |
| Knit `Service`, `Controller`, `Signal` | Cross-boundary RemoteEvent helpers (per `current-best-practices.md`) | Library; confirmed at engine setup |

## Tuning Knobs

All knobs are **server-authoritative** and live in a single config module (consumed by Knit `PlayerControllerService`). Categories: **Feel** (player-perceived responsiveness), **Curve** (drives a formula), **Gate** (rate-limit / threshold). Knobs flagged "**ED-locked**" are owned by the Ecological Disturbance registry and **MUST NOT** be redefined here — listed only to surface their relevance.

### G.1 — Locomotion Knobs

| Knob | Default | Range | Category | Section | Too Low | Too High |
|---|---|---|---|---|---|---|
| `WALK_SPEED` | 12 studs/s | 8–16 | Feel | C.1 | Movement feels punishment-slow; squad pacing breaks; gather travel time exceeds 5–20 min run window | Walk feels arcade-y; "fragile body" fantasy lost; sprint differentiation collapses |
| `SPRINT_SPEED` | 20 studs/s | 16–28 | Feel | C.1 | Sprint feels like fast-walk; loud-action distinction lost | Mobile touch precision degrades >24; players overshoot interaction targets |

### G.2 — Stamina Knobs

| Knob | Default | Range | Category | Section | Too Low | Too High |
|---|---|---|---|---|---|---|
| `STAMINA_MAX` | 100 units | 60–200 | Curve | C.2, D.1 | Sprint windows feel trivial; "deliberate transaction" fantasy collapses | Sprint is effectively unlimited; Pillar 1 weakens |
| `STAMINA_DRAIN_RATE` | 12.5 units/s | 8–20 | Curve | C.2, D.1, D.3 | Sprint duration feels generous (12+ s at default max); Pillar 1 weakens | Sprint windows shorten to <5s; aggressive players never escape predator |
| `STAMINA_REGEN_RATE` | 10 units/s | 5–18 | Curve | C.2, D.2 | Recovery takes >20s; sprint feels punishing | Recovery feels free; sprint-rest-sprint becomes optimal everywhere |
| `STAMINA_REGEN_DELAY` | 1.5 s | 0.5–4.0 | Feel | C.2, D.2 | Bar twitches on partial-sprint inputs; tap-sprint micro-management feels noisy | Felt as "broken regen"; punishment perception |

**Coupled tuning note**: `STAMINA_DRAIN_RATE` and `STAMINA_REGEN_RATE` define the spend/recovery asymmetry (default ratio 0.8). Adjusting either independently breaks the design intent that "sprint everywhere, walk on empty" is a losing strategy. Tune as a coupled pair.

### G.3 — Lantern Knobs

| Knob | Default | Range | Category | Section | Too Low | Too High |
|---|---|---|---|---|---|---|
| `LANTERN_VISIBILITY_RADIUS` | 20 studs | 12–40 | Feel | C.3 | Dark zones become navigationally hostile; players keep lantern up constantly | Lantern reduces tension; "where safety ends" rule weakens |

### G.4 — Coordination Knobs

| Knob | Default | Range | Category | Section | Too Low | Too High |
|---|---|---|---|---|---|---|
| `PING_DISPLAY_DURATION` | 8 s | 3–15 | Feel | C.4.1 | Pings disappear before squad reads them | Stale pings clutter HUD; ping volume in 4-player squads becomes overwhelming |
| `PING_COOLDOWN_PER_PLAYER` | 1.0 s | 0.5–3.0 | Gate | C.4.1, E.F | Ping spam from a single player floods squad HUD | Pings feel unresponsive in fast encounters |
| `PING_BURST_CAP` | 3 | 2–6 | Gate | C.4.1 | Single-player burst pinging in danger sequences feels unresponsive | Burst-cap stops gating spam |
| `PING_BURST_WINDOW` | 1.5 s | 1.0–5.0 | Gate | C.4.1 | Burst window too tight, legitimate fast-pings denied | Burst window too wide, spam tolerance returns |
| `PING_RAYCAST_RANGE` | 80 studs | 40–200 | Feel | C.4.1 | Pings can't reach distant threats; players feel unequipped to flag distant predators | Pings reach across map; intel becomes too cheap |
| `PING_TWO_FINGER_WINDOW` | 150 ms | 80–300 | Feel | C.7, E.F | Legitimate two-finger taps register as separate touches; quick-ping is unreliable on touch | Palm-rest false-pings register as intentional |
| `EMOTE_COOLDOWN_PER_PLAYER` | 3.0 s | 1.0–10.0 | Gate | C.4.2 | Emote spam clutters HUD | Emotes feel unresponsive; coordination signal degrades |
| `EMOTE_BURST_CAP` | 5 | 3–10 | Gate | C.4.2 | Burst tolerance too low; legitimate fast-emote sequences blocked | Burst tolerance too high; spam re-emerges |
| `EMOTE_BURST_WINDOW` | 15.0 s | 10.0–60.0 | Gate | C.4.2 | Window too short to detect spam patterns | Window too wide; legitimate sequential emoting feels rate-limited |
| `EMOTE_DISPLAY_DURATION` | 4 s | 2–8 | Feel | C.4.2 | Emotes vanish before squad reads | Emote markers persist past relevance; HUD clutter |

### G.5 — Touch-Input Knobs

| Knob | Default | Range | Category | Section | Too Low | Too High |
|---|---|---|---|---|---|---|
| `TAP_HOLD_COMMIT_DURATION` | 500 ms | 300–800 | Feel | C.7 | Accidental holds register as commits; mis-tap defence weakens | Gather feels unresponsive on PC; accusations of "stuck input" |
| `GATHER_PROXIMITY_RADIUS` | 4 studs | 2–8 | Gate | C.7 | Gate disarms during slow approach; player must stop *exactly* on the node | Gate arms from too far; player can pre-arm gather while still walking past |
| `MOBILE_ANALOG_DRIFT_THRESHOLD` | 2 studs | 1–4 | Gate | C.7, D.4 | Real player movement classified as drift; emissions falsely attenuate | Genuine analog drift not filtered; stationary players unintentionally publish full-magnitude pulses |

### G.6 — Death/Respawn Knobs

| Knob | Default | Range | Category | Section | Too Low | Too High |
|---|---|---|---|---|---|---|
| `RESPAWN_DELAY` | 30 s | 10–60 | Feel | C.5 | Death feels inconsequential; squad doesn't feel the loss; Pillar 2 (shared risk) weakens | Death feels punishing; dead player loses interest before respawn; Pillar 2 (squad cohesion) weakens |
| `SPRINT_CLIENT_TIMEOUT` | 3 s | 1–10 | Gate | E.D | Legitimate brief client lag (mobile reconnect flap) classified as zombie; sprint reverts during a valid session momentary hitch | Ghost-sprint persists up to N seconds after client becomes unresponsive; up to `N / SPRINT_PULSE_INTERVAL` extra pulses emitted |
| `HEARTBEAT_SEND_RATE` | 1 Hz | 0.5–2 | Gate | E.D, C.9 | Heartbeats arrive too infrequently; `SPRINT_CLIENT_TIMEOUT` fires spuriously during legitimate high-jitter connections | Heartbeat traffic exceeds bandwidth budget; at 2 Hz × 4 players × 40 bytes ≈ 320 B/s — still within H.29 budget but approaching it |
| `GRACE_REENTRY_COOLDOWN` | 6.0 s | 4.0–12.0 | Gate | C.8.1, C.8.2, D.4, E.C | Below 4.0 s the cadence exploit partially reopens (per-axis math floor `max(SPRINT_PULSE_INTERVAL + STAMINA_REGEN_DELAY, LIGHT_PULSE_INTERVAL) = 4.0`); legitimate second-sprint feels invisible but exploit re-emerges | Above 12 s a player who genuinely sprinted hard, walked 11 s to recover, and sprinted again finds their second sprint silenced — punishes legitimate long-sprint sequences |

**G.6 invariants for `GRACE_REENTRY_COOLDOWN` (B9 anchor-on-eligibility rule)**:

1. The cooldown anchor `t_lastGracePulse[axis] = t_0` is written when `grace_eligible == true` is *resolved at state-entry*, NOT when the grace-window pulse fires. Under server jitter (e.g., thermally-throttled mobile Heartbeat tick longer than 1.0 s), the first pulse may arrive after `FIRST_PULSE_GRACE_WINDOW`. The cooldown still holds because the anchor was recorded at eligibility resolution, not at pulse fire.
2. **G1 exploit class is closed under any server delivery latency** because the cooldown is a function of when eligibility was *granted*, not of whether the grace pulse was *delivered* on time. A player who toggles sprint off/on under thermally-throttled latency cannot harvest repeated grace exemptions by exploiting the missed-window state.
3. The trade-off is a cost the *player* pays under jitter (they may forfeit one grace exemption they were entitled to under nominal latency), not a cost the *predator* pays. Pillar 1 enforcement strictly biases toward cost-paid; never toward cost-skipped.
| `HP_ARM_RECENT_WINDOW` | 30.0 s | 15–60 | Gate | C.5.3, E.E | Legitimate "lethal combo in flight" disconnects misclassified as non-predator (player took heavy graze, ran 20 s, disconnected at low HP — predator IS proximate cause but the window already expired); Pillar 2 false-negative class | Stale-graze false-positive class re-opens — slow oxygen-depletion death after a long-ago predator brush starts paying squad cost again; Pillar 2 false-positive class (the round-3 defect this knob closes) |

**G.6 boundary-comparator semantics (B11)**: `HP_IMMINENT_THRESHOLD` is compared with strict `<` (HP=25.0 exactly does NOT fire arm 1). `HP_ARM_RECENT_WINDOW` and `DAMAGE_RECENT_WINDOW` are also compared with strict `<` (an elapsed time exactly equal to the window does NOT satisfy the recency check). This is intentionally asymmetric with E.F's `PING_COOLDOWN_PER_PLAYER` precedent (`>=` accept-at-boundary): ping-cooldown UX favors player-friendly acceptance at the boundary; imminent-death cost attribution favors squad-friendly rejection at the boundary. See C.5.3 boundary semantics block for the full rationale and the practical "use 24.99 / 25.01" tuning guidance.

### G.7 — ED-Locked Constants (referenced, not redefined here — owned by `design/gdd/ecological-disturbance.md` registry)

| Knob | Default | Owner | Used By |
|---|---|---|---|
| `EMITTER_MOVEMENT_DELTA_FLOOR` | 1 stud | ED registry | C.7, C.8, D.4, D.6 |
| `STATIONARY_EMISSION_FACTOR` | 0.30 | ED registry | C.7, C.8, D.4 |
| `FIRST_PULSE_GRACE_WINDOW` | 1.0 s | ED registry | C.6 (T1, T3), C.8.1, C.8.2, D.4 |
| `SPRINT_PULSE_INTERVAL` | 2 s | ED registry | C.6 (T1), C.8.1 |
| `LIGHT_PULSE_INTERVAL` | 4 s | ED registry | C.6 (T3), C.8.2 |
| `MAGNITUDE_SPRINT_PULSE` | 0.10 | ED registry | C.8.1, D.4 |
| `MAGNITUDE_LIGHT_PULSE` | 0.08 | ED registry | C.8.2, D.4 |

Any change to a G.7 row requires modifying the ED GDD's source (registry update + ED.G.5 tuning section), not this GDD.

### G.8 — Tuning Methodology

1. Default values shipped here are **first-pass design intent**, not playtest-validated. Architecture phase consumes them as-is; first-playtest-data revises them.
2. **Never tune two coupled knobs in the same patch without playtesting between** (e.g., `STAMINA_DRAIN_RATE` + `STAMINA_REGEN_RATE`).
3. **Touch-platform knobs MUST be playtested on iPhone SE-class hardware under thermal throttle** (per game-concept). PC-only validation is insufficient.
4. **No knob exposed to the client**. All values live in server-side config. Clients read state, not config.

## Visual/Audio Requirements

Player Controller is in the "Animation / character movement" category — Visual/Audio direction is mandatory at the GDD stage. All requirements respect the **cosmetic-boundary rule**: no cosmetic may change inputs the predator AI consumes (audio emission volume / radius, light emission, motion signature, spatial signature) or inputs the player reads to make survival decisions. Detailed visual specs (palettes, exact pixel sizes) live in `design/art/art-bible.md` and the asset specs that follow per-system `/asset-spec` runs.

### V/A.1 — Animation Requirements

| Animation | Source | MVP? | Specs |
|---|---|---|---|
| Walk loop | Roblox Humanoid default | v2 candidate (override only if testing reveals it conflicts with the "fragile body" read) | n/a |
| Sprint loop | Custom AnimationTrack | **MVP** | Reads as effortful, not heroic — leaning forward, slightly labored. Single loop, ~0.4 s cycle. Mobile 30 fps: no sub-100 ms keyframe intervals. |
| Walk → Sprint blend | Custom cross-fade | **MVP** | Blend-in 0.15 s. Immediate feel communicates the deliberateness of the transaction. |
| Sprint → Walk blend | Custom + forced-walk variant | **MVP** | Standard blend = 0.15 s. **Forced-walk variant** (T2 from stamina = 0): 0.25 s stumble hold frame before settling into walk cycle — communicates depletion visually. |
| Jump | Roblox Humanoid default | v2 candidate | Use default unless playtest flags it as breaking the "fragile body" read. |
| Lantern raise | Custom one-shot, upper-body layer | **MVP** | ~0.3 s. Slightly slower than lower — deliberate weight signal. |
| Lantern lower | Custom one-shot, upper-body layer | **MVP** | ~0.25 s. |
| Emote slot animations (×6) | Custom full-body one-shots | **MVP** (all 6) | 1.5–2.5 s each. Asset count: 6 tracks. Blend-out 0.3 s to idle. Pillar-2 critical. |
| Death | Custom one-shot collapse | **MVP** | ~0.8 s fall-collapse pose. Body stays as a static frozen pose until respawn or run-end (Roblox ragdoll is unreliable cross-platform). No predator-consume animation at MVP. |
| Respawn | Fade-in via `LocalTransparencyModifier` | **MVP** | 0.5 s opacity ramp. No spawn-pop. Standard idle resumes. |

### V/A.2 — VFX Requirements

| Effect | MVP? | Specs |
|---|---|---|
| Sprint footstep dust | **No** — v2 candidate | Terrain-aware dust requires surface-material detection; cost exceeds value at MVP. |
| Lantern raise/lower brightness ramp | **MVP** | `PointLight.Brightness` lerp matching the animation: raise 0→full over 0.3 s, lower full→0 over 0.25 s. **Property tween, not a particle asset.** |
| Quick-ping marker | **MVP** | Screen-space (pending art-bible Decision B finalisation): 8 px filled circle + 1 px stroke. Own-player ping = white fill + squad-colored stroke; remote pings use category color (Danger violet, Resource teal, Navigate yellow, Untagged white). Opacity 1.0 → 0.0 linear over `PING_DISPLAY_DURATION = 8 s`. **No pulse animation** (motion-reduction compliance). |
| Emote on-screen indicator | **MVP** | World-space billboard above character head; squad-color stroke + white fill + emote icon. Visible 2.5 s, fade 0.5 s. Max 1 active per player. |
| Death VFX (own player) | **MVP** | Screen-edge vignette darkens to black over 1.5 s. **No particle burst, no full-screen flash** — photosensitive-safe. |
| Respawn VFX | **MVP** | Inverse vignette: lifts from black over 0.5 s. No flash. |
| Sprint/Light pulse-fired indicator on the player character | **No** | The disturbance HUD bar is the teaching signal. Player-character world-space VFX would create visual noise readable by other players and conflicts with the cosmetic-boundary rule if skinnable. |

### V/A.3 — Audio Cues

All in-world positional 3D audio uses Roblox `SoundService` with `RollOffMode = InverseTapered`. UI-channel sounds (ping, emote) are **non-positional** per game-concept's anti-pillar (emote audio must never be positional 3D audio that the predator AI could consume).

**Audio-perception boundary (Pillar 1 fidelity note)**: The predator AI's only perception inputs from the player controller are the discrete mechanical contracts emitted by `DisturbanceService:Emit()` on the server: `SprintEmission` (fired per `SPRINT_PULSE_INTERVAL = 2 s` while sprint is authorized, magnitude 0.10) and `LightEmission` (fired per `LIGHT_PULSE_INTERVAL = 4 s` while lantern raised, magnitude 0.08). No other signal from this controller crosses the predator-perception channel. **Footstep audio — both walk and sprint — is positional 3D feedback for player-to-player perception (own player + nearby squad members) only.** Neither walk nor sprint footstep audio is consumed by the predator AI; neither affects disturbance accumulation; neither carries any information about the player's detection risk. The predator does not "hear" walking any more than it "hears" sprinting — both are aural-feedback channels, never perception channels (OQ.1 closed Theme 1). The audio design for sprint footsteps must therefore communicate **effort and physical cost** (the body working hard), not **broadcast volume** (predator-detection radius). A louder or faster sound design that reads as "I am broadcasting danger" would train players to conflate audio volume with mechanical risk — a mental model that is wrong for this game and breaks Pillar 1 ("quiet is the only easy mode") by implying noisy sprint is loud-and-detectable rather than mechanically costly-and-discrete. Cadence is locked to approximate the 2 s pulse interval to the player's ear, reinforcing the sprint-as-transaction feel. Walk footsteps remain low-volume aural feedback **on the same player-feedback-only side of the audio-perception boundary defined above** — i.e., walk footstep audio, like sprint footstep audio, is never an input the predator AI consumes. Cosmetic skins may alter timbre only — see V/A.6.

| Cue | Channel | MVP? | Specs |
|---|---|---|---|
| Walk footstep | Positional 3D | MVP (uses Roblox default if no custom asset) | Low volume; aural feedback for own player + squad proximity awareness. **Walk footstep audio is NOT a predator-perception input** (OQ.1 closed, Theme 1) — predator consumes only the discrete `DisturbanceService:Emit()` mechanical contracts (`SprintEmission`, `LightEmission`); positional walk audio is player-feedback only. Cosmetic skins MUST NOT alter volume, emission radius, or cadence; timbre is the only permitted cosmetic dimension (mechanical-equivalence test verifies disturbance generation unchanged and movement speed unchanged). |
| Sprint footstep | Positional 3D | **MVP** (custom asset) | Distinct timbre from walk — heavier texture, slightly breathless quality communicating physical effort. Volume at source: +3–4 dB above walk footstep maximum (effort cue, **not** broadcast cue). Cadence locked to approximate the `SPRINT_PULSE_INTERVAL` window; cadence is the mechanical transaction-pacing signal to the player's ear, not a volume escalation. The formal disturbance signal is `SprintEmission` (discrete mechanical contract, server-fired); this audio is redundant aural feedback for the sprinting player and nearby squad only — **not a predator-perception input** (OQ.1 closed, Theme 1). Cosmetic skins MUST NOT alter volume, emission radius, or cadence; timbre is the only permitted cosmetic dimension. |
| Jump grunt | — | **No** — skip MVP | No survival-decision information. |
| Lantern raise SFX | UI-adjacent (attached to character, not fully positional) | **MVP** | Short mechanical click/whirr, ~0.3 s. |
| Lantern lower SFX | UI-adjacent | **MVP** | Softer click, ~0.2 s. |
| Death SFX | Positional 3D (own + nearby remote) | **MVP** | Non-vocal: low percussive impact + brief resonant tone. **No scream** (non-diegetic; conflicts with biological/organic predator sonic identity which must remain unique). ~1.0 s. |
| Respawn SFX | UI-adjacent | **MVP** | Soft ambient inhale-analog tone, ~0.5 s. Non-vocal. |
| Quick-ping audio | **UI channel only — NOT positional** | **MVP** | Short neutral tone (~200 ms). **Same sound for all ping categories** — category is distinguished visually only. |
| Emote audio | **UI channel only — NOT positional** | **MVP** | Brief acknowledgment tone per emote type; non-vocal. |

### V/A.4 — Captions Mode Visual Equivalents

When the player enables captions mode (per game-concept accessibility floor), the following indicators appear in a `CaptionsOverlay` ScreenGui (top-left band, 1-line-at-a-time display):

| Audio cue | Captions equivalent |
|---|---|
| Walk footstep cadence | Animated footstep icon cycling at walk tempo, beside nearest squad member's nameplate |
| Sprint footstep cadence | Distinct sprint-stride icon (heavier footstep shape, wider than walk icon) at walk-equivalent cycle speed + squad-color highlight stripe. **The stride icon shape communicates sprint body-state (effort), not broadcast rate** — cycle speed is NOT increased. (Parallels V/A.3 design note: caption players must build the same effort-vs-broadcast mental model as hearing players.) |
| Lantern raise SFX | "Lantern raised" text badge with lantern icon, 1.5 s |
| Lantern lower SFX | "Lantern lowered" text badge, 1.5 s |
| Death SFX (own player) | Vignette already serves; no additional caption needed |
| Death SFX (remote) | "[Name] is down" text in squad color, 3 s |
| Respawn SFX | "Respawn" text badge, 1 s |
| Quick-ping audio | Ping marker is already visual-primary; no caption |
| Emote audio | Emote icon is already visual-primary; no caption |

### V/A.5 — Photosensitive / Motion-Reduction Compliance

**WCAG 2.3.1 (max 3 flashes/sec; no full-screen flashes)**: every effect introduced by Player Controller is compliant by design — death vignette is single-direction fade (not a flash); respawn vignette inverse-fade; ping opacity is a static decay; emote indicator is a fade-out; lantern PointLight ramp is a gradual lerp. **No full-screen flashes exist in this spec.**

**Motion-reduction toggle must disable or substitute**:

- Emote billboard fade → instant-show / instant-hide at toggle boundary frames
- Ping marker opacity decay → static display + instant-remove at 8 s
- Captions-mode footstep icon cycling → static footstep icon
- Sprint footstep VFX (when introduced in v2) → static dust decal

### V/A.6 — Cosmetic-Boundary Compliance Implications

| Asset | Cosmetic-replaceable? | Constraint |
|---|---|---|
| Sprint footstep VFX (v2 only) | YES — shape/color only | Volume / radius / emission rate locked. Mechanical-equivalence test: predator-AI inputs unchanged. |
| Lantern `PointLight` (radius, brightness, edge behaviour) | **NO — locked** | These are survival-decision inputs (Principle 1 — the lit-pool boundary). |
| Lantern raise/lower SFX | YES — timbre/texture only | Duration and volume locked. |
| Sprint/walk footstep SFX | Timbre YES; volume / emission radius / cadence NO | **Volume locked**: sprint footstep must remain at +3–4 dB above walk maximum (effort cue calibrated against walk baseline; altering volume changes the effort-vs-broadcast read). **Emission radius locked**: any radius change would alter the squad proximity-awareness signal (player-information input). **Cadence locked**: cadence approximates the `SPRINT_PULSE_INTERVAL` transaction-pacing signal to the player's ear; altering it would degrade mechanical-contract legibility. Walk footstep audio is NOT a predator-perception input (OQ.1 closed, Theme 1) — cosmetic sign-off does not require predator-AI validation, but mechanical-equivalence test must still confirm disturbance generation unchanged and movement speed unchanged. |
| Death collapse animation | YES — pose/style only | Duration locked (0.8 s). No cosmetic may restore health signal. |
| Death SFX | YES — timbre only | Must remain non-vocal, non-musical. |
| Emote animations | YES | No emote may introduce light emission or audio emission above locked baseline. |
| Quick-ping marker shape | YES — decorative skin | Color must remain squad-color-coded; shape ≤ 12 px. Visibility is a survival-decision input. |

### V/A.7 — Art Bible Principle Application

- **Principle 1 — Contrast Is the Map**: Player Controller owns the lantern `PointLight` lifecycle. Hard-edged 12-stud pool toggled strictly on T3/T4 transitions. **Never linger in a partial state. Brightness lerp on raise/lower is permitted because the transition is brief and directional — it does not produce a soft ambient fill.**
- **Principle 2 — Scale Signals Danger Before Color Does**: Player Controller's contribution is to ensure player-character animations do not visually puff up the player's apparent size. Sprint animation leans forward and narrows; emote animations are contained; death collapse compresses the silhouette downward. **No camera FOV widening on sprint** — flagged for the camera/UX layer (Player Controller does not own the camera, but PC's animations must support the small-player read).
- **Principle 3 — Biological Saturation Is the Disturbance Meter**: Player Controller does not author environment saturation. Its contribution is ensuring **no player-controlled visual effect introduces color outside the disturbance-tier palette or touches the predator's reserved hue**. Ping markers, emote indicators, and squad outline colors all defer to the locked palette in `art-bible.md` §7.5.

### V/A.8 — Out of Scope (for clarity — owned elsewhere)

1. **Predator audio cues and perception range** — owned by Predator AI GDD.
2. **Bioluminescent flora animation and disturbance-tier saturation shifts** — owned by Ecological Disturbance GDD's flora subsystem.
3. **HUD rendering** (stamina bar, disturbance bar, oxygen bar visual presentation) — owned by HUD GDD. Player Controller only specifies the *state changes* that drive HUD updates.
4. **Safe-room lighting and environmental ambience** — owned by future Level/Environment GDD.
5. **Run-end / whole-squad death screen layout and animation** — owned by HUD GDD. Player Controller owns only the "your character is gone" feedback (death vignette + collapse animation) before the screen transition.
6. **Camera behaviour during sprint / death / respawn** — owned by future Camera GDD. Player Controller flags the no-FOV-widening-on-sprint constraint here as an obligation owed forward.

> **📌 Asset Spec** — Visual/Audio requirements are defined. After the art bible is fully approved, run `/asset-spec system:player-controller` to produce per-asset visual descriptions, dimensions, AI generation prompts, and audio specifications from this section.

## UI Requirements

Player Controller introduces several **input affordances** the player interacts with directly. Pixel-precise rendering specs (radii, fonts, exact dimensions) live in the HUD GDD and the eventual `/ux-design` spec for each screen. This section defines **what UI elements PC needs and the contract those elements consume**.

### U.1 — Input Affordances Owned by Player Controller

| Affordance | Platforms | What it consumes | What it produces |
|---|---|---|---|
| **Sprint button** | Touch only (PC + gamepad have key/button bindings, no on-screen widget) | Server-pushed sprint state (S1 vs S2) for visual on/off rendering | Tap fires `RequestSprintToggle` |
| **Stamina bar** | All platforms | `OnStaminaChanged` (≤ 5 Hz) | Read-only — display |
| **Lantern button** | Touch only | Server-pushed lantern state (S3a vs S3b) | Tap fires `RequestLanternToggle` |
| **Quick-ping affordance** | Gesture (touch two-finger); key (PC `G`); bumper (gamepad `L1/LB`) — **no dedicated touch button** | None (input-only widget) | Fires `RequestPing` |
| **Emote wheel** | All platforms | None (input-only widget); category list of 6 slots | Fires `RequestEmote(slot)` |
| **Gather progress ring** | All platforms (rendered when tap-hold or proximity-gate is active) | Local hold-time elapsed (client-predicted); server `GatherNodeArmed` / `GatherNodeDisarmed` | Fires `RequestGather` on completion |
| **Death screen vignette** | All platforms — own dying player only | `OnPlayerDied` | Read-only |
| **Respawn fade-in** | All platforms — own respawning player only | `OnPlayerRespawned` | Read-only |
| **Captions overlay** | All platforms when captions mode enabled | All audio cues from V/A.4 | Read-only |

### U.2 — Touch UI Layout (per ux-designer recommendation, V/A-aligned)

```
 ____________________________________
|  [Lantern]               [Captions]|  Notch / Dynamic Island free
|                                    |
|                                    |
|   [L-Stick]                        |
|                       [Emote Open] |
|                       [Jump]       |
|   [Sprint]            [Interact /  |
|                        Gather]     |
|____________________________________|
```

**Layout commitments:**

- Lantern button is in the upper-left zone, **physically separated from sprint + stick** to defend against predator-encounter mis-tap (Section E.D pitfall).
- Quick-ping is **gesture-only on touch** (no dedicated button) to preserve right-thumb screen real estate.
- Sprint button is a single 44×44 pt tap target (Apple HIG floor). On tap → toggle sprint.
- Jump is bottom-right, above Interact/Gather, within natural right-thumb arc.
- Emote-wheel-open button is above Interact/Gather; opening locks tap-hold gather per T9.

### U.3 — Cross-Platform Parity

- Every PC keyboard binding has a touch and a gamepad equivalent (per C.4 + V/A.3 + game-concept's "all interactive prompts must work with touch tap, mouse click, and gamepad button").
- **No hover-only interactions** anywhere in this controller's UI.
- All affordances scale via `UIScale` and `UIAspectRatioConstraint` per `current-best-practices.md`.
- Tested on a 16:9 PC, 4:3 emulated, and a tall mobile aspect (e.g., 19.5:9) per Roblox UI guidance.

### U.4 — Input Display State

- **Sprint button** visual state: ON when in S2, OFF when in S1, disabled (grey) when stamina = 0 (server has rejected sprint toggles).
- **Lantern button** visual state: ON when in S3b, OFF when in S3a.
- **Stamina bar** visual state: fill = `stamina / STAMINA_MAX`. When in `STAMINA_REGEN_DELAY` window (S1 with regen suppressed), bar shows a static-no-regen indicator (e.g., greyed-out tip).
- All visual state updates respect motion-reduction + photosensitive rules from V/A.5.

### U.5 — UX Spec Flag

> **📌 UX Flag — Player Controller**: This controller has UI requirements that span the in-run HUD, the emote-wheel screen, and the death/respawn overlay. In Phase 4 (Pre-Production), run `/ux-design` to create a UX spec for each screen or HUD element this system contributes to **before** writing epics. Stories that reference UI should cite the resulting `design/ux/[screen].md`, not this GDD directly. Note this in the systems index for Player Controller when it's updated.

## Acceptance Criteria

All criteria are independently verifiable by a QA tester without reading this GDD. Test types: **AUTO-UNIT** (TestEZ headless), **AUTO-INTEGRATION** (Lemur or Studio multi-client), **MANUAL-PLAYTEST**, **MANUAL-DEVICE** (iPhone SE-class required).

### H.1 — Locomotion

- **H.1** — AUTO-UNIT — GIVEN a `PlayerControllerService` with default config, WHEN `GetMoveSpeed(state)` is called, THEN returns 12 studs/s for `Walk` and 20 studs/s for `Sprint`. (Verifies C.1.1 / C.1.2 walk/sprint speed values.)
- **H.2** — MANUAL-PLAYTEST (PC) — GIVEN a live server with one player, WHEN the player holds W for 3 seconds on flat terrain and releases, THEN observed XZ displacement is 36 ± 0.5 studs and Y-axis displacement is uncounted. (Verifies D.6 XZ-only distance; tester uses Studio ruler or `print(HumanoidRootPart.Position)`.)
- **H.3** — MANUAL-PLAYTEST (PC) — GIVEN a sprinting player, WHEN the player jumps mid-sprint, THEN sprint emission interval timer is unaffected (next pulse fires at the expected `SPRINT_PULSE_INTERVAL = 2 s` boundary regardless of jump). (Verifies C.1.4 jump does not reset pulse timers.)

### H.2 — Stamina

- **H.4** — AUTO-UNIT — GIVEN stamina = 100 and sprint state active, WHEN `TickStamina(dt = 0.01667)` is called once (one Heartbeat at 60 Hz), THEN stamina = `clamp(100 − 12.5 × 0.01667, 0, 100) ≈ 99.792` (within ±0.001). (Verifies D.1 drain formula.)
- **H.5** — AUTO-UNIT — GIVEN stamina = 50, sprint inactive, and the regen-delay timer expired (`(t − t_sprint_end) > 1.5`), WHEN `TickStamina(dt = 0.01667)` is called, THEN stamina = `clamp(50 + 10 × 0.01667, 0, 100) ≈ 50.167` (within ±0.001). (Verifies D.2 regen formula.)
- **H.6** — AUTO-UNIT — GIVEN starting stamina `s_0 = 50`, WHEN `T_sprint(s_0)` is computed, THEN result = 4.0 s ± 0.01 s. (Verifies D.3 effective sprint duration.)
- **H.7** — AUTO-INTEGRATION — GIVEN stamina = 0, WHEN the client sends `RequestSprintToggle(sprint=true)`, THEN the server rejects the request, the player remains in S1, and `OnSprintStateChanged` is NOT broadcast. (Verifies C.2.5 force-walk + sprint-input-ignored at zero stamina.)
- **H.8** — AUTO-UNIT — GIVEN sprint just exited at server time `t_end`, WHEN simulation advances by 1.4 s and `IsRegenActive()` is queried, THEN returns `false`; advance by 0.1 s more and re-query, THEN returns `true`. (Verifies C.2.4 / D.2 regen delay = 1.5 s ± 1 frame.)

### H.3 — Lantern

- **H.9** — AUTO-INTEGRATION — GIVEN a player in S2 (sprinting) + S3a (lantern lowered), WHEN the player toggles lantern on, THEN locomotion axis remains S2 and lantern axis transitions to S3b. Server state dump shows both states active concurrently. (Verifies C.3.4 orthogonal lantern + sprint axes.)
- **H.10** — MANUAL-PLAYTEST (PC + Mobile + Gamepad) — GIVEN lantern in S3b, WHEN toggled to S3a then back to S3b within 200 ms, THEN final state matches the final input on all three platforms with no client/server desync visible to the player. (Verifies C.3.1 toggle reliability cross-platform.)

### H.4 — Disturbance Emission Contract

- **H.11** — AUTO-UNIT — GIVEN a player with `t_lastGracePulse_sprint = nil` (fresh life or post-cooldown) enters S2 at `t_0`, WHEN `GetPulseMagnitude(t = t_0 + 0.5, d_xz = 0.4, platform = "pc")` is called (within `FIRST_PULSE_GRACE_WINDOW = 1.0 s`), THEN returns `MAGNITUDE_SPRINT_PULSE = 0.10` (full magnitude — grace-exempt because cooldown is not active and pulse is within grace window). Server records `t_lastGracePulse_sprint = t_0`. (Verifies D.4 grace-eligible branch.)
- **H.11b** — AUTO-UNIT — GIVEN `t_lastGracePulse_sprint = t_now - 3.0 s` (cooldown active; `GRACE_REENTRY_COOLDOWN = 6.0 s` not yet elapsed), the player enters S2 again, and the first pulse fires within `FIRST_PULSE_GRACE_WINDOW`, WHEN `GetPulseMagnitude(t = t_0 + 0.5, d_xz = 0.4 stud, platform = "pc")` is called for Sprint, THEN `grace_eligible = false`, the formula falls through to the movement-delta branch, and result = `0.10 × 0.30 = 0.03` (stationary attenuation, because 0.4 < EMITTER_MOVEMENT_DELTA_FLOOR). (Verifies G1 cooldown-blocks-grace-exemption; closes round-1 exploit.)
- **H.11c** — AUTO-UNIT — GIVEN `t_lastGracePulse_sprint = t_now - 3.0 s` (cooldown active), the player enters S2 again moving (`d_xz = 5 stud`), WHEN `GetPulseMagnitude` is called for Sprint, THEN `grace_eligible = false` AND `effective_d = 5 >= EMITTER_MOVEMENT_DELTA_FLOOR`, formula falls through to the moving branch, result = `0.10` (full magnitude). **A moving sprinter pays the correct cost regardless of cooldown** — only the stationary-bypass exploit is closed.
- **H.11d** — AUTO-INTEGRATION — GIVEN a player who has fired a Sprint grace-exempt pulse 2 s ago (cooldown active), WHEN `Humanoid.Died` fires (T5), and the player respawns, and immediately enters S2, THEN the first Sprint pulse on the new life is grace-exempt at full magnitude (`t_lastGracePulse_sprint` was reset to `nil` on T5). (Verifies T5 cooldown-reset side-effect; Pillar 4 fairness.)
- **H.11e** — AUTO-UNIT — GIVEN `t_lastGracePulse_sprint = nil` AND `t_lastGracePulse_light = nil` (fresh life), the player enters S2 (sprint) at `t_0`, then S3b (lantern) at `t_0 + 0.5 s` while S2 is still active, WHEN both first-pulses are evaluated, THEN BOTH are grace-exempt: Sprint first pulse = 0.10, Light first pulse = 0.08. **Per-axis independence**: entering Sprint does not consume Light's grace exemption. (Verifies axis independence at the rule level.)
- **H.11f** — AUTO-UNIT — GIVEN `t_lastGracePulse_light = t_now - 3.0 s` (Light-axis cooldown active; `GRACE_REENTRY_COOLDOWN = 6.0 s` not yet elapsed), the player enters S3b again, and the first pulse fires within `FIRST_PULSE_GRACE_WINDOW`, WHEN `GetPulseMagnitude(t = t_0 + 0.5, d_xz = 0.4 stud, platform = "pc")` is called for Light, THEN `grace_eligible = false`, the formula falls through to the movement-delta branch, and result = `0.08 × 0.30 = 0.024` (stationary attenuation, because 0.4 < EMITTER_MOVEMENT_DELTA_FLOOR). (Verifies Light-axis parity with H.11b — closes the round-1 lantern toggle-cycle 10× exploit at the AC level.)
- **H.11g** — AUTO-UNIT — GIVEN `t_lastGracePulse_light = t_now - 3.0 s` (Light-axis cooldown active), the player enters S3b again moving (`d_xz = 5 stud`), WHEN `GetPulseMagnitude` is called for Light, THEN `grace_eligible = false` AND `effective_d = 5 >= EMITTER_MOVEMENT_DELTA_FLOOR`, formula falls through to the moving branch, result = `0.08` (full magnitude). **A moving lantern-toggler pays the correct cost regardless of cooldown** — only the stationary-bypass exploit is closed. (Verifies Light-axis parity with H.11c.)
- **H.11h** — AUTO-UNIT — GIVEN `t_lastGracePulse_sprint = nil` (eligible) and the player enters S2 at `t_0`, but the simulated server delivers the first pulse at `t = t_0 + 1.5 s` (past `FIRST_PULSE_GRACE_WINDOW = 1.0 s`, simulating a thermally-throttled mobile Heartbeat), WHEN the formula evaluates Step 0a, THEN `t_lastGracePulse[Sprint]` is set to `t_0` regardless of whether the grace-window check passes (it does NOT pass — the pulse falls through to the movement-delta branch). A subsequent S2 entry at `t_0 + 5.0 s` (within `GRACE_REENTRY_COOLDOWN = 6.0 s` from the originally-anchored `t_0`) observes `grace_eligible = false`. (Verifies B9 anchor-on-eligibility — the missed-grace-window jitter exploit is closed even when the server fails to deliver the first pulse within the grace window.)
- **H.12** — AUTO-UNIT — GIVEN `t = t_0 + 4.0` (grace expired), `d_xz = 0.5 stud`, `platform = "pc"`, WHEN `GetPulseMagnitude` is called for Sprint, THEN returns `0.10 × 0.30 = 0.03` (stationary attenuation). (Verifies D.4 stationary branch.)
- **H.13** — AUTO-UNIT — GIVEN `t = t_0 + 4.0`, `d_xz = 0.2 stud`, `platform = "touch"`, WHEN `GetPulseMagnitude` is called for Light, THEN `effective_d` is set to 0 (drift floor zeroed; `0.2 < 2.0`) and result = `0.08 × 0.30 = 0.024` (stationary attenuation applies after drift-zeroing). (Verifies D.4 mobile-drift branch on touch context.)
- **H.14** — AUTO-UNIT — GIVEN `platform = "pc"`, `d_xz = 0.2 stud`, `t = t_0 + 4.0`, WHEN `GetPulseMagnitude` is called for Light, THEN drift-floor gate does NOT apply (PC platform), `effective_d = 0.2`, and stationary branch fires: result = `0.08 × 0.30 = 0.024`. **Distinguishes that PC and touch produce the same magnitude here, but via different code paths** — drift gate must not engage on PC.
- **H.15** — AUTO-INTEGRATION — GIVEN a player in S2 publishing Sprint pulses every 2 s, WHEN the player also enters S3b, THEN both Sprint and Light emissions appear in `DisturbanceService` live-source list with distinct `emissionType` tags and no deduplication. (Verifies C.8 concurrent emissions + E.C "no deduplication".)

### H.5 — Squad Coordination — Ping

- **H.16** — AUTO-INTEGRATION — GIVEN a 2-player server, WHEN player A fires `RequestPing` targeting a tagged entity at distance 50 studs (within `PING_RAYCAST_RANGE = 80`), THEN player B's client receives `OnPingBroadcast` with the entity's tag (e.g., `enemy`) within ≤ 1 server Heartbeat (≤ 17 ms server-side); marker displays for 8.0 s ± 0.1 s and auto-removes. (Verifies C.4.1 ping broadcast + display.)
- **H.17** — AUTO-UNIT — GIVEN a player has fired 3 pings within a 1.5 s window, WHEN a 4th ping is requested within the same 1.5 s window, THEN the server rejects (`PING_BURST_CAP = 3` exceeded), no `OnPingBroadcast` fires, and no rate-limit budget for legitimate pings is consumed. (Verifies C.4.1 burst cap.)
- **H.18** — AUTO-INTEGRATION (touch simulation) — GIVEN three `TouchStarted` events arrive within `PING_TWO_FINGER_WINDOW = 150 ms`, WHEN the gesture detector evaluates, THEN no ping fires (3rd-finger cancel) and no cooldown is charged. (Verifies C.7 / E.D third-finger cancel rule.)

### H.6 — Squad Coordination — Emote

- **H.19** — AUTO-INTEGRATION — GIVEN a player in any state opens the emote wheel and selects any of slots 1–6, WHEN the emote fires, THEN `DisturbanceService:Emit` is NOT called (zero invocations) for the duration of the emote. (Verifies C.4.2 ZERO-disturbance contract; tester mocks `DisturbanceService` and asserts call count = 0.)
- **H.20** — MANUAL-PLAYTEST (Gamepad — D-pad-only configuration) — GIVEN a controller with right stick masked off (single-input-mode), WHEN the player presses D-pad Up (held 0.3 s) to open the wheel, then D-pad Left or Right to cycle slots, then `A / Cross` to commit, THEN one of the 6 emotes fires correctly and displays for `EMOTE_DISPLAY_DURATION = 4 s`. (Verifies C.4.2 D-pad fallback flow.)

### H.7 — Death and Respawn

- **H.21** — AUTO-INTEGRATION — GIVEN a player in S2 + S3b with sprint pulse timer active, WHEN `Humanoid.Died` fires, THEN within 1 server Heartbeat: locomotion axis = S1 (sprint cleared), lantern axis = S3a (force-lowered), sprint pulse timer stopped, light pulse timer stopped, stamina value frozen. (Verifies C.5.5 + C.6 T5 sprint hard-reset.)
- **H.22** — AUTO-INTEGRATION — GIVEN `Humanoid.Died` fires for player A, WHEN the same `Humanoid.Died` event fires a second time within 1 s (replication race), THEN the death handler is a no-op (idempotent guard: no second oxygen deduction; no second timer reset). (Verifies C.5.2 idempotent guard.)
- **H.22b** — AUTO-INTEGRATION — GIVEN an alive player A with `Humanoid.Health = 20` (below `HP_IMMINENT_THRESHOLD = 25`), `getServerTime()` injected to return a fixed value `T`, `lastPredatorDamageTimestamp[A] = T - 5` (predator damage 5 s ago — within `HP_ARM_RECENT_WINDOW = 30 s` and outside `DAMAGE_RECENT_WINDOW = 3 s`, so only arm 1 carries), and squad oxygen = 5, WHEN the player disconnects (`Players.PlayerRemoving` fires) without `Humanoid.Died` having fired, THEN within the same server Heartbeat: `_deathCostPaid` becomes `true`, squad oxygen decrements to 4, `OnPlayerDied(deathCause="disconnect-while-damaged")` is broadcast to the squad. (Verifies C.5.3 Path B HP-arm trigger — all three conjuncts satisfied: low HP, non-nil timestamp, timestamp within `HP_ARM_RECENT_WINDOW`. **Test executability requires the C.11 clock-injection seam.**)
- **H.22c** — AUTO-INTEGRATION — GIVEN an alive player A with `Humanoid.Health = 100` (above `HP_IMMINENT_THRESHOLD`), `getServerTime()` injected to return a fixed value `T`, and `lastPredatorDamageTimestamp[A] = nil` (no recent predator damage), WHEN the player disconnects, THEN the `PlayerRemoving` handler evaluates the imminent-death predicate as `false`, T5 is NOT invoked, squad oxygen is unchanged, no `OnPlayerDied` event is broadcast. (Verifies C.5.3 Path B no-trigger when neither arm is satisfied — non-exploit disconnects pay nothing. **Test executability requires the C.11 clock-injection seam.**)
- **H.22d** — AUTO-INTEGRATION — GIVEN an alive player A with `Humanoid.Health = 100` (above `HP_IMMINENT_THRESHOLD`, so arm 1 cannot fire), `getServerTime()` injected to return a fixed value `T`, `lastPredatorDamageTimestamp[A] = T - 1.5` (predator damage 1.5 s ago — within `DAMAGE_RECENT_WINDOW = 3.0 s`, so arm 2 carries), and squad oxygen = 5, WHEN the player disconnects (`Players.PlayerRemoving` fires) without `Humanoid.Died` having fired, THEN within the same server Heartbeat: `_deathCostPaid` becomes `true`, squad oxygen decrements to 4, `OnPlayerDied(deathCause="disconnect-while-damaged")` is broadcast to the squad. (Verifies C.5.3 Path B time-arm trigger in isolation — only arm 2 carries the predicate; HP arm cannot fire because health is full. Closes the round-3 qa-lead CRIT-2 coverage gap on arm 2. **Test executability requires the C.11 clock-injection seam** — `getServerTime()` is mocked, not `workspace:GetServerTimeNow()` directly.)
- **H.22e** — AUTO-INTEGRATION — GIVEN a 4-player squad with squad oxygen = 5, player A dies a first time at time `T_1` (T5 fires on Path A; `_deathCostPaid[A]` set to `true`; squad oxygen decrements 5 → 4), then T6 fires at `T_1 + 30 s` (player A respawns; `_deathCostPaid[A]` cleared back to `false` per T6 side-effects), WHEN player A dies a second time during the same server session, THEN T5 fires successfully (sets `_deathCostPaid[A] = true` for the second life), `RequestSquadOxygenSpend(amount=1)` is invoked, squad oxygen decrements 4 → 3, and `OnPlayerDied(playerId=A)` is broadcast. (Verifies B6 — without T6 clearance the second-life T5 would observe `_deathCostPaid[A] = true` at step 1 and return immediately; this AC is the binary signal that the lifecycle clearance is implemented. Pillar 2 across multi-life squad runs.)
- **H.22f** — AUTO-INTEGRATION — GIVEN player A satisfies the C.5.3 Path B imminent-death predicate at disconnect time, `_deathCostPaid[A] = false`, AND a fault is injected into the `RequestSquadOxygenSpend` RemoteFunction such that `pcall` returns `(false, errorMessage)`, WHEN the Path B handler executes its set-before-yield sequence, THEN: (1) `_deathCostPaid[A]` is set to `true` BEFORE the pcall'd RemoteFunction call, (2) the pcall captures the failure without crashing the handler, (3) the rollback path clears `_deathCostPaid[A]` back to `false`, (4) the failure is surfaced to a server log channel (e.g., `warn(...)` with player + reason), and (5) the per-player squad oxygen ledger is unchanged. (Verifies B8 — flag rollback on RemoteFunction failure; without rollback, a failed cost-deduction would permanently mark the player as having paid, silently zeroing the cost on any retry path. Idempotency holds only when the flag-set is paired with a guaranteed downstream success OR a flag-rollback on downstream failure.)
- **H.23** — AUTO-INTEGRATION — GIVEN a 2-player squad with squad oxygen = 5, WHEN player A dies, THEN squad oxygen decrements to 4 within the same server Heartbeat as the death event (NOT at respawn arrival 30 s later). (Verifies C.5.3 deduct-at-death timing.)
- **H.24** — AUTO-INTEGRATION — GIVEN a player in S4 (Dead-Respawning), WHEN the player sends `RequestPing` AND `RequestEmote`, THEN both are accepted server-side; movement / sprint / lantern / gather requests in the same window are rejected. (Verifies C.5.4 dead-player allowed input set + C.9 fixed `RequestPing` validation.)

### H.8 — State Machine Concurrency

- **H.25** — AUTO-UNIT — GIVEN the four locomotion×lantern combinations (S1+S3a, S1+S3b, S2+S3a, S2+S3b), WHEN each axis is mutated independently, THEN the other axis remains unchanged in all 8 single-axis transitions tested. (Verifies C.6 orthogonal axis invariant — no cross-axis side effects.)

### H.9 — Cross-Platform Parity

- **H.26** — MANUAL-PLAYTEST (PC + Gamepad) — GIVEN one PC tester (KB+M hold) and one gamepad tester (L3 hold) on the same server, WHEN both initiate sprint from `s_0 = 50` and hold continuously, THEN both exhaust stamina at exactly `t = 4.0 s ± 1 frame`; both transition to S1 within the same Heartbeat. (Verifies cross-platform stamina parity per D.3.)
- **H.27** — MANUAL-DEVICE (iPhone SE-class) — GIVEN touch sprint toggle is active (player tapped sprint to start), WHEN stamina depletes to 0 and force-walk engages (T2), THEN the touch sprint toggle button visually returns to "off" state and a fresh tap is required to re-arm sprint when stamina recovers. (Verifies C.1.3 touch toggle does not ghost-hold post force-walk.)

### H.10 — Performance and Bandwidth

- **H.28** — AUTO-INTEGRATION (Lemur headless) — GIVEN a 4-player server running 300 Heartbeat ticks (5 s simulated), all 4 players cycling Walk/Sprint/Dead with lantern toggling each second, WHEN total CPU time attributed to Player Controller state machines + stamina + lantern + emission timers is measured via `debug.profilebegin` / `debug.profileend`, THEN average per-frame cost < 0.1 ms. (Verifies gameplay-programmer feasibility budget.)
- **H.29** — AUTO-INTEGRATION — GIVEN a 4-player server in steady-state sprint, WHEN RemoteEvent traffic is sampled over 60 frames excluding character replication, THEN total outbound bandwidth for Player Controller events (`OnSprintStateChanged`, `OnLanternStateChanged`, `OnStaminaChanged`, ping/emote broadcasts) cumulative across all clients < 1 KB/s. (Verifies feasibility bandwidth budget.)

### H.11 — Accessibility

- **H.30** — MANUAL-PLAYTEST (Gamepad — D-pad-only) — GIVEN a player using only D-pad + face buttons (no thumbsticks), WHEN the player opens the emote wheel and reaches any of the 6 slots, THEN every slot is reachable in ≤ 5 button presses (Up-hold to open, Left/Right cycle, A to commit; worst-case 3 cycles for opposite-side slot in 6-slot wheel). (Verifies C.4.2 D-pad fallback as full path.)

### H.12 — Inherited ED Obligations

- **H.31** — MANUAL-PLAYTEST (PC) — GIVEN a fresh player spawned in the level-design-flagged Calm-tier first zone (Q11 obligation), WHEN the player walks (no sprint) for the first 10 s after spawn, THEN no Sprint emission is published, no predator state transition occurs, and the squad disturbance meter remains in Calm tier. (Verifies inherited Q11 teaching beat — level-design dependency; PC's role: do not auto-emit on spawn.)
- **H.32** — MANUAL-DEVICE (iPhone SE-class) — GIVEN a stationary player with thumbstick deflected sub-perceptibly (drift), WHEN sprint state is active for 10 s, THEN every Sprint pulse fired at `t > FIRST_PULSE_GRACE_WINDOW` is attenuated (magnitude = 0.03, not 0.10) — verified by `DisturbanceService` event log. (Verifies C.7 + D.4 mobile drift floor + Tier-2 #17.)

### H.13 — Heartbeat / `SPRINT_CLIENT_TIMEOUT` (verifies E.D ghost-sprint safeguard via `PlayerHeartbeat`)

- **H.33a** — AUTO-INTEGRATION — GIVEN a player in S2 (sprinting) actively sending `PlayerHeartbeat` at 1 Hz, `getServerTime()` injected to advance under test control, WHEN the client stops sending `PlayerHeartbeat` (simulated zombie: server receives no further heartbeat packets) and the injected clock advances `SPRINT_CLIENT_TIMEOUT = 3 s` past `_lastHeartbeatTime[player]`, THEN within 1 server Heartbeat of timeout: server transitions the player to S1, stops the sprint pulse timer, stops emitting Sprint pulses, and starts `STAMINA_REGEN_DELAY` timer. (Verifies E.D ghost-sprint timeout via heartbeat mechanism. **Test executability requires the C.11 clock-injection seam** — without it, the test cannot deterministically advance the timeout window.)
- **H.33b** — AUTO-INTEGRATION — GIVEN a player in S2 (sprinting) actively sending `PlayerHeartbeat` at 1 Hz, `getServerTime()` injected to advance under test control, WHEN the client sends additional `PlayerHeartbeat` events faster than `HEARTBEAT_SEND_RATE = 1 Hz` (simulated flood: 10/s), THEN the server drops excess events (rate-limited), `_lastHeartbeatTime[player]` is updated by accepted events ONLY (excess flood events do NOT update the timestamp — verifying the rate-limit is on the write path, not just on the read path), stamina continues draining at `STAMINA_DRAIN_RATE = 12.5 units/s`, and the sprint session terminates at the normal stamina-0 boundary — NOT extended by heartbeat traffic. (Verifies exploit resistance: heartbeat cannot extend sprint authorization beyond stamina bound. **Test executability requires the C.11 clock-injection seam.**)
- **H.33c** — AUTO-INTEGRATION — GIVEN a player in S1 (walking, not sprinting), WHEN the client sends `PlayerHeartbeat`, THEN the server silently drops the event (no error, no rate-limit ban), `_lastHeartbeatTime` is NOT updated for this player, and no state transition occurs. (Verifies S2-only validation rule from C.9.)

### H.14 — Emote-Wheel Gather Lockout (added — verifies T9 mutual exclusion)

- **H.34** — AUTO-INTEGRATION (touch simulation) — GIVEN a player on touch with the emote wheel open, WHEN a `RequestGather` would normally fire from a tap-hold on the right-thumb zone, THEN the gather input is suppressed client-side and no `RequestGather` reaches the server. After the wheel closes, the same input fires `RequestGather` normally. (Verifies C.4.3 / C.6 T9 mutual-exclusion rule.)

## Open Questions

Captures items that emerged during design but were not fully resolved. Each has an owner and target resolution date.

| # | Question | Owner | Target |
|---|---|---|---|
| OQ.1 | **CLOSED — Theme 1 (2026-05-01)**: Walk footstep audio is NOT a predator-perception channel. The predator consumes only discrete `DisturbanceService:Emit()` mechanical contracts (`SprintEmission`, `LightEmission`, plus any contracts the Predator AI GDD's Perception submodule defines). No positional 3D audio from the Player Controller is an input the predator processes. Theme 3 (downstream contract) must enumerate the full predator-perception input set in F.4. | audio-director (closed) | Closed 2026-05-01 |
| OQ.2 | Should jump have a custom animation / SFX, or is the Roblox `Humanoid` default acceptable for MVP? | art-director + audio-director | Before first internal playtest (data-driven) |
| OQ.3 | A future **Camera GDD** does not exist in the systems index. Spectator camera (C.5.6 + E.E), camera FOV behaviour during sprint (V/A.7), and respawn camera fade are owned there. Should we add a Camera system to the systems-index (raising MVP system count from 7 to 8), or fold it into Player Controller? | game-designer + producer | Before `/create-architecture` |
| OQ.4 | The `workspace:HasChunkLoaded()` API name is unverified post-cutoff (Roblox is a live platform). Does this exact method still exist? Architecture phase will block on this. | gameplay-programmer | At `/create-architecture` |
| OQ.5 | Stamina drain rate (12.5 units/s = 8 s sprint window) and regen rate (10 units/s = 10 s recovery) are **first-pass design intent**. Are 8 s sprint and 10 s recovery the right *felt* values? Validate by playtest, not desk-calc. | game-designer (first playtest) | After `/prototype` validation |
| OQ.6 | Is `RESPAWN_DELAY = 30 s` (locked at concept) the right pacing for Roblox 5–20 min sessions? Too short undermines Pillar 2 (shared risk); too long loses the dead player's interest. Validate by playtest. | game-designer (first playtest) | After `/prototype` validation |
| OQ.7 | The 4 ADRs flagged for `/create-architecture` (F.4) — are these the complete set, or will architecture surface more decisions? | technical-director (at `/create-architecture`) | At `/create-architecture` |
| OQ.8 | Cosmetic emote slot 4–6 (`All clear`, `Wait`, `Help/SOS`) — what are the **exact monetization rules** for animation-replacement skins? E.g., can a "danced waving" replacement for `All clear` ship in the launch shop, or is the cosmetic-replaceable nature deferred to v1.x? | live-ops-designer + economy-designer | Before launch-shop spec |
