# Integration Tests

Cross-system tests — multiple Knit services interacting, not a single module in
isolation. Placeholder until Foundation/Core services exist in `src/`.

First expected occupants (per the Accepted ADRs' own Validation Criteria sections):

- **RunController fan-in** (ADR-0002): a duplicate `RunEndConditionRaised` call with
  a different `conditionType` results in exactly one `RunEnded` fire, `exitReason`
  matching the first call.
- **Death/Respawn reconciliation** (ADR-0005): a duplicate `RequestSquadOxygenSpend`
  call with the same `(deadPlayerUserId, deathEventId)` is a no-op; a simulated
  staleness-sweep re-arm during an in-flight call's yield discards the late success.
- **RemoteEvent global budget** (ADR-0006): a simulated client firing 6 different
  under-their-own-limit events in rapid alternation is capped once the sum exceeds
  the 30/s global budget.

Naming: `[SystemA]_[SystemB]_integration.spec.luau`.
