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
- Prawn for PDF generation, in pure Ruby with the built-in Type 1 faces (no browser, no `wkhtmltopdf`)
- Bun 1.4.2 for all JavaScript (`packageManager` in `package.json`, lockfile is `bun.lock`)
- Active Storage (disk in development, Cloudflare R2 with SSE-C in production)
- Airtable holds the old signing system's NDA records and stays the shared source of truth (`AIRTABLE_TOKEN`, `AIRTABLE_BASE_ID`, `AIRTABLE_TABLE_ID`)
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
| --- | --- |
| `app/controllers/sessions_controller.rb` | OAuth start/callback/logout |
| `app/controllers/nda_signatures_controller.rb` | Signer form + create |
| `app/controllers/api/v1/nda_statuses_controller.rb` | Public status JSON |
| `app/controllers/legacy_nda_imports_controller.rb` | Legacy NDA upload, pending state, email challenge |
| `app/controllers/admin/legacy_nda_imports_controller.rb` | Review queue: approve or revoke an import |
| `app/services/legacy_nda/pades_signature.rb` | PAdES/CMS verification against a pinned certificate |
| `app/services/legacy_nda/certificate_allowlist.rb` | Pinned signing certificates (YAML + env) |
| `app/services/legacy_nda/document_text.rb` | pdf-reader extraction, glyph normalisation, page split |
| `app/services/legacy_nda/certificate_page.rb` | Documenso signing certificate page parser |
| `app/services/legacy_nda/signature_block.rb` | The AGREED block at the foot of the agreement |
| `app/services/legacy_nda/content_match.rb` | Is this the Hack Club NDA (containment + headings) |
| `app/services/legacy_nda/redactor.rb` | Strips personal data before scoring or any AI call |
| `app/services/legacy_nda/verifier.rb` | Layers 1-3 into approved / needs_review / rejected |
| `app/services/legacy_nda/claim.rb` | Identity binding; the only place an import becomes a signature |
| `app/services/legacy_nda/email_challenge.rb` | HMAC-stored one-time code to the document's address |
| `app/services/legacy_nda/airtable_record.rb` | Looks up a signed row in the old system's Airtable base |
| `app/services/legacy_nda/airtable_import.rb` | Turns a matched Airtable row into a legacy signature |
| `app/services/airtable_client.rb` | Airtable REST + attachment upload |
| `app/services/airtable_sync.rb` | Pushes a signature back to the Airtable base |
| `app/services/nda_pdf.rb` | Renders a signed agreement as a PDF |
| `app/services/loops_client.rb` | Transactional email via Loops (no ActionMailer in this app) |
| `app/services/sse_customer_blob.rb` | Reads SSE-C blobs back; Active Storage cannot |
| `app/models/legacy_nda_import.rb` | Upload workflow, audit row, retention |
| `app/jobs/verify_legacy_nda_import_job.rb` | Runs verification off the request |
| `app/jobs/import_airtable_nda_job.rb` | Looks a member up in Airtable off the request |
| `app/jobs/sync_signature_to_airtable_job.rb` | Writes a new signature back to Airtable |
| `app/jobs/attach_airtable_document_job.rb` | Fetches an imported PDF after the claim is settled |
| `lib/tasks/airtable.rake` | One-off: tag pre-existing rows with `Source` |
| `lib/tasks/legacy_documents.rake` | Decrypt one upload for review |
| `config/legacy_signing_certificates.yml` | Pinned certificate fingerprints |
| `app/services/hack_club_auth.rb` | auth.hackclub.com OAuth |
| `app/services/xai_transcription.rb` | `POST https://api.x.ai/v1/stt` multipart |
| `app/services/zero_data_retention.rb` | Shared ZDR header check for both xAI calls |
| `app/services/pledge_validator.rb` | Token overlap + required concepts |
| `app/models/user.rb` | Identity + signing details |
| `app/models/nda_signature.rb` | Signed record + video attachment + retention |
| `lib/tasks/identity_videos.rake` | Decrypt one video for review |
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
- `GET/POST /nda_signature`, `GET /nda_signature.pdf`
- `GET/POST /legacy_nda_import`, `POST /legacy_nda_import/challenge`
- `POST /legacy_nda_import/lookup`, `POST /legacy_nda_import/lookup_email`
- `GET /admin/legacy_nda_imports`, `PATCH /admin/legacy_nda_imports/:id`
- `GET /api/v1/nda_status/:slack_id`

## Conventions

- Follow existing style: RuboCop Omakase, compact Ruby, ERB that matches the current views.
- The country picker is a listbox built in `application.js` over a real `<select>` that stays in the DOM, invisible
  but laid out, so browser autofill, HTML5 validation and the no-JS fallback keep working. Country flags are
  vendored SVGs under `app/javascript/flags` (`bin/rails flags:fetch`, sourced from jdecked/twemoji); do not swap
  them for a CDN or an emoji font, which Windows does not render.
- Keep the frontend vanilla. The wizard is a small script in `application.js`; CSS is one file. Do not introduce a JS framework, CSS framework, or importmap.
- Keep JS package changes in `package.json` + `bun.lock` via `bun`.
- There are two ways out to PDF and both must keep working. `NdaPdf` renders server-side with Prawn and is what
  `GET /nda_signature.pdf` and the Airtable upload use. The `@media print` block in `application.css` is the
  browser path (`window.print()` -> Save as PDF). Keep the serif `font-family` override on `.print-contract *` (the
  UI font exports as a Type 3 font, which breaks text extraction and PDF/A), the `:root, body` white background
  (the root background paints the page box), `overflow: visible`, and the break-control rules. See "Exporting the
  signed agreement" in `README.md`.
- `NdaPdf` must stay pure Ruby. Production is shell-free, so a headless browser, `wkhtmltopdf` or anything else
  that needs a subprocess cannot run there. It uses the built-in Type 1 faces deliberately: they need no embedding
  and keep the text extractable, which is the same reason the print stylesheet forces a serif family. An embedded
  TrueType font would also work, but check `LegacyNda::ContentMatch` still passes on the output before swapping.
- Keep the Dockerfile at two stages (`build` then `production`). Bring Bun in with `COPY --from=dhi.io/bun:1-debian13-dev`, not a third `FROM`. Keep DHI floating tags (`dhi.io/ruby:3.4-dev`, `dhi.io/ruby:3.4`, `dhi.io/bun:1-debian13-dev`). Do not re-add digest pins or switch to unhardened `ruby:` / `oven/bun` images.
- Production runtime is shell-free. `bin/docker-entrypoint` and `HEALTHCHECK` must keep working without `/bin/sh` (they already exec via Ruby).
- Orchard pulls `dhi.io` with `DHI_USERNAME` + `DHI_TOKEN` (or `DOCKER_AUTH_CONFIG`) set as app secrets. Those keys are builder pull auth, not Rails runtime.
- Schema changes go through migrations. Do not edit `db/schema.rb` by hand. Solid Queue's tables are a normal migration in `db/migrate`, not a second database: pointing several database.yml entries at one `DATABASE_URL` makes `db:prepare` skip creating their tables.
- One signature per user per `NdaDocument::VERSION` (unique index).

## Privacy and security (non-negotiable)

The public API is the only unauthenticated data surface. `GET /api/v1/nda_status/:slack_id` may return only:

```json
{ "slack_id": "U0123ABCDEF", "status": "signed"|"not_signed", "nda_version": "...", "signed_at": "...", "signature_type": "native"|"legacy" }
```

`signature_type` is a deliberate addition, not drift: consumers have to be able to tell a legacy
import from a signature this app produced, because the two carry different assurance about *who*
signed. It is not PII. Nothing else may be added. Never add names, email, address, birthdate,
video, transcript, IP, user agent, envelope ID, certificate fingerprint, review state, or co-signer
fields to this endpoint. Unknown IDs are `not_signed`; malformed Slack IDs (`User::SLACK_ID_FORMAT`) are HTTP 400.
`signed_at` and `signature_type` appear only when `status` is `signed`; `nda_version` is always present.
Only `approved` imports count as signed — `needs_review` reads as `not_signed`.

Other rules:

- `XAI_API_KEY`, `HACK_CLUB_CLIENT_SECRET`, and `SECRET_KEY_BASE` stay server-side. Never send them to the browser or commit them.
- Configuration is environment variables only. There are no Rails encrypted credentials, no `config/master.key`, and no `credentials.yml.enc`; do not reintroduce them.
- `.env` is gitignored; only `.env.example` is tracked (placeholders only).
- Identity videos, transcripts, addresses, birthdates, IPs, and co-signer data are sensitive. Do not log them, dump them in errors, or include them in fixtures beyond what tests need.
- Identity videos are uploaded to R2 with SSE-C (`R2_SSE_CUSTOMER_KEY`, exactly 32 characters). Keep it that way: without SSE-C, anyone with Cloudflare dashboard access can watch them. Active Storage cannot read SSE-C objects back, which is why `config.active_storage.analyzers` is empty and why review goes through `identity_videos:download`.
- `AirtableSync` also sends a copy of the video and the transcript to Airtable, by product decision, where anyone with base access can watch it. That is a deliberate exception to the line above, not an oversight: R2 stays the encrypted store, and Airtable holds the same second copy it has always held for the old system. Airtable will only take file bytes up to 5 MB (`AirtableClient::MAX_ATTACHMENT_BYTES`) and cannot read an SSE-C object itself, so a longer video is logged and skipped. Do not work around that cap by serving videos from a public or signed URL; that would add a second unauthenticated data surface.
- Identity videos are kept for the life of the signature: there is no retention window and no scheduled purge. `purge_identity_video!` exists for a one-off deletion by hand and is deliberately not on a schedule. The R2 bucket stays private; videos are never linked publicly.
- Uploaded legacy NDAs are at least as sensitive as an identity video: they carry the signer's name, personal email, signature image, IP address, device string and full co-signer details. They go to R2 with SSE-C like videos and are kept for the life of the import, with `purge_document!` there for a one-off deletion by hand. Read them back only through `SseCustomerBlob` / `legacy_documents:download`.
- `AIRTABLE_TOKEN` stays server-side and grants write access to every personal detail in the base. `AIRTABLE_BASE_ID` and `AIRTABLE_TABLE_ID` are configuration, not secrets.
- The Airtable base is the old signing system's record of who has an NDA. It holds no Slack ID, so an email address is the only join key, and a bulk backfill is impossible — an import can only ever start from a signed-in member. A row counts as signed only when `{Signed?}` is true; 396 of its rows are people who started and never finished, and those must never read as a signature.
- An Airtable match proves somebody signed, never who is asking. Settle a claim only on the verified Hack Club Auth account email or a passed email challenge, exactly as for an uploaded PDF, and record the row id in `airtable_record_id` so one row cannot be claimed twice.
- `LegacyNda::AirtableImport.check_on_sign_in` runs one query per member, once, gated on `users.airtable_checked_at`, and the callback swallows every `AirtableClient::Error`. A login must never fail or stall because the base is slow or down, so keep the lookup out of the settling work: the PDF is fetched afterwards by `AttachAirtableDocumentJob`.
- `LegacyNda::AirtableImport.challenge!` must answer identically whether or not the address is in the base. Naming an address that is present would turn the importer into a directory of who signed an NDA.
- Airtable formulas take double-quoted strings. Every value interpolated into `filterByFormula` goes through `AirtableClient.quote`, or an address can rewrite the filter.
- `Signed?`, `Signed NDA - Last Modified At` and the `Loops - *` fields are formulas or computed; writing them fails. `Signed?` is driven by the `Signed NDA` attachment, so the only way to make a native signature read as signed in the base is to upload a rendered agreement to that field, which `AirtableSync#attach_agreement` does. `Source` records which system produced it.
- Attachment uploads append to a cell instead of replacing it, so `AirtableSync` sends files on the first sync only (`airtable_synced_at`). Dropping that guard duplicates every attachment on every later sync.
- A field name reaches `uploadAttachment` in the URL path, and `Signed NDA` contains a space. Keep it percent-encoded.
- Legacy import rejection copy must stay generic (`LegacyNdaImportsController::REJECTION`). Reason codes go to the audit record, never to the page: naming the failed check turns the importer into a forgery oracle.
- Verifying a legacy PDF proves the document is authentic Hack Club output. It proves nothing about who uploaded it, and a leaked PDF verifies perfectly. Never settle a claim without either an account-email match or a passed email challenge, and never settle one at all for a document carrying no address.
- Legacy signing certificates are trusted by pinning only (`config/legacy_signing_certificates.yml`). Do not add chain validation, do not enforce the certificate validity window — real documents were signed after it expired — and do not drop a pin that ever signed a real NDA.
- xAI validates spoken content only, not face, raised hand, liveness, or speaker identity. Do not claim otherwise in UI copy.
- OAuth `state` must keep using `secure_compare`. Session is reset after login.

## Testing notes

- Minitest + fixtures. Fixture video: `test/fixtures/files/pledge.webm`.
- Stub `XaiTranscription.call` the same way `test/services/pledge_validator_test.rb` does.
- Pledge acceptance: token Jaccard ≥ 0.65 **and** each required concept ≥ 0.5 overlap. Keep those thresholds unless the product owner changes them.
- Video: MP4 or WebM, ≤ 25 MB.
- Minors (`user.age < 18`) require `cosigner_name` and `cosigner_email`.
- `signed_name` must case-insensitively match `legal_first_name` + `legal_last_name`. Native signatures only: the video, transcript, co-signer and legal-name checks are all conditional on `signature_type == "native"`.
- Legacy fixtures are generated at test time by `test/support/legacy_pdf_factory.rb`, which builds a real PAdES-signed PDF with a throwaway key. Never commit a real person's NDA. Pin the test certificate with `LegacyNda::CertificateAllowlist.default = LegacyPdfFactory.allowlist` and `reset!` afterwards.
- Stub `LoopsClient.send_email` the way `test/jobs/verify_legacy_nda_import_job_test.rb` does. No live network anywhere.
- Stub Airtable with `AirtableStub#with_airtable` (`test/support/airtable_stub.rb`). The fake parses the `filterByFormula` the code actually builds, so an unescaped or malformed filter fails the test rather than silently matching.
- `config.active_job.queue_adapter = :test` in `config/environments/test.rb` is load-bearing. Active Job otherwise
  defaults to `:async`, which really runs enqueued jobs on a thread pool during tests, lets them reach the network,
  and then blocks process exit on their retry backoff. Do not remove it.
- `NdaPdfTest` asserts the generated PDF passes `LegacyNda::ContentMatch` (18/18 headings). That is the regression
  test for the renderer: if a layout change starts dropping or mangling text, extraction catches it.
- `LoopsClient` is a stub: the transport is real, but the challenge template still has to be built in Loops and named by `LOOPS_IMPORT_CHALLENGE_TRANSACTIONAL_ID`. The body lives in that template, not in this repo.
- Content match thresholds are provisional, measured on three real samples that all scored 1.0 containment with 18/18 headings. Gate on containment, not Jaccard: a genuine document carrying an appendix keeps containment 1.0 while its Jaccard falls.
- Not every legacy document has a signing certificate page, and not every one is `ETSI.CAdES.detached` (`adbe.pkcs7.detached` is also real). A document with no certificate page is authentic but names no address, so it can only ever reach `needs_review`.

## Do not

- Do not commit secrets, NDA PDFs of real people, or production credentials.
- Do not “fix” the legal text without a version bump and an explicit request.
- Do not replace Bun with npm/yarn, Ruby 3.4.10 with another series, or Postgres 18 with another major.
- Do not add a second source of agent instructions. Edit this file; `CLAUDE.md` is a symlink to it.
