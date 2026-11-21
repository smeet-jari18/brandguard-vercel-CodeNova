import 'package:brandguard/app/ui/brand_showcase.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/widget_test_setup.dart';

void main() {
  configureTestFonts();

  testWidgets('curated brand shortcuts emit the selected brand', (tester) async {
    String? chosen;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: BrandShowcase(
        selectedBrand: 'Acme',
        onSelected: (brand) => chosen = brand,
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsNWidgets(4));
    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.contain);
    expect(find.byType(AspectRatio), findsOneWidget);
    await tester.tap(find.text('Zest Foods'));
    await tester.pump();
    expect(chosen, 'Zest Foods');
    expect(tester.takeException(), isNull);
  });

  testWidgets('resubmission lock disables brand shortcuts', (tester) async {
    String? chosen;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: BrandShowcase(
        selectedBrand: 'Acme',
        enabled: false,
        onSelected: (brand) => chosen = brand,
      )),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skyline Travel'));
    expect(chosen, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom brand does not display unrelated sample artwork', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: BrandShowcase(
        selectedBrand: 'Another Brand',
        onSelected: (_) {},
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsNWidgets(4));
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('New brand is first and clears the selected scope', (tester) async {
    String? chosen;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: BrandShowcase(
      selectedBrand: 'Acme', onSelected: (value) => chosen = value,
    ))));
    await tester.pumpAndSettle();
    final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
    expect((chips.first.label as Text).data, 'New brand');
    await tester.tap(find.text('New brand'));
    expect(chosen, '');
    expect(tester.takeException(), isNull);
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('embedded brand chips need no outer Material ($brightness)', (tester) async {
      tester.view.physicalSize = const Size(280, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? chosen;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness),
        // Deliberately no Scaffold, Card or Material around BrandShowcase.
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(280, 600),
            textScaler: TextScaler.linear(1.6),
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 280,
              child: SingleChildScrollView(
                child: BrandShowcase(
                  selectedBrand: 'Acme',
                  onSelected: (brand) => chosen = brand,
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(ChoiceChip), findsNWidgets(4));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Zest Foods'));
      await tester.tap(find.text('Zest Foods'));
      await tester.pumpAndSettle();
      expect(chosen, 'Zest Foods');
      expect(tester.takeException(), isNull);
    });
  }
}
