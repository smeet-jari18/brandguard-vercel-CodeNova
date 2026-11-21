import 'package:material_ui/material_ui.dart';

/// Curated shortcuts, not an access-control list. Policies remain server-owned.
/// Other brands can still be entered in the normal brand text field.
class BrandShowcase extends StatelessWidget {
  const BrandShowcase({
    super.key,
    required this.selectedBrand,
    required this.onSelected,
    this.enabled = true,
  });

  final String selectedBrand;
  final ValueChanged<String> onSelected;
  final bool enabled;

  static const brands = <String, String>{
    'Acme': 'acme',
    'Zest Foods': 'zest_foods',
    'Skyline Travel': 'skyline_travel',
  };

  @override
  Widget build(BuildContext context) {
    final entry = brands.entries.where(
      (entry) => entry.key.toLowerCase() == selectedBrand.trim().toLowerCase(),
    );
    final slug = entry.isEmpty ? null : entry.first.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Embedded library views do not necessarily have a Scaffold/Material.
        // Use the same material_ui Material implementation as ChoiceChip.
        Material(
          type: MaterialType.transparency,
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: const Text('New brand'),
                selected: slug == null,
                onSelected: enabled ? (_) => onSelected('') : null,
              ),
              for (final brand in brands.keys)
                ChoiceChip(
                  label: Text(brand),
                  selected: selectedBrand.trim().toLowerCase() == brand.toLowerCase(),
                  onSelected: enabled ? (_) => onSelected(brand) : null,
                ),
            ],
          ),
        ),
        if (slug == null) ...[
          const SizedBox(height: 8),
          const Text(
            'A reviewer must configure this brand’s policies. Until then, only available global checks may apply; a clean scan is not proof of brand compliance.',
            style: TextStyle(fontSize: 12),
          ),
        ],
        if (slug != null) ...[
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 3,
                child: Image.asset(
                  'assets/brands/$slug.png',
                  width: double.infinity,
                  fit: BoxFit.contain,
                  semanticLabel: '$selectedBrand fictional demonstration brand artwork',
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Fictional sample brands. Read the active policies before submitting.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ],
    );
  }
}

/// Selecting a scope does not publish a policy or grant review authority.
Future<String?> promptBrandName(BuildContext context) async {
  var enteredName = '';
  final name = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('New brand'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Enter a brand name to view its library. A reviewer must add its guidelines and rules separately. Approving a check does not create policies.'),
          const SizedBox(height: 12),
          TextField(
            onChanged: (value) => enteredName = value,
            autofocus: true,
            maxLength: 128,
            decoration: const InputDecoration(labelText: 'Brand name'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final value = enteredName.trim();
            if (value.isNotEmpty) Navigator.pop(dialogContext, value);
          },
          child: const Text('Open library'),
        ),
      ],
    ),
  );
  return name;
}
