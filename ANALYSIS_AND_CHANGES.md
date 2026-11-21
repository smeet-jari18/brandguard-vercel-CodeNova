# Repository Analysis & Patch Summary

## Source inspected

- Repository: https://github.com/smeet-jari18/smeet-jari18-Brand_Guard-App
- Commit: `d2768d7aa51023b5129fd51c0c65be134bcf92fb`
- Agreed release backend: `https://brandguard-vercel-code-nova.vercel.app`
- Cleanup approach selected by owner: inventory and explicitly approved IDs, not blanket reset.

## Findings that shaped the implementation

| Finding | Why it matters | Patch response |
|---|---|---|
| SQL is the default storage repository; JSON files are seed material. | Replacing `backend/data` files would not clear existing hosted records. | Explicit trusted database inventory/plan/apply tooling; no startup reset. |
| Domain objects live in generic `bg_entities` and `bg_documents` tables. | SQL foreign-key cascades cannot be assumed for check-related JSON references. | Known-dependent closure plus fail-closed retained-reference scanning. |
| Ordinary check DELETE rejects reviewed/approved content. | Old approved test data cannot safely be removed through the ordinary Creator delete button. | Explicit admin-only local maintenance command, private backup, owner-reviewed manifest, and extra reviewed-record acknowledgement. |
| Acme currently includes two phrase rules plus `COMP-14`, `VIS-02`, `VIS-05`. | Adding two new Acme rules without archiving extras would not produce the agreed four-rule baseline. | Optional explicit `--archive-extra-rules` uses the policy API to remove extras from the current version while retaining old versions. |
| Global placeholder/absolute-claim rules are separate from brand rules. | “Four rules per brand” must not imply only four engine checks overall. | Preserve both global rules and document their additional findings. |
| Guidelines Hub was hardcoded to Acme. | Other seeded brands would not have a first-class library entry point. | Three brand shortcuts and selected-brand propagation to library modules. |
| Library requests can race during scope switching. | A slow previous response could display another brand's entries. | Request-generation guards in hub and library list loads. |
| Native client default was old Antideploy. | New APK could call a different backend from the web client. | Default switched to the owner-confirmed Vercel URL; explicit release build command documented. |
| Assistant quick prompt named Acme regardless of selected scope. | Users could ask the wrong brand question accidentally. | Brand-aware prompt and three scope shortcuts. |
| No final brand artwork was bundled. | First-use brand choices lacked visual identity. | Three original local brand-card PNGs and three distinct uploadable campaign PNGs. |
| Auth identities and file bytes have separate lifecycles. | A SQL backup is not a full auth/storage backup, and bucket deletion is unsafe. | Preserve both by default and document separate review/recovery requirements. |
| Latest repo lacks root Vercel entrypoint/configuration. | Pushing it to the existing Vercel project is not equivalent to the older Vercel-specific repo. | Separate optional adapter based on the previously deployed configuration. |
| Flutter Web is precompiled in `browser_preview`. | Dart-only changes do not update the deployed browser UI. | Explicit rebuild/copy/redeploy steps. |

## Final curated content

### Shared policies

- Acme: existing `ACME-001` and `ACME-002`, plus `ACME-003` and `ACME-004`.
- Zest Foods: `ZEST-001` through `ZEST-004`.
- Skyline Travel: `SKY-001` through `SKY-004`.
- One curated guideline per brand is added if missing; old differently titled entries are not silently deleted.
- No fabricated factual sources or automatic fact verification.

### Dedicated Creator workspace

1. Acme submitted check with genuine Reviewer approval and seal/receipt evidence.
2. Zest submitted check left pending, with “100% organic” and “zero sugar” findings.
3. Skyline saved draft, not an extra submitted check.

A fresh user continues to see only their own private workflow records while reading the shared brand library.

## Safety boundaries

- No production data was changed during patch creation.
- Cleanup IDs must come from an inventory; no wildcard deletion exists.
- Plans include known dependent rows and reject retained references.
- Plans become invalid if the database changes after review.
- Database cleanup writes a private pre-delete backup and a maintenance audit event.
- Reviewed test checks require an additional explicit flag.
- Existing audit history, all users/auth identities, assets, policy documents, facts, and unselected rows are preserved by database cleanup.
- Policy seeding is a separate explicit action, with historical rule versions retained.
- Seeding is journaled and refuses blind retries after uncertain mutation outcomes.
- This is not a complete arbitrary-data garbage collector. Unrelated/orphan files, library clutter, unknown orphan rows, and auth accounts require separate approved handling.

## Validation actually performed

- Secure baseline on this source before new maintenance tests: **123 passed, 2 skipped**.
- Patched secure suite: **136 passed, 2 skipped**.
- Patched full backend suite, including legacy and secure tests: **176 passed, 2 skipped**.
- New tests: **13 passed**, included above.
- Both skipped cases need an absent Tesseract executable.
- Policy model validation and each of the twelve phrase matchers tested.
- Real API workflow tested with and without image attachments.
- Approval verification required `valid=true` in both modes.
- Repeated setup with the same state did not duplicate checks/drafts.
- Current brand rule counts were four, while Acme's original five-rule historical version remained present.
- Fresh signup saw shared rules, empty private history/drafts, and could not read the demo receipt or approve the pending item.
- Existing-output refusal and stale-cleanup-plan rejection tested.
- Live Vercel health endpoint returned HTTP 200; no authenticated live requests were made.

## Validation still required locally / after deployment

Flutter SDK and Android SDK are not installed here. Run `flutter analyze`, all Flutter tests, a web build, and an APK build locally. Exercise brand switching on a narrow phone screen and verify image preview/download on the actual hosted storage configuration.

Vercel deployment has not been executed here. The adapter's production configuration guard requires Supabase mode and PostgreSQL; review the project's actual server variables and deployment settings.

See **`DEMO_SETUP_AND_RELEASE.md`** for execution order, exact commands, image behavior, rollback warnings, and the final checklist.
