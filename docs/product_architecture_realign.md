# Product architecture realignment

## Phase 1 outcome

The visible product is **Puitei Chhakchhuak**, a single-business tailoring operations app. Normal owner and staff navigation no longer exposes public trial signup, plans, subscriptions, billing upgrades, tenant switching, or SaaS promotion. Authentication and all tailoring records remain intact.

Phase 1 intentionally has no database migration. It is a reversible product/UI realignment, not a destructive tenancy rewrite.

## Existing architecture retained temporarily

- `Shop` remains the tenant root.
- `Membership` continues to connect a global Devise `User` to a shop, branch, and effective operational role.
- `CurrentTenant` derives `Current.membership`, `Current.shop`, and `Current.branch` from the signed-in user and the server-side session.
- Business records retain non-null `shop_id` foreign keys and tenant-aware constraints.
- Pundit scopes continue to enforce shop and branch isolation.
- `Plan`, `Subscription`, `SubscriptionEntitlement`, and subscription write-access code remain because customer, order, staff, design, and report behavior currently depends on them.
- Business audit history remains available through `BusinessAuditEvent` for operational changes such as payment-profile updates and staff invitations.
- Public registration, onboarding, subscription, and current-shop routes remain for compatibility, but SaaS entry points are absent from the normal product UI.

The development dataset contains multiple shops and memberships, including Puitei Chhakchhuak. Removing `shop_id` scopes or choosing a global shop in Phase 1 could expose or mutate data across those records, so the current isolation boundary must remain until consolidation is explicitly mapped.

## Preserved business modules

Customers, garment-aware measurements and history, Design Studio, orders, production, customer receipts, deliveries, inventory, expenses, staff/workforce, reports, business payment settings, attachments, and PWA/offline behavior remain operational.

## Staged removal strategy

1. Confirm the canonical production business, owner accounts, branches, and record counts; take and verify a database and attachment backup.
2. Replace plan entitlements with explicit single-business configuration and remove subscription-based write blocking.
3. Replace public SaaS registration with an administrator-controlled account and staff invitation workflow.
4. Consolidate any records that belong to the canonical business with explicit source-to-target mappings and integrity checks.
5. Remove legacy subscription, plan, trial, and tenant-switch routes only after no controller, policy, service, test, or production operation references them.
6. Simplify `Membership`, `Shop`, and `shop_id` only as a final migration with a rollback plan; keeping one internal shop record may remain the safest long-term design.

## Phase 2 recommendation

Redesign the dashboard as Puitei Chhakchhuak's daily command centre: today's orders, upcoming trials, due and overdue deliveries, outstanding balances, production bottlenecks, low stock, and focused quick actions. The dashboard should use the retained policy scopes and existing operational data without introducing new SaaS dependencies.
