--!strict
-- DisturbanceServiceRegistrationHandshake
--
-- Implements: production/epics/ecological-disturbance/story-001-constants-bootstrap-field-update-loop.md
--             (KnitInit-time require() acquisition ONLY -- see SCOPE NOTE below)
-- ADR: docs/architecture/adr-0001-knit-lifecycle-ordering-discipline.md (Rule 2 --
--      RegistrationHandshake module-private require() pattern for the one class of live
--      cross-service subscription where neither side can assume KnitStart ordering)
--      docs/architecture/adr-0004-disturbanceservice-core-architecture.md (Architecture
--      Diagram -- RegisterPredatorLockChangedSignal / ReleasePredatorLock exports)
--
-- SCOPE NOTE (Story 001): this module is a PLACEHOLDER. Story 011 owns its real exports
-- (RegisterPredatorLockChangedSignal(signal), ReleasePredatorLock(predatorId)). This story's
-- only obligation (per its own Out of Scope list) is that DisturbanceService's KnitInit
-- successfully require()s a module at this path -- the module's actual surface is
-- intentionally empty until Story 011 lands. Not a story deliverable named in the story file
-- itself, but required by the AC's own "the RegistrationHandshake module reference
-- (require() the module...)" line -- see the gameplay-programmer's implementation report for
-- this call-out.
--
-- Per ADR-0001 Rule 2: acquired via require(), NOT Knit.GetService() -- this makes the
-- module's identity independent of KnitStart ordering between DisturbanceService and its
-- future consumer (Predator AI). Per ADR-0001's own binding constraint, this module must only
-- ever be require()d from the default serial Luau script context, never from inside an Actor
-- used for parallel execution.

local DisturbanceServiceRegistrationHandshake = {}

-- Story 011 will add:
--   function DisturbanceServiceRegistrationHandshake.RegisterPredatorLockChangedSignal(signal) ... end
--   function DisturbanceServiceRegistrationHandshake.ReleasePredatorLock(predatorId) ... end

return DisturbanceServiceRegistrationHandshake
