# Production readiness

Puitei Chhakchhuak fails fast when a production web container starts without its deployment contract. The Docker entrypoint validates configuration, while Railway runs database preparation once as a pre-deploy command.

## Required environment

| Variable | Purpose |
| --- | --- |
| `APP_HOST` | Public hostname without a scheme; used for mail links and host authorization. |
| `APP_HOSTS` | Optional comma-separated host aliases. |
| `MAILER_FROM` | Verified sender address. |
| `SMTP_ADDRESS` | SMTP server hostname. |
| `ACTIVE_STORAGE_SERVICE` | A key from `config/storage.yml`; Railway must use `railway`, never `local`. |
| `DATABASE_URL` or `PUITEI_DATABASE_PASSWORD` | PostgreSQL credential. Railway should reference `Postgres.DATABASE_URL`. |
| `RAILS_MASTER_KEY` or `SECRET_KEY_BASE` | Rails secret. `RAILS_MASTER_KEY` is preferred when encrypted credentials are used. |

Selecting `ACTIVE_STORAGE_SERVICE=railway` additionally requires `AWS_ENDPOINT_URL`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_S3_BUCKET_NAME`, and `AWS_DEFAULT_REGION`. SMTP supports `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_AUTHENTICATION`, and `SMTP_STARTTLS`.

Never commit a production environment file, master key, SMTP password, database URL, or bucket credential. Use Railway reference variables and seal manually entered secrets.

## Release gate

Run before building an image:

```sh
bin/rails test
bin/rails test:system
bin/rubocop
bin/brakeman --no-pager
bin/rails zeitwerk:check
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile
```

With production variables loaded, `bin/rails production:readiness` verifies environment configuration, database connectivity, and Active Storage initialization. Production execution of `db/seeds.rb` is code-level disabled because it contains demonstration records. Use the idempotent `production:bootstrap_owner` task documented in `docs/railway.md`.

## Health and rollback

- `GET /up` proves Rails can boot.
- `GET /health/ready` verifies database connectivity and is Railway's deployment health check.
- A release stops if the Railway pre-deploy migration command fails.
- Roll back the application image independently from the database. Only use backward-compatible migrations when old and new revisions may overlap.
- Enable Railway PostgreSQL backups and keep an independent export of critical private bucket files; test restoration before launch.

After deployment, smoke-test sign-in, dashboard, customer and measurement lookup, order creation, production transitions, payment receipt, expense entry, delivery handover, staff attendance, report export, file upload, and email delivery with non-production records. See `docs/railway.md` for the complete runbook.
