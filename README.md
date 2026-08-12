# Puitei Chhakchhuak

Puitei Chhakchhuak is a Rails 8 Progressive Web App for the daily operation of one tailoring business. Its current implementation temporarily retains proven data boundaries while the product is simplified safely into a single-shop application. See [Product architecture realignment](docs/product_architecture_realign.md).

## Stack

- Ruby 4.0.3 and Rails 8.1
- PostgreSQL
- Devise and Pundit
- Hotwire (Turbo and Stimulus), Importmap, Propshaft, Tailwind CSS 4
- Active Storage
- Solid Queue, Solid Cache, and Solid Cable
- Minitest

## Setup

Requirements: Ruby 4.0.3, PostgreSQL 14 or newer, and a platform supported by `tailwindcss-ruby`.

```sh
bundle install
bin/rails db:prepare
bin/rails db:seed
bin/dev
```

The server is available at `http://localhost:3000`. Production forces HTTPS and validates its required environment before the container starts. See [Production readiness](docs/production_readiness.md) for the deployment contract and health checks.

## Development logins

- Primary tenant owner: `owner@puitei.test`
- Second tenant owner: `esther@puitei.test`
- Shared development password: `Puitei-Dev-2026!`

The default password is only used when seeding in development. Set `SEED_PASSWORD` to override it. Seeding any other environment requires an explicit `SEED_PASSWORD`; no production password is embedded in the application.

Additional seeded accounts use the same development password and are listed in `db/seeds.rb` for every Phase 1 role.

## Verification

```sh
bin/rails test
bin/rubocop
bin/brakeman --no-pager
bin/rails zeitwerk:check
bin/rails assets:precompile
```

## Single-business tenancy foundation

- `Shop` is the tenant root and doubles as the single business's profile record. `User` is global authentication identity; `Membership` owns the shop-specific role and branch assignment.
- `Current.membership` securely derives `Current.user`, `Current.shop`, and `Current.branch` from an authenticated membership stored in the session. Tenant identity is never accepted from normal form parameters.
- Existing business records are backfilled to a default migration shop before `shop_id` becomes non-null. Composite identifiers are unique inside a shop.
- There is no public self-registration, plan, subscription, or trial: every feature and resource is unrestricted for the business. New accounts are created through the staff invitation workflow.
- Secure, expiring, digest-backed staff invitations and one-time shop onboarding remain available.
- Every branch creates exactly one `ShopSetting`; database constraints protect the one-to-one relation and operational ranges.
- Pundit policies enforce tenant and role access on the server, and `verify_authorized` makes missing controller authorization fail closed.
- The service worker caches the offline shell and same-origin static assets. It does not cache authenticated HTML or attempt offline data synchronization.
- English is complete. Mizo (`lus`) and Hindi (`hi`) locale namespaces and initial core terms are present; missing translations fall back to English until later localization work.

## Phase 2 behavior

- Customers have generated non-sequential public codes, branch-scoped normalized phone uniqueness, search, profile photos, language preferences, and archival instead of destructive deletion.
- Eleven seeded garment templates define only the measurement fields relevant to that garment. Template fields remain data rather than hardcoded form columns.
- A customer can have multiple named measurement profiles. Every measurement save creates a locked sequential version; existing versions have no update or delete route.
- Measurement values are normalized through `BigDecimal` and stored as decimal strings in JSONB, preserving decimal intent without floating-point columns.
- Previous versions can be copied into a new version. Fitting/posture notes, customer preferences, and design/fitting photos are supported.
- Owners, managers, and receptionists can manage measurements. Cashiers have read-only customer access, while production roles cannot access the customer directory or measurement history directly.

## PWA installation

On Chromium-based browsers, use the install control offered by the browser or the dashboard button when it appears. On iPhone Safari, choose Share → Add to Home Screen. HTTPS is required outside localhost.

## Phase 3 behavior

- Orders receive branch/year-scoped sequential order numbers using the shop invoice prefix, with database uniqueness protection.
- Every garment selects an exact saved measurement version. Its values, field labels, unit, profile notes, and version metadata are copied into an immutable JSONB snapshot on the order item.
- Fabric photos and design references can be attached per garment. Trial and delivery dates are validated against the order date.
- Draft orders can be reviewed and confirmed. Printable job cards include measurements and production notes, while a scannable QR code links authorized staff back to the order.
- All staff can view branch-scoped orders and job cards; owners can view every branch. Owners, managers, and receptionists can create and confirm orders.

## Phase 4 behavior

- Confirming an order creates an ordered production route for every garment: cutting, optional embroidery, tailoring, and finishing.
- Production staff can claim, start, and complete tasks matching their role. Owners and managers can assign staff, skip stages, and safely reopen completed work.
- A stage cannot start until every earlier stage is complete or skipped. Later active work must be reopened before an earlier stage can be reopened.
- The workshop queue supports stage, status, and “my tasks” filters, with live unassigned, in-progress, due-today, and overdue counts.
- Orders show garment-level production progress. Every claim, assignment, transition, skip, and reopen writes an immutable audit event.
- Existing confirmed order items are backfilled into the production queue during migration.

## Phase 5 behavior

- Every garment records quantity and unit price. Confirmation freezes the subtotal, discount, shop tax rate, tax amount, currency, and final total as an auditable pricing snapshot.
- Confirmed orders accept partial or full payments without allowing overpayment. Active receipts determine paid and outstanding balances.
- Receipts receive branch/year-scoped sequential numbers and capture payment date, method, non-cash reference, receiving staff, and notes.
- Recorded financial details cannot be edited or deleted. Owners and managers can void a receipt only with a reason; voided receipts remain visible in audit history and stop contributing to collected totals.
- Owners, managers, receptionists, and cashiers can access billing. Production roles continue to see order and workshop details without financial data.
- The payment dashboard reports daily and lifetime collections, outstanding confirmed-order balances, void counts, search, and printable receipts.

## Phase 6 behavior

- Every branch has a searchable material catalogue covering fabrics, thread, buttons, zippers, lining, trims, accessories, and custom items, with a stable SKU, stock unit, supplier, pricing, swatch image, and reorder level.
- Stock on hand and reserved stock are concurrency-safe cached balances backed by an immutable ledger. Receive, issue, adjustment, wastage, reservation, release, and consumption movements preserve before-and-after balances and the responsible staff member.
- Confirmed order garments can reserve inventory. Completing the cutting stage atomically consumes every outstanding reservation for that garment, while reopening production does not incorrectly return already-cut material.
- Owners and managers manage the catalogue and all movements. Receptionists can reserve and release materials; cutting staff and tailors can issue, record wastage, and consume reservations. Other active staff have branch-scoped read access.
- The responsive inventory workspace includes low-stock alerts, stock value, filters, desktop tables, mobile cards, item detail, order links, and complete movement history.

## Phase 7 behavior

- Production-complete orders enter a dedicated delivery desk with ready, overdue, delivered-today, and outstanding-balance summaries.
- A handover requires final quality, garment count, payment-status, packaging, and recipient-acknowledgement checks. The recipient, collection method, staff member, timestamp, optional proof images, and notes are retained permanently.
- Delivery captures an immutable financial snapshot. Receptionists and cashiers may release fully paid orders; only owners and managers can authorize handover while a balance remains.
- Completing the handover moves the order to the terminal delivered status and generates a printable delivery receipt. Delivered orders can still accept a later balance payment without losing their handover snapshot.
- Delivery records are branch-scoped, non-editable, non-deletable, searchable, and available in responsive desktop tables and mobile operational cards.

## Phase 8 behavior

- Business expenses receive branch/year-scoped sequential voucher numbers and capture category, date, vendor, amount, currency, payment method, reference, notes, and optional image or PDF receipts.
- Owner and manager entries are approved immediately. Receptionist and cashier entries remain pending until an owner or branch manager approves them; only approved, non-void expenses contribute to totals and profit.
- Recorded financial details cannot be edited or deleted. Owners and managers may void an entry only with a reason, preserving the complete staff, approval, and correction audit trail.
- Weekly, monthly, quarterly, and yearly schedules create linked future occurrences without overwriting earlier records or silently generating costs in the background.
- The expense workspace supports search, category/status/date filters, daily and monthly metrics, printable vouchers, and formula-injection-safe CSV export.
- Dashboard monthly profit now calculates active payment revenue less approved active expenses. Access remains branch-scoped for managers and staff, while owners may review all branches.

## Phase 9 behavior

- Owners and managers have a branch-scoped staff directory with secure account creation, operational role assignment, profile editing, and archival without deleting production or financial history.
- Every staff member receives a permanent branch-coded employee number. Owner-only compensation references support monthly, hourly, daily, and piece-rate arrangements without attempting payroll processing.
- Active staff can check themselves in and out once per workday. Attendance retains immutable check-in identity and time, accurate durations, optional notes, manager filters, and mobile daily actions.
- Staff submit and cancel their own leave requests. Owners and managers approve or reject branch requests with review notes; approved dates cannot overlap.
- Owners and managers schedule non-overlapping shifts and cancel them only with a reason. Staff can view their own schedule from mobile or desktop.
- Staff profiles combine current production workload, monthly completions, attendance hours, upcoming shifts, leave history, and a permanent workforce activity log.

## Phase 14 behavior

- Owner and manager reports combine revenue, approved expenses, profit, order value, outstanding balances, customers, and deliveries over a bounded date range.
- Monthly trends, expense categories, payment methods, and staff performance are calculated from tenant-scoped relations; CSV exports neutralize spreadsheet formulas.
- Advanced report sections are available to every authorized business manager alongside core business reporting.

## Phase 15 hardening

- Authentication enforces stronger passwords, inactivity timeouts, and timed account lockout after repeated failed sign-ins.
- Tenant selection now excludes inactive shops and branches. Attendance, shifts, staff activity, staff workload, deliveries, and reporting queries are explicitly shop-scoped.
- A restrictive Content Security Policy, browser security headers, host authorization, and deployment-time environment checks protect the production boundary.
- A skip link, meaningful QR alternative text, keyboard-contained mobile dialogs, restored focus, coarse-pointer touch targets, and reduced-motion support improve accessibility.
- Dashboard and report aggregations use grouped SQL and subqueries instead of loading full collections or issuing repeated count queries.
- `/up` is the liveness endpoint; `/health/ready` verifies database connectivity and returns HTTP 503 while unavailable.
- CI runs static security scans, lint, model/controller integration tests, and desktop/mobile system tests for every core workspace.
