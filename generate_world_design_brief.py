"""
Generate WORLD-DESIGN-BRIEF.pdf — the document for outsourcing world
design work on Mycelia. Covers per-biome intent + style + spatial
requirements + technical constraints, plus shared world elements (Trading
Post, player huts, Forest Spirits, etc.).

Style matches SCRIPTING-ORDER.pdf (Helvetica, plain headings, numbered
lists, tables for tight reference data, no graphics).
"""

from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.lib.enums import TA_LEFT
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle,
)
from reportlab.lib import colors

OUTPUT_PATHS = [
    r"C:\Users\fonte\Documents\Mycelia\docs\WORLD-DESIGN-BRIEF.pdf",
    r"C:\Users\fonte\Downloads\Mycelia - World Design Brief.pdf",
]

# ---------- Styles ---------------------------------------------------------

styles = getSampleStyleSheet()

H1 = ParagraphStyle(
    "H1", parent=styles["Heading1"],
    fontName="Helvetica", fontSize=18, leading=22,
    spaceBefore=18, spaceAfter=10, textColor=colors.black,
)
H2 = ParagraphStyle(
    "H2", parent=styles["Heading2"],
    fontName="Helvetica", fontSize=14, leading=18,
    spaceBefore=14, spaceAfter=6, textColor=colors.black,
)
H3 = ParagraphStyle(
    "H3", parent=styles["Heading3"],
    fontName="Helvetica", fontSize=11, leading=14,
    spaceBefore=8, spaceAfter=4, textColor=colors.HexColor("#555555"),
)
BODY = ParagraphStyle(
    "Body", parent=styles["BodyText"],
    fontName="Helvetica", fontSize=11, leading=15,
    spaceAfter=6, alignment=TA_LEFT, textColor=colors.black,
)
LIST_ITEM = ParagraphStyle(
    "ListItem", parent=BODY,
    leftIndent=20, bulletIndent=8, spaceAfter=3,
)


def P(text):
    return Paragraph(text, BODY)


def heading(text, level=2):
    return Paragraph(text, [None, H1, H2, H3][level])


def numbered(items):
    return [Paragraph(f"{i}. {item}", LIST_ITEM) for i, item in enumerate(items, 1)]


def bullets(items):
    return [Paragraph(f"• {item}", LIST_ITEM) for item in items]


def table(rows, col_widths):
    t = Table(rows, colWidths=col_widths)
    t.setStyle(TableStyle([
        ("FONTNAME", (0, 0), (-1, -1), "Helvetica"),
        ("FONTSIZE", (0, 0), (-1, -1), 10),
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#eeeeee")),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]))
    return t


# ---------- Content -------------------------------------------------------

story = []

# Title + intro
story.append(heading("Mycelia — World Design Brief", level=1))
story.append(P(
    "This document briefs world designers / 3D builders on the design and "
    "construction of Mycelia's playable world. Mycelia is a cozy mushroom-"
    "cultivation Roblox game in the Bee Swarm Simulator longevity lineage, "
    "wrapped in a Stardew-Valley-style cozy aesthetic. The world is the "
    "single most important art asset — players spend 100+ hours in it; it "
    "must reward repeat visits, feel inviting on first impression, and "
    "stay coherent across 7 biomes that each have their own mood."
))
story.append(P(
    "What you build: 3D world geometry, terrain, foliage, NPC homes, props, "
    "decorative mushrooms (separate from the gameplay-spawned ones), the "
    "Trading Post building, player hut interior prefab, and biome transition "
    "spaces. Each biome is a 1000-stud-diameter zone; biomes are 2000 studs "
    "apart in a single-place world (no separate Roblox Places — see "
    "Technical Constraints)."
))
story.append(P(
    "What you do NOT build: gameplay code, UI, animations, audio, particle "
    "VFX (those have their own briefs and contractors). You DO place the "
    "spawn pads, plot regions, and wild-spawn-area markers per biome so "
    "the gameplay scripter can hook into them — see Per-Biome Spatial "
    "Anchors section in each biome."
))

# Vision + tone
story.append(heading("Visual + tonal direction", level=2))
story.append(P(
    "Hand-painted, slightly desaturated cozy aesthetic. Think Studio Ghibli "
    "forest scenes meets cottagecore. Heavy use of mist, dappled light, "
    "and atmospheric perspective. The world should feel inviting on first "
    "impression and varied enough to reward repeat visits over hundreds "
    "of hours."
))
story.append(P("Locked-in design rules across all biomes:"))
story.extend(bullets([
    "Cozy, never threatening. No combat exists in Mycelia. No skeletons, no derelict horror, no aggressive predators. The Lost Cathedral biome is the only one that flirts with mystery, and even there it's wonder-leaning, not fear-leaning.",
    "Slightly desaturated palette. Pure-saturated colors read as toy-like. Pull saturation down 10-15% from default Roblox material colors. Warm tones lean toward ochre and honey rather than fire-engine red; cool tones lean teal and slate rather than electric blue.",
    "Soft lighting. Sharp shadows feel harsh. Use ShadowSoftness ~0.3-0.5, EnvironmentDiffuseScale around 0.4-0.6.",
    "Dappled light is the signature. Sunlight breaking through canopy = the most-used composition technique. Lay this in via Atmosphere haze + tree shadows + Beam parts where appropriate.",
    "Mist is a core ingredient. Atmosphere density should be high enough that distant biome elements fade visibly. Create an illusion of depth without requiring a huge geometry budget.",
    "Mobile-first readability. Mycelia targets ages 9-16 primarily; mobile is the dominant platform. Every important landmark must be readable from a thumbnail-sized image. NPCs, plots, the witch's cave, the cauldron — all should pop visually from across the biome.",
    "Distinct mushroom silhouettes. The wild-spawned mushrooms are gameplay-spawned (scripter handles those). But decorative mushrooms you place must NOT visually conflict with the gameplay species. Use larger sizes (3-5x), unusual shapes (lattice, jelly, crystalline) to clearly distinguish from harvestable mushrooms.",
    "Particle accents are core. Spores in the air, glowing pollen, distant fireflies, drifting motes. These are supplied by the VFX contractor; you place ParticleEmitter anchor points where they should attach.",
]))

# Player journey
story.append(heading("The player journey through the world", level=2))
story.append(P(
    "A new player should be able to do these steps in their first 5 minutes "
    "with zero text-tutorial hand-holding, just by following the visible "
    "landmarks of the Starter Glade. Designing the spawn area to make this "
    "discovery flow obvious is more important than any individual prop choice."
))
story.extend(numbered([
    "Spawn on the spawn pad in the Starter Glade. Look around — see immediately a small set of distinct landmarks: glowing mushrooms in one direction (wild field), a row of soil patches in another (plots), a path leading toward a tall mountain (witch's cave), and a path toward a pond (decorative water feature with koi).",
    "Walk toward the wild mushrooms. They're spaced and lit clearly. Pick one up by walking to it (ProximityPrompt-driven; no inventory tutorial needed because the HUD updates automatically).",
    "Notice coins in the HUD increased? No — coins come from selling. Walk back toward the path to the cave. The witch is in there.",
    "Inside the cave: see the Forest Witch (NPC stand-in for now; replaceable). Press the prompt to sell. See coins go up.",
    "Walk back to the plots. Plant a Spore Patch. Wait. Watch the soil change visually as it grows. Harvest when ready.",
    "Notice the cauldron next to the witch. Approach it. Realize you can brew the mushrooms you've collected.",
]))
story.append(P(
    "Every step should feel like the WORLD invites the action, not a UI "
    "telling the player what to do. The world's visual organization is the "
    "tutorial. Spend disproportionate effort on the Starter Glade — it's "
    "the player's first impression and will determine retention."
))

# Spatial constraints
story.append(heading("Technical constraints — read before building", level=2))
story.append(P(
    "Mycelia is a single-place Roblox game. All 7 biomes coexist in one "
    "Workspace at fixed coordinates 2000 studs apart. The architecture "
    "decision (single-place over per-biome separate Places) is locked in — "
    "see ADR 001 in the project's docs/decisions/ folder for the reasoning. "
    "This means:"
))
story.extend(bullets([
    "Total world extent is large but bounded: from x=-1500 to x=8500 (covers all 7 biomes with their 1000-stud diameter zones at 2000-stud center spacing). Z and Y dimensions are biome-local, ~1000 stud cube per biome.",
    "Workspace.StreamingEnabled = true (already configured by the scripter). This means content far from the player is streamed out to save memory. You don't need to optimize geometry counts heroically — focus on per-biome budgets, since players see one biome's content at a time.",
    "Per-biome polygon budget: aim for ~300k polygons total per biome (mid-tier mobile target). Includes terrain + props + buildings + decorative mushrooms. Soft-cap; can go higher for a hero biome (Glimmerwood, Lost Cathedral).",
    "Use Roblox Terrain (voxel) for ground, hills, water bodies. Use BasePart geometry for buildings + props + mushrooms. Use MeshParts for high-detail items where polygon savings matter.",
    "All NPC positions, plot regions, and wild-spawn areas have FIXED coordinates per biome (locked in src/shared/Constants.luau Constants.BIOMES). You build around these anchors. See per-biome sections.",
    "Each biome's content lives under Workspace.Biomes.<biomeId> (Folder). When you finish hand-building a biome, set the Folder's BuiltManually attribute to true — this tells the scripter's procedural fallback to skip overwriting your work.",
    "Mushroom spawn zones are invisible BaseParts named per biome (e.g., WildSpawnArea_StarterGlade). The scripter will spawn mushrooms inside these volumes at runtime; you DON'T place individual gameplay mushrooms — just decorative ones.",
]))

# Per-biome specs
story.append(PageBreak())
story.append(heading("Per-biome design specifications", level=1))
story.append(P(
    "7 biomes shipping across the lifetime of the project. Phase 1 ships "
    "Starter Glade + Misty Hollow. The other 5 land in Phase 4 (Global "
    "Launch). Build them in unlock order so playtesting can keep up; "
    "Starter Glade and Misty Hollow are highest priority."
))
story.append(P("Quick-reference table (full details below):"))

biome_overview = [
    ["Biome", "Unlock", "Phase", "One-line identity"],
    ["Starter Glade", "Always", "Pre-Alpha", "Misty woodland clearing — your first home"],
    ["Misty Hollow", "Reputation 100", "Phase 1", "Rainforest hollow with ever-present rain mist"],
    ["Frostroot Pass", "Reputation 300", "Phase 4", "Snowy mountain pass; slow-growing high-value species"],
    ["Sunken Grove", "Reputation 600", "Phase 4", "Mysterious swamp; alchemy ingredients"],
    ["Old Growth", "Reputation 1500", "Phase 4", "Ancient forest with massive trees, legendary species"],
    ["Glimmerwood", "Reputation 2500 + lunar quest", "Phase 4", "Bioluminescent night forest"],
    ["Lost Cathedral", "Event-based", "Phase 4", "Ruined nature-reclaimed temple; mythic event spawns"],
]
story.append(table(biome_overview, [1.2 * inch, 1.7 * inch, 0.9 * inch, 3.0 * inch]))
story.append(Spacer(1, 8))

# ----- STARTER GLADE -----
story.append(PageBreak())
story.append(heading("1. Starter Glade", level=1))
story.append(P("Status: Pre-Alpha biome (already partially built). Always unlocked. The first biome a player sees, and the one they spend the most time in (months 1-3 of progression)."))

story.append(heading("Identity + mood", level=3))
story.append(P(
    "A misty clearing in a temperate woodland. Mid-morning lighting with a "
    "slight golden tint, like it's perpetually 9am. Warm, welcoming, "
    "domesticated wilderness — the boundary between civilization and the "
    "deeper wild. This is the player's home base; it should feel safe and "
    "familiar like a favorite local park, not exotic."
))
story.append(P("Visual references for the designer to study:"))
story.extend(bullets([
    "Studio Ghibli — Whisper of the Heart's hillside scenes, Princess Mononoke's quiet woodland moments (NOT the dark forest scenes).",
    "Stardew Valley — the Cindersap Forest area at dawn.",
    "Bee Swarm Simulator — the central spawn area's clarity of layout.",
    "Real-world reference: temperate North American or English deciduous forest in early autumn — leaves still on trees, dappled light.",
]))

story.append(heading("Spatial layout", level=3))
story.extend(bullets([
    "Zone center: (0, 0, 0). Zone radius: 500 studs. Total diameter: 1000 studs.",
    "Spawn point: (0, 5, 0). Players appear here on game join + when traveling back from other biomes.",
    "Plot region: starts at (0, 0, 30). 4 plots in a row by default; +N with Bigger Plot gamepass. Spaced 7 studs apart along the X axis.",
    "Wild mushroom spawn area: invisible 60×4×60 BasePart at (0, 2, -50). Mushrooms spawn inside this volume — you decorate around it but DON'T fill it with permanent prop mushrooms.",
    "Witch's cave: enter from a tunnel mouth in the side of a tall mountain at the east edge. The cave interior is the witch's home + the cauldron + a small storage area. Exterior of the mountain dominates the eastern skyline.",
    "Pond: a freshwater pond on the west side, ~30 studs across, surrounded by lily pads and reeds. Koi fish (animated by the scripter) swim in it. Decorative; no gameplay function in Pre-Alpha.",
    "Travel Coordinator NPC anchor: (-15, 0, 0). A wooden travel post / signpost / map table where players talk to the Travel NPC.",
    "Substrate Merchant NPC anchor: (15, 0, 0). A small market stall.",
]))

story.append(heading("Color palette", level=3))
story.extend(bullets([
    "Primary green: warm moss (~RGB 120, 160, 90). Use for grass, leaves, primary foliage.",
    "Secondary green: deeper forest (~RGB 70, 110, 65). Use for shaded foliage, undergrowth.",
    "Earth tones: sandy ochre (~RGB 200, 175, 130) for paths and dirt patches; warm brown (~RGB 100, 75, 55) for tree trunks.",
    "Highlight: honey-amber (~RGB 240, 200, 130) for sunlit patches, glowing mushrooms, lantern lights.",
    "Stone / mountain: cool sandstone (~RGB 180, 165, 145). Witch's cave mountain leans this color.",
    "Water: deep teal (~RGB 60, 100, 110) for the pond.",
]))

story.append(heading("Architectural elements", level=3))
story.extend(bullets([
    "Witch's cave: rough stone arch entrance carved into a tall mountain (~80 studs tall, mostly natural rock). Inside: a small chamber, a wooden door at the back, oil lamps. The cauldron sits in the center. The witch herself is a placeholder Part for now; designer can leave a marker for the eventual NPC model.",
    "Travel Coordinator post: a wooden signpost (~6 studs tall) with arrows pointing to the other 6 biomes. The arrows can be physically present (wooden boards) even though most biomes are locked — the visual hints at exploration.",
    "Substrate Merchant stall: a small wooden cart with crates of substrates (compost, hardwood, straw, dung). 4-5 studs across. Open-air; the substrate merchant NPC stands behind it.",
    "Path system: dirt paths connecting spawn → plots → witch's cave → pond → travel post → substrate stall. The paths are well-worn; this is a place that's been lived in.",
]))

story.append(heading("Foliage + props", level=3))
story.extend(bullets([
    "30-50 trees of 3-4 distinct types — large oak-like, medium birch-like, scattered pines. Cluster them; don't space evenly.",
    "Decorative mushroom clusters: 8-12 around the perimeter (NOT in the wild spawn area). Use larger / weirder shapes than the gameplay species — say 3x normal size, unusual colors like deep red with white spots, or lattice-textured.",
    "Stones: scattered moss-covered stones, 1-2 small clusters of cairns.",
    "Fallen logs: 2-3 large fallen logs. Players can sit on them.",
    "Wildflowers: small clusters of yellow + white wildflowers along path edges.",
    "Lantern posts: 2-3 small wooden posts with hanging lanterns near the witch's cave entrance + spawn pad. They light up at evening.",
]))

story.append(heading("Lighting + atmosphere", level=3))
story.append(P(
    "The scripter has set up Lighting / Atmosphere / Bloom defaults; the "
    "designer can override per-biome but should preserve the warm-afternoon "
    "feel for Starter Glade specifically. Defaults: ClockTime 14.5, "
    "Brightness 1.6, warm Ambient + OutdoorAmbient (yellow-leaning), "
    "FogStart 200 / FogEnd 850, mild bloom on glowing elements."
))

# ----- MISTY HOLLOW -----
story.append(PageBreak())
story.append(heading("2. Misty Hollow", level=1))
story.append(P("Status: Phase 1 (data + procedural fallback shipped; awaits hand-built terrain pass). Unlock: Reputation 100. The first traveled-to biome; players reach it after a couple hours."))

story.append(heading("Identity + mood", level=3))
story.append(P(
    "A rainforest hollow nestled between hills. It rains here 80% of the "
    "time. Ground is wet, mossy, and dotted with small puddles. The air is "
    "thick with moisture — atmosphere density is noticeably higher than "
    "Starter Glade. Distant trees fade into mist. Player should feel like "
    "they've stepped into a fundamentally different climate, not just a "
    "different patch of woods. Cool, moody, lush — the opposite of Starter "
    "Glade's warmth."
))
story.append(P("Visual references:"))
story.extend(bullets([
    "Studio Ghibli — Princess Mononoke's central forest scenes (the ones with the kodama).",
    "Real-world: Pacific Northwest temperate rainforests (Olympic National Park's Hoh Rainforest).",
    "Avatar: The Way of Water — the bioluminescent water plants (subtle inspiration; we're not going full alien).",
]))

story.append(heading("Spatial layout", level=3))
story.extend(bullets([
    "Zone center: (2000, 0, 0). Zone radius: 500 studs.",
    "Spawn point: (2000, 5, 0). Travel Coordinator drops players here.",
    "Plot region: (2000, 0, 30). Same plot mechanic as Starter Glade.",
    "Wild mushroom spawn area: invisible BasePart, ~400×100×400 at (2000, 50, 0). Larger and denser than Starter Glade — Misty Hollow ships with cap=30 (vs 25) and respawn interval=6s (vs 8).",
    "Travel Coordinator anchor: (1985, 0, 0). A weathered wooden post under a small wooden roof to keep the rain off.",
    "No merchants in Misty Hollow. Players travel back to Starter Glade for shopping.",
    "Recommended hero element: a tall waterfall on one side of the hollow, ~50 studs tall, falling into a pool that flows into a small stream. Visible from the spawn pad. Anchors the biome's identity.",
]))

story.append(heading("Color palette", level=3))
story.extend(bullets([
    "Primary green: deep emerald (~RGB 60, 140, 90). Wet, saturated.",
    "Moss / undergrowth: blue-green (~RGB 80, 130, 110).",
    "Bark / dark elements: very dark wood (~RGB 40, 35, 30).",
    "Wet stone: cool grey-blue (~RGB 90, 100, 110).",
    "Highlight: pale rain-light (~RGB 200, 220, 210). Not warm at all.",
    "Water: deep cool blue-green (~RGB 40, 80, 95).",
]))

story.append(heading("Atmosphere / lighting", level=3))
story.extend(bullets([
    "Atmosphere density: 0.6 (vs Starter Glade's 0.3). Distant trees fade visibly.",
    "Ambient: cool green-blue (~RGB 80, 100, 95). OutdoorAmbient: same but lighter.",
    "ClockTime: NOT locked; follows the global cycle. But Misty Hollow's lighting feels overcast regardless.",
    "Brightness: 1.5 (slightly dimmer than Starter Glade's 1.6).",
    "Fog: heavy. FogStart 100, FogEnd 600.",
    "Rain particles continuously emit (VFX contractor handles this; you place anchor points).",
]))

story.append(heading("Foliage + props", level=3))
story.extend(bullets([
    "Tree density 2-3x Starter Glade. Many overlapping canopies.",
    "Tree types: tall conifers, ferns at the base, hanging vines from branches.",
    "Hanging moss + lichens on tree trunks.",
    "Glowing mushrooms scattered through the undergrowth — these are decorative; don't conflict with the gameplay-spawned wild mushrooms (which include Glowmoss as a rare wild here).",
    "Mossy rocks in clusters along the stream / waterfall.",
    "Small wooden plank bridge over the stream.",
    "Decorative giant ferns (5+ studs tall) clustered in low-traffic areas.",
    "Lily pads on any standing water.",
]))

# ----- FROSTROOT PASS -----
story.append(PageBreak())
story.append(heading("3. Frostroot Pass", level=1))
story.append(P("Status: Phase 4. Unlock: Reputation 300. The 'high difficulty' biome — players grind here for high-value rare species."))

story.append(heading("Identity + mood", level=3))
story.append(P(
    "A snow-covered mountain pass between two peaks. Cold, quiet, "
    "spectacular. The wind blows constantly (visible in particle effects). "
    "Patches of bare rock and dark earth visible under thin snow. A few "
    "hardy alpine plants poke through. Players feel small here — the "
    "mountains tower around them. This biome's reward is in the rare "
    "mushroom species that only grow in cold; the punishment is slow "
    "growth times and a sparser, less welcoming environment than the "
    "lower biomes."
))
story.append(P("Visual references:"))
story.extend(bullets([
    "Studio Ghibli — the alpine scenes in Howl's Moving Castle.",
    "Skyrim — the high passes in Whiterun Hold.",
    "Real-world: Yukon, Patagonia, the Swiss Alps in late autumn (snow but not full winter).",
]))

story.append(heading("Spatial layout", level=3))
story.extend(bullets([
    "Zone center: (4000, 0, 0). Zone radius: 500 studs. (Coordinates may shift; coordinate with the scripter when this biome ships.)",
    "Spawn point near the entrance to the pass; players walk in between two large rock walls that funnel them into the open valley.",
    "Plot region: snow-covered patches of soil. Players will need to clear snow before planting (mechanic TBD; for now, just visual snow on top of soil).",
    "Wild mushroom spawn area: smaller than Misty Hollow (cap ~20). Frostroot's species are inherently rare; the world feels emptier on purpose.",
    "Hero element: the pass itself. Two mountain walls towering on either side, framing a distant snow-capped peak.",
]))

story.append(heading("Color palette", level=3))
story.extend(bullets([
    "Snow: clean white (~RGB 240, 245, 250). Slight blue tint.",
    "Bare rock: dark grey (~RGB 80, 85, 95).",
    "Sparse foliage: dark evergreen (~RGB 40, 70, 50).",
    "Sky: pale grey-blue, almost white at the horizon.",
    "Highlight: cold blue (~RGB 180, 210, 240) for shadowed snow + ice.",
    "Bare earth: nearly black (~RGB 50, 40, 35).",
]))

story.append(heading("Atmosphere / lighting", level=3))
story.extend(bullets([
    "Atmosphere density: 0.4. Cold rather than misty.",
    "ClockTime: midday (~12:00) — sun high, no warm glow.",
    "Ambient: cold blue-white. OutdoorAmbient: bright but cold.",
    "Brightness: 2.0 (snow reflects everything).",
    "Wind particle effect (snow drifting horizontally) constant.",
]))

story.append(heading("Foliage + props", level=3))
story.extend(bullets([
    "Sparse trees: bare deciduous + sparse pines, snow-laden branches.",
    "Boulders: large grey boulders, partly snow-covered.",
    "Frozen stream — narrow blue ribbon across the valley.",
    "Few buildings: maybe one abandoned shelter (a small cabin) near the spawn for ambient narrative.",
    "Decorative ice mushrooms — translucent crystalline shapes, much rarer than other biomes' decorative mushrooms.",
]))

# ----- SUNKEN GROVE -----
story.append(PageBreak())
story.append(heading("4. Sunken Grove", level=1))
story.append(P("Status: Phase 4. Unlock: Reputation 600. The 'weird' biome — alchemy ingredients, atypical mushroom shapes, unsettling-but-not-scary aesthetic."))

story.append(heading("Identity + mood", level=3))
story.append(P(
    "A lowland swamp. Murky water, cypress-like trees with knotted roots "
    "growing out of the water, hanging Spanish moss, fireflies at night. "
    "The biome that's ALMOST creepy but pulls back into wonder — Princess "
    "Mononoke's spirit forest, or the Bayou levels in classic platformers. "
    "Players feel like they're walking through someone else's home, with "
    "all the weird beauty that implies. This is the alchemy ingredient "
    "biome; mushrooms here are weird-looking but valuable."
))
story.append(P("Visual references:"))
story.extend(bullets([
    "Studio Ghibli — the spirit forest in Princess Mononoke (the kodama scenes).",
    "Real-world: Louisiana / Florida cypress swamps, Okefenokee.",
    "Bee Swarm — cricket-sound-heavy ambient zones.",
]))

story.append(heading("Spatial layout", level=3))
story.extend(bullets([
    "Zone center: (6000, 0, 0). Zone radius: 500 studs.",
    "Hero element: A central pool of murky water, ~80 studs across, with twisted cypress trees rising from it. A wooden walkway loops around the pool.",
    "Plot region: planters built INTO the wooden walkway (raised plots). Soil is permanently moist. Visual contrast: the only dry land in the biome.",
    "Spawn point: at the edge of the wooden walkway entrance.",
    "Wild mushroom spawn: among the cypress roots in the central pool area.",
]))

story.append(heading("Color palette", level=3))
story.extend(bullets([
    "Primary: murky green-brown (~RGB 90, 110, 70). The water color.",
    "Wood / walkways: dark weathered brown (~RGB 70, 55, 40).",
    "Spanish moss: pale grey-green (~RGB 150, 165, 140).",
    "Highlight: firefly yellow-green (~RGB 200, 230, 130).",
    "Cypress bark: very dark brown, nearly black (~RGB 50, 40, 35).",
    "Atmospheric mist: pale grey (~RGB 180, 180, 175).",
]))

story.append(heading("Atmosphere / lighting", level=3))
story.extend(bullets([
    "Atmosphere density: 0.7 (densest biome). Distant trees fade quickly.",
    "ClockTime: dusk (~17:30). Always-evening feel.",
    "Ambient: warm-leaning amber (the dying light of the sun reflects off the still water).",
    "Brightness: 1.2 (dimmest biome). The mood is moody.",
    "Fireflies emitting throughout (VFX).",
]))

# ----- OLD GROWTH -----
story.append(PageBreak())
story.append(heading("5. Old Growth", level=1))
story.append(P("Status: Phase 4. Unlock: Reputation 1500. The 'awe' biome — massive ancient trees, legendary species."))

story.append(heading("Identity + mood", level=3))
story.append(P(
    "An ancient forest where the trees are 100+ studs tall and so wide a "
    "player could fit inside the bole. Sunlight filters down in pillars "
    "through the canopy. Player feels small but reverent. This is the "
    "biome that sells the game's 'wonder' — players who reach this point "
    "have invested time, and Old Growth rewards that investment with "
    "scale that feels mythic."
))
story.append(P("Visual references:"))
story.extend(bullets([
    "Real-world: California redwoods (Muir Woods, Redwood National Park).",
    "Studio Ghibli — Princess Mononoke's deeper forest scenes (the ancient ones).",
    "Lord of the Rings — Lothlórien (without the elven architecture).",
]))

story.append(heading("Spatial layout", level=3))
story.extend(bullets([
    "Zone center: (8000, 0, 0). Zone radius: 500 studs.",
    "Hero element: 6-10 GIANT trees (100+ studs tall, 20+ studs wide trunks). Player walks BETWEEN them; they form natural rooms.",
    "Wooden plank bridges between the larger tree branches at high elevation. Optional player-traversable, with railings.",
    "Hidden hollow at the base of the largest tree — small interior space, possibly a quest hub. NPC: the Spirit Speaker.",
    "Light pillars: sunbeams cutting through the canopy at angles. Use Beam parts.",
    "Spawn point near the entrance, looking up into the canopy.",
]))

story.append(heading("Color palette", level=3))
story.extend(bullets([
    "Primary: deep forest green (~RGB 50, 100, 60). Saturated; this is healthy old growth.",
    "Tree bark: rich red-brown (~RGB 110, 75, 55). Redwood-inspired.",
    "Sunlight pillars: warm gold (~RGB 250, 220, 160).",
    "Shadow: deep cool teal (~RGB 30, 60, 70).",
    "Moss: bright fresh green (~RGB 110, 160, 90).",
]))

story.append(heading("Atmosphere / lighting", level=3))
story.extend(bullets([
    "Atmosphere density: 0.5. Atmospheric perspective shows tree silhouettes fading into the distance.",
    "ClockTime: late afternoon (~16:00). The golden-hour lighting that makes redwoods spectacular.",
    "Ambient: warm green-gold.",
    "Brightness: 1.8.",
    "Drifting pollen + mote particles in the light pillars (VFX).",
]))

# ----- GLIMMERWOOD -----
story.append(PageBreak())
story.append(heading("6. Glimmerwood", level=1))
story.append(P("Status: Phase 4. Unlock: Reputation 2500 + lunar quest completion. Night-only / lunar-active. The bioluminescent biome — visually distinct from every other."))

story.append(heading("Identity + mood", level=3))
story.append(P(
    "A forest where every plant glows. Players visit this biome only at "
    "night (or during lunar events); the daytime version of this place "
    "looks dim and unimpressive — the magic activates after sundown. "
    "Glowing mushrooms cluster in fairy rings. Glowing pollen drifts "
    "through the air. The whole biome feels enchanted in the most "
    "literal sense. Most visually distinct biome — Glimmerwood is the "
    "screenshot biome players will share."
))
story.append(P("Visual references:"))
story.extend(bullets([
    "Avatar (the Pandora forest scenes — but warmer-toned, less alien).",
    "Studio Ghibli — Pom Poko's spirit-night scenes.",
    "Real-world: bioluminescent algae in tropical bays at night.",
]))

story.append(heading("Spatial layout", level=3))
story.extend(bullets([
    "Zone center: (10000, 0, 0). Zone radius: 500 studs.",
    "Hero element: dense clusters of glowing mushrooms in fairy-ring patterns. Some rings are walkable; some have ambient effects when crossed.",
    "Floating particles: glowing pollen, small light orbs (firefly-like, larger and more ethereal).",
    "Trees: pale-bark trees with hanging luminescent vines.",
    "Small reflective pools that catch the bioluminescent light.",
]))

story.append(heading("Color palette", level=3))
story.extend(bullets([
    "Primary: deep dark blue (~RGB 20, 30, 60). Night sky color.",
    "Bioluminescent accents: vibrant cyan-green (~RGB 100, 240, 200).",
    "Pollen / dust: pale lavender (~RGB 180, 160, 220).",
    "Tree bark: pale ash-grey (~RGB 200, 195, 200).",
    "Reflective water: deep purple-blue with cyan highlights.",
]))

story.append(heading("Atmosphere / lighting", level=3))
story.extend(bullets([
    "Atmosphere density: 0.4. Mist still present but not heavy.",
    "ClockTime: locked to night. ClockTime = 22 (10pm).",
    "Ambient: very dark blue.",
    "Brightness: 0.4 (very dim — the biome's light comes from emissive mushrooms, not from the sky).",
    "Heavy use of PointLights + Neon material on mushrooms + emissive textures.",
]))

# ----- LOST CATHEDRAL -----
story.append(PageBreak())
story.append(heading("7. Lost Cathedral", level=1))
story.append(P("Status: Phase 4. Event-based unlock. The mythic biome — appears during seasonal events, hosts mythic species."))

story.append(heading("Identity + mood", level=3))
story.append(P(
    "A ruined cathedral / temple deep in the woods, slowly being reclaimed "
    "by nature. Stone walls covered in moss and ivy. Trees growing "
    "through gaps in the floor and roof. Pillars of light through holes "
    "in the ceiling. Wonder-leaning, never threatening. This is where "
    "mythic species spawn during community events; the biome itself "
    "carries narrative weight even when no event is active. Sacred + "
    "abandoned + reclaimed by life."
))
story.append(P("Visual references:"))
story.extend(bullets([
    "Angkor Wat / Ta Prohm — the trees growing through ancient temple walls.",
    "Studio Ghibli — Castle in the Sky's central temple.",
    "Old Growth meets architecture.",
]))

story.append(heading("Spatial layout", level=3))
story.extend(bullets([
    "Zone center: (12000, 0, 0). Zone radius: 500 studs.",
    "Central building: ruined cathedral / temple. ~80 studs long, ~30 studs wide, partial roof. Player can enter freely.",
    "Inside: an altar at the far end. The altar is the spawn point for mythic species during events.",
    "Outside: a small courtyard with overgrown stone benches, statue fragments, vines crawling up the walls.",
    "Surrounding forest: dense old-growth trees, pressing in.",
]))

story.append(heading("Color palette", level=3))
story.extend(bullets([
    "Stone: pale weathered limestone (~RGB 200, 195, 180).",
    "Moss: vibrant green covering the stone (~RGB 90, 140, 70).",
    "Ivy / vines: dark green (~RGB 50, 90, 50).",
    "Light pillars: warm gold from above.",
    "Shadow stone: deep grey-purple in the unlit interior.",
]))

story.append(heading("Atmosphere / lighting", level=3))
story.extend(bullets([
    "Atmosphere density: 0.5.",
    "ClockTime: late afternoon (~17:00). Long shadows from the broken roof.",
    "Ambient: warm golden where lit, deep cool grey in the unlit interior. Strong contrast.",
    "Brightness: 1.6 outside; effective brightness much lower inside the ruins.",
    "Light pillars from holes in the roof — strong Beam effects.",
]))

# Shared elements
story.append(PageBreak())
story.append(heading("Shared world elements", level=1))
story.append(P(
    "These are NOT biome-specific — they appear across multiple biomes "
    "and need a unified design language."
))

story.append(heading("Trading Post (Phase 2)", level=2))
story.append(P(
    "A central marketplace building inside the Starter Glade biome (or in "
    "its own dedicated zone if we run out of room — coordinate with the "
    "scripter). Players gather here to trade with each other. Should feel "
    "warm, communal, lived-in. Not a sterile shopping mall."
))
story.append(P("Spatial layout:"))
story.extend(bullets([
    "A central pavilion: covered open-air structure with a stone floor and timber roof. ~30 studs across.",
    "Surrounding the pavilion: 12-16 small rentable stalls. Each is a wooden booth ~6 studs across with a counter facing inward toward the pavilion. Players can rent these and decorate them.",
    "Trading Post Manager NPC: at the entrance to the pavilion. Greets new visitors.",
    "Atmosphere: warm interior lighting (oil lamps), even at midday. Should feel cozy.",
    "Visual reference: medieval trading squares, Moroccan souks, Stardew Valley's Saloon.",
]))

story.append(heading("Player Hut interiors (Phase 3)", level=2))
story.append(P(
    "Each player owns a small hut. The interior is instanced (separate "
    "RoomService space). Players decorate it with items they've earned. "
    "Build ONE prefab interior; the engine instances it per-player."
))
story.extend(bullets([
    "Size: ~12×10 stud single-room interior.",
    "Default elements: a personal cauldron, a personal storage chest, a spirit display shelf, several decoration anchor points (slots where players can place their decoration items).",
    "Style: cozy cabin / cottage interior. Wood beams, stone fireplace, wooden floor, small windows.",
    "Should feel customizable — a blank canvas with a few default items the player can move around or replace.",
]))

story.append(heading("Forest Spirit Models (placeable across all biomes)", level=2))
story.append(P(
    "6 spirit creature Models (Phase 1, plus 1 Legendary Phase 4). These "
    "are pet-style companions players collect and equip; they wander near "
    "the player's hut. The scripter handles the animation / wander AI; "
    "you supply rigged Models with idle + walk animations."
))
story.extend(bullets([
    "Mossling — small mossy round creature. Soft green glow. ~2 studs tall.",
    "Spritefly — tiny winged sprite, blue-white particle trail. ~1.5 studs tall, hovers.",
    "Dewdrop — translucent water-drop creature, semi-blob. ~2 studs tall.",
    "Lanternfox — fox-like creature with a glowing tail tip. ~3 studs tall.",
    "Crystalmoth — moth with crystalline wings. ~3 studs wingspan.",
    "Deerlet — tiny deer with antlers like coral. ~3 studs tall.",
    "Forest Mother (Phase 4 / Legendary) — stag-like figure with antlers wreathed in glowing leaves. Large; ~10 studs tall.",
]))

story.append(heading("Decorative mushrooms (across all biomes)", level=2))
story.append(P(
    "These are visual-only mushrooms you place around the world. They are "
    "NOT the gameplay-spawned wild mushrooms. They should look distinctly "
    "different so players don't confuse them with harvestables. Use:"
))
story.extend(bullets([
    "3-5x scale of normal mushrooms.",
    "Atypical shapes: lattice-textured, jelly-soft, clustered like coral, or tall and bell-shaped.",
    "Strong colors that don't match any wild species' palette.",
    "Per-biome variants (snowy mushrooms in Frostroot, glowing in Glimmerwood, swamp-fungal in Sunken Grove).",
]))

story.append(heading("Travel transitions between biomes", level=2))
story.append(P(
    "Players travel between biomes via the Travel Coordinator NPC; the "
    "scripter handles the actual teleport. But the SPACE BETWEEN biomes "
    "(2000-stud-wide gaps) should feel natural rather than empty. Suggestions:"
))
story.extend(bullets([
    "Sparse trees + winding paths in the transition zones.",
    "Visible signs / markers indicating the direction of each biome.",
    "Subtle environmental gradient — the transition zone between Starter Glade and Misty Hollow should slowly become wetter and mossier, hinting at what's ahead.",
    "Don't fill the gaps with high-detail content. Players are streamed out of these zones quickly.",
]))

# Deliverables
story.append(PageBreak())
story.append(heading("Deliverables expected (in priority order)", level=1))
story.append(P(
    "These are the build deliverables. Phase priority matches the project's "
    "ROADMAP — earlier phases are more urgent."
))

deliverables_table = [
    ["#", "Deliverable", "Phase", "Notes"],
    ["1", "Starter Glade hand-built terrain + props + witch's cave + pond", "Pre-Alpha (now)", "Highest priority — first impression"],
    ["2", "Misty Hollow hand-built terrain + props + waterfall hero", "Phase 1 (now)", "Travel UX depends on this feeling distinct"],
    ["3", "6 Forest Spirit Models, rigged + animated (idle + walk)", "Phase 1", "Scripter wires; spirits invisible until Models exist"],
    ["4", "Trading Post pavilion + 12-16 rentable stalls", "Phase 2", "Required for player trading economy"],
    ["5", "Player hut interior prefab", "Phase 3", "Single Model, instanced per player"],
    ["6", "Frostroot Pass biome", "Phase 4", "Snow / mountain pass aesthetic"],
    ["7", "Sunken Grove biome", "Phase 4", "Swamp / cypress / firefly aesthetic"],
    ["8", "Old Growth biome", "Phase 4", "Massive trees / scale / awe"],
    ["9", "Glimmerwood biome", "Phase 4", "Bioluminescent / night-only"],
    ["10", "Lost Cathedral biome", "Phase 4", "Ruined temple / mythic event hub"],
    ["11", "1 Legendary spirit Model: Forest Mother", "Phase 4", "Larger; lunar event spawn"],
]
story.append(table(deliverables_table, [0.3 * inch, 3.0 * inch, 1.0 * inch, 2.5 * inch]))
story.append(Spacer(1, 8))

# Style refs section
story.append(heading("Master style references", level=2))
story.append(P(
    "When a design choice feels ambiguous, fall back to the locked-in "
    "references below. These are the project's north stars."
))
story.extend(bullets([
    "Studio Ghibli films — particularly Princess Mononoke, Howl's Moving Castle, and Whisper of the Heart for forest atmospheres.",
    "Stardew Valley — for the cozy + warm + slightly-faded color palette.",
    "Bee Swarm Simulator — for Roblox-specific landmark clarity at mobile thumbnail size.",
    "Adopt Me! — for the cozy aesthetic that retains kid-friendly readability without being saccharine.",
    "Don't Starve (artistically; not tonally — DS is dark; we're cozy) — for hand-painted texture qualities.",
    "Cottagecore visual aesthetic boards (Pinterest, Instagram) for general mood.",
]))

# Coordination notes
story.append(heading("Coordinating with the scripter", level=2))
story.append(P(
    "World designer + scripter are separate roles. Tight coordination on:"
))
story.extend(bullets([
    "Spawn point coordinates per biome (locked in src/shared/Constants.luau Constants.BIOMES). The world designer must not move these without coordinating; the scripter teleports players to those exact coordinates.",
    "Wild spawn area BasePart per biome. Designer creates an invisible BasePart matching the per-biome size, names it per the spec (e.g., WildSpawnArea_StarterGlade), and parents it under Workspace.Biomes.<biomeId>. Scripter spawns mushrooms inside it at runtime.",
    "Plot region per biome. Designer creates a marker (a small Folder named PlotArea) at the biome's plotOrigin. Scripter places plot Models in a row from there.",
    "NPC anchor positions. Designer places marker Parts where each NPC should stand. Scripter parents the NPC Models there at runtime.",
    "BuiltManually attribute on each biome's Workspace.Biomes.<biomeId> Folder. Set to true once the biome is hand-built; this stops the scripter's procedural fallback from overwriting your work.",
]))

story.append(heading("Final notes for designers", level=2))
story.extend(bullets([
    "Mycelia targets a multi-year operational lifecycle (Bee Swarm-tier longevity). Build for 5+ years of player time in this world; investing in detail pays back over months.",
    "Mobile-first: every important visual must read at 6.1\" phone screen size in motion. Test on a phone before committing to detail-level decisions.",
    "Pace matters: don't pack every square stud with detail. Give the eye places to rest. Empty meadow areas + dense detail clusters = good. Wall-to-wall props = bad.",
    "When in doubt, lean cozier and less complicated. Mycelia's competitive advantage is being uncontested in this aesthetic on Roblox; don't drift toward the visual conventions of Bee Swarm or Adopt Me.",
    "Reference the project's design doc at docs/DESIGN.md for the broader project vision; this brief covers world build specifically.",
]))

# ---------- Build --------------------------------------------------------

for path in OUTPUT_PATHS:
    doc = SimpleDocTemplate(
        path,
        pagesize=letter,
        leftMargin=0.85 * inch,
        rightMargin=0.85 * inch,
        topMargin=0.85 * inch,
        bottomMargin=0.85 * inch,
        title="Mycelia - World Design Brief",
        author="RabidGunter",
    )
    # SimpleDocTemplate.build mutates the story in place; rebuild a copy
    # for the second output. Easiest: re-import a fresh story by rerunning
    # this script — but we already have story populated, so deepcopy.
    import copy
    doc.build(copy.deepcopy(story))
    print(f"Wrote {path}")
