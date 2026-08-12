# Production readiness

Puitei Chhakchhuak fails fast when a production web container starts without its deployment contract. The Docker entrypoint runs `bin/rails production:check_environment` before `db:prepare`.

## Required environment

| Variable | Purpose |
| --- | --- |
| `APP_HOST` | Public hostname without a scheme; also used for host authorization and mail links. |
| `MAILER_FROM` | Verified sender address. |
| `SMTP_ADDRESS` | SMTP server hostname. |
| `ACTIVE_STORAGE_SERVICE` | A key from `config/storage.yml`. Use `local` only with a durable mounted volume. |
| `DATABASE_URL` | Preferred connection string; used for all database roles unless a role-specific URL overrides it. |
| `RAILS_MASTER_KEY` | Decrypts production credentials. `SECRET_KEY_BASE` is accepted as an alternative when credentials are not required. |

`TAILOR_FLOW_DATABASE_PASSWORD` may replace `DATABASE_URL` when using the database names and user from `config/database.yml`. Large deployments may override the shared URL with `CACHE_DATABASE_URL`, `QUEUE_DATABASE_URL`, and `CABLE_DATABASE_URL`. SMTP also supports `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_AUTHENTICATION`, and `SMTP_STARTTLS`.

Never commit a production `.env` file, master key, SMTP password, or database credential.

## Deployment checks

Run the full release gate before building an image:

```sh
bin/rails test
bin/rails test:system
bin/rubocop
bin/brakeman --no-pager
bin/rails zeitwerk:check
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile
```

With production environment variables loaded, verify the live dependencies:

```sh
bin/rails production:readiness
```

The readiness task verifies the environment, database connection, and Active Storage service. A successful release should run migrations once, start the web and Solid Queue processes, mount durable storage when `local` is selected, and retain database and upload backups.

## Probes and rollback

- `GET /up` proves that Rails can boot. It does not query the database.
- `GET /health/ready` executes a lightweight database query. Route traffic only after it returns HTTP 200 with `{"status":"ready"}`.
- Remove a failing instance from rotation when readiness returns HTTP 503. Review application and PostgreSQL logs by request ID before retrying.
- Roll back the application image independently from the database. Phase 15 migrations add authentication columns and indexes and replace the attendance uniqueness index; do not reverse them while newer instances are running.

After deployment, smoke-test sign-in, dashboard, customer and measurement lookup, order creation, production transitions, payment receipt, expense entry, delivery handover, staff attendance, and report export with a non-production tenant.
