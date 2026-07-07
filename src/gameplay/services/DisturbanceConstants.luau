--!strict
-- DisturbanceConstants
--
-- Implements: production/epics/ecological-disturbance/story-001-constants-bootstrap-field-update-loop.md
-- GDD: design/gdd/ecological-disturbance.md -- G.1-G.5 (every G-section tuning knob)
--
-- Single source of truth for every Ecological Disturbance tuning knob. No other file in
-- this service may hardcode a literal duplicating any value published here
-- (coding-standards.md: "Gameplay values must be data-driven").
--
-- SCOPE NOTE (Story 001): this module ONLY publishes constants. It does not validate them
-- (that's DisturbanceServiceBootstrapLogic's job, called from DisturbanceService:KnitInit())
-- and does not consume them (later stories, 002-017, do).

local DisturbanceConstants = {}

-- ============================================================================
-- G.1 -- Tier thresholds & hysteresis
-- ============================================================================
DisturbanceConstants.TENSE_THRESHOLD = 0.30
DisturbanceConstants.HUNT_THRESHOLD = 0.65
DisturbanceConstants.HYSTERESIS_BAND = 0.03

-- ============================================================================
-- G.2 -- Decay
-- ============================================================================
DisturbanceConstants.STANDARD_HALF_LIFE = 30 -- seconds
DisturbanceConstants.BEACON_HALF_LIFE = 90 -- seconds
DisturbanceConstants.MAGNITUDE_FLOOR = 0.02

-- ============================================================================
-- G.3 -- Spatial / field-update cadence
-- ============================================================================
DisturbanceConstants.INFLUENCE_RADIUS = 24 -- studs
DisturbanceConstants.HOTSPOT_DEDUP_GRID_SIZE = 4
DisturbanceConstants.SPATIAL_GRID_CELL_SIZE = 32 -- studs; G.7 invariant: >= INFLUENCE_RADIUS
DisturbanceConstants.FIELD_UPDATE_HZ = 5

-- ============================================================================
-- G.4 -- Flora / chunk streaming / archive
-- ============================================================================
DisturbanceConstants.FLORA_UPDATE_DELTA_THRESHOLD = 0.02
DisturbanceConstants.EXPIRY_MAINTENANCE_INTERVAL = 3 -- seconds
DisturbanceConstants.MAX_LIVE_SOURCES = 500
DisturbanceConstants.ATTRIBUTION_ARCHIVE_TTL = 1200 -- seconds
DisturbanceConstants.MAX_ATTRIBUTION_ARCHIVE_ENTRIES = 4000
DisturbanceConstants.MAX_FLORA_PER_CHUNK = 8
DisturbanceConstants.CHUNK_DIMENSIONS = 64 -- studs

-- ============================================================================
-- G.5 -- Per-Emission-Type Magnitudes (D.7)
-- ============================================================================
DisturbanceConstants.MAGNITUDE_GATHER_LIGHT = 0.15
DisturbanceConstants.MAGNITUDE_GATHER_MEDIUM = 0.25
DisturbanceConstants.MAGNITUDE_GATHER_HEAVY = 0.40
DisturbanceConstants.MAGNITUDE_SPRINT_PULSE = 0.10
DisturbanceConstants.MAGNITUDE_LIGHT_PULSE = 0.08
DisturbanceConstants.SPRINT_HOLD_FLOOR = 0.09
DisturbanceConstants.MAGNITUDE_BEACON = 0.95
DisturbanceConstants.SPRINT_PULSE_INTERVAL = 2 -- seconds
DisturbanceConstants.LIGHT_PULSE_INTERVAL = 4 -- seconds
DisturbanceConstants.EMITTER_MOVEMENT_DELTA_FLOOR = 1 -- studs
DisturbanceConstants.STATIONARY_EMISSION_FACTOR = 0.30
DisturbanceConstants.FIRST_PULSE_GRACE_WINDOW = 1.0 -- seconds
DisturbanceConstants.BEACON_STATIONARY_PROXIMITY_RADIUS = 16 -- studs
DisturbanceConstants.BEACON_CUMULATIVE_DISTANCE_THRESHOLD = 6.0 -- studs; PROVISIONAL pending iPhone SE drift measurement (GDD G.5)
DisturbanceConstants.BEACON_STATIONARY_WINDOW = 3.0 -- seconds
DisturbanceConstants.BEACON_STATIONARY_CAP_FIELD_VALUE = 0.65
DisturbanceConstants.PREDATOR_LOCK_RELEASE_GRACE_WINDOW = 5.0 -- seconds
DisturbanceConstants.SQUAD_T_FAIL_FLOOR_THRESHOLD = 0.28

return DisturbanceConstants
