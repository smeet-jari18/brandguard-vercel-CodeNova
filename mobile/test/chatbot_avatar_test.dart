import 'package:brandguard/app/ui/chatbot_avatar.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('chatbot uses the selected bundled bubble image', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ChatbotAvatar(size: 44)),
    ));
    await tester.pumpAndSettle();
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, 'assets/branding/chatbot_bubble.png');
    expect(image.width, 44);
    expect(image.fit, BoxFit.contain);
    expect(tester.takeException(), isNull);
  });
}
