import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import 'package:otzaria/plugins/services/webview2_compat_check.dart';

/// תצוגה שמופיעה במקום WebView כשגרסת WebView2 המותקנת במכשיר
/// אינה תומכת בתוספים (לדוגמה v143 שגורם לקריסת התוכנה).
class WebView2UnsupportedView extends StatelessWidget {
  final WebView2CompatResult result;
  final String? pluginName;

  const WebView2UnsupportedView({
    super.key,
    required this.result,
    this.pluginName,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                FluentIcons.warning_24_regular,
                size: 56,
                color: cs.error,
              ),
              const SizedBox(height: 16),
              Text(
                pluginName != null
                    ? 'לא ניתן לטעון את התוסף "$pluginName"'
                    : 'לא ניתן לטעון את התוסף',
                style: tt.titleLarge,
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 12),
              Text(
                result.reasonForUser,
                style: tt.bodyMedium,
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'כיצד לפתור:',
                      style: tt.titleSmall,
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. פנה למנהל המערכת ובקש לעדכן את '
                      'Microsoft Edge WebView2 Runtime.\n'
                      '2. אם אין מגבלות מנהל — ניתן להתקין את הגרסה החדשה '
                      'מהאתר הרשמי של Microsoft.\n'
                      '3. שאר תכונות אוצריא ימשיכו לעבוד כרגיל גם בלי תוספים.',
                      style: tt.bodySmall,
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
              ),
              if (result.version != null) ...[
                const SizedBox(height: 12),
                Text(
                  'גרסה מותקנת: ${result.version}',
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
