import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

/// ווידג'ט המוצג כאשר אין תוצאות בספרייה.
/// מציג הודעה ראשית ופעולות עזר לניווט וחיפוש.
///
/// כאשר [onOpenLink] מסופק, מוצג מצב קישור ישיר עם לחצן פתיחת קישור.
class LibraryEmptyStateWidget extends StatelessWidget {
  const LibraryEmptyStateWidget({
    super.key,
    required this.message,
    required this.onBack,
    required this.onHome,
    required this.onOpenSearch,
    this.onOpenLink,
    this.showSearchElsewhereHint = false,
  });

  final String message;
  final VoidCallback onBack;
  final VoidCallback onHome;
  final VoidCallback onOpenSearch;

  /// כאשר מוגדר, מוצג מצב "קישור ישיר" עם לחצן פתיחת קישור.
  final VoidCallback? onOpenLink;

  /// האם להציג את הרמז "ניתן לנסות לחפש בתיקייה אחרת".
  /// מוצג רק כאשר בוצע חיפוש ללא תוצאות בתוך תת-תיקייה.
  final bool showSearchElsewhereHint;

  bool get _isDeepLink => onOpenLink != null;

  Widget _buildNavButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: onBack,
          icon: const Icon(FluentIcons.arrow_up_24_regular),
          label: Text('library_empty_state.back'.tr()),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: onHome,
          icon: const Icon(FluentIcons.home_24_regular),
          label: Text('library_empty_state.home'.tr()),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FluentIcons.document_search_24_regular,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (_isDeepLink) ...[
            const SizedBox(height: 8),
            Text(
              'library_empty_state.deep_link_subtitle'.tr(),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onOpenLink,
              icon: const Icon(FluentIcons.link_24_regular),
              label: Text('library_empty_state.open_link'.tr()),
            ),
            const SizedBox(height: 12),
            _buildNavButtons(),
          ] else ...[
            if (showSearchElsewhereHint) ...[
              const SizedBox(height: 12),
              Text(
                'ניתן לנסות לחפש בתיקייה אחרת',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            _buildNavButtons(),
            const SizedBox(height: 12),
            Text(
              'library_empty_state.search_hint'.tr(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: onOpenSearch,
              icon: const Icon(FluentIcons.search_24_regular),
              label: Text('library_empty_state.open_search'.tr()),
            ),
          ],
        ],
      ),
    );
  }
}
