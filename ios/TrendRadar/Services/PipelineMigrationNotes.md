# RefreshPipeline Migration

## Current migration state

Background refresh remains responsible for scheduling and lifecycle management.

Business execution is moving into RefreshPipelineExecutor.

## Target flow

BackgroundRefreshService

-> BackgroundRefreshPipelineAdapter

-> RefreshPipelineExecutor

-> Pipeline Stages

## Next steps

- replace legacy refresh body gradually
- add stage level tests
- verify unsigned and adhoc IPA workflows
