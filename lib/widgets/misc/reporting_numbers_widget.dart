import 'dart:io';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:otzaria/core/ui_snack.dart';

/// Widget that displays reporting numbers with copy functionality
class ReportingNumbersWidget extends StatelessWidget {
  final String libraryVersion;
  final int? bookId;
  final int lineNumber;
  final int? errorId;
  final bool showPhoneNumber;

  const ReportingNumbersWidget({
    super.key,
    required this.libraryVersion,
    required this.bookId,
    required this.lineNumber,
    this.errorId,
    this.showPhoneNumber = true,
  });

  static const String _phoneNumber = '(+972) 077-4636-198';

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'widgets.reporting_numbers.title'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            // Wrap מאפשר לנתונים להיות באותה שורה ולעבור לשורה הבאה אם אין מקום
            Wrap(
              spacing: 16, // מרווח אופקי בין הפריטים
              runSpacing: 8, // מרווח אנכי בין השורות
              children: [
                _buildCompactNumberItem(
                  context,
                  'widgets.reporting_numbers.version'.tr(),
                  libraryVersion,
                ),
                _buildCompactNumberItem(
                  context,
                  'widgets.reporting_numbers.book'.tr(),
                  bookId?.toString() ??
                      'widgets.reporting_numbers.not_available'.tr(),
                  enabled: bookId != null,
                ),
                _buildCompactNumberItem(
                  context,
                  'widgets.reporting_numbers.line'.tr(),
                  lineNumber.toString(),
                ),
                _buildCompactNumberItem(
                  context,
                  'widgets.reporting_numbers.error'.tr(),
                  errorId?.toString() ??
                      'widgets.reporting_numbers.not_selected'.tr(),
                  enabled: errorId != null,
                ),
              ],
            ),

            if (showPhoneNumber) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              _buildPhoneSection(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactNumberItem(
    BuildContext context,
    String label,
    String value, {
    bool enabled = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: $value',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: enabled ? null : Theme.of(context).disabledColor,
                ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: enabled ? () => _copyToClipboard(context, value) : null,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                FluentIcons.copy_24_regular,
                size: 16,
                color: enabled
                    ? Theme.of(context).iconTheme.color
                    : Theme.of(context).disabledColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneSection(BuildContext context) {
    final isMobile = Platform.isAndroid || Platform.isIOS;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // 1. הכותרת שתוצג בצד ימין
            Text(
              'widgets.reporting_numbers.otzaria_line'.tr(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),

            // 2. Spacer שתופס את כל המקום הפנוי ודוחף את שאר הווידג'טים שמאלה
            const Spacer(),

            // 3. מספר הטלפון מודגש (כבר לא צריך להיות בתוך Expanded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: isMobile
                  ? InkWell(
                      onTap: () => _makePhoneCall(context),
                      child: Text(
                        _phoneNumber,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.bold,
                            ),
                        textDirection: TextDirection.ltr,
                      ),
                    )
                  : SelectableText(
                      _phoneNumber,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                      textDirection: TextDirection.ltr,
                    ),
            ),
            const SizedBox(width: 8),

            // 4. כפתור ההעתקה
            IconButton(
              onPressed: () => _copyToClipboard(context, _phoneNumber),
              icon: const Icon(FluentIcons.copy_24_regular, size: 18),
              tooltip: 'widgets.reporting_numbers.copy_phone'.tr(),
              visualDensity: VisualDensity.compact,
            ),

            // 5. כפתור החיוג (למובייל)
            if (isMobile) ...[
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => _makePhoneCall(context),
                icon: const Icon(FluentIcons.phone_24_regular, size: 18),
                tooltip: 'widgets.reporting_numbers.call'.tr(),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),

        // טקסט המשנה נשאר כמו שהיה
        Text(
          'widgets.reporting_numbers.leave_clear_recording'.tr(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Future<void> _copyToClipboard(BuildContext context, String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        UiSnack.show('widgets.reporting_numbers.copied_to_clipboard'
            .tr(namedArgs: {'text': text}));
      }
    } catch (e) {
      if (context.mounted) {
        UiSnack.showError('widgets.reporting_numbers.copy_error'.tr());
      }
    }
  }

  Future<void> _makePhoneCall(BuildContext context) async {
    try {
      final phoneUri = Uri(scheme: 'tel', path: _phoneNumber);
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (context.mounted) {
          UiSnack.showError('widgets.reporting_numbers.cant_open_phone'.tr());
        }
      }
    } catch (e) {
      if (context.mounted) {
        UiSnack.showError('widgets.reporting_numbers.phone_open_error'.tr());
      }
    }
  }
}
