--!strict
-- DisturbanceServiceEmissionLogic
--
-- Implements: production/epics/ecological-disturbance/story-002-emission-schema-emit-intake.md
-- GDD: design/gdd/ecological-disturbance.md -- C.1.2 (EmissionPayload 7-field schema,
--      published Luau types, NaN/Infinity isFinite idiom E.16), C.1.8 ("No client-callable
--      emission path" -- this module has no Client-reachable surface at all), C.3.6 (Beacon
--      reserved-magnitude band)
-- ADR: docs/architecture/adr-0004-disturbanceservice-core-architecture.md -- governs Emit()'s
--      server-internal-only status via GDD C.1.8's "no client-callable emission path" rule
--      (control-manifest.md Core-layer Forbidden pattern). NOTE (code review correction): this
--      ADR's own "Public surface (server-internal, non-.Client)" bullet list does NOT actually
--      enumerate Emit() (confirmed via grep -- zero matches for "Emit" anywhere in the ADR) --
--      this story's own Context section is the correct citation for Emit()'s exact signature,
--      not ADR-0004's diagram. A future ADR-0004 touch could add Emit() to that list for
--      traceability completeness; not done here since this file doesn't edit ADRs.
--
-- Pure domain logic for DisturbanceService:Emit()'s schema validation and EmissionPayload
-- construction. Deliberately has ZERO dependency on Knit, any Roblox service call, OR any
-- require() at all (mirrors DisturbanceServiceBootstrapLogic's own zero-require precedent from
-- Story 001) -- `now` (the sampled workspace:GetServerTimeNow() value) and `emissionId` (the
-- sampled HttpService:GenerateGUID(false) value) are both EXPLICIT PARAMETERS, injected by the
-- DisturbanceService:Emit() Knit-wrapper -- never read from a global clock/GUID API inside this
-- module. This is what makes H.7b's "only workspace:GetServerTimeNow() may be the clock source"
-- AC provable two ways: (1) a static grep of THIS file for os%.time/tick%(/os%.clock finds zero
-- matches (this file never touches a clock API at all, injected or otherwise -- it doesn't even
-- know one exists), and (2) tests can inject any fake `now` directly, with no monkey-patching
-- required.
--
-- NOTE (harness-driven scope call, approved 2026-07-06): BEACON_MAGNITUDE_RESERVED_BOUNDARY
-- (0.85) and ATTRIBUTION_CHAIN_MAX_LENGTH (4) are kept as LOCAL constants below rather than
-- published in DisturbanceConstants.luau. Both values are schema-fixed per GDD C.1.2's own
-- prose (not listed as G.x designer-tunable knobs), and requiring DisturbanceConstants here
-- would need `require(script.Parent.DisturbanceConstants)`, which tests/run_tests.lua's
-- load_luau_file() harness cannot resolve today (loadstring-executed modules are never given a
-- `script` global -- only DisturbanceService.luau uses that require path, and it is never
-- instantiated under this harness, only source-text-checked). Keeping this module require()-
-- free avoids that landmine entirely and matches Story 001's own BootstrapLogic precedent.
--
-- DisturbanceService.luau is a thin Knit wrapper around this module's ValidateAndBuildEmission
-- function -- it owns the real workspace:GetServerTimeNow()/HttpService:GenerateGUID(false)
-- call sites, the live-source-list insertion, and the game-facing warn() call site; this module
-- owns only the actual validation/construction logic and never inserts anything itself.

export type EmissionType = "Gather" | "Sprint" | "Light" | "Beacon" | "Craft"

export type EmissionPayload = {
	emissionId: string,
	sourcePlayerId: number,
	emissionType: EmissionType,
	position: Vector3,
	initialMagnitude: number,
	emissionTime: number,
	attributionChain: { string },
}

export type EmissionRejectionReason =
	"missing-field"
	| "invalid-emission-type"
	| "non-finite-value"
	| "non-positive-magnitude"
	| "beacon-below-reserved-band"
	| "non-beacon-above-reserved-band"
	| "attribution-chain-too-long"

--- H.2/H.3/H.3b/H.3c/H.6/H.6b's rejection detail -- the Knit wrapper's warn() call site formats
--- this into the "server-side error log entry" the ACs require, identifying the offending field.
export type EmissionRejection = {
	reason: EmissionRejectionReason,
	field: string,
	sourcePlayerId: number?,
	emissionType: string?,
}

local DisturbanceServiceEmissionLogic = {}

-- GDD C.1.2: "attributionChain ... length <= 4 ... Length-cap is a runtime validation (not a
-- Luau type constraint)." Schema-fixed, not a G.x tuning knob -- see this file's header note.
local ATTRIBUTION_CHAIN_MAX_LENGTH = 4

-- GDD C.1.2: "initialMagnitude ... values above 0.85 are reserved for Beacon" (strict '>', so
-- 0.85 itself is the SHARED boundary value -- legal for both Beacon (>= 0.85) and non-Beacon
-- (<= 0.85); resolved explicitly per this story's own H.6 edge-case instruction, approved
-- 2026-07-06). Schema-fixed, not a G.x tuning knob -- see this file's header note.
local BEACON_MAGNITUDE_RESERVED_BOUNDARY = 0.85

local VALID_EMISSION_TYPES: { [string]: boolean } = {
	Gather = true,
	Sprint = true,
	Light = true,
	Beacon = true,
	Craft = true,
}

--- E.16's required NaN/Infinity detection idiom (GDD-verbatim, per this story's Implementation
--- Notes -- use verbatim, do not alter).
local function isFinite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

--- Validates and constructs an EmissionPayload from the seven conceptual EmissionPayload fields
--- (GDD C.1.2). `now` and `emissionId` are injected by the caller (the DisturbanceService:Emit()
--- Knit wrapper samples workspace:GetServerTimeNow() and HttpService:GenerateGUID(false)
--- respectively, THEN calls this function) -- see this module's header comment for why.
---
--- Parameter types are deliberately permissive (`string?` for emissionType, not `EmissionType?`)
--- because this function's entire purpose is validating externally-sourced values that have not
--- yet been proven to match the schema -- a real caller narrows/asserts the type only AFTER this
--- function accepts the value.
---
--- Returns (payload, nil) on success, or (nil, rejection) on rejection. Never inserts anything
--- itself and never errors -- DisturbanceService:Emit() owns the actual live-source-list
--- insertion (Story 003 owns spatial-grid cell placement; Story 004 owns the attribution archive
--- entry -- both explicitly out of this story's scope).
function DisturbanceServiceEmissionLogic.ValidateAndBuildEmission(
	emissionType: string?,
	position: Vector3?,
	initialMagnitude: number?,
	sourcePlayerId: number?,
	attributionChain: { string }?,
	now: number?,
	emissionId: string?
): (EmissionPayload?, EmissionRejection?)
	-- H.2: all seven fields required, checked in GDD C.1.2's own canonical field-table order.
	if emissionId == nil then
		return nil, { reason = "missing-field", field = "emissionId", sourcePlayerId = sourcePlayerId, emissionType = emissionType }
	end
	if sourcePlayerId == nil then
		return nil, { reason = "missing-field", field = "sourcePlayerId", sourcePlayerId = sourcePlayerId, emissionType = emissionType }
	end
	if emissionType == nil then
		return nil, { reason = "missing-field", field = "emissionType", sourcePlayerId = sourcePlayerId, emissionType = emissionType }
	end
	if position == nil then
		return nil, { reason = "missing-field", field = "position", sourcePlayerId = sourcePlayerId, emissionType = emissionType }
	end
	if initialMagnitude == nil then
		return nil, { reason = "missing-field", field = "initialMagnitude", sourcePlayerId = sourcePlayerId, emissionType = emissionType }
	end
	if now == nil then
		return nil, { reason = "missing-field", field = "emissionTime", sourcePlayerId = sourcePlayerId, emissionType = emissionType }
	end
	if attributionChain == nil then
		return nil, { reason = "missing-field", field = "attributionChain", sourcePlayerId = sourcePlayerId, emissionType = emissionType }
	end

	-- H.3c: emissionType must be an EXACT, case-sensitive match against the canonical enum.
	if not VALID_EMISSION_TYPES[emissionType] then
		return nil, { reason = "invalid-emission-type", field = "emissionType", sourcePlayerId = sourcePlayerId, emissionType = emissionType }
	end

	-- H.3b: NaN/Infinity rejection on every position axis, then on initialMagnitude.
	if not isFinite(position.X) then
		return nil, { reason = "non-finite-value", field = "position.X", sourcePlayerId = sourcePlayerId, emissionType = emissionType }
	end
	if not isFinite(position.Y) then
		return nil, { reason = "non-finite-value", field = "position.Y", sourcePlayerId = sourcePlayerId, emissionType = emissionType }
	end
	if not isFinite(position.Z) then
		return nil, { reason = "non-finite-value", field = "position.Z", sourcePlayerId = sourcePlayerId, emissionType = emissionType }
	end
	if not isFinite(initialMagnitude) then
		return nil, { reason = "non-finite-value", field = "initialMagnitude", sourcePlayerId = sourcePlayerId, emissionType = emissionType }
	end

	-- H.3: initialMagnitude must be strictly positive.
	if initialMagnitude <= 0 then
		return nil, { reason = "non-positive-magnitude", field = "initialMagnitude", sourcePlayerId = sourcePlayerId, emissionType = emissionType }
	end

	-- H.6 / H.6b: the Beacon reserved-magnitude band. 0.85 itself is the SHARED boundary --
	-- legal for both Beacon (>= 0.85) and non-Beacon (<= 0.85).
	if emissionType == "Beacon" then
		if initialMagnitude < BEACON_MAGNITUDE_RESERVED_BOUNDARY then
			return nil,
				{
					reason = "beacon-below-reserved-band",
					field = "initialMagnitude",
					sourcePlayerId = sourcePlayerId,
					emissionType = emissionType,
				}
		end
	else
		if initialMagnitude > BEACON_MAGNITUDE_RESERVED_BOUNDARY then
			return nil,
				{
					reason = "non-beacon-above-reserved-band",
					field = "initialMagnitude",
					sourcePlayerId = sourcePlayerId,
					emissionType = emissionType,
				}
		end
	end

	-- Runtime attributionChain length cap (GDD C.1.2: "length <= 4" -- not a Luau type
	-- constraint).
	if #attributionChain > ATTRIBUTION_CHAIN_MAX_LENGTH then
		return nil,
			{
				reason = "attribution-chain-too-long",
				field = "attributionChain",
				sourcePlayerId = sourcePlayerId,
				emissionType = emissionType,
			}
	end

	local payload: EmissionPayload = {
		emissionId = emissionId,
		sourcePlayerId = sourcePlayerId,
		emissionType = emissionType :: EmissionType,
		position = position,
		initialMagnitude = initialMagnitude,
		emissionTime = now,
		attributionChain = attributionChain,
	}

	return payload, nil
end

return DisturbanceServiceEmissionLogic
