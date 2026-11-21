import 'package:material_ui/material_ui.dart';

import 'library_screen.dart';

class UploadRuleScreen extends StatelessWidget {
  const UploadRuleScreen({super.key, this.initialBrandName = 'Acme'});
  final String initialBrandName;
  @override
  Widget build(BuildContext context) =>
      LibraryScreen(kind: 'rules', title: 'Enforceable Rules', initialBrandName: initialBrandName);
}
