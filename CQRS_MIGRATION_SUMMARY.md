# CQRS & Deterministic Runtime Migration Summary

This document summarizes the changes introduced in the recent massive refactoring commit: `feat: migrate to deterministic distributed operational runtime with CQRS` and the subsequent patch `fix: resolve import errors and add triggerFullRebuild`.

## Executive Summary
The Staff App has been completely migrated from a reactive, frontend-driven state management model to a highly resilient **Event-Sourcing and CQRS** (Command Query Responsibility Segregation) architecture. This guarantees that all UI state across all devices (Tablets, KDS, Manager Dashboards) is deterministic, sequence-safe, and server-authoritative.

## Key Additions & Systems

### 1. The Operational Runtime Bridge
- **Added:** `lib/core/runtime/operational_runtime_bridge.dart`
- **Purpose:** Acts as the strict gateway between incoming WebSocket payloads and the application's state. It intercepts all events and forces them through validation before they can affect the UI.

### 2. Deterministic Projection Store
- **Added:** `lib/core/runtime/deterministic_projection_store.dart`
- **Purpose:** An in-memory replica of backend state. Replaces direct repository mutation. WebSocket events update this store, which then triggers invalidations that force UI projections to rebuild.

### 3. Centralized Validation & Orchestration
- **Added:** `lib/core/runtime/runtime_orchestrator.dart`
- **Added:** `lib/core/runtime/sequence_validator.dart`
- **Added:** `lib/core/runtime/realtime_event_router.dart`
- **Purpose:** Ensures payloads are strictly ordered. Out-of-sequence events are buffered. Cross-branch payload bleeding is blocked at the gateway via the new `branch_isolation_resolver.dart`.

### 4. Hydration & Replay Recovery
- **Added:** `lib/core/runtime/operational_runtime_hydrator.dart`
- **Added:** `lib/core/runtime/replay_recovery_coordinator.dart`
- **Purpose:** Fetches authoritative state on login and seamlessly recovers missing event deltas if the device drops offline and reconnects.

### 5. Optimistic Mutation Management
- **Added:** `lib/core/runtime/mutation_acknowledgement_manager.dart`
- **Purpose:** Tracks local optimistic state changes (e.g., completing an order). If the server does not acknowledge the action within a TTL threshold, the mutation is automatically rolled back, preventing "ghost state".

### 6. Kitchen & Staff Governance
- **Added:** `KitchenRuntimeCoordinator` and `PresenceGovernanceRuntime`.
- **Purpose:** Shifts KDS (Kitchen Display System) idempotency and Staff heartbeat/presence mechanics to strict server-authoritative rules.

### 7. Runtime Observability Widgets
- **Added:** Realtime diagnostics widgets (`transport_health_monitor.dart`, `replay_recovery_monitor.dart`, `queue_backlog_inspector.dart`).
- **Purpose:** Allows administrators to view the actual health, sequence gaps, and recovery statuses of the transport layer during live restaurant operations.

## Architectural Enforcements
- **Removed:** Direct `applyRemoteUpdate` logic from the `RealtimeSyncManager`.
- **Enforced:** Repositories now feature `sync[Domain]()` endpoints that strictly pull fresh arrays from the central `DeterministicProjectionStore` during a projection rebuild cycle.

## Compilation Fixes & Error Resolutions (Final Patch)

During the final stages of the transition, `flutter run` failed due to strict compiler checks. The following specific errors were encountered and resolved in the final patch commit (`fix: resolve import errors and add triggerFullRebuild`):

1. **Ghost Imports:** 
   - **Error:** `Error when reading 'lib/core/runtime/domain/invalidation_rule.dart': The system cannot find the file specified`
   - **Context:** During the massive file restructuring, I moved `InvalidationRule` into `invalidation_coordinator.dart` and consolidated the KDS providers, but forgot to remove the old import paths from the `OperationalRuntimeBridge`.
   - **Resolution:** Stripped the invalid imports, resulting in clean compilation.

2. **Missing Rebuild Engine Method:** 
   - **Error:** `The method 'triggerFullRebuild' isn't defined for the type 'ProjectionRebuildEngine'.`
   - **Context:** The `OperationalRuntimeHydrator` was successfully built and hooked into the session start sequence, but it lacked a way to force the UI to aggressively pull the newly hydrated state across all domains at once.
   - **Resolution:** Implemented `triggerFullRebuild()` inside `ProjectionRebuildEngine` which bypasses individual domain invalidation constraints and synchronously iterates over all registered projection keys, ensuring the UI perfectly reflects the freshly downloaded backend snapshot.
