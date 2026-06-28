import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:otzaria/widgets/misc/keyboard_dialog_navigation.dart';

/// דיאלוג אישור עם תמיכה באנטר וחיצים
class ConfirmationDialog extends StatefulWidget {
  final String title;
  final String content;
  final String? cancelText;
  final String? confirmText;
  final Color? confirmColor;
  final bool isDangerous;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.content,
    this.cancelText,
    this.confirmText,
    this.confirmColor,
    this.isDangerous = false,
  });

  @override
  State<ConfirmationDialog> createState() => _ConfirmationDialogState();
}

class _ConfirmationDialogState extends State<ConfirmationDialog>
    with DialogNavigationMixin {
  @override
  Widget build(BuildContext context) {
    return buildKeyboardNavigator(
      onConfirm: () => Navigator.of(context).pop(true),
      onCancel: () => Navigator.of(context).pop(false),
      child: AlertDialog(
        title: Text(widget.title),
        content: Text(widget.content),
        actions: [
          _buildButton(
            text: widget.cancelText ?? 'common.cancel'.tr(),
            isFocused: focusedButtonIndex == 0,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          _buildButton(
            text: widget.confirmText ?? 'common.ok'.tr(),
            isFocused: focusedButtonIndex == 1,
            isConfirm: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String text,
    required bool isFocused,
    required VoidCallback onPressed,
    bool isConfirm = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final color = isConfirm
        ? (widget.confirmColor ?? (widget.isDangerous ? cs.error : cs.primary))
        : null;
    final foregroundColor = color == null
        ? null
        : (widget.confirmColor == null
            ? (widget.isDangerous ? cs.onError : cs.onPrimary)
            : (ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                ? cs.surface
                : cs.onSurface));

    if (isConfirm) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: isFocused ? color!.withValues(alpha: 0.9) : color,
          foregroundColor: foregroundColor,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: isFocused ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      );
    }

    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: isFocused
            ? cs.secondaryContainer.withValues(alpha: 0.9)
            : cs.secondaryContainer,
        foregroundColor: cs.onSecondaryContainer,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isFocused ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

/// הצגת דיאלוג אישור
Future<bool?> showConfirmationDialog({
  required BuildContext context,
  required String title,
  required String content,
  String? cancelText,
  String? confirmText,
  Color? confirmColor,
  bool isDangerous = false,
  bool barrierDismissible = true,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (context) => ConfirmationDialog(
      title: title,
      content: content,
      cancelText: cancelText,
      confirmText: confirmText,
      confirmColor: confirmColor,
      isDangerous: isDangerous,
    ),
  );
}
