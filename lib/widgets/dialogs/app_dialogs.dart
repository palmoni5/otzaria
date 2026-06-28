// lib/widgets/dialogs/app_dialogs.dart
//
// דיאלוגים גנריים של האפליקציה — M3-styled.
//
// מכיל:
//  • [SingleActionDialog] — דיאלוג עם כפתור אישור בלבד
//  • [TwoActionsDialog]   — דיאלוג עם ביטול + אישור (M3 FilledButton)
//  • [WarningDialog]      — דיאלוג אזהרה: ביטול (primary), אישור (error/שקוף)
//
// **הבדל מ-ConfirmationDialog:**
//  [ConfirmationDialog] (confirmation_dialog.dart) משתמש ב-TextButton ומאפשר
//  [isDangerous] / [confirmColor] — מתאים לניווט מקלדת עם הדגשת פוקוס.
//  [TwoActionsDialog] / [WarningDialog] כאן מסוגננים לחלוטין בסגנון M3
//  FilledButton ומתאימים לדיאלוגים פשוטים ללא ניווט מקלדת מיוחד.
//
// **שימוש:**
// ```dart
// await showSingleActionDialog(context: context, title: '...', content: '...');
// await showTwoActionsDialog(context: context, title: '...', content: '...');
// await showWarningDialog(context: context, title: '...', content: '...');
// ```

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:otzaria/widgets/misc/keyboard_dialog_navigation.dart';

// ── SingleActionDialog ────────────────────────────────────────────────────────

/// דיאלוג עם פעולה אחת (כפתור אישור בלבד)
class SingleActionDialog extends StatefulWidget {
  final dynamic title;
  final String? content;
  final Widget? customContent;
  final String? confirmText;
  final TextDirection? textDirection;

  /// נקרא בלחיצת אישור. אם מחזיר false הדיאלוג נשאר פתוח (למשל כשוולידציה
  /// בתוכן נכשלה). null = התנהגות רגילה שסוגרת תמיד.
  final bool Function()? onConfirm;

  const SingleActionDialog({
    super.key,
    required this.title,
    this.content,
    this.customContent,
    this.confirmText,
    this.textDirection,
    this.onConfirm,
  }) : assert(
          content != null || customContent != null,
          'content או customContent חייבים להיות מוגדרים',
        );

  @override
  State<SingleActionDialog> createState() => _SingleActionDialogState();
}

class _SingleActionDialogState extends State<SingleActionDialog>
    with DialogNavigationMixin {
  void _handleConfirm() {
    if (widget.onConfirm != null && !widget.onConfirm!()) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return buildKeyboardNavigator(
      onConfirm: _handleConfirm,
      onCancel: () => Navigator.of(context).pop(false),
      child: AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        title: widget.title is String
            ? Text(widget.title, textDirection: widget.textDirection)
            : widget.title,
        content: widget.customContent ??
            Text(widget.content!, textDirection: widget.textDirection),
        actions: [
          FilledButton(
            onPressed: _handleConfirm,
            style: FilledButton.styleFrom(
                backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
            child: Text(
              widget.confirmText ?? 'common.ok'.tr(),
              textDirection: widget.textDirection,
            ),
          ),
        ],
      ),
    );
  }
}

// ── TwoActionsDialog ──────────────────────────────────────────────────────────

/// דיאלוג עם שתי פעולות (ביטול ואישור) — סגנון M3 FilledButton
class TwoActionsDialog extends StatefulWidget {
  final dynamic title;
  final String content;
  final Widget? customContent;
  final String? cancelText;
  final String? confirmText;
  final bool handleEnterKey;
  final TextDirection? textDirection;

  const TwoActionsDialog({
    super.key,
    required this.title,
    required this.content,
    this.customContent,
    this.cancelText,
    this.confirmText,
    this.handleEnterKey = true,
    this.textDirection,
  });

  @override
  State<TwoActionsDialog> createState() => _TwoActionsDialogState();
}

class _TwoActionsDialogState extends State<TwoActionsDialog>
    with DialogNavigationMixin {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return buildKeyboardNavigator(
      onConfirm: () => Navigator.of(context).pop(true),
      onCancel: () => Navigator.of(context).pop(false),
      handleEnterKey: widget.handleEnterKey,
      child: AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        title: widget.title is String
            ? Text(widget.title, textDirection: widget.textDirection)
            : widget.title,
        content: widget.customContent ??
            Text(widget.content, textDirection: widget.textDirection),
        actions: [
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(false),
            style: FilledButton.styleFrom(
                backgroundColor: cs.secondaryContainer,
                foregroundColor: cs.onSecondaryContainer),
            child: Text(
              widget.cancelText ?? 'common.cancel'.tr(),
              textDirection: widget.textDirection,
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
            child: Text(
              widget.confirmText ?? 'common.ok'.tr(),
              textDirection: widget.textDirection,
            ),
          ),
        ],
      ),
    );
  }
}

// ── WarningDialog ─────────────────────────────────────────────────────────────

/// דיאלוג אזהרה — כפתור ביטול כהה (הפעולה הבטוחה), אישור אדום (מסוכן)
class WarningDialog extends StatefulWidget {
  final dynamic title;
  final String content;
  final String? subtitle;
  final String? cancelText;
  final String? confirmText;
  final TextDirection? textDirection;

  const WarningDialog({
    super.key,
    required this.title,
    required this.content,
    this.subtitle,
    this.cancelText,
    this.confirmText,
    this.textDirection,
  });

  @override
  State<WarningDialog> createState() => _WarningDialogState();
}

class _WarningDialogState extends State<WarningDialog>
    with DialogNavigationMixin {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return buildKeyboardNavigator(
      onConfirm: () => Navigator.of(context).pop(true),
      onCancel: () => Navigator.of(context).pop(false),
      child: AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        title: widget.title is String
            ? Text(widget.title, textDirection: widget.textDirection)
            : widget.title,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.content, textDirection: widget.textDirection),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.subtitle!,
                style: TextStyle(color: cs.error, fontSize: 13),
                textDirection: widget.textDirection,
              ),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: FilledButton.styleFrom(
                backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
            child: Text(
              widget.cancelText ?? 'common.cancel'.tr(),
              textDirection: widget.textDirection,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: cs.error),
            child: Text(
              widget.confirmText ?? 'common.continue_action'.tr(),
              textDirection: widget.textDirection,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper functions ──────────────────────────────────────────────────────────

Future<bool?> showSingleActionDialog({
  required BuildContext context,
  required String title,
  String? content,
  Widget? customContent,
  String? confirmText,
  TextDirection? textDirection,
  bool barrierDismissible = true,
  bool Function()? onConfirm,
}) =>
    showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => SingleActionDialog(
          title: title,
          content: content,
          customContent: customContent,
          confirmText: confirmText,
          textDirection: textDirection,
          onConfirm: onConfirm),
    );

Future<bool?> showTwoActionsDialog({
  required BuildContext context,
  required String title,
  required String content,
  Widget? customContent,
  String? cancelText,
  String? confirmText,
  TextDirection? textDirection,
  bool barrierDismissible = true,
  bool handleEnterKey = true,
}) =>
    showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => TwoActionsDialog(
          title: title,
          content: content,
          customContent: customContent,
          cancelText: cancelText,
          confirmText: confirmText,
          handleEnterKey: handleEnterKey,
          textDirection: textDirection),
    );

Future<bool?> showWarningDialog({
  required BuildContext context,
  required String title,
  required String content,
  String? subtitle,
  String? cancelText,
  String? confirmText,
  TextDirection? textDirection,
  bool barrierDismissible = true,
}) =>
    showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => WarningDialog(
          title: title,
          content: content,
          subtitle: subtitle,
          cancelText: cancelText,
          confirmText: confirmText,
          textDirection: textDirection),
    );

Future<bool?> showDbCopyRequiredDialog({
  required BuildContext context,
  required String sizeText,
  bool barrierDismissible = false,
}) =>
    showTwoActionsDialog(
      context: context,
      title: 'dialogs.db_copy_required.title'.tr(),
      content: '',
      barrierDismissible: barrierDismissible,
      cancelText: 'dialogs.db_copy_required.cancel'.tr(),
      confirmText: 'dialogs.db_copy_required.confirm'.tr(),
      customContent: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'dialogs.db_copy_required.intro'.tr(namedArgs: {'size': sizeText}),
          ),
          const SizedBox(height: 12),
          Text(
            'dialogs.db_copy_required.instruction'.tr(),
          ),
          const SizedBox(height: 6),
          Text(
            'dialogs.db_copy_required.delete_note'.tr(),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
