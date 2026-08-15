# Railway deployment

Puitei Chhakchhuak is prepared for a small, production single-shop deployment on Railway. The initial topology is deliberately simple:

- one persistent `Puitei Chhakchhuak` web service built from the repository Dockerfile;
- one Railway PostgreSQL service shared by application data, Solid Cache, Solid Queue, and Solid Cable;
- one private Railway Storage Bucket for customer photos, designs, receipts, and delivery proof;
- Solid Queue running inside Puma, with no Redis and no separate worker service.

This is the recommended starting point for the current workload. Add a separate `bin/jobs` worker only if production metrics show that background work is delaying web requests.

## 1. Create the project

1. Push the repository to a private GitHub repository.
2. In Railway, create a project named `Puitei Chhakchhuak` and choose **Deploy from GitHub repo**.
3. Name the application service `Puitei Chhakchhuak` and select the production branch.
4. Add a PostgreSQL service and keep its name as `Postgres`.
5. Add a Storage Bucket named `Uploads`.
6. Put the app, PostgreSQL, and bucket in the same environment and the closest available region to the shop. For Aizawl, use Singapore when it is available for all three resources.
7. In the Puitei Chhakchhuak service's **Settings → Networking**, generate a Railway domain before adding `APP_HOST`.

Do not attach a volume to the web service. Its filesystem is ephemeral by design; PostgreSQL and the bucket hold all durable data.

## 2. Add variables

Open the Puitei Chhakchhuak service's **Variables → Raw Editor** and use `config/railway.env.example` as the template. Railway reference variables keep database and bucket credentials synchronized without copying secrets.

Add `RAILS_MASTER_KEY` separately, paste the exact value from local `config/master.key`, and seal the variable. Never place the master key, SMTP password, database URL, or bucket credentials in Git.

Before deploying, replace these placeholders:

- `MAILER_FROM` with an address verified by the mail provider;
- `SMTP_ADDRESS`, `SMTP_USERNAME`, and `SMTP_PASSWORD` with production SMTP details;
- `AWS_S3_URL_STYLE` with the style shown in the bucket Credentials tab (`virtual` for current buckets, `path` only for an older path-style bucket).

If the Railway services are not named `Postgres` and `Uploads`, update the reference namespaces in the example. `DATABASE_URL=${{Postgres.DATABASE_URL}}` uses Railway private networking.

For a custom domain, set `APP_HOST` to the custom hostname without `https://`. Keep the generated Railway hostname in `APP_HOSTS` as an optional comma-separated alias until DNS verification and the final smoke test are complete.

## 3. Deploy

`railway.json` makes Railway use the Dockerfile and enforces this release sequence:

1. build the immutable image and precompile assets;
2. run `./bin/rails db:prepare` once as a pre-deploy command;
3. start `./bin/thrust ./bin/rails server`, with Thruster receiving Railway traffic on port 80 and proxying to Puma;
4. wait for `GET /health/ready` to return HTTP 200 before switching traffic;
5. restart a crashed service up to ten times.

The Docker entrypoint runs `production:check_environment` before the server starts. A missing secret, mail setting, database URL, or bucket credential therefore fails the deployment instead of silently losing data.

Deploy from GitHub by committing and pushing the production branch. For a manual CLI deployment, install the Railway CLI, authenticate, link this directory to the `Puitei Chhakchhuak` service, and run:

```sh
railway up --service "Puitei Chhakchhuak"
```

Follow the rollout with:

```sh
railway logs --service "Puitei Chhakchhuak"
railway service status --service "Puitei Chhakchhuak"
```

## 4. Create the first owner once

Production sample seeds are disabled. After the first healthy deployment, add these temporary variables to the Puitei Chhakchhuak service:

- `BOOTSTRAP_OWNER_EMAIL`
- `BOOTSTRAP_OWNER_PASSWORD` (seal this one)
- `BOOTSTRAP_OWNER_NAME`
- `BOOTSTRAP_SHOP_NAME`
- `BOOTSTRAP_BRANCH_NAME`
- `BOOTSTRAP_BRANCH_CODE`

Open a Railway SSH shell for the deployed Puitei Chhakchhuak service and run:

```sh
bin/rails production:bootstrap_owner
```

The task is idempotent and never prints the password. Sign in immediately, then delete all `BOOTSTRAP_*` variables and redeploy so the temporary password is removed from the running environment.

## 5. Verify the release

Run these checks against the production domain:

```sh
curl -fsS https://YOUR_HOST/up
curl -fsS https://YOUR_HOST/health/ready
```

Then smoke-test sign-in, dashboard, customer creation with a photo, measurement history, order creation, production transitions, payment receipt, expense receipt, delivery proof, staff attendance, report export, and outbound email. Confirm that an uploaded file still opens after a redeploy.

Inside a deployed service, `bin/rails production:readiness` checks configuration, PostgreSQL connectivity, and Active Storage initialization.

## 6. Operations and scaling

- Keep one web replica initially. Solid Queue is running inside Puma and must remain continuously available, so do not enable serverless sleep for production.
- Start with 1 GB RAM, one Puma process, five Rails threads, and one job process. Change one setting at a time after reviewing Railway CPU, memory, HTTP latency, and PostgreSQL connection metrics.
- Enable PostgreSQL backups available on the selected Railway plan and rehearse a restore before launch. Export critical bucket files separately because a database backup does not include uploads.
- Configure an external uptime monitor for `/health/ready`; Railway's deployment health check is not continuous monitoring.
- Set a Railway usage limit/budget alert and review logs without recording customer photos, measurements, passwords, UPI identifiers, or payment details.
- Use backward-compatible migrations. If a release fails, roll the app back from Railway Deployments; restore data only through a rehearsed recovery procedure.
- When job backlog or mail/report processing begins affecting request latency, create a second service from the same repository with start command `bin/jobs`, remove `SOLID_QUEUE_IN_PUMA` from the web service, and share the same variables. At that point remove `startCommand` from the root `railway.json` and configure the web and worker start commands per service.

## 7. Pre-launch gate

Run locally before every production release:

```sh
bin/rails test
bin/rails test:system
bin/rubocop
bin/brakeman --no-pager
bin/bundler-audit check --update
bin/rails zeitwerk:check
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile
```

Do not run `db:seed` in production. Use only the one-time owner bootstrap task described above.
