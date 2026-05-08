import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

/// Toolbar widget providing markdown formatting controls
class MarkdownToolbar extends StatelessWidget {
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onHeader1;
  final VoidCallback onHeader2;
  final VoidCallback onHeader3;
  final VoidCallback onUnorderedList;
  final VoidCallback onOrderedList;
  final VoidCallback onLink;
  final VoidCallback onCode;
  final VoidCallback onQuote;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onSearch;
  final bool hasLinksFile;

  const MarkdownToolbar({
    super.key,
    required this.onBold,
    required this.onItalic,
    required this.onHeader1,
    required this.onHeader2,
    required this.onHeader3,
    required this.onUnorderedList,
    required this.onOrderedList,
    required this.onLink,
    required this.onCode,
    required this.onQuote,
    required this.onUndo,
    required this.onRedo,
    required this.onSearch,
    this.hasLinksFile = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          // Text formatting
          _ToolbarButton(
            icon: FluentIcons.text_bold_24_regular,
            tooltip: 'markdown_toolbar.bold'.tr(),
            onPressed: onBold,
          ),
          _ToolbarButton(
            icon: FluentIcons.text_italic_24_regular,
            tooltip: 'markdown_toolbar.italic'.tr(),
            onPressed: onItalic,
          ),

          const _ToolbarDivider(),

          // Headers
          _ToolbarButton(
            icon: FluentIcons.text_header_1_24_regular,
            tooltip:
                hasLinksFile
                    ? 'markdown_toolbar.h1_disabled'.tr()
                    : 'markdown_toolbar.h1'.tr(),
            onPressed: hasLinksFile ? () {} : onHeader1,
            text: 'H1',
            enabled: !hasLinksFile,
          ),
          _ToolbarButton(
            icon: FluentIcons.text_header_1_24_regular,
            tooltip:
                hasLinksFile
                    ? 'markdown_toolbar.h2_disabled'.tr()
                    : 'markdown_toolbar.h2'.tr(),
            onPressed: hasLinksFile ? () {} : onHeader2,
            text: 'H2',
            enabled: !hasLinksFile,
          ),
          _ToolbarButton(
            icon: FluentIcons.text_header_1_24_regular,
            tooltip:
                hasLinksFile
                    ? 'markdown_toolbar.h3_disabled'.tr()
                    : 'markdown_toolbar.h3'.tr(),
            onPressed: hasLinksFile ? () {} : onHeader3,
            text: 'H3',
            enabled: !hasLinksFile,
          ),

          const _ToolbarDivider(),

          // Lists
          _ToolbarButton(
            icon: FluentIcons.text_bullet_list_24_regular,
            tooltip: hasLinksFile
                ? 'markdown_toolbar.ul_disabled'.tr()
                : 'markdown_toolbar.ul'.tr(),
            onPressed: hasLinksFile ? () {} : onUnorderedList,
            enabled: !hasLinksFile,
          ),
          _ToolbarButton(
            icon: FluentIcons.text_number_list_ltr_24_regular,
            tooltip: hasLinksFile
                ? 'markdown_toolbar.ol_disabled'.tr()
                : 'markdown_toolbar.ol'.tr(),
            onPressed: hasLinksFile ? () {} : onOrderedList,
            enabled: !hasLinksFile,
          ),

          const _ToolbarDivider(),

          // Links and code
          _ToolbarButton(
            icon: FluentIcons.link_24_regular,
            tooltip: 'markdown_toolbar.link'.tr(),
            onPressed: onLink,
          ),
          _ToolbarButton(
            icon: FluentIcons.code_24_regular,
            tooltip: 'markdown_toolbar.code'.tr(),
            onPressed: onCode,
          ),
          _ToolbarButton(
            icon: FluentIcons.text_quote_24_regular,
            tooltip: hasLinksFile
                ? 'markdown_toolbar.quote_disabled'.tr()
                : 'markdown_toolbar.quote'.tr(),
            onPressed: hasLinksFile ? () {} : onQuote,
            enabled: !hasLinksFile,
          ),

          const _ToolbarDivider(),

          // Search and navigation
          _ToolbarButton(
            icon: FluentIcons.search_24_regular,
            tooltip: 'markdown_toolbar.search'.tr(),
            onPressed: onSearch,
          ),

          const _ToolbarDivider(),

          // Undo/Redo
          _ToolbarButton(
            icon: FluentIcons.arrow_undo_24_regular,
            tooltip: 'markdown_toolbar.undo'.tr(),
            onPressed: onUndo,
          ),
          _ToolbarButton(
            icon: FluentIcons.arrow_redo_24_regular,
            tooltip: 'markdown_toolbar.redo'.tr(),
            onPressed: onRedo,
          ),

          // Warning for books with links
          if (hasLinksFile) ...[
            const _ToolbarDivider(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.errorContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: cs.error.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    FluentIcons.warning_24_regular,
                    size: 16,
                    color: cs.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'markdown_toolbar.linked_book_warning'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Individual toolbar button
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final String? text;
  final bool enabled;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.text,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // ================== התחלת הקוד החדש ==================
    Widget content;
    if (text != null) {
      // אם יש טקסט (כמו H1), הצג רק אותו
      content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Text(
          text!,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: enabled
                ? Theme.of(context).textTheme.bodyLarge?.color
                : cs.onSurfaceVariant,
          ),
        ),
      );
    } else {
      // אחרת, הצג רק את האייקון
      content = Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(icon, size: 18),
      );
    }
    // =================== סוף הקוד החדש ===================

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(4),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: content, // הצגת התוכן שיצרנו
        ),
      ),
    );
  }
}

/// Vertical divider for toolbar sections
class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      color: Theme.of(context).dividerColor,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
