import 'dart:async';
import 'dart:convert';

import 'package:brandguard/app/app_theme.dart';
import 'package:brandguard/app/ui/brand_showcase.dart';
import 'package:brandguard/core/auth/demo_auth.dart';
import 'package:brandguard/core/auth/session.dart';
import 'package:brandguard/core/network/brandguard_api_service.dart';
import 'package:brandguard/features/checks/new_brand_check_screen.dart';
import 'package:brandguard/features/notifications/notifications_screen.dart';
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
    session.signIn(DemoAuth.creator.user, accessToken: 'creator-test');
    BrandGuardApiService.clientForTesting = MockClient(
      (_) async => http.Response('{"items":[],"reviews":[],"total":0}', 200),
    );
  });
  tearDown(() {
    session.signOut();
    BrandGuardApiService.clientForTesting = http.Client();
  });

  testWidgets('fresh check starts with New brand rather than Acme', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const NewBrandCheckScreen()));
    await tester.pumpAndSettle();
    final showcase = tester.widget<BrandShowcase>(find.byType(BrandShowcase));
    expect(showcase.selectedBrand, isEmpty);
    final chip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'New brand'));
    expect(chip.selected, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening an existing draft retains its brand', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light,
      home: const NewBrandCheckScreen(draft: {
        'id': 'draft-brand', 'revision': 1, 'title': 'Travel',
        'brand_name': 'Skyline Travel', 'content': '', 'attachments': [],
      }),
    ));
    await tester.pumpAndSettle();
    expect(tester.widget<BrandShowcase>(find.byType(BrandShowcase)).selectedBrand, 'Skyline Travel');
    expect(tester.takeException(), isNull);
  });

  testWidgets('banner stays compact on wide viewports and never crops', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: BrandShowcase(
      selectedBrand: 'Acme', onSelected: (_) {},
    ))));
    await tester.pumpAndSettle();
    final image = find.byType(Image);
    expect(tester.getSize(image).width, lessThanOrEqualTo(320));
    expect(tester.widget<Image>(image).fit, BoxFit.contain);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notification opens loading destination before read acknowledgement finishes', (tester) async {
    final readGate = Completer<http.Response>();
    final reviewGate = Completer<http.Response>();
    var readRequested = false;
    BrandGuardApiService.clientForTesting = MockClient((request) async {
      if (request.method == 'PATCH') {
        readRequested = true;
        return readGate.future;
      }
      if (request.url.path == '/api/v1/reviews') return reviewGate.future;
      if (request.url.path == '/api/v1/notifications') {
        return http.Response(jsonEncode({'items': [{
          'id': 'notification-one', 'title': 'Decision ready', 'body': 'Open your check',
          'read': false, 'check_id': 'check-one', 'created_at': '2026-11-01',
        }]}), 200);
      }
      return http.Response('{"items":[],"reviews":[]}', 200);
    });
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const NotificationsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Decision ready'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(readRequested, isTrue);
    expect(readGate.isCompleted, isFalse);
    expect(find.byType(ReviewQueueScreen), findsOneWidget);
    expect(find.text('Loading review records…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    readGate.complete(http.Response('{}', 200));
    reviewGate.complete(http.Response('{"reviews":[]}', 200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
