# iPhone Suspension Audit And Active-Lane Footprint

## Status

Date: 2026-04-08

This document closes the current audit question for issue `#77`:

- what iPhone lifecycle transitions Pocket Relay can and cannot influence
- which active-lane costs are worth reducing before backgrounding
- whether the current visible transcript tail of `160` is too high

Related docs:

- [`054_transcript_windowing_memory_plan.md`](./054_transcript_windowing_memory_plan.md)
- [`059_background_execution_publishability_findings.md`](./059_background_execution_publishability_findings.md)
- [`063_ios_simulator_validation_handoff.md`](./063_ios_simulator_validation_handoff.md)
- [`069_true_live_turn_continuity_contract.md`](./069_true_live_turn_continuity_contract.md)

## Executive Result

Pocket Relay cannot prevent ordinary iPhone suspension for a general-purpose
foreground app.

What Pocket Relay can still improve is the amount of active-lane UI/runtime
state it keeps hot before backgrounding, so brief backgrounding is less likely
to degrade into:

- rebuild-heavy restore
- lost detail after return
- higher cold-start risk under memory pressure

The current repo carries enough live-lane surface area that the default visible
transcript tail should be reduced below `160`.

Recommended policy:

- keep ordinary suspension/termination modeling explicit and separate
- keep live-turn continuity work focused on truthful reconnect/reattach, not on
  pretending iOS can run indefinitely
- reduce the default visible transcript tail from `160` to `120`
- treat `120` as a budgeted default, not a sacred constant
- measure whether iPhone return quality improves before considering deeper
  pruning work

## Relevant iPhone Lifecycle Paths

Pocket Relay must distinguish these cases:

### 1. App switch

- user leaves the app through the app switcher or by opening another app
- iOS will normally move Pocket Relay toward suspension shortly afterward
- Pocket Relay can preserve lane identity and background-grace requests while
  the app is still allowed to run
- Pocket Relay cannot assume it will keep executing indefinitely

### 2. Screen lock

- locking the phone is another ordinary path toward background suspension
- this is not itself proof of transport loss or conversation loss
- Pocket Relay should preserve narrow recovery state and avoid voluntary lane
  teardown

### 3. Longer background stay

- after enough time away, ordinary suspension is expected
- later return quality depends on whether the same process survived and whether
  upstream truth can still be reattached or restored

### 4. Force quit

- user force quit is app termination, not ordinary suspension
- Pocket Relay cannot prevent it and should not model it as a continuity bug

### 5. Memory pressure / kill / jetsam

- this is where active-lane footprint matters most
- lower retained UI/runtime cost does not stop suspension, but it can reduce
  the chance that the suspended app is later relaunched cold with less in-memory
  detail intact

## What Pocket Relay Can Influence

Pocket Relay owns:

- how much transcript and work-log surface it keeps projected
- how much lane-local UI state stays alive while the app is foregrounded
- whether it preserves narrow recovery state truthfully
- whether it avoids self-inflicted disconnect/rebuild work on routine
  lifecycle transitions

Pocket Relay does not own:

- whether iOS suspends the process after backgrounding
- whether iOS later kills the suspended process under pressure
- any general-purpose right to run arbitrary code forever in the background

## Current Active-Lane Cost Drivers

### 1. Visible transcript tail

Current file:

- [`chat_transcript_surface_projector.dart`](../lib/src/features/chat/transcript/presentation/chat_transcript_surface_projector.dart)

Current behavior before this change:

- default visible tail window: `160`
- projector still builds contracts for the entire visible tail
- transcript items can include assistant messages, user messages, work-log
  surfaces, request surfaces, and detail-heavy transcript blocks

This is the clearest adjustable cost driver with low product risk.

### 2. Work-log and command surfaces

Relevant files:

- [`chat_work_log_item_projector.dart`](../lib/src/features/chat/worklog/application/chat_work_log_item_projector.dart)
- [`chat_session_controller_work_log_terminal.dart`](../lib/src/features/chat/lane/application/chat_session_controller_work_log_terminal.dart)

Work-log rows and command detail surfaces are valuable, but they increase the
amount of projected active-turn detail the lane may retain.

### 3. Pending request state

Relevant files:

- [`chat_pending_request_placement_projector.dart`](../lib/src/features/chat/transcript/presentation/chat_pending_request_placement_projector.dart)
- [`chat_screen_contract.dart`](../lib/src/features/chat/lane/presentation/chat_screen_contract.dart)

Pinned approval/input state is product-critical and should remain accessible,
but it is still part of the active-lane footprint that must be budgeted.

### 4. Multi-lane live protection hosts

Relevant files:

- [`workspace_turn_activity_builder.dart`](../lib/src/features/workspace/presentation/widgets/workspace_turn_activity_builder.dart)
- [`workspace_turn_background_grace_host.dart`](../lib/src/features/workspace/presentation/widgets/workspace_turn_background_grace_host.dart)
- [`workspace_turn_wake_lock_host.dart`](../lib/src/features/workspace/presentation/widgets/workspace_turn_wake_lock_host.dart)

These hosts are correct product ownership, but they confirm that live-lane
state is shared across multiple surfaces and not just one selected transcript.

## Transcript Tail Decision

`160` is too high for the current product budget on iPhone.

Reasoning:

- it preserves more visible history than the active mobile task usually needs
- it increases projection and retained widget cost without changing upstream
  transcript truth
- the repo already treats transcript windowing as a product budget, not a
  correctness rule

Chosen adjustment:

- reduce the default visible tail from `160` to `120`

Why `120`:

- still large enough to preserve recent working context
- materially lower than `160` without becoming aggressively restrictive
- small enough to lower projection pressure now while keeping future tuning
  simple

## Measurement Plan

This repo still needs real-device follow-up, but the success criteria are now
explicit.

Measure before and after the `120`-item change:

- memory footprint shortly before backgrounding
- memory footprint after returning from brief backgrounding when the process
  survives
- cold-start or restore frequency after brief lock/unlock and app-switch flows
- whether completed-turn detail survives brief return paths more reliably

Recommended manual scenarios:

- app switch during a long live turn
- screen lock during a long live turn
- app switch shortly after turn completion
- return after a brief background stay

## Recommended iPhone Policy

- do not describe ordinary iPhone suspension as something Pocket Relay can
  "solve"
- keep recovery/continuity truth tied to upstream/runtime evidence
- keep active-lane footprint intentionally budgeted
- prefer smaller visible transcript tails over carrying more historical surface
  by default
- treat further reductions, work-log compaction, or stronger per-lane eviction
  as follow-on work only after real-device measurements
