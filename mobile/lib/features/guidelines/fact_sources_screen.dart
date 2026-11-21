import 'package:material_ui/material_ui.dart';

import 'library_screen.dart';

class FactSourcesScreen extends StatelessWidget {
  const FactSourcesScreen({super.key, this.initialBrandName = 'Acme'});
  final String initialBrandName;
  @override
  Widget build(BuildContext context) =>
      LibraryScreen(kind: 'facts', title: 'Fact Sources', initialBrandName: initialBrandName);
}
