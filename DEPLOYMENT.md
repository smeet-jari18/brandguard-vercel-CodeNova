# Deploy BrandGuard on Vercel

**One project, one domain:** Vercel serves the committed Flutter web build at `/`; a Python 3.13 FastAPI function handles `/api/v1/*`, `/auth/confirm`, `/auth/reset`, `/docs` and `/health`. Supabase stores accounts, database rows and private files. No Flutter SDK, Docker daemon, or local SQLite database is required on Vercel.

## 1 · Import the cleaned source

Extract the ZIP and push its contents (including dotfiles) to a **new Git repository**, with `vercel.json` at its root. Alternatively, apply the supplied migration patch to a clean checkout of the original commit `d2768d7aa51023b5129fd51c0c65be134bcf92fb`, then commit and push. Simply overlaying a ZIP on the old repo **does not delete** obsolete tracked files.

In **Vercel → Add New → Project**, import the updated repo. **Root Directory: `.` · Framework: FastAPI**. Keep install/build/output overrides off: `vercel.json` supplies the build command, which copies `browser_preview/` to `public/`. Do not choose `mobile/`, `backend/` or `browser_preview/` as root. Decide which stable production domain you will use (not a changing preview URL).

## 2 · Connect the intended Supabase project

Reuse the BrandGuard project if it already holds your data. For a new project, run `backend/migrations/001_core.sql`, then `backend/supabase/002_private_storage.sql`, then `backend/supabase/003_temporary_demo_expiry.sql`. For an existing database, verify migrations and policies rather than resetting it. See [Supabase setup](docs/SUPABASE_SETUP.md) for the bucket's image MIME types and trusted role assignment.

Add these under **Vercel → Project Settings → Environment Variables → Production**. Replace every example with your own value. Use a separate test database for Preview, or leave Preview unconfigured. Never add database passwords or private keys to Flutter, Git or chat.

| Variable | Value |
|---|---|
| `AUTH_PROVIDER` | `supabase` |
| `SEED_DEMO_USERS` | `false` |
| `SUPABASE_URL` | Your project's HTTPS API URL |
| `SUPABASE_PUBLISHABLE_KEY` | Its publishable (or legacy anon) key, not the service role key |
| `DATABASE_URL` | Your PostgreSQL **session pooler** URI; URL-encode the password. Example format below. |
| `SUPABASE_STORAGE_BUCKET` | `brandguard-files` (private) |
| `PUBLIC_APP_URL` | Your stable production origin, e.g. `https://YOUR-PROJECT.vercel.app` |
| `AUTH_REDIRECT_URL` | The same origin followed by `/auth/reset` |
| `AI_PROVIDER` | `disabled` unless intentionally enabling a paid or free provider |

Example DB format: `postgresql+psycopg://postgres.PROJECT_REF:ENCODED_PASSWORD@POOLER_HOST:5432/postgres?sslmode=verify-full&sslrootcert=certs/supabase-prod-ca-2021.crt&connect_timeout=10`. Use the host and user from **Connect** in your project; verify that its CA matches the bundled public certificate, or supply the correct public CA. Don't disable TLS verification. Same-origin web doesn't require permissive CORS.

## 3 · Cut over login and email

- Supabase → **Authentication → URL Configuration**: set Site URL to `PUBLIC_APP_URL`. Allowlist the full HTTPS URLs ending in `/auth/confirm` and `/auth/reset`.
- If using the app's signed **Send Email Hook**, point it at `PUBLIC_APP_URL/api/v1/auth/hooks/email`. Set `SUPABASE_EMAIL_HOOK_SECRET` to the matching signing secret in Vercel, plus `RESEND_API_URL=https://api.resend.com`, your own `RESEND_API_KEY`, and `EMAIL_FROM` at a verified sender domain. No keys are injected automatically.
- Alternatively disable the previous hook, configure your own SMTP delivery in Supabase, and verify the email templates send confirmation and recovery to the intended domain. Don't leave a stale hook enabled. Test with an actual inbox.
- Rotate or disable any previously published hosted demo credentials before enabling public access. Keep local demo users disabled. Remove retired callback URLs after cutover. Deleting repository files does not turn off an old hosting account.

## 4 · Deploy and verify

Click **Deploy** (redeploy after changing environment settings). Check `/` loads Flutter, `/health` returns JSON, `/api/v1/auth/config` reports `supabase` and `demo_accounts_enabled: false`, and `/auth/reset` displays the reset page. Then confirm a new signup, sign in, reset a password and upload a small private test file. A green health check alone doesn't verify auth email or Storage. If root loads but API returns 500, check Function Logs, pooler credentials, TLS certificate and auth settings.

**Runtime limits:** This setup does not package the native Tesseract executable: image OCR reports `tesseract_not_installed` if absent. Use a runtime with Tesseract if OCR is required. Vercel Functions' request/response payload limit is 4.5 MB, below the app's 5 MB file limit: keep uploads under 4 MB including multipart overhead. Larger files need a direct-storage design. In-memory login throttling is per instance; configure provider/edge limits for a public deployment.

For native builds, substitute your real domain in `flutter run --dart-define=API_BASE=https://YOUR-PROJECT.vercel.app`. For web UI changes rebuild `mobile/` with `flutter build web --no-web-resources-cdn` **without** an `API_BASE`, replace `browser_preview/` with the generated web files, and redeploy.
