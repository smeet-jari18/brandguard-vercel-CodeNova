import 'package:material_ui/material_ui.dart';

import 'library_screen.dart';

class BrandGuidelinesScreen extends StatelessWidget {
  const BrandGuidelinesScreen({super.key, this.initialBrandName = 'Acme'});
  final String initialBrandName;
  @override
  Widget build(BuildContext context) =>
      LibraryScreen(kind: 'guidelines', title: 'Brand Guidelines', initialBrandName: initialBrandName);
}
