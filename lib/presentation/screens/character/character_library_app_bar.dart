import 'package:flutter/material.dart';
import 'package:native_tavern/data/models/character_folder.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';

/// Horizontal inset shared by breadcrumb, search, and character browse lists.
const double kCharacterBrowseHorizontalInset = 16;

/// Horizontal breadcrumb under the AppBar title while browsing folders.
class CharacterLibraryBreadcrumb extends StatelessWidget {
  const CharacterLibraryBreadcrumb({
    super.key,
    required this.crumbs,
    required this.onRoot,
    required this.onCrumb,
  });

  final List<CharacterFolder> crumbs;
  final VoidCallback onRoot;
  final ValueChanged<int> onCrumb;

  @override
  Widget build(BuildContext context) {
    if (crumbs.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        );
    final activeStyle = style?.copyWith(
      color: scheme.primary,
      fontWeight: FontWeight.w600,
    );

    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: kCharacterBrowseHorizontalInset),
        children: [
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: onRoot,
            child: Text(l10n.characters, style: style),
          ),
          for (var i = 0; i < crumbs.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Icon(
                Icons.chevron_right,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: i == crumbs.length - 1 ? null : () => onCrumb(i),
              child: Text(
                crumbs[i].name,
                style: i == crumbs.length - 1 ? activeStyle : style,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
