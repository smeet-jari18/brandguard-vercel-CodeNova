import 'package:material_ui/material_ui.dart';

/// User-selected chatbot artwork, independent of BrandGuard's shield app mark.
class ChatbotAvatar extends StatelessWidget {
  const ChatbotAvatar({super.key, this.size = 32});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * 0.28),
    child: Image.asset(
      'assets/branding/chatbot_bubble.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'BrandGuard assistant',
      errorBuilder: (_, _, _) => SizedBox(
        width: size,
        height: size,
        child: const Icon(Icons.chat_bubble_outline_rounded),
      ),
    ),
  );
}
