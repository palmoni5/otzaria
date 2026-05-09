import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

/// מצב אזהרת האינדקס המוצג למשתמש.
enum IndexingWarningMode {
  /// אינדקס קיים אך נמצא בתהליך עדכון/בנייה - חיפוש אפשרי, חלק מהתוצאות עלול לחסור.
  inProgress,

  /// אין אינדקס כלל - לא ניתן לבצע חיפוש שמשתמש באינדקס.
  missing,
}

class IndexingWarning extends StatelessWidget {
  final VoidCallback? onDismiss;
  final IndexingWarningMode mode;

  const IndexingWarning({
    super.key,
    this.onDismiss,
    this.mode = IndexingWarningMode.inProgress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final message = switch (mode) {
      IndexingWarningMode.inProgress =>
        'אינדקס החיפוש בתהליך עדכון. יתכן שחלק מהספרים לא יוצגו בתוצאות החיפוש.',
      IndexingWarningMode.missing =>
        'אינדקס לא קיים, לא ניתן לבצע חיפוש זה ללא אינדקס.',
    };
    return Container(
      padding: const EdgeInsets.all(8.0),
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(FluentIcons.warning_24_regular, color: colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              textAlign: TextAlign.right,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
          if (onDismiss != null && mode == IndexingWarningMode.inProgress)
            IconButton(
              icon: const Icon(FluentIcons.dismiss_24_regular),
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }
}
