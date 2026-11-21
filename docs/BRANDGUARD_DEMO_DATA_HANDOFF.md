# BrandGuard — First-Use Experience & Curated Data Handoff

**Purpose:** Prepare the deployed app so a first-time visitor sees a clear, realistic product rather than development/test clutter.

**Audience:** Teammate implementing data cleanup, policy setup, account provisioning, and release verification.

**Target application:** https://brandguard-vercel-code-nova.vercel.app/

**Repository:** https://github.com/smeet-jari18/brandguard-vercel-CodeNova

> **Status and approval boundary:** We previously discussed keeping three fixed brands—**Acme, Zest Foods, and Skyline Travel**—with curated rules and a small, coherent demonstration workflow. That was a proposal, not an executed database change. No production deletion or curated seeding has been performed as part of this handoff. The exact rule wording and examples below are a detailed implementation proposal requiring owner approval before production changes.
>
> **Safety requirement:** Back up first. Obtain explicit approval for the deletion manifest. Never delete real user data, authentication identities, audit history, or stored files just because they look like test data.

---

## 1. Desired result

A new visitor should immediately understand:

1. **What BrandGuard does:** checks content against brand rules, shows evidence, and supports human review.
2. **Which brands are available:** three intentionally prepared brands with useful, readable policies.
3. **What to do next:** select a brand, read its rules, and run a check.
4. **Why evidence matters:** sample copy triggers findings tied to actual active policy text.
5. **Why review matters:** a pending submission is visibly different from an approved version.
6. **Why versioning matters:** approval belongs to the reviewed content, not every future edit.

The app should feel ready to use, not artificially full. A few coherent records are better than dozens of disconnected checks.

### Success criteria

- Exactly three curated demonstration brands are intentionally presented: Acme, Zest Foods, Skyline Travel.
- Every brand has active supported rules, guidelines, and understandable example copy.
- The shared demonstration Creator account has **three workflow items total: two submitted checks and one draft**.
- One submitted check has a genuine recorded approval; one is pending review.
- An authorized Reviewer can see the pending item and act on it.
- A newly registered user sees shared brand policies but **not another creator's private checks, drafts, receipts, or notifications**.
- No stale test records, misleading fake receipts, broken sample assets, or expired policy examples remain in the curated account.
- Both the web app and release APK use the working Vercel backend.

---

## 2. Fixed brand catalogue

These are fictional demonstration brands, not claims about real organizations.

| Brand | Category | Why keep it | Main demonstration |
|---|---|---|---|
| **Acme** | Digital services / SaaS | Existing default brand and bundled rules make this the lowest-risk starting point. | Unsupported superlatives and permanent-free claims. |
| **Zest Foods** | Packaged food | Shows that policies differ by brand and industry. | Health claims, nutrition absolutes, and certification language. |
| **Skyline Travel** | Travel booking | Shows promotional restrictions and conditional offers. | Guarantees, price absolutes, and misleading cancellation claims. |

### Naming rules

- Use these exact names consistently in UI data, API parameters, drafts, submissions, assets, and library entries.
- Do not create variants such as `ACME`, `Acme Test`, `Zest Food`, or `SkylineTravel` as separate brands.
- Do not assume a dedicated SQL `brands` table exists. Inspect how the current brand selector discovers names and ensure all three are selectable.
- If the selector is hardcoded to Acme, adding library rows alone is insufficient; update and test the selector separately.
- Keep the branding readable. Final logos are optional polish, not a reason to delay a correct data setup.

---

## 3. Rule implementation contract

### Important: a written policy is not automatically an executable check

Before loading any proposed rule below:

1. Inspect the current rule schema and deterministic engine.
2. Identify the supported matcher/type and required fields.
3. Use valid rule identifiers, brand scope, versions, channel settings, and dates.
4. Ensure the actual detection logic matches the policy wording.
5. Test both triggering and non-triggering copy through preflight and submission.
6. Confirm the finding cites the stored policy text with valid grounding spans.

**Do not seed arbitrary JSON fields or invent a matcher type.** If a requirement cannot be enforced by the current engine, either implement and test it as a separate code change or publish it as guidance—not as a functioning automated check.

### Shared metadata requirements

For each rule, use the schema-supported equivalent of:

| Attribute | Requirement |
|---|---|
| Rule ID | Stable, unique identifier; preserve existing IDs where appropriate. |
| Brand | Exact fixed brand name. |
| Version | Explicit version; increment when modifying an existing rule. |
| Policy text | Clear, quotable wording saved as the source of truth. |
| Matcher configuration | Supported deterministic configuration, verified by tests. |
| Severity / outcome | Only use accepted schema values; do not infer valid enum values from this document. |
| Channel | All supported channels initially, unless deliberately demonstrating a restriction. |
| Effective dates | Active at the time of deployment and demonstration. |
| Expiry | No near-term expiry that could silently break the demo; use supported open-ended validity if available. |
| Topic key | Meaningful unique topic within brand, avoiding accidental source conflicts. |
| Supersession | Set only for real policy replacement, not arbitrary seed ordering. |

Keep the normal first-use flow conflict-free. Temporal supersession, conflicts, and amendments are useful advanced demonstrations, but should not block a visitor's first submission.

---

## 4. Proposed Acme rule set

Keep and review the two existing bundled IDs; do not silently change their meaning or severity without checking current records. Existing bundled behavior was `ACME-001` for “free forever” with a review outcome and `ACME-002` for “best in the world” with a warning outcome.

| ID | Proposed policy text | Trigger example | Safer alternative |
|---|---|---|---|
| **ACME-001** | Do not describe Acme services as “free forever”. Describe the actual plan and its applicable terms instead. | “Use Acme free forever.” | “Explore Acme's available plans and features.” |
| **ACME-002** | Do not describe Acme as “best in the world”. Use specific, supportable descriptions instead of absolute superiority claims. | “Acme is the best in the world.” | “Acme helps teams organize their daily work.” |
| **ACME-003** | Do not promise “guaranteed results” when advertising Acme services. Explain capabilities without guaranteeing a customer's outcome. | “Acme delivers guaranteed results.” | “Acme provides tools to support your workflow.” |
| **ACME-004** | Do not call Acme services “100% secure”. Describe concrete security features without claiming absolute security. | “Your data is 100% secure.” | “Learn about Acme's available security features.” |

### Guidelines entry

**Title:** Acme — Clear, Credible Product Communication

**Content:** Use clear, practical language. Explain what the product helps users do. Avoid unsupported superiority, permanent pricing promises, absolute security, and guaranteed outcomes. Refer to the active rule library for enforceable restrictions. Do not invent product capabilities or commercial terms.

### Test copy

**Triggering:**

```text
Acme is the best in the world. Get guaranteed results with a service that is free forever and 100% secure.
```

**Clean candidate:**

```text
Bring your team's daily work into focus with Acme. Explore available features and choose the plan that fits your workflow.
```

A clean deterministic result means no configured matcher fired; it is not independent proof that every statement is legally or factually correct.

---

## 5. Proposed Zest Foods rule set

| ID | Proposed policy text | Trigger example | Safer alternative |
|---|---|---|---|
| **ZEST-001** | Do not claim that Zest Foods products “cure diabetes”. Food marketing must not make this disease-treatment claim. | “Our snack can cure diabetes.” | “Explore Zest Foods snacks and read the product information.” |
| **ZEST-002** | Do not describe Zest Foods products as causing “guaranteed weight loss”. Do not guarantee health or body-weight outcomes. | “Enjoy guaranteed weight loss.” | “Choose foods based on your needs and the product information.” |
| **ZEST-003** | Do not use “zero sugar” in Zest Foods promotional copy under this demo policy. Direct readers to the product's nutrition information instead. | “Our new snack has zero sugar.” | “Check the product's nutrition information for sugar content.” |
| **ZEST-004** | Do not use “100% organic” in Zest Foods promotional copy under this demo policy. Do not imply certification or composition without an approved product-specific source. | “A 100% organic treat.” | “Read the product information for ingredient details.” |

**Scope clarification:** These are deliberately simple fictional brand restrictions. A phrase detector cannot determine whether a product is actually organic, sugar-free, or medically effective. Do not describe these rules as full regulatory or nutrition validation.

### Guidelines entry

**Title:** Zest Foods — Responsible Food Marketing

**Content:** Keep food descriptions informative and avoid disease-treatment or guaranteed health-outcome claims. Do not invent nutrition, ingredient, certification, or allergen information. Refer to approved product-specific material where available. The demo rules prohibit specific phrases; they do not replace food-label or legal review.

### Test copy

**Triggering:**

```text
Try Zest Foods: a 100% organic snack with zero sugar, guaranteed weight loss, and ingredients that cure diabetes.
```

**Clean candidate:**

```text
Discover Zest Foods snacks for your next break. Review the product information for ingredients and nutrition details before choosing.
```

---

## 6. Proposed Skyline Travel rule set

| ID | Proposed policy text | Trigger example | Safer alternative |
|---|---|---|---|
| **SKY-001** | Do not promise “guaranteed visa approval” in Skyline Travel advertising. Visa decisions are not guaranteed by a booking service. | “Book now for guaranteed visa approval.” | “Check the destination's visa requirements before booking.” |
| **SKY-002** | Do not advertise a “100% refund” in general Skyline Travel copy. Refund eligibility depends on the booking's actual terms. | “Every booking includes a 100% refund.” | “Review the booking's refund terms before payment.” |
| **SKY-003** | Do not claim Skyline Travel offers the “lowest price guaranteed” under this demo policy. Describe available options without an absolute price guarantee. | “Lowest price guaranteed on every trip.” | “Compare available travel options.” |
| **SKY-004** | Do not say “free cancellation anytime” in Skyline Travel advertising. State that cancellation conditions depend on the selected booking. | “Enjoy free cancellation anytime.” | “Check the cancellation conditions for your selected booking.” |

### Guidelines entry

**Title:** Skyline Travel — Transparent Booking Communication

**Content:** Make booking conditions visible and do not invent visa outcomes, refunds, prices, or cancellation entitlements. Use conditional language where an offer depends on a specific fare or supplier. Direct travelers to the actual booking terms and destination requirements.

### Test copy

**Triggering:**

```text
Skyline Travel offers guaranteed visa approval, lowest price guaranteed, a 100% refund, and free cancellation anytime.
```

**Clean candidate:**

```text
Plan your next journey with Skyline Travel. Compare available options and review visa requirements, refund terms, and cancellation conditions before booking.
```

---

## 7. Guidelines, facts, and policy content to keep

### Guidelines Hub baseline

| Content | Acme | Zest Foods | Skyline Travel |
|---|---:|---:|---:|
| Active supported rules | 4 | 4 | 4 |
| Concise overview guideline | 1 | 1 | 1 |
| Optional sample policy document | 1 | 1 | 1 |
| Product-specific verified fact source | Only if genuinely prepared | Only if genuinely prepared | Only if genuinely prepared |

A document is optional; readable in-app policy text is mandatory.

### Facts must not be fabricated

Do not create a fake independent citation to make AI verification appear impressive. If adding fictional internal facts for these fictional brands:

- Label them clearly as **demonstration-only internal sources**.
- Store actual source text and provenance supported by the app.
- Have the authorized reviewer verify them through the implemented workflow.
- Use source-compatible quotes and dates.
- Do not claim that a paid AI or external fact-check was performed when it was not.

For the baseline demo, it is acceptable to have no verified product facts. The assistant should disclose missing evidence or use the deterministic fallback, rather than inventing facts.

---

## 8. Curated workflow records

### Important counting rule

Create **three workflow items**, not three submitted checks plus extra drafts:

1. One approved submitted check.
2. One pending submitted check.
3. One saved draft.

The draft must not inflate the submitted-check count unless the actual product model deliberately represents it that way. Derive dashboard counts from real data, not hardcoded totals.

### Item A — Acme, approved

| Field | Proposal |
|---|---|
| Display title, if supported | Acme — Team Workflow Launch |
| Owner | Curated demonstration Creator account |
| Brand | Acme |
| Content | Use the Acme clean candidate above. |
| Assets | Optional readable sample campaign image, clearly marked as demo material. |
| Workflow | Create check → submit → authorized Reviewer approves. |
| Expected evidence | Genuine recorded decision, current version, and valid generated receipt/approval evidence. |

**Do not fabricate approval state by editing JSON.** Create the actual decision through the supported API/UI so hashes, history, notifications, and receipts stay consistent.

### Item B — Zest Foods, pending review

| Field | Proposal |
|---|---|
| Display title, if supported | Zest Foods — Snack Campaign Review |
| Owner | Same curated demonstration Creator |
| Brand | Zest Foods |
| Content | “Discover Zest Foods: a 100% organic snack with zero sugar for your next break.” |
| Workflow | Create check → inspect findings → submit for review → leave pending. |
| Expected findings | Supported ZEST-003 and ZEST-004 phrase detections, with exact grounding. |
| Expected Reviewer view | One clearly identifiable pending submission. |

**Verification requirement:** Confirm the current workflow permits submission with these findings. If it blocks submission, do not bypass validation. Adjust to a supported warning-level example or demonstrate the findings before submission and use a genuinely submittable item for the pending queue.

### Item C — Skyline Travel, draft

| Field | Proposal |
|---|---|
| Display title, if supported | Skyline Travel — Weekend Campaign Draft |
| Owner | Same curated demonstration Creator |
| Brand | Skyline Travel |
| Content | “Plan your next journey with Skyline Travel. Compare available options and review booking terms before confirming.” |
| Workflow | Save as draft only. |
| Expected behavior | Reopens with saved brand/content; remains editable; has no reviewer approval or approval receipt. |

### Why this combination?

- Acme shows a completed workflow.
- Zest Foods shows evidence and work waiting for review.
- Skyline Travel shows an obvious “continue working” action.
- Three brands are represented without filling every screen with artificial records.

---

## 9. Accounts and first-open behavior

### Account A: curated demonstration Creator

- Contains the two checks and one draft above.
- Has a small, coherent activity timeline generated by those actions.
- Can inspect its own receipt and submission details.
- Cannot perform Reviewer-only actions.

### Account B: curated demonstration Reviewer

- Has the server-provisioned Reviewer role.
- Can see authorized review items, including Item B.
- Is the actual decision-maker for Item A if the current separation rules permit that account.
- Has no irrelevant personal draft collection.

Use dedicated account names such as **Demo Creator** and **Demo Reviewer**. Choose actual email addresses and credentials through supported account provisioning. Do not assume an arbitrary mailbox can complete Supabase email confirmation.

**Never put service credentials or reused personal passwords in source code or public documentation.** Share evaluation credentials privately or through an explicitly approved public-demo access mechanism.

### A newly registered user is different

A brand-new account should see:

- Three shared brands and their readable policies.
- Its own identity and a clear route to create a check.
- Honest zero counts for its own checks, drafts, and activity.
- Helpful empty states rather than other users' records.

It should **not** automatically see Demo Creator's submissions, receipt details, assets, or notifications.

> The existing library is brand-scoped shared data. User checks, drafts, and notifications should remain private according to backend access controls. Do not solve an “empty dashboard” by weakening ownership checks.

If product requirements later call for universal sample records, implement an explicit read-only sample mode or copy-on-create template feature with separate access rules. That is a code change—not permission to expose private records.

---

## 10. What to remove or archive

**Every removal below is conditional on ownership verification, backup, and approval.**

| Area | Candidate cleanup | What must remain |
|---|---|---|
| Brand checks | Developer-created test checks, duplicates, dummy submissions, intentionally broken records. | Curated items and any genuine user-owned data not approved for deletion. |
| Versions and review data | Child records associated only with approved-for-deletion test checks. | Complete version/decision history of retained checks. |
| Receipts and approval records | Records belonging only to deleted test submissions. | Genuine receipts and approval evidence for retained content. |
| Drafts | “test”, “asdf”, “hello”, empty experiments, abandoned fixture drafts with verified demo ownership. | Skyline draft and real user work. |
| Notifications | Old test events, duplicate noise, notifications pointing to deleted test objects. | Relevant real notifications and current curated workflow events. |
| Uploaded files | Unreferenced test assets with verified ownership and no retention obligation. | Files referenced by retained checks, versions, guidelines, facts, templates, or receipts. |
| Rules and guidelines | Duplicate or experimental brand policies after confirming no retained evidence depends on them. | Active curated rules plus historical policy versions needed to interpret approvals. |
| Facts | Fabricated, unverified, irrelevant test facts after reference checks. | Legitimate verified sources and history required by retained records. |
| Conflicts / clarity tickets | Deliberately generated test cases tied exclusively to removed data. | Genuine unresolved items; historical items needed by retained workflows. |
| Analytics / caches | Stale cached or derived aggregates if applicable. | Source records; regenerate counts from retained data. |
| Authentication users | Only explicitly identified disposable test identities through supported admin tooling. | Curated accounts, real accounts, maintainers, and required system identities. |
| Audit history | Follow the retention decision below. | Default: preserve audit history. |

### Do not use these shortcuts

- Do not run `TRUNCATE bg_entities`, bulk-delete all collections, or reset the entire Supabase project.
- Do not delete an identity simply because its email includes “test”.
- Do not delete all files in the `brandguard-files` bucket.
- Do not remove historical rule versions required by approved content.
- Do not directly manufacture receipts, hashes, decisions, or user roles in client-visible state.
- Do not hardcode dashboard metrics to make the demonstration look busy.

### Audit retention decision

The earlier discussion included removing test audit noise. For a safer implementation, **preserve audit data by default**. Archive and remove only explicitly identified disposable test audit entries after owner approval and retention review. Do not erase the history of retained approvals. If the UI needs a cleaner activity view, filter irrelevant technical events without destroying the underlying audit trail.

---

## 11. Asset and notification plan

### Files

Keep **one or two polished sample assets** initially:

1. A simple Acme campaign image consistent with the approved text.
2. Optionally a Zest Foods campaign image matching the pending submission.

Requirements:

- Use original or authorized artwork; label fictional brands clearly where appropriate.
- Text should be readable on a phone.
- Store through the supported upload API.
- Confirm preview and download on both web and Android.
- If OCR is unavailable on the runtime, do not promise that the image's text was checked; demonstrate text-based evidence separately.
- Never seed a file reference unless the underlying private object actually exists and is accessible to authorized users.

### Notifications

Aim for **two or three relevant notifications**, generated by real workflow actions where supported, such as submission and decision events.

Do not invent a notification type the application does not support. Do not leave a “pending review” notification pointing at an already deleted check. If actual supported events yield fewer notifications, keep the smaller truthful set.

---

## 12. Screen-by-screen expected experience

| Screen | Curated Creator | New user | Reviewer |
|---|---|---|---|
| Sign-in | Clear identity and working login. | Signup/login and confirmation guidance as configured. | Login to provisioned role. |
| Home / dashboard | Actual metrics from two checks and one draft, as the implementation counts them. | Honest empty metrics and clear create action. | Relevant authorized review metrics. |
| Brand selection | Acme, Zest Foods, Skyline Travel. | Same shared brands. | Same shared brands. |
| Guidelines Hub | Correct brand-scoped policies. | Same readable policies. | Policies plus authorized management actions. |
| New Brand Check | Clean form, saved drafts accessible, real preflight. | Immediate usable creation path. | Behavior according to role permissions. |
| Findings | Exact rule and content evidence. | Only findings on accessible records. | Evidence on authorized review records. |
| Drafts | One Skyline draft initially. | Empty state until the user saves one. | No artificial drafts needed. |
| History / records | Only coherent retained user records. | Empty until activity occurs. | Authorized record scope. |
| Review Queue | No unauthorized decision capability. | No automatic Reviewer privileges. | Zest pending item visible and actionable. |
| Receipt detail | Acme evidence loads and validates. | No access to another creator's private receipt. | Authorized evidence access. |
| Assistant | Helpful policy explanation; honest provider status. | Usable on shared brand context without leaking private records. | Guidance does not replace explicit decisions. |
| Profile | Correct name, email, role, and session state. | Own identity only. | Reviewer identity and role. |

**Scope note:** Friendly empty-state or onboarding copy may require UI changes. Data seeding alone cannot guarantee a new layout or new navigation action.

---

## 13. Safe implementation sequence

### Phase 1 — Inventory, backup, and approval

1. Identify the actual deployment project and database; confirm this is not another production environment.
2. Record deployed commit, configuration mode, and current data counts.
3. Export `bg_entities` and `bg_documents` from a trusted server/admin connection.
4. Inventory auth identities and private storage objects. Back up required objects securely and document how identities will be handled; application table exports alone are not a full auth/storage backup.
5. Record the current policy versions and links from retained checks to policies/assets/receipts.
6. Prepare a deletion manifest with collection, entity ID, owner, reason, references, and proposed action.
7. Prepare a separate keep manifest.
8. Get the owner to approve both manifests and the retention decision.

**Checkpoint:** Do not proceed until backup recovery has been tested or otherwise credibly validated, and approvals are recorded.

### Phase 2 — Rehearse away from live data

1. Restore application data into an isolated test environment where feasible.
2. Disable outbound email and optional paid provider calls in the rehearsal environment.
3. Implement a dry-run cleanup script that prints candidates and retained references without deleting anything.
4. Make the script idempotent and explicitly environment-gated.
5. Rehearse deletion and seeding, then run access/integrity checks.

### Phase 3 — Prepare policies and accounts

1. Provision the two curated accounts through supported admin tooling.
2. Verify both logins and the actual server roles.
3. Upsert approved brand policies using supported schema and workflows.
4. Retain required historical rule versions.
5. Confirm all three brands are selectable and each has the correct four active rules.
6. Test trigger/clean copy against preflight and submitted checks.

### Phase 4 — Clean approved test data

1. Use supported check-deletion APIs wherever they enforce access and related cleanup correctly.
2. For gaps, use a reviewed server-side maintenance script with explicit IDs and transactions where available.
3. Process dependent records in the correct order, based on inspected storage references—not guessed collection names.
4. Delete storage objects only after a full retained-reference scan.
5. Defer auth identity deletion unless specifically necessary and approved; it is less reversible than hiding old test content.
6. Recompute or invalidate relevant caches/derived state.

The physical database uses generic `bg_entities(collection, entity_id, position, payload)` and `bg_documents(name, payload)` storage. Many links are application-level JSON references, not SQL foreign keys. Cascading cleanup cannot be assumed.

### Phase 5 — Seed genuine workflow actions

1. Upload retained sample files through the supported endpoint.
2. Create Acme check as Demo Creator, submit it, and approve it as Demo Reviewer.
3. Validate Acme approval/receipt and same-content verification.
4. Create and submit Zest item, then leave it pending.
5. Save Skyline draft without submitting.
6. Keep relevant generated notifications; avoid manual timestamp manipulation.

Use supported APIs/UI wherever possible. A direct policy/data import must follow actual server schema and preserve metadata. Do not edit generated receipt integrity fields by hand.

### Phase 6 — Validate and freeze

1. Run the acceptance tests below.
2. Confirm the APK was built against the working HTTPS backend.
3. Recheck web bundle deployment after any UI changes.
4. Record final counts and retained IDs in a private handoff report.
5. Take a post-seed backup or snapshot.
6. Stop using the curated accounts for random testing.
7. Route further experiments to staging or separate accounts.

---

## 14. AI, OCR, and deployment constraints

### AI baseline

The earlier deployment plan used **AI disabled** to avoid reliance on provider balance. Recheck runtime status before the demonstration; do not assume it has stayed unchanged.

- Deterministic checks must work without paid AI.
- The chatbot should explain its available capabilities or use the implemented fallback.
- Do not say a factual claim was AI-verified when the provider was disabled or no verified source was available.
- If enabling a provider later, test quotas, latency, timeout behavior, source grounding, and cost controls separately.

### OCR

Docker configuration may install OCR dependencies, but a Vercel Python runtime should not be assumed to contain Tesseract. Verify actual runtime support before centering the demonstration on image text extraction.

### Backend and APK

Working target:

```text
https://brandguard-vercel-code-nova.vercel.app
```

Build from `mobile/` with:

```bash
flutter build apk --release --dart-define=API_BASE=https://brandguard-vercel-code-nova.vercel.app
```

Do not distribute an APK pointing at device loopback or the previous Antideploy host. An installed APK does not inherit a later environment-variable change from Vercel.

### Auth redirects

Confirm the deployed confirmation/recovery routes and add the exact allowed URLs to Supabase Auth URL configuration, including the app's `/auth/confirm` and `/auth/reset` routes where used. Verify an actual signup/confirmation and reset flow instead of checking configuration alone.

---

## 15. Acceptance tests

### Policies and detection

- [ ] All three exact brand names appear in the selector.
- [ ] Each brand displays one clear guideline and four approved active rules.
- [ ] Each proposed prohibited phrase triggers the intended supported matcher.
- [ ] Clean copy avoids those configured findings.
- [ ] Brand scoping works: Zest policies do not appear as Acme rules.
- [ ] Findings quote actual stored policy text and reference correct rule versions.
- [ ] All policy dates are valid for the intended demonstration period.
- [ ] No accidental source conflict pauses the normal examples.

### Curated workflow

- [ ] Demo Creator has two submitted checks and one separate saved draft.
- [ ] Acme check has a genuine Reviewer approval and valid approval evidence.
- [ ] Zest item remains pending and is visible to the Reviewer.
- [ ] Skyline draft reopens correctly and is not presented as approved.
- [ ] Unchanged approved content verifies as expected.
- [ ] Modified approved content produces an identity/change warning as appropriate.
- [ ] Every retained receipt, decision, version, asset, and notification points to an existing accessible object.
- [ ] Dashboard totals match actual records and status definitions.

### Access and first use

- [ ] New signup sees shared policies but not Demo Creator's private records.
- [ ] New signup can create its own check.
- [ ] Direct API attempts to read another user's private record are rejected appropriately.
- [ ] Creator cannot approve by calling the Reviewer API directly.
- [ ] Reviewer account works without relying on a client-only role toggle.
- [ ] Assistant summaries do not leak another creator's records.

### Client and environment

- [ ] Live root opens successfully.
- [ ] `GET /health` responds successfully.
- [ ] Both curated accounts can sign in on web and Android.
- [ ] APK is rebuilt with the intended HTTPS backend and installed fresh for testing.
- [ ] File preview/download works on both clients for retained samples.
- [ ] Provider-disabled behavior is understandable and does not show a false verification claim.
- [ ] Confirmation and password reset redirects work where enabled.

### Cleanup and recovery

- [ ] Pre-change backups are securely stored and recovery has been validated.
- [ ] Keep/delete manifests were approved.
- [ ] No real user data or required policy history was removed.
- [ ] Audit retention decision was followed.
- [ ] No unreferenced test objects remain within the approved cleanup scope.
- [ ] Post-seed snapshot and private retained-ID report exist.

---

## 16. Prevent the demo from drifting

Shared demonstration accounts are mutable: visitors can change decisions, create checks, or delete their own data where allowed. A pristine initial state will not remain pristine automatically.

Choose an explicit operational approach:

- **Recommended short-term:** keep curated credentials controlled, use separate testing accounts, and perform a pre-session smoke check.
- **For repeat public use:** implement an explicit isolated demo workspace/reset process with safeguards. Do not periodically wipe all production data.
- **Before a live presentation:** confirm the pending item has not already been decided and the draft has not been submitted.
- **After a session:** restore only the approved curated workspace data through a reviewed process if needed, preserving unrelated users.

---

## 17. Decisions required from the project owner

Approve or change these before touching production:

- [ ] Keep the three brands: Acme, Zest Foods, Skyline Travel.
- [ ] Approve the proposed twelve policy texts and supported matcher behavior.
- [ ] Preserve existing Acme rule semantics/history where required.
- [ ] Approve two submitted checks plus one draft as the initial curated workspace.
- [ ] Confirm which accounts are the dedicated Creator and Reviewer.
- [ ] Confirm whether credentials are private or intentionally shared for a controlled demo.
- [ ] Approve the keep/delete manifests after inventory.
- [ ] Approve audit retention/archive handling.
- [ ] Confirm AI-disabled baseline or approve a separately tested provider configuration.
- [ ] Confirm whether files/OCR are included in the core demo or optional.
- [ ] Choose how shared demo changes will be managed between sessions.

---

## 18. Implementation completion report

The teammate should return this short report after execution:

```text
Environment / domain:
Deployed commit:
Backup location and recovery validation:
Approved keep/delete manifest reference:

Brands and active rule counts:
- Acme:
- Zest Foods:
- Skyline Travel:

Curated workflow IDs:
- Acme approved check:
- Zest pending check:
- Skyline saved draft:

Account provisioning verified:
- Creator: yes/no
- Reviewer: yes/no

Deleted / archived counts by collection:
Retained historical policy versions:
Storage cleanup summary:
Audit retention action:

AI mode and verified behavior:
OCR availability and verified behavior:
APK backend URL:

Acceptance tests passed / failed:
Known issues:
Rollback procedure:
Post-seed snapshot reference:
```

Do not include passwords, access tokens, database connection strings, or admin keys in this report.

---

## Final instruction to the implementer

**Inspect → back up → inventory references → obtain approval → rehearse → clean only approved test data → seed through genuine workflows → verify permissions and integrity → freeze the curated state.**

The goal is not to make the app look busy. The goal is to make its first-use experience clear, trustworthy, and demonstrably functional.
