import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:otzaria/core/focus_repository.dart';
import 'package:otzaria/widgets/text/rtl_text_field.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/widgets/misc/keyboard_dialog_navigation.dart';

/// דיאלוג לאימות סיסמה למצב מוגן
class PasswordVerificationDialog extends StatefulWidget {
  final Future<bool> Function(String password) onVerify;
  final String? title;
  final String? hint;

  const PasswordVerificationDialog({
    super.key,
    required this.onVerify,
    this.title,
    this.hint,
  });

  @override
  State<PasswordVerificationDialog> createState() =>
      _PasswordVerificationDialogState();
}

class _PasswordVerificationDialogState extends State<PasswordVerificationDialog>
    with
        DialogNavigationMixin,
        DialogFocusRestorerMixin<PasswordVerificationDialog> {
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _textFieldFocusNode = FocusNode();
  bool _isObscured = true;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    registerDialogFocusRestorer(_textFieldFocusNode);
    // תן פוקוס לשדה הטקסט אחרי שהדיאלוג נפתח
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _textFieldFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    if (_passwordController.text.isEmpty) {
      UiSnack.showError('settings.safer_mode.empty_password_error'.tr());
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      final isValid = await widget.onVerify(_passwordController.text);

      if (!mounted) return;

      if (isValid) {
        Navigator.of(context).pop(true);
      } else {
        UiSnack.showError('settings.safer_mode.wrong_password_error'.tr());
        _passwordController.clear();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return buildKeyboardNavigator(
      onConfirm: _handleVerify,
      onCancel: () => Navigator.of(context).pop(false),
      textFieldFocusNode: _textFieldFocusNode,
      child: AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Icon(FluentIcons.lock_closed_24_regular),
            const SizedBox(width: 8),
            Text(
              widget.title ?? 'settings.safer_mode.verify_title'.tr(),
              style: const TextStyle(fontSize: 20),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.hint != null) ...[
                Text(
                  widget.hint!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              RtlTextField(
                controller: _passwordController,
                focusNode: _textFieldFocusNode,
                obscureText: _isObscured,
                enabled: !_isVerifying,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'settings.safer_mode.password_label'.tr(),
                  hintText: 'settings.safer_mode.password_hint'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(FluentIcons.key_24_regular),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isObscured
                          ? FluentIcons.eye_24_regular
                          : FluentIcons.eye_off_24_regular,
                    ),
                    onPressed: () {
                      setState(() {
                        _isObscured = !_isObscured;
                      });
                    },
                  ),
                ),
                onSubmitted: (_) => _handleVerify(),
              ),
            ],
          ),
        ),
        actions: [
          _buildButton(
            text: 'common.cancel'.tr(),
            isFocused: focusedButtonIndex == 0,
            onPressed: () => Navigator.of(context).pop(false),
            enabled: !_isVerifying,
          ),
          _buildButton(
            text: 'common.ok'.tr(),
            isFocused: focusedButtonIndex == 1,
            isConfirm: true,
            onPressed: _handleVerify,
            enabled: !_isVerifying,
            isLoading: _isVerifying,
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String text,
    required bool isFocused,
    required VoidCallback onPressed,
    required bool enabled,
    bool isConfirm = false,
    bool isLoading = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final showHover = isFocused && !_textFieldFocusNode.hasFocus;

    if (isConfirm) {
      return FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor:
              showHover ? cs.primary.withValues(alpha: 0.9) : cs.primary,
          foregroundColor: cs.onPrimary,
        ),
        child: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(text),
      );
    } else {
      return FilledButton.tonal(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: showHover
              ? cs.secondaryContainer.withValues(alpha: 0.9)
              : cs.secondaryContainer,
          foregroundColor: cs.onSecondaryContainer,
        ),
        child: Text(text),
      );
    }
  }
}

/// דיאלוג להגדרת סיסמה חדשה
class SetPasswordDialog extends StatefulWidget {
  final Future<void> Function(String password) onSetPassword;

  const SetPasswordDialog({
    super.key,
    required this.onSetPassword,
  });

  @override
  State<SetPasswordDialog> createState() => _SetPasswordDialogState();
}

class _SetPasswordDialogState extends State<SetPasswordDialog>
    with DialogNavigationMixin, DialogFocusRestorerMixin<SetPasswordDialog> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmFocusNode = FocusNode();
  bool _isObscured1 = true;
  bool _isObscured2 = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    registerDialogFocusRestorer(_passwordFocusNode);
    // תן פוקוס לשדה הראשון אחרי שהדיאלוג נפתח
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _passwordFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _passwordFocusNode.dispose();
    _confirmFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_passwordController.text.isEmpty) {
      UiSnack.showError('settings.safer_mode.empty_password_error'.tr());
      return;
    }

    if (_passwordController.text.length < 4) {
      UiSnack.showError('settings.safer_mode.min_length_error'.tr());
      return;
    }

    if (_passwordController.text != _confirmController.text) {
      UiSnack.showError('settings.safer_mode.passwords_mismatch_error'.tr());
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.onSetPassword(_passwordController.text);

      if (!mounted) return;

      UiSnack.show('settings.safer_mode.password_saved'.tr());
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      UiSnack.showError('settings.safer_mode.save_error'
          .tr(namedArgs: {'error': e.toString()}));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return buildKeyboardNavigator(
      onConfirm: _handleSave,
      onCancel: () => Navigator.of(context).pop(false),
      textFieldFocusNode: _passwordFocusNode,
      child: AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'settings.safer_mode.set_title'.tr(),
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 8),
            const Icon(FluentIcons.lock_closed_24_regular),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'settings.safer_mode.set_description'.tr(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              RtlTextField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                obscureText: _isObscured1,
                enabled: !_isSaving,
                decoration: InputDecoration(
                  labelText: 'settings.safer_mode.new_password_label'.tr(),
                  hintText: 'settings.safer_mode.new_password_hint'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(FluentIcons.key_24_regular),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isObscured1
                          ? FluentIcons.eye_24_regular
                          : FluentIcons.eye_off_24_regular,
                    ),
                    onPressed: () {
                      setState(() {
                        _isObscured1 = !_isObscured1;
                      });
                    },
                  ),
                ),
                onSubmitted: (_) => _confirmFocusNode.requestFocus(),
              ),
              const SizedBox(height: 16),
              RtlTextField(
                controller: _confirmController,
                focusNode: _confirmFocusNode,
                obscureText: _isObscured2,
                enabled: !_isSaving,
                decoration: InputDecoration(
                  labelText: 'settings.safer_mode.confirm_label'.tr(),
                  hintText: 'settings.safer_mode.confirm_hint'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(FluentIcons.checkmark_lock_24_regular),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isObscured2
                          ? FluentIcons.eye_24_regular
                          : FluentIcons.eye_off_24_regular,
                    ),
                    onPressed: () {
                      setState(() {
                        _isObscured2 = !_isObscured2;
                      });
                    },
                  ),
                ),
                onSubmitted: (_) => _handleSave(),
              ),
            ],
          ),
        ),
        actions: [
          _buildButton(
            text: 'common.cancel'.tr(),
            isFocused: focusedButtonIndex == 0,
            onPressed: () => Navigator.of(context).pop(false),
            enabled: !_isSaving,
          ),
          _buildButton(
            text: 'common.save'.tr(),
            isFocused: focusedButtonIndex == 1,
            isConfirm: true,
            onPressed: _handleSave,
            enabled: !_isSaving,
            isLoading: _isSaving,
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String text,
    required bool isFocused,
    required VoidCallback onPressed,
    required bool enabled,
    bool isConfirm = false,
    bool isLoading = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final showHover = isFocused &&
        !_passwordFocusNode.hasFocus &&
        !_confirmFocusNode.hasFocus;

    if (isConfirm) {
      return FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor:
              showHover ? cs.primary.withValues(alpha: 0.9) : cs.primary,
          foregroundColor: cs.onPrimary,
        ),
        child: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(text),
      );
    } else {
      return FilledButton.tonal(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: showHover
              ? cs.secondaryContainer.withValues(alpha: 0.9)
              : cs.secondaryContainer,
          foregroundColor: cs.onSecondaryContainer,
        ),
        child: Text(text),
      );
    }
  }
}
