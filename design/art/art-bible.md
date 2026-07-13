# Terranova — Art Bible

*Created: 2026-04-29 (Roblox-derived, post-pivot from Unity)*
*Status: Draft — authoring in progress*

> **Art Director Sign-Off (AD-ART-BIBLE)**: *Skipped — Lean review mode (2026-04-29)*

---

## Visual Identity Anchor (from game-concept.md)

> *"The player should always know where safety ends."*

- Stylized Roblox aesthetic — leans into the platform's voxel/blocky strengths rather than fighting them
- Strong contrast between safe-light and unknown-dark
- Scale contrast — predator silhouette dwarfs the player at first sighting
- Bioluminescence as a primary lighting source — alien color punching through earth tones

This bible expands and operationalises the anchor for production.

---

## 1. Visual Identity Statement

### One-line visual rule

> *"The player should always know where safety ends."*

### Why this rule

Terranova's core horror is not the predator itself — it is the moment the squad realizes they invited it. That horror only lands if players can read the world clearly enough to understand what they chose: they saw the dark edge, they crossed it anyway, and now something is coming. Without a consistent visual boundary between the known and the unknown, actions feel arbitrary and consequence feels random. The rule exists to guarantee that every moment of dread is legible — players must be able to look back at the boundary they crossed and understand exactly when the world stopped being safe. That legibility also serves the disturbance hook directly: when bioluminescent saturation rises or light radius contracts as disturbance climbs, the boundary *moves*, and players see it move. The rule is not aesthetic polish — it is the visual contract that makes the predator's arrival feel earned rather than scripted.

### Supporting principles

**Principle 1: Contrast Is the Map**

- Lit zones are safe by definition; unlit zones are unknown by definition. This binary is non-negotiable. Every light source in the world — player lanterns, bioluminescent flora, safe-room emitters — must produce a legible boundary between its lit pool and the surrounding dark. That boundary is the only map the player has. Any light behavior that produces a soft, gradual, scene-filling glow (rather than a hard pool with a readable edge) destroys the map by making every zone feel equally navigable.
- **Pillar served**: Pillar 1 — Quiet Is Power (a player who cannot read the boundary cannot choose stealth over aggression; the choice requires legibility).
- **Design test**: "When a new light source asset is proposed — lantern, glowing flora, safe-room emitter — this principle says choose a tight pool with a visible dark edge over a wide ambient fill, even if the wider radius feels more comfortable to play in."

**Principle 2: Scale Signals Danger Before Color Does**

- The predator's threat must be communicated to a player before they have fully processed what they are looking at. Scale is the fastest-reading visual signal available in Roblox's blocky, low-detail aesthetic — a silhouette that is four to six times the player's block-height reads as apex threat before the eye identifies anatomy, color, or motion. Every environment element is subordinated to this: ceilings, canopy, terrain features, and resource nodes must all be sized to make a player-height character read as small. The predator entering frame must visually overwhelm that already-small figure.
- **Pillar served**: Pillar 3 — The World Watches (the world communicates its hierarchy through proportion; the planet is not scaled to the player).
- **Design test**: "When a modeler is deciding the height of a terrain feature, canopy cluster, or cavern wall, this principle says choose the scale that makes a standard Roblox character block look visibly small in that space over a scale that feels human-proportioned or navigably comfortable."

**Principle 3: Biological Saturation Is the Disturbance Meter**

- The world at rest uses a restricted palette: de-saturated earth tones, grey-brown rock, low-saturation ground cover. Bioluminescence exists at rest but at low intensity — ambient, quiet, slow-pulsing. As ecological disturbance rises, color saturation rises with it: flora brightens, bioluminescent elements pulse faster, the air itself seems more saturated. This is not particle-effect decoration — it is the visual read of the disturbance meter, redundant with the HUD for players who are watching the world instead of the UI. The predator's specific hue — a single color assigned in the Color System section — must appear nowhere in the ambient world at any disturbance level. It is reserved exclusively for the predator so that any trace of that hue in peripheral vision is an unambiguous alarm.
- **Pillar served**: Pillar 3 — The World Watches (the world's appearance directly reflects what the players have done to it).
- **Design test**: "When an artist proposes a new prop, flora asset, or environmental effect, this principle says choose a saturation level below the threshold defined for that disturbance tier over a more visually striking treatment — and check whether any proposed color touches the predator's reserved hue before the asset ships."

### What this rule rejects

- **No fully-lit open zones outside designated safe rooms.** Ambient environmental lighting that fills the scene evenly eliminates the boundary the rule depends on. If a player cannot locate the dark edge from where they stand, the rule is violated.
- **No atmospheric haze or fog that unifies the lit and unlit spaces.** A visual effect that blends the safe pool into the surrounding dark — making the transition gradual rather than readable — destroys the map. Fog-like effects are permitted only within unlit zones, where they add depth to darkness rather than bridge it with safety.
- **No decorative bioluminescence that ignores disturbance state.** Bioluminescent elements that are always vivid and fully saturated regardless of player activity treat color as decoration rather than information. Every bioluminescent asset must have a low-state and a high-state appearance; only one is authored as a starting condition.
- **No predator hue appearing on any ambient asset at any disturbance level.** Sharing the predator's color with flora, terrain, or UI elements undermines the one visual signal that must remain unambiguous.
- **No scale decisions made for player comfort.** Widening corridors, lowering ceilings, or reducing environmental feature scale to make spaces feel navigable works against the principle that this world was not built for the player. Comfort-driven scale choices are a scope addition and require explicit sign-off against Principle 2.

---

## 2. Mood & Atmosphere

### 2.1 Lobby / Menu

**Primary emotion target:** Cautious anticipation — the feeling before stepping off a ledge you cannot see the bottom of.

**Lighting character:**
- Time-of-day: static pre-dawn (ClockTime ~5.0) — sky is dark, no sun contribution, no warm fill
- Color temperature: cool-neutral (6500 K direction); dominant tint is a low-saturation blue-grey
- Contrast level: hard-edge pools from instance lights (PointLight / SurfaceLight) on loadout stations and squad avatars; surrounding lobby volume is dark; no ambient fill bridging the two
- Dominant source: sparse ceiling-mounted SurfaceLight emitters — functional, institutional, clearly artificial; they exist to light the squad, not the room

**Atmospheric descriptors:**
- *Still* → no particle emitters active; no animated fog volumes; world is not breathing yet
- *Sparse* → few light sources, negative space dominates; Lighting.Ambient set low (~[40,40,50] RGB direction) so only the instance-lit areas resolve clearly
- *Waiting* → bioluminescent flora visible at the lobby perimeter but at minimum saturation — present to establish the world, not to excite it
- *Contained* → fog (FogStart/FogEnd) tightened so lobby volume is fully readable; world beyond the drop hatch is pure black

**Energy level:** Contemplative.

**Carrier element:** The squad's silhouettes lit from above by a single SurfaceLight emitter. Four small blocky figures under one cone of light, surrounded by dark. Without this overhead pool and the dark surround, the lobby reads as a menu screen rather than a preparation room on an alien world.

**Disturbance-meter integration:** Disturbance is zero — Principle 3 reads as near-zero saturation on all bioluminescent perimeter flora. Pulse rate: off or imperceptibly slow (period ~8s). No tint shift. This is the baseline the player must internalize so that later shifts register.

**Must NOT look like:**
- State 5 (Safe Room) — lobby lights must not use warm color temperature or soft-wash fill; those are reserved for relief. Lobby light is cool and functional.
- State 2 (Exploration Calm) — lobby has no ambient sky, no open world; the volume must feel enclosed and stage-dressed, not traversable.

### 2.2 Exploration — Calm (Disturbance Low)

**Primary emotion target:** Alert quietude — the squad's shared awareness that silence is an asset, not an absence.

**Lighting character:**
- Time-of-day: alien twilight (ClockTime ~19.5) — sky contributes a dim, cool blue-violet wash at very low EnvironmentDiffuseScale (~0.15); not sufficient to navigate by; fills nothing
- Color temperature: cool-desaturated; ground and terrain surfaces read as grey-brown in low sky light
- Contrast level: hard-edge; player lanterns (PointLight, radius tight, ~12 studs) are the primary navigation tool; bioluminescent flora produce secondary hard-edged pools; both have legible dark edges per Principle 1
- Dominant source: player-carried PointLights + sparse bioluminescent flora nodes

**Atmospheric descriptors:**
- *Measured* → lantern pools do not overlap unless players are close; squad spacing is readable from light-pool positions
- *Breathing* → bioluminescent flora pulse slowly (period ~4–5s) at low saturation; suggests life without urgency
- *Open-dark* → FogStart pulled out (~80 studs); unlit zones are deep black, not grey; no haze bridging lit and unlit per Section 1 reject list
- *Grounded* → earth-tone terrain visible only inside light pools; outside pools, terrain disappears into dark

**Energy level:** Measured.

**Carrier element:** Separated lantern pools — each squad member's PointLight creates their own island of visibility. When the squad is spread, four distinct hard-edged pools float in darkness. When they cluster, pools merge. The spatial relationship of the pools is the squad's communication without a word.

**Disturbance-meter integration:** Saturation low — bioluminescent flora Color set to desaturated variant (target ~30% saturation relative to maximum). Pulse period ~4–5s, amplitude low. No unusual tint. This must be visually distinct from State 3: the flora is clearly "at rest," not agitated.

**Must NOT look like:**
- State 3 (Tense) — flora pulse rate must be clearly slower; if calm and tense pulse rates are ambiguous at a glance, the disturbance read is broken.
- State 1 (Lobby) — exploration has sky contribution and traversable volume; lobby is enclosed with artificial light only; a screenshot should contain visible terrain and open sky.

### 2.3 Exploration — Tense (Disturbance Mid)

**Primary emotion target:** The held question — the squad knows something has changed but not yet what it means. Like hearing a sound you cannot place.

**Lighting character:**
- Time-of-day: unchanged from Calm — ClockTime remains ~19.5; the sky does not shift; the world's skeleton is stable, only its biology has changed
- Color temperature: unchanged sky; but flora and bioluminescent elements introduce a warmer, more saturated tint into the pools they cast — the warmth reads as wrong against the cool sky
- Contrast level: hard-edge pools maintained; PointLight radii on player lanterns subtly contracted (~10 studs, down from ~12) to suggest the world closing in without triggering player panic; dark boundaries feel closer
- Dominant source: player lanterns + bioluminescent flora (now elevated saturation and faster pulse, see below); the contrast between cool lantern light and warm flora light creates a dual-tone environment readable at a glance

**Atmospheric descriptors:**
- *Agitated* → flora pulse period compressed to ~1.5–2s; visually present without being strobing
- *Closing* → lantern radius reduced; negative space between players and dark edge is narrower
- *Biologically active* → more flora nodes visible-and-lit than in Calm; the world is responding
- *Wrong-warm* → bioluminescent pools shift toward the warm-saturated end of the palette against a still-cool sky — the aesthetic mismatch is the unease signal

**Energy level:** Suspended — the run is not yet frenetic; players should feel pressure but retain the ability to make decisions.

**Carrier element:** The flora pulse rate. This is the primary carrier for this state. Without the faster pulse, Tense and Calm share too many visual features. The pulse rate is the single most legible signal that the world has noticed the squad. This must be visible even on mobile hardware (no post-process dependency — it is a Color animation on instances, not a shader effect).

**Disturbance-meter integration:** Saturation mid — bioluminescent flora Color at ~60–70% of maximum saturation. Pulse period ~1.5–2s. Color tint shifts perceptibly warmer than Calm state. This is the most-visited state and must sustain tension without becoming numbing — the saturation ceiling in this range (~70%) is load-bearing; if it reaches 100%, the Hunt state has nowhere to escalate to.

**Must NOT look like:**
- State 2 (Calm) — pulse rate and saturation must be unambiguously different; design test is a side-by-side screenshot.
- State 4 (Hunt) — Tense must not reach full saturation or maximum pulse rate; Hunt requires headroom above this state.

### 2.4 Hunt (Disturbance High)

**Primary emotion target:** Shared dread with no clean exit — the squad is not scared individually; they are scared together, and that is worse.

**Lighting character:**
- Time-of-day: ClockTime shifted to ~2.0 (deepest night) — sky contribution drops to near-zero; EnvironmentDiffuseScale reduced to 0.05; the world is darker than it has been in any prior state
- Color temperature: the ambient (Lighting.Ambient) takes on a deep-cool cast with a trace tint toward the predator's reserved hue — not the hue itself, but adjacent enough to register subliminally (this is the only state where the ambient can approach the predator color range; it stops short of it)
- Contrast level: maximum hard-edge; player lanterns are the only navigation; their pools are the only safe islands; the contrast ratio between pool and dark is at its peak; ColorCorrectionEffect Brightness pulled down slightly (~-0.05), Contrast raised (~+0.1) — conditional on PC only; mobile skips ColorCorrection adjustment to preserve frame budget
- Dominant source: player-carried PointLights only; all other light sources de-prioritized or masked; bioluminescent flora at maximum saturation provides eerie fill within its hard-edged radius but competes with no other source

**Atmospheric descriptors:**
- *Frenetic* → flora pulse period compressed to ~0.3–0.5s — at this speed it reads as strobing alarm rather than living pulse; this is the ceiling
- *Saturated* → all bioluminescent flora at 100% saturation maximum; the world is screaming in color
- *Contracted* → PointLight radii reduced further (~8 studs); visual field is at its tightest; players cannot see far
- *Predator-adjacent* → Lighting.Ambient tint pulls toward cool-violet, adjacent to but not at the predator reserved hue; subliminally wrong

**Energy level:** Frenetic.

**Carrier element:** The bioluminescent world at full saturation with maximum pulse rate, combined with contracted lantern radii. The combination of "the world is vivid and screaming" against "I can barely see in front of me" is the specific sensory tension of Hunt. A player who closes their eyes and opens them must immediately know this is Hunt without reading the HUD.

**Mobile note:** ColorCorrectionEffect Brightness/Contrast adjustment is PC-only. On iPhone SE-class hardware, skip the ColorCorrection change — the flora saturation and pulse rate alone carry the state.

**Disturbance-meter integration:** Saturation maximum — bioluminescent flora Color at 100% target saturation. Pulse period ~0.3–0.5s. This is the visual ceiling; nothing escalates further from here. Any introduced post-processing (BloomEffect) must be conditional: PC can run moderate Bloom intensity; mobile disables Bloom entirely.

**Must NOT look like:**
- State 3 (Tense) — pulse period is the primary differentiator; Hunt must feel physically different in tempo, not merely "more saturated."
- State 5 (Safe Room) — Safe Room introduces warmth and stillness; Hunt is cool-dark and frenetic; these must be day-and-night different.

### 2.5 Safe Room

**Primary emotion target:** Grateful exhale — relief that is real but impermanent; the squad knows the clock is still running.

**Lighting character:**
- Time-of-day: irrelevant — Safe Room is fully interior; ClockTime has no effect; sky is not visible from inside
- Color temperature: warm (2700–3200 K direction); dedicated SurfaceLight and PointLight emitters inside the safe room use warm white; this is the only space in the game where warm color temperature appears; the contrast with the cool exterior is immediate and readable
- Contrast level: soft within the room but hard at the threshold — the room interior is evenly lit (multiple warm instance lights creating a wash); the doorway / boundary is where the hard-edge Principle 1 rule applies: outside the safe room is dark; inside is warm and lit; the threshold between them is the visible hard edge
- Dominant source: warm SurfaceLight panels on walls/ceiling; no player lanterns needed inside; the room itself is the light source

**Atmospheric descriptors:**
- *Still* → no particle emitters; no pulse; bioluminescent elements outside visible through any window are at their current disturbance saturation — the contrast with the interior's stillness reinforces that the world is still active
- *Sheltered* → FogStart contracted inside the room to near-zero (room is fully readable with no fog depth); FogEnd remains as exterior
- *Temporary* → a UI timer or audio cue signals departure — the warmth is not permanent; the room is scored as a pause, not a save
- *Enclosed* → ceiling is low relative to exterior (scale compression for comfort intentionally reversed — this room is the one space sized for humans, which makes it feel precious)

**Energy level:** Suspended — dropped pulse rate on everything; the room is visually and sonically quiet.

**Carrier element:** The warm light wash. This is the only warm-temperature light in the entire game. The moment a player steps across the threshold and the color temperature shifts from cool dark to warm interior, the body reads "safe" before the mind processes it. Removing the warm temperature and replacing it with a neutral or cool safe room destroys the emotional register entirely.

**Disturbance-meter integration:** Bioluminescent flora is outside the safe room and continues to pulse at whatever the current disturbance saturation is — visible through window geometry if present, or implied by audio. Inside the room, there are no bioluminescent elements. The meter's visual read pauses at the threshold. Players see the world still active outside; the contrast between the still warm interior and the saturated pulsing exterior is the tension of State 5.

**Must NOT look like:**
- State 1 (Lobby) — both are enclosed lit spaces; differentiated by color temperature (Lobby is cool-functional; Safe Room is warm) and by context (Lobby has no disturbance cues visible; Safe Room has the exterior world visible and active through boundaries).
- State 2 (Exploration Calm) — Safe Room must not feel like outdoor space; ceiling, warmth, and enclosure are the differentiators.

### 2.6 Death Screen

**Primary emotion target:** Stunned clarity — the moment after something irreversible happens when the brain is still catching up. Not grief yet. Recognition.

**Lighting character:**
- This is a UI-layer state overlaid on the world; the world beneath continues in its current Hunt lighting
- Overlay treatment: the world view desaturates to near-monochrome (ColorCorrectionEffect Saturation pulled to ~-0.8 on PC; on mobile, a partial desaturate to ~-0.5 to preserve performance); the bioluminescent element that registered the fatal disturbance event highlights — it is the only color remaining in the frame
- Color temperature: the surviving color is whatever the disturbance-meter bioluminescence was — warm-saturated flora against a grey world; this is the teaching moment
- Contrast level: high; the one remaining color element pops against the desaturated world

**Atmospheric descriptors:**
- *Arrested* → all pulse animation freezes at the moment of death; the world is captured mid-breath
- *Isolating* → vignette effect (UIGradient in a ScreenGui Frame, not a shader) darkens screen edges; the center retains the world view
- *Readable* → on-screen text (minimal: the disturbance event that triggered the predator, no numerical stats) appears in the cleared center area; font contrast is guaranteed against the desaturated world
- *Cold* → the desaturated palette removes all warmth except the surviving bioluminescent element; the juxtaposition is the lesson

**Energy level:** Arrested / still.

**Carrier element:** The single surviving color element — the bioluminescent flora (or player equipment, or disturbed resource node) whose saturation spike contributed to this death. Without the selective color isolation, the death screen is just a grey overlay with text. With it, the screen performs the teaching: "that thing you were looking at is why this happened." Implementation path is deferred to `technical-artist` review — likely a global ColorCorrectionEffect desaturate combined with per-instance Color override on the highlight target, or a UI overlay with a transparent mask aligned to the highlighted element's screen position.

**Mobile note:** Full desaturation via ColorCorrectionEffect is the most expensive treatment here. On iPhone SE-class hardware, limit desaturation to ~-0.5 rather than -0.8; the selective highlight effect remains but the contrast is reduced. Test that the highlighted element still reads distinctly against the partial-desaturate background before shipping.

**Disturbance-meter integration:** This screen IS the disturbance meter read — it surfaces the specific saturation event. The highlighted element's color is whatever saturation tier the meter was at when the predator located the downed player. Maximum saturation reads as maximum disturbance. Players learn the correlation by seeing the vivid color isolated in the grey frame.

**Must NOT look like:**
- State 4 (Hunt) — Hunt is frenetic and colorful; Death Screen is still and near-monochrome. A player should not confuse being hunted with being dead.
- State 5 (Safe Room) — Safe Room is warm and enclosed; Death Screen is cold and arrested; no warmth appears in State 6.

### 2.7 Special Moments

**Victory (Escape Beacon activates):** The beacon fires a single vertical PointLight column — pure white, full brightness, no color tint — that simultaneously overrides all bioluminescent pulse (flora snaps to off or minimum) and collapses FogEnd to near-zero except inside the beam column; for one to two seconds, the only thing visible in the world is the white column and the squad around its base.

**First predator sighting:** The predator enters frame in the far-dark outside the squad's lantern pools — silhouette only, four-to-six times character block-height, occupying the vertical space from ground to above FogEnd ceiling; no bioluminescent flora surrounds the predator (the reserved hue is dark at rest); the player's PointLight lantern pool is in the foreground, the predator silhouette is in the mid-ground dark; Principle 2 is delivered purely through scale differential between the lit small figure in the foreground and the dark enormous shape behind it.

---

## 3. Shape Language

### 3.1 Character Silhouette Philosophy

#### Player avatars

**Locked: Work-with the player's Roblox avatar; mandate two identifying gear pieces.**

Constraining player avatars conflicts with one of Roblox's core player motivations: avatar identity. The squad composition is Pillar 2 — The Squad Is the Experience — and that pillar weakens the moment players feel the game rejected who they are.

The alternative is mandatory visible gear that functions as a silhouette stamp regardless of underlying avatar. Two pieces are required, consistent in form, and occupy a part of the silhouette that reads at lantern-pool-edge distance:

- **Oxygen Pack**: a rectangular dorsal pack, MeshPart, approximately 0.6 × 0.8 × 0.4 studs. Mounted upper-back. Silhouette add: widens the upper torso profile, making a crouched player read as carrying something heavy. Cannot be confused with predator silhouette (predator has no horizontal shoulder-width extension at that proportion).
- **Wrist Lantern / Forearm Unit**: a boxy forearm-mounted emitter, MeshPart, that holds the player PointLight. Silhouette add: creates a distinctive arm-extended-with-object profile. When a player raises the lantern, the silhouette differs from a lantern-down idle. Both states read differently from the predator's limb geometry.

**Silhouette differentiator test**: At the edge of a lantern pool (~12 studs), an R15 character block is approximately 6–8 pixels tall on iPhone SE-class resolution. The oxygen pack and wrist unit add approximately 2–3 pixels of distinctive width/protrusion. This is the minimum viable differentiator. If QA finds the protrusion is not readable at that pixel count, the pack size must be increased before ship — do not compensate with color.

**Implementation note**: Both items are accessories or tool attachments in Roblox terms, not character replacements. Players retain their avatar. Gear color is fixed per the Color System (Section 4): the gear palette must not overlap the predator's reserved hue.

#### Predator silhouette

**Shape grammar: Low-hunched quadrupedal with a raised dorsal mass. Bilaterally asymmetric limb geometry. Elongated horizontal body axis.**

The predator does not stand upright. An upright biped reads as humanoid villain — a category players are trained to engage. The predator is not something the player is supposed to fight; it is something the player is supposed to avoid. The hunched quadrupedal posture communicates "I am always in hunting stance; I have no posture reserved for rest." There is no silhouette configuration in which this creature looks calm or non-threatening.

Specific shape commitments:
- **Body axis**: horizontal, elongated. Length (nose-to-tail) approximately four to six times the player's block-width at ground level. This satisfies Principle 2's four-to-six block-height requirement when the dorsal mass is included: the dorsal ridge rises to that height while the head remains lower, creating a shape that fills the vertical frame without standing upright.
- **Dorsal mass**: a raised central ridge along the spine — not wings, not fins, not spines, but a solid mass that adds vertical height at the center of the body axis. In silhouette this reads as a hump or crest. The shape grammar is: the highest point of the creature is its back, not its head. This inverts the upright-humanoid silhouette grammar and signals non-human hierarchy.
- **Limb count and geometry**: four primary limbs plus two forward-reaching forelimb extensions (six total contact points). In silhouette the forward extensions read as the creature always reaching slightly ahead of where its body is — a posture of reach, of always about to close distance. Limbs are angular, not curved; joints are visible as hard inflection points in the silhouette edge.
- **Head**: low, forward, carried below dorsal ridge height. No visible neck separation in silhouette — the head merges into the forward body mass. The creature leads with mass, not with face.
- **Bilateral asymmetry**: left and right sides of the silhouette are not mirrors. One limb extension is longer. The asymmetry is subtle but present. This breaks the "designed creature" read and suggests biological irregularity — something that evolved rather than was engineered.

This shape says "apex predator that knows you are food" because it presents a creature that is always in approach posture, always at hunting height, never readable as standing-still-and-dormant. There is no "at rest" silhouette that could be mistaken for neutral.

**MeshPart requirement**: The predator is a full custom MeshPart asset. No native Roblox parts can produce this silhouette. Polygon budget specified in Section 8. The silhouette must read at a four-pixel width on mobile — geometry must prioritize silhouette edge sharpness over surface detail.

#### Instant silhouette differentiators (0.3-second read at lantern-pool edge)

The player's eye must classify a moving shape within one visual impulse. Each category has exactly one silhouette property that no other category shares:

| Category | Unique silhouette property | Roblox implementation |
|---|---|---|
| **Teammate** | Upright biped + dorsal pack (rectangular horizontal add) + forearm protrusion | R15 character + MeshPart gear; upright at all times unless crouching mechanic is added |
| **Predator** | Horizontal elongated mass + dorsal ridge (highest point is the back, not the head) + low-forward head | Full MeshPart; four-to-six block-height includes dorsal ridge |
| **Flora reacting** | Vertical elements only; no horizontal mass; movement is oscillating in-place, never translating | Anchored Part/MeshPart; animation is rotation/scale in place, never position change |
| **Environmental hazard** | Inanimate geometry cue — no limb motion, no translation; shape is consistent with terrain but displaced or wrong-scale | Static MeshPart or Union; differentiated from flora by absence of pulse animation |

**Critical movement-grammar rule**: flora and hazards must never translate across the ground plane. Any element that moves horizontally is either a teammate or the predator. This is a design rule, not just an art rule — the movement grammar enforces the silhouette read when shape alone is ambiguous at maximum lantern distance.

### 3.2 Environment Geometry

#### Dominant geometric character

**Primary: Angular. Supporting: Organic (biological).**

Angular geometry is Roblox's native mode — Part-based construction produces hard edges and flat planes at no performance cost. This is not a concession; it is a strategic alignment. Hard-edged angular terrain produces the occlusion planes and shadow planes that Principle 1 (Contrast Is the Map) depends on. A curved or organic terrain creates gradual transitions between lit and unlit surfaces — shadows are soft, boundaries are soft, the map is soft. Angular geometry produces hard corners that produce hard light-to-dark transitions. This serves the visual contract.

**Pillar alignment**: Pillar 1 — Quiet Is Power. Angular terrain creates clean sightlines and clean occlusion — players can read exactly what is and is not visible from a given position. This is legible stealth geometry. Curved terrain makes sightline reading ambiguous.

**Roblox implementation**: Primary environment geometry is constructed from Part-based wedges, blocks, and rectangular volumes at module-snapped scales. **The Roblox smooth-terrain sculpting tool is prohibited in primary navigation zones** — it produces surfaces that cannot be precisely controlled for light-boundary sharpness, violating Principle 1. Custom rock/cliff MeshPart assets are permitted for hero features (defined below) but must maintain angular silhouette edges even if their surface has micro-detail.

#### Terrain language

**Shape vocabulary: Vertical cliffs and stepped platforms separated by flat or near-flat ground planes.**

The planet's surface reads as stratified — horizontal layers of flat traversable ground, interrupted by vertical cliff faces and ridgeline drops. No rolling hills, no gentle slopes:

- **Flat ground planes**: traversable zones where lantern pools read cleanly as circles (flat surface + point light = clean circular boundary). Principle 1 is easiest to satisfy on flat ground.
- **Vertical cliff faces**: occlusion walls. A player behind a cliff face is invisible; a player at the cliff edge is at the boundary. The cliff itself is the map feature that creates safe/unsafe geography.
- **Step geometry**: terrain rises in discrete steps (2–4 stud increments), not smooth ramps. Each step edge is a potential shadow line — the upper surface is lit by the player lantern above; the riser face is in shadow. Steps create micro-contrast even inside a lantern pool.
- **Caves**: permitted only as one-squad-wide linear encounter spaces. **Branching cave networks are prohibited** — they split the squad and break the separated-lantern-pool spatial read that Pillar 2 depends on.

**How this supports Principle 1**: The cliff face is the world's natural hard-edge boundary. A lantern pool hitting a cliff face creates a hard-terminated lit circle on the ground, a lit plane on the cliff wall, and a dark void above the lit zone. Three distinct values in one geometry. The boundary is legible.

#### Safe room geometry

**Shape vocabulary: Human-grid geometry inside an angular terrain world.**

Safe rooms read as built, not grown. Against the alien terrain's angular-but-random stratification, the safe room introduces regularity — rectangular walls that meet at consistent 90-degree angles, uniform wall height, ceiling that is flat and close (low relative to exterior canyon walls).

Specific geometric tells:
- **Wall planarity**: safe room walls are single flat planes, no protrusions, no ledges. Alien terrain is never a single uninterrupted flat plane; it always has angular breaks and steps. A large uninterrupted flat wall reads immediately as constructed.
- **Threshold frame**: the doorway or entry to the safe room is framed by a rectangular cut — hard right angles. Alien terrain entries (cave mouths, cliff gaps) are irregular. The right-angle frame is the signal.
- **Interior scale compression**: ceiling height approximately 1.5 × player block-height (roughly 6–7 studs for an R15 character). Exterior alien terrain ceilings (canopy, cliff overhangs) are sized to make a player look small. The safe room inverts this — players are not small inside it. This scale reversal is legible even without color or light cues.
- **Material contrast**: safe room surfaces must not share texture/material treatment with alien rock. Human-built = fabricated surface (paneling, metal, composite). Alien = raw geological. Material-class commitments are detailed in Section 6.

#### Flora vs terrain shape contrast

**Flora shape grammar: Vertical, branching, non-rigid, pulse-animated at the tip.**

Flora must read as biological against the angular-geological terrain. The contrast is achieved through:

- **Growth axis**: flora grows vertically from a narrow base. Terrain geometry is horizontal-dominant (flat planes) or vertical-dominant (cliff faces) but always straight and non-branching. Flora branches — the silhouette of a flora node is a branching tree-form, not a block or column.
- **Tip geometry**: bioluminescent emission is concentrated at tips, not at the base or trunk. This creates small bright points at the top of a vertical branching form — the opposite of a lantern (which is a ground-level point light producing a circle below). The tip-glow read distinguishes flora from player lanterns at a glance.
- **Pulse animation shape**: the animation is a radial scale pulse at the tip (tip nodes scale 1.0 → 1.3 → 1.0 over the pulse period). The visual effect is a bloom-and-contract at the tip of each branch. **This is a scale animation, not a position animation** — the flora does not sway. Position animation would cause horizontal silhouette shift, which is reserved for teammates and predator per 3.1. Scale-in-place preserves the silhouette-stability rule.
- **Roblox implementation**: flora trunk and main branches are native Part geometry. Tip nodes are small spherical Parts or low-poly MeshParts with a PointLight. The pulse is a Tween on Color and Size. No shader, no particle. Mobile-safe.

### 3.3 UI Shape Grammar

#### Diegetic vs non-diegetic

**Locked: Non-diegetic, with equipment-register visual language.**

Diegetic UI (wrist displays, visor overlays rendered on the character) is conceptually aligned with Pillar 1 because it grounds information in the world. However, on iPhone SE-class resolution at play distance, a wrist-mounted display on an R15 character is at most 3–4 pixels wide. It cannot carry legible information. Diegetic UI fails the mobile-first constraint.

Non-diegetic is the call. But the HUD must not read as a generic game overlay. The shape language of HUD elements must reference equipment aesthetics — the visual vocabulary of the oxygen pack and wrist unit — so that the UI feels continuous with the world even while floating on screen.

**Equipment register in Roblox UI primitives**:
- **Frame shape**: rectangular, no UICorner rounding (CornerRadius 0). Hard corners. This is the shape of a readout panel on a piece of equipment, not a friendly app interface. The hard rectangle connects the UI visually to the angular terrain grammar and differentiates it from Roblox's default soft-rounded UI convention.
- **Exception for the emote/signal wheel**: circular Frame used only for the squad communication wheel. It is the only organic (circular) shape in the HUD. Its uniqueness signals "this is a social action, not a readout." One exception; it remains intentional.
- **Stroke vs fill**: Stroke preferred over fill for framing elements. A 1–2 pixel UIStroke on a transparent Frame reads as an equipment reticle or panel outline. Fill (opaque Frame) is reserved for active/alert states only — when an element fills, it signals urgency, not default display.
- **UIGradient usage**: UIGradient is permitted on meters (oxygen, disturbance) only — horizontal gradient from a base color to a warning color as value increases. No UIGradient on static labels or frame outlines. The gradient is data, not decoration.
- **Corner radius philosophy**: CornerRadius = 0 as the global default. The only permitted exception is the squad communication wheel. Any proposed rounded-corner HUD element requires explicit Art Director sign-off — the rounding must have a justification beyond "looks friendlier."

#### HUD element shape vocabulary

- **Oxygen meter**: horizontal rectangular bar (Frame, UIStroke 1px, UIGradient fill). Occupies bottom-left screen quadrant. Width proportional to screen width at a ratio defined in Section 7. No capsule shape; no circular meter.
- **Disturbance meter**: identical shape vocabulary to oxygen meter, stacked or paired. Fill color defined by Section 4. The two meters are visually a matched pair — same shape, same size, different fill — communicating that they are related systems.
- **Ping / waypoint markers**: chevron shape (two angular strokes meeting at a point, no rounded arc). Rendered as ImageLabel with a pre-baked chevron asset. Angular — consistent with the terrain grammar. Not circular reticles.
- **Squad status indicators** (alive/down per-player): rectangular icon, UIStroke, no fill when alive, filled (solid) when downed. The fill state is the urgency signal. Position: top corners or vertical strip at screen edge.
- **Emote / signal wheel**: circular Frame, eight segments at most, each segment is a pie-slice UIGradient or ImageLabel icon. This is the only circle in the HUD. Position and activation gesture defined in Section 7.

### 3.4 Hero Shapes vs Supporting Shapes

#### Hero shape

**The predator silhouette is the hero shape of any frame it enters.**

This follows from Section 1 Principle 2: scale signals danger before color does. When the predator is in frame, nothing in the composition should visually compete with it. Environment geometry, flora, squad silhouettes, and HUD elements are all subordinated. The predator's horizontal-elongated mass plus raised dorsal ridge is the single most volumetrically large shape in any frame it occupies; no design decision should create an environmental feature that approaches its silhouette scale.

**When the predator is not in frame**, the hero shape falls to the squad's light pools as a group — the cluster of separated lantern circles floating in dark is the compositional anchor of exploration gameplay.

#### Supporting shapes

The following shapes recede and serve as visual ground:

- **Angular terrain faces**: flat planes, cliff walls, step risers. These are the neutral grey-brown field against which all other shapes read.
- **Fog depth volume**: not a geometric shape but a visual plane — the point at which terrain and flora dissolve into dark. This is the visual back wall of every frame, and it must stay visually quiet. Anything that decorates or animates the fog boundary competes with the predator silhouette in depth.
- **Base flora (non-agitated state)**: at low disturbance, flora tip nodes are small, dim, and slow-pulsing. They are background texture, not focal points. Only at mid-to-high disturbance do they advance toward hero-shape territory — and at maximum disturbance, they are intentionally competing with the predator for visual intensity (the world and the predator together create the Hunt feeling).

#### The light-pool boundary: structural shape

**The lantern pool boundary is a structural shape, not a hero shape.**

The boundary — the hard edge of the lantern pool's lit circle against the surrounding dark — is the organizing grid of the entire visual system. It is the most important shape in the game at a design level, but it must not draw the eye as a hero element does. If the boundary itself becomes visually decorative (glowing ring, animated edge, colored halo), it shifts from infrastructure to ornament and competes with the spatial reads it is supposed to support.

The boundary's job is to be seen as a limit, not admired. It organizes the frame by dividing it into lit and unlit zones. Players use it instrumentally — they do not look at it; they look across it, at the dark beyond it. The shape is structural in exactly the same way that a page margin is structural: it defines the reading field without appearing in it.

**Roblox implementation**: the boundary is produced purely by PointLight Brightness and Range settings against Lighting.Ambient. No additional asset is rendered at the boundary. No ring, no edge particle, no UIGradient circle overlaid on the world. The boundary is a natural consequence of the lighting math.

---

## 4. Color System

### 4.1 Primary World Palette

The world at rest uses six named base colors. No additional base colors may be introduced without Art Director approval. Each color has a specific job; it is not a swatch to pull from freely.

| Name | Hex | Color3.fromRGB | Job | When used |
|---|---|---|---|---|
| **Basalt Grey** | `#3A3532` | `Color3.fromRGB(58, 53, 50)` | Primary terrain surface — the visual neutral of the entire game | Rock faces, cliff walls, cave walls, step risers. The default surface color of 70%+ of all geometry. |
| **Ash Brown** | `#5C5047` | `Color3.fromRGB(92, 80, 71)` | Secondary terrain — slightly warmer read, provides value separation from Basalt Grey | Ground plane material, flat traversable surface. Lighter than Basalt Grey, so the ground and the wall read as two different values inside a lantern pool. |
| **Lichen Taupe** | `#6B6355` | `Color3.fromRGB(107, 99, 85)` | Ground-cover surface detail — low-saturation organism mat visible at ground level inside lantern pools | Moss patches, root surfaces, low-lying organic cover. Distinguishes biological-but-ground from geological. |
| **Dead Canopy** | `#4A4840` | `Color3.fromRGB(74, 72, 64)` | Canopy and upper foliage in its non-bioluminescent state — dark, flat, providing occlusion mass above the player | Upper branch clusters, overhead organic volume. Never emits light in calm state; exists as a dark mass that creates overhead occlusion and reinforces Principle 2's scale pressure. |
| **Safe Room Panel** | `#C8B99A` | `Color3.fromRGB(200, 185, 154)` | Safe room interior surface — the only warm-toned surface material in the world | Safe room wall panels, ceiling surfaces, fabricated interior faces. Warm enough to shift visually under warm light; desaturated enough that it is not mistaken for the predator at a glance. |
| **Equipment Slate** | `#2E3138` | `Color3.fromRGB(46, 49, 56)` | Player gear base material — slightly cool-tinted dark grey for oxygen pack and wrist lantern housing | Player-attached MeshPart gear. Cool undertone prevents confusion with the warm safe room. Dark value ensures the gear silhouette reads against lit terrain inside a lantern pool without being a visual highlight. |

**Palette rule**: these six colors define the non-emissive world. Every world surface material draws from this set or from a value that falls within ± 8 RGB units of one of these entries. Do not introduce a new base color to solve a specific prop's look — adjust toward the nearest entry.

### 4.2 The Predator's Reserved Hue

**Locked: Bioluminescent Amber — `#E8871A` / `Color3.fromRGB(232, 135, 26)`**

A deep, saturated amber-orange in the 30°–40° hue angle range (HSV). This is the single most consequential color decision in this bible.

**Justification on three required axes:**

**Axis A — Peripheral recognition at small size on mobile.** Amber-orange at this saturation level is one of the highest-contrast hue shifts possible on an sRGB LCD display relative to the blue-cool-grey ambient of the Terranova world. The human eye's peripheral ganglion cells are maximally sensitive to luminance contrast, but hue contrast supplements this in the 20°–60° peripheral field. A point of amber light against a grey-brown world registers as "wrong color, attend now" before foveal fixation. At 4–6 pixels on iPhone SE resolution, pure hue contrast is the only signal that survives — the amber-against-grey-brown delta is measurable on iPhone SE's color gamut. Cooler hues (cyan, violet, blue) read as extensions of the already-cool ambient sky and lantern pools; they are camouflaged, not alarming. Warm hues in the red range (0°–15°) trigger learned "danger is red" associations that undermine the ecological reading — the predator is not "danger" in the horror sense, it is the apex creature that has noticed you. Amber reads as biological-thermal-present, not as abstract danger.

**Axis B — No collision with any existing world or UI color.** The world palette runs from grey-brown (Basalt Grey `#3A3532`) through warm-taupe (Ash Brown `#5C5047`) with no element approaching the orange band. The HUD palette (specified in 4.5) uses white stroke, blue-tinted transparent fills, and a violet-blue gradient for the disturbance meter. The safe room uses desaturated warm fill under warm white light — the wall surface `#C8B99A` is a muted khaki-tan that, under warm lighting, reads as pale gold, stopping well short of the amber hue angle. None of the bioluminescent flora base colors (specified in 4.3) occupy the amber band. The predator's reserved hue has a clear lane.

**Axis C — Emotional read consistent with apex predator.** Amber-orange is biologically associated with predator eyes, heated breath, thermal presence — the eye-shine of a large animal in the dark. It is not "monster color" (saturated red or sickly green), not "villain color" (deep purple or acid yellow), and not "environmental hazard color" (pure red). It reads as *alive, warm, watching.* For an apex predator whose design philosophy is "it evolved rather than was engineered," amber communicates natural lethality rather than designed threat. This aligns with the game concept's *Subnautica* and *Alien: Isolation* references — both of which use thermal/biological color cues for their predators rather than pure danger-red.

**Reserved-hue exclusion zone:**

Any use of `Color3.fromRGB(232, 135, 26)` or within a ± 15° hue rotation of it (roughly `#E86A1A` through `#E8A81A` at mid saturation, S > 50%) in any non-predator context is a production violation requiring Art Director review.

**This hue must never touch:**
- Any world terrain or rock surface, at any disturbance level
- Any bioluminescent flora node, at any saturation tier
- Any HUD element, meter, or UI frame — including the disturbance meter at maximum
- Any safe room surface, light emitter, or interior prop
- The victory beacon (which is pure white)
- Any player gear or equipment color (including cosmetic shop items — cosmetic accent colors must be reviewed against the exclusion zone before entering the shop)

The predator's full surface Color3 palette is specified in Section 5 (Character Design Direction). What this section locks is the reserved hue as a signal.

### 4.3 Bioluminescent Disturbance Tiers

The base flora color is specified at 100% saturation (Hunt tier). All lower tiers are derived by interpolating toward a desaturated neutral. This allows a programmer to implement `Color3.Lerp(dullBase, fullSaturation, t)` where `t` maps linearly to the disturbance scalar (0.0–1.0).

**Bioluminescent base hue: Spectral Green-Cyan**

At 100% saturation the flora glows at `#22FF8A` / `Color3.fromRGB(34, 255, 138)` — a vivid alien green at ~148° hue angle. This hue:
- Reads as biological, not technological (cyan is mechanical; green-cyan is organic bioluminescence)
- Stays well clear of the predator's amber reserved hue (148° vs 33° — 115° of hue separation, more than enough for colorblind safety, see 4.7)
- Survives iPhone SE LCD reproduction — green-family hues have the highest cone sensitivity in human vision and remain readable at lower display gamut

The desaturated neutral anchor (the flora's "off" appearance) is `#3D4A42` / `Color3.fromRGB(61, 74, 66)` — a near-neutral grey-green that reads as dead foliage inside a lantern pool without drawing attention at rest.

**Interpolation formula:**

```lua
floraColor(t) = Color3.fromRGB(61, 74, 66):Lerp(
    Color3.fromRGB(34, 255, 138),  -- full saturation (t = 1.0)
    t                               -- normalized disturbance scalar
)
```

The PointLight Color on each flora node uses the same Lerp with identical `t`, so the emitted light color tracks the flora surface color.

**Tier table:**

| Tier | State | t | Flora Color3 | Hex | Pulse Period | PointLight Color3 | Notes |
|---|---|---|---|---|---|---|---|
| **0 — Lobby** | Lobby / Menu | 0.0 | `Color3.fromRGB(61, 74, 66)` | `#3D4A42` | ~8s (near-imperceptible) | `Color3.fromRGB(50, 60, 54)` | Flora present at perimeter; reads as dead vegetation; establishes the world without exciting it |
| **1 — Calm** | Exploration low | 0.30 | `Color3.fromRGB(86, 138, 107)` | `#568A6B` | ~4–5s | `Color3.fromRGB(70, 112, 88)` | Clearly alive; clearly not urgent; the baseline players internalize |
| **2 — Tense** | Exploration mid | 0.65 | `Color3.fromRGB(140, 224, 172)` | `#8CE0AC` | ~1.5–2s | `Color3.fromRGB(125, 190, 120)` (warm-shifted) | Visibly brighter; agitated tempo; warm tint shift on light only |
| **3 — Hunt** | Hunt / max | 1.0 | `Color3.fromRGB(34, 255, 138)` | `#22FF8A` | ~0.3–0.5s | `Color3.fromRGB(28, 210, 114)` | Full saturation ceiling; strobing alarm tempo |

**Tense-tier warm tint shift**: At t = 0.65, override the PointLight color from the direct Lerp result `Color3.fromRGB(114, 182, 140)` to `Color3.fromRGB(125, 190, 120)` (slightly more yellow). This changes the color of light cast on adjacent grey-brown terrain — warm-green pools against cool lantern pools, creating the "wrong-warm" feeling described in Section 2.3. The flora *surface* color follows the standard Lerp; only the emitted light is warm-shifted.

**PointLight Brightness interpolation:**

```lua
floraBrightness(t) = 0.3 + (2.0 - 0.3) * t  -- Lerp(0.3, 2.0, t)
```

At t = 0.0, brightness is 0.3 (barely visible pool, tight radius). At t = 1.0, brightness is 2.0 (vivid pool, radius extends further). More of the dark world becomes lit by bioluminescence at high disturbance, simultaneously revealing the world and heightening unease.

### 4.4 Lighting Color Reference

All values below are Roblox Lighting property targets. These are the anchor configurations; interpolation between states follows the disturbance scalar where noted.

#### Exterior Twilight (Calm and Tense states)

| Property | Value | Notes |
|---|---|---|
| `Lighting.ClockTime` | `19.5` | Late-night alien twilight; sun is below horizon; sky contributes a dim cool fill |
| `Lighting.Ambient` | `Color3.fromRGB(40, 42, 55)` | Cool blue-grey, very low value; not zero (absolute black suppresses surface reads inside lantern pools) |
| `Lighting.OutdoorAmbient` | `Color3.fromRGB(28, 30, 42)` | Slightly darker and cooler than Ambient |
| `Lighting.EnvironmentDiffuseScale` | `0.15` | Low sky contribution; faintly resolves terrain silhouettes at the outer edge of lantern pools without bridging the lit/unlit boundary |
| `Lighting.EnvironmentSpecularScale` | `0.05` | Near-zero specular from sky; prevents shiny terrain that would create false light-source reads |
| `Lighting.FogColor` | `Color3.fromRGB(18, 18, 24)` | Near-black cool fog; does not bridge lit and unlit zones |

**Sky color result**: At ClockTime 19.5 with these ambient values, the visible sky reads as dark blue-violet (~`#12121C`). The sky is atmosphere, not navigation.

#### Hunt State (Deep Night shift)

| Property | Value delta from Calm | Notes |
|---|---|---|
| `Lighting.ClockTime` | `2.0` | Deepest night |
| `Lighting.Ambient` | `Color3.fromRGB(28, 28, 38)` | Cool-violet shift — adjacent to predator hue range but stops short; subliminal, not literal |
| `Lighting.EnvironmentDiffuseScale` | `0.05` | Sky fill near-zero |
| PC only: `ColorCorrectionEffect.Brightness` | `-0.05` | Mobile skips |
| PC only: `ColorCorrectionEffect.Contrast` | `+0.10` | Mobile skips |

#### Safe Room — Warm Interior

| Property | Value | Notes |
|---|---|---|
| SurfaceLight Color | `Color3.fromRGB(255, 220, 165)` (`#FFDCA5`) | Warm white at ~2800K; the ONLY warm-hue light emitter in the entire game |
| SurfaceLight Brightness | `1.5–2.0` | Soft fill, not pool |
| Wall fill surface material | `Color3.fromRGB(200, 185, 154)` (Safe Room Panel `#C8B99A`) | Combined read under warm light: pale warm tan ~`#E0CAA0` |
| `Lighting.Ambient` | Not applicable inside | Interior fully controlled by instance lights |

**How warm light + panel surface combine**: The Safe Room Panel material `#C8B99A` is a desaturated khaki. Under the warm SurfaceLight `#FFDCA5`, the perceived surface color shifts toward a pale warm tan ~`#E0CAA0`. This remains clearly distinct from the predator amber `#E8871A`: the safe room surface has near-zero saturation in the orange channel while amber is highly saturated. **Validation check**: if a safe room surface prop reads as orange rather than tan under the warm light, the surface material saturation is too high.

#### Lobby — Cool Functional

| Property | Value | Notes |
|---|---|---|
| Ceiling SurfaceLight Color | `Color3.fromRGB(200, 210, 230)` (`#C8D2E6`) | Cool-neutral white; institutional |
| `Lighting.Ambient` | `Color3.fromRGB(40, 40, 50)` | Low cool ambient |

### 4.5 UI Palette

The HUD operates in a separate visual layer from the world. Its palette must remain legible against all four world states without depending on the world palette for contrast.

| Element | Color | Hex | Color3.fromRGB | Justification |
|---|---|---|---|---|
| **HUD stroke / text** | Opaque white | `#F0F0F0` | `Color3.fromRGB(240, 240, 240)` | Maximum contrast against the cool-dark world. Off-white reads as equipment readout, not chrome |
| **HUD frame fill (default)** | Transparent cool dark | `#1A1E2B` @ ~60% opacity | `Color3.fromRGB(26, 30, 43)` at ImageTransparency ~0.4 | Cool-tinted dark fill recedes against the world while creating a readable panel |
| **Oxygen meter — safe (>30%)** | Teal-white | `#5FFFD8` | `Color3.fromRGB(95, 255, 216)` | Cool, functional. Distinct from flora green (more blue-tinted) |
| **Oxygen meter — warning (10–30%)** | Pale warning yellow | `#FFF860` | `Color3.fromRGB(255, 248, 96)` | Light, desaturated warm yellow at hue ~57° (S~62%), 24° clear of predator's 33° reserved hue and outside the ±15° exclusion band entirely — corrected 2026-07-06 after the prior value (`#FFD060`, hue ~42°) was found to sit inside the exclusion zone despite §4.5's earlier (incorrect) claim of hue ~50° |
| **Oxygen meter — critical (<10%)** | Light red-orange | `#FF8060` | `Color3.fromRGB(255, 128, 96)` | Light, desaturated red-orange. Hue closer to red (~10°) than predator amber. Light value vs mid-tone predator |
| **Disturbance meter — low endpoint** | Cool grey-blue | `#3A4A60` | `Color3.fromRGB(58, 74, 96)` | Empty meter — receding, almost invisible |
| **Disturbance meter — high endpoint** | Vivid violet-blue | `#6040E0` | `Color3.fromRGB(96, 64, 224)` | Saturated cool violet. ~100°+ hue separation from predator amber. Players learn "violet meter = approaching threshold" as separate from "amber in periphery = predator present" |
| **Squad member down — indicator fill** | Alert red-white | `#FF6060` | `Color3.fromRGB(255, 96, 96)` | Light high-value red. Hue ~0° vs predator 33° |
| **Ping / waypoint chevron** | White | `#F0F0F0` | `Color3.fromRGB(240, 240, 240)` | Same as HUD stroke — equipment register |

**Disturbance meter UIGradient specification:**

- Direction: Horizontal (left = low, right = high)
- Keypoints:
  - `0.0`: `Color3.fromRGB(58, 74, 96)` (cool grey-blue)
  - `0.5`: `Color3.fromRGB(70, 55, 160)` (mid-violet transition)
  - `1.0`: `Color3.fromRGB(96, 64, 224)` (vivid violet-blue)
- Transparency keypoints: all at `0` (fully opaque fill within the UIStroke frame)
- **Constraint**: this gradient must not pass through any amber, orange, or warm-green values at any keypoint. Intermediate keypoints must each be checked against the predator reserved hue exclusion zone (±15° of 33° hue angle).

**Oxygen meter UIGradient specification:**

- Direction: Horizontal (left = empty, right = full — meter drains left)
- Keypoints (on the fill gradient):
  - `0.0`: `Color3.fromRGB(255, 128, 96)` (critical red-orange)
  - `0.3`: `Color3.fromRGB(255, 248, 96)` (warning yellow — corrected 2026-07-06, was `Color3.fromRGB(255, 208, 96)`)
  - `1.0`: `Color3.fromRGB(95, 255, 216)` (safe teal-white)

### 4.6 Semantic Color Vocabulary

The color grammar of Terranova's world. Players learn it through play.

| Color / Range | Meaning | Player learns it via |
|---|---|---|
| **Grey-brown (Basalt `#3A3532`, Ash `#5C5047`)** | The inert world — terrain, rock. Neutral. Carries no signal. | Everywhere. The absence of other colors makes grey-brown mean "background." |
| **Cool dark fill (`#C8D2E6` lobby light, `#28283` ambient)** | Functional / waiting / not-yet-active. | Lobby state — "cool light = preparation, not relief." |
| **Bioluminescent green-cyan (flora tiers `#3D4A42` → `#22FF8A`)** | The world's ecological health state — disturbance level. More vivid = more disturbed. The world's readout. | Flora visible in all exterior states; the in-world disturbance meter |
| **Warm khaki-tan (Safe Room Panel `#C8B99A` under warm light)** | Shelter, constructed, human-scale. | Safe rooms only — exclusive to interior |
| **Warm white light (`#FFDCA5`)** | Safety. Relief. Temporary. | Safe room entry — immediate temperature shift from cool exterior |
| **Amber-orange (predator reserved `#E8871A` ± 15°)** | The predator is present or approaching. No other meaning. | First predator encounter; any peripheral amber trace is unambiguous alarm |
| **Violet-blue (disturbance meter high `#6040E0`)** | Your squad's collective ecological disturbance. UI signal, not world signal. | HUD disturbance meter — graduates cool-grey to vivid violet over the run |
| **Teal-white / warning yellow / red-orange (oxygen meter)** | Oxygen remaining. Teal = fine. Yellow = attention. Red = act now. | Oxygen meter — present from session start |

### 4.7 Colorblind Safety Audit

**Pair 1 — Bioluminescent flora vs. predator amber (Green `#22FF8A` vs. Amber `#E8871A`)**

Risk profile: **Deuteranopia and protanopia** collapse green and red/orange channels. Under deuteranopia, green-cyan shifts toward pale neutral; amber shifts toward dull yellow — both lose saturation but retain different value levels. Hue distinction degrades.

Backup cues:
- **Motion grammar**: predator translates horizontally; flora animates only in-place (Section 3.1 hard rule). Colorblind player distinguishes "thing translating toward me" from "thing scaling in place."
- **Scale**: predator is 4–6 player-heights; flora is sub-player-height. A shape that fills the vertical frame is not flora.
- **Sound cue**: predator has a dedicated audio signature (rumble / low-frequency sweep) that begins before visual contact. **Primary backup cue for this pair.**

**Pair 2 — Disturbance meter violet vs. oxygen warning yellow (`#6040E0` vs. `#FFF860`)**

Risk profile: **Tritanopia** collapses blue and yellow channels. Violet may shift red-leaning; warning yellow may shift grey-pink.

Backup cues:
- **Position**: meters are at different screen positions (oxygen bottom-left, disturbance paired beside).
- **Shape/label**: each meter has a small text label in HUD-stroke white. Label is the disambiguation.
- **Fill direction**: oxygen drains (fill moves left); disturbance fills (right). Animation direction is the backup cue.

**Pair 3 — Safe room warm tan vs. world grey-brown (`#C8B99A` vs. `#5C5047`)**

Risk profile: **Protanopia** can reduce warm-channel distinction.

Backup cues:
- **Geometry**: safe room walls are large uninterrupted flat planes (Section 3.2). Alien terrain is never a single uninterrupted flat plane.
- **Light value**: safe room interior is brighter than exterior (multiple SurfaceLight emitters). Brightness persists under colorblind simulation.
- **Threshold frame**: hard right-angle entry (Section 3.2) — a spatial event the player feels.

### 4.8 What This Palette Forbids

A concrete production checklist. Each item is a preventable failure mode.

- **No fully saturated red (`#FF0000` vicinity, 0° hue, S > 80%) on any world asset.** Approaches predator hue and conflicts with disturbance vocabulary.
- **No warm-temperature light sources outside the safe room.** Any PointLight/SurfaceLight/SpotLight Color in `#FFA060`–`#FFE0A0` range is forbidden in exterior or lobby geometry. Safe room is the game's only warm-temperature emitter.
- **No orange or amber color on flora, terrain, props, or decorative assets.** Hue exclusion zone: ±15° of hue angle 33° (~`#E85A1A` through `#E8B41A` at S > 50%). Check at the point of asset Color3 assignment, not at final QA.
- **No bioluminescent flora at full saturation during Lobby or Calm states.** Flora Color3 must be runtime-driven by the disturbance scalar; hand-placed full-saturation values are a bug.
- **No UICorner rounding on HUD meters or frame elements** (Section 3.3 commitment, restated). Rounded HUD elements require explicit Art Director sign-off.
- **No disturbance meter gradient passing through warm hues.** Gradient keypoints must remain on the cool side: hue > 200° or hue < 10°. Any keypoint between 10° and 200° not in the green-cyan band is a violation.
- **No gear color on the player oxygen pack or wrist unit within the predator hue exclusion zone.** Cosmetic accent colors must be reviewed against the exclusion zone before entering the shop.
- **No atmospheric fog tinted warm.** FogColor must remain in cool-dark range (`#10101A`–`#1E1E2E`).
- **No decoration of the lantern pool boundary** (Principle 1 / Section 3.4 commitment). No colored ring, glow halo, or emissive edge. Boundary is produced by lighting math alone.
- **No neon colors outside the bioluminescent flora system.** High-saturation pure cyan (`#00FFFF`), magenta (`#FF00FF`), or lime (`#00FF00`) read as Roblox-default UI. Bioluminescent green `#22FF8A` is the only high-saturation hue in the world, state-gated.

---

## 5. Character Design Direction

### 5.1 Player Character Direction

#### Gear specification — Oxygen Pack

| Property | Specification |
|---|---|
| Form factor | Boxy-rectangular. No curved surfaces. Six flat faces only. Proportions: 0.6 studs wide × 0.8 studs tall × 0.4 studs deep. Corners hard (no fillet). Consistent with angular terrain grammar and hard-corner HUD vocabulary from Section 3.3. |
| Surface treatment | Roblox Material: `SmoothPlastic`. Avoids the texture noise of `Metal` or `Slate` which read inconsistently at small pixel counts on mobile. |
| Surface color | Equipment Slate `#2E3138` / `Color3.fromRGB(46, 49, 56)` on all six faces. No gradient. No emissive on the housing itself. |
| Visible secondary detail | One horizontal band of seam geometry running across the pack at 60% of its height — a single extruded edge strip, 0.04 studs proud of the face. Readable at lantern-pool distance; adds equipment register without significant polygon cost. |
| Strap/harness | A single horizontal cross-chest strap: SmoothPlastic Part, Equipment Slate, 0.06 × 0.06 studs cross-section, connecting pack to character's front torso. No full harness web — too many small Parts is a mobile polygon risk. |
| Attachment point | `AccessoryType.Back`. Roblox HumanoidDescription `BackAccessory` slot. Positioned flush against R15 UpperTorso `BodyBackAttachment`. Pack must not clip through the character's torso regardless of avatar body scale — test at thinnest standard avatar body type. |
| Emissive element | None. The pack is dark mass, not a light source. |

#### Gear specification — Wrist Lantern

| Property | Specification |
|---|---|
| Form factor | Boxy forearm cuff with forward-facing emitter head. Cuff: 0.35 studs wide × 0.2 studs tall × 0.5 studs long (forearm axis). Emitter head: rectangular protrusion 0.15 × 0.15 × 0.1 studs proud of cuff's forward face. Side silhouette: horizontal forearm band with a forward nub. |
| Surface treatment | `SmoothPlastic` on cuff body. Emitter head: `Neon` material with desaturated warm-white fill `Color3.fromRGB(200, 185, 160)` — Neon makes the emitter face glow faintly even without a PointLight. This is the emitter face only, not the cuff. |
| Surface color | Cuff housing: Equipment Slate `#2E3138`. Emitter face: desaturated warm-white Neon (above). The Neon emitter face is the only non-Equipment-Slate element on either gear piece. |
| PointLight | `PointLight` parented to emitter head. Brightness: 3.0. Range: 12 studs (Calm), 10 studs (Tense), 8 studs (Hunt) — driven by disturbance scalar. Color: `Color3.fromRGB(200, 210, 230)` (cool white matching lobby functional light). PointLight is housed inside the emitter head Part; does not float free of wrist geometry. |
| Attachment point | `AccessoryType.Wrist` (locked to dominant hand, typically right). If `AccessoryType.Wrist` is unavailable at implementation, fall back to a Tool held in the right hand using `Motor6D` weld to RightLowerArm. Delegate attachment method to `gameplay-programmer`. |
| Orientation | Emitter head faces forward (along forearm axis, pointing in character's facing direction when arm lowered). When character raises forearm, light rotates upward with arm. PointLight follows the wrist Part naturally — no separate aim script. |

#### Cosmetic identity surface

The gear silhouette is the game's primary player-from-predator differentiator. Cosmetic customization is permitted only on surfaces that do not alter the silhouette read.

| Zone | Allowed cosmetic change | Locked |
|---|---|---|
| Pack housing face color | Yes — any Color3 within cosmetic-safe palette | Form factor, dimensions, seam-band placement |
| Pack housing pattern / decal | Yes — Decal/Texture instance on pack face; within face bounds; no protrusions; opacity locked at 100% | Decal must not use predator hue exclusion zone |
| Strap color | Yes — independently colorable from pack | Strap cross-section dimensions |
| Wrist cuff color | Yes — same cosmetic palette constraint | Cuff form factor + emitter-head protrusion |
| Emitter face color | No — locked to desaturated warm-white | — |
| PointLight color | No — locked cool-white; warm light emitters forbidden in exterior space (Section 4.8) | — |
| Pack or cuff form factor | No — dimensions, silhouette edges, seam-band position, emitter protrusion all locked | Any cosmetic altering silhouette outline requires Art Director sign-off + re-run of silhouette test |

**Cosmetic-safe palette rule**: cosmetic accent colors must not fall within the predator hue exclusion zone (33° ± 15°, S > 50%). The cosmetic shop pipeline must run each proposed accent color against this check before publishing — a simple HSV calculation. Delegate implementation to `gameplay-programmer`.

#### Pose and stance grammar

| Stance | Visual | Silhouette impact |
|---|---|---|
| Idle | Arms at sides; wrist lantern forearm lowered; PointLight illuminates ground in front of feet | Upright biped. Dorsal pack widens upper torso. Forearm cuff protrudes laterally at low arm. |
| Lantern raised | Right forearm raised to ~70° from vertical; emitter head points forward-up; light pool shifts to mid-distance | Forearm-raised silhouette = "active scanning" read. Distinct from lowered idle at pixel-count distance. |
| Sprint | Arms forward-pumping; lantern forearm cycles with run animation | Still upright biped + dorsal pack. Sprint introduces no ambiguous silhouette. PointLight Brightness unchanged. |
| Crouch | Player lowers to ~60% of standing height. Dorsal pack remains on upper back — does not disappear or collapse. | **Critical rule**: crouched player retains dorsal-pack protrusion above head level. At ~4–5 px on iPhone SE, dorsal pack still reads as distinctive rectangular add above shoulder. Crouched player silhouette never matches predator: predator is horizontal-elongated-mass; crouched player is vertical-axis figure with dorsal protrusion. **Crouch IS permitted.** Section 3.1's "unless crouching mechanic is added" is resolved here. QA test: at 5-px character height on iPhone SE, crouched player and predator must be distinguishable by shape alone. |

#### Mobile/touch readability acceptance criteria

At 6–8 pixel character height on iPhone SE-class resolution (375 × 667 pt @2x):

1. Oxygen pack must add minimum 2-pixel protrusion above character's shoulder line in silhouette.
2. Wrist lantern forearm must produce minimum 2-pixel lateral protrusion from arm profile when raised.
3. Crouched player silhouette must differ from predator silhouette at 5-pixel height by body axis (vertical vs horizontal) and dorsal protrusion position (above head vs above horizontal body midline).
4. Two adjacent squad members must produce two discrete upright-biped outlines with two dorsal pack protrusions — not a merged mass.

**These are QA blocking criteria, not advisory.** If any criterion fails at first build, pack and cuff dimensions must scale up before feature completion. Do not compensate with color.

### 5.2 Predator Design Direction

#### Surface palette

The predator's body is 90%+ dark mass. Amber `#E8871A` appears only as accent signal, not as body base.

| Body region | Color3 | Hex | Material | Role |
|---|---|---|---|---|
| Primary body mass (flanks, dorsal ridge body, upper limbs) | `Color3.fromRGB(28, 24, 20)` | `#1C1814` | `Slate` | Near-black warm-dark. Slate catches faint specular from PointLights, allowing surface reads inside lantern pool without becoming invisible at medium range. Warm undertone (not cool grey) prevents reading as shadow or terrain feature. |
| Lower limbs / contact points | `Color3.fromRGB(38, 32, 26)` | `#26201A` | `Slate` | Slightly lighter — separates limb geometry from trunk in silhouette at medium distance. Subtle (10 RGB units) but sufficient for angular limb joint reads. |
| Dorsal ridge crown | `Color3.fromRGB(22, 18, 14)` | `#16120E` | `Slate` | Darkest surface — dorsal ridge reads as highest and darkest point in silhouette. No emissive. Ridge is mass, not signal. |
| Amber signal accent — eye-shine | `Color3.fromRGB(232, 135, 26)` | `#E8871A` | `Neon` | Full predator reserved hue. Eye-shine only — see 5.2 Eye/face design. |
| Thermal exhaust seams (secondary accent) | `Color3.fromRGB(180, 88, 14)` | `#B4580E` | `Neon` (dim) | Darker, less saturated amber — within reserved exclusion zone but lower value. Three to four narrow seam lines along dorsal ridge where ridge meets flank. Glow faintly but below peripheral-alarm threshold — close-range detail, not lantern-edge signal. Confirms "this is the predator, it is biological" at medium range when eye-shine isn't directly visible. |

**Why dark mass + minimal amber**: a 50%+ amber predator would trigger alarm at long range before scale and motion register. Amber is a point signal — light in dark mass — reading as "eyes in the dark" rather than "orange thing incoming." Dark mass delivers scale and silhouette first (Principle 2). Amber delivers the alarm second, as the predator advances and eye-shine catches the lantern pool.

#### Surface treatment

| Property | Specification |
|---|---|
| Primary material | `Slate` on all body MeshPart surfaces. Provides subtle surface texture without `Concrete` noise or `SmoothPlastic` artificiality. Under PointLight, Slate reads as rough-biological. Best built-in approximation of scaled/hide surface. |
| SurfaceAppearance / MaterialVariant | **Not used for MVP.** Custom PBR textures via SurfaceAppearance add 0.5–2 MB per texture set — unacceptable on iPhone SE with 200 MB place weight budget (Section 8). Slate's built-in normal/specular response is sufficient at play distance. v2 surface pass requires technical-artist mobile-downgraded variants before ship. |
| Silhouette edge priority | Polygon budget (Section 8) allocated to silhouette edge fidelity first. Surface micro-detail polygons cut before silhouette-defining polygons. At 4-px predator width on iPhone SE, silhouette IS the entire visual read. |

#### Animation feel direction

**Primary mode: Weighted stalking.** Every footfall reads as deliberate. No scurry. Each primary limb lands with a settle — slight impact deceleration before next lift, not fluid glide. Animation team builds in ground-contact holds (2–4 frames at 30fps) where limb rests before lifting. Feel target: "something very heavy is moving because it has decided to."

**Secondary mode: Explosive lunge.** When closing the final 8–12 studs to a player, the predator accelerates to full speed in a single motion — no wind-up animation. The acceleration itself is the read. The lunge is the only fast animation state. Contrast between stalking weight and lunge speed is the primary kinetic horror delivery.

**Transition rule**: stalking → lunge requires no visual telegraph. The lunge is unwarned by visual animation. The audio system delivers the warning cue; the visual IS the event. Preserves the "I knew something was happening but didn't know how close" horror loop.

**Movement grammar rule**: predator must never bounce, float, or appear aerial. All six contact points maintain implied ground contact during stalking. During lunge, contact points may briefly leave ground but body axis remains horizontal — predator lunges through space, not over it.

#### Eye/face design

The head is low and forward, merging into the forward body mass with no neck separation (Section 3.1). Player's primary perceptual target is the eye-shine.

**Eye-shine specification:**

- Two `Neon`-material spherical Parts, each 0.12 studs diameter, embedded in the forward head mass at slight forward-angled orientation (forward-downward — predator looks down at prey).
- Color: `Color3.fromRGB(232, 135, 26)` — full predator reserved hue `#E8871A`.
- Neon material self-illuminates — no separate PointLight on eye-shine Parts. Keeps eyes as color signal only, not a light emitter that would create a second lantern pool and violate Principle 1.
- Eye separation: ~0.5 studs apart at forward head mass. Close-set, not wide-set — forward-facing close-set arrangement reads as predator (binocular hunter), not prey (lateral wide-set).
- Eye-shine Parts recessed slightly into head mesh (0.04 studs inward) so they do not protrude from silhouette edge. Sub-pixel and invisible at maximum distance. At 10–20 studs they read as two small amber points. At <8 studs they are the dominant visual feature of the head.

**No additional amber on the face.** Thermal exhaust seams are on dorsal ridge and flanks only. Face is dark mass except for the two eye-shine points.

#### First-encounter staging

Per Section 2.7, the predator enters mid-ground dark behind the foreground lantern pool.

**Staging sequence:**

1. **Full silhouette dark.** Predator visible only as silhouette — dark-mass shape against slightly less-dark fog depth. No amber visible. The scale reveal: horizontal-elongated mass with raised dorsal ridge, four-to-six character-heights tall. Eye-shine Parts face forward but are sub-pixel at this distance and do not register.
2. **Amber reveal on turn / advance.** As the predator turns toward or advances toward the player's position, eye-shine catches the edge of the lantern pool at medium range (~15–18 studs). Two amber dots appear in the dark. **The trauma point** — first time the player sees the reserved hue in the world. Means the predator has detected them or is actively facing them.
3. **Thermal seam ambient** (close range only, ~8–10 studs). Dim dorsal seam glow becomes visible only inside the lantern pool at close range. By this distance the encounter is terminal; seam read is "I am close enough to see its biology."

**Why full-silhouette-dark first**: amber on first sighting would teach "amber = predator exists." Instead the lesson is: (a) scale and shape are the first horror, before any color signal; (b) amber appears specifically when predator is oriented toward the player — directional awareness, not ambient presence. Amber is the moment predator awareness and player awareness intersect. Harder-hitting and more learnable than "amber means predator is somewhere."

### 5.3 Distinguishing-Feature Rules

#### Squad teammate vs. strangers

PvP is disabled — no hostile players. The visual grammar still marks "squad member" clearly because at lantern-pool-edge distance a moving upright biped could be ambiguous.

**Teammate markers:**

- Persistent soft aura on each squad member: low-brightness `SelectionBox` or Billboard `ImageLabel` (team-color square outline, 1px UIStroke, no fill) visible only within 30 studs.
- Each squad member assigned one of four distinct cool-toned hues — Squad Color set fixed by HUD spec (Section 7), constrained to: four hues, all outside predator exclusion zone, all distinguishable under deuteranopia.
- Squad Color appears on outline only — does not tint gear or avatar. Outline is the signal; avatar remains the player's cosmetic identity.
- At >30 studs, no teammate marker renders. Upright-biped-plus-dorsal-pack silhouette is the only read — design intent. Squad spacing beyond 30 studs is intentional risk.

#### Player downed vs. dead

| State | Visual change | Roblox implementation |
|---|---|---|
| **Downed** (waiting for revive, run live) | Character collapses to ground — R15 ragdoll or prone animation. Gear pieces remain visible, Equipment Slate unchanged. Vertical Billboard Gui above character shows downed indicator (rectangular UIStroke filled with Squad alert red `#FF6060`). PointLight on wrist lantern dims to 50% brightness; downed player's light pool contracts to ~4 studs radius. The contracted pool is a "dying light" read without separate art. | R15 prone/ragdoll. `PointLight.Brightness` set to 50%. Billboard Gui enabled on downed event. |
| **Dead** (run-ending) | Character Part Transparency tweens to 1.0 over 1s (character becomes invisible, not corpse). Wrist lantern PointLight fades to 0 simultaneously. Squad's total light count visibly decreases. | Transparency tween. Followed by character removal from workspace. No corpse — too many physics objects on mobile. |

**Downed vs dead discrimination rule**: downed always has visible body + contracted pool. Dead has no body, no light, no marker. At distance where billboard is sub-pixel: contracted pool = downed; zero pool = dead.

#### Player low oxygen vs. healthy

| State | Character-level visual change |
|---|---|
| **Healthy (>30%)** | None beyond HUD meter. |
| **Warning (10–30%)** | Breathing animation rate accelerates (shoulder-bob idle speed increases). Secondary reinforcement of HUD warning — players watching teammates can read "that player is breathing harder." |
| **Critical (<10%)** | Gasping animation override (sharp pause-and-recover rhythm, distinct from warning's continuous fast breathing). Wrist lantern PointLight flickers: randomized Brightness oscillation between 100% and 60% at ~0.5s period. Visible to squadmates; cross-player oxygen warning. |

**Mobile safety**: flicker is a `Tween` on `PointLight.Brightness`, not particle or post-process. No mobile perf impact.

**Silhouette impact**: gasping changes shoulder/torso animation timing but not overall silhouette shape. Dorsal pack remains. Upright-biped read preserved at all O2 states.

#### Player carrying a key resource

Key resources (escape beacon components) do not create a held-item silhouette. Beacon components are stored in inventory (no visible geometry). Visual signal for "this player is carrying a key resource" is a Billboard Gui icon above the character — consistent with downed indicator shape vocabulary (rectangular, UIStroke, white icon on dark fill) but with a distinct icon.

**Rationale**: visible carried items would create a third silhouette element, risk ambiguity at pixel-read distance, add asset scope. Billboard icon is known cost, mobile-safe, consistent with HUD equipment register. **No visible geometry for carried items** — billboard-layer communication only.

### 5.4 LOD and Read-Distance Rules

#### Player character LOD

| Distance | Detail level | Notes |
|---|---|---|
| 0–20 studs (near) | Full R15 + both gear MeshParts at authored detail | Default render |
| 20–50 studs (mid) | R15 + both gear MeshParts. Squad outline visible if within 30 studs. | No simplification. Roblox handles R15 LOD; gear MeshParts small enough that polygon reduction not needed. |
| 50+ studs (far) | R15 at Roblox automatic LOD. Gear MeshPart may simplify — flag for low-poly variant (max 60 triangles each) if iPhone SE playtest at 4-player density shows frame drop. | Squad outline doesn't render >30 studs. Dorsal pack at this distance is ~1 px — distinguishes player from terrain but not from predator. Players shouldn't be navigating relative to other players at 50+. |

**Low-poly variant trigger**: 60-triangle gear variant deferred until performance profiling on device shows the need. Do not speculate-optimize.

#### Predator LOD

| Distance | Minimum readable feature |
|---|---|
| Extreme (60–80 studs, fog edge) | Horizontal-elongated dark mass above terrain line. Dorsal ridge as highest point. No amber visible. Silhouette-only read. Predator may render at coarsely-simplified MeshPart LOD. **Silhouette edge is LOD priority** — no polygon cuts that round the dorsal ridge or collapse limb-count read. |
| Medium (20–60 studs, outside lantern pool) | Horizontal body mass + dorsal ridge + visible angular limb joints (3+ distinct joint inflection points in silhouette). Amber eye-shine sub-pixel — may register as warm-toned texture, not clean color read. |
| Close (within lantern pool, 0–20 studs) | Full silhouette detail + amber eye-shine as two distinct colored points + thermal seam glow visible on dorsal ridge. Full read. Terminal encounter range. |

**Mobile-specific**: predator MeshPart must have a registered LOD mesh for >40 studs on iPhone SE. LOD mesh must retain: horizontal-elongated body axis, dorsal ridge as highest point, minimum three limb protrusions per side. All other surface polygon reduction permitted.

#### Mobile LOD summary

| Asset | Mobile treatment |
|---|---|
| Oxygen pack MeshPart | Flag for 60-triangle variant if profiling requires. Silhouette protrusion preserved in any variant. |
| Wrist cuff MeshPart | Same — 60-triangle cap. Emitter head protrusion must survive simplification. |
| Predator MeshPart | LOD mesh required for >40 studs. Silhouette features locked in LOD mesh. |
| Predator eye-shine (Neon Parts) | At >30 studs, may drop to hidden on iPhone SE without visual impact (sub-pixel at that range). Re-enable at <30 studs via `BasePart.LocalTransparencyModifier` or distance-based enable/disable. |
| SurfaceAppearance | Not used in MVP. |

---

## 6. Environment Design Language

### 6.1 Architectural Style and Cultural Context

**Locked: Option C — Layered. One pre-human alien structure class (Precursor Slab) integrated into the geology.**

The planet had a prior tenant that is now gone. Their structures are integrated into the geology — overgrown, partially collapsed, in the same angular material class as the cliff faces.

**Why Layered over Untouched:**

The world's visual contract is "you disturbed something that was already in balance." Option C allows the environment to show what "in balance" looked like before the squad arrived: prior civilisation's structures intact-but-silent, plant life growing through them, disturbance-at-zero. As the squad raises disturbance, their actions are legible as a violation of something with prior order, not just a random wilderness. Makes the predator's response feel earned at an environmental level.

**Scope ceiling:**

One alien structure class only — the **Precursor Slab**. A flat rectangular monolith, angular, Roblox Part-based, in Slate material (Basalt Grey). Placed at fixed positions per Section 6.3. **No rooms, no corridors, no interior architecture.** Structural complexity ceiling: flat slab + occasional T or L arrangement of two to three slabs. The alien culture is readable from the *existence and arrangement* of slabs, not from elaborate ruin geometry.

**What the geography implies without text:**

- Strata read as inhabited long before the squad arrived
- Prior civilisation built at the cliff base — slabs are always against a cliff face, never in open ground
- Oriented along a single axis (true of game geometry naturally — corridors are linear)
- Gone. No bodies, no equipment, no signage
- Flora has grown through and around the slabs over an implied long interval
- Predator avoids slab sites in calm state — slab locations are quiet, teaching players they read as sanctuary precursors to safe rooms

**The story told without text:**

> "Something lived here long enough to arrange stone against the cliff walls. Then it stopped. The planet continued."

### 6.2 Texture Philosophy on Roblox Materials

Section 4 locks colors per surface class. This section locks the Roblox built-in Material per surface class. Every choice is evaluated against four constraints: (1) angular silhouette read, (2) no custom shader, (3) mobile gamut survival, (4) contrast behavior under lantern light (PointLight at cool `Color3.fromRGB(200, 210, 230)`).

| Surface class | Roblox Material | Color3 assignment | Justification |
|---|---|---|---|
| **Cliff face (vertical rock)** | `Slate` | Basalt Grey | Slate produces correct rough-geological surface read under PointLight with no over-specular. At vertical orientation, built-in normal variation reads as stratified rock. Catches lantern light across broader value range than `SmoothPlastic` — lit face reads lit, unlit face reads dark. Produces hard-edge contrast (Principle 1). `Granite` rejected: too much specular-speckle at mobile resolution, reads as noise. |
| **Ground plane (traversable terrain)** | `Sand` | Ash Brown | Low-frequency surface variation under PointLight reads as compacted alien soil. Slightly lighter than Basalt Grey (per 4.1), giving the required ground-vs-wall value separation inside a lantern pool. `Pebble` rejected: too coarse at mobile pixel counts, breaks the flat-ground-plane read. `SmoothPlastic` rejected: reads as manufactured, not geological. |
| **Step risers** | `Slate` | Basalt Grey | Step risers are micro-cliff-faces. Identical material unifies "vertical rock" visual family. Under lantern from above, riser face is in shadow; Slate retains surface read in low light. |
| **Dead canopy / overhead organic mass** | `SmoothPlastic` | Dead Canopy | Canopy exists as dark occlusion mass, not detailed geological surface. SmoothPlastic at this dark value reads as flat organic mass — sufficient for silhouette job. Geological materials would add noise to a surface seen at oblique angles in poor lighting. Mobile-cheap. |
| **Lichen ground cover** | `Grass` | Lichen Taupe | Grass at de-saturated brown-grey reads as organic mat without saturated color. Built-in vertex variation differentiates from flat Sand beneath. **Note**: Grass material can have density-related performance overhead — must be placed as discrete patches, not as terrain-covering Part arrays. |
| **Safe room walls** | `SmoothPlastic` | Safe Room Panel | Safe room's key signal is uninterrupted flat plane (Section 3.2). SmoothPlastic is the only Roblox material that reads as manufactured-flat with no geological texture. Under warm SurfaceLight `#FFDCA5`, shifts to expected pale warm tan ~`#E0CAA0`. Geological materials on safe room walls would break "built, not grown." |
| **Safe room floor** | `SmoothPlastic` | Ash Brown | Slightly darker than walls (natural indoor reading). SmoothPlastic avoids Sand's geological read — the floor is one of few large flat horizontal surfaces in the world; Sand there would bleed exterior "ground" vocabulary into safe interior. |
| **Safe room ceiling** | `SmoothPlastic` | Safe Room Panel | Matches walls. Functions primarily as light-emitter mount surface. SurfaceLight emitters sit flush without material interference. |
| **Crash pod / lander hull** | `SmoothPlastic` | Equipment Slate | Pod is squad's origin point. Equipment Slate matches player gear palette (Section 5.1) — pod and gear read as from the same manufactured world. SmoothPlastic at this dark cool value reads as machined plating. **`Metal` rejected**: specular creates white highlights at acute angles producing false-light-source reads, violating Principle 1. |
| **Bioluminescent flora trunk** | `SmoothPlastic` | Dead-flora neutral `#3D4A42` (base state) | Trunk is structural base — narrow, branching, dark. SmoothPlastic keeps trunk visually quiet, allowing Neon tip nodes to dominate flora's read. Geological materials on trunk-width Parts (~0.2-0.5 studs) produce noise artifacts. Avoids per-Part normal-sampling overhead at high flora density. |
| **Bioluminescent flora tip nodes** | `Neon` | Per Section 4.3 disturbance tier table | Already committed Section 4. Neon self-illuminates without separate PointLight. The PointLight is a sibling of the tip node, not the emitter — Neon surface = visible glowing form; PointLight = world-light contribution. Independent tween targets. |
| **Precursor Slab** | `Slate` | Basalt Grey | Prior civilisation built in same material as cliff faces — intentional. After a long interval, slabs are geologically indistinguishable from terrain at a distance. Close range tells them apart: slab geometry is flat and rectangular (angular cut surfaces, no step risers); cliff faces are irregular fractures. **Material match reinforces "integrated into the planet"** over "imported material." SmoothPlastic would read as safe-room wall — wrong signal. |

**Material summary by family:**

| Family | Materials |
|---|---|
| Geological (exterior, alien) | `Slate` (vertical), `Sand` (horizontal), `Grass` (organic cover) |
| Fabricated (safe room, gear, pod) | `SmoothPlastic` |
| Emissive (flora tips only) | `Neon` |

**No other Roblox materials appear in the MVP world.** This three-family vocabulary is the material grammar.

### 6.3 Prop Density and Composition Rules

#### Density by zone type

| Zone | Density | Reasoning |
|---|---|---|
| **Open exterior** (cliff corridors, flat ground between zones) | Sparse — 3–6 flora nodes per 50 × 50 stud area; 0–1 lichen patch cluster; no decorative geology | Sparse density preserves lantern-pool readability. Open zones, the entire lantern pool should resolve cleanly — props inside a pool compete with terrain silhouette reads. Mobile draw call budget favors low-prop. |
| **Cliff corridor** | Moderate — flora clustered at cliff base and step risers; lichen patches along ground edges; 1–2 Precursor Slabs at cliff base per corridor segment | Cliff faces create natural visual rest areas (dark vertical planes). Flora at cliff base reads against the cliff wall rather than competing with ground-plane pool read. Corridors are linear — moderate density guides navigation without cluttering sightlines. |
| **Cave** | Sparse to bare — 0–2 flora at entrance; interior near-empty | Caves are one-squad-wide linear spaces (Section 3.2). Props reduce effective width. Caves are maximum-tension spaces (limited escape); prop density must not obscure linear-path read. Near-empty caves read deliberately stripped. |
| **Safe room** | Minimal functional — 2–3 wall-mounted SurfaceLight emitter Props; 1 resupply station prop; no flora, no lichen | Safe rooms are human-grid geometry. Props must reinforce "built environment" — no geological props, no flora. Warm emitters are structural (carrier element for warm-safe state). Resupply station = the one gameplay prop. |
| **Crash site** | Moderate hero — centered on crash pod; 4–6 scattered hull debris Parts; disturbed terrain (sand displaced in ring around pod); 0 surviving flora within 10 studs of impact ring | Squad's entry point and first visible evidence of ecological impact. Disturbed terrain is the site's story. Props are pod debris, not decoration. Flora absence within impact radius foreshadows the disturbance mechanic — environmental storytelling Beat 1. |

#### Composition rules

**Cluster-and-void rule**: Props cluster at fixed anchor points — cliff bases, step-riser edges, Precursor Slab adjacency, safe-room wall perimeters — and are absent from ground centers. The void in the center of any open zone is where the lantern pool reads cleanly. Props at the perimeter give the eye a frame without interrupting the lit floor.

**No random scatter**: All flora nodes, lichen patches, and slab positions are hand-placed. Random scatter is prohibited. Reasons: (1) random scatter cannot guarantee void zones at lantern-pool centers; (2) Roblox streaming chunks along spatial grids — hand placement allows deliberate chunk-boundary alignment (6.5); (3) environmental storytelling beats require specific positions.

**Hero element rule**: Every zone has exactly one hero environmental element that anchors spatial memory.

| Zone | Hero element |
|---|---|
| Open exterior | A single tall flora node cluster (3–4 stalks of varying height, grouped at one cliff base) — brightest point in the zone |
| Cliff corridor | Precursor Slab arrangement — two or three slabs against cliff wall, visible from corridor entry |
| Cave | The cave mouth — silhouette of opening against exterior light or flora at entrance. Cave interior has no hero element; absence is the spatial anchor. |
| Safe room | The threshold — doorway frame and hard temperature shift from cool exterior to warm interior. Not a prop; a spatial event. |
| Crash site | The crash pod — hull silhouette, Equipment Slate material, always visible from zone entry angle |

**Cluster vs. solo rules**:
- Flora always clusters (2–4 stalks per placement) — isolated single nodes read as glitch
- Lichen patches stand alone — single patch reads as organic scatter; grouped lichen would fight sparse exterior density
- Precursor Slabs in pairs or triplets at cliff bases — single slab reads as decoration; pair reads as arrangement, implying intent

### 6.4 Environmental Storytelling Guidelines

**Teaching objective before death**: The disturbance mechanic teaches most permanently on the death screen (Section 2.6). But the game must begin teaching earlier in-world. Goal: a player's first death-screen recognition lands because they already encountered the highlighted element earlier.

**Teaching priority** (taught through physical evidence, not UI):
1. Bioluminescent flora tracks something
2. Loud actions near flora are causal, not ambient

**Five environmental storytelling beats:**

**Beat 1 — The Impact Ring (Crash Site)**
- *What*: Circular area of dead/absent flora surrounding the crash pod impact point. Ground material inside ring is scorched/displaced (Sand at darker Color3, or Basalt Grey overriding Sand in partial circle). Outside ring: normal flora. Inside: nothing living.
- *What it teaches*: Human arrival disrupts life. First visual evidence, at squad's spawn, visible in first 10 seconds.
- *Implementation*: Basalt Grey Sand-material-replaced area, radius ~10 studs from pod center. No new asset — existing materials, hand-placed displacement.

**Beat 2 — The Claw Line (Cliff Corridor)**
- *What*: Series of 4–6 narrow rectangular Parts (Slate, Basalt Grey, 0.06 × 0.06 × 1.2 studs) embedded flush into a cliff face at predator-limb height (~2–3 studs off ground). Parallel diagonal lines — claw drag pattern. Groups of three parallel lines, 0.3 stud spacing.
- *What it teaches*: Predator has been here. It is physical. Larger than player (claw-mark height implies a limb above player-eye-level). Drag direction implies travel direction. Players who study marks before encounter internalize predator's scale.
- *Implementation*: Six static narrow Parts welded to cliff face. No new material.
- *Constraint*: Claw marks must not appear near safe rooms or crash sites — wilderness evidence only. Their absence at safe-zone-adjacent walls is itself a signal.

**Beat 3 — The Dark Cluster (Pre-disturbed Zone)**
- *What*: Cluster of flora at higher saturation tier than squad's current disturbance level. 3–4 nodes grouped tightly, casting a small vivid pool against ambient-tier surrounding flora.
- *What it teaches*: Ecological disturbance is local and persistent. Something raised disturbance here before squad arrived. A visual question — "what happened?" — primes player to understand causation between events and disturbance state.
- *Implementation*: Hand-set flora Color3 at fixed higher tier (e.g., Tense t=0.65) rather than driven by global disturbance scalar for that cluster's nodes. Requires flag/tag system so these nodes do not interpolate with global disturbance events. Delegate to `gameplay-programmer`.

**Beat 4 — The Broken Lantern (Cave Entrance)**
- *What*: A dead piece of player gear — wrist lantern cuff Part (SmoothPlastic, Equipment Slate) on the ground at a cave entrance. PointLight disabled. Emitter face dim Neon `Color3.fromRGB(80, 75, 70)` — not fully dark, clearly not active. No body, no blood, no other props.
- *What it teaches*: This location claimed a previous player. Predator does not leave bodies. It leaves absence. The lantern shape — identical to the player's own — registers as memento mori without UI prompt.
- *Implementation*: One static Part (or two: cuff + emitter head), SmoothPlastic, Equipment Slate, placed flat at cave threshold. Dim Neon emitter (battery almost gone). No new asset beyond Section 5.1 specs.

**Beat 5 — The Still Flora (Safe Room Exterior)**
- *What*: Cluster of flora immediately outside a safe room's exterior wall, visible through window geometry or threshold gap. During calm/low-disturbance, near-zero saturation — almost dead-looking. As disturbance rises, this cluster is the first in the immediate area to elevate saturation, visible from inside the safe room.
- *What it teaches*: World's disturbance state is visible from safety. Safe room interior is still; looking outward, players see the world responding. Visual version of "your safety is temporary" — flora outside brightening, not a UI countdown.
- *Implementation*: Three flora nodes hand-placed at exterior-wall adjacency, visible through a rectangular gap in the safe room geometry (consistent with hard-angle geometry — gap is the window, no separate glass Part). No new props.

### 6.5 Roblox Streaming Considerations

StreamingEnabled is confirmed for the MVP map. Environment design decisions to support streaming-friendly loading:

- **Spatial chunking alignment**: Map organized into discrete zone types (open exterior, cliff corridor, cave, safe room, crash site) mapping to spatial chunks of approximately 64 × 64 studs or smaller. Hand-placed props stay within zone boundaries; do not straddle chunk edges.
- **Safe room as stream anchor**: Safe rooms are highest-traffic player positions. Authored as a single compact unit (interior + threshold + exterior wall) within one streaming chunk. Flora visible through the window is in the adjacent exterior chunk, loaded as player approaches.
- **Flora node budget per chunk**: Maximum 8 flora stalk assemblies (each = trunk Parts + 2–4 tip node Parts + 1 PointLight) per 64 × 64 stud chunk. Keeps flora PointLights per chunk under Roblox's recommended dynamic light count for mobile (~12–16 active per render area). One cluster per chunk maximum.
- **Lighting events are instance-scoped**: The disturbance scalar drives individual flora PointLight properties via Tween on Parts in-scene, not via post-process or global lighting (except 4.4 global lighting shifts, which are lightweight). Instance-scoped tweens do not require chunk reload.
- **Precursor Slabs are passive geometry**: Static non-emitting Parts — no PointLight, no animation, no script. Minimal streaming overhead. One slab assembly (2–3 Parts) per cliff-corridor chunk. No slab crosses chunk boundary.
- **Crash pod is a dedicated anchor chunk**: Squad's spawn origin. Loads first, always. Pod assembly (hull + 4–6 debris Parts) fits within one chunk. No debris placed outside crash site chunk.

---

## 7. UI/HUD Visual Direction

### 7.1 Typography

#### Primary typeface

**`Font.GothamMedium`** — primary typeface for all HUD labels, button text, and alert copy.

Rationale: Gotham's geometric construction (near-uniform stroke weight, squared apertures) matches the equipment-register grammar of Section 3.3 — the typeface reads as instrumentation, not consumer UI. Medium weight delivers legibility at small sizes without the top-heavy stroke of Bold. GothamBlack reads as shouting at HUD scale; SourceSans reads as website. Gotham is the closest native Roblox match to a field-readout font.

**`Font.RobotoMono`** — secondary typeface for numeric readouts only (oxygen percentage, timer, squad disturbance numeric overlay if implemented).

Rationale: Monospaced numerals prevent layout shift as values tick (digit width is fixed, so "100" and "10" occupy the same horizontal space). RobotoMono pairs with Gotham at similar optical weight. Its character is utilitarian, reinforcing the instrument-panel read.

#### Type scale (iPhone SE-class baseline — 375 × 667 pt logical resolution @2x)

All sizes in `TextSize` (Roblox pixels at 1× scale factor). Minimum readable threshold on iPhone SE: 14px.

| Role | Font | TextSize | Weight | Usage |
|---|---|---|---|---|
| **Alert / spike text** | GothamBold | 20 | Bold | Disturbance spike alert, squad-down alert — must read at a glance, no focus required |
| **HUD label** | GothamMedium | 16 | Medium | Meter labels (O₂, DIST), section headers in the emote wheel |
| **Button text** | GothamMedium | 16 | Medium | Any tap/click target text |
| **Meter readout** | RobotoMono | 14 | Regular (mono inherently) | Numeric values adjacent to meters — "82%" oxygen, "0.64" disturbance scalar if displayed |
| **Body / tooltip** | GothamMedium | 14 | Medium | Death screen event line; secondary info |

**Minimum floor**: TextSize 14 is the hard minimum on iPhone SE. No HUD element may render text below 14px. Any element that would require sub-14 text to fit its layout must either widen its frame or drop the text in favor of an icon.

#### Weight rules

- **Bold** (`GothamBold`): alert states only — disturbance spike, squad-down indicator text. Urgency signal. Using Bold on static labels dilutes the urgency read.
- **Medium** (`GothamMedium`): all static labels, button text, meters, emote wheel segments. Default HUD weight.
- **Mono Regular** (`RobotoMono`): numeric readouts only. Never used for labels or alerts.

#### Kerning and spacing

Default Roblox `TextService` letter-spacing applies. No custom `LetterSpacing` override required — Gotham's built-in tracking is equipment-register appropriate. Exception: Alert text may use `TextScaled = false` with a fixed width frame and `TextTruncate = AtEnd` to guarantee no overflow on narrow mobile screens. Do not stretch or compress glyphs.

All text is `TextColor3 = Color3.fromRGB(240, 240, 240)` (HUD stroke white `#F0F0F0`) on all dark-fill frames. No shadow effect (`TextStrokeTransparency = 1` default — stroke is off). Legibility is delivered by the dark panel fill behind the text, not by text shadow.

---

### 7.2 Iconography

#### Style

**Flat outlined, two-stroke construction.** Every icon is built from strokes only — no filled shapes. Consistent with the Stroke-over-fill rule from Section 3.3. Icons read as equipment reticle marks, not illustrated symbols. Stroke weight: **2px** at source resolution. At runtime icon sizes, 2px at source produces a clean 1–2px rendered stroke on iPhone SE — below 1px collapses; above 2px reads as decorative.

#### Canvas

**32 × 32px source canvas, square aspect.** Exported as PNG with transparent background, `[ui]_icon_[name]_32.png` naming convention. Displayed in Roblox via `ImageLabel`. No `ScaleType = Stretch` — use `ScaleType = Fit` within the containing frame to preserve aspect ratio.

#### Per-icon specifications

**Oxygen icon (`ui_icon_oxygen_32.png`)**
A boxy rectangular tank silhouette — the oxygen pack in miniature. Three concentric hard-corner rectangles of decreasing width, offset upward, suggesting a pressurized cylinder with banding. Consistent with oxygen pack's rectangular form factor (Section 5.1). No circular gas-tank metaphor; the pack is the referent.

**Disturbance icon (`ui_icon_disturbance_32.png`)**
A radiating broken-circle: a central hard rectangle with three angled stroke lines projecting outward at 45° intervals (upper-left, upper-right, right). Read: "emission / signal / disruption." Not a sound-wave arc (circular grammar); the break in the arc reads as angular. Consistent with chevron and angular grammar.

**Ping / waypoint chevron icon (`ui_icon_ping_32.png`)**
Two angular strokes meeting at a downward point — inverted V, no arc at the vertex. Inner void is empty. This is the canonical chevron from Section 3.3. At 32px it is drawn with 2px strokes, 60° included angle at tip. The chevron directional axis rotates in world-space (or screen-edge) per the ping marker subsystem.

**Emote wheel segments (8 max) — icon set (`ui_icon_emote_[name]_32.png`)**
Each segment receives one icon. MVP emote set (8 max):

| Slot | Icon | Description |
|---|---|---|
| Stop | Raised-palm outline — flat horizontal bars suggesting halt | |
| Follow | Arrow pointing right, angular stepped path, no curve | |
| Wait | Two vertical bars (pause symbol), hard corners | |
| Disturbance high | The disturbance icon above with three strokes exaggerated — same symbol, urgency read | |
| Revive | Up-arrow bisecting a flat horizontal line — "up from downed" | |
| Spread | Two chevrons pointing outward left and right | |
| Regroup | Two chevrons pointing inward left and right | |
| Beacon | Vertical stroke with a flat rectangular base — beacon silhouette from concept doc | |

All emote wheel icons: 2px stroke, outlined, no fill, `#F0F0F0` on the segment background `#1A1E2B`.

**Inventory slot icon (`ui_icon_slot_32.png`)**
A hard-corner empty rectangle, 2px stroke, full canvas. No inner detail — slot is a container icon; content icon is placed inside it. When occupied by a beacon component, the beacon icon (above) renders inside the slot frame.

**Downed / dead status icon (`ui_icon_downed_32.png`, `ui_icon_dead_32.png`)**
- Downed: horizontal figure — single horizontal stroke with a small head circle at left end, oriented flat. Surrounded by squad-color rectangular UIStroke (frame fills alert red `#FF6060` per Section 4.5). Icon is the character; fill-state of the frame is the urgency.
- Dead: an X formed by two 2px diagonal strokes. Same canvas. No frame fill — dead indicator has no ongoing UI state.

**Beacon component (carried) indicator (`ui_icon_beacon_carried_32.png`)**
Vertical stroke, 2px, topped with a small 4×4 hard-corner square. Distinct from the waypoint chevron (which is V-shaped and rotates). Beacon icon is always axis-aligned vertical — represents the physical beacon mast.

**Beacon objective marker (`ui_icon_beacon_objective_32.png`)**
Identical to beacon carried icon but surrounded by a pulsing UIStroke frame (Tween on `UIStroke.Thickness` 1px → 2px → 1px at 1s period) when active. Differentiator: objective marker pulses; carried indicator is static.

---

### 7.3 Animation Feel for UI

#### Default transition durations

All transitions via `TweenService:Create()` using `TweenInfo`.

| Event | Duration | Easing Style | Easing Direction | Notes |
|---|---|---|---|---|
| Panel open (emote wheel, inventory) | 0.15s | `Enum.EasingStyle.Cubic` | `Enum.EasingDirection.Out` | Fast open — equipment panels open crisply, not leisurely |
| Panel close | 0.10s | `Enum.EasingStyle.Cubic` | `Enum.EasingDirection.In` | Close faster than open; dismissal is snappy |
| Meter value tick (oxygen, disturbance) | 0.25s | `Enum.EasingStyle.Sine` | `Enum.EasingDirection.InOut` | Smooth value movement reads as analog instrumentation |
| Alert flash (disturbance spike) | 0.08s in / 0.12s out | `Enum.EasingStyle.Linear` | N/A | Hard-on, soft-off; flash reads as electrical event, not fade |
| Alert fade-out (after spike) | 0.5s | `Enum.EasingStyle.Sine` | `Enum.EasingDirection.Out` | Alert lingers briefly then departs; player has time to register |
| Squad-down indicator fill | 0.10s | `Enum.EasingStyle.Cubic` | `Enum.EasingDirection.Out` | Fast fill communicates sudden event |
| Death screen overlay | See 7.3 death screen | — | — | — |
| Beacon pulse (objective marker) | 1.0s looping | `Enum.EasingStyle.Sine` | `Enum.EasingDirection.InOut` | Slow pulse — presence, not alarm |

**Global rule**: no UI animation exceeds 0.3s for reactive events (alerts, status changes). Slow animations at moments of urgency are a UX failure. Reserve slow timing for ambient/looping states (beacon pulse, meter idle).

#### Disturbance spike-alert feedback sequence

Trigger: disturbance scalar crosses a tier threshold (0 → Calm, Calm → Tense, Tense → Hunt) or a sudden resource-disturbance spike event fires.

1. **Frame border flash**: the entire HUD's outer container frame UIStroke Thickness tweens `1px → 3px → 1px` over 0.08s + 0.12s. Reads as the instrument panel registering a hit. No color change on the frame itself — border weight is the signal.
2. **Disturbance meter scale punch**: the disturbance meter Frame scales briefly `{1, 1} → {1.04, 1.04} → {1, 1}` (UIScale tween) over 0.16s total. Anchored at center. Reads as the meter "jolting."
3. **Alert text pop**: a TextLabel reading `DISTURBANCE SPIKE` appears above the disturbance meter, GothamBold 20px, `#F0F0F0`. Fades in over 0.08s (full opacity snap) then fades out over 0.5s. Positioned above the meter frame, never overlapping oxygen meter.
4. **No vignette on spike**: vignette (UIGradient darkened edge) is reserved for the death screen only. Using it on spike-alert would dilute the death-screen's visual weight.
5. **Mobile safety**: all of the above are Frame/UIStroke/UIScale tweens — no particle, no post-process, no shader. Runs on iPhone SE within frame budget.

#### Death screen animation sequence

Cross-reference Section 2.6: selective desaturation + freeze + surviving bioluminescent color.

| Step | What | Timing | Implementation |
|---|---|---|---|
| 0. Trigger | Player character health reaches 0 / downed confirmed | t = 0 | Server event received |
| 1. World pulse freeze | All flora pulse animations receive `Tween:Pause()` via server broadcast | t = 0 to 0.05s | Immediate — world arrested mid-breath (Section 2.6 "arrested") |
| 2. Desaturation overlay | Full-screen ScreenGui Frame with UIGradient: `BackgroundColor3 = Color3.fromRGB(26, 30, 43)` at opacity 0 tweens to opacity 0.75 over 0.4s (`Sine/Out`) | t = 0.05s to 0.45s | Semi-transparent cool-dark overlay, not full black. World still visible underneath |
| 3. Death text appear | TextLabel center-screen: event cause line (GothamMedium 16px), `#F0F0F0`. Fades in over 0.2s after overlay settles | t = 0.45s to 0.65s | Minimal text only — one line identifying the disturbance event |
| 4. Vignette | UIGradient radial darken on screen edges (corners dark, center light). Transparency 1.0 → 0.6 on edge stops over 0.3s | t = 0.3s to 0.6s | Implemented as Section 2.6 specifies: UIGradient in a ScreenGui Frame, not a shader |
| 5. Hold | Screen holds at full death state | t = 0.65s to 3.0s | Respawn/rejoin UI fades in at 2.0s mark |
| 6. PC desaturation | PC only: `ColorCorrectionEffect.Saturation` tweens -0.8 over 0.4s | t = 0.05s to 0.45s | Concurrent with overlay step |
| 7. Mobile desaturation | iPhone SE-class: limit ColorCorrectionEffect to Saturation -0.5; or skip if frame budget exceeded | t = 0.05s to 0.45s | Profile on-device; skip ColorCorrectionEffect entirely if >2ms GPU cost |

**Total death screen transition**: ~0.65s from trigger to stable hold. Deliberate — not instant (jarring) and not slow (players wait to understand what happened).

---

### 7.4 Layout Grid and Screen Anchoring

#### Layout philosophy

All positions use `UDim2` Scale-based anchoring (not Offset). Offset is only used for fixed-pixel gaps ≤ 8px (e.g., padding between paired meters). This ensures the layout responds to iPhone SE (375 × 667 pt), iPad (768 × 1024 pt), and PC widescreen without reflow.

#### Safe area handling

Roblox exposes `GuiService:GetGuiInset()` which returns the top inset (for the topbar) and a safety-zone floor for notch and home-indicator on mobile. All HUD anchors must offset from these insets.

**Rule**: No interactive element placed within 8px logical of any screen edge before GuiInset is applied. After GuiInset, apply an additional 8px internal padding. Result: minimum 16px clearance from any physical edge on iPhone SE.

**Top inset**: Roblox topbar height varies (typically 36px in-game on mobile). Anchor all top-placed elements at `AnchorPoint {0.5, 0}`, `Position UDim2.fromScale(x, 0)` plus `GuiService:GetGuiInset()` Y offset.

#### HUD element positions

The four coordination affordances from the concept doc: squad disturbance meter, auto-broadcast spike alerts, quick-ping, emote wheel. Plus: oxygen meter, squad status indicators, ping markers. All must coexist on iPhone SE 375 × 667 pt without overlap.

| Element | Anchor point | Position (Scale) | Size (Scale + Offset) | Notes |
|---|---|---|---|---|
| **Oxygen meter** | Bottom-left | `{0, 1}` → offset up + right from corner | `{0.40, 0} + {0, 10}` wide, `{0, 10}` tall | Width = 40% screen width. Height = 10px fixed. Horizontal bar. Label "O₂" above bar (GothamMedium 14px) |
| **Disturbance meter** | Bottom-left, stacked above O₂ | Same X as oxygen meter, 4px gap above | Same width as O₂ meter | Height = 10px fixed. Label "DIST" above bar. Matched-pair vocabulary (Section 3.3) |
| **Squad status strip** | Top-right | `{1, 0}` anchor + GuiInset | `{0, 48}` wide, `{0, 80}` tall | Four 12 × 12px rectangular indicators (per teammate slot), stacked vertically with 4px gap. Squad colors visible as outline UIStroke on each indicator |
| **Quick-ping button** | Bottom-right | `{1, 1}` anchor | `{0, 48}` × `{0, 48}` | Square touch target. Min 44px — Apple/Google touch target guideline. Chevron icon centered. Tap to ping at reticle point |
| **Emote wheel trigger** | Bottom-right, above ping | `{1, 1}` anchor, above ping button | `{0, 48}` × `{0, 48}` | Same size as ping. Hold-to-open gesture reveals the wheel. Wheel expands from this anchor point upward-left |
| **Disturbance spike alert** | Center-top | `{0.5, 0}` + GuiInset | `{0.60, 0}` wide, `{0, 24}` tall | Alert text frame. Appears only during spike events. Does not persist. Centered horizontally, just below topbar inset |
| **Ping / waypoint markers** | Screen-space (see 7.6) | Dynamic | Fixed icon size `{0, 32}` × `{0, 32}` | Screen-edge arrow indicators. Position driven by world-to-screen projection |
| **Emote wheel (expanded)** | Center-screen when open | `{0.5, 0.5}` | `{0, 220}` diameter | Circular frame. Expands from trigger button. 220px diameter: eight segments, each large enough for tap at mobile. Touch dismisses on release |

**iPhone SE non-overlap verification** (375 × 667 pt):

- Bottom strip (O₂ + DIST meters stacked): left-aligned, ~40% width (150px) × ~28px tall (two 10px bars + 4px gap + labels). Sits at bottom-left. Bottom-right buttons (48 × 48px ping + 48 × 48px emote = 48px total wide, 100px tall with gap) are right-aligned. No horizontal overlap. Vertical floor identical — confirmed no overlap between meters and buttons.
- Top-right squad strip (48px wide, 80px tall): does not reach center. Spike alert (60% = 225px wide, centered = 75px from each edge): does not overlap 48px right strip.
- Emote wheel when open (220px diameter centered at 375/2 = 187pt, 667/2 = 333pt): does not reach any persistent HUD element. Clears bottom strips by > 100pt.

---

### 7.5 Squad Color Set

Section 5.3 deferred to here. Four hues, all outside predator exclusion zone (33° ± 15°, S > 50%), all distinguishable under deuteranopia.

**Deuteranopia safety constraint**: deuteranopia collapses green/red channels. Distinguishing by hue angle alone is insufficient for green/red pairs. The four hues must separate on both hue angle and luminance under deuteranopia simulation.

#### Predator exclusion zone check

Predator reserved hue: 33° ± 15° = hue 18° – 48° is excluded at S > 50%. All four squad hues must sit outside this band.

#### The four squad colors

| Player slot | Name | Hex | Color3.fromRGB | Hue (HSV) | Saturation | Deuteranopia-safe pair check |
|---|---|---|---|---|---|---|
| **P1** | Signal Blue | `#4090E0` | `Color3.fromRGB(64, 144, 224)` | ~210° | ~71% | Under deuteranopia: shifts to medium-blue (retains blue channel — unaffected by red/green collapse). Distinct value: medium-light |
| **P2** | Citron | `#C8D040` | `Color3.fromRGB(200, 208, 64)` | ~63° | ~69% | Under deuteranopia: yellow-green shifts toward yellow (green channel reduced). Distinct from Signal Blue by value contrast (lighter) and by surviving yellow hue. 63° is 15° outside the exclusion zone upper bound (48°) — passes. |
| **P3** | Lavender | `#9060D0` | `Color3.fromRGB(144, 96, 208)` | ~270° | ~54% | Under deuteranopia: violet retains blue channel; reads as blue-purple, distinct from Signal Blue by lower value and different hue angle. Unaffected by green/red collapse. |
| **P4** | Ice Teal | `#40D0C0` | `Color3.fromRGB(64, 208, 192)` | ~175° | ~69% | Under deuteranopia: cyan-teal retains blue channel but green component partially collapses — shifts toward a lighter cyan. Distinct from Signal Blue (warmer hue, lighter value). Distinct from Lavender (no blue-purple component). |

**Exclusion zone verification for each:**

| Color | Hue angle | In exclusion zone (18–48°)? | Verdict |
|---|---|---|---|
| Signal Blue | 210° | No (162° clear) | Pass |
| Citron | 63° | No (15° above upper bound) | Pass |
| Lavender | 270° | No (222° clear) | Pass |
| Ice Teal | 175° | No (127° clear) | Pass |

**Deuteranopia pair separability** (critical pairs — most likely to be confused):

- P1 Signal Blue vs P3 Lavender: both blue-family under deuteranopia. Separated by value (Signal Blue is lighter) and hue residue (Lavender shifts more purple). Sufficient for outline-width discrimination at squad-strip icon size. Additional backup: position in squad strip (slot 1 vs slot 3).
- P2 Citron vs P4 Ice Teal: both green-family at full color. Under deuteranopia, Citron shifts yellow and Ice Teal shifts lighter cyan — value difference is maintained. Distinguishable.
- All four under protanopia (red-blind): Blue and Citron remain separable (value contrast). Lavender and Ice Teal remain separable (value and hue residue). No pair collapses.

**Backup cue**: squad colors appear only on the Billboard outline and squad-strip indicators. Position in the squad strip (fixed slot per player) is a non-color disambiguation. A player who cannot distinguish P1 from P3 by color reads slot position instead.

**Usage rule**: squad color appears exclusively on:
- Billboard ImageLabel UIStroke outline (within 30 studs, Section 5.3)
- Squad status indicator UIStroke (top-right strip)
- No other element. Squad color does not tint gear, avatar, or world assets.

---

### 7.6 Diegetic Adaptations

#### Disturbance meter vs. world bioluminescent saturation

The HUD disturbance meter and the world's bioluminescent saturation are two reads of the same underlying `disturbanceScalar` value. They are driven from the same source but are not required to be pixel-synchronous.

**Relationship rule:**

- The world flora responds **immediately** to disturbance scalar changes (Color3 Lerp and pulse-period Tween fire on the same server event that updates the scalar).
- The HUD disturbance meter **follows with a 0.25s `Sine/InOut` Tween lag** (per Section 7.3 meter tick timing).
- **World leads, HUD follows.** The bioluminescent world is the primary read; the HUD is the confirmation. This is intentional: a player watching the world sees the change first, then glances at the HUD. The 0.25s lag is not a bug — it reinforces "the world is the meter."
- Pulse synchrony: HUD elements do **not** pulse synchronously with flora. Flora pulse is a continuous ambient animation. HUD alerts are event-driven spikes. Synchronizing them would create false visual bonding between UI and world, blurring the diegetic/non-diegetic boundary.

#### Ping markers — screen-space

**Recommendation: Screen-space (always-visible 2D arrow at screen edge), not world-space.**

Rationale:
- **Mobile occlusion problem**: world-space ping markers occlude behind terrain geometry. On iPhone SE at 375pt width, the 3D scene has substantial occluder density (cliff faces, caves). A pinged location behind a cliff produces a marker that disappears entirely — useless for squad coordination.
- **Roblox implementation**: screen-space markers are ImageLabels in a ScreenGui, position calculated each frame from `WorldToViewportPoint`. When the target is off-screen, the ImageLabel is repositioned to the screen edge and the chevron icon rotates to point toward the target. This is a standard pattern in Roblox UI and imposes minimal compute cost.
- **Touch parity**: a screen-edge arrow is tap-visible and does not require the player to aim at a 3D object. Fully touch-compatible.
- **Consistency with Section 3.3**: screen-space markers use the same chevron icon and `#F0F0F0` color as the rest of the equipment-register HUD.

**Implementation spec**:
- Marker is a 32 × 32px ImageLabel (ping chevron icon `ui_icon_ping_32.png`), `TextColor3` irrelevant (image), `ImageColor3 = Color3.fromRGB(240, 240, 240)`.
- When target is within viewport: ImageLabel position tracks `WorldToViewportPoint` result. Chevron does not rotate (points down as waypoint indicator).
- When target is off-screen: ImageLabel clamps to nearest screen-edge position (minimum 8px from any edge plus GuiInset). Chevron image rotates to bearing angle (atan2 of direction from screen center to off-screen target position). Rotation applied via `ImageLabel.Rotation`.
- Max concurrent ping markers: 4 (one per squad member). No marker overlap handling required — four squad members pinging simultaneously is a degraded edge case, not a primary flow.
- Ping marker fade-out: Tween `ImageTransparency` from 0 to 1 over 5s after placement. Duration is design-tunable.

#### Squad teammate outline — Billboard behavior at range

Section 5.3 specifies: Billboard ImageLabel UIStroke outline, within 30 studs, squad color.

**Outline shape**: Rectangle, not circular. Hard-corner UIStroke frame (`UIStroke.Thickness = 1`, `UIStroke.Color = [squad color]`, `UIStroke.LineJoinMode = Miter` for hard corners). Frame has no fill (`BackgroundTransparency = 1`). Dimensions: 40 × 56px in Billboard GUI units — approximates the upright-biped bounding box of an R15 character in frame. Does not track exact character pose; it is a fixed-size marker hovering at character position.

**Opacity behavior at range:**

| Range | Billboard opacity | Behavior |
|---|---|---|
| 0–15 studs | `ImageTransparency = 0.7` (near-invisible) | At close range the outline would clutter frame. Squad member is visible directly — outline redundant. Dim it. |
| 15–25 studs | `ImageTransparency = 0` (fully opaque) | Primary read range. Squad color outline is at full visibility. |
| 25–30 studs | `ImageTransparency = 0` → `1.0` linear fade over the 5-stud band | Linear opacity falloff over the 5-stud edge band. Not hard cutoff — hard cutoff at 30 studs produces a visible pop artifact. |
| >30 studs | Billboard disabled (`Enabled = false`) | No marker rendered. Design intent: beyond 30 studs, silhouette + gear is the only read. |

**Implementation**: `BillboardGui.AlwaysOnTop = true` to prevent terrain occlusion within the 30-stud range. This overrides normal depth sorting for the outline only. The outline appears through thin walls — acceptable trade-off for mobile, where detecting a teammate through a low cliff wall is tactically useful and the visual read is not misleading (the outline is a squad-state indicator, not a 3D spatial asset).

**AlwaysOnTop justification**: If `AlwaysOnTop = false`, a teammate two studs behind a thin cliff wall disappears entirely — the player cannot confirm squad position through minimal cover. `AlwaysOnTop = true` within 30 studs is the correct choice for this game's squad-cohesion design goal. It is flagged here explicitly because it is a non-default behavior requiring programmer awareness.

---

### 7.7 Tap-Hold Confirm Visual (Touch Disturbance Actions)

Concept doc commits: every disturbance-creating action on touch (gather, craft, beacon-activate) requires a tap-hold or proximity-gate confirm pattern. This subsection specifies the visual feedback shape; full interaction behavior is owned by the upcoming `/ux-design` pass.

**Visual: Radial fill arc around the tap point.**

- Implementation: a `Frame` with a `UIStroke` (Thickness 3px, Color `#F0F0F0`) and a `UIGradient` whose offset is tweened to fill clockwise. Or alternatively: an `ImageLabel` with a circular progress sprite and a `Tween` on `ImageRectOffset` for sprite-based progress.
- Anchor: centered on the tap location (`AnchorPoint = {0.5, 0.5}`). Diameter ~48px (matches touch target dimension from 7.4).
- Fill duration: configurable per action; default 0.6s.
- On early release: arc resets to 0 over 0.10s (`Cubic/In`). No completion event fires.
- On completion: arc snaps to full circle, briefly flashes `UIStroke.Thickness 3px → 5px → 3px` over 0.1s, then disappears. Confirms action committed.
- Color stays `#F0F0F0` throughout — no mid-fill color change. The fill geometry is the signal.
- Mobile-safe — Tween on UIGradient or ImageRectOffset only. No shader, no particle.

### 7.8 Accessibility Notes

**Death screen text contrast (WCAG AA)**: death screen text is `#F0F0F0` on the cool-dark overlay `#1A1E2B` at 0.75 opacity over the desaturated world. The effective text-on-overlay contrast ratio is ≥ 16:1 — well above WCAG AA's 4.5:1 minimum for body text and AAA's 7:1 for high-stakes content. **Constraint**: any future revision that changes the death overlay color or opacity must re-verify the contrast ratio remains ≥ 4.5:1. Tested in WebAIM contrast checker against the worst-case (overlay over fully bright Hunt-state world).

**Spike alert is non-photosensitive**: the disturbance spike-alert sequence (7.3) uses a 1px → 3px → 1px UIStroke punch + 1.0 → 1.04 UIScale punch + hard-on-then-fade text. **It is not a screen flash.** No frequency exceeds 3 Hz. No large-area red flash. Compliant with WCAG 2.3.1 (Three Flashes or Below Threshold).

**Reduced-motion accessibility toggle (deferred)**: the upcoming `/ux-design` pass owns the reduced-motion design call. Some animations in this game carry gameplay state — flora pulse rate IS the disturbance read; lantern flicker IS a cross-player oxygen warning. These cannot be naively disabled without breaking the visual contract. Reduced-motion fallbacks must be designed per-animation: which animations are decorative (panel transitions, emote wheel open, ping fade-in) and can be reduced/disabled, and which are load-bearing (flora pulse, lantern flicker, predator animation) and must stay enabled. **Required for UX spec.** Not specified here.

**Squad color colorblind backup**: squad colors are reinforced by slot position in the top-right squad strip (P1 always slot 1, P2 always slot 2, etc.) and by the P-number numeric label. A player who cannot distinguish squad colors reads slot position as the disambiguator. See 7.5.

**Cross-platform input parity (flagged for /ux-design)**: ping (single-action input) and emote wheel (multi-stage gesture) require platform-specific input mappings — touch tap vs movement disambiguation, gamepad button assignment, mouse click. These are owned by the `/ux-design` pass and the game-designer's input map. Art bible commits to: visual presentation works across all input methods (screen-space markers + circular wheel) without input-method-specific UI variants.

### 7.9 Locked Decisions

| Decision | Resolution |
|---|---|
| **A — Font** | `Font.GothamMedium` (primary) + `Font.RobotoMono` (numerics). Locked. |
| **B — Ping marker style** | Screen-space (always-visible chevron at screen edge, rotates to bearing off-screen). Locked. World-space rejected on mobile-occlusion grounds. |
| **C — Squad outline at 0–15 studs** | `ImageTransparency = 0.7` near + linear fade at 25–30 studs. Locked. Hard cutoff rejected (visible pop). |
| **D — Citron P2 hue** | `#C8D040` at 63° hue. Locked. Minimum 15° margin from exclusion zone deemed sufficient. |
| **E — Tap-hold confirm visual** | Radial fill arc around tap point. Specified in 7.7. Locked. |
| **F — Reduced-motion toggle** | Deferred to `/ux-design` pass. Section 7.8 records the deferral and the per-animation classification rule. |

---

## 8. Asset Standards

### 8.1 Asset Categories and Folder Structure

Rojo syncs this repo's `assets/art/` tree into Studio Explorer under `ReplicatedStorage/Assets/` (exact mapping owned by technical-artist's Rojo configuration). Canonical source-of-truth structure:

```
assets/art/
├── characters/
│   ├── predator/           # Predator MeshPart geometry, LOD variants
│   ├── player-gear/        # Oxygen pack, wrist cuff MeshParts + low-poly variants
│   └── cosmetics/          # Cosmetic accent decals and color-variant configs
├── environment/
│   ├── terrain/            # Wedge/step geometry prefabs (Part-based — no smooth terrain)
│   ├── precursor-slabs/    # Precursor Slab MeshPart assemblies
│   ├── safe-room/          # Safe room wall, ceiling, threshold, resupply station Parts
│   ├── crash-site/         # Crash pod hull + debris Part assemblies
│   └── claw-marks/         # Beat 2 claw-line Part assemblies
├── flora/
│   ├── trunk/              # Flora trunk + branch Parts (SmoothPlastic, Dead Canopy neutral)
│   └── tip-nodes/          # Flora tip node Parts (Neon material, per disturbance tier)
├── ui/
│   ├── icons/              # All 32×32 icon PNGs (see 8.2)
│   ├── fonts/              # Font reference notes only — Roblox native fonts, no external files
│   └── screens/            # Full-screen ScreenGui layout mockups (PNG; reference only, not imported)
└── reference/
    └── moodboards/         # See 8.6
```

**File types per category:**

| Folder | File types | Notes |
|---|---|---|
| `characters/predator/` | `.fbx` (source), `.rbxm` (Roblox export) | FBX is the handoff to Roblox importer; RBXM is the Studio-ready MeshPart |
| `characters/player-gear/` | `.fbx`, `.rbxm` | One FBX per gear piece; low-poly LOD variant as separate file |
| `characters/cosmetics/` | `.png` (decals), `.json` (color configs) | Decal PNGs only; form-factor changes are never cosmetics (Section 5.1) |
| `environment/` (all subfolders) | `.fbx` for hero MeshParts; `.rbxm` for native Part geometry | Part-based terrain uses no FBX — wedges and blocks are Roblox native |
| `flora/` | `.rbxm` (Part assemblies) | Flora is native Roblox Parts, not imported mesh |
| `ui/icons/` | `.png` (32×32, transparent background) | See 8.2 |
| `ui/screens/` | `.png` (reference mockups) | Not imported to Roblox; design reference only |
| `reference/moodboards/` | `.png`, `.jpg` | See 8.6 |

**No `.psd`, `.ai`, `.blend`, or `.ma` source files committed.** Source working files live in art team's local storage; only export-ready formats are committed.

### 8.2 Naming Conventions

**Locked: `snake_case` for all art binary files.** PascalCase applies to Luau code files only (per `.claude/docs/technical-preferences.md`). Snake_case is human-readable, diff-friendly, and consistent with the `ui_icon_[name]_32.png` convention from Section 7.2.

#### MeshPart sources (`.fbx`) and Roblox exports (`.rbxm`)

```
[category]_[name]_[variant].[ext]
```

| Token | Values |
|---|---|
| `category` | `char`, `env`, `flora`, `ui` |
| `name` | Descriptive noun, no spaces: `predator`, `oxygen_pack`, `precursor_slab` |
| `variant` | `base`, `lod_lo`, `lod_hi`, `debris_01` (numeric suffix for multiples) |

Examples: `char_predator_base.fbx`, `char_predator_lod_lo.fbx`, `char_oxygen_pack_base.fbx`, `env_precursor_slab_pair.rbxm`, `env_safe_room_wall_panel.rbxm`, `env_crash_pod_hull.rbxm`, `env_claw_mark_group.rbxm`.

#### Texture and decal files (`.png`)

Terranova MVP uses no SurfaceAppearance/MaterialVariant. Only PNG textures in production are UI icons + cosmetic decals.

```
ui_icon_[name]_[size].png          — UI icons (Section 7.2 — already locked)
char_cosmetic_decal_[name].png     — Cosmetic pack-face decals
```

Examples: `ui_icon_oxygen_32.png`, `ui_icon_disturbance_32.png`, `char_cosmetic_decal_stripe_01.png`. Size suffix is mandatory for UI icons (encodes source canvas resolution); cosmetic decals omit size suffix (applied at face-fill scale).

#### Animation files (`.rbxm`)

```
anim_[character]_[state]_[index].rbxm
```

Examples: `anim_predator_stalk_01.rbxm`, `anim_predator_lunge_01.rbxm`, `anim_player_idle_lantern_lowered.rbxm`, `anim_player_crouch_idle.rbxm`, `anim_player_breathe_warning.rbxm`, `anim_player_gasp_critical.rbxm`.

#### Sound files (placeholder scope)

```
sfx_[source]_[event]_[index].[ext]
```

Examples: `sfx_predator_stalk_loop_01.ogg`, `sfx_player_gasp_critical_01.ogg`, `sfx_flora_pulse_ambient_01.ogg`. Format: `.ogg` preferred for Roblox upload.

#### Cosmetic accent assets

`char_cosmetic_decal_[name].png` (face decal) + `char_cosmetic_color_[name].json` (HSV record for palette validation; not a Roblox asset, used by pre-flight check).

### 8.3 Color and Material Validation Rules

#### Predator hue exclusion zone (Section 4.2)

**Check point: at asset commit, before merge to main.**

- Exclusion zone: hue 18°–48°, S > 50% in HSV
- Check: HSV gate script run by committing artist (delegated to `gameplay-programmer` to implement as pre-commit hook or CI check) against asset's primary Color3
- For multi-color assets, every distinct Color3 is checked independently
- **Failure**: commit blocked; route to Art Director for review
- **Exception handling**: a Color3 within the exclusion zone may proceed only with Art Director approval logged in `assets/art/reference/asset-decisions.md`

Applies to: cosmetic decal PNGs (dominant color extracted), MeshPart RBXM files (each Part's Color), UI icon PNGs (any fill color > 10% canvas area). Does not apply to predator's own assets.

#### Material family consistency (Section 6.2)

Three locked families: Geological (`Slate`, `Sand`, `Grass`), Fabricated (`SmoothPlastic`), Emissive (`Neon` flora tips only).

> **Rule**: No new Roblox Material may appear on any asset without Art Director sign-off. Artist opens review request, states what new material is needed and why locked families cannot serve. Approval logged in `asset-decisions.md`.

Each family is load-bearing for a visual principle: Geological materials create hard-edge contrast (Principle 1); SmoothPlastic delivers "built, not grown"; Neon is exclusively biological emissive. Adding a fourth material erodes the grammar.

#### Six-color base palette (Section 4.1)

> **Rule**: A new base Color3 not within ± 8 RGB units of the six named palette entries is not permitted without Art Director sign-off. Artist must demonstrate (a) which existing palette entry was tried and why it failed, (b) the proposed color does not conflict with named semantic vocabulary (Section 4.6).

### 8.4 Asset Sign-Off Workflow

All sign-off requests initiated by proposing artist via written brief. Art Director not required as first reviewer — technical-artist and ui-programmer reviews can run in parallel.

**`assets/art/reference/asset-decisions.md`** is the permanent record. Every approved exception to a locked rule is logged: date, asset name, rule waived, rationale, approver.

#### When Art Director sign-off is required

| Trigger | What to submit |
|---|---|
| New MeshPart silhouette (any character or hero environment asset not pre-spec'd in Sections 3–6) | Rendered silhouette image at 4px and 16px widths against neutral grey + written shape-language alignment |
| Color outside locked palette (Section 4.1, > ± 8 RGB units from nearest entry) | HSV values + side-by-side screenshot against nearest palette entry + argument for failure |
| Material outside locked three-family set (Section 6.2) | Material name + screenshot under cool lantern PointLight + written justification |
| New UI icon set or new HUD element shape | 32×32 PNG mockup at actual rendered size + labeled screenshot in Section 7.4 layout grid |
| Cosmetic accent color under exclusion zone review (failed automated check) | HSV values + on-gear context |

#### When technical-artist sign-off is required (in parallel with AD review)

- Polygon count of any new MeshPart
- Texture size and format of any new PNG (cosmetic decals)
- Mobile performance impact of any new PointLight added to a world asset
- LOD mesh review for predator and gear LOD variants

#### When ui-programmer sign-off is required

Any new HUD element added beyond 7.4 layout grid — new screen anchor, new persistent UI frame, or any element not in 7.4's verified non-overlap layout. ui-programmer verifies no iPhone SE overlap and `UDim2` Scale anchoring per Section 7.4.

#### When producer sign-off is required

Adding a new asset *category* (a new top-level folder under `assets/art/` not in 8.1 structure). New category represents scope.

#### Standard procedure

```
1. Artist proposes asset → runs automated HSV gate and material check
2. If gate passes: submit to technical-artist (parallel) and Art Director
3. If gate fails: route to Art Director with explanation before technical review
4. Technical-artist returns verdict (poly budget, perf, mobile impact)
5. Art Director returns verdict (visual identity, palette, silhouette, grammar)
6. If both approve: merge; log any waived rules in asset-decisions.md
7. If either rejects: artist revises and restarts from step 1
```

### 8.5 Cosmetic Pipeline Standards

All cosmetics alter only surfaces in Section 5.1's cosmetic identity table. Silhouette dimensions, emitter face, PointLight color are locked.

#### Cosmetic submission format

1. `char_cosmetic_decal_[name].png` — decal art (32×32 or 64×64, square, transparent background, contained fully within canvas with no bleed)
2. `char_cosmetic_color_[name].json` — HSV record of proposed housing Color3 for automated gate (`{ "h": 210, "s": 0.71, "v": 0.88 }` format)
3. Brief description of where on gear the decal/color applies (pack face, cuff housing, strap)

#### Cosmetic palette gate (automated pre-flight)

- Input: HSV values from `char_cosmetic_color_[name].json`
- Check: `18° <= h <= 48° AND s > 0.50` → **FAIL**
- On FAIL: returned to artist automatically; no human review triggered
- On PASS: proceeds to standard 8.4 workflow

For decal PNGs, dominant color (by pixel area, threshold > 10% canvas) is extracted and run through the same gate. Delegate extraction to `gameplay-programmer`.

#### Cosmetic shop-readiness checklist

| Check | Criteria | Source |
|---|---|---|
| Predator hue gate | Automated pre-flight PASS on all color values | 8.5 gate script |
| Form factor locked | No dimension change to oxygen pack or wrist cuff | Section 5.1 |
| Decal opacity | 100% on all decal pixels — no semi-transparent decals | Section 5.1 |
| Decal contained | Fully within gear face boundary, no overflow | Visual check |
| Material unchanged | No material change from SmoothPlastic on cuff/pack housing | Section 6.2 |
| Emitter face unchanged | Emitter face remains desaturated warm-white Neon per Section 5.1 | Visual check |
| PointLight color unchanged | PointLight Color remains `Color3.fromRGB(200, 210, 230)` | Section 5.1 + 4.8 |
| Silhouette unchanged | Crouched and standing silhouette test images match base at 5px height | Section 5.1 mobile criteria |
| Technical-artist sign-off | Polygon and texture counts verified | 8.4 parallel sign-off |

### 8.6 Reference and Mood-Board Curation

**Locked storage location: `assets/art/reference/`** (co-located with art assets; Rojo excludes this subtree from Studio sync).

```
assets/art/reference/
├── moodboards/              # Curated mood boards (composite PNGs, one per theme)
├── source-images/           # Individual reference photos or screenshots, credited
└── asset-decisions.md       # Record of all rule-waiver approvals (8.3 / 8.4)
```

`moodboards/` and `source-images/` are **not synced to Studio.** Rojo's `default.project.json` must explicitly exclude `assets/art/reference/`. Delegate exclusion to technical-artist.

#### Mood-board naming

```
ref_moodboard_[theme]_v[N].png
```

Examples: `ref_moodboard_lobby-atmosphere_v1.png`, `ref_moodboard_predator-silhouette_v2.png`, `ref_moodboard_flora-bioluminescence_v1.png`. Version increments on meaningful update; prior versions retained.

#### Source-image naming and crediting

```
ref_src_[source-tag]_[descriptor].[ext]
```

`[source-tag]` is a short source identifier: `subnautica`, `alienisolation`, `nasa_jpl`, `flickr_jsmith`. Examples: `ref_src_subnautica_bioluminescent-ocean.jpg`, `ref_src_alienisolation_corridor-darkness.jpg`.

**`assets/art/reference/source-images/credits.md` is required.** Every image in the folder must have an entry: filename, original source URL or citation, license, art-direction note explaining what is being referenced. Images without credit entries are a production violation.

External reference URLs are recorded in `credits.md` but the source image itself is committed — URLs rot; the committed file does not.

### 8.7 Polygon Budgets

Hard caps, not targets. Exceeding requires technical-artist approval before ship.

#### 8.7.1 Per-asset triangle caps

| Asset | Triangle cap | LOD variant | Rationale |
|---|---|---|---|
| **Player character (R15)** | ~2,000 (Roblox platform default) | Roblox automatic LOD past 50 studs | Project does not modify base avatar — gear is separate MeshParts |
| **Oxygen pack MeshPart** | 300 | 60-tri variant, **conditional** (see 8.7.3) | Sufficient for rectangular banding silhouette read at mid-range |
| **Wrist cuff / lantern MeshPart** | 200 | 60-tri variant, **conditional** | Small, wrist-occluded; emitter-head protrusion read is sufficient |
| **Predator MeshPart — full detail** | 1,200 | LOD mesh required >40 studs on mobile | Hero read; eye-shine and three-surface-plane construction need this budget |
| **Predator MeshPart — mobile LOD (>40 studs)** | 300 | This IS the LOD variant | Must preserve: horizontal body axis, dorsal ridge as highest point, ≥3 limb protrusion silhouettes per side. **Do not round the dorsal ridge.** |
| **Flora trunk (per stalk)** | 40 | None — use Part primitives | Narrow structural spine; primitive Part shapes preferred (cylinder/wedge) |
| **Flora tip node (each)** | 16 | None — Neon Parts (primitives) | Neon material provides glow; polygon count adds nothing |
| **Crash pod (hero)** | 800 | None — always-loaded anchor chunk | Hull plating + entry hatch at this budget |
| **Crash pod debris (each)** | 80 | None | 4–6 pieces × 80 tri = ≤480 tri total |
| **Precursor Slab (each)** | Parts only — 0 MeshPart triangles | None | Flat rectangular monoliths use Roblox `Part` (Block shape). 2-3 Parts per slab assembly. |
| **Cliff face / step / safe-room wall** | Parts only | None | All architecture is Part-based per Section 6.2 |

#### 8.7.2 Part count budget per zone

Roblox renderer issues one draw call per unique (Material + Color3 + RenderFidelity) combination unless batched.

| Zone type | Part ceiling | Notes |
|---|---|---|
| Open exterior corridor | 120 Parts | Cliff walls + ground patches + flora + tip nodes + PointLights + 1 Precursor Slab assembly |
| Cave interior | 80 Parts | Smaller spatial footprint; lower ceiling; fewer flora |
| Safe room | 60 Parts | Walls + floor + ceiling + SurfaceLight + threshold; no flora inside |
| Crash site anchor | 100 Parts | Pod hull + debris + ground; always-loaded so higher tolerated |

Keep Materials and Color3 values consolidated to the five-material six-color vocabulary (Sections 4.1 + 6.2) to maximize batching.

#### 8.7.3 Conditional low-poly variant decision gate

Gear MeshPart 60-triangle variants are **deferred until profiling confirms need.** Do not author speculatively.

**Trigger**: sustained frame time above 33ms on iPhone SE during the 4-player cliff corridor test (Section 8.11 Test 1). If test passes, variants are never authored.

### 8.8 Texture Memory Budget

#### 8.8.1 Budget allocation

Hard ceiling: 200 MB total place asset weight (CDN-delivered).

| Category | Target | Ceiling | Notes |
|---|---|---|---|
| Textures (UI icons + decals + accent) | 8 MB | 15 MB | No SurfaceAppearance/MaterialVariant in MVP |
| MeshParts | 5 MB | 10 MB | Predator (2 variants), oxygen pack, wrist cuff, crash pod, debris |
| Audio | 25 MB | 40 MB | Placeholder — audio bible pending. See 8.12 |
| Scripts/ModuleScripts | 2 MB | 5 MB | Luau compresses well |
| Place structure overhead | 5 MB | 8 MB | XML serialization, Part/Instance overhead |
| **Headroom / unaccounted** | — | **122 MB** | Intentional reserve. Do not treat as available without scope discussion. |

Total tracked: 78 MB allocated against 200 MB ceiling.

#### 8.8.2 Per-texture size caps

| Texture type | Max source size | Rationale |
|---|---|---|
| UI icons | 32×32 px | Section 7.2 commitment. No upsize permitted. |
| UI panel/overlay textures | 256×256 px | Most UI is programmatic (UICorner, UIStroke, UIGradient) — no texture |
| Decals (Roblox `Decal` instance on Parts) | 256×256 px | Requires Art Director approval before authoring |
| Predator custom decal (if approved) | 128×128 px | Not in current MVP scope |
| Any unlisted texture | Requires technical-artist sign-off | Default-deny |

#### 8.8.3 Format recommendations

| Use | Format | Why |
|---|---|---|
| UI icons | **PNG-24 with alpha** | Transparent backgrounds; PNG-8 quantizes 2px stroke to dithered artifacts at 32×32 |
| UI panel textures | PNG-24 | No alpha needed; JPEG artifacts on hard-edged geometry |
| Decals with transparency | PNG-24 with alpha | Roblox Decal supports transparent PNG |
| Opaque large textures (out of MVP scope) | JPEG @ 85% | Only if compression artifacts acceptable |

**PNG-8 prohibited for all MVP textures.** File-size savings are negligible against 200 MB budget; quantization artifacts on 6-color palette + 2px strokes are visible.

#### 8.8.4 Roblox upload compression

> **Flag** — Roblox auto-compresses textures on upload to its CDN. Source assets may be larger than CDN weight. Verify that 2px stroke and icon linework survive Roblox compression at 32×32 before MVP. If artifacts appear, technical-artist flags to art-director — icons may need stroke-weight adjustment to survive CDN compression.
>
> *This compression behavior may have changed after January 2026 — verify in Roblox Creator Docs before finalizing texture pipeline.*

### 8.9 MeshPart Import Settings

#### 8.9.1 File format

**Use FBX for all MeshPart imports.** FBX preserves named submeshes (matters for predator eye-shine separation), supports future animation data, and has cleaner material slot naming than OBJ.

> **Flag**: Roblox MeshPart importer behavior evolves with Studio updates. Verify current supported import workflow in Creator Docs before first predator mesh import.

#### 8.9.2 Collision settings

| Asset | CollisionFidelity | Rationale |
|---|---|---|
| Predator MeshPart | `Hull` | Convex hull sufficient for physics-driven threat; PreciseConvexDecomposition adds CPU cost without gameplay benefit |
| Oxygen pack MeshPart | `Box` | Player rig attachment; **must set `CanCollide = false`** to prevent self-collision |
| Wrist cuff MeshPart | `Box` | Same as oxygen pack |
| Crash pod hull | `Hull` | Convex pod shape; players spawn adjacent, not inside |
| Crash pod debris | `Box` | Background scenery; cheap approximate collision |
| All Part-based geometry | N/A | Parts use shape directly (Block, Wedge, Cylinder) |

#### 8.9.3 Material override on import

Critical post-import checklist for every MeshPart:

1. After import, inspect `MeshPart.Material` — confirm correct Roblox built-in Material
2. Set `MeshPart.Material` explicitly — don't leave importer default
3. Confirm `MeshPart.TextureID` is empty (no texture) unless approved Decal assigned
4. Set `MeshPart.Color` to Section 4.1 Color3 for that surface class

> **Flag — Material availability on MeshParts**: Not all Roblox built-in Materials behave identically on MeshPart instances. `Slate`/`Sand` behavior on MeshPart may differ from Part because MeshPart uses imported normals. **Verify `SmoothPlastic` on MeshPart renders as expected under PointLight before committing gear and predator materials.** May have changed since January 2026 — verify against Creator Docs.

### 8.10 Streaming Asset Behavior

#### 8.10.1 StreamingTargetRadius

**Recommended: `Workspace.StreamingTargetRadius = 128 studs`**, with `StreamingMinRadius = 64 studs`.

Rationale: longest gameplay corridor is ~64-stud chunk width. 128-stud radius ensures current chunk + two adjacent chunks load simultaneously. Predator can path across boundaries — 128 studs ensures predator's chunk and player's chunk are both loaded during encounters.

> **Flag**: `StreamingTargetRadius` API may have evolved. Verify property names and behavior in Creator Docs. On low-memory devices, Roblox may honor MinRadius and drop TargetRadius — acceptable for Terranova's corridor layout.

#### 8.10.2 RenderFidelity per asset class

| Asset | RenderFidelity | Rationale |
|---|---|---|
| Predator MeshPart (full detail) | `Precise` | Project manages predator LOD via hand-authored mesh swap at 40 studs. `Automatic` would interfere. |
| Predator MeshPart (LOD variant) | `Performance` | Already simplified; engine reduction at extreme distances adds free mobile headroom |
| Oxygen pack / wrist cuff | `Automatic` | Small, far-from-camera most of the time; let engine manage |
| Crash pod | `Performance` | Always-loaded; mostly viewed from medium distance after spawn |
| Crash pod debris | `Performance` | Background scenery |

Parts: `RenderFidelity` does not apply.

#### 8.10.3 Force-loaded vs streamable

**Force-loaded** (always in memory):

| Asset | Mechanism | Rationale |
|---|---|---|
| Crash pod assembly | `ReplicatedFirst` or `PersistentLoaded` attribute | Squad spawn origin; must be loaded before character appears |
| Active safe room | StreamingEnabled with stream-anchor tag | High-traffic position; interior must load before threshold cross |
| HUD ScreenGui + UI assets | `StarterGui` / `StarterPlayerScripts` | Not part of Workspace streaming; loads with client |

**Streamable** (default behavior): all cliff corridor chunks, cave chunks, exterior flora clusters, Precursor Slab assemblies, non-active safe rooms.

> **Flag**: Force-load API for `Model:SetAttribute("StreamingEnabled", false)` or `ReplicatedFirst` placement may have changed. Verify current best practice in Creator Docs.

### 8.11 Performance Profiling — Blocking QA Gates

Required before MVP ship. Each test has a documented evidence file.

#### Test 1 — 4-Player Squad Hunt-State Frame Time (Mobile)

**Scenario**: 4 players in same 64×64 cliff corridor chunk. Disturbance at Hunt tier (full bioluminescent saturation, max PointLight brightness, all flora pulsing). Predator active in-chunk. All 4 player lanterns active. iPhone SE-class.

**Pass**: sustained frame time ≤ 33ms (30fps floor) for 60-second continuous playthrough. No single frame > 50ms more than twice.

**Validates**: PointLight ceiling (12 flora + 4 player + predator eye-shine = ~17 lights — at the ceiling), Part count per chunk, predator mesh perf, streaming under player density.

**Owner**: technical-artist runs on device. Art-director + lead-programmer sign off on evidence.

#### Test 2 — Death Screen ColorCorrectionEffect Mobile GPU Cost

**Scenario**: single player iPhone SE, dies in Hunt-tier flora corridor. Death sequence triggers (Section 7.3): overlay Frame, vignette UIGradient, `ColorCorrectionEffect.Saturation` tween to -0.5.

**Pass**: GPU cost via Studio MicroProfiler during 0.4s tween < 2ms per frame.

**On fail**: ColorCorrectionEffect disabled on mobile; overlay-frame-only fallback adopted as permanent.

**Decision must be documented**: evidence file states either "ColorCorrection passes — mobile death screen includes post-process" or "ColorCorrection fails — mobile uses overlay-only fallback." Locks mobile death screen implementation.

**Recommendation**: prioritize Test 2 as **pre-implementation spike**, not post-implementation QA gate. Producer schedules device access before death screen story begins.

**Owner**: technical-artist runs profiling. lead-programmer confirms conditional handles both outcomes. Art-director signs off on fallback if effect dropped.

#### Test 3 — Zone Streaming Load (4 Simultaneous Clients)

**Scenario**: 4 clients begin simultaneously in crash site anchor chunk. All move toward first cliff corridor chunk. Measure time from chunk-boundary cross to chunk fully loaded.

**Pass**: chunk loads within 3 seconds of first player crossing on mid-range PC network test. No missing-geometry frames after the 3s window.

**Validates**: StreamingTargetRadius sizing, chunk Part count vs streaming budget, crash site force-load doesn't compete with streaming bandwidth.

**Owner**: technical-artist runs streaming test. network-programmer reviews any server-side coordination.

#### Test 4 — Predator LOD Swap at 40 Studs (Mobile)

**Scenario**: single player iPhone SE, predator visible at 45 studs. Player crosses 40-stud threshold. Observe LOD swap.

**Pass criteria**:
1. No visible silhouette pop on swap. If pop visible, push threshold to 50 studs OR LOD mesh better preserves silhouette edges.
2. No frame-time spike on swap frame (MeshPart property change, not destroy/create).
3. LOD mesh preserves: horizontal body axis, dorsal ridge as highest point, ≥3 limb protrusion silhouettes per side.

**Owner**: technical-artist runs LOD test, documents silhouette comparison. Art-director signs off on visual quality.

### 8.12 Audio Asset Standards (Placeholder)

> **Status**: pending audio-bible authoring. This subsection covers only constraints touching the 200 MB ceiling and mobile performance. Expand when audio bible is authored.

#### Format

Roblox accepts `.ogg`, `.mp3`, `.wav`. **Prefer `.ogg`** for all MVP — OGG Vorbis at equal perceived quality is smaller than MP3, directly reducing CDN weight against 200 MB ceiling.

#### File size guidance (mobile streaming)

| Audio type | Max size | Bitrate target |
|---|---|---|
| Ambient loops (biolume pulse, safe room hum) | 500 KB | 96 kbps OGG |
| Short one-shot SFX (footstep, gather, alert click) | 100 KB | 128 kbps OGG |
| UI sound events | 50 KB | 128 kbps OGG |
| Predator vocalisation (one-shot) | 300 KB | 128 kbps OGG |
| Music (not in current MVP scope) | Requires technical-artist approval | — |

10–15 distinct audio assets at these caps stay well under the 25 MB allocation. Reductions in this allocation must come from headroom reserve or another category.

#### Concurrent voice ceiling

Roblox `SoundService` enforces a concurrent active sounds limit. Mobile handles concurrent sounds less gracefully than PC. **Audio bible should design for max 8 concurrent non-looping sounds on iPhone SE-class.** Ambient loops with `RollOffMode` distance-based may be culled automatically by Roblox spatial audio at distance.

> **Flag**: Concurrent voice limit, spatial audio culling, `RollOffMode` API may have changed since January 2026. Audio-bible author coordinates with technical-artist on final voice count before implementing `SoundService` voice pooling.

### 8.13 Conditional Contingencies

Decisions deferred until profiling reveals their need. Documented here so they don't get lost.

| Trigger | Contingency | Approval needed |
|---|---|---|
| Test 1 (8.11) frame time fails at 8 stalks/chunk | Reduce flora density 8 → 5–6 stalks per chunk. **Section 6.5 must be updated.** | Art-director (vocabulary change) |
| Test 1 reveals Grass material is performance bottleneck | Replace Grass with SmoothPlastic at adjusted Color3 for lichen | Art-director (material vocabulary change — Section 6.2 + 4.1 update) |
| First predator mesh import shows SmoothPlastic specular violates Principle 1 | Adjust Color3 within SmoothPlastic; do **not** switch material class | Art-director + technical-director |
| Test 2 ColorCorrectionEffect fails | Mobile death screen uses overlay-frame-only desaturation (no post-process) | Already pre-authorized; document outcome only |
| Audio assets exceed 25 MB allocation | Draw from 122 MB headroom reserve | Technical-artist approves reallocation |
| Cosmetic asset accent color enters exclusion zone (8.3 gate fail) | Block cosmetic from shop until artist revises | Automated; no human approval to ship a violation |

---

## 9. Reference Direction

Each reference is licensed for one specific visual technique or principle. The "Draw from" entry maps directly to a locked bible commitment. The "Do not import" entry exists because future production teams will instinctively reach for the familiar whole — this section stops that drift before it starts.

### 9.1 Alien: Isolation — Audio-Visual Dread Architecture

**Draw from**: The way *Alien: Isolation* treats the lantern-pool-equivalent (motion tracker / hand-held torch) as the player's only map, with surrounding space held at hard-cut darkness. Specifically: foreground-lit player figure in a near-dark corridor, background unlit zone, threat legible as a shape in mid-ground dark before it is legible as a creature. Maps to Section 2.7 (first predator sighting staging) and Section 3.4 (hero shape compositional hierarchy): foreground lantern pool → mid-ground predator silhouette in darkness → no ambient bridging.

**Do not import**: The sci-fi industrial material vocabulary — riveted steel, corroded vents, orange-and-grey industrial palette. Terranova's world is geological and biological. Any environment reading as a space station is a material-language violation (Section 6.2: three-family vocabulary, no industrial exception).

### 9.2 Subnautica — Single Predator at Scale

**Draw from**: The moment the Reaper Leviathan is first seen from a distance — a dark, slow-moving mass occupying disproportionate frame volume before the player can fully process what they're looking at. The principle: scale registers before detail, before color, before motion. The creature's silhouette is the first horror. Maps to Section 3.1 predator silhouette grammar (horizontal-elongated mass with dorsal ridge, 4-6 player-heights) and Section 5.2 first-encounter staging (full-silhouette-dark first; amber eye-shine only on directional advance).

**Do not import**: Subnautica's bioluminescent color palette — the electric blues, teals, and greens of the ocean floor. Terranova has committed its bioluminescent hue (Spectral Green-Cyan `#22FF8A`, Section 4.3) as an earned design decision grounded in colorblind safety and predator-hue clearance. Pulling broad bioluminescent inspiration from Subnautica risks palette conflation. The amber-versus-green-cyan tension in Terranova is not Subnautica's tension — do not let that game's color identity blur it.

### 9.3 Doors (Roblox) — Hard Contrast as Navigational System

**Draw from**: The way *Doors* treats darkness not as atmosphere but as functional map — lit rooms are explorable, unlit spaces are not, transition between them is architectural. Players learn to read lit area as safe territory without being told. This is Section 1 Principle 1 (Contrast Is the Map) implemented at Roblox-native fidelity. Valuable as an implementation reference precisely because it was achieved within the same engine constraints: Roblox PointLights, no custom shaders, mobile-compatible.

**Do not import**: The room-by-room scripted encounter structure — jump-scare cadence, per-room entity design, door-opening tension loop. Terranova's disturbance system produces emergent predator encounters. Importing scripted-encounter pacing from *Doors* would undermine the "you summoned it" horror and flatten the ecological mechanic into pre-authored beats.

### 9.4 Pressure (Roblox) — Platform-Honest Stylization

**Draw from**: *Pressure* demonstrates that high atmospheric tension is achievable inside Roblox's native aesthetic without fighting platform limitations. Specifically: committing to hard angular geometry, minimizing smooth terrain, using lighting contrast rather than texture density or post-processing to generate dread. The strategic alignment locked in Section 3.2 (angular terrain as primary, smooth-terrain tool prohibited) and Section 6.2 (three-material vocabulary, no SurfaceAppearance in MVP). The precedent exists on the platform — Terranova is not pioneering the constraint, it is operating within a proven framework.

**Do not import**: *Pressure*'s specific entity design language or visual grammar for threats and hazards. Terranova's predator silhouette (Section 3.1) is derived from first principles, not from existing Roblox horror creature conventions. Any influence from familiar Roblox horror entity shapes makes the predator read as "another Roblox horror monster" rather than an apex creature that evolved on this specific planet.

### 9.5 Apeirophobia (Roblox) — Co-op Spatial Fragility

**Draw from**: The way *Apeirophobia* makes squad spacing legible through light — players read the group's dispersal from how their individual light sources relate to each other in space. When the squad spreads, light pools separate; when they cluster, pools merge. This is the carrier element locked in Section 2.2 (Exploration Calm): "Separated lantern pools — each squad member's PointLight creates their own island of visibility." The spatial read of squad-as-light-configuration is an established Roblox-native pattern that Terranova extends and systematizes.

**Do not import**: Apeirophobia's walking-simulator pacing and its tendency toward passive atmosphere over mechanical pressure. Terranova has a resource loop, a disturbance system, an active predator. The visual vocabulary of calm co-op exploration is borrowed from *Apeirophobia*; the mechanical pressure that makes that calm fragile is Terranova's own.

### 9.6 What to Avoid (Overall)

**Generic Roblox horror UI vocabulary.** Saturated red screen vignettes, high-contrast jumpscare text, full-screen white flashes, screaming-red alert colors — the default visual language of Roblox horror. Terranova's HUD is an equipment-register instrument panel (Section 3.3: hard-corner rectangles, stroke-over-fill, no UICorner rounding). Any HUD element that reads as "Roblox horror UI" has abandoned the visual contract. The disturbance spike alert is a border-weight punch and a text pop — not a vignette, not a color flash (Section 7.3 explicitly prohibits vignette on spike-alert for this reason).

**The "bioluminescence aesthetic" as uncritical borrowing.** Bioluminescence has become a genre convention — alien worlds with vivid blues and greens are ubiquitous across games, concept art, and trailers. Terranova's bioluminescent system is mechanically meaningful: saturation is data, not decoration; the specific hue is derived from colorblind-safety + predator-hue clearance (Section 4.3). If production begins adding bioluminescent elements because they "look cool," the disturbance-saturation signal degrades. Every bioluminescent element must earn its place by serving the disturbance read, or it is cut.

**Humanoid-villain creature design.** The predator is explicitly not an upright biped, not a "monster" in the costumed-threat sense, and not something that reads as a designed antagonist (Section 3.1). Any redesign moving the predator toward upright silhouette, symmetrical body plan, or face-forward head orientation drifts toward the humanoid villain category — a shape players are trained to engage, not avoid. The predator's role is "thing you do not fight." Humanoid silhouette grammar undoes that.

**Full-scene ambient lighting as safety shorthand.** When playtesting reads as "too dark," the temptation is to raise `Lighting.Ambient` until the space feels navigable. This is the most common production failure mode for a game built on Principle 1. Higher ambient fills the boundary between lit and unlit zones, softens the lantern-pool edge, and removes the map. Players who say "it's too dark" have not yet internalized that **the darkness is the mechanic.** The correct response is to verify that the dark-to-lit transition is legible (hard edge, not gradient) — not to eliminate the dark.
