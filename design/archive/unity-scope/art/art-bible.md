# Terranova — Art Bible

*Created: 2026-04-21*
*Status: Complete — All 9 sections authored*
*Review Mode: Lean*

---

## Section 1: Visual Identity Statement

### One-Line Visual Rule

**The player's eye should always know where safety ends.**

This is the resolution rule for every ambiguous visual decision: lighting placement, asset silhouette, color contrast, UI legibility, skybox density. If a visual element obscures where threat begins or blurs the edge of the known, it violates this rule. If it sharpens that edge — makes the boundary between lit and unlit, known and unknown, inhabited and wild — it serves the game.

---

### Principle 1: Penumbra Is the Primary Space

**Definition**: The most important visual zone in any scene is not the bright area (safety) or the deep dark (threat) — it is the gradient between them, where the player must make decisions. All scene composition, light placement, and asset staging should maximize the expressiveness of this in-between zone.

**Design test**: When deciding how bright a player-held light source should be, choose the radius that makes the penumbra — the visible but uncertain edge — the dominant visual zone in frame, not the fully lit center. If the player's light creates a wide safe pool with a hard black wall, the radius is too large. If the penumbra itself takes up the most screen real estate, the radius is correct.

**Pillar served**: Pillar 4 — Tension Over Comfort

---

### Principle 2: Scale Speaks Before Color

**Definition**: The alien quality of this world is communicated primarily through size relationships — how tall the canopy is relative to the player, how wide a creature's footprint shadow is before the creature itself is visible, how small a base structure looks against a cliff face. Color palette and texture detail are secondary to scale as the first signal the player receives entering any new space.

**Design test**: When staging a new environment or encounter, check whether the scale story is legible in a greyscale silhouette pass before any color or material work is applied. If the scene reads as "human-sized world" in silhouette, the geometry needs revision regardless of how alien the color palette is. The predator must read as enormous in silhouette at the distance it is first detected — before any behavioral cues trigger.

**Pillar served**: Pillar 1 — The World Is Alive

---

### Principle 3: Biological Color Means Information

**Definition**: Saturated, luminous color — bioluminescence, bloom-edge flowering, spore fields — is not atmospheric decoration. It is the visual language of biological activity, and therefore of ecological disturbance. A quiet, undisturbed scene uses a restricted palette of muted earth tones and low-saturation greens. Color saturation increases as biological activity — and disturbance level — rises. The predator carries a specific hue that appears nowhere else in the world.

**Design test**: When an asset is proposed for a biome, ask whether its color saturation level correctly communicates its biological role. Background flora = low saturation. Interactable resources = mid saturation. Active ecological events (disturbed prey, spore clouds, bioluminescent pulses) = full saturation. If a non-interactive prop reads at full saturation, desaturate it. If the predator shares a color with any ambient environmental element, that color must be reassigned — the predator's hue must be unique and unrepeated.

**Pillar served**: Pillar 2 — Knowledge Is Survival

---

## Section 2: Mood & Atmosphere

### Visual Grammar

Three variables govern all nine game states consistently:

- **Color temperature** encodes player security: warm = human agency, cool = alien indifference
- **Contrast level** encodes player control: low contrast = legibility and calm; high contrast = information loss and threat
- **Saturation level** encodes ecological pressure (per Principle 3): rising saturation signals rising disturbance

The predator's dedicated hue (defined in Section 4) appears as an environmental element only in States 3, 4, and 8.

---

### State 1: First Arrival / Crash Site

**Primary emotion**: Awe-grief — the world is indifferent, not hostile. The player is small and recently bereaved.

**Lighting**: Overcast mid-morning, fully diffuse top-light, no directional source. Color temp: 5800K–6500K (cool, silvery-white). No warm fill. Contrast: low — hull and terrain share similar value range.

**Atmospheric adjectives**: Vast, still, silver-washed, mournful, inaugural

**Energy level**: Contemplative

**Signature visual element**: The crash hull casts a wide, faint shadow gradient that extends toward the player — making them feel enclosed by a structure that no longer protects them. The largest human-made object in the game, and it is already behind them.

---

### State 2: Exploration — Low Disturbance

**Primary emotion**: Wary wonder — gathering, observing, building a mental map. Threat is implied by the quality of silence.

**Lighting**: Early afternoon, low oblique angle (45–60°) creating long readable shadows. Color temp: 5000K–5500K (neutral-cool daylight), faint teal sky fill. Contrast: medium.

**Atmospheric adjectives**: Hushed, geometric, cool-toned, layered, attentive

**Energy level**: Measured

**Bioluminescent state**: Ambient organisms pulse on a **4–6 second cycle**

**Signature visual element**: Parallax shadow layers from alien-tall canopy elements fall on mid-ground at an angle that doesn't match ground-level plant shadows — communicating height without showing the canopy top. The player is always at the bottom of a very tall space.

---

### State 3: Exploration — High Disturbance

**Primary emotion**: Contaminated alertness — something is wrong before the player can name it.

**Lighting**: Same time of day as State 2, but sky fill has shifted — thin cloud layer is colored by higher atmospheric particulate from disturbed bioluminescent spore-producers, casting a faint green-amber tint into ambient shadows. Color temp: 4800K with greenish secondary fill. Contrast: medium-high.

**Atmospheric adjectives**: Humid, electric, over-bright, unsettled, contaminated

**Energy level**: Dread-soaked

**Bioluminescent state**: Same organisms now pulse on a **1–2 second cycle** — the player may not consciously register this immediately, but it creates instinctive unease. This pulse rate is the ecological disturbance meter expressed as ambient light behavior.

**Signature visual element**: Pulse rate acceleration is the primary disturbance readout. Ambient creatures are relocating, not grazing.

---

### State 4: Predator Encounter / Near Miss

**Primary emotion**: Arrested breath — maximum suppressed dread; the player has stopped moving and is trying not to exist.

**Lighting**: Local environmental lighting collapses relative to predator presence. Color temp: deep cool 4200K with the predator's unique hue as a faint edge-light source from the predator's direction. Contrast: very high — zone around predator is sharp-edged; everything else is in deep shadow by comparison.

**Atmospheric adjectives**: Eclipsing, taut, sub-vocal, enormous, wrong-bright

**Energy level**: Suspended — zero ambient creature movement; the world holds still when the predator is present

**Signature visual element**: **Predator rim-light on geometry.** Even when the predator is not in frame, its unique hue creates a colored rim-light gradient on any nearby surface. If it moves behind a ridgeline, the near side of that ridge picks up a faint wash of its hue. Players learn to detect proximity through colored rim-light on environmental geometry before the predator enters frame — terrifying on first occurrence, a survival skill by midgame. *This is a committed art requirement: the predator must emit a localized color light source.*

---

### State 5: Base — Daytime / Working

**Primary emotion**: Provisional safety — productive and relatively secure, but this is a foothold, not a home.

**Lighting**: Player-controlled time, afternoon assumed. Warm artificial light from crash salvage (3200K–3800K) inside base perimeter; ambient alien daylight (5200K) outside. Visible temperature gradient at perimeter edge. Contrast: low inside, medium at perimeter.

**Atmospheric adjectives**: Amber-pooled, provisional, industrious, bordered, grounded

**Energy level**: Purposeful

**Signature visual element**: The thermal gradient at the base perimeter — a 2–3 meter blend zone between warm base light and cool alien light. This seam is the visual definition of "where safety ends" and should be the most deliberately designed lighting element in every base configuration.

---

### State 6: Base — Night / Vulnerable

**Primary emotion**: Siege patience — inside, aware of what is outside, managing that awareness.

**Lighting**: Full night. Alien sky produces dim blue-violet ambient (not pitch black — silhouettes visible without detail). Inside base: 3000K (warmer and more isolated than daytime). Outside: blue-violet sky ambient. Contrast: very high at perimeter — warmth inside, cold dark outside.

**Atmospheric adjectives**: Cloistered, watch-keeping, violet-dark, isolated, aware

**Energy level**: Dread-soaked but static

**Signature visual element**: Bioluminescent organisms outside the base perimeter are visible from inside as distant slow pulses. Non-threatening, but their pulse rate (per States 2/3 logic) is readable from inside the base — the base perimeter gaps function as passive ecological surveillance. If outside pulses accelerate, the player knows the predator is active without going outside.

---

### State 7: Crafting / Progression Milestone

**Primary emotion**: Earned clarity — cognitive satisfaction, not celebration. The reward is understanding.

**Lighting**: Independent of world time. Crafting interface is the primary light source at 3500K, illuminating the player's hands and object from below and front. Background environment softens (reduced contrast, slight DoF). Contrast: low.

**Atmospheric adjectives**: Focused, amber-close, deliberate, resolving, intimate

**Energy level**: Contemplative

**Signature visual element**: The newly crafted object produces a single slow bioluminescent surface pulse — mid-saturation, 2-second fade, using the world's ecological color language (not the predator's hue). Not a UI effect — the world's biological system acknowledging the player has learned to work with it, not against it.

---

### State 8: Death / Failure

**Primary emotion**: Witnessed ending — the world continues without the player; it was never their world.

**Lighting**: Desaturation vignette pulls color from periphery inward over 1.5 seconds, draining to near-monochrome except the predator's hue, which intensifies as everything else fades. Color temp shifts to neutral 4000K; predator hue is the only warm-spectrum element remaining. Contrast: low and falling. *This is a committed production requirement: a dedicated death-state post-process pass is required.*

**Atmospheric adjectives**: Emptying, alien-claimed, flat, hue-dominated, witnessed

**Energy level**: Arrested

**Signature visual element**: Inverse warmth vignette — a cold drain, not an enveloping warmth. The last thing in full color is what killed the player, reinforcing that the predator's hue means death, not danger. Danger was State 4. This is resolution.

---

### State 9: Main Menu / Loading

**Primary emotion**: Suspended arrival — the world exists without the player; scale and patience, no threat implied.

**Lighting**: Pre-dawn. Alien sky at its most complex — layers of atmospheric color without a sun present. Deep violet at zenith, thin pale amber at horizon that never resolves into sunrise. Color temp: 3600K at horizon (false dawn glow), 5800K+ at zenith. No sun source. Contrast: low, soft-edged.

**Atmospheric adjectives**: Pre-inhabited, vast, unhurried, expectant, pre-dawn

**Energy level**: Contemplative — the slowest energy level of any state

**Signature visual element**: A single very slow bioluminescent event in the mid-ground — large scale (too large to be a creature), low frequency (12–20 second pulse cycle), low saturation. The world at rest, luminous and indifferent. It communicates that the world is alive and operating by its own rules before the player makes a single decision.

---

### State Comparison

| State | Temp | Contrast | Saturation | Energy |
|---|---|---|---|---|
| 1. Crash Site | Cool 6000K | Low | Very low | Contemplative |
| 2. Explore Safe | Neutral-cool 5200K | Medium | Low (4–6s pulse) | Measured |
| 3. Explore Danger | Bio-wrong 4800K+green | Med-high | High (1–2s pulse) | Dread-soaked |
| 4. Predator Near | Deep cool + predator hue rim | Very high | Max (predator hue) | Suspended |
| 5. Base Day | Warm inside / cool outside | Low inside | Low | Purposeful |
| 6. Base Night | Warm inside / violet outside | Very high at perimeter | Low (distant pulses) | Static dread |
| 7. Crafting | Warm 3500K | Low (bg soft) | Single mid-sat pulse | Contemplative |
| 8. Death | Draining 4000K + predator hue | Low, falling | Draining (hue persists) | Arrested |
| 9. Main Menu | Pre-dawn gradient | Low | Very low | Contemplative |

---

## Section 3: Shape Language

### Governing Shape Rule

**Organic does not mean safe. Geometric does not mean built.**

On Terranova, shape vocabulary is not a reliable signal of origin or intent. The world uses organic curvature to conceal and entrap. The predator uses geometry to wrong the viewer. Human structures use hard lines not because they are powerful, but because they are comprehensible in a world that resists comprehension.

Every shape decision must answer two questions:
1. Does this shape tell the player what category of thing this is (world, creature, built, resource, threat)?
2. Does this shape communicate the correct relationship between that thing and safety?

If a shape fails either question, it requires revision regardless of aesthetic success in isolation.

---

### 3.1 World Geometry Philosophy

**Primary vocabulary: Macro-scale organic, micro-scale fractal.**

At large scale (structures the player navigates), all forms are organic: smoothly concave or convex, no straight line extending more than 2 meters before curving. Rock formations follow biomorphic bulge-and-pinch logic rather than geological fracture logic — they read as if grown, not broken. The player should never be fully certain whether a terrain feature is geological or biological in origin. This ambiguity serves Principle 2 (Scale Speaks Before Color) and Pillar 2 (Knowledge Is Survival).

At small scale (surface detail, cliff texture, root branching underfoot), shapes become fractal and iterative. The same branching angle repeats at 3–4 scales of magnification — not decoration, but the visual argument that the world operates by biological rules that precede the player's arrival.

**Forbidden geometry in undisturbed zones:**
- No straight edges longer than 2 meters at any scale
- No right angles
- No flat planes larger than 1.5m × 1.5m (rock ledges must be subtly bowed, floors must slope or corrugate)
- No radially symmetric forms (bilateral symmetry permitted; radial symmetry reads as human-designed)
- No sharp convex spikes on background geometry (spines reserved for interactive biological elements)

**Disturbed ecological zones (States 3, 4):**
When the predator has been recently active, biological elements enter a different shape state — normally relaxed fronds and membranes become taut, vine-like organisms retract to expose harder geometry beneath. The world grows more legible and more hostile simultaneously. This is a technical art note: the disturbed state reveals edges the undisturbed state conceals.

---

### 3.2 Player Character Silhouette

**Distinguishing trait: A single thin vertical antenna.**

The player reads as human by contrast with everything else. Four required silhouette properties:

1. **Bilateral symmetry** — in a world where no background element is symmetrical, bilateral symmetry immediately signals "designed object." The suit must not have asymmetric limb shapes.
2. **Blocked-in massing** — the suit silhouette reads as simple blocked volumes at 10+ meters: helmet sphere, torso box, limb cylinders. No fine surface detail readable at range.
3. **Clear neck breakpoint** — helmet is a visually distinct shape from torso with a clear value or silhouette break.
4. **The environmental sensor antenna** — a single thin vertical element rising 15–20cm above the helmet. Perfectly straight. In a world of curves, it is the only straight line that moves. At game camera distances and in moderate occlusion, this is what makes the player findable.

**What is not permitted on the player suit:**
- Organic-curve body sections (hard-shell, not soft biomech)
- Spines, fins, or protrusions that echo world geometry
- Radically asymmetric limb designs

---

### 3.3 Predator Silhouette

**The predator is geometrically wrong: it uses angles that do not exist in nature or in human engineering.**

Its shape must not read as a large animal. Large animals are comprehensible — the player has a mental model. The predator's silhouette must violate organic curvature without replacing it with the legibility of human geometry.

**Primary rule: Non-Euclidean apparent silhouette.** The silhouette appears to change in ways that do not correspond to a single coherent 3D volume. Achieved through layered translucent membrane structures, reticulated surface geometry with multiple overlapping edge profiles, and deliberate avoidance of any dominant axis. The predator does not present a single head-to-tail axis — it reads as organized by different logic than biological symmetry or human design.

**Shape prohibitions for the predator:**
- No clear head-body-tail axis readable at detection range
- No bilateral symmetry at the gross silhouette level (bilateral micro-symmetry in surface detail is permitted)
- No smooth continuous outline — silhouette must have multiple nested edges from overlapping membrane or carapace structures
- No human-associated angles (no right angles, no 45° planar faces, no parallel flat surfaces)
- No biomorphic softness (reads as hard even where technically membrane)

**What it does have:**
- **Scale asymmetry**: one part is significantly larger than the viewer would expect given the whole — the viewer cannot confidently estimate total volume from a partial view
- **Radiating angular extensions at irregular intervals**: not biological spines but geometric extrusions following no organic branching logic. Crystalline or structural, not grown. (Annihilation reference: familiar structures mutated into unfamiliar geometry)
- **Silhouette instability**: moving 15° around the predator reveals a substantially different outline due to nested membrane structures. The player cannot build a stable mental model of its true shape. This is intentional and must be preserved through production.

**Category test**: In greyscale silhouette against world geometry, the predator's outline must not be mistakable for large terrain geometry at detection range. If it can be confused with terrain, the silhouette requires revision.

---

### 3.4 Base Structures Silhouette

**Man-made forms announce themselves through regularity. This announcement is both their purpose and their cost.**

Base structures use unmistakably manufactured vocabulary: straight edges, planar surfaces, parallel and perpendicular faces, consistent modular proportions. This regularity is readable at range, in fog, and in low light — the visual definition of "human zone."

**The visual tension is intentional and must not be resolved.** There must be no art pass that softens base structures to make them "fit" the world. The dissonance between salvage-panel geometry and alien organic forms is not a problem — it is the visual argument for the player's condition.

**What base structures must communicate in silhouette:**
- **Modular assembly**: made of identifiable repeating units, not monolithic sculpted forms. Joins and seams are visible.
- **Provisional construction**: every element reads as load-bearing or enclosing — nothing is ornamental.
- **Age gradient**: older sections acquire world-surface biological growth (alien mosses, membrane-organism attachment). This growth is modeled geometry, not texture-painted. The silhouette shows the contest between manufactured edge and biological encroachment.

**Scale relationship**: A full base complex reads, at distance, as a cluster of small geometric forms at the foot of massively larger organic world geometry. Modelers must resist the temptation to scale up structural elements for visual impact. The structures are small because the player is small.

---

### 3.5 UI Shape Grammar

**The UI belongs to the suit, not the world.**

The HUD is the player suit's onboard display — human-engineered, and it looks human-engineered. Same shape vocabulary as base structures but refined for information display.

**Primary UI shape rules:**
- **Rectilinear and arc-segment frames only.** No organic curves, no biomorphic borders. All corners are 90° or chamfered 45°. This immediately separates UI reading from world reading.
- **No drop shadows or soft edges.** UI elements are hard-edged against the world. Soft edges read as atmospheric.
- **Sparse element count.** Each UI frame contains the minimum information required. Empty space is deliberate — the HUD competes with the world for attention, and the world must usually win.
- **Disturbance meter**: a thin arc segment at the periphery of the HUD. It defines an edge, not a center — echoing Principle 1 (Penumbra Is the Primary Space).

**The biological data exception:**
Suit biological analysis readouts (ecological scan results, entity classification, spore data) use an organic-curve sub-language within the geometric UI frame. When analyzing something biological, the data display grows tendrils and branching structures that echo the world's fractal micro-scale language. This is the one permitted instance of organic shapes in the HUD. The contrast between geometric frame and organic internal data makes biological information feel alive within the machine context. This exception is tied exclusively to biological information.

---

### 3.6 Hero Shapes vs. Supporting Shapes

**Tier 1 — Hero shapes (must be read and acted upon):**
Threats, gatherable resources, craftable outputs, disturbance events. Use convex-dominant profiles with a clear "peak" that catches light. Resources ready for gathering use a rounded bulge form (pressurized or full). Non-predator threats use irregular convex protrusions (spines, swollen membranes) signaling hostility through form before color registers. Craftable outputs use player-suit geometric vocabulary.

**Tier 2 — Mid shapes (environmental legibility, no action required):**
Non-interactive flora, background terrain features, ambient organisms. Smoothly curved, non-fractal at readable scale. The player's eye should pass over without snagging.

**Tier 3 — Supporting shapes (pure fill, no information):**
Ground surface texture, sky geometry, distant terrain mass. Handled through texture and material, not mesh geometry. Never add polygon budget to a supporting-shape element "to add interest."

**The resource tell:**
All gatherable resources read as slightly out of place against immediate surroundings — a mineral deposit has a growth angle inconsistent with surrounding gravity-following logic; a biological resource cluster has density that reads as cultivated rather than wild. Shape is the first signal; color (mid-saturation per Principle 3) is confirmation. Gatherable resources must be identifiable in greyscale silhouette before color registers.

**The predator as exception:**
The predator transitions across all three tiers as it closes: at detection range it reads as Tier 3 (barely differentiated from the dark environment), transitions through Tier 2 (large shape, cannot yet categorize), then resolves into Tier 1 (individual geometry readable, player must act). The early detection cue is rim-light (Section 2, State 4), not shape. If the player is reading the predator's shape clearly, the encounter has already escalated beyond the ideal detection window.

---

## Section 4: Color System

### Governing Color Rule

**Saturation is not style. Saturation is a meter.**

Hue identifies what something is. Value communicates its relationship to the light source. Saturation communicates biological activity level — and by extension, danger. An artist who correctly assigns saturation has done most of the semantic work, regardless of hue.

---

### 4.1 Primary Palette

Seven colors constitute the world's complete visual vocabulary. No hue outside this palette may be introduced without an art director review.

---

**1. ASHEN** — H 210°, neutral-low saturation, mid-low luminance
*Role: World base tone. The ground state of the world at rest.*

The default color of undisturbed Terranova. Every biome tilts away from this baseline, but it is always present in shadowed areas, background geology, and unexplored terrain. Ashen carries a faint cool-blue parent hue — not grey, not concrete, not earthen. The color of a world that has been here longer than anything warm.

Appears in: background terrain, rock formations, crash hull mid-tones, aged base structure exterior panels. Must not appear in interactive elements at full mid-ground visibility.

---

**2. SPORE-TEAL** — H 175°, mid saturation, mid luminance
*Role: Ecological health indicator. The biological normal.*

The primary bioluminescent hue. The color of a world in equilibrium — not safe, but undisturbed. Appears in ambient organisms at low disturbance, in healthy plant-adjacent forms, and as the default pulse color of bioluminescent life.

When an ecological system is healthy, its bioluminescent elements pulse in spore-teal. Disturbance does not change the hue — it changes saturation and pulse rate (per Principle 3). Spore-teal at 4–6 second pulse = equilibrium. Spore-teal at 1–2 second pulse = pressure. The hue stays constant; the behavior tells the story.

Appears in: ambient bioluminescent organisms, healthy interactable flora, atmospheric particles in low-disturbance states, crafted objects' post-crafting surface pulse. Does not appear in the predator, base structures, or any HUD element.

---

**3. VOID-BLUE** — H 250°, low-mid saturation, low luminance
*Role: Alien sky. Indifference at scale.*

The color of Terranova's night sky and upper atmosphere. Sits in the perceptual dead zone between blue and violet — cool and deep without being black. The predator cannot own anything near this range (the sky would echo it and destroy signal uniqueness).

Appears in: night sky, deep shadow atmosphere, farthest-reach ambient fill in any scene. A depth cue and scale cue — it communicates that the space above and around the player operates by physics the player cannot control.

---

**4. SALVAGE AMBER** — H 35°, mid-high saturation, mid-high luminance
*Role: Human agency. Warmth as manufactured origin marker.*

The color of base lighting, crafting interfaces, and the HUD. Explicitly warm in a cool world — it does not belong here, and that wrongness is the point. Every base structure's interior light sources emit salvage amber. When a player sees this color, they have either made it or found something a human made before them.

Appears in: base interior lighting, HUD elements, crafting interfaces, player-held light inner radius, crash site interior light sources. Does not appear in undisturbed ecological zones. Maintain minimum 150° hue separation between salvage amber and any ecological element sharing its saturation tier.

---

**5. SILT-GREEN** — H 80°–95°, low saturation, mid luminance
*Role: Biological transition. The in-between state.*

The hue of organic matter in its passive, non-light-emitting state. Present in the membranes of resting organisms, underside of large flora, biological growth on aged base structures. Deliberately unremarkable — when it is everywhere, the player stops seeing it. This makes its absence notable: a zone stripped of silt-green biological ground cover has been recently disturbed.

Appears in: passive organism surfaces, base structure biological encroachment geometry, background foliage mass, foreground substrate. Its high-quantity presence should generate low-grade unease — this is a design asset.

---

**6. BREACH-WHITE** — H 0° (achromatic), very high luminance, zero saturation
*Role: Emergency signal. Human-engineered alarm.*

The single achromatic element. Not used atmospherically — pure signal. When breach-white appears, it requires a decision. The only color designed to pull the player's eye away from the world and toward specific information.

Appears in: HUD critical state overlays, suit integrity breach readout. Does not appear on the disturbance pulse leading edge — that signal uses spore-teal driven to Tier 3 luminance (see Section 4.3). Overuse destroys its function — if anything other than a genuine critical signal of manufactured-system origin uses breach-white, that usage must be reassigned immediately.

---

**7. CAUL** — H 305°, S 65%, L 38%
*Role: The predator. Wrongness with no name.*

Caul is the predator's dedicated hue and the most important single color decision in this game. It must not appear anywhere else in the world.

Named after the amniotic membrane that occasionally covers a newborn's face at birth — a living film, associated with biological intimacy and historically considered an omen. In isolation, caul reads as mauve or bruised violet-pink. In the context of Terranova's cool-blue, teal-green, amber-human world, it reads as the one thing that does not fit any system the player has learned to read. Not "danger." Wrong.

**Hue justification**: H 305° sits between violet (H ~270°, owned by void-blue's parent family) and magenta (H 330°, cosmetic connotation risk) — the perceptual gap where human color categorization is least confident. Readable against the cool world palette (130° hue distance from spore-teal, 50° from void-blue). Not red (too culturally loaded), not orange (too legible), not yellow-green (too close to State 3 disturbed atmosphere). Low luminance (L 38%) means it reads as dark and internal — biological, not electric. The correct viewer response is "bruise." Bruised things are evidence that something with force has been present. Caul is the color of the predator's passage before the predator is understood.

**Caul rules — most strictly policed in the art bible:**
- The predator's surface materials emit caul as their self-illumination component
- The predator's rim-light effect on surrounding geometry uses caul at reduced saturation (S 30–40%, blended into surface normal-based light falloff)
- The death-state desaturation post-process preserves caul as the final remaining hue (Section 2, State 8)
- No flora, terrain, sky, UI element, resource indicator, or atmospheric particle may use any hue within 20° of caul (H 285°–325°)
- If a proposed asset's natural color falls within the caul range, that asset's color must be reassigned

---

### 4.2 Semantic Color Vocabulary

An artist adding a new asset answers three questions to determine correct color assignment:
1. Is it biological (world-origin) or manufactured (human-origin)?
2. What is its interaction state (background / interactive / active event)?
3. Does it have a relationship to the predator?

These answers fully determine color assignment.

**Danger (escalating ecological pressure):** Not communicated by a specific hue. Communicated by saturation level and pulse rate of spore-teal bioluminescent elements. Do not add red danger indicators or pulsing warning hues. The world's biological language is the danger indicator. Exception: HUD disturbance meter uses salvage amber shifting toward breach-white — a manufactured (suit) signal, not a world signal.

**Resources (gatherable materials):** Mid-saturation. Biological resources: warm silt-green shifted toward spore-teal (H 95°–155°, S 35–55%). Geological/mineral resources: ashen base with luminosity increase only — no saturation increase. *The rule: biological resources glow; geological resources glint.*

**Ecological health:** Expressed through density and saturation of spore-teal elements per unit area. Healthy zones have many mid-saturation spore-teal elements. Depleted zones have fewer at lower saturation. Predator-active zones have zero — stripped clean. Model ecological damage by removing spore-teal elements, not recoloring them.

**Threat (non-predator hostile fauna):** Spore-teal displaced toward silt-green, at high saturation, with convex protrusive shapes (per Section 3). Non-predator threats belong to the same ecosystem as everything else — they are the world's biological language in a hostile configuration.

**Threat (predator):** Caul only. Any other color treatment of the predator is a category error.

**Human presence:** Salvage amber. Aged or damaged human objects lose saturation toward ashen but retain a slight warm cast — even ruin reads warmer than the world around it. A fully desaturated human object has been entirely consumed by the world.

---

### 4.3 Saturation Gradient Rules

| Tier | Range | State | What uses it |
|---|---|---|---|
| **Tier 0** | S 0–20% | Inert / Background | Background terrain, sky, crash hull exterior, dead biology |
| **Tier 1** | S 20–40% | Passive Ecological | Living undisturbed biology; dominant tier in low-disturbance scenes |
| **Tier 2** | S 40–65% | Active Ecological | Resources ready for gathering, disturbed fauna, biological events |
| **Tier 3** | S 65–100% | Event / Predator | Predator caul self-illumination, max-disturbance pulse peak (spore-teal at Tier 3 luminance — not breach-white), breach-white alerts |

**Bioluminescent pulse behavior by tier:**
- Tier 1 pulse: 4–6 second cycle, luminance oscillation stays within Tier 1
- Tier 2 pulse: 1–2 second cycle (high disturbance); sustained without pulse for active events; luminance peak briefly touches Tier 3 — the peak flash is the alarm
- Predator: sustained Tier 3, no pulse. Sustained high-tier saturation that does not pulse is the predator's behavioral signature in the color system.

No background or passive element may sustain Tier 3 saturation. A sustained Tier 3 reading outside of the predator or an active HUD critical alert is an immediate art review flag.

---

### 4.4 Per-Biome Color Temperature Rules

The world palette is fixed. Biomes are expressed by tilting the temperature of the ashen base tone and dominant fill light direction. Semantic hues (spore-teal, caul, salvage amber, breach-white) are never reassigned. The predator's caul must read correctly in every biome.

Each biome is specifiable by three values: ambient temperature offset (K), secondary shadow fill tint, and biological density tier (sparse / medium / dense).

---

**The Shallows** (MVP biome)
*Humid, dense, tropical-wrong. The most biologically rich biome.*

- Ambient temp: +300K above baseline (≈5500K)
- Secondary shadow fill: faint warm yellow-green from canopy light filtration (must not approach caul range)
- Biological density: dense — the highest spore-teal bioluminescent presence in the game; the optimal environment for learning the pulse-rate readout
- High-disturbance shift: atmospheric particulate increases, sky fill shifts toward green-amber contamination (State 3); warmth becomes fever-warmth

---

**The Rift Zone** (full vision biome)
*Cold, geological, sparse biology. The world without warmth.*

- Ambient temp: −800K below baseline (≈4400K)
- Secondary shadow fill: near-black with blue tint; rift walls absorb more light than any other surface in the game
- Biological density: sparse — bioluminescence clusters near hydrothermal features only; its presence is alarming rather than ambient
- High-disturbance shift: bioluminescent elements increase in density (new light sources appear rather than existing ones brightening) — disturbance signal is addition, not intensification

**General rule for future biomes:** A biome may shift the temperature of non-semantic elements. It may not reassign semantic hues. If a biome requires a new color to feel distinct, the problem is density and temperature — adjust those first.

**Universal high-disturbance shift rule (all biomes):** At disturbance level 7+/10, ambient temperature shifts 200–400K colder and the secondary shadow fill gains a component of the biome's contamination tint. Subtle enough that the player would not consciously identify it, but generates increasing unease.

---

### 4.5 UI Palette

**The HUD is a salvage amber system operating under manufactured duress.**

The suit's HUD pre-dates the planet. Its color system does not borrow from or respond to the world's biological vocabulary — which is why it reads as immediately, unambiguously separate from world color at every saturation tier.

- **Primary elements** (framing, borders, labels): Salvage amber S 55–65%, L 45–55%
- **Secondary elements** (data fills, progress indicators): Salvage amber S 30–45%
- **Inactive / standby elements**: Ashen (S 5–15%, L 40–50%)

**Alert escalation:**
- Advisory: primary salvage amber, no change
- Warning: salvage amber luminance +15% — attention-drawing without panic
- Critical: breach-white — one element at a time; multiple critical alerts are queued by fatality priority

**The HUD must never use caul.** If any HUD element appears to require caul (e.g., a "predator detected" indicator), it must use a shape signal — a dedicated icon — over a breach-white substrate. Never caul coloring.

**Biological data readout sub-palette:** Biological analysis readouts use spore-teal (Tier 1–2) for data content within salvage amber frames. The two-color frame/content rule must be maintained — frame is always salvage amber, data content is always spore-teal.

---

### 4.6 Colorblind Safety

| Signal | Hue | Risk Type | Severity |
|---|---|---|---|
| Spore-teal | H 175° | Deuteranopia/Protanopia | Medium — mitigated by pulse-rate dual-signal |
| **Caul (predator)** | H 305° | Tritanopia / Deuteranopia | **Critical — must have full backup** |
| Salvage amber | H 35° | Deuteranopia/Protanopia | Medium — mitigated by luminance and geometry |
| Breach-white | Achromatic | None | None |
| Silt-green | H 88° | Deuteranopia | Low — semantic background only |

**Spore-teal backup:** Pulse rate (4–6s vs 1–2s) is hue-independent. HUD disturbance meter mirrors ecological pulse state numerically. Mitigated — no additional overlay required.

**Caul backup (critical — all four required simultaneously):**
1. **Shape-on-geometry overlay**: Where caul rim-light would appear, a luminance-only surface normal contrast increase is applied — directional geometry brightening independent of color
2. **Audio frequency marker**: A sub-bass frequency rises in presence proportional to caul rim-light intensity — constant-presence tone, not a sound effect
3. **HUD proximity indicator**: Edge-vignette indicator on HUD border (directional, matching predator bearing), using breach-white substrate with shape-based icon; off by default for sighted players, on by default in colorblind-assist mode
4. **Colorblind-assist mode**: A fine radial line pattern overlay on all caul-saturated surfaces — the predator reads as "patterned" rather than specifically caul-colored; this pattern must not appear on any other surface

**Salvage amber backup:** Base perimeter outer face emits a thin luminance-increase rim on the side facing the world — value-contrast signal independent of warm-cool hue distinction.

**Implementation note:** Colorblind-assist mode requires a global shader flag enabling the caul pattern overlay and activating the HUD directional indicator. Requires the AI system to expose predator world-space bearing to the UI system.

---

## Section 5: Character Design Direction

### 5.0 Governing Character Rule

**Every character in Terranova communicates its relationship to the survival system through form, not through labeling.**

The player suit reads as human engineering under duress. The predator reads as biology operating by rules the player cannot fully model. Every other creature reads as part of the world's ecological system — neither threatening nor safe in isolation, but meaningful as signal. A 3D artist finishing any character asset should be able to answer: "What does this tell the player about where they stand?" If the answer is unclear, the asset requires revision.

---

### 5.1 Player Character Visual Direction

#### 5.1.1 Suit Philosophy

The player's suit is the most important single asset in the game. It is the only human-manufactured wearable in the world. It is the visual container for the player's survival state, and in co-op, the player's body is the clearest signal of friendly presence in an environment that offers no reliable legible signs.

The suit is hard-shell construction. It does not flex or breathe — it holds. The material vocabulary is salvaged aerospace-industrial: machined surfaces with visible production marks, panel seams with recessed fasteners, worn matte-anodized finishes in service colors. Nothing about it was designed for this planet. Nothing about it was designed to look alien. It was designed for a different context entirely, and it reads like it.

#### 5.1.2 First-Person Presentation (Hands and Arms)

The player sees gloved hands and suited forearms at all times. These are the primary rendering surface for suit condition and wear state, because they occupy center-frame.

**Proportions**: The gloves are thick-fingered and over-built — industrial grip, not tactical precision. The forearm casing has a wider profile than a human forearm beneath it, blocked-in to match the mass silhouette established in Section 3.2. The wrist joint is a visible rotational ring, clearly mechanical — a breakpoint the player can read.

**Surface material at maximum detail (LOD 0, arms-distance)**: The suit surface has three distinct surface zones readable at full detail:
1. **Structural panels** — smooth matte finish, salvage amber color treatment at S 40–50%, L 40–50%. Subtle directional grain from machining, not enough to break flatness at reading distance. Hard specular on panel edges only (chamfered 45° edges catch light in a single clean highlight).
2. **Joint and articulation zones** — visually recessed, matte black, no specular. These are the technical voids in the human engineering aesthetic — they should not catch attention.
3. **Sensor patches and HUD emitter zones** — small geometric inset panels flush with the suit surface. In ambient light, they read as dark salvage amber (S 30%, L 30%). When HUD is active, they emit the HUD display light from their surface rather than from air in front of them. See Section 5.1.4 for HUD integration.

**Handed asymmetry is the single permitted exception to the bilateral rule**: the right glove carries a recessed sensor interface module on the dorsal surface (back of hand). This is the player's suit-mounted scanner. It must not break the blocked-in mass silhouette in side profile — the module sits flush or 3–5mm proud at most.

#### 5.1.3 Third-Person / Co-Op Presentation

In co-op, the player's own character is visible. The full suit silhouette must be legible at 15 meters — another player scanning the environment must be able to immediately distinguish their co-op partner from any fauna archetype or environmental element.

**Silhouette requirements at 15m** (LOD 2):
- Bilateral symmetry intact — this is the primary recognition signal
- Helmet sphere distinct from torso mass — neck breakpoint must read as a value break, not just a shape break. The helmet slightly warmer or slightly lighter in local light than the torso to maintain the read in shadow
- The antenna: 15–20cm above helmet apex, 3–4mm diameter rod, perfectly vertical. Its bilateral position (centered on helmet sagittal axis) is correct. At LOD 2, the antenna renders as a single-pixel line — this is acceptable and expected. It moves with the player and reads as an intentional object, not a rendering artifact
- Arms: visually distinct from torso mass at rest position. Rest position is arms slightly out from body (a result of the suit's bulk, not a posed stance). This prevents the character from reading as a monolith in silhouette

**Color treatment in third-person**: The suit uses salvage amber as its primary identifying hue (S 40–50%, L 45–55% on major panels). This is the only human-identified color in the co-op environment. If two players' suits are identically colored, the secondary differentiation is trim markings — a thin chamfered stripe on helmet and upper arm using a value-shifted version of salvage amber, not a new hue. No player customization may introduce a hue outside the established palette.

#### 5.1.4 Suit Wear States and Ecological Interaction

The suit has three progressive wear states. Each state is the base mesh plus a texture overlay that accumulates through gameplay events — the overlay system allows per-panel state variation without requiring separate authored meshes. The production pipeline requires one suit mesh plus a wear overlay texture set with three tiers of authored content.

**Wear State 0 — Intact**: Salvage amber panels at full S 40–50%. Fastener seams clean. No biological material contact visible. Overlay mask at zero opacity.

**Wear State 1 — Ecologically Contacted**: Panel anodizing degraded at high-friction zones (forearm edges, kneepad equivalents, glove grip surface). Salvage amber S drops 10–15% at wear zones via overlay texture. Silt-green biological material present at articulation joints — visible as thin streaks following the joint recesses, biological matter that worked into the mechanical seams. At LOD 0, this resolves as textured biological film driven by the overlay mask. At LOD 1, it reads as a value-darkened seam. The overlay mask value drives the transition from zero coverage (State 0) to full joint coverage (State 1) and is continuously updated by the suit environmental contact system. Biological contact material at this state is silt-green Tier 1 (passive, non-luminescent) — the suit has encountered the world's biology, but the encounter was mundane.

**Wear State 2 — Critical**: Breach indicator on helmet visor frame — breach-white trace along the compromised section perimeter, hair-line width at full integrity, widening toward full panel-edge illumination at critical failure. The overlay at this state applies biological coverage across panel surfaces — silt-green material advances onto panel faces, not just seams. At articulation joints, the biological material shows faint bioluminescent pulse (spore-teal, Tier 1, 4–6s cycle), driven by the overlay material's emissive parameter, which is activated when State 2 is entered. The breach-white element on the visor is the only critical-state visual signal allowed to appear on the suit surface itself. No additional color signals.

**Design test for wear states**: The player must be able to read the current wear state from first-person view using only the forearm panels visible in frame. If State 1 is not distinguishable from State 0 without looking at the HUD, the biological coverage density in the overlay requires adjustment.

#### 5.1.5 HUD Integration and Projection System

The HUD does not float in screen-space as a conventional overlay. It is projected from the suit's interior visor surface — the player is looking through a visor that has display elements embedded in it. This distinction has production implications.

**Visual treatment**: HUD elements have a faint parallax offset relative to background geometry as the player turns their head. This is a 2–4 pixel drift at standard FOV, implemented as a camera-relative screen-space offset. The parallax must be subtle enough not to cause eye strain but present enough to physically ground the HUD on the visor surface rather than in space.

**Edge glow at HUD emitter zones**: The inset sensor patches emit salvage amber light outward from their surface when the HUD is active. This light falls on the near face of the gloves and forearm when the hands are at center-frame, producing a faint amber fill that integrates the HUD light into the scene lighting. The strength of this fill is tied to HUD alert state: Advisory = faint ambient, Warning = moderate fill, Critical = strong fill with flicker on the breach-white element only.

**The HUD must not occlude environmental information**: The total screen area covered by HUD elements at any time must not exceed 12% of screen space. The center 80% of screen is always world.

**Biological data readout exception** (from Section 3.5): When the scanner is active, the biological data readout extends a tendril-branching display structure from its sensor panel. This display uses spore-teal data content within a salvage amber frame. The branching structure reads as the suit interpreting biological information in a language borrowed from the biology itself — the machine using the world's own grammar to report what it found.

#### 5.1.6 Antenna: Placement and Purpose

The environmental sensor antenna is centered on the suit helmet's sagittal axis, rising from the apex. It does not move independently — no flex, no secondary animation. It is a rigid rod.

**Production specification**: 3–4mm diameter, 15–20cm length, matte salvage amber material matching the suit panels. No specular. At its tip, a 2mm-diameter dome element — the sensor head — which reads as a minimally different value, not a different color. In game camera, the antenna will often read as a single line against complex background geometry. This is correct behavior. It must remain perfectly vertical in model space. The physical simulation may not apply secondary motion to the antenna under any circumstances — its rigidity is semantically meaningful in a world of organic movement.

**Design test**: When the player character is viewed from 15 meters in third-person against the world's organic background geometry, the antenna must be findable within 2 seconds of looking at the character. If it reads as part of background structure, its luminance or local contrast requires adjustment.

---

### 5.2 Predator Visual Direction

#### 5.2.1 Surface Material Philosophy

The predator is not carapace. It is not membrane. It is both simultaneously, and the failure of either category to hold is the point.

At a distance, the predator reads as massive and dark — almost geological. As it closes, the surface resolves into a material system that has no biological precedent the player will recognize: overlapping structures that appear to be both rigid and translucent at the same time, the way mica is simultaneously stone and see-through.

**Material layers (inner to outer)**:
1. **Interior mass** — Never fully visible. It reads as a dark, internally complex volume through the outer structures. Emits caul (H 305°, S 65%, L 38°) as self-illumination from within this interior volume.
2. **Structural extensions** — The geometric angular extrusions described in Section 3.3. Near-opaque, low specularity on flat faces, high specular on true edge only (edges are sharp as a fracture, not chamfered). They do not emit caul — they pass it through where thin enough, and block it where thick.
3. **Outer membranes** — Translucent, layered. Not skin. Not glass. Layers of biological material through which interior light is visible but diffused. The caul interior glow is transmitted through these membranes and arrives at the outer surface as a low-saturation wash (S 30–40%). The membranes carry silt-green and ashen color when the predator is cold (not active) — in this state they are nearly invisible against the world's background palette, which is correct and intended.

**The threshold event**: When the predator engages, the interior self-illumination increases in intensity. The caul glow transmitted through the outer membranes shifts from S 30–40% to full S 65%. There is no roar, no posture change, no dramatic animation cue — just the interior light coming on, seen through the surface the player has been looking at without understanding what they were seeing.

#### 5.2.2 Caul Self-Illumination

The predator's caul emission is an interior volumetric glow, not a surface emissive. The technical target in URP is a surface emissive material with a normal-map-driven occlusion pass that prevents emission at membrane-thickened zones, creating the impression of an internal source rather than a surface-lit object.

**Emission behavior**:
- At rest (far detection range): Interior emission at L 20–25% — barely present.
- At active hunt: Interior emission at L 38% (full caul specification). Transmitted through membranes at S 30–40%, concentrated at structural extension gaps and thin membrane zones at S 50–65%.
- The predator does not pulse. Pulsing is the biological world's disturbance language. The predator is outside that language — its light is steady, which reads as more wrong than pulsing, because the player has been trained to read pulse-rate as the ecological signal, and the predator provides nothing to read. The steady glow refuses to be a signal. It is a presence.

**Rim-light on geometry** (technical requirement confirmed in Section 2, State 4): The predator carries a world-space caul point-light (L 38%, S 30–40% tint) that casts rim-light on geometry within a 20–30 meter radius. This light should not be culled when the predator is within 40 meters of the player — pending confirmation with the technical artist against the URP dynamic light budget. At 20 meters it is strong enough to tint the facing normals of rock, structure, and flora geometry. At 30 meters, it is a faint wash. Beyond 30 meters, ambient scene lighting reasserts.

This light source must remain functional even when the predator is out of frame, around corners, or behind terrain. It is the earliest player-available detection cue. Coordinate with the technical artist to ensure the URP light budget allocates this as a high-priority dynamic light.

#### 5.2.3 Distance Reading and Encounter Escalation

The predator's visual information scales with proximity. An artist must author the predator to read correctly at four ranges simultaneously.

**Stage 1 — Far Detection (40–80m)**: The predator is a large dark mass with no readable surface detail. The caul interior emission is at rest level (L 20–25%). The only reliable detection cue is rim-light on nearby geometry. In silhouette and greyscale, the predator at this range must cause the player to stop moving and look harder, not immediately run. If it reads as immediately obviously predator at 60 meters, the material and emission levels require adjustment toward Tier 2 ambiguity.

**Stage 2 — Mid-Range (15–40m)**: The predator's surface begins resolving. Membrane layering visible as overlapping translucent planes. Structural extensions readable as angular extrusions — wrong geometry that doesn't match the world or any animal. The caul interior emission is transmitting through thin membrane sections as visible light patches. Silhouette instability fully apparent at this range — moving 15° reveals a substantially different profile.

**Stage 3 — Near (5–15m)**: Individual surface features readable. Structural extension fracture-sharp edges visible. Membrane layer depth apparent. The caul emission from interior gaps is bright enough to produce visible light on the immediate ground surface beneath the predator.

**Stage 4 — Contact (0–5m)**: The player sees a portion of the predator's surface at close detail. No full-body read available — the predator is too large and too close to frame as a whole entity. At contact range it must feel too large to understand. If the player can see enough to have a complete mental model of its shape, the predator is too small.

#### 5.2.4 Movement and Animation Visual Implications

The predator does not walk. It does not have a locomotion mode the player can name.

**Movement visual principle**: The predator relocates rather than moves. Between two positions, the reader cannot confidently track a single axis of motion — the mass appears to fold, extend, and compress in ways that do not conserve a visible center of gravity. No single joint drives movement; multiple structural volumes shift simultaneously without a clear master motion.

**What the predator must not do**: stride, swim, glide, or present a front and back that remain consistent through a full movement cycle.

**What the predator does**: It transitions between positions through a collapse-and-extension sequence in which the dominant visible volume changes. What appeared largest from one angle recedes; what was secondary advances. This is achieved through complex skeletal deformation on the membrane elements combined with visibility-state toggling on discrete structural extension elements — a technical note for the rigger. Coordinate with the technical artist on implementation approach.

---

### 5.3 Fauna Archetypes

The world contains creatures that are not the predator. Their visual function is threefold: they make the world feel inhabited, they carry the ecological health signal, and they establish the silhouette contrast baseline that makes the predator's silhouette identifiably wrong.

Every fauna archetype must pass the **category test**: at detection range in silhouette, a player who has encountered the predator must not confuse any fauna archetype with the predator. Silhouette must be distinct in at least two of: overall scale, axis orientation, edge quality, bilateral symmetry.

#### Archetype 1 — Drifter

**Role**: Ambient bioluminescent organism. Ecological health visible indicator. Most common visible creature in The Shallows.

**Scale**: 0.3m–0.8m diameter.

**Silhouette**: Radially symmetrical from below — a dome or bell form with trailing filaments hanging beneath. In profile, reads as a soft convex dome above a vertical cluster of hanging strands.

**Color treatment**: Body in silt-green Tier 0–1 (S 15–30%). Filament tips carry spore-teal bioluminescence, Tier 1–2. Equilibrium: 4–6s pulse. Disturbance: 1–2s pulse. Drifters do not change hue — they are the world's pulse-rate meter made visible and mobile. When drifters accelerate their pulse, the player has a visual disturbance readout they can follow across terrain. A zone without drifters has been recently under predator pressure.

#### Archetype 2 — Grazer

**Role**: Mid-size fauna. Ecological health indicator in the middle ecosystem tier. Most likely to be near gatherable resources.

**Scale**: 1.2m–2.0m at shoulder equivalent.

**Silhouette**: Bilateral symmetry at the gross level, but not in a way that reads as familiar vertebrate structure. Body mass is low-slung and wide — the creature covers ground horizontally rather than rising vertically. No neck extension. Four or six attachment points to ground, not legs — wider at the base than at the body, with no clear joint division.

**Color treatment**: Silt-green base (H 88°, S 20–30%). No bioluminescence in passive state. When feeding actively, the contact zone shifts toward spore-teal S 30%. When spooked (by predator or player proximity), the body surface mottles — silt-green patches desaturate toward ashen while other patches briefly brighten to Tier 2 — a panic pattern, not threat coloring.

#### Archetype 3 — Borer

**Role**: Hostile non-predator fauna. Environmental hazard. Occupies disturbed ecological zones and resource-extraction areas.

**Scale**: 0.4m–0.6m body length. Tube-bodied, horizontal. Difficult to see until close.

**Silhouette**: Elongated horizontal tube with convex protrusions on the anterior end. Moves with sinuous locomotion along substrate surfaces. From above (most common view angle), reads as a thin line with a wider blob at one end. The convex protrusions on the anterior echo the Tier 1 hero shape vocabulary — the player who has internalized the shape language reads the borer's anterior as "this part does the damage."

**Color treatment**: Silt-green base at Tier 1 (S 25–35%). When agitated (player within 2m), the anterior probe zone shifts to spore-teal Tier 2 (S 45–55%) for the duration of engagement. This is the world's ecological color language in a hostile configuration — not a designed warning sign, but the same biological activity signal used throughout the world, here expressing predatory behavior.

#### Archetype 4 — Column Former

**Role**: Ambient fauna forming the world's vertical element. Sessile or near-sessile, in dense clusters, producing the canopy height that makes the player feel small.

**Scale**: 4m–12m height. This fauna provides the scale contrast invoked in Principle 2 (Scale Speaks Before Color).

**Silhouette**: Vertical axis dominant. Single column or multi-stalk cluster that tapers, bulges, and pinches along its height (no 2m straight section). At the apex, a spreading structure creates the canopy layering visible in State 2. Column formers are one of the clearest expressions of the world's biological-is-geological ambiguity — at 20m they read like geological columns; at 2m they are clearly living biological material.

**Color treatment**: Silt-green Tier 0–1 on trunk surfaces (S 10–20%). Apex spreading structure carries spore-teal bioluminescent material at Tier 1 (S 20–35%) — visible from the player's below-looking-up view as a faint luminous canopy fringe. In high disturbance, canopy fringe pulse rate accelerates. Column formers in predator-stripped zones show no apex bioluminescence — the canopy is dark, and the player is beneath a dark ceiling rather than a faintly glowing one.

---

### 5.4 Expression and Pose Style

#### 5.4.1 Player Suit Animation

The suit communicates through limitation, not expressiveness. Suit animations are the physical argument that the player is encased in protective equipment designed for a different context, operating in a world it was not designed for.

**First-person hand animation style**: Deliberate and weighted. The hands do not gesture — they act. Idle animations are minimal: small postural shifts of individual fingers, no whole-hand or wrist animation unless a specific tool is held. Every suit animation should feel like a procedure, not an improvisation.

**Third-person (co-op) animation style**: The suit reads as slightly stiffer than a human body in motion. Walking gaits prioritize the blocked-in mass reading — the torso does not sway, the head does not bob. The goal is a character who reads as human inside a machine, not as a machine performing human motion.

**Reactive animations**: The suit has two permitted reactive states visible in third-person — crouched (disturbance avoidance posture, reduces vertical silhouette ~30%) and looking-up (predator response). Both states have immediate entry and exit — no blending, snapping to state. The suit responds to threat with mechanical efficiency, not natural fluidity.

#### 5.4.2 Fauna Animation Principle

**Alien biology moves with internal logic that does not prioritize the player's comprehension.**

No fauna archetype has an animation that reads as "noticing the player" in the sense of acknowledging the player's significance. A startle response begins at the fauna's sensory surface — it does not begin in a "look toward the player" rotation. The distinction: fauna treat the player as an environmental variable. The predator treats the player as a target — it is the only creature that explicitly orients to the player. Every other creature's indifference makes the predator's attention categorically different and therefore terrifying.

---

### 5.5 LOD Philosophy

| LOD Level | Distance Range | Detail Level |
|---|---|---|
| LOD 0 | 0–8m | Maximum: full surface detail, wear overlay state, biological material, joint articulation |
| LOD 1 | 8–20m | Medium: primary surface material reads, silhouette-critical geometry, no wear state fine detail |
| LOD 2 | 20–40m | Low: silhouette and primary color block only |
| LOD 3 | 40m+ | Impostors or geometry-only, extreme silhouette simplification |

**Non-negotiable semantic signals that must persist through LOD reduction:**
- Player suit bilateral symmetry: readable at LOD 3
- Player suit antenna: readable at LOD 2 as a single-pixel vertical line; must not disappear at LOD 3
- Predator silhouette instability: membrane layering must be preserved through LOD 1; at LOD 2, simplified membranes acceptable if gross silhouette remains non-bilateral and angular
- Bioluminescent pulse: all bioluminescent materials maintain emission at all LOD levels; mesh simplification may reduce geometry but the emissive material must not be stripped

#### 5.5.1 Predator LOD as Tier Transition

At LOD 3 (40m+ / Stage 1): The predator reads as Tier 2 ambiguity — large dark mass, possible terrain, possible predator. Caul emission at rest (L 20–25%). The rim-light on surrounding geometry is the only confirmed cue, and it operates independently of the predator's LOD state (the world-space point light is not subject to mesh LOD).

At LOD 2 (20–40m / Stage 2): Silhouette instability becomes apparent. The LOD 2 mesh must preserve enough membrane geometry to produce the wrong silhouette reading — coordinate with the technical artist to ensure the LOD 2 mesh captures at least two overlapping membrane planes producing silhouette fringe.

At LOD 1 (8–20m / Stage 3): Full surface material reading begins. Caul emission through membranes visible. The transition from LOD 2 to LOD 1 must not produce a pop — increase LOD 1 mesh detail to close the difference if necessary.

At LOD 0 (0–8m / Stage 4): Maximum detail. Surface detail at LOD 0 must be disturbing — the translucent layering, the interior glow depth, the fracture-edge structural extensions — and must not be comprehensible as a single organized system. Too much, too close.

**The predator's rim-light is LOD-independent**: The caul point-light source operates at all distances regardless of the predator's LOD state. It is a world-space light carried by the predator, not a mesh property.

---

### 5.6 Character Design Test Suite

**Player Suit Tests:**
1. In third-person at 15 meters against complex organic world background, the bilateral symmetry is readable in 2 seconds or less.
2. The antenna is findable within 2 seconds at 15 meters against organic background geometry.
3. At LOD 2, the suit reads as clearly manufactured (geometric vocabulary) against organic world geometry.
4. Wear State 1 is distinguishable from State 0 from first-person forearm view without consulting the HUD.
5. The HUD edge-glow emission from sensor patches does not visually compete with the world's bioluminescent elements at the same screen distance.

**Predator Tests:**
1. At 60 meters in greyscale silhouette against rock formations, the predator causes hesitation rather than immediate recognition.
2. Moving 15 degrees around the predator at 20 meters produces a measurably different silhouette read.
3. The predator's caul rim-light on a neutral grey (ashen-equivalent) surface at 20 meters is visible without HUD assist.
4. The predator at LOD 0 (5m) does not allow the player to form a complete mental model of its surface structure in a single frame.
5. The caul hue on the predator's surface is not confusable with any fauna archetype or environmental element in any of the nine game states.

**Fauna Archetype Tests:**
1. All four fauna archetypes are identifiable as distinct from the predator in silhouette at detection range.
2. The drifter's pulse-rate change (4–6s to 1–2s) is readable without stopping to count cycles — it must feel faster, not require timing.
3. The borer's hostile anterior zone color shift (silt-green to spore-teal Tier 2) is readable at the player's action distance (2m) against the ground substrate.
4. Column formers at 60 meters do not produce a visual silhouette that could be confused with the predator's mass profile.

---

## Section 6: Environment Design Language

### 6.1 Geological Logic

**The planet was shaped by pressure from below and biology from above. The player is caught between them.**

Terranova's terrain forms are explained by two forces operating at different scales and timescales. At geological scale, the planet's interior generates irregular upwelling pressure — slow, high-viscosity extrusion of dense mineral material through fissure networks that do not follow a readable tectonic grid. This produces terrain that reads as swollen, pressurized, and rounded rather than fractured and angular. Rock formations are not shattered — they are pushed outward. Cliffs are not shear faces — they are convex bulges at massive scale, as if the interior is still pressing.

At biological scale, organisms of exceptional scale and longevity have colonized every exposed surface over millennia. Root-analogue structures exert continuous tensile pressure against geological forms. Organic membranes bridge crevices that would otherwise expose sharp mineral edges. Almost no geological surface is bare — raw rock is transitional, visible only where the surface was recently exposed (crash impact craters, active hydrothermal vent margins, sites of predator-caused trauma to large biological structures).

**The governing geological rule**: every terrain form must be explainable by one of these two forces. A cliff that reads as a shear fracture belongs to neither logic and must be revised. A dome-shaped rock formation whose top is colonized by biological growth and whose underside reveals raw extrusion texture at the overhang edge is geologically correct for this world.

**Silhouette rules for terrain:**
- At skyline: terrain profiles are dome-convex or smoothly concave — no jagged spires, no blade ridges. Irregular heights are achieved through variable-height domes of different radii, not through points.
- At mid-ground: cliff geometry is bulging convex at the face, with deep concave undercut bases. The cliff leans toward the viewer — the sense that the ground above is overhung.
- At foreground: the ground surface is never flat. Every 3×3m area must include a minimum 15cm vertical variance through biological root-ridge formations, mineral extrusion nubs, or surface organism terrain. True flat ground does not exist.
- Cave interiors follow the same logic but inverted: biological growth hangs from ceilings (tensile, downward-reaching), mineral extrusion protrudes upward from floors. Caves are contested spaces between upward pressure and downward growth.

**The test for new terrain geometry**: Cover the asset in a flat diffuse grey material and render it from 5 angles. If any silhouette produces a straight edge longer than 2m, a right angle, or a flat plane larger than 1.5m × 1.5m, it violates the geological rule. Send back for revision before material assignment begins.

---

### 6.2 Texture Philosophy

**Stylized PBR is not a compromise. The stylization lives entirely in value relationships and saturation discipline, not in flat or toon shading.**

Terranova's textures must read as physically plausible materials under consistent lighting while maintaining the semantic color system defined in Section 4. Roughness maps are physically accurate, normal maps are geologically or biologically motivated, and albedo textures contain real-world value variance. Stylization is achieved by keeping albedo saturation strictly within the tier assignments from Section 4.3, and by making value contrast decisions based on visual hierarchy rather than photographic reference. If a texture would look correct in a photograph of real terrain but violates the saturation tier it should occupy, it is photorealistic but wrong for this game.

**Texel density policy:**
- Hero surfaces (foreground terrain within 8m, base structure panels, crash hull near player): 512px per meter. Normal and roughness maps at same density.
- Mid-ground surfaces (terrain 8–30m, background flora canopy, cliff faces): 256px per meter. Normal maps at full density, roughness maps at half.
- Background surfaces (terrain beyond 30m, skybox-adjacent geometry): 128px per meter. Normal maps optional; roughness may be baked into albedo.
- All textures: power-of-2 dimensions, authored at highest tier with LOD chain generated by asset pipeline. Do not hand-author LOD textures.

**Four surface types and their layering order:**

Every environmental surface is constructed from these four types, applied in order from bottom to top.

**Layer 1 — Geological Base**: The mineral substrate. Ashen-range albedo (H 200–220°, S 5–15%, L 30–50%). Roughness: 0.75–0.90 (geological surfaces are uniformly non-specular except at wet vent margins). Normal detail: medium-frequency extrusion texture, macro-convex reading at tile edge. Metallic: zero on all geological surfaces. The geological base communicates age and mass.

**Layer 2 — Passive Biological Coating**: A thin continuous layer of silt-green surface organisms that colonize all exposed geological surfaces over time. Silt-green (H 80–95°, S 15–30%). Roughness: slightly lower than geological base (0.60–0.75). Applied as a soft mask of silt-green that follows surface convexity — accumulates on upper surfaces, thins on undercut overhangs and vertical cliff faces. Its absence at a specific location is the primary visual indicator that a surface has been recently disturbed.

**Layer 3 — Active Biological Growth**: Modeled geometry, not painted texture. Biological organisms of substantial scale (0.1m to 2m+ in The Shallows) grow from Layer 2 as separate mesh elements. Their surfaces occupy spore-teal (Tier 1 undisturbed) and silt-green ranges. These elements retract and expose harder geometry in disturbed states via vertex animation or blend shapes deforming inward — disturbance is a geometric state change, not a texture swap. Transition: 3–5 second blend to disturbed state; 30–60 second blend to restore (biology recovers slowly).

**Layer 4 — Human Salvage Surfaces**: Applied only at crash site, base structures, and salvage field debris. Salvage amber base (H 35°, S 40–60% on lit panels, dropping to S 15–25% on aged/corroded areas). Damage decal layers: scoring, impact deformation, corrosion — as authored decal textures with roughness variation. Layer 2 passive coating begins appearing on salvage panels after 72 hours of game time. Layer 3 active growth begins attaching at the aged-state threshold.

**How biological coverage reads at LOD distances:**

At LOD 0: Layer 3 active biological growth is full geometry with vertex animation or blend shape support.
At LOD 1 (8–20m): Layer 3 mesh complexity halves; vertex animation freezes but mesh shape is maintained.
At LOD 2 (20–50m): Layer 3 geometry reduces to low-poly silhouette cards. Layer 2 and Layer 1 merge into a combined albedo texture.
At LOD 3 (50m+): All biological coverage represented by a single albedo-plus-normal atlas. Layer 3 presence indicated by spore-teal albedo patches and heightfield normal approximation. No transparency.

**Critical LOD rule**: The saturation tier of the surface must be maintained across all LOD levels. A LOD 3 surface must not increase in saturation relative to its LOD 0 state. Verify saturation consistency in the final LOD chain before asset submission.

---

### 6.3 Prop Density Rules

**Density is an information system, not a beauty system.**

Every prop placed in an environment occupies the player's visual attention budget. High-density areas require active parsing. Low-density areas communicate importance through openness. The rule for prop placement is not "what makes this look interesting" but "what does this density level tell the player about this area."

**The Shallows — High Density (Dense Biological)**

Target: 8–12 distinct biological prop elements visible within 10m radius of player at any point in the biome.

Rule for adding a prop: Ask whether the prop performs one of three functions: (1) cover/navigation obstacle, (2) ecological state indicator (pulse rate visible, silt-green coating readable), (3) resource location marker. If it does none of these, do not add it regardless of how the space feels visually.

Rule for removing a prop: If any point allows the player to see more than 20m of clear sightline, that sightline has been opened incorrectly. Either add biological props to restore appropriate density or redesign the navigation corridor if the open sightline is intentional.

**The Rift Zone — Sparse Density (Geological, Sparse Biological)**

Target: 2–4 geological prop elements visible within 10m radius. Biological props cluster within 3m of active hydrothermal features only — no biological props in non-vent areas.

Reasoning: The Rift Zone's openness is its primary emotional statement. The player can see farther and feels more exposed. Bioluminescent elements near vents are alarming precisely because they are isolated — the player has learned that bioluminescence means biological health, and here it is concentrated in unnatural proximity to heat sources.

Rule for adding a prop: Must be geological in origin or a biological element within 3m of a vent. Any biological prop more than 3m from a vent is a design error.

Rule for removing a prop: If any 10m radius contains more than 4 geological props, the Rift Zone's emptiness is compromised.

**Crash Site / Base Interior — Manufactured Density**

- Active work areas (crafting station adjacency, equipment storage): 6–8 props within 5m radius. Every prop visually readable as a specific functional object. No decorative clutter.
- Transition spaces (corridors, airlocks, perimeter edges): 2–4 props. Navigation unobstructed.
- Exterior debris field (crash impact scatter): Graduated density — highest within 10m of hull breach, declining to 1–2 props per 10m at 40m radius.
- Abandoned/aged areas: 0–2 props; biological growth on walls and floors compensates. The biological takeover of unused human space is an environmental story beat.

Rule for adding a manufactured prop: It must have a plausible origin story (came off the ship, was built from salvaged materials). Props without explainable origins are not permitted. If a prop's origin cannot be answered in one sentence, it should not be in the scene.

**Natural Clearings and Navigation Corridors — Intentional Sparseness**

Rule for not adding a prop: In any space that functions as a navigation waypoint, decision point, or safe zone, additional props are prohibited unless they serve as resource markers or navigation anchors. If the space feels empty, that feeling is correct — do not fill it.

---

### 6.4 Crash Site Visual Rules

**The crash site is a clock. Its visual state tells the player how long they have survived.**

| Stage | Hull Exterior | Debris Field | Biology Radius | Emotional Read |
|---|---|---|---|---|
| Hour Zero | S 40–50% amber, no biology | Dense, clean | 20m cleared | Arrival, exposure |
| Early game | S 35–45%, coating at seams | Outer debris greening | 12m cleared | Foothold forming |
| Mid game | S 25–40%, Layer 2 coat | Debris integrating | 6m cleared | Provisional home |
| Late game | S 15–25%, Layer 3 growth | Debris indistinguishable | 2–3m at perimeter | World is winning |

**Hour Zero**: The hull is fresh impact. Surrounding terrain shows a scar of cleared biological matter extending 60–80m in the approach direction. The hull is structurally distorted at contact faces but recognizably manufactured — straight panels, salvage amber lighting in breach gaps. Biological absence within 20m of the hull from thermal and physical trauma. This openness makes the crash site feel enormous and exposed — the correct emotional state for first arrival (Section 2, State 1).

**Mid game**: The hull reads as integrated. Salvage amber interior lighting is the visual anchor of the player's base volume. Biological growth is visible on the original hull at Layer 2 coverage and early Layer 3 attachment. Visual test: at mid-game, the crash site must read as "human foothold" not "human outpost." If the base looks permanent from 20m, the biological encroachment modeling is insufficient.

**Late game**: Hull exterior at unused sections is at Layer 3 biological growth — actual organism attachment geometry visible. The salvage amber of the hull exterior has desaturated toward ashen as corrosion has progressed. Interior spaces remain amber-lit and intentionally clean — the contrast between maintained interior and surrendered exterior is the visual argument for the player's situation. The debris field at distance is no longer identifiable as human-origin. Only shape (straight edges, parallel surfaces) distinguishes debris from geological forms at distance.

**Visual rule**: Biological encroachment maps to distance from active player use. High-traffic paths remain clean. Low-traffic areas acquire coating. This is authored by level artists at each game stage milestone — deliberate decisions about which surfaces tell the story of neglect vs. active use.

---

### 6.5 Environmental Storytelling Techniques

**The world records events in its surface. Artists must author these records deliberately.**

#### Technique 1 — Predator Territory Markers (Compression Traces)

When the predator traverses an area, it exerts significant downward force at irregular intervals that compress the biological ground layer. These compression traces appear as areas where Layer 3 active biological growth has been pressed flat or driven into the substrate — not torn or scorched, but compressed. The surface depression has a specific geometry: irregular oval or elongated footprint (the predator does not have bilateral-symmetric feet), 0.6–1.2m in its longest dimension, with surrounding biological mat at the edge showing slight outward displacement.

**Age-reading compression traces**: Layer 2 passive biological coating re-colonizes compression traces within 20–30 game-hours. A fresh trace (center exposed, geological base visible) means the predator was here hours ago. A partially regrown trace (edge coating at 50%, center bare) means 12–24 hours ago. A fully regrown trace (surface restored but with a subtle surface normal anomaly from the original displacement) means the predator has a route through this area. Multiple traces at different ages indicate a patrol path.

**Production note:** Compression traces are generated at runtime from the predator's pathfinding system — a dedicated trace emitter component on the predator spawns decal instances at the pathfinding waypoint contacts, driven by the same disturbance system that drives ecological response. The trace decal has a continuous aging shader parameter (fresh → mid-age → recovered) driven by game-time since emission, managed by the disturbance simulation. Three shader states are authored: fresh (geological base exposed), mid-age (partial Layer 2 recovery), old (fully recovered surface normal, subtle displacement only). The trace system requires the predator's pathfinding to expose waypoint contact events to the visual systems layer — flag for technical art implementation. The visual distribution of traces should correspond naturally to actual predator routes because it is generated from them.

#### Technique 2 — Ecological Succession Layering

Different areas of the world are at different stages of biological succession — the sequence in which organism types colonize a surface. Early succession: geological base plus thin passive coating (Layers 1+2 only). Mid succession: Layer 3 pioneer organisms — small, round, low-profile. Late succession: full canopy organisms at maximum height with Layer 3 biodiversity. The stage of succession visible in an area communicates how long it has been since significant disruption.

Areas near the crash approach path are in early succession. Players who pay attention will realize that following the crash approach path back tells them the direction from which they came. Areas where the predator is historically most active are in perpetual early-to-mid succession. An area of late succession tells the player: nothing has disrupted this area for a very long time. It is either safe or the predator has no interest in it.

**Production note**: Ecological succession is authored by level designers as a zone property. Each environment area has a succession stage tag (Early / Mid / Late) that determines which Layer 3 asset set is applied, which LOD variant of Layer 2 coverage is used, and what canopy height tier is permissible.

#### Technique 3 — Salvage Archaeology

Human presence before the player arrived is recorded in the surface condition of objects that were part of the ship. Wear patterns on interior surfaces reveal which corridors were used most. Specific cargo items from the ship have arrived at locations far from the crash site — a container bearing salvage amber panel markings appears embedded in a cliff face 300m from the hull, having left the ship during atmospheric entry. Finding these objects tells the player about the trajectory and violence of the crash without any map or cutscene.

**Production note**: Pre-crash salvage objects use the same salvage surface material as base structures but at a forced advanced aging state (minimum mid-game encroachment level, because they have been on the surface longer than the crash). Objects embedded in terrain must show terrain disturbance geometry at the embed point — the terrain was displaced when the object arrived, and that displacement is still visible as an irregular surface depression.

#### Technique 4 — Biological Depletion Rings

When the player gathers from biological resource nodes repeatedly, the area around that node shows signs of ecological depletion. Layer 3 organisms adjacent to a frequently gathered node show stress positioning: fronds partially retracted, the transitional state between undisturbed and disturbed geometry caused by extraction rather than predator activity. The silt-green coating in a 2m radius around a repeatedly harvested node is slightly less dense.

Crucially, a heavily depleted area generates the same early-succession biological visual state as predator-active territory. The player who understands the system will realize they have, in their own way, created the conditions that attract the predator. The environment makes this argument visually, without text.

**Production note**: Depletion ring states are authored as a blend shape or material parameter driven by the gameplay resource system's depletion value at each node. Full health: undisturbed geometry, full Layer 3, full Layer 2 coating. 50% depletion: Layer 3 elements in transitional state, Layer 2 density reduced by 40% in the 2m radius. Fully depleted: Layer 3 retracted to expose geological base, Layer 2 suppressed — same visual state as predator compression trace area. This parameter must be driven from gameplay code to the environment material system — flag for technical art implementation.

---

### 6.6 Biome Transition Types

**Biome boundaries on Terranova are never walls. They are gradients with internal logic.**

A biome transition is the record of where two different ecological communities have been competing. The transition zone is not a blend of both biomes' aesthetics — it is a specific third state with its own visual character.

**Transition Type A — Ecological Gradient (The Shallows to any mid-zone): 30–50m**

As the player moves away from The Shallows core, canopy height steps down in tiers over 30–50 meters. Each height step corresponds to a species that cannot sustain itself at lower biological density and has retreated toward the denser core.

Visual signals the player receives in sequence as they move away from The Shallows:
1. Canopy height begins stepping down — visible in skyline silhouette
2. Density of Layer 3 ground-level organisms decreases, opening ground sightlines
3. Bioluminescent ambient pulse elements become less frequent; ambient light color temperature shifts subtly as fewer biological light sources contribute
4. Color temperature of the biome begins cooling (Shallows +300K shifts toward the baseline) — over the full 50m transition, not abruptly
5. Ground Layer 2 passive coating begins thinning — geological base more visible

A player who has learned to read the world will recognize they are leaving The Shallows when the canopy steps down, not when a text indicator appears.

**Transition Type B — Geological Boundary (→ The Rift Zone): 10–15m**

The Rift Zone begins at a structural geological discontinuity — a rift edge where terrain drops into a deep geological formation. The transition is asymmetric: from above, the player sees biological community at the rim and open geological space below. The rim itself is biologically depleted — too exposed and too dry to sustain Shallows-equivalent density.

Visual signals at the Rift Zone boundary:
1. Ground surface transitions from biological substrate to geological base within 5m of the rift edge
2. The rift wall below is visible — raw geological extrusion geometry, minimal biological coating
3. Ambient temperature read drops visibly — blue-cool Rift Zone fill light visible below before the player descends
4. Bioluminescent elements absent at the rim, then visible only at hydrothermal vent bases far below

**Audio design note (flagged for audio director sync)**: Biome transitions must have corresponding ambient audio transitions. The 50m visual gradient should be a 50m audio gradient. The Rift Zone's faster visual transition (10–15m) should be a faster audio crossfade. The visual and audio density curves must be authored to the same transition distances.

**Rules for future biome transitions**: Any new biome boundary must be one of three types: Ecological Gradient (slow, biology-driven), Geological Boundary (fast, structural), or Trauma Boundary (20–30m, marking where a major event — crash impact, predator catastrophic activity — has reset the biological state and created a succession void between otherwise adjacent communities).

---

### 6.7 Technical Art Notes for Environment

**Modular kit — use for:**
- All base structure and crash hull surfaces: exterior wall panels, interior corridor segments, hatch and doorframe components, structural flooring. The aesthetic of modularity is correct and enforced.
- Geological base terrain in tiling areas: cliff face segments, rift wall tiles, cavern ceiling and floor tile sets. Seam breaks must use irregular break geometry (a protruding mineral nub or biological organism covers each seam point) to prevent visible grid repetition.
- Layer 2 passive biological coating: always a tileable material, never a modeled element. Use triplanar UV projection on all geological surfaces.

**Bespoke sculpting — use for:**
- Hero geological formations that serve as navigation landmarks or silhouette elements.
- All Layer 3 active biological growth elements with unique profile (largest organisms, major root arch systems).
- Compression traces and other environmental storytelling geometry (see 6.5).
- Crash hull deformation geometry at impact zones.

**Ecological disturbance — two channels:**

**Geometry channel (Layer 3)**: Disturbance is represented through vertex animation or blend shapes moving biological forms from undisturbed (relaxed, open, space-occupying) to disturbed (retracted, taut, reduced silhouette). This affects silhouette and spatial volume — the disturbed state makes terrain more navigable and more legible. Driven by the disturbance value from the gameplay system.

**Shader channel (Layers 1 and 2)**: In the disturbed state, Layer 2 roughness increases slightly, albedo saturation drops by 10–15%, and bioluminescent self-illumination frequency increases (pulse rate acceleration, per Section 2, States 2/3). These shader changes accompany the geometry changes but operate independently.

**The combined disturbance read**: At low disturbance, geometry is fully open, shaders in passive state. At medium disturbance, geometry is transitioning, shaders accelerating. At high disturbance, geometry is fully retracted, shader pulse at maximum, and the predator's caul rim-light contributes to surrounding surface appearance. The world becomes more geometrically legible and more atmospherically alarming simultaneously.

**Draw call budget note**: Target fewer than 200 draw calls from environment assets within player render distance. Layer 3 biological growth in The Shallows represents the primary draw call risk — implement GPU instancing per biological element category (all similar frond types in one batch), not per individual instance. Flag for the technical artist to validate against the 500-call total budget from the performance specification, accounting for character, VFX, and UI draw calls sharing that budget.

---

## Section 7: UI/HUD Visual Direction

### Governing UI Rule

**The suit knows things the player cannot see. The HUD's job is to communicate exactly those things — nothing more.**

Every HUD element must pass a single justification test: does the player need this information to survive, and does the world fail to communicate it clearly enough on its own? If the world can teach it through consequence, the HUD should not say it. If the world cannot say it at all — oxygen level, suit breach integrity, disturbance meter in total darkness — then the HUD is the correct and only channel. This test eliminates decoration, reinforces diegesis, and directly serves the design constraint that knowing when to panic is the skill.

---

### 7.0 HUD Element Priority Hierarchy

Five systems are tracked in the HUD. Visual prominence, escalation urgency, and critical-state queue order all follow the same priority ranking — determined by lethality speed and resource alienness.

| Tier | Element | Lethality Speed | Notes |
|---|---|---|---|
| 1 | Oxygen | Seconds at zero | Most alien resource — no cultural baseline; fastest kill |
| 2 | Suit Integrity | Seconds–minutes | Acute event; accelerates oxygen depletion |
| 3 | Food | Hours | Familiar concept; slow depletion |
| 3 | Water | Hours | Familiar concept; slow depletion |
| 4 | Ecological Disturbance | Not a lethality meter | World-state readout; drives no escalation |

**Tier 1 (Oxygen)** uses the largest and most centrally positioned indicator within the HUD's allocated zone. **Tier 2 (Suit Integrity)** is slightly smaller. **Tier 3 elements (Food and Water)** are grouped at equal, smaller sizes. **Tier 4 (Disturbance arc)** occupies the peripheral arc position and operates independently of the alert escalation system.

**The visual hierarchy is not a courtesy. It is a survival priority chart encoded in geometry.** A player reading the HUD under duress in State 4 darkness must be able to find the oxygen indicator without searching. Its position and size must make it the most prominent element without any labeling or tutorial.

**Critical-state queue order (strictly enforced):** When two systems enter Critical state simultaneously, they surface in Tier order: Oxygen → Suit Breach → Food → Water. The second-priority Critical element enters breach-white state 2.0 seconds (±0.1s) after the first. No pending-queue visual indicator is shown — the sequence is deterministic and consistent, so players learn the ordering through repeated experience.

---

### 7.1 Diegetic vs. Non-Diegetic Summary

#### 7.1.1 The Visor Projection System (Diegetic Core)

The HUD is fully diegetic. It is projected from the suit's interior visor surface as established in Section 5.1.5 — not a screen-space overlay but a display embedded in a physical object the player is wearing. This distinction governs every visual choice in the HUD: elements have weight, position, and physical source. The parallax drift (2–4 pixels on head turn) and the edge glow on gloves from HUD emitter zones are the two concrete production requirements that maintain this illusion at all times.

The visor projection fiction sets three rules for HUD design that may not be violated:
1. HUD elements exist in a fixed coordinate system relative to the visor surface, not the world. They do not drift toward objects in the world, do not attach to world-space geometry, and do not resize based on world-space distance to anything.
2. HUD elements emit light from their source panel. They are not transparent UI drawn over the world — they glow from the visor surface, reading as slightly in-front-of-the-world. Material treatment reinforces this: salvage amber glow, not flat alpha-blended geometry.
3. If the visor is compromised (Wear State 2 breach condition), the HUD projection through the breach-adjacent zone exhibits distortion artifacts — scan lines, partial element flickering — at the compromised section only. Localized to the breach location; does not affect HUD elements projecting through undamaged visor regions.

#### 7.1.2 Menus and Interface Screens (Diegetic Extension)

Pause menus, inventory, crafting, and settings screens are the suit's system interface — accessible via the sensor module on the right-hand dorsal surface (Section 5.1.2). The fiction: the player raises the sensor hand and interacts with an expanded projection from the hand-mounted panel, not from the visor. The projection source shifts from peripheral to centered.

**What this means visually**: When the player enters any menu or interface screen, the world does not disappear. It dims — contrast reduces, depth of field increases, and a faint amber vignette from the sensor panel's expanded projection illuminates the near foreground. The world remains visible at the periphery. The player has raised their hand and is looking at what is in it.

The transition in: 0.2 seconds. World dims immediately on menu-enter, before the interface appears — the brightness change reads as the projected light from the panel, not a cinematic cut. Interface panel activates at 0.2 seconds (low opacity, rising to full opacity). The hand-raise animation precedes the interface appearing, giving physical motivation to the screen change.

The transition out: 0.15 seconds. Interface collapses to sensor panel; world contrast restores over 0.4 seconds (slightly slower to restore than to dim). **Emergency exception**: if a Critical HUD state is active when the player opens the menu, the world-to-menu transition compresses to 0.1 seconds total. Emergencies do not wait for the interface.

**The pause menu is not paused fiction**: No in-game justification for time stopping. Uses the same sensor-interface visual system, with "SYSTEMS SUSPENDED" in standby ashen coloring at the top of the interface as the only meta-state acknowledgment. The world in the background renders as a static frame.

#### 7.1.3 Death Screen and Loading States (Acknowledged Non-Diegetic)

The death screen (State 8 in Section 2) honors the diegetic fiction in its termination. The desaturation post-process and caul intensification are world-state effects, not UI. No death-screen overlay is added after the world completes its death read (~3–4 seconds); a sparse text prompt appears — plain breach-white on black, no interface chrome, no salvage amber framing. This is the only moment where text appears outside the suit interface diegesis.

Loading screens use the State 9 visual presentation — the pre-dawn alien environment, single slow bioluminescent event, no HUD. Loading progress is not shown as a meter. A single text line in standby ashen appears at the lower edge when loading is more than 75% complete.

---

### 7.2 Typography Direction

#### 7.2.1 Governing Type Rule

**Letterforms must read as the product of functional engineering, not visual design.**

Every typeface choice should look like something the suit's original manufacturer would have specified for a heads-up display system — designed to be read under duress, at distance, in variable lighting conditions, by a person doing something else at the same time. No editorial typography, no expressive variation, no typefaces that ask to be noticed for their own sake.

#### 7.2.2 HUD Informational Text

**Use case**: Resource values, distance readouts, numerical status indicators, scanner data values, brief system-state labels.

**Typeface personality**: Condensed geometric sans-serif. Monospaced numerals required — values that change continuously must not shift adjacent character positions as digits update. Letter spacing +5% to +8% wider than default to compensate for the low-contrast amber-on-dark rendering environment.

**Weight**: Regular to Medium. Bold only for Critical-state values (Warning or Critical escalation). Bold is reserved for the alert escalation system — never for stylistic differentiation.

**Minimum legible size at 1080p**: 14px rendered height for any continuously updated numerical value. 12px minimum for static labels adjacent to values. No HUD text below 12px under any circumstances.

**Numeric emphasis rule**: When a value crosses a threshold, the numeral does not change weight or size — it changes color via the alert escalation palette (Section 4.5). Typography communicates state through color, not scale. Rescaling text on state change produces layout shift and breaks the HUD's static-geometry feel.

**Resource indicators are icon-only**: Resource type indicators carry no text labels in the HUD under any in-game circumstances. The player reads what each icon represents through consequence and repeated exposure — consistent with the no-tutorial design philosophy. This is a firm design constraint, not a placeholder.

#### 7.2.3 Menu and Interface Body Text

**Typeface personality**: The same geometric sans-serif family as HUD text, at wider tracking and slightly heavier default weight. Consistent family across HUD and interface maintains the fiction that this is one system.

**Weight**: Regular for body text. Medium for section headers within an interface screen. No bold in menus — bold belongs to the HUD alert system.

**Minimum legible size at 1080p**: 16px for body text. 20px for first-level headers. 13px minimum for secondary labels. Verify against rendered pixel height in-engine, not design-tool point size.

**Line length**: Maximum 60 characters per line for body text in interface panels.

**Alignment**: Left-aligned throughout. Centered text for single-line confirmation prompts only ("CONFIRM / CANCEL" format). Right-aligned for numerical values in columnar layouts. Justified text is not permitted.

#### 7.2.4 Narrative and Discovery Text

**Typeface personality**: The same family, regular weight, 1.5× line spacing minimum. The player has chosen to stop and read — generous spacing honors that pause.

**In-world authored text** (painted labels on cargo, embossed text on salvage panels) is part of the object's albedo texture or mesh. If it cannot be read clearly at the interaction distance without UI assist, replace with a non-legible symbol that reads as text from distance. Do not rely on UI zoom to make in-world text legible.

---

### 7.3 Iconography Style

#### 7.3.1 Governing Icon Rule

**Icons are diagram elements, not pictograms. They communicate system state through geometric form, not representational likeness.**

A resource icon is not a drawing of the resource. It is a geometric shape the player learns to associate with that resource, legible at small HUD sizes and consistent with the rectilinear and arc-segment frame grammar (Section 3.5). This approach prioritizes read-speed over first-encounter intuition — new players will not immediately recognize icon meanings but learn rapidly because icons are geometrically distinct from each other and from world visual content.

#### 7.3.2 Resource Type Icons

**Construction rule**: Each resource icon is constructed within a 16×16 grid minimum (authored at 64×64 for LOD quality), using only straight lines, 90° corners, 45° chamfers, and partial arc segments. No diagonals except 45° chamfers. No curves except arc segments. No filled irregular polygons.

**Style**: Outline only, never filled. Uniform 1px stroke at 1080p (2px at 4K). Bold stroke weight (2px at 1080p) is reserved for Critical-state escalation only — not for design variation.

**Icon-only rule (enforced)**: No text labels appear alongside resource icons in the HUD. See Section 7.2.2. Item names do appear in the inventory/crafting interface (see Section 7.5.5) — this is a discrete deliberate-reading context, not the survival-state HUD.

**Oxygen icon**: Partial arc segment (top two-thirds of a circle, open at the base). Communicates a contained resource depleting from both ends. Does not represent a gas cylinder or mask — represents containment running out. As the Tier 1 element, this icon is rendered at the largest size in the HUD (minimum 4.5% of screen height at the indicator's tallest dimension).

**Food icon**: Two parallel horizontal lines of equal length, bisected by a short vertical line. Reads as a count or measure.

**Water icon**: A square with a single horizontal bar at 40% height from the bottom — a fill-level diagram. Reads as "container, how full."

**Suit integrity icon**: A square frame with one corner chamfered at 45°. The breach-white trace system on the visor frame (Section 5.1.4) provides the primary signal; the HUD integrity icon's chamfered corner widens proportionally at Warning state, echoing the breach geometry.

**Disturbance meter**: A thin arc segment at the upper HUD periphery (Section 3.5). At disturbance level zero: standby ashen, near-invisible. Rising disturbance increases opacity and saturation. At disturbance 7+/10: pulses in Warning amber (amber luminance +15%), synchronized with the world's accelerating ecological pulse rate — the HUD meter and world biological signal pulse at the same rate. The connection is learned, not explained.

#### 7.3.3 Action Prompt Icons

**Style**: Keyboard key outline (square with rounded interior — the physical key cap shape is the one permitted rounded form in the HUD, representing a physical object the player's hand is touching). Inside the key outline: the key label in HUD informational text style.

**Gamepad**: Same square frame with button label inside. Not hardware-accurate PlayStation/Xbox iconography. Platform-specific button shape variations are permitted at the publisher submission pass but are derived from this base system, not authored separately.

**Placement**: Lower center of the HUD area — not world-space attached to interactable objects. The prompt belongs to the suit, not the world.

**Timing**: Appears on approach with 0.15-second opacity fade-in. Disappears at 0.1 seconds on exit range, no fade. Asymmetric intentionally — the player must read the prompt with enough time to act; they do not need to watch it leave.

#### 7.3.4 Status Indicators and Predator Detection Icon

**Status indicators (general)**: Non-resource, non-disturbance state indicators use an 8×8px dot plus a short label. Standby ashen when inactive, advisory amber when noteworthy, warning amber when requiring attention. Lower HUD periphery.

**Predator detection icon**: The HUD must never use caul (Section 4.5). When active: a chamfered-rectangle breach-white frame (30% opacity fill) at the HUD border zone corresponding to predator bearing. Inside: two angular lines converging to a point — directional, not representational. Off by default for sighted players; on by default in colorblind-assist mode (Section 4.6).

#### 7.3.5 Biological Scanner Sub-Language

When the scanner is active, the data readout panel (Section 5.1.5) produces organic-curve icons and branching structures within the salvage amber frame — spore-teal branching that echoes world fractal micro-scale. Entity classification icons within the scanner panel are simplified organic silhouettes of the entity being scanned — the single instance of representational iconography in the entire UI system. The geometric frame must remain uncontaminated by the organic content within it.

---

### 7.4 Animation and Motion Philosophy

#### 7.4.1 Governing Motion Rule

**The suit's interface is electromechanical, not digital-fluid. Motion is mode change, not decoration.**

Transitions that exist to communicate state change are included. Transitions that exist because they look smooth are not. The mechanical snap and the precise fade serve different purposes and appear in different contexts.

#### 7.4.2 HUD Element Appearance and Dismissal

**The HUD is always present.** The first time the player sees the HUD is when the game loads — it is already in standby ashen state, barely visible. Elements activate from standby (ashen, low opacity) to primary (salvage amber, full opacity) in 0.1 seconds as the player interacts with systems. The activation reads as a display warming up, not as UI appearing.

**Resource value updates**: Numerical values update instantaneously. No roll-up counter animation, no digit-cycling. Values change in the same frame the system value changes. The HUD does not lie about timing.

**Element dismissal**: Elements return to standby ashen state (0.2 seconds). The HUD architecture is constant; the activity level of its elements changes.

#### 7.4.3 Alert Animations

**Advisory escalation**: Color shift to warning amber (+15% luminance) over 0.15 seconds. No motion. A change of state, not an event.

**Warning escalation**: The warning-state element adds a slow luminance pulse — 2-second cycle, matching the ecological high-disturbance pulse rate (Section 2, State 3). The HUD warning pulse and the world's biological warning pulse are synchronized — the connection is earned over time, not explained.

**Oxygen Warning kinetic behavior**: Oxygen is the only resource indicator that receives a kinetic signal at Warning threshold. In addition to the warning amber color shift, the oxygen arc-segment icon begins a slow luminance pulse (2-second cycle, matching the warning pulse rate). No other resource indicator receives kinetic behavior at Warning. Motion draws the eye to the Tier 1 element without labeling or explicit instruction.

**Critical escalation**: Breach-white element appears at its assigned position. One arrival flicker at 0.4 seconds duration, once only, at a maximum frequency of **3 Hz** (photosensitivity compliance). No repeating flash after the arrival flicker. Steady breach-white maintains urgency without desensitization. An accessibility option to disable the arrival flicker while retaining the breach-white state must be available in settings.

**Multiple critical states — strict queue**: When two systems enter Critical simultaneously, they surface in Tier order: Oxygen (Tier 1) → Suit Breach (Tier 2) → Food (Tier 3) → Water (Tier 3). The second-priority element enters breach-white 2.0 seconds (±0.1s) after the first. No pending-queue indicator is shown. The ordering is always deterministic: oxygen failure surfaces first because it is the fastest-kill threat.

**Disturbance meter alert motion**: At disturbance level thresholds (3, 5, 7, 9 of 10), the arc segment produces a single swell — the arc briefly increases in thickness by 1px for 0.3 seconds, then returns. Not a flash, not a color change. A physical swell consistent with the arc-segment grammar.

#### 7.4.4 Menu Screen Transitions

**World-to-menu**: Hand-raise animation 0.25 seconds. World dim begins at the start of the hand-raise. Interface panel activates at 0.2 seconds (low opacity, rising to full at 0.25 seconds). Emergency exception: Critical HUD state active on menu-open compresses total transition to 0.1 seconds.

**Within menus**: Panel transitions use 0.1-second cross-fade. Panel frame remains; content changes. No slide transitions, no scale transitions.

**Menu-to-world**: Interface fades to standby (0.1 seconds) while hand-lower animation plays (0.2 seconds). World contrast restores over 0.4 seconds after hand-lower completes.

**No skip**: Menu transitions may not be shortened by button hold. They are short enough that skipping them would be imperceptible while removing the physical motivation from the interface.

---

### 7.5 Menu Screens Visual Direction

#### 7.5.1 Interface Screen Architecture

All menu screens share one visual container: the sensor interface projection panel. Occupies 55–65% of screen width, 60–70% of screen height, centered. The world is visible at all edges.

**Panel structure**: Salvage amber chamfered-rectangle outer frame (primary amber S 55–65%, L 45–55%), 2px border weight at 1080p. Interior fill: dark ashen (S 5%, L 8–12%) — the darkest salvage amber value, maintaining color family coherence while receding behind content.

**Two-tier hierarchy only**: Outer container at primary amber; internal sections at secondary amber (S 30–45%). No third tier of framing — if a layout requires more hierarchy, the screen is too complex and must be simplified.

#### 7.5.2 Gamepad and Keyboard Navigation

**Shape-based focus indicators are required on all interactive elements**. Focused elements gain a visible border increase (outer frame weight increases from 2px to 3px at 1080p) and a subtle scale increase (104% of normal size). The focus state must be distinguishable from unfocused state without color information — required for deuteranopia/protanopia users and for all players in low-luminance contexts.

**Focus traversal order**: Top-to-bottom, left-to-right default for all screens. Exceptions must be explicitly documented in the UI spec for that screen before implementation — ambiguous traversal order is prohibited.

**Keyboard navigation**: All menu screens support full keyboard navigation. Tab/Shift-Tab for traversal; Enter for confirm; Escape for back/cancel. These are non-negotiable minimums. Any screen that cannot be fully navigated with these four keys requires layout revision.

#### 7.5.3 Main Menu

**Visual context**: State 9 (pre-dawn alien environment) renders continuously in background. No HUD. No visor effects — the player is not yet in the suit.

**Exception to the diegetic rule**: The main menu is before the suit fiction begins. The sensor interface panel visual system is not used. Instead: game title in HUD informational text style at 36px, menu options in menu body text at 20px, left-aligned, lower-left screen quadrant. No panel frame. Text at 85% opacity — slightly transparent to remain integrated with the world behind it. On focus: selected item shifts from standby ashen to primary salvage amber.

**Title treatment**: Game title in the same typeface, regular weight. No logotype, no special effect. A logotype for marketing and store use is created separately and is not used in-game.

#### 7.5.4 Pause Menu

**Visual context**: World as static frame. Sensor interface panel. "SYSTEMS SUSPENDED" in standby ashen at top, 14px, tracking +10%. Pause options below. Resume listed first; standard focus-state emphasis, no persistent visual prominence.

#### 7.5.5 Crafting and Inventory Screens

**Layout**: Two-column. Left: 40% width, item list with secondary amber sub-frame. Right: 60% width, item detail with secondary amber sub-frame.

**Resource inventory**: Icon + item name (menu body text) + quantity (right-aligned, monospaced numeral). Item names appear here in the interface context, as this is a discrete deliberate-reading context. No progress bars — exact quantities only.

**Crafting interface**: Left column: craftable items (standby ashen if insufficient resources, primary amber if craftable). Right column: item icon at 32×32px, item name as header, required resources as list (current stock / required, warning amber if insufficient), confirmation prompt. No crafting animation until confirmed.

**Biological scanner log**: Reverse-chronological list. Each entry: entity icon (scanner sub-language organic silhouette, 16×16px), entity name, distance at scan time, timestamp. Detail view: full organic-curve scanner display in spore-teal within salvage amber frame. Organic content must not visually leak beyond the secondary amber sub-frame that contains it.

#### 7.5.6 Settings Screen

**Layout**: Single-column within sensor interface panel. **Accessibility category appears first** — not last. Players who need colorblind-assist or flicker-disable should not have to scroll past other settings to reach them.

When colorblind-assist is enabled, a note in standby ashen below the toggle reads: "Caul pattern overlay and HUD directional indicator active." This is the only in-interface explanatory text in the game.

**Breach-white flicker accessibility option**: A control to disable the breach-white arrival flicker while retaining the breach-white state, located in the Accessibility category. Default: flicker enabled for sighted players.

---

### 7.6 Legibility Rules

#### 7.6.1 Contrast Ratios

**Working minimums by HUD state**:

| HUD State | Minimum Contrast | Notes |
|---|---|---|
| Normal (Advisory) | 2.5:1 | Game survival HUD in intentionally dark atmosphere |
| Warning | 3.5:1 | — |
| Critical (breach-white) | 4.5:1 | Achromatic at high luminance; likely already met |
| Interface body text | 4.5:1 (target 7:1) | Controlled panel background — verify at actual rendered fill value |
| Interface primary text | 7:1 | — |

Verify against actual rendered pixel values in-engine, not design-tool approximation. Verify critical state ratios against the darkest ambient rendering state (Rift Zone, deep cool −800K ambient).

#### 7.6.2 Environmental Interference Rules

**Anti-washout backing panel**: At any ambient luminance value above the HUD frame's interior luminance threshold, a dark backing panel activates behind the HUD frame — strictly behind the frame and its contents, not the full HUD zone. Ashen at 40% opacity, 1px larger than the frame at every edge. For breach-white elements in bright-world contexts: 60% opacity backing. The backing must not be visible as a discrete object — contrast only, not structure. Backing suppresses in very dark world states (redundant in near-black ambient).

**HUD auto-dim in State 4 (predator encounter dark-world floor)**: When world ambient luminance drops to the State 4 floor, HUD primary elements dim by 10–15% from their normal value. The HUD remains fully legible but does not compete for eye priority during the most attention-demanding survival state. Warning and Critical state elements override the auto-dim and maintain their escalated luminance — critical information is never suppressed by the dimming behavior.

**Bioluminescent pulse peaks**: Spore-teal (H 175°) has 140° hue separation from salvage amber (H 35°). Pulse peaks from the world do not contaminate HUD legibility. No compensation needed.

**Caul rim-light**: 90° hue separation from salvage amber. No direct legibility contamination. At Warning state, verify that a Warning-state HUD element is distinguishable from world caul content in State 4 — if not, Warning-state luminance requires increase.

#### 7.6.3 Text and Element Size Hierarchy

All sizes are rendered pixel heights at 1080p native. Define in-engine as % of vertical resolution, not absolute pixels, for resolution independence.

| Tier | Use | Min (1080p) | % Vertical Height | Weight |
|---|---|---|---|---|
| T1 | Oxygen %, active alerts | 20px | 1.85% | Medium (on Warning/Critical) |
| T2 | All continuous resource values | 14px | 1.3% | Regular |
| T3 | HUD labels, unit suffixes | 12px | 1.1% | Regular |
| T4 | Menu body text | 16px | 1.48% | Regular |
| T5 | Menu section headers | 20px | 1.85% | Medium |
| T6 | Discovery / scanner log detail | 16px | 1.48% | Regular, 1.5× line height |
| T7 | Settings labels, secondary info | 13px | 1.2% | Regular |

**Nothing below T7 (13px / 1.2% VH) under any circumstances.**

**HUD element size floors (by priority tier)**:

| Element | Min (1080p) | % Screen Height |
|---|---|---|
| Tier 1 indicator (Oxygen arc) | 48px | 4.5% |
| Tier 2 indicator (Suit Integrity) | 40px | 3.7% |
| Tier 3 indicators (Food/Water) | 32px each | 3.0% |
| Disturbance arc stroke width | 4px | 0.4% |
| Action prompt key-cap frame | 28×28px | ~2.6% |

These percentage floors hold for all display configurations including TV-distance play.

#### 7.6.4 HUD Coverage Verification

Per Section 5.1.5, total HUD coverage must not exceed 12% screen area, with center 80% always clear. This is a production requirement, not a guideline.

**Measurement protocol**: At maximum simultaneous HUD activity (all resource indicators active, disturbance meter at max, one Critical alert, one action prompt), render the HUD as a flat white mask against black. Measure white pixel coverage as a percentage of total screen pixels. Above 12% requires HUD layout revision. Repeat this test after any HUD element is added or resized.

---

### 7.7 UI Design Test Suite

**HUD Legibility Tests:**
1. At maximum simultaneous HUD activity, the white-mask coverage test returns under 12% screen area.
2. At 1080p native, all T2 tier (14px) text is legible at 60cm viewing distance without squinting. Verification: print screenshot at actual pixel size and verify at reading distance.
3. In the darkest ambient render state (Rift Zone, pre-dawn equivalent), primary salvage amber HUD elements achieve minimum 2.5:1 contrast against scene background — measured at actual rendered pixel values.
4. During State 4 predator encounter at maximum caul rim-light intensity (20m), a Warning-state HUD element is distinguishable from world caul content within 1 second of knowing to look.
5. In isolation (no world context), no HUD element is confusable with a world bioluminescent event — the amber family and spore-teal family must not be conflatable at any combination of opacity and luminance they occupy in normal play.
6. HUD auto-dim behavior activates in State 4 dark-world ambient and dims primary elements 10–15%, while Warning and Critical elements maintain escalated luminance — test with a debug scene at State 4 minimum ambient.

**Iconography Tests:**
1. All resource-type icons are distinguishable from each other at 16×16px rendered resolution in greyscale only. Any two icons confusable at 16×16px greyscale require revision — both icons, not just one.
2. The predator detection icon (when active) reads as directional within 2 encounters — a player who has not seen it before understands it indicates a bearing, not an object.
3. Action prompt icon updates correctly for keyboard and gamepad input without layout shift. The containing frame must not resize between input contexts.

**Alert System Tests:**
1. The Warning-state HUD pulse (2-second cycle) and the ecological disturbance world pulse are synchronized at disturbance level 7+/10. Verify against the ecological pulse rate system at runtime — count the HUD pulse beats against the world's bioluminescent cycle.
2. The oxygen Warning kinetic pulse initiates within the same frame the Warning threshold is crossed.
3. When two systems enter Critical simultaneously, the second element's breach-white activates at 2.0 seconds (±0.1s) after the first. Force simultaneous oxygen-critical and suit-breach-critical in a test scenario and measure the delay.
4. The breach-white arrival flicker fires once only, at a maximum frequency of 3 Hz, and does not re-trigger while the Critical state persists. Hold oxygen at Critical for 30 seconds — flicker must not re-trigger.
5. With breach-white flicker disabled (accessibility setting), the Critical state remains visually present as steady breach-white — the disabled-flicker state must not revert the element to Warning or Advisory display.

**Menu System Tests:**
1. World-to-menu transition reads as a single coherent physical action — dim and hand-raise must begin simultaneously. Film the transition and verify.
2. In the crafting screen with an insufficient-resource state, a player can identify which resources are short in under 5 seconds without reading labels — warning amber quantity values carry the information visually. Verify with a first-time user given 5 seconds of observation.
3. Scanner log organic sub-language content does not visually leak beyond the secondary amber sub-frame. Verify at all scanner log entry types.
4. All menu screens are fully navigable using Tab/Shift-Tab/Enter/Escape alone. Verify in a complete playthrough of all screens with mouse disconnected.
5. Gamepad focus state is distinguishable from unfocused state in greyscale (shape-based indicator test). Screenshot focused vs. unfocused element, desaturate, verify legibility.

---

## Section 8: Asset Standards

### Governing Asset Standard Rule

**An asset is correct when it cannot be used incorrectly.** Naming, format, and palette compliance are not bureaucratic requirements — they are the mechanisms that make it impossible to accidentally ship an asset that violates the visual identity. Every standard in this section exists because the cost of finding an inconsistency after integration is orders of magnitude higher than the cost of enforcing consistency at submission.

This section functions as two sequential gates. An asset must pass the technical gate (Sections 8.6–8.13) before it reaches the art director's visual gate. The art director's approval presupposes technical compliance.

---

### 8.1 Asset Category Definitions

Terranova's assets are organized into seven top-level categories. Each category is visually governed by a specific set of art bible sections. A 3D artist must know which category their work belongs to before beginning, because the category determines texture budgets, LOD requirements, saturation tier assignments, and submission review path.

---

**Category: ENV — Environment**

All geometry that constitutes the playable world: terrain forms, geological features, biological growth elements (Layer 1–3 per Section 6.2), cave systems, biome transition geometry, and the crash impact scar.

*Subdivisions:*
- `env_terrain` — geological base forms, rift walls, cave ceilings and floors
- `env_bio` — Layer 3 active biological growth: frond organisms, root arches, column formers, ambient drifter flora
- `env_prop` — free-standing non-structural environment objects: resource nodes, loose geological props, compression trace decals, ecological event markers

*Visual governance*: Sections 3.1, 4.3, 5.5, 6.1, 6.2, 6.3, 6.5. Modular vs. bespoke assignment: follow Section 6.7 rules exactly.

---

**Category: CHAR — Characters**

All character assets: the player suit, the predator, and all fauna archetypes. Animated, rigged, authored across all four LOD levels per Section 5.5.

*Subdivisions:*
- `char_player` — player suit mesh, wear state overlay set, first-person hand/arm mesh, antenna
- `char_predator` — predator body mesh, structural extensions, outer membrane elements
- `char_fauna` — drifter, grazer, borer, column former

*Visual governance*: Section 5 (all subsections). Silhouette requirements are the primary review criteria — greyscale silhouette test required before color or material work begins. Non-negotiable: no character asset enters the build without passing the Section 5.6 test suite. Submit greyscale silhouette renders at all four LOD distances before the textured version is reviewed.

---

**Category: STR — Structures**

All human-origin built geometry: crash hull sections, base wall panels, interior corridor segments, hatches, doorframes, structural flooring, crafting station geometry, and salvage debris field objects.

*Subdivisions:*
- `str_hull` — crash hull exterior panels, hull deformation geometry, impact zone sculpts
- `str_base` — modular base structure kit pieces: wall panels, corner connectors, flooring tiles, ceiling panels
- `str_salvage` — debris field objects, pre-crash salvage items at remote locations

*Visual governance*: Sections 3.4, 6.2 (Layer 4), 6.4, 6.7. The modular kit seam-break convention (Section 6.7) is a submission requirement — assets submitted without seam-break geometry are returned.

---

**Category: VFX — Visual Effects**

All particle systems, shader-driven visual effects, and full-screen post-process passes.

*Subdivisions:*
- `vfx_bio` — bioluminescent pulse effects on organisms and Layer 3 growth elements
- `vfx_disturbance` — ecological disturbance atmospheric effects (State 3 spore contamination, air particulate)
- `vfx_predator` — caul rim-light world-space effect, compression trace aging shader
- `vfx_suit` — suit breach visor distortion, wear state biological overlay animation
- `vfx_postprocess` — death-state desaturation, crafting milestone pulse, State 3 atmospheric tint

*Visual governance*: Section 4 (color system state behavior), Section 6.7 (disturbance visual output). Every VFX asset is authored to a specific game state or disturbance level — document in the asset's metadata comment field: `// State: 3, Disturbance: 5–9`.

---

**Category: UI — User Interface**

All user interface assets: HUD element frames, resource icons, action prompt icons, scanner data sub-panel, menu panel geometry, interface screen layouts, typography.

*Subdivisions:*
- `ui_hud` — heads-up display elements: resource arc frames, disturbance arc, icon set, alert overlay frames
- `ui_menu` — interface screen panels: inventory grid, crafting panel, settings screen, pause overlay
- `ui_icon` — resource type icons, action prompts, status indicators, predator detection icon
- `ui_type` — typography assets: font files, size-specification sheets, tracking/weight variant definitions

*Visual governance*: Sections 3.5, 4.5, 7 (all subsections). The rectilinear-and-arc-segment rule from Section 3.5 is the first review test for any UI asset — organic curves in UI are rejected immediately except in the biological scanner sub-panel (Section 7.3.5). Caul may not appear in any UI asset under any circumstances (Section 4.5).

---

**Category: PP — Post-Process Profiles**

Unity URP Volume profiles governing scene-level color grading, depth of field, vignetting, and state-specific post-process passes defined in Section 2.

*Subdivisions:*
- `pp_state` — per-game-state Volume profiles (nine profiles matching Section 2's nine states)
- `pp_biome` — per-biome color temperature offset profiles
- `pp_death` — death-state desaturation post-process (dedicated pass per Section 2, State 8)

*Visual governance*: Section 2 (state color temperatures, contrast, saturation). Each `pp_state` profile output must match the quantitative specifications in the Section 2 state comparison table exactly — color temperature in Kelvin, contrast level in the established vocabulary. Validated against that table before each sprint build.

**Audio note (AUDIO category — not an art director asset type)**: Audio assets are not governed by this section. Visual/audio synchronization requirements are flagged here for cross-team awareness: bioluminescent pulse timing must match audio transition timing within ±0.1 seconds. Biome audio transitions must match the visual transition distances from Section 6.6.

---

### 8.2 Naming Conventions

**All asset files follow this schema:**

```
[category]_[descriptive-slug]_[variant-or-state].[extension]
```

**Case convention: `snake_case` throughout.** All asset file names use lower-case with underscore separators. This is a deliberate divergence from the C# `PascalCase` convention used for code files. Rationale: any file using `PascalCase` is a code file; any file using `snake_case` is an asset. A developer can determine in one glance whether they are looking at a script or an asset without opening it or checking the extension.

**LOD suffix exception: `_LOD0`, `_LOD1`, `_LOD2`, `_LOD3` (uppercase).** Unity's LOD Group import system uses this exact convention for automatic LOD mesh assignment. The rest of the filename uses `snake_case`; only the LOD component is uppercase. This is a Unity technical constraint, not a style choice.

Category prefixes match the seven-category codes from Section 8.1, lowercased: `env`, `char`, `str`, `vfx`, `ui`, `pp`. Sub-division codes append to the category prefix: `env_bio`, `env_terrain`, `char_player`, `str_hull`, `ui_hud`, `vfx_predator`, `pp_state`.

---

**Meshes (FBX source files and Unity-imported mesh assets):**

```
[category]_[object-name]_[variant]_[LOD-level].fbx
```

Examples:
- `env_bio_column_former_a_LOD0.fbx`
- `char_player_suit_default_LOD1.fbx`
- `char_predator_body_LOD0.fbx`
- `str_base_wall_panel_corner_LOD0.fbx`
- `env_terrain_shallows_cliff_bulge_a_LOD2.fbx`

LOD level suffix is always present: `_LOD0`, `_LOD1`, `_LOD2`, `_LOD3`. If a mesh has no LOD chain, use `_LOD0` and note its status in the asset tracker. Variant labels are lowercase alphabetic: `_a`, `_b`, `_c`. Use variants for same-type mesh variations (three drifter shapes = `_a`, `_b`, `_c`), not for different objects.

---

**Textures:**

```
[category]_[object-name]_[map-type].[extension]
```

Map type suffixes (append as the final name component before extension):

| Map Type | Suffix | sRGB | Notes |
|---|---|---|---|
| Albedo / Base Color | `_alb` | Yes | Only texture with sRGB on |
| Normal map | `_nrm` | No | OpenGL convention (green channel up) |
| Roughness | `_rgh` | No | Packed into channel R of mask map |
| Metallic | `_met` | No | Packed into channel G of mask map |
| Ambient Occlusion | `_ao` | No | Packed into channel B of mask map |
| Mask map (packed) | `_msk` | No | R=Roughness, G=Metallic, B=AO, A=Detail or unused |
| Emissive | `_emi` | No | See bioluminescent emissive rules in Section 8.3 |
| Height / Displacement | `_hgt` | No | Greyscale |
| Opacity / Alpha mask | `_opc` | No | Greyscale; pack into albedo alpha channel where feasible |
| Detail normal | `_nrm_detail` | No | Second normal for micro-surface detail |

Examples:
- `env_bio_drifter_body_a_alb.png`
- `env_bio_drifter_body_a_nrm.png`
- `env_bio_drifter_body_a_msk.png`
- `char_predator_membrane_outer_emi.png`
- `str_hull_exterior_panel_aged_alb.png`

---

**Materials:** `[category]_[object-name]_[variant].mat`

Materials are authored one-per-surface-state. Disturbance transitions are handled by the shader's exposed parameters driven by the gameplay disturbance system — the material is the authored baseline, not the animated state. Two materials per disturbed surface type: `_undisturbed` and `_disturbed`.

---

**Prefabs:** `[category]_[object-name]_[variant].prefab`

Prefabs use the same naming as their root mesh but without a LOD level suffix — the prefab contains the LOD Group component managing all LOD levels.

---

**Animations:** `[category]_[character-name]_[action]_[state].anim`

State qualifiers for biological animation cycles: `_equilibrium` (4–6s pulse, undisturbed), `_disturbance` (1–2s pulse, high disturbance). These qualifiers are semantic — they communicate which game state triggers the clip.

---

**VFX (Unity VFX Graph or Particle System assets):**

```
vfx_[subcategory]_[effect-name]_[loop-state].[extension]
```

Loop state: `_loop` for continuous, `_oneshot` for triggered single plays, `_burst` for triggered multi-instance.

---

**Post-Process Profiles:** `pp_[state-or-biome]_[descriptor].asset`

State profiles use zero-padded two-digit numbers matching Section 2's state numbering (e.g., `pp_state_04_predator_near.asset`).

---

### 8.3 Texture Format Standards

**Pre-import authoring formats:**

| Map Type | Authored Format | Rationale |
|---|---|---|
| Albedo | PNG, 32-bit RGBA | Lossless; supports alpha channel for masked surfaces |
| Normal | PNG, 24-bit RGB | OpenGL convention; lossless prevents banding in smooth gradient normals |
| Mask map (packed) | PNG, 32-bit RGBA | All four channels authored per-pixel; lossless preserves channel precision |
| Emissive | PNG, 32-bit RGB | Lossless for HDR emissive workflows using Unity's emissive multiplier |
| Height / Displacement | PNG, 16-bit greyscale | 16-bit for sub-millimeter precision |
| Opacity / Alpha mask | PNG, 8-bit greyscale | Single channel; no color data |
| EXR | Reserved for VFX and post-process only | Do not use for character or environment textures |

**Unity importer settings by map type:**

| Map Type | sRGB | Compression | Max Size | Notes |
|---|---|---|---|---|
| Albedo (`_alb`) | On | BC7 (PC) | Per texel density tier (see below) | sRGB must be on |
| Normal (`_nrm`) | Off | BC5 (PC) | Same as albedo at matching tier | Set texture type to "Normal map" in importer |
| Mask map (`_msk`) | Off | BC7 (PC) | Same as albedo at matching tier | Import as "Default" type, not Normal |
| Emissive (`_emi`) | Off | BC7 | Same as albedo at matching tier | See bioluminescent rules below |
| Height (`_hgt`) | Off | BC4 | Half of albedo max size | Used for displacement reference |
| Opacity (`_opc`) | Off | BC4 | Match albedo at same tier | Pack into albedo alpha if surface has alpha |
| Detail normal (`_nrm_detail`) | Off | BC5 | 512px maximum | Tiling factor set per material instance |

**Max texture size by texel density tier** (see Section 6.2 for tier definition):

| Texel Density Tier | Max Texture Size |
|---|---|
| Hero (512px/m, 0–8m) | 2048×2048 |
| Mid-ground (256px/m, 8–30m) | 1024×1024 |
| Background (128px/m, 30m+) | 512×512 |

Do not author textures above the tier maximum. Verify the importer's Max Size field matches the tier before committing the asset — the asset pipeline does not downscale automatically.

**Channel packing — mask map standard:**

```
R channel = Roughness (0 = smooth, 1 = rough)
G channel = Metallic (0 = non-metal, 1 = full metal)
B channel = Ambient Occlusion (0 = fully occluded, 1 = fully lit)
A channel = Detail mask (set to 1.0 white if unused)
```

Compatible with Unity URP Lit shader mask map input. Metallic values for biological and geological surfaces are zero. Metallic channel is used only for human salvage surfaces (salvage amber panels: metallic 0.05–0.15). Do not leave metallic channel as non-zero from a reference scan without zeroing biological and geological areas.

**Bioluminescent emissive texture rules:**

Emissive textures for bioluminescent elements (drifters, column former apex, Layer 3 growth, crafting milestone pulse, and predator caul material) are authored as non-HDR maps — RGB values capped at 1.0 per channel. The HDR glow effect is achieved through Unity's emissive intensity multiplier and URP bloom, not by encoding HDR values in the texture. This keeps files manageable and allows runtime intensity control for the pulse rate animation system.

Emissive map content: only elements that actually emit light are white or near-white. Non-emitting surface areas are pure black (0,0,0). A texture where the emissive map is globally brightened rather than masked to specific emitting zones will produce a flat glowing appearance and will fail the palette compliance check.

**Caul self-illumination (predator emissive)**: authored at H 305°, S 65%, L 38% in albedo space on the emissive map's emitting areas. The predator's interior mass emission is an emissive-only shader pass with a normal-map-driven occlusion pass suppressing emission at membrane-thickened zones (Section 8.10). The emissive texture documents the base caul color; intensity and the occlusion mask are shader parameters, not baked into the texture.

---

### 8.4 Palette Compliance Verification

**Purpose**: Every asset submitted for art director review must arrive with verifiable palette compliance. This checklist is performed by the submitting artist before submission. Art director review is a confirmation, not a discovery process.

**Seven-step self-review checklist:**

**Step 1 — Hue boundary check (caul exclusion zone)**
Open the albedo texture in the color picker. Sample 10 representative points across the asset surface. Confirm no sampled hue falls within H 285°–325° (the caul exclusion zone, Section 4.1). If any sample falls in this range, recolor before submission. No exceptions.

**Step 2 — Saturation tier assignment**
Identify the asset's saturation tier from Section 4.3 based on category and narrative role (Tier 0–1 for background/passive biological, Tier 1–2 for active ecological/interactable, Tier 3 for event/predator only). Sample the three highest-saturation points on the surface. Confirm all three are within the assigned tier. Sustained Tier 3 saturation on any non-predator, non-HUD-critical asset is a hard rejection.

**Step 3 — Semantic hue identity**
Identify which of the seven palette colors the asset's dominant hue belongs to (Section 4.1). An asset must be assignable to one or two palette colors. If the color requires a new hue to describe, it is not palette-compliant.

**Step 4 — Biological vs. manufactured vocabulary check**
Apply the three-question test from Section 4.2: biological or manufactured? Interaction state? Relationship to predator? Confirm color assignment matches the actual albedo.

**Step 5 — Emissive map audit (if applicable)**
Confirm: (a) emitting areas are exclusively elements that logically emit in the world fiction, (b) non-emitting areas are black (0,0,0), (c) emitting hue matches the biological emissive vocabulary (spore-teal for biological bioluminescence; caul for predator only; salvage amber for manufactured light sources), (d) emissive map is authored at non-HDR levels (RGB ≤ 1.0 per channel).

**Step 6 — LOD saturation consistency**
Render the LOD 0 and LOD 3 albedo textures side by side at a neutral grey background. Saturation must not increase between LOD 0 and LOD 3. If the simplified LOD 3 texture reads as higher saturation than LOD 0, the LOD 3 albedo requires manual desaturation. This is flagged as a critical LOD rule in Section 6.2.

**Step 7 — Greyscale silhouette legibility (character and ENV hero assets only)**
Render the asset over a flat diffuse grey scene, greyscale only, single overhead light. Confirm the asset's category is identifiable from its silhouette at the distances specified in the applicable Section 5.6 test. Confirm it does not read as a category it is not.

**Submission format**: Submit the completed checklist as a text annotation in the asset's submission comment, including sampled hue values from Steps 1 and 2. "Passed all checks" without sampled values is not an acceptable submission.

---

### 8.5 Export Settings and Pipeline Conventions

**Scale: 1 Unity unit = 1 real-world meter.** Apply universally. Verify in-engine before submitting the final asset. Do not adjust Unity's "Scale Factor" in the FBX importer to compensate for an incorrectly scaled source file — fix the source. Import scale factor in Unity must be set to 1.0 on all assets.

**Coordinate system: Right-hand, Y-up.** Blender: export FBX with "Apply Transform" checked, Forward axis −Z, Up axis Y. Do not use the Unity FBX importer's "Bake Axis Conversion" checkbox as a correction for an incorrectly exported mesh — it applies a root-level transform rather than correcting mesh data, which propagates into child objects, physics colliders, and animation root motion.

**Mesh format: FBX only.** OBJ does not support blend shapes (required for disturbance geometry transitions) and does not carry animation data. GLTF requires a Unity importer plugin not in the approved addon list.

**Pivot point conventions:**

| Asset Type | Pivot Location |
|---|---|
| Modular kit pieces | At the connection point — the face that joins adjacent modules. Enables snapping in Unity's Scene view without offset correction. |
| Free-standing props | At world-floor contact point, centered horizontally. Never at geometric center. |
| Character meshes | At character's center of mass at the floor contact point. |
| VFX emitter prefabs | At the intended world-anchor point of the effect. |
| Biological Layer 3 growth (env_bio) | At the surface attachment point — where the organism contacts its Layer 2 substrate. Enables orientation to surface normal for placement on curved terrain. |

**FBX export settings (set per-export; do not leave at DCC defaults):**

- Geometry: Triangulate mesh on export. Do not rely on Unity's triangulation.
- Normals: Export "Normals Only" — binormals computed by Unity from normals + tangents. Do not export embedded binormals.
- Smoothing groups: "Face" smoothing for hard-surface assets (base structures, crash hull, modular kit); "Edge" smoothing for organic surfaces (geological forms, biological growth).
- Animations: Bake animations on export at 60fps to match target framerate.
- Embedded textures: Never embed textures in the FBX. Textures are imported separately.
- Armatures/Skeletons: Export with skeleton for all character and animated biological assets. Export without skeleton for all static geometry.

**Unity mesh import defaults (set once at first import; do not change after initial setup without art director approval):**

- Read/Write: Disabled (unless required by a mesh deformation system — flag with technical artist)
- Generate Lightmap UVs: Disabled by default. Enable only for base structure modular kit and crash hull elements receiving baked lighting.
- Optimize Mesh: Enabled. Order vertices by polygon zone.
- Import BlendShapes: Enabled for biological growth assets with disturbance blend shapes. Disabled for all other assets.
- Weld Vertices: Enabled.
- Import Cameras / Import Lights: Disabled. Never import cameras or lights from FBX.

---

### 8.6 Polygon Count Budgets

*Counts are in triangles. LOD transitions follow Section 5.5 distances (0–8m / 8–20m / 20–40m / 40m+).*

**Player Suit:**

| Asset | Triangle Budget | Notes |
|---|---|---|
| First-person arms, LOD 0 | 8,000 tris | Arms-only mesh; the dominant foreground object in all gameplay |
| Third-person full body, LOD 0 | 12,000 tris | Co-op only; up to 3 suits may be in frame simultaneously |
| Third-person full body, LOD 1 | 5,000 tris | Must preserve bilateral symmetry and helmet/torso separation (Section 5.5 non-negotiables) |
| Third-person full body, LOD 2 | 1,500 tris | Silhouette block only; antenna as single-pixel geometry, not a mesh tube |

**Predator:**

| LOD | Triangle Budget | Notes |
|---|---|---|
| LOD 0 (0–8m) | 30,000 tris | Membrane layering at full complexity; interior caul geometry included |
| LOD 1 (8–20m) | 12,000 tris | Membrane layering MUST be preserved (Section 5.5 non-negotiable); minimum two overlapping membrane planes; no LOD pop permitted between LOD 0 and LOD 1 |
| LOD 2 (20–40m) | 3,500 tris | Simplified membranes acceptable; gross silhouette must remain non-bilateral and angular |
| LOD 3 (40m+) | Impostor billboard | Mesh-only LOD; caul point-light continues operating independently of mesh state |

**Fauna Archetypes (GPU instanced — individual instance budgets):**

| Category | LOD 0 | LOD 1 | LOD 2 |
|---|---|---|---|
| Large fauna (drifter scale) | 6,000 tris | 2,500 tris | 800 tris |
| Medium fauna | 3,000 tris | 1,200 tris | 400 tris |
| Small fauna | 1,200 tris | 500 tris | 150 tris |

Fauna sharing a visual archetype are batched via GPU instancing — one draw call per fauna category regardless of instance count, provided all instances share the same material with property block variation.

**Environmental Props:**

| Asset | LOD 0 | LOD 1 | Notes |
|---|---|---|---|
| Hero environmental prop | 5,000 tris | 1,800 tris | Navigation landmarks; not instanced |
| Layer 3 biological growth — large (>0.5m) | 2,000 tris | 600 tris | Must support vertex animation or blend shape at LOD 0; deformed pose maintained at LOD 1 |
| Layer 3 biological growth — small (<0.5m) | 600 tris | 180 tris | High-density instancing; this budget drives maximum Shallows instance count |
| Tiling/kit environment piece | 1,200 tris | 400 tris | Many tiles visible simultaneously — budget strictly enforced |
| Base structure module (per module) | 2,500 tris | — | No LOD 1 required; base structures are interaction-distance only (FLAG-VERIFY: confirm occlusion beyond 40m with level design) |
| VFX geometry (particle mesh cap) | 200 tris max | — | Per particle mesh element; sprite particles are exempt |

---

### 8.7 Texture Memory Budgets

**Overall allocation (4GB RAM ceiling):**

| Category | Allocation | Notes |
|---|---|---|
| Engine + OS overhead | 512 MB reserved | Unity runtime, OS, audio system |
| Gameplay + UI + misc | 256 MB reserved | Code-side allocations, UI textures, font atlases |
| **Art texture budget (total)** | **~3,200 MB** | Working ceiling for all art texture memory |
| Character textures | 256 MB | Player + predator + all fauna categories |
| Environment streaming (active chunks) | 1,536 MB | ~2–3 active terrain chunks plus transition zones |
| VFX textures | 128 MB | Particle sheets, distortion maps, emissive flipbooks |
| Decal textures | 64 MB | Compression trace decals and salvage scoring decals |
| Safety headroom | 256 MB | Never fill to ceiling — streaming spikes require slack |
| **Environment prop peak budget** | **~960 MB** | Remainder; covers all non-streaming environment textures |

FLAG-VERIFY: Profile actual streaming chunk size against a representative Shallows scene before treating these numbers as hard gates.

**Texture size limits per asset category:**

| Category | Max Resolution | Notes |
|---|---|---|
| Player suit (first-person arms) | 2048×2048 | Dominant foreground object |
| Player suit (third-person body) | 1024×1024 | Shared with wear overlay atlas |
| Predator | 2048×2048 | Singleton; membrane complexity requires full 2K. Caul emissive mask as separate 1024 |
| Hero environmental prop | 2048×2048 | Bespoke navigation landmarks only |
| Tiling kit piece (base, crash hull) | 1024×1024 | Kit pieces share one atlas — see atlas strategy below |
| Layer 3 biological growth | 512×512 per type, atlased | GPU instanced; small per-type textures atlased into 2048×2048 per category |
| Layer 2 passive coating | 512×512 tiling | Triplanar projection material |
| Decal textures (compression traces) | 512×512 | Three shader states channel-packed on one 512 atlas |
| VFX sprite sheets | 512–1024×1024 | No VFX sprite sheet above 1024 |
| UI textures | 512×512 max | All UI elements in one atlas per screen |

**2K texture environment prop limit**: At 2048×2048 BC7 (≈5.3 MB per texture with mip chain), practical active target is **60 unique 2K texture sets** (albedo + normal + roughness) = approximately 954 MB. Stay within: maximum 15 unique hero prop sets, maximum 8 unique kit atlases.

**Atlas strategy for biological elements**: Use a `Texture2DArray` with 512×512 slices (one per growth variant). Enables GPU instancing without material breaks. Maximum 16 variants per array. FLAG-VERIFY: Confirm `Texture2DArray` support in the project's URP Shader Graph templates before the biological growth shader is authored.

**Suit wear overlay packing**: Author three wear state overlay masks as separate channels of a single 1024×1024 RGBA texture. R = State 1 mask, G = State 2 mask, B = State 3 alpha. One texture drives all three wear states via material property block. Do not author three separate overlay textures.

---

### 8.8 Material Slot Limits Per Asset

Excess material slots generate excess draw calls. Each unique material on each renderer is a separate draw call unless GPU instancing is active.

| Asset Type | Maximum Material Slots | Notes |
|---|---|---|
| Player suit (first-person arms) | 2 | Slot 1: suit surface (panels + joints via mask). Slot 2: HUD emitter zones (emissive). Wear state via property block on Slot 1. |
| Player suit (third-person body) | 3 | Slot 1: suit body. Slot 2: visor (transparency). Slot 3: HUD emitter zones. |
| Predator | 3 | Slot 1: outer carapace/membrane. Slot 2: caul interior emissive (occlusion + emission layer). Slot 3: specialized surface if required. All membrane planes share Slot 1. |
| Fauna archetype | 2 | Slot 1: body surface. Slot 2: bioluminescent zone if present. Fauna sharing a category must use the same material with property block variation. |
| Hero environmental prop | 2 | Slot 1: primary surface. Slot 2: biological growth overlay or emissive detail only if unavoidable. |
| Tiling kit piece | 1 | One material, one atlas. Each additional slot on kit pieces multiplies draw calls linearly across all instances. |
| Layer 3 biological growth element | 1 | GPU instanced. One material per biological category. All variation via property block or Texture2DArray. Zero tolerance for additional slots on instanced elements. |
| Base structure module | 2 | Slot 1: manufactured surface. Slot 2: interior/emissive zones. Biological growth on base structures is separate mesh elements, not additional slots on the base mesh. |
| VFX particle mesh | 1 | One material per VFX particle mesh element. |

**Hard rule**: Any asset submitted with more material slots than permitted is rejected at import gate, regardless of visual quality. Material slot violations are arithmetic draw call overruns.

---

### 8.9 URP-Specific Constraints

**Dynamic light budget:**

| Light | Type | LOD-culled? | Notes |
|---|---|---|---|
| Player held light | Point light | No — always LOD 0 range | Primary scene illumination; shadow-casting enabled |
| Predator caul point-light | Point light | No — must not cull at 40m | See constraint below |
| Base structure interior | Point lights, baked where possible | Yes — distance cull acceptable | Maximum 4 dynamic interior lights simultaneously; others baked to Adaptive Probe Volumes |
| Bioluminescent pulse elements | Emissive material — NOT dynamic lights | N/A | Zero tolerance for per-organism dynamic lights on Layer 3 elements — would exhaust light budget in The Shallows alone |

Peak dynamic light count: Player light (1) + predator caul light (1) + up to 4 base interior lights = 6 dynamic lights. This provides headroom for gameplay event lights.

**Predator caul point-light — must not cull at 40m**: A `Light` component attached to the predator's root GameObject (not a child of any LOD-switched renderer) remains active regardless of the LOD Group state. `Light.range` must reach 40m from the predator center.

FLAG-VERIFY: Verify the exact relationship between `Light.range` and URP Forward+ per-tile light attenuation in Unity 6.3 LTS — a 40m range point light has non-trivial fill-rate cost on mid-range PC. Profile in isolation before committing to scene-wide assumption. If 40m range is GPU-prohibitive, the fallback is a custom RenderGraph render feature injecting a screen-space rim-light at the predator's world-space position.

**GPU instancing compatibility (GPU Resident Drawer requirements):**
- All instanced asset Mesh Renderers must use static GI only (no Light Probe Proxy Volume)
- No per-instance unique materials — use `MaterialPropertyBlock` for per-instance variation
- Meshes must not use blend shapes if they are GPU Resident Drawer candidates — blend shapes prevent instancing. Use vertex animation shaders for instanced biological growth (see Section 8.11)

**Shader complexity:**
- Maximum 4 shader keywords per material shader. Variants above this count cause stall and memory pressure.
- All per-instance variation must use properties, not keywords.
- The death state desaturation vignette must use a single post-process pass using the RenderGraph API (`RecordRenderGraph`). Do not use the deprecated `SetupRenderPasses` / `Execute` pattern — soft-deprecated in Unity 6.2, flagged for hard removal.
- Shader Graph master nodes must target URP Lit or URP Unlit. Do not use Built-in pipeline shader targets.

---

### 8.10 Predator Technical Requirements — Feasibility Confirmation

All four art bible commitments are achievable in URP with the following implementation constraints:

**a) Interior caul self-illumination via emissive material with normal-map-driven occlusion**: Achievable. In Shader Graph: sample emissive color, modulate by a curvature/cavity map derived from the normal map (AO approximation via normal-derived bent normal), output to Emission channel of a URP Lit master node. The predator mesh must include a separate interior-facing geometry layer with normals pointing inward, so the emissive reads as originating from inside the caul volume. This geometry is included in the Section 8.6 polygon budget.

**b) World-space caul point-light not culled at 40m**: Achievable with a constraint. A `Light` component as a child of the predator's root (not under any LOD-switched renderer) remains active regardless of LOD state. FLAG-VERIFY: Profile GPU fill-rate cost of a 40m-range point light on target hardware in isolation. If prohibitive, implement a custom URP RenderGraph render feature using the predator's world position as a shader input to generate a screen-space rim contribution.

**c) Membrane layering preserved through LOD 1**: Achievable. The Section 8.6 budget of 12,000 tris at LOD 1 provides sufficient budget for two overlapping membrane planes. The LOD 1 mesh must demonstrate membrane plane overlap in a side-profile silhouette render at the transition distance before approval.

**d) No LOD pop between LOD 1 and LOD 0**: Achievable by closing the geometric gap. Use dithered LOD crossfade (SpeedTree dither crossfade technique) on the predator's LOD Group. FLAG-VERIFY: Confirm URP LOD crossfade dithering compatibility with the predator's custom Shader Graph material in Unity 6.3 LTS — the Shader Graph must explicitly handle the `unity_LODFade` built-in variable.

---

### 8.11 Blend Shape / Vertex Animation Constraints

**Decision tree:**

| Condition | Use |
|---|---|
| Asset is GPU instanced (biological growth, fauna categories) | Vertex animation shader only — blend shapes are incompatible with GPU instancing |
| Asset is a singleton or low-instance-count object (hero prop, predator) | Blend shapes acceptable |
| Asset requires continuous disturbance float (0.0–1.0) drive | Either works; shader approach avoids Animator dependency |

**For biological growth disturbance system** (8–12 instanced props per 10m radius in The Shallows): Use vertex animation shaders.

**Recommended approach**: Procedural vertex animation using sine-wave oscillation driven by world-space position (so instances do not animate in synchrony) plus a blend toward a retracted offset pose driven by the disturbance float uniform. Avoids VAT texture memory; works natively with GPU instancing.

**Maximum vert count for a vertex-animated instanced prop within budget**: Do not exceed 2,000 tris at LOD 0 (already established in Section 8.6). At 100 instances × 2,000 tris = 200,000 tris per instanced type per draw call — approximately 0.1–0.2ms vertex cost per type. Across 12 biological growth types in The Shallows: under 2.5ms vertex cost total. FLAG-VERIFY: These are first-principles estimates. Verify against a Unity Frame Debugger capture of a representative Shallows scene at target instance density.

---

### 8.12 Decal System Constraints

**URP Decal Renderer Feature — Compression Trace System:**

Implementation: URP `DecalProjector` component instances. The aging shader parameter (`_TraceAge`, a normalized float 0.0–1.0) is a material property block value updated by the disturbance simulation system each frame for each live decal.

**Maximum live decal instances**: FLAG-VERIFY — post-cutoff. Working assumption: **48 live compression trace decals** maximum at any time. This leaves 16 decal slots for other decal types (salvage scoring, impact events).

**Predator patrol path visual memory constraint**: If one decal is generated per ~2–3m of predator travel and decals persist for 20–30 game-hours, a 48-decal pool represents approximately 96–144m of traceable patrol history.

**Implementation requirement**: The decal spawner must maintain a circular buffer of 48 `DecalProjector` instances (pooled, not destroyed/created at runtime), recycling the oldest when the pool is full. The gameplay system must expose the "oldest active trace" for reclamation.

**Decal atlas**: All three compression trace states (fresh, mid-age, recovered) channel-packed into a single 512×512 texture. The aging shader blends between channels based on the `_TraceAge` float — one texture bind regardless of state. Required for the pooling model above.

---

### 8.13 Import Pipeline Checklist

This is the mandatory technical gate applied to every mesh asset before art director review. The technical artist runs this checklist on every submission. BLOCKING items return the asset to the artist. ADVISORY items are flagged for correction before the sprint milestone.

**Mesh Requirements:**

| Check | Level | Criteria |
|---|---|---|
| Triangle count within budget | BLOCKING | See Section 8.6. Count must be at or below the table value for the asset category and LOD. |
| No n-gons | BLOCKING | All faces must be tris or quads. N-gons produce unpredictable results during Unity mesh import triangulation. |
| No zero-area faces or zero-length edges | BLOCKING | Causes UV seam and normal map artifacts. |
| No duplicate vertices at weld points | BLOCKING | Open edges at weld points cause hard normals where smooth normals are required. Run a vertex merge pass in DCC before export. |
| UV channel 0 present, non-overlapping | BLOCKING | Required for all assets. Overlapping UVs cause lightmap and decal projection errors. |
| UV channel 1 present, lightmap-unwrapped | BLOCKING for ENV assets | Required for static environment geometry receiving baked light from APV. Character meshes exempt. |
| Pivot point at world origin or defined anchor | BLOCKING | Misplaced pivots break modular kit snapping and LOD Group setup. |
| LOD chain complete | BLOCKING | All LOD levels defined in Section 8.6 must be present. Missing LOD levels are not acceptable even in early production. |
| LOD crossfade configured on assets with LOD pop risk | BLOCKING | Predator LOD Group must have SpeedTree-style dither crossfade. Confirm `unity_LODFade` sampled in shader. |
| Material slot count within limit | BLOCKING | See Section 8.8. Excess slots are rejected. |
| No inverted faces | BLOCKING | Confirm with backface culling enabled in DCC before export. |

**Texture Requirements:**

| Check | Level | Criteria |
|---|---|---|
| Power-of-2 dimensions | BLOCKING | All textures must be power-of-2 (512, 1024, 2048). Non-power-of-2 breaks mip generation and GPU memory alignment. |
| Texture resolution within category budget | BLOCKING | See Section 8.7 table. No oversize textures regardless of visual quality. |
| Correct compression format set | BLOCKING | Albedo: BC7/DXT5. Normal: BC5 (two-channel). Mask/packed: BC7. Emissive: BC7. Single-channel: BC4. |
| Normal map Import Type set to "Normal Map" | BLOCKING | Unity's normal map import applies the correct channel swizzle for URP. Importing as Default produces incorrect normals. |
| Generate Mip Maps enabled | BLOCKING | All runtime textures except UI. No texture without mip chain. |
| sRGB setting correct | BLOCKING | Albedo: sRGB On. All other maps: sRGB Off (linear). Incorrect sRGB produces wrong material response in URP. |
| Texel density within range for surface category | ADVISORY | See Section 6.2. Verify against reference quad in DCC tool before export. |
| Emissive texture present on all bioluminescent assets | BLOCKING | Per Section 5.5 non-negotiable: emissive must not be stripped at any LOD level. Verify emissive is not null on LOD 2 and LOD 3 renderer components. |

**Naming and Organization:**

| Check | Level | Criteria |
|---|---|---|
| Asset name follows snake_case convention | ADVISORY | See Section 8.2. Category prefix + descriptive slug + variant + LOD suffix. |
| Texture name encodes type suffix | ADVISORY | `_alb`, `_nrm`, `_msk`, `_emi`, etc. per Section 8.2. Unnamed or generically named textures are rejected at the next pipeline audit. |
| Mesh file contains only one root object | BLOCKING | Multiple unrelated objects in one FBX break the LOD Group auto-setup. |
| LOD meshes named with `_LOD0`, `_LOD1`, `_LOD2`, `_LOD3` suffix (uppercase) | BLOCKING | Unity's LOD Group import relies on this convention for automatic LOD assignment. |
| Asset placed in correct directory per category | ADVISORY | Misplaced assets break Addressable group configuration. |

**GPU Instancing Compatibility (instanced assets only):**

| Check | Level | Criteria |
|---|---|---|
| Material has GPU Instancing enabled | BLOCKING | Required for all env_bio, char_fauna, and kit piece materials. |
| No blend shapes on instanced meshes | BLOCKING | Blend shapes disable GPU instancing. Confirmed in DCC before export. |
| Material uses MaterialPropertyBlock for per-instance variation | BLOCKING | Verify with Unity Frame Debugger — instanced draw calls must appear as one batch per category, not one call per instance. |
| No Light Probe Proxy Volume on instanced renderers | BLOCKING | GPU Resident Drawer requirement. |

**Disturbance System Integration (vertex-animated assets only):**

| Check | Level | Criteria |
|---|---|---|
| Disturbance float property exposed on material | BLOCKING | Named `_DisturbanceBlend` (normalized 0–1). Gameplay code binds to this exact property name. Non-standard names break the disturbance system binding. |
| Undisturbed and disturbed pose verified in editor | BLOCKING | Set `_DisturbanceBlend` to 0 and 1. Both states must be visually correct and within geometry bounds. |
| Vertex animation does not exceed mesh bounding box | ADVISORY | Overshoot causes frustum culling errors — the mesh is culled while visually present. Expand the import bounding box if animation exceeds it. |

---

*Cross-references: Section 5.5 (LOD philosophy), Section 6.2 (texel density), Section 6.7 (draw call budget). All FLAG-VERIFY items require profiling against a Unity 6.3 LTS project build before these numbers become hard production gates.*

---

## Section 9: Reference Direction

### 9.1 "Stalker" (Andrei Tarkovsky, 1979) — Lighting and Atmosphere

**What it is**: A Soviet science fiction film in which a guide leads two men through a post-catastrophe forbidden zone where the laws of physics are unreliable.

**What to take**: Tarkovsky's Zone is lit by a single rule — luminosity follows hazard, not time of day. Water catches light when nothing else does. Dead grass is brighter than living grass. The light source is never the sun, the lamp, or the fire; it is an undefined ambient directionality that pools at precisely the locations that are wrong. Apply this to Terranova by making the world's own bioluminescence the primary light source in dangerous states, not the player's lamp. When disturbance rises, the world begins to light itself. Biological elements pulse light toward the player from directions that do not match any single source. The effect: the player's light becomes less relevant as the danger increases — their agency in defining the lit space contracts exactly when they need it most.

Technically: light pooling on ground plane at biome-scale, not cast from above. Horizon fog that is lighter than the sky above it (inverted luminance gradient). Puddles and reflective surfaces as secondary light contributors in high-disturbance states.

**What to leave behind**: Tarkovsky's pacing and the film's existential exhaustion. The Zone reads as beautiful, melancholic, and welcoming in several sequences — this is antithetical to Terranova's principle that safety is always provisional. Do not allow biological lighting to become ambient and restful. The pooled luminosity must always carry directional information, not decorative warmth. The Zone is ruined and nostalgic; Terranova is ancient and indifferent.

**How it connects**: Directly serves Principle 1 (Penumbra Is the Primary Space) and Pillar 4 (Tension Over Comfort). The mood grammar rule that contrast level encodes player control is realized through this approach: when bioluminescent lighting pools without a discernible source, contrast rises in exactly the areas the player cannot categorize — the penumbra expands by definition.

---

### 9.2 Ernst Haeckel — "Kunstformen der Natur" (1899–1904) — Creature and Organic Design

**What it is**: A 19th-century scientific illustration series documenting radiolarians, medusae, sea anemones, and deep-ocean organisms. Haeckel discovered that the most alien-looking structures on Earth follow strict geometric and bilateral rules.

**What to take**: Haeckel's organisms are built from geometric axioms — bilateral symmetry applied recursively, radial repetition at scale, fractal branching with consistent ratios. His radiolarians and foraminifera look alien precisely because they are so ordered: not organic randomness, but strict geometric law applied to biological material. Apply this to Terranova's environmental biology and fauna: the alien quality of native organisms should come from geometry that is too consistent, not from chaos. A frond organism that repeats a precise tri-radial spiral 240 times reads as more unsettling than one that is asymmetric and lumpy, because the mind cannot attribute it to accident. The predator's structural extensions (angular geometric extrusions from the membrane surface) follow a Haeckelian logic: too systematic to be random, too biological to be manufactured.

Micro-scale fractal detail on all biological surfaces should pass the Haeckel test: can you identify the axiomatic rule generating the surface at close inspection? If the detail is pure noise, replace it with iterated geometric subdivision.

**What to leave behind**: Haeckel's color choices — his plates are saturated, warm, illustrative, often beautiful. Terranova's biological surfaces are low-saturation except in active disturbance states. Do not import the aesthetic warmth of scientific illustration. Also leave behind bilateral symmetry in the predator's overall form — Haeckel's organisms have a clear center axis; the predator must not. Apply his geometric recursion rule to the predator's surfaces and extrusions, not to its macro silhouette.

**How it connects**: Serves Principle 2 (Scale Speaks Before Color) — geometric recursion is legible at multiple scales without color cues. Serves Section 5's predator silhouette requirement that "familiar structures [are] mutated into unfamiliar geometry." The non-Euclidean apparent shape of the predator requires an underlying logic that the player cannot consciously articulate but can subconsciously detect — Haeckelian geometric rigor provides that logic.

---

### 9.3 "Blade Runner 2049" (Denis Villeneuve / Roger Deakins, 2017) — Environmental Scale and Isolation

**What it is**: A science fiction film shot primarily in desaturated, monochromatic outdoor environments — orange dust plains, white salt flats, grey flooded ruins — that communicate overwhelming scale through color restriction and horizon geometry.

**What to take**: Cinematographer Roger Deakins' approach to isolation: a single, dominant, low-saturation hue occupies the entire environment, and the only contrast comes from the geometry of small human-made vertical elements against the horizontal world. The effect of isolation is produced not by emptiness but by tonal uniformity — the world refuses to differentiate itself, and the human figure reads as loud and out of place by default. Apply to Terranova's biome base states: ashen tone (H 210°) should dominate the inactive world the way the orange dust dominates those sequences. The player's salvage amber lamp and suit geometry become the only warm, contrasting element in a field of visual uniformity — legible not because the environment is dark but because it refuses to compete.

The second technique: Deakins places the horizon at precise vertical thirds or quarters, not at center frame. The sky portion establishes the scale of the space before anything in it is legible. In a first-person game, this translates to: the sky zone (void-blue, H 250°) should occupy the upper 35–45% of the primary environment composition during non-disturbance states, making the canopy height felt before the player encounters it.

**What to leave behind**: The film's narrative elegance and its color sequencing driven by emotional arc. Terranova's color states are driven by ecological disturbance logic, not cinematic mood design. Do not produce composed landscapes. Also leave behind the retrofuturist material language — 2049's surfaces are corroded human technology. Terranova's human surfaces should feel operational and recent against a world that has been here for geological timescales.

**How it connects**: Directly serves Pillar 3 (Solitude and Scale) and Principle 2 (Scale Speaks Before Color). The salvage amber / ashen contrast is the visual implementation of the player being small against an indifferent world — and this reference demonstrates that scale is a function of color uniformity, not scene complexity.

---

### 9.4 "Control" (Remedy Entertainment, 2019) — Material and Surface Quality

**What it is**: A third-person action game set in a brutalist Federal government building partially occupied by a hostile extra-dimensional entity, using poured concrete, institutional tile, and fluorescent light as the primary surface language throughout.

**What to take**: Remedy solved a specific problem Terranova shares: how to make manufactured human surfaces feel categorically distinct from the inhuman, using physically plausible materials throughout. Their approach: human surfaces are defined by strict planarity, uniform surface sheen, and evidence of intentional manufacture (tile grout lines, poured concrete formwork marks, standardized fixtures). Apply to Terranova's biological encroachment system (Section 6.2): base structure surfaces should read as unmistakably manufactured — hard specular sheen on wall panel surfaces, visible fastener geometry, evidence of fabrication process. The surface under the biological encroachment should still be legible at close range. The encroachment story requires the manufactured surface to be authoritative first.

Second extraction: their interior fluorescent lighting casts hard parallel shadows from ceiling geometry — categorically different from exterior bioluminescent pooling (directionless, ground-level). This contrast reinforces the game-grammar rule that warm = human agency. Base interior lighting in Terranova should cast identifiable parallel shadows from a defined source, so the player always knows when they are inside a human-made space.

**What to leave behind**: The Metroidvania spatial logic and the brutalist permanence. Control's architecture is institutional, studied, and designed to be oppressive. Terranova's human structures are improvised survival infrastructure built by people who expected to leave — they should feel like field equipment, not government facility. Do not produce the Oldest House. The salvage amber material language should feel operational and recent.

**How it connects**: Serves Section 6.2 (the four-layer environment surface system) and Pillar 2 (Knowledge Is Survival). The legibility of biological encroachment over manufactured surfaces depends on the manufactured surface being visually authoritative. A weak human surface reading produces a weak encroachment reading — the player cannot perceive what is being lost.

---

### 9.5 Wayne Barlowe — "Expedition" (1990) — Creature Design Logic

**What it is**: Scientific illustration work by conceptual artist Wayne Barlowe, documenting a fictional xenobiological survey of an alien world in which organisms are designed according to plausible evolutionary logic under different atmospheric and gravitational conditions.

**What to take**: Barlowe's core discipline: every visible feature on an alien organism has a function that a biologist could argue for. Bony extrusions serve as heat radiators or structural load-bearing elements. Eye placement follows from predation vs. prey evolutionary pressures. Coloration serves camouflage, mate selection, or aposematism. The result is that his creatures feel discovered rather than designed — the viewer's brain reads them as having evolved, not been invented.

Apply to Terranova's fauna archetypes and to the predator: every visible feature should have a plausible diegetic function statable in one sentence. The predator's layered translucent membranes and bioluminescent interior glow are not aesthetic choices — they are the visual signature of an ambush predator whose primary detection-avoidance strategy is optical transparency followed by sudden interior luminosity. This function-first discipline prevents decorative alien design, which Terranova explicitly rejects.

Secondary extraction: Barlowe's color restraint. His alien organisms are colored for survival in their environment — they do not glow unless it serves a specific function. This supports Principle 3 (Biological Color Means Information): fauna base coloration should be ecologically consistent with their biome tier, with saturation increase occurring only when the organism is in an active biological state (fleeing, mating, dying). A grazer that is always brightly colored provides no ecological information — a grazer that brightens when disturbed is a disturbance indicator.

**What to leave behind**: Barlowe's bilateral symmetry defaults — most of his organisms have a clear axis of symmetry, which is a pragmatic illustration choice but produces creatures that read as Earth-adjacent. Terranova's fauna should deviate from bilateral symmetry in asymmetric appendage count and placement. Also leave behind his tendency toward the impressive and monumental — several of his most iconic creatures are spectacular, large, and dramatically dominant. Terranova's fauna archetypes should be unremarkable at first inspection, legible through behavioral pattern recognition, not visual spectacle.

**How it connects**: Directly serves Pillar 5 (Earned Revelation) and the anti-pillar "No spectacle-first." Barlowe's function-first creature design discipline prevents the team from producing alien fauna that reads as a concept art showcase rather than a believable ecology. The game's promise — "I learned to read a world that was trying not to be readable" — requires that the world initially resist reading. Decorative alien design short-circuits this by being immediately legible as alien-designed rather than alien-evolved.

---

### Composite Rule

These five references do not converge on a single aesthetic. That is intentional. A Terranova environment that looks like Tarkovsky is too beautiful and melancholic. One that looks like 2049 is too cinematic and composed. One that looks like Haeckel is too illustrative and warm. One that looks like Control is too institutional. One that looks like Barlowe is too spectacular. The correct composite takes one narrow technique from each — the lighting logic, the geometric discipline, the scale grammar, the surface authority, the function-first creature logic — and discards the rest. If an outsourcing artist can identify which of these five references a specific asset is "from," the asset has gone too far. A correctly derived Terranova asset should be identifiable only as Terranova.
