# Final UI Polish, Data Setup & Release Commands

## 1. What changed in this update

- Brand shortcuts now appear as **New brand → Acme → Zest Foods → Skyline Travel**.
- In a new-check form, **New brand** clears the brand input so you can enter a name. The brand remains locked during resubmission.
- In Guidelines Hub / library screens, **New brand** asks for a name and opens that brand scope. It does not manufacture policies.
- Acme artwork now depicts a software dashboard; Zest depicts a food pack; Skyline depicts travel/mountains/flight.
- Banner layout uses its actual **3:1 aspect ratio and `BoxFit.contain`**, rather than a fixed-height `BoxFit.cover`. The whole banner is visible without cutting off its text.
- Your attached mint/teal chat-bubble image is used in the chatbot launcher and chat header. The empty outer canvas was cropped for readability; the selected artwork itself was not redesigned.
- Browser/PWA icons use the **same `verified_user_rounded` shield/check symbol and navy/teal colors already used by BrandMark inside your app**. No unrelated new app logo was chosen.
- Browser icon URL changed to `favicon-brandguard.png` to help avoid the cached Flutter favicon.
- Both mobile launcher scripts default to Vercel rather than old Antideploy and accept an explicit `API_BASE` environment override.

This cumulative patch also includes the earlier safe cleanup/seeding tools. You do not need to apply the older main patch first.

## 2. Answers about policies and new brands

### Should Zest Foods and Skyline Travel have rules/guidelines?

**Yes.** Otherwise the brand choices look functional but do not demonstrate meaningful brand-specific checking.

The included catalogue has **four rules and one guideline for each of the three brands**, with existing Acme phrase-policy semantics preserved. This is enough for a concise, coherent demonstration. Four brand rules do not disable the separate global checks.

Seeing only Acme policies means the current database has not yet had the other policies installed (or you are viewing a different backend). Source-code replacement does not seed a populated hosted database. Run the explicit setup workflow below against the intended environment.

### Does approving a new brand check add a brand to Guidelines Hub?

**No. These are different actions:**

1. **Submission approval:** a Reviewer approves the exact submitted version and its evidence.
2. **Policy authoring:** a Reviewer adds guidelines and enforceable rules under a brand name.

Approving a check does not turn its copy into policy, create a verified fact source, or add a permanent shortcut. This separation is intentional: user-submitted copy should not silently become the source of truth.

The three sample-brand shortcuts remain fixed. Other brands can be opened using **New brand** / the editable brand input. An authorized Reviewer must add their policies using the library modules. An automatically growing, approval-based brand directory would be a separate feature; it is not claimed here.

Unknown brands may receive only applicable global checks. The UI now warns about that limitation. A clean scan without brand-specific policies is not proof of brand compliance.

### Why are old test checks still in Review Queue?

They are stored in the live SQL database. Neither a Flutter rebuild nor a redeploy removes them. Ordinary check deletion intentionally protects reviewed decisions. Use the explicit-ID admin cleanup below; it includes backup, reference checks, and additional acknowledgement for reviewed test records.

**No live records have been deleted by this patch.**

---

## 3. Apply the patch

1. Commit or back up your local source changes.
2. Extract **`brandguard_final_polish_and_demo_patch.zip` at the repository root** (the folder with `backend/` and `mobile/`).
3. This is cumulative against latest inspected source commit `d2768d7aa51023b5129fd51c0c65be134bcf92fb`; it includes the prior main demo patch. If you changed these files yourself, compare/merge rather than overwriting blindly.
4. Keep the earlier optional Vercel adapter files if you applied them. If missing, the adapter ZIP is separate and linked alongside this patch.
5. Do not copy a completed `.env` or real credentials from another person into source control.

The patch includes updated browser icons in both `mobile/web/` and `browser_preview/`. Other Flutter UI changes still require rebuilding the compiled web bundle.

---

## 4. Choose the environment before running anything

**A. Existing hosted accounts and hosted database:** run the frontend against Vercel. No local backend is needed for normal use.

**B. Fully local rehearsal:** run a local backend using local SQLite/auth and use locally provisioned accounts. Your existing Supabase account password is not automatically valid in the local auth database.

**C. Local API using Supabase:** configure the local backend with the intended Supabase project and PostgreSQL settings. This can affect real cloud data if pointed at production. Only do this deliberately; it is not necessary just to run the client against Vercel.

The sign-in you reported worked after pointing the client to Vercel, confirming the account/server mismatch. Do not reset that working password merely because local authentication rejected it.

---

## 5. Install Python dependencies and run backend tests

Open PowerShell in the repository root. These commands assume you are testing in a development environment, not casually reusing production configuration.

```powershell
cd backend
py -3 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
.\.venv\Scripts\python.exe -m pytest -q
```

If `.venv` already exists and works, skip creating it. Calling its Python directly avoids PowerShell activation-policy problems.

Recorded backend result in the patched checkout: **176 passed, 2 skipped**. Both skips require Tesseract. Flutter is not installed in the patch-building environment, so the Flutter steps below must be run locally.

---

## 6A. Run frontend against Vercel — recommended for your existing account

In a new PowerShell terminal, starting from repository root:

```powershell
cd mobile
flutter pub get
flutter analyze
flutter test
flutter run -d chrome --dart-define=API_BASE=https://brandguard-vercel-code-nova.vercel.app
```

Run each command individually and stop on failures. This starts a local Flutter client that calls the hosted API. Sign in with your working hosted account. It does **not** use `AUTH_PROVIDER=local` from a local backend.

For a connected Android device/emulator instead of Chrome:

```powershell
flutter devices
flutter run --dart-define=API_BASE=https://brandguard-vercel-code-nova.vercel.app
```

Select the intended device if Flutter lists multiple targets. Do not start a second run command while the first is still running; stop it first with `q` or Ctrl+C.

---

## 6B. Optional fully local backend and frontend

Use a **separate local development database/configuration**. Preserve any existing `.env` before editing it; do not replace production settings unintentionally.

For isolated local mode, the relevant settings in `backend/.env` are:

```dotenv
AUTH_PROVIDER=local
SEED_DEMO_USERS=true
AI_PROVIDER=disabled
```

Also ensure `DATABASE_URL` and `BRANDGUARD_DATA_DIR` do not point to production. Existing shell environment variables can override `.env`; inspect them if behavior differs from the file.

**Terminal 1**, from repository root:

```powershell
cd backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Open `http://127.0.0.1:8000/health` to confirm the local API responds.

**Terminal 2**, from repository root:

```powershell
cd mobile
flutter pub get
flutter run -d chrome --dart-define=API_BASE=http://127.0.0.1:8000
```

With local seeding enabled, the local development accounts are `creator@brandguard.demo` and `reviewer@brandguard.demo`, password `Demo@12345`. These are **local demo credentials only**, not promises that those users exist in hosted Supabase.

For a standard Android emulator, the host machine's local API is normally `http://10.0.2.2:8000`; use a development build with suitable cleartext configuration. For a physical phone, use the computer's reachable LAN IP and verify the firewall/Wi-Fi setup. Never distribute a release APK targeting those development addresses.

Stop the backend with Ctrl+C when finished. Local mode will not clean the production database.

---

## 7. Back up and inventory the actual hosted database

This is trusted administration, not a frontend command. Use a secure backend environment configured with the **actual target PostgreSQL database**. The local SQLite database is a different dataset.

The CLI reads `backend/.env` and process environment. Confirm `AUTH_PROVIDER`, database type, and target host without publishing secrets. Do not send your `.env` or database password to the assistant.

From `backend/`:

```powershell
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
.\.venv\Scripts\python.exe manage.py backup --output ".demo-private/pre-demo-$stamp.json"
.\.venv\Scripts\python.exe demo_admin.py inventory --out ".demo-private/inventory-$stamp.json"
Copy-Item .\demo\selection.example.json ".demo-private/selection-$stamp.json"
```

Keep this PowerShell terminal open so `$stamp` stays defined. The outputs are private and must not be committed or shared publicly.

Open the inventory and selection files. Put **only real, approved disposable test IDs** in the arrays. Review checks, standalone drafts, stale notifications, and related records. Do not select real submissions just to make counts smaller.

Private storage and Supabase Auth identities are not backed up by the two application-table exports; handle those separately if needed. This cleanup does not delete them.

---

## 8. Preview and apply approved cleanup

From the same backend PowerShell terminal:

```powershell
.\.venv\Scripts\python.exe demo_admin.py plan --selection ".demo-private/selection-$stamp.json" --out ".demo-private/plan-$stamp.json"
```

**Stop and inspect the plan.** Check every proposed deletion and all blockers. If a retained record references a selected record, resolve the scope deliberately. Do not simply disable the safeguard.

Avoid app traffic/login/activity writes between plan and apply: the entire application snapshot is checked for changes. A stale plan is refused rather than applied speculatively.

After approval:

```powershell
$confirmation = (Get-Content ".demo-private/plan-$stamp.json" -Raw | ConvertFrom-Json).snapshot_sha256
.\.venv\Scripts\python.exe demo_admin.py apply --plan ".demo-private/plan-$stamp.json" --backup ".demo-private/transaction-backup-$stamp.json" --confirm $confirmation
```

If and only if the approved plan includes previously reviewed **test** records, use this version instead:

```powershell
.\.venv\Scripts\python.exe demo_admin.py apply --plan ".demo-private/plan-$stamp.json" --backup ".demo-private/transaction-backup-$stamp.json" --confirm $confirmation --allow-reviewed-test-records
```

Do not run both apply commands after a successful apply. If the database changed, regenerate and approve a new plan with a new output filename. Never delete the only backup to make a retry command work.

Known check-linked receipts/seals/etc. are included in the plan. Audit history, users, assets, and policies remain preserved. Unrelated orphan files/records and old library entries need separate review; this is not a blind garbage collector.

---

## 9. Seed all three brands and the coherent workflow

Before this step:

- Back up the target database, including if no cleanup was needed.
- Provision distinct confirmed **Creator** and **Reviewer** accounts using supported administration.
- Use a dedicated empty Creator workspace after approved cleanup.
- Review current extra brand rules before choosing `--archive-extra-rules`.
- Review old facts and guidelines for unrelated test clutter separately.

From `backend/`, enter actual account emails (passwords are prompted by the tool):

```powershell
$creatorEmail = Read-Host "Dedicated demo Creator email"
$reviewerEmail = Read-Host "Provisioned demo Reviewer email"
.\.venv\Scripts\python.exe demo_admin.py seed --base-url https://brandguard-vercel-code-nova.vercel.app --confirm-origin https://brandguard-vercel-code-nova.vercel.app --creator-email $creatorEmail --reviewer-email $reviewerEmail --state .demo-private/production-seed-state.json --archive-extra-rules --with-assets
```

The archive flag removes extra *current* rules only for the three curated brands through the library API, retaining historical versions. The stock Acme extras are `COMP-14`, `VIS-02`, and `VIS-05`; the actual live library must be inspected. Global rules remain.

`--with-assets` uploads Acme/Zest campaign PNGs and links them to checks. For a text-only baseline, omit that flag **on the first run**. Do not change mode halfway through a seed state.

Result:

- Four current brand rules and one added curated guideline per brand.
- Acme approved through a real Reviewer action.
- Zest pending with actual policy findings.
- Skyline saved as a separate draft.
- Acme content/assets successfully verified before success is reported.

If only Acme was visible before, this is the step that installs the other brands' actual policies. It is not performed automatically by the ZIP.

### If the tool stops

Read the error and private state. Do not delete the state file and start over: that can duplicate prior successful writes. An `inflight` marker means a mutation outcome is uncertain; reconcile the actual server record before retrying. See `DEMO_SETUP_AND_RELEASE.md` for the full retry/recovery procedure.

Seeding does not silently erase differently titled old guidelines or fabricate verified facts. Clean those through a separate reviewed library action where appropriate.

---

## 10. Rebuild the deployable web bundle

From repository root:

```powershell
cd mobile
flutter pub get
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn
Copy-Item -Path .\build\web\* -Destination ..\browser_preview\ -Recurse -Force
```

Do not skip the copy step: the optional Vercel adapter publishes `browser_preview` into `public`.

This web release uses the deployed same-origin backend by default. Do not embed a development localhost URL in a public web build.

---

## 11. Build the final APK

Still inside `mobile/`:

```powershell
flutter doctor
flutter build apk --release --dart-define=API_BASE=https://brandguard-vercel-code-nova.vercel.app
```

If doctor reports missing Android tools, resolve them first. APK output:

```text
mobile\build\app\outputs\flutter-apk\app-release.apk
```

Install this newly built APK and test both roles. Do not accidentally share an earlier APK from another folder.

---

## 12. Push and redeploy

From repository root, review exactly what will be committed:

```powershell
git status --short
git diff --stat
```

Stage only the intended source, branding, web output, and configuration files. Never stage `.env`, `.demo-private`, backups, tokens, or database files. Use your normal reviewed commit/push process, then deploy the intended commit to the existing Vercel project/domain.

If this latest repository lacks Vercel's entrypoint/config, apply the separate adapter ZIP first. Keep existing server-side Supabase/PostgreSQL/storage secrets in Vercel. Never put cleanup or seeding commands in a build/start hook.

After redeployment:

1. Open `/health` and the root application.
2. Hard-refresh or test an incognito window for the new favicon and compiled UI.
3. If an old installed PWA still shows cached artwork/UI, update/reinstall it or clear only this site's cached app data; this can sign you out.
4. Confirm both roles sign in.
5. Check all three brand libraries and New brand behavior.
6. Confirm old test checks within the approved cleanup scope are gone.
7. Verify the retained Acme approval, Zest pending submission, and Skyline draft.
8. Confirm the selected chatbot avatar and uncropped banners on narrow screens.
9. Confirm the rebuilt APK points to the same Vercel backend.
10. Verify confirmation/reset redirects where enabled.

## 13. Readiness boundary

The backend suite passes locally. This environment cannot run Flutter or Android builds, perform your authenticated production cleanup, or verify your final Vercel deployment. Treat the local Flutter checks and production smoke tests above as release gates—not optional paperwork.

No live checks, policies, users, or stored files were changed during creation of this patch.
