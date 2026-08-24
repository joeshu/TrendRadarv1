# TrendRadar iOS Next Batch Implementation Tracking

Based on TrendRadar iOS project plan.

## Current batch target: P0 stabilization continuation

- Verify CI dynamic simulator selection.
- Ensure build/test logs are preserved.
- Continue ReportDeliveryService unification.
- Prepare RefreshPipeline separation:
  - Scheduler
  - Collector
  - Filter
  - Persist
  - Report
  - Deliver

## Acceptance

- Unsigned IPA workflow passes.
- Ad-hoc IPA workflow passes.
- SHA256 artifact generated.
- No additional TestFlight, Development IPA, or App Store workflow.

## Next engineering tasks

1. Refactor refresh execution into testable pipeline units.
2. Add diagnostics export and startup safe mode.
3. Split SwiftUI feature views for independent testing.
