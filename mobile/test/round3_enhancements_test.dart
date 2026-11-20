import 'dart:convert';
import 'dart:typed_data';

import 'package:brandguard/app/app_theme.dart';
import 'package:brandguard/app/ui/brandguard_shell.dart';
import 'package:brandguard/core/auth/demo_auth.dart';
import 'package:brandguard/core/auth/session.dart';
import 'package:brandguard/core/network/asset_saver.dart';
import 'package:brandguard/core/network/brandguard_api_service.dart';
import 'package:brandguard/features/checks/findings_evidence_screen.dart';
import 'package:brandguard/features/checks/new_brand_check_screen.dart';
import 'package:brandguard/features/receipts/receipt_detail_screen.dart';
import 'package:brandguard/features/reviews/review_queue_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/widget_test_setup.dart';

void main() {
  configureTestFonts();

  // Valid 1x1 transparent PNG bytes for Image.memory verification.
  final validPngBytes = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    session.signIn(
      DemoAuth.creator.user,
      accessToken: 'creator-access',
      refreshToken: 'creator-refresh',
    );
  });

  tearDown(() {
    saveAssetOverrideForTesting = null;
    session.signOut();
    BrandGuardApiService.clientForTesting = http.Client();
  });

  Future<void> open(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AppTheme.syncBrightness(Brightness.light);
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        theme: AppTheme.light,
        home: screen,
      ),
    );
    await settleTestUi(tester);
  }

  Future<void> scrollAndEnsure(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      final verticalElements = find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .evaluate()
          .toList()
          .reversed;
      for (final element in verticalElements) {
        final state = tester.state<ScrollableState>(
          find.byElementPredicate((e) => e == element),
        );
        final pos = state.position;
        for (final step in [200.0, -200.0]) {
          var hops = 0;
          while (finder.evaluate().isEmpty && hops < 40) {
            final next = (pos.pixels + step).clamp(
              pos.minScrollExtent,
              pos.maxScrollExtent,
            );
            if ((next - pos.pixels).abs() < 0.5) break;
            pos.jumpTo(next);
            await tester.pump();
            hops++;
          }
          if (finder.evaluate().isNotEmpty) break;
        }
        if (finder.evaluate().isNotEmpty) break;
      }
    }
    await tester.ensureVisible(finder);
    await tester.pump();
  }

  testWidgets(
    'NewBrandCheckScreen uses native date, time, and timezone picker instead of manual ISO text',
    (tester) async {
      BrandGuardApiService.clientForTesting = MockClient((request) async {
        return http.Response(jsonEncode({'status': 'clean', 'findings': []}), 200);
      });

      await open(tester, const NewBrandCheckScreen());
      await scrollAndEnsure(tester, find.byKey(const ValueKey('pick-custom-date')));
      expect(find.text('Custom date & time'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pick-custom-date')));
      await settleTestUi(tester);

      // Step 1: DatePicker appears (no raw ISO TextField dialog).
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(find.text('ISO-8601 timestamp'), findsNothing);
      await tester.tap(find.text('OK'));
      await settleTestUi(tester);

      // Step 2: TimePicker appears.
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await settleTestUi(tester);

      // Step 3: Timezone selector appears.
      expect(find.text('Select timezone'), findsOneWidget);
      await tester.tap(find.textContaining('IST (India'));
      await settleTestUi(tester);

      expect(find.textContaining('IST (+05:30)'), findsWidgets);
    },
  );

  testWidgets(
    'ReceiptDetailScreen renders human-readable creator and reviewer names and emails',
    (tester) async {
      BrandGuardApiService.clientForTesting = MockClient((request) async {
        if (request.url.path == '/api/v1/receipts/rcpt-author-1') {
          return http.Response(
            jsonEncode({
              'receipt_id': 'rcpt-author-1',
              'check_id': 'chk-author-1',
              'brand_name': 'Acme',
              'content_version': 1,
              'content_hash': 'hash1234567890abcdef',
              'rules_version': '1.0.0',
              'creator_id': '99999999-aaaa-bbbb-cccc-111111111111',
              'creator_name': 'Maya Creator',
              'creator_email': 'maya@acme.com',
              'reviewer': '88888888-dddd-eeee-ffff-222222222222',
              'reviewer_name': 'Alex Reviewer',
              'reviewer_email': 'alex@acme.com',
              'scan_status': 'passed',
              'final_status': 'approved',
              'current_review_status': 'approved',
              'is_current_version': true,
              'rules_current': true,
              'approval_valid': true,
              'timestamp': '2026-11-18T10:00:00Z',
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      await open(tester, const ReceiptDetailScreen(receiptId: 'rcpt-author-1'));
      expect(find.text('Maya Creator'), findsOneWidget);
      expect(find.text('maya@acme.com'), findsOneWidget);
      expect(find.text('Alex Reviewer'), findsOneWidget);
      expect(find.text('alex@acme.com'), findsOneWidget);
    },
  );

  testWidgets(
    'Bottom Done button after submission routes directly to Reviews inside BrandGuardShell',
    (tester) async {
      BrandGuardApiService.clientForTesting = MockClient((request) async {
        if (request.url.path == '/api/v1/analytics') {
          return http.Response(jsonEncode({'pending': 1}), 200);
        }
        if (request.url.path == '/api/v1/notifications') {
          return http.Response(jsonEncode({'unread': 0, 'items': []}), 200);
        }
        if (request.url.path == '/api/v1/reviews') {
          return http.Response(jsonEncode({'reviews': []}), 200);
        }
        if (request.url.path == '/api/v1/brand/check') {
          return http.Response(
            jsonEncode({
              'check_id': 'chk-done-1',
              'receipt_id': 'rcpt-done-1',
              'brand_name': 'Acme',
              'status': 'review_required',
              'review_status': 'draft',
              'content_version': 1,
              'scan_status': 'passed',
              'findings': [],
              'conflicts': [],
              'assets': [],
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/brand/chk-done-1/submit') {
          return http.Response(
            jsonEncode({
              'check_id': 'chk-done-1',
              'receipt_id': 'rcpt-done-1',
              'brand_name': 'Acme',
              'status': 'review_required',
              'review_status': 'pending',
              'content_version': 1,
              'scan_status': 'passed',
              'findings': [],
              'conflicts': [],
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      await open(tester, const BrandGuardShell(initialIndex: 0));
      await scrollAndEnsure(tester, find.text('New Brand Check').first);
      await tester.tap(find.text('New Brand Check').first);
      await settleTestUi(tester);

      await scrollAndEnsure(tester, find.byKey(const ValueKey('check-content')));
      await tester.enterText(
        find.byKey(const ValueKey('check-content')),
        'Acme launch copy.',
      );
      await scrollAndEnsure(tester, find.byKey(const ValueKey('run-check')));
      await tester.tap(find.byKey(const ValueKey('run-check')));
      await settleTestUi(tester);

      await tester.tap(find.byKey(const ValueKey('submit-authorised-review')));
      await settleTestUi(tester);

      // Even if user closes dialog via View-or-Done or taps bottom button:
      await tester.tap(find.byKey(const ValueKey('submission-done-to-reviews')));
      await settleTestUi(tester);

      expect(
        tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
        2,
      );
      expect(find.byType(NewBrandCheckScreen), findsNothing);
      expect(find.byType(FindingsEvidenceScreen), findsNothing);
    },
  );

  testWidgets(
    'Creator can delete an unreviewed pending check beside Edit & Resubmit, and Delete is hidden once reviewed',
    (tester) async {
      var deletedCalls = 0;
      var reviewsPayload = [
        {
          'check_id': 'chk-del-pending',
          'brand_name': 'Acme',
          'creator_id': DemoAuth.creator.user.userId,
          'status': 'pending',
          'content_version': 1,
          'rules_version': '1.0.0',
          'created_at': '2026-11-18T10:00:00Z',
          'content': 'New unreviewed copy',
          'findings': const [],
        },
        {
          'check_id': 'chk-reviewed-locked',
          'brand_name': 'Acme',
          'creator_id': DemoAuth.creator.user.userId,
          'status': 'changes_requested',
          'review_note': 'Needs fix',
          'decided_at': '2026-11-18T11:00:00Z',
          'decision_history': [
            {'decision': 'changes_requested', 'reviewer': 'u2'},
          ],
          'content_version': 1,
          'rules_version': '1.0.0',
          'created_at': '2026-11-18T09:00:00Z',
          'content': 'Already reviewed copy',
          'findings': const [],
        },
      ];

      BrandGuardApiService.clientForTesting = MockClient((request) async {
        if (request.url.path == '/api/v1/reviews' && request.method == 'GET') {
          return http.Response(jsonEncode({'reviews': reviewsPayload}), 200);
        }
        if (request.url.path == '/api/v1/brand/chk-del-pending' &&
            request.method == 'DELETE') {
          deletedCalls++;
          reviewsPayload = [reviewsPayload.last];
          return http.Response(
            jsonEncode({'deleted': true, 'check_id': 'chk-del-pending'}),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      await open(tester, const ReviewQueueScreen(initialTab: 'Pending'));
      await tester.tap(find.text('Acme Brand Check').first);
      await settleTestUi(tester);

      // Both Edit & resubmit and Delete appear side-by-side for unreviewed pending check.
      expect(find.byKey(const ValueKey('edit-resubmit-review')), findsOneWidget);
      expect(find.byKey(const ValueKey('delete-check-review')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('delete-check-review')));
      await settleTestUi(tester);
      expect(find.text('Delete brand check?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm-delete-check')));
      await settleTestUi(tester);
      expect(deletedCalls, 1);

      // Switch to Changes Requested: reviewed check must NOT show Delete.
      await tester.ensureVisible(find.text('Changes Requested'));
      await tester.tap(find.text('Changes Requested'));
      await settleTestUi(tester);
      await tester.tap(find.text('Acme Brand Check').first);
      await settleTestUi(tester);
      expect(find.byKey(const ValueKey('edit-resubmit-review')), findsOneWidget);
      expect(find.byKey(const ValueKey('delete-check-review')), findsNothing);
    },
  );

  testWidgets(
    'Reviewer can view source image and download attached PNG and PDF docs from ReviewQueueScreen',
    (tester) async {
      session.signIn(DemoAuth.reviewer.user, accessToken: 'reviewer-access');
      final savedFiles = <String>[];
      saveAssetOverrideForTesting = (fileName, bytes, mimeType) async {
        savedFiles.add('$fileName:${bytes.length}:$mimeType');
        return 'Downloads/BrandGuard/$fileName';
      };

      final pdfBytes = Uint8List.fromList(utf8.encode('%PDF-1.4 sample content'));
      BrandGuardApiService.clientForTesting = MockClient((request) async {
        if (request.url.path == '/api/v1/reviews' && request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'reviews': [
                {
                  'check_id': 'chk-assets-1',
                  'brand_name': 'Acme',
                  'creator_id': DemoAuth.creator.user.userId,
                  'creator_name': 'Creator User',
                  'creator_email': 'creator@brandguard.demo',
                  'status': 'pending',
                  'content_version': 1,
                  'rules_version': '1.0.0',
                  'created_at': '2026-11-18T10:00:00Z',
                  'content': 'Check with banner and PDF.',
                  'ocr_text': 'PROMO TEXT ON IMAGE',
                  'asset_ids': ['asset-img-1', 'asset-pdf-1'],
                  'assets': [
                    {
                      'id': 'asset-img-1',
                      'name': 'hero_banner.png',
                      'bytes': validPngBytes.length,
                      'content_type': 'image/png',
                      'is_image': true,
                      'width': 1,
                      'height': 1,
                    },
                    {
                      'id': 'asset-pdf-1',
                      'name': 'terms_sheet.pdf',
                      'bytes': pdfBytes.length,
                      'content_type': 'application/pdf',
                      'is_image': false,
                    },
                  ],
                  'findings': const [],
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/files/asset-img-1') {
          return http.Response(
            jsonEncode({
              'id': 'asset-img-1',
              'name': 'hero_banner.png',
              'bytes': validPngBytes.length,
              'content_type': 'image/png',
              'is_image': true,
              'width': 1,
              'height': 1,
              'extracted_text': 'PROMO TEXT ON IMAGE',
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/files/asset-img-1/download') {
          return http.Response.bytes(
            validPngBytes,
            200,
            headers: {'content-type': 'image/png'},
          );
        }
        if (request.url.path == '/api/v1/files/asset-pdf-1/download') {
          return http.Response.bytes(
            pdfBytes,
            200,
            headers: {'content-type': 'application/pdf'},
          );
        }
        return http.Response('{}', 200);
      });

      await open(tester, const ReviewQueueScreen(initialTab: 'Pending'));
      await tester.tap(find.text('Acme Brand Check').first);
      await settleTestUi(tester);

      // Scroll inside the review details sheet to the attached files section.
      await scrollAndEnsure(tester, find.text('hero_banner.png'));
      expect(find.text('hero_banner.png'), findsOneWidget);
      await scrollAndEnsure(tester, find.text('terms_sheet.pdf'));
      expect(find.text('terms_sheet.pdf'), findsOneWidget);

      // View source image inside modal viewer.
      await scrollAndEnsure(
        tester,
        find.byKey(const ValueKey('view-asset-asset-img-1')),
      );
      await tester.tap(find.byKey(const ValueKey('view-asset-asset-img-1')));
      await settleTestUi(tester);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text('PROMO TEXT ON IMAGE'), findsWidgets);

      // Download image from viewer.
      await tester.tap(find.byKey(const ValueKey('asset-viewer-download')));
      await settleTestUi(tester);
      expect(
        savedFiles,
        contains('hero_banner.png:${validPngBytes.length}:image/png'),
      );

      // Close viewer & download PDF directly from review sheet.
      await tester.tap(find.byIcon(Icons.close_rounded).last);
      await settleTestUi(tester);
      await scrollAndEnsure(
        tester,
        find.byKey(const ValueKey('download-asset-asset-pdf-1')),
      );
      await tester.tap(find.byKey(const ValueKey('download-asset-asset-pdf-1')));
      await settleTestUi(tester);
      expect(
        savedFiles,
        contains('terms_sheet.pdf:${pdfBytes.length}:application/pdf'),
      );
    },
  );
}
