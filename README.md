# Puitei Chhakchhuak

Puitei Chhakchhuak is a mobile-first Progressive Web App for running the daily operations of a single tailoring business — from customer measurements through production, delivery, and payment.

## Features

- Customer directory with measurement history and multiple named profiles
- Design gallery and collections with customer selections
- Guided order creation with per-garment measurement snapshots and job cards
- Tailoring production workflow (cutting, embroidery, tailoring, finishing)
- Payments, receipts, and outstanding balance tracking
- Inventory catalogue and stock movement ledger
- Expense tracking with approvals and vouchers
- Staff directory, attendance, leave, and scheduling
- Business reports (revenue, expenses, profit, trends)
- Notifications and customer communication
- Installable PWA with offline shell support

## Tech Stack

- Ruby 4.0.3 and Rails 8.1
- PostgreSQL
- Hotwire (Turbo and Stimulus), Importmap, Propshaft, Tailwind CSS 4
- Active Storage
- Solid Queue, Solid Cache, and Solid Cable
- Docker, deployed on Railway

## Getting Started

Requirements: Ruby 4.0.3, PostgreSQL 14+, and a platform supported by `tailwindcss-ruby`.

```sh
bundle install
bin/rails db:prepare
SEED_PASSWORD='choose-a-local-development-password' bin/rails db:seed
bin/dev
```

The app is available at `http://localhost:3000`. Seed data is synthetic demonstration data only; no password is embedded in the repository.

## Tests

```sh
bin/rails test
bin/rubocop
bin/brakeman --no-pager
bin/rails zeitwerk:check
```

## Production Deployment

Production deployment is configured for Railway. See [`docs/railway.md`](docs/railway.md) for environment variables, database, storage, and deployment steps, and [`docs/production_readiness.md`](docs/production_readiness.md) for the health-check and release contract.
