# AGENTS.md

Instructions for coding agents working in this repository. Human setup and product context live in `README.md`.

## What this is

Hack Club NDA: a Rails app where members sign in with Hack Club Auth, complete a three-step signer flow (personal details, video pledge, contract), and produce a publicly queryable signed/not-signed status by Slack ID.

The agreement in `app/models/nda_document.rb` is a transcription of the Hack Club Contributor NDA last revised 2025-04-01: same wording, numbering and sub-clause lettering, verified word for word against a signed PDF. It departs from the source in exactly one way — the source renumbered its sections at some point and left five cross-references pointing at the wrong ones, which are corrected here and flagged with a comment at each site. That is why `VERSION` is `2025-04-01-corrected` rather than the bare source date. Do not reintroduce the originals, and do not make further edits without an explicit request; changing the legal text requires bumping `NdaDocument::VERSION` (it is immutable once signatures exist).

## Stack

- Ruby 3.4.10 (`/.ruby-version`), Rails 8.1, Minitest
- PostgreSQL 18
- Vite + vanilla JS/CSS via `vite_rails` (no React, no importmap, no Tailwind in the frontend pipeline)
- `countries` gem for the ISO 3166-1 list; Twemoji flag SVGs vendored, not installed from npm
- Bun 1.4.2 for all JavaScript (`packageManager` in `package.json`, lockfile is `bun.lock`)
- Active Storage (disk in development, Cloudflare R2 with SSE-C in production)
- Solid Queue for the one recurring job, with its tables in the primary database and its supervisor inside Puma (`SOLID_QUEUE_IN_PUMA`). No Solid Cache or Solid Cable; production caches in-process.
- Docker Hardened Images for Ruby 3.4 and Bun 1.x (floating tags, not digest-pinned)

## Commands

Prefer host-based development with Postgres from Compose. Host port is `55439`.

```sh
cp .env.example .env          # fill Hack Club Auth + xAI keys
docker compose up -d db
export DATABASE_URL=postgres://nda:nda@localhost:55439/nda_development
bin/setup --skip-server       # bundle + bun + db:prepare
bin/dev                       # Rails :3000 + Vite :3036
```

Full stack in containers: `docker compose up --build` (requires `docker login dhi.io`).

### Checks to run after changes

```sh
DATABASE_URL=postgres://nda:nda@localhost:55439/nda_test bin/rails test
bin/rubocop
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
bin/bundler-audit
bun run build
```

`bin/ci` is the full local gate. There is no `npm`/`yarn`/`pnpm` in this project — use `bun`.

Tests need Postgres. They mock xAI (`XaiTranscription.call`) and do not call live Hack Club Auth. Do not add live-network tests.

## Layout

| Path | Role |
|---|---|
| `app/controllers/sessions_controller.rb` | OAuth start/callback/logout |
| `app/controllers/nda_signatures_controller.rb` | Signer form + create |
| `app/controllers/api/v1/nda_statuses_controller.rb` | Public status JSON |
| `app/services/hack_club_auth.rb` | auth.hackclub.com OAuth |
| `app/services/xai_transcription.rb` | `POST https://api.x.ai/v1/stt` multipart |
| `app/services/pledge_validator.rb` | Token overlap + required concepts |
| `app/models/user.rb` | Identity + signing details |
| `app/models/nda_signature.rb` | Signed record + video attachment + retention |
| `app/jobs/purge_identity_videos_job.rb` | Nightly purge of expired identity videos |
| `lib/tasks/identity_videos.rake` | Manual purge + decrypt-for-review |
| `app/models/country.rb` | ISO 3166-1 list behind the country picker (`countries` gem) |
| `lib/tasks/flags.rake` | Vendors Twemoji flag SVGs into `app/javascript/flags` |
| `app/models/nda_document.rb` | Canonical agreement text + SHA-256 |
| `app/models/pledge_script.rb` | Spoken pledge text |
| `app/javascript/entrypoints/application.js` | Wizard + public lookup |
| `app/javascript/entrypoints/application.css` | All UI styles |
| `app/views/nda_signatures/show.html.erb` | Three-step form + receipt |
| `Dockerfile` | Two-stage DHI build: Ruby 3.4-dev + Bun binary, then shell-free production UID 65532 |
| `compose.yml` | Postgres 18, Rails `build` target, Bun Vite |

Routes of interest:

- `GET /auth/hack_club` / `GET /auth/hack_club/callback` / `DELETE /logout`
- `GET/POST /nda_signature`
- `GET /api/v1/nda_status/:slack_id`

## Conventions

- Follow existing style: RuboCop Omakase, compact Ruby, ERB that matches the current views.
- The country picker is a listbox built in `application.js` over a real `<select>` that stays in the DOM, invisible
  but laid out, so browser autofill, HTML5 validation and the no-JS fallback keep working. Country flags are
  vendored SVGs under `app/javascript/flags` (`bin/rails flags:fetch`, sourced from jdecked/twemoji); do not swap
  them for a CDN or an emoji font, which Windows does not render.
- Keep the frontend vanilla. The wizard is a small script in `application.js`; CSS is one file. Do not introduce a JS framework, CSS framework, or importmap.
- Keep JS package changes in `package.json` + `bun.lock` via `bun`.
- The `@media print` block in `application.css` is the PDF export path (`window.print()` -> Save as PDF); there is
  no PDF toolchain. Keep the serif `font-family` override on `.print-contract *` (the UI font exports as a Type 3
  font, which breaks text extraction and PDF/A), the `:root, body` white background (the root background paints the
  page box), `overflow: visible`, and the break-control rules. See "Exporting the signed agreement" in `README.md`.
- Keep the Dockerfile at two stages (`build` then `production`). Bring Bun in with `COPY --from=dhi.io/bun:1-debian13-dev`, not a third `FROM`. Keep DHI floating tags (`dhi.io/ruby:3.4-dev`, `dhi.io/ruby:3.4`, `dhi.io/bun:1-debian13-dev`). Do not re-add digest pins or switch to unhardened `ruby:` / `oven/bun` images.
- Production runtime is shell-free. `bin/docker-entrypoint` and `HEALTHCHECK` must keep working without `/bin/sh` (they already exec via Ruby).
- Orchard pulls `dhi.io` with `DHI_USERNAME` + `DHI_TOKEN` (or `DOCKER_AUTH_CONFIG`) set as app secrets. Those keys are builder pull auth, not Rails runtime.
- Schema changes go through migrations. Do not edit `db/schema.rb` by hand. Solid Queue's tables are a normal migration in `db/migrate`, not a second database: pointing several database.yml entries at one `DATABASE_URL` makes `db:prepare` skip creating their tables.
- One signature per user per `NdaDocument::VERSION` (unique index).

## Privacy and security (non-negotiable)

The public API is the only unauthenticated data surface. `GET /api/v1/nda_status/:slack_id` may return only:

```json
{ "slack_id": "U0123ABCDEF", "status": "signed"|"not_signed", "nda_version": "...", "signed_at": "..." }
```

Never add names, email, address, birthdate, video, transcript, IP, user agent, or co-signer fields to this endpoint. Unknown IDs are `not_signed`; malformed Slack IDs (`User::SLACK_ID_FORMAT`) are HTTP 400.

Other rules:

- `XAI_API_KEY`, `HACK_CLUB_CLIENT_SECRET`, and `SECRET_KEY_BASE` stay server-side. Never send them to the browser or commit them.
- Configuration is environment variables only. There are no Rails encrypted credentials, no `config/master.key`, and no `credentials.yml.enc`; do not reintroduce them.
- `.env` is gitignored; only `.env.example` is tracked (placeholders only).
- Identity videos, transcripts, addresses, birthdates, IPs, and co-signer data are sensitive. Do not log them, dump them in errors, or include them in fixtures beyond what tests need.
- Identity videos are uploaded to R2 with SSE-C (`R2_SSE_CUSTOMER_KEY`, exactly 32 characters). Keep it that way: without SSE-C, anyone with Cloudflare dashboard access can watch them. Active Storage cannot read SSE-C objects back, which is why `config.active_storage.analyzers` is empty and why review goes through `identity_videos:download`.
- Identity videos are deleted 7 days after signing by `PurgeIdentityVideosJob`, scheduled in `config/recurring.yml` (`NdaSignature::IDENTITY_VIDEO_RETENTION`). Keep the purge path working and do not widen the window without a product decision. The R2 bucket stays private; videos are never linked publicly.
- xAI validates spoken content only, not face, raised hand, liveness, or speaker identity. Do not claim otherwise in UI copy.
- OAuth `state` must keep using `secure_compare`. Session is reset after login.

## Testing notes

- Minitest + fixtures. Fixture video: `test/fixtures/files/pledge.webm`.
- Stub `XaiTranscription.call` the same way `test/services/pledge_validator_test.rb` does.
- Pledge acceptance: token Jaccard ≥ 0.65 **and** each required concept ≥ 0.5 overlap. Keep those thresholds unless the product owner changes them.
- Video: MP4 or WebM, ≤ 25 MB.
- Minors (`user.age < 18`) require `cosigner_name` and `cosigner_email`.
- `signed_name` must case-insensitively match `legal_first_name` + `legal_last_name`.

## Do not

- Do not commit secrets, NDA PDFs of real people, or production credentials.
- Do not “fix” the legal text without a version bump and an explicit request.
- Do not replace Bun with npm/yarn, Ruby 3.4.10 with another series, or Postgres 18 with another major.
- Do not add a second source of agent instructions. Edit this file; `CLAUDE.md` is a symlink to it.
