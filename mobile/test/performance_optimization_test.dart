import 'dart:async';
import 'dart:convert';

import 'package:brandguard/app/ui/brandguard_shell.dart';
import 'package:brandguard/core/auth/demo_auth.dart';
import 'package:brandguard/core/auth/session.dart';
import 'package:brandguard/core/network/brandguard_api_service.dart';
import 'package:brandguard/features/dashboard/home_dashboard_screen.dart';
import 'package:brandguard/features/reviews/review_queue_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/widget_test_setup.dart';

void main() {
  configureTestFonts();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    session.signIn(DemoAuth.reviewer.user, accessToken: 'perf-token');
  });

  tearDown(() {
    session.signOut();
    BrandGuardApiService.clientForTesting = http.Client();
  });

  test('getJson coalesces concurrent GETs and respects forceRefresh/invalidation', () async {
    var analyticsCalls = 0;
    final gate = Completer<void>();
    BrandGuardApiService.clientForTesting = MockClient((request) async {
      if (request.url.path == '/api/v1/analytics') {
        analyticsCalls++;
        if (analyticsCalls == 1) await gate.future;
        return http.Response(jsonEncode({'pending': analyticsCalls}), 200);
      }
      return http.Response('{}', 200);
    });

    final first = BrandGuardApiService.getJson('/api/v1/analytics');
    final second = BrandGuardApiService.getJson('/api/v1/analytics');
    await Future<void>.delayed(Duration.zero);
    gate.complete();
    final results = await Future.wait([first, second]);
    expect(analyticsCalls, 1);
    expect(results[0]['pending'], 1);
    expect(results[1]['pending'], 1);

    // Within TTL window, another read returns the cached value without a request.
    final cached = await BrandGuardApiService.getJson('/api/v1/analytics');
    expect(analyticsCalls, 1);
    expect(cached['pending'], 1);

    // Explicit forceRefresh hits the server immediately.
    final refreshed = await BrandGuardApiService.getJson(
      '/api/v1/analytics',
      forceRefresh: true,
    );
    expect(analyticsCalls, 2);
    expect(refreshed['pending'], 2);

    // Mutations invalidate the cache via notifyDataChanged().
    BrandGuardApiService.notifyDataChanged();
    final afterMutation = await BrandGuardApiService.getJson('/api/v1/analytics');
    expect(analyticsCalls, 3);
    expect(afterMutation['pending'], 3);
  });

  testWidgets('BrandGuardShell lazy-loads tabs and coalesces startup badge/home calls', (
    tester,
  ) async {
    final counts = <String, int>{};
    BrandGuardApiService.clientForTesting = MockClient((request) async {
      final path = request.url.path;
      counts[path] = (counts[path] ?? 0) + 1;
      if (path == '/api/v1/analytics') {
        return http.Response(
          jsonEncode({
            'total_checks': 1,
            'pending': 1,
            'approved': 0,
            'rejected': 0,
            'changes_requested': 0,
            'total_findings': 0,
            'scan_passed': 1,
          }),
          200,
        );
      }
      if (path == '/api/v1/notifications') {
        return http.Response(jsonEncode({'items': [], 'unread': 0}), 200);
      }
      if (path == '/api/v1/system/status') {
        return http.Response(
          jsonEncode({'auth_provider': 'supabase', 'database': 'postgresql'}),
          200,
        );
      }
      if (path == '/api/v1/reviews') {
        return http.Response(jsonEncode({'reviews': [], 'total': 0}), 200);
      }
      return http.Response('{}', 200);
    });

    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: BrandGuardShell()),
    );
    await settleTestUi(tester);

    // Home + shell share a single /analytics and /notifications call, and inactive
    // tabs (Reviews, Profile) do not fire background requests at launch.
    expect(counts['/api/v1/analytics'], 1);
    expect(counts['/api/v1/notifications'], 1);
    expect(counts['/api/v1/system/status'], 1);
    expect(counts['/api/v1/reviews'] ?? 0, 0);
    expect(counts['/api/v1/auth/preferences'] ?? 0, 0);

    // Tapping Reviews lazily mounts ReviewQueueScreen and fetches /reviews once.
    await tester.tap(find.text('Reviews').last);
    await settleTestUi(tester);
    expect(counts['/api/v1/reviews'], 1);
  });

  testWidgets('Home and ReviewQueue do not double-wait after a request timeout', (
    tester,
  ) async {
    var analyticsCalls = 0;
    var reviewsCalls = 0;
    BrandGuardApiService.clientForTesting = MockClient((request) async {
      if (request.url.path == '/api/v1/analytics') {
        analyticsCalls++;
      }
      if (request.url.path == '/api/v1/reviews') {
        reviewsCalls++;
      }
      throw TimeoutException('slow upstream');
    });

    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: HomeDashboardScreen()));
    await settleTestUi(tester);
    expect(analyticsCalls, 1);
    expect(find.textContaining('Connection timed out'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: ReviewQueueScreen()));
    await settleTestUi(tester);
    expect(reviewsCalls, 1);
    expect(find.textContaining('Connection timed out'), findsOneWidget);
  });
}
