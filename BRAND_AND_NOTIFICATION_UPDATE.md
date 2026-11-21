# New-Check Defaults, Compact Banners & Responsive Notifications

## Meaning of the sample-brand choices

Acme, Zest Foods, and Skyline Travel are reusable **policy scopes**. Choosing one tells the backend which configured brand policies to apply. Their cards are not submitted checks, approval statuses, customer accounts, or required choices. Shared policies help demonstrate the checking workflow; private submissions remain user-specific.

**New brand** is the custom-brand path. It does not automatically create policies. A Reviewer must separately configure that brand's guidelines/rules; a clean scan without brand policies is not proof of compliance.

## Behavior changes

1. A fresh New Brand Check now starts with an empty brand field and **New brand selected**, rather than Acme.
2. Existing drafts retain their saved brand. Resubmissions/revisions retain the supplied existing brand and lock behavior.
3. Callers can explicitly preselect a brand with `initialBrandName`; this is also used by Acme-specific test fixtures rather than relying on a global default.
4. Banner artwork is limited to **320 logical pixels wide**, or the available width if narrower. Its 3:1 ratio and contain fit preserve the entire image. It no longer stretches across a large screen.
5. Clicking a check-linked notification opens Review Queue immediately. Its existing visible loading circle remains while review records load, then the existing check-detail behavior continues.
6. Mark-as-read runs in the background instead of blocking navigation behind a PATCH and a notification-list reload.
7. A short-lived opening spinner/status is shown on the notification itself. Repeated clicks are guarded while opening. Messages without a check link show acknowledgement progress rather than navigating somewhere unrelated.
8. A failed read acknowledgement restores unread state and shows a message; it does not prevent opening the check. Network errors in the destination continue to use the review screen's existing error/retry UI.

This changes responsiveness, not a claim that server data fetches have become instantaneous. Existing notification routing remains check-focused Review Queue; no new receipt-routing policy was invented.

## Apply

Extract `brand_defaults_banner_notification_patch.zip` at your repository root, merging/replacing its listed files. It includes updated Acme-specific test fixtures plus new regression tests. Do not restore earlier versions of those tests afterward.

No backend or database change is needed. No user data is deleted, and the curated policy seeding/cleanup procedure is unchanged.

## Test from mobile/

Run each command separately and stop if it fails:

```powershell
flutter analyze
flutter test test/brand_defaults_and_notification_loading_test.dart
flutter test test/brand_showcase_test.dart
flutter test test/feature_navigation_test.dart
flutter test test/round3_enhancements_test.dart
flutter test test/phase4_round3_ui_test.dart
flutter test
```

The new delayed-response notification test verifies that Review Queue and its loading feedback appear **before** the mark-as-read response completes. Other tests cover the fresh custom-brand default, saved-draft brand retention, and the compact no-crop banner.

Flutter tooling is unavailable in the assistant environment; these tests are supplied but not claimed to have executed here. `git diff --check` completed without whitespace errors.

After tests pass, restart the running client to verify a newly created editor (an already-open editor may retain its previous state):

```powershell
flutter run -d chrome --dart-define=API_BASE=https://brandguard-vercel-code-nova.vercel.app
```

For final distribution, rebuild web and Android using the existing release guide. Source changes alone do not update an already deployed compiled Flutter web bundle or installed APK.
