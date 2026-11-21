# Curated BrandGuard Setup & Release Guide

## Read this first

This patch was prepared against repository **`smeet-jari18/smeet-jari18-Brand_Guard-App`**, commit **`d2768d7aa51023b5129fd51c0c65be134bcf92fb`**.

The agreed backend target is **https://brandguard-vercel-code-nova.vercel.app**.

**Replacing source files does not delete cloud database rows or prepare demonstration accounts.** The patch includes explicit administration commands for those tasks. Nothing automatically wipes data on startup, signup, app launch, or deployment.

**No live database deletion or seed operation has been executed by the assistant.** Only an unauthenticated health check was performed against Vercel; it returned HTTP 200. All automated mutation tests ran against isolated local test databases.

---

## 1. What is included

### Main patch

- Three selectable sample-brand shortcuts: **Acme, Zest Foods, Skyline Travel**.
- Original branded artwork bundled with Flutter; no external image URL dependency.
- Brand selection in Guidelines Hub, with the selected scope carried into guidelines, rules, and facts screens.
- Editable custom-brand fields remain available; this is not an artificial restriction to only three brands forever.
- Protection against stale library responses when switching brands quickly.
- Chatbot brand shortcuts and a brand-aware “Summarize … rules” suggestion.
- Native API default changed from Antideploy to the agreed Vercel host.
- A twelve-rule policy catalogue using supported regex rules and real grounding text.
- Trusted CLI for inventory, explicit-ID cleanup plans, backup-before-delete execution, and real API-based seeding.
- Three optional uploadable campaign images, separate from the decorative brand cards.
- Backend regression tests and Flutter brand-selector widget tests.
- Ignore rules to keep private administration exports out of Git and deployment images.

### Separate optional Vercel adapter patch

The latest source snapshot contains Antideploy deployment files but **does not contain the Vercel `main.py` / `vercel.json` adapter** present in your other deployed repository. The separate adapter ZIP restores that deployment shape without mixing it into the main data/UI patch.

Apply it if you will deploy this latest repository directly to the existing Vercel project. If your local folder already has customized Vercel configuration, compare first rather than blindly replacing it.

### Explicitly not done automatically

- No cloud SQL/auth/storage credentials are supplied.
- No users are created or granted Reviewer privileges by the seed command.
- No authentication identities or stored files are deleted.
- No audit history is erased.
- No fake facts, fake approvals, fabricated receipts, hardcoded dashboard counts, or fabricated notification events are inserted.
- No historical policy versions are erased.
- No paid AI provider is enabled.
- No compiled Flutter web bundle or APK is included: rebuild them on your machine.

---

## 2. Apply files safely

1. Commit or back up your local working folder.
2. Extract `brandguard_curated_demo_patch.zip` into the **repository root**—the folder containing `backend`, `mobile`, and `README.md`.
3. Merge/replace the listed files. Do not extract into an extra nested repository folder.
4. If deploying this latest repository to Vercel, apply `brandguard_vercel_adapter_patch.zip` at the same root after reviewing it.
5. Read the included file manifest and inspect the diff.

The ZIP does **not** overwrite `backend/data/brand_rules.json`. Merely changing that file would not update a populated SQL database, and replacing its full policy history would be unsafe. Policies are installed explicitly through the supported library API instead.

---

## 3. Prepare Python and verify code

From the repository root on Windows PowerShell:

```powershell
cd backend
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements-dev.txt
python -m pytest -q
```

If you already have a working virtual environment, activate it rather than creating another.

For local rehearsal, use a separate, non-production `backend/.env` / database with local auth, AI disabled, and seeded local accounts. For production maintenance, use the actual deployed PostgreSQL configuration in a **trusted admin environment**.

**Important:** the CLI uses the `DATABASE_URL` loaded by this checkout. A local SQLite inventory cannot clean Vercel's Supabase database. Verify which database is targeted before planning anything.

- Run administration commands from `backend/` so relative bundled certificate paths resolve as expected.
- Never paste database credentials into command history or send them to another person unnecessarily.
- Do not point a running local development server at production while experimenting.
- Keep backups, plans, inventory, and seed state in `backend/.demo-private/`, which is ignored by this patch. On Windows, also restrict folder permissions through your OS account/security settings; POSIX mode bits alone are not a Windows ACL policy.

---

## 4. Back up and inventory the target database

Do this before cleanup **and before policy seeding**, including when the Creator workspace is empty.

```powershell
python manage.py backup --output .demo-private/pre-demo-full-backup.json
python demo_admin.py inventory --out .demo-private/inventory.json
```

Commands refuse to overwrite existing output files. Use a new meaningful filename for each attempt; do not casually delete your only backup.

The database backup is compatible with the existing trusted `manage.py restore` command. It contains private data and may include password/session information. Back up private storage objects separately when needed, and preserve required server secrets securely. Application-table backups are not complete Supabase Auth backups.

The private inventory includes:

- Check IDs, owners, statuses, brand names, and short content previews.
- Draft, notification, conflict, override, and clarity-ticket IDs.
- Current brand policy details for review.
- Existing guidelines/fact entries for manual review.
- An empty selection template.

**Do not upload inventory or backup files to GitHub.**

### Inspect existing policies before archiving

The checked-in Acme seed currently includes these extra brand rules:

- `COMP-14`
- `VIS-02`
- `VIS-05`

The two base/global rules (`BG-001`, `BG-002`) are separate and remain enabled. Four curated rules per brand means **four brand-specific rules, plus applicable global checks**, not necessarily only four findings or four total engine rules.

If the current cloud library differs, inspect the inventory rather than assuming these are the only extra rules.

---

## 5. Select only approved test records

Create `.demo-private/selection.json` using the inventory's `selection_template`:

```json
{
  "check_ids": [],
  "draft_ids": [],
  "notification_ids": [],
  "ticket_ids": [],
  "conflict_ids": [],
  "override_ids": []
}
```

Insert **actual IDs copied from the inventory** for disposable test records only. Empty arrays mean “remove none from this category”, not “remove all”.

- Selecting a check also selects known check-linked receipts, approval seals, overrides, conflicts, and notifications.
- Nested versions/decision history inside the selected check are archived in the database backup and removed with the selected parent record.
- Standalone drafts and old notifications need their own explicit IDs when not linked to selected checks.
- Retained child checks, shared clarity tickets, or other records that reference selected IDs can block the plan. Review those relationships; do not bypass the guard by changing its code.
- If a clarity ticket is entirely disposable test data, select its real ID too. If it also represents real activity, preserve it and reconsider deleting its referenced history.
- Audit history is intentionally exempt from orphan blocking because it remains a historical record of removed test IDs.

### Generate the dry-run plan

```powershell
python demo_admin.py plan --selection .demo-private/selection.json --out .demo-private/cleanup-plan.json
```

Open the resulting plan. Check **every deletion**, `reviewed_check_ids`, and `blockers` with the project owner. This command does not delete anything.

The plan is tied to an exact snapshot of both application tables. Any concurrent database change invalidates it—including login/session or activity writes. Use a quiet maintenance window, avoid opening the app between planning and applying, and regenerate/review a new plan if necessary. This strict behavior is intentional; the tool does not silently relax it.

### Apply after explicit approval

```powershell
$confirmation = (Get-Content .demo-private/cleanup-plan.json -Raw | ConvertFrom-Json).snapshot_sha256
python demo_admin.py apply --plan .demo-private/cleanup-plan.json --backup .demo-private/cleanup-transaction-backup.json --confirm $confirmation
```

If the approved plan includes previously reviewed test checks, the normal command intentionally refuses. Only after approval to remove those test decisions, run:

```powershell
python demo_admin.py apply --plan .demo-private/cleanup-plan.json --backup .demo-private/cleanup-transaction-backup.json --confirm $confirmation --allow-reviewed-test-records
```

The tool writes an exclusive, durable pre-delete backup inside the database transaction **before** deleting rows. It then records a new maintenance audit event. Failure rolls back database changes. A backup file may remain after a failed transaction; preserve it and use a new output filename for a deliberate retry.

**No blanket “delete all” command exists.**

---

## 6. Review leftover policies, sources, and files

The explicit workflow-record cleanup deliberately does not purge files, identities, rules, guidelines, facts, or unknown orphan records.

Use the inventory and authorized library UI to review old guideline/fact clutter. Remove only confirmed disposable entries through supported actions after checking retained dependencies. If an entry is needed to explain a retained approval, preserve its history.

Do not empty the Supabase bucket. Retained checks, historical versions, uploaded fact sources, drafts, and policy templates may reference old assets. File garbage collection requires a separate retained-reference inventory and explicit approval.

If you need this further cleanup, create a separate manifest; do not expand SQL deletion scope opportunistically during the demo reset.

---

## 7. Provision two dedicated accounts

Use supported account administration and actual confirmed email addresses:

- **Demo Creator:** role `creator`, empty submitted history and drafts after the approved cleanup.
- **Demo Reviewer:** role `reviewer` (or an appropriate authorized admin account), a different user identity.

The normal backend tool supports provisioning accounts:

```powershell
python manage.py create-user --help
```

Use its supported options and follow secure prompts. In Supabase mode, admin provisioning may require a server-only administrative key; do not put it in Flutter. Public signup does not grant Reviewer access.

Confirm both logins work. Do not seed into a personal account with unrelated real work. The seed command refuses a nonempty Creator workspace on its first run.

---

## 8. Install policies and genuine workflow examples

The current Vercel API must expose compatible library, check, review, draft, and verification routes. If your current deployment is older/incompatible, deploy the backend adapter/code first without running seed on startup; then run this step. Otherwise data setup can precede the final client redeploy.

### First inspect archive scope

The seed command preserves existing matching Acme rules `ACME-001` / `ACME-002`. If an existing curated rule has different pattern, text, severity, or enabled state, it stops rather than silently overwriting it. Review changes through normal policy versioning.

To reach exactly four current brand rules, `--archive-extra-rules` removes **all current rules not in this patch's curated four** for each of the three selected brands, using the normal Reviewer library DELETE API. This creates new policy versions and preserves historical versions. Review the current library before choosing that flag.

It does not remove other brands or base/global rules.

### Recommended deterministic baseline

The following is a PowerShell multiline command; keep the backtick as the final character on each continued line. Replace the two email examples with the actual provisioned accounts.

```powershell
python demo_admin.py seed `
  --base-url https://brandguard-vercel-code-nova.vercel.app `
  --confirm-origin https://brandguard-vercel-code-nova.vercel.app `
  --creator-email creator@your-domain.example `
  --reviewer-email reviewer@your-domain.example `
  --state .demo-private/production-seed-state.json `
  --archive-extra-rules
```

Passwords are prompted, not included in command-line arguments or the state file. Use `--archive-extra-rules` only after approving that scope. Without it, the command stops on unexpected current brand rules and lists them.

### Include actual image attachments

If you want the approved Acme and pending Zest submissions to include uploadable campaign images, add this flag **on the first seed run**:

```text
--with-assets
```

The command uploads the Acme and Zest images through the private file API, links them to the corresponding checks, and supplies asset IDs during approval verification. Skyline's third image is available for manual experimentation; its saved draft starts without attachments.

This is optional because OCR availability and image-inspection latency depend on the hosting runtime. The decorative brand artwork still appears in the app without this flag.

### What the command actually does

1. Logs in using two distinct provisioned roles.
2. Checks the initial Creator workspace is empty.
3. Installs missing curated rules, optionally archives extra current rules, and adds missing titled guidelines.
4. Does not overwrite different existing curated rules or different same-title guidelines.
5. Runs live preflight on clean and triggering copy for all three brands.
6. Optionally uploads Acme/Zest campaign images.
7. Creates an Acme check as Creator and approves it as Reviewer through the real decision endpoint.
8. Creates a Zest check with “100% organic” and “zero sugar”, and leaves it pending.
9. Saves a separate Skyline draft.
10. Verifies the Acme approval, requiring a valid result before reporting success.

Expected starting workspace:

| Item | Brand | State |
|---|---|---|
| Team-workflow copy | Acme | Approved submitted check, real seal/receipt evidence |
| Snack campaign | Zest Foods | Pending submitted check, actual grounded findings |
| Weekend campaign | Skyline Travel | Saved editable draft, not a human approval |

Guidelines are shared brand content. A new user's checks, drafts, receipts, notifications, and counts remain their own. No private sample records are exposed to everyone.

### Existing library entries

The script adds one missing curated guideline per brand; it does **not** delete differently titled old entries. Review them separately in Step 6 if you want exactly one visible guideline. No facts are fabricated or automatically verified.

### Safe retry behavior

- Reuse the same private state file when resuming the same setup on the same origin/accounts.
- Never delete the state file merely to retry; that can duplicate records.
- A mutation is marked `inflight` before it is sent. If the process crashes or times out after a request, the command refuses blind retries because the server might already have committed.
- Inspect the exact step, method, and path in `inflight`, then inspect live data through authorized APIs/UI.
- If the operation succeeded, reconcile `steps` with the **actual returned record / ID** and remove `inflight` only after verification. Never fabricate a response or approval state.
- If it definitively did not occur, remove only the failed `inflight` marker after checking; keep successful prior steps.
- Reusing state is duplicate-resistant, not a server-wide idempotency guarantee. It does not reset content modified later by visitors, nor does it prevent simultaneous runs from two machines.
- Never change `--with-assets` or `--archive-extra-rules` halfway through one seed state.

Policy/workflow API writes are individually committed, not one cross-request transaction. This is why the earlier full backup, private journal, and manual review matter.

---

## 9. What the images are for

### Bundled decorative cards

```text
mobile/assets/brands/acme.png
mobile/assets/brands/zest_foods.png
mobile/assets/brands/skyline_travel.png
```

These are local artwork shown near brand shortcuts. They are not uploaded evidence or claims that OCR ran. Flutter `pubspec.yaml` includes them, so web and Android do not depend on an image CDN.

### Uploadable creative examples

```text
demo_samples/acme_campaign.png
demo_samples/zest_foods_campaign.png
demo_samples/skyline_travel_campaign.png
```

- Acme and Skyline use non-triggering example wording.
- Zest deliberately contains “100% organic” and “zero sugar” for supported rule demonstrations.
- All artwork is original programmatically drawn demonstration material, labelled fictional and not a real offer.
- These are campaign samples, not screenshots and not final app/chatbot launcher logos.
- Even without OCR, the Zest submission caption contains the same restricted phrases, so deterministic text evidence remains demonstrable. Do not describe caption findings as image findings unless their actual origin is OCR.

The original Acme visual/compliance rules are outside the four-rule baseline when archived. This patch does not claim to demonstrate visual palette/logo enforcement in that baseline. Use separate reviewed visual policies if you want to showcase those capabilities later.

---

## 10. Test and rebuild Flutter

From the repository root:

```powershell
cd mobile
flutter pub get
flutter analyze
flutter test
```

If dependencies/assets are stale, run `flutter clean`, then repeat `flutter pub get`. Fix test/analyzer failures before release. Changes near the brand input add visible content and can affect tests that assume a specific scroll position.

### Rebuild the web application

```powershell
flutter build web --release --no-web-resources-cdn
Copy-Item -Path .\build\web\* -Destination ..\browser_preview\ -Recurse -Force
```

The web build remains same-origin by default. The Vercel adapter copies `browser_preview` into `public` during its Linux build. **Changing Dart files without rebuilding/copying the web bundle will leave the deployed UI unchanged.**

Do not copy private administration exports into `public` or `browser_preview`.

### Build Android

```powershell
flutter build apk --release --dart-define=API_BASE=https://brandguard-vercel-code-nova.vercel.app
```

Output:

```text
mobile\build\app\outputs\flutter-apk\app-release.apk
```

The source default is now Vercel, but the explicit flag makes the release target unambiguous. Install this newly built APK rather than redistributing an older file.

---

## 11. Redeploy to Vercel

1. If using this latest GitHub repository, link it to the intended Vercel project and keep the existing production domain assignment.
2. Apply/review the optional adapter ZIP if these files are missing.
3. Keep server-side Supabase/PostgreSQL/storage settings configured in Vercel. Changing the connected repository does not mean copying secrets into Git.
4. Use `AUTH_PROVIDER=supabase`, `SEED_DEMO_USERS=false`, an appropriate persistent PostgreSQL `DATABASE_URL`, and the correct public URL/redirect configuration.
5. Do not enable paid AI merely for this demo. Check actual runtime provider status and source availability.
6. Commit the intended source changes and freshly built `browser_preview` assets. Check `git status` before pushing.
7. Redeploy and test root, `/health`, sign-in, and the three brand library scopes.
8. Verify Supabase's allowed `/auth/confirm` and `/auth/reset` URLs match the deployed routes used by the app.
9. Check both Creator and Reviewer flows in the browser and the rebuilt APK.

Do not run maintenance or seed commands as a Vercel build/start command. They are explicit trusted administration tasks only.

The adapter reuses your previously deployed Vercel entrypoint/configuration shape. Actual Vercel build/deployment has not been executed in this environment.

---

## 12. Test status

Executed against this patched checkout in isolated local databases:

- Full backend suite: **176 passed, 2 skipped**.
- Secure backend suite: **136 passed, 2 skipped**.
- New maintenance tests: **13 passed**, included in the above totals.
- Both skipped tests require an unavailable Tesseract OCR executable.
- One dependency deprecation warning concerns Starlette/httpx; it is not a failed test.

The tests exercise explicit cleanup scope, blocker detection, reviewed-record protection, backup creation, stale-plan refusal, real API approval/receipt verification, repeat execution without duplicate checks, four current rules per brand, historical Acme policy retention, and seeding with/without actual image uploads.

**Flutter SDK is not installed in this environment.** The Dart changes and widget tests are supplied, but `flutter analyze`, `flutter test`, APK generation, and the rebuilt web bundle must be verified on your machine. This guide does not claim those have passed here.

---

## 13. Final verification checklist

- [ ] Current deployment uses the intended database and backend origin.
- [ ] Backup is private and a recovery procedure has been checked.
- [ ] Explicit keep/delete scope approved before cleanup.
- [ ] No real user records, identities, or files removed.
- [ ] Audit and policy history preserved.
- [ ] Three brand shortcuts and correct artwork visible.
- [ ] Guidelines modules keep the selected brand scope.
- [ ] Four current brand-specific rules per brand; base rules remain separate.
- [ ] Acme approval verifies; changing its text fails identity verification appropriately.
- [ ] Zest pending item is visible to Reviewer with grounded findings.
- [ ] Skyline draft reopens correctly.
- [ ] New signup sees shared policies but not Demo Creator's private records.
- [ ] No stale/test guidelines or facts left in the approved cleanup scope.
- [ ] Actual dashboard counts match retained records.
- [ ] Uploaded sample previews/downloads work if `--with-assets` was used.
- [ ] AI/OCR status is represented honestly.
- [ ] Flutter analyzer/tests pass locally.
- [ ] New APK reaches Vercel, not old Antideploy or loopback.
- [ ] Fresh web bundle deployed, not just Dart source.
- [ ] Curated accounts no longer used for random development tests.

## 14. Recovery

For application database recovery, use the existing trusted restore tool only after confirming the target environment and backup:

```powershell
python manage.py restore --input .demo-private/pre-demo-full-backup.json --confirm-overwrite
```

**Warning:** this replaces both application tables, including unrelated changes made after the backup. Stop writes and obtain explicit approval first. Do not restore production casually just to undo a single demo action. Auth identities and private object bytes require their own recovery procedures. The cleanup tool itself does not delete those.

Prefer a staging rehearsal and careful manifests over depending on a full-production rollback.
