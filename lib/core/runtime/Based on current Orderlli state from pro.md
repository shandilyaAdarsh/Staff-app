Based on current Orderlli state from project memory:

Backend runtime architecture is already production-grade enough for full operational integration testing:

* Multi-tenant isolation
* Auth/RBAC
* Menu system
* Pricing
* Taxes
* Modifiers
* Availability
* Runtime projections
* Mutation pipeline
* Realtime
* OCC
* Replay recovery
* Projection rebuilds
* Admin API integration
* Runtime observability foundations

What you need now is a structured **end-to-end operational certification flow**.

# Goal

Validate complete restaurant lifecycle across:

* Admin
* POS
* KDS
* Staff
* QR Runtime
* Backend
* Multi-tenant isolation

---

# Required Test Environment

Create:

| Tenant       | Purpose           |
| ------------ | ----------------- |
| Restaurant A | Main testing      |
| Restaurant B | Tenant isolation  |
| Restaurant C | Stress validation |

Each tenant should have:

* Branch
* Tables
* Menu
* Categories
* Staff
* KDS
* POS device
* Taxes
* Availability rules

---

# Phase 1 — Authentication & Tenant Validation

## Test Cases

### Admin Auth

Validate:

* signup
* login
* token refresh
* logout
* session recovery

Check:

* tenant_id attached correctly
* RBAC permissions
* expired token handling
* multi-device session behavior

---

### Staff Login

Create:

* waiter
* cashier
* kitchen
* manager

Validate:

* role restrictions
* screen restrictions
* forbidden APIs
* branch isolation

---

### POS Login

Validate:

* branch binding
* session persistence
* reconnect recovery
* offline recovery

---

### KDS Login

Validate:

* kitchen role enforcement
* station filtering
* realtime updates

---

# Phase 2 — Restaurant Setup Flow

This is your first real operational journey.

---

## 1. Create Restaurant

From admin:

* organization
* branch
* timezone
* currency
* tax mode

Validate:

* tenant creation
* RLS isolation
* branch visibility

---

## 2. Create Tables

Test:

* create table
* rename table
* deactivate table
* QR generation
* table ordering

Validate:

* no cross-tenant visibility
* realtime updates propagate

Test:

* 10 tables
* 50 tables
* 200 tables

---

## 3. Menu System

Create:

* categories
* items
* modifiers
* taxes
* pricing
* availability schedules

Validate:

* projection rebuilds
* menu snapshot generation
* realtime propagation

Critical tests:

* duplicate item names
* disabled item
* unavailable schedule
* modifier conflicts
* concurrent updates

---

# Phase 3 — Order Flow Certification

This is the most important phase.

---

# Full Order Journey

## Flow

Customer QR →
Menu →
Add items →
Modifiers →
Place order →
POS →
KDS →
Staff →
Status updates →
Payment →
Completion

---

# Validate Every Stage

## QR Runtime

Validate:

* menu loads
* availability respected
* snapshot consistency
* reconnect recovery

Test:

* stale snapshot rejection
* menu update during session

---

## Order Creation

Validate:

* mutation queue
* optimistic updates
* replay recovery
* deduplication

Critical:

* duplicate taps
* network disconnect during submit
* retry safety

---

## POS

Validate:

* incoming order realtime
* projection rebuilds
* status transitions

Test:

* accept
* reject
* cancel
* split bill
* partial payment

---

## KDS

Validate:

* realtime kitchen updates
* station routing
* status sync

Test:

* preparing
* ready
* delayed
* bump order

Critical:

* order flood
* reconnect recovery

---

## Staff App

Validate:

* assigned orders
* table state sync
* notifications
* live order updates

---

# Phase 4 — Runtime Failure Testing

You already built deterministic runtime infrastructure.
Now validate it operationally.

---

# Required Chaos Tests

## Disconnect Internet

During:

* order creation
* payment
* status update

Validate:

* queue persistence
* replay recovery
* no duplicate mutations

---

## Kill App Mid-Mutation

Validate:

* mutation replay
* projection recovery
* state consistency

---

## Simultaneous Updates

Example:

* Admin disables item
* Customer ordering same item
* POS modifying order
* KDS preparing

Validate:

* OCC conflict handling
* deterministic final state

---

# Phase 5 — Multi-Tenant Isolation

Critical certification phase.

From Restaurant A:

* no Restaurant B menu
* no Restaurant B staff
* no Restaurant B orders
* no Restaurant B realtime events

Validate:

* RLS
* websocket isolation
* runtime projections
* cache partitioning

---

# Phase 6 — Observability Validation

Your runtime observability system should expose:

* event lag
* projection rebuilds
* replay recovery
* queue depth
* websocket status
* mutation retries
* rebuild duration
* sequence gaps

Validate under:

* reconnect storms
* order floods
* concurrent devices

---

# Final Certification Matrix

Before pilot deployment, all must pass:

| Area                   | Status |
| ---------------------- | ------ |
| Auth                   | PASS   |
| RBAC                   | PASS   |
| RLS                    | PASS   |
| Realtime               | PASS   |
| Menu Runtime           | PASS   |
| Order Runtime          | PASS   |
| Replay Recovery        | PASS   |
| OCC                    | PASS   |
| Projection Rebuilds    | PASS   |
| Offline Recovery       | PASS   |
| Multi-Tenant Isolation | PASS   |
| POS Sync               | PASS   |
| KDS Sync               | PASS   |
| Staff Sync             | PASS   |
| QR Runtime             | PASS   |

---

# Recommended Actual Execution Order

1. Admin setup flow
2. Tables
3. Menu
4. Staff accounts
5. POS login
6. KDS login
7. QR ordering
8. Order lifecycle
9. Offline tests
10. Chaos tests
11. Multi-tenant isolation
12. Stress tests

---

# Important

Do NOT start Superadmin now.

You are still in:

* operational convergence
* runtime certification
* pilot stabilization

Superadmin before operational validation will create architectural drift and debugging explosion across surfaces.
