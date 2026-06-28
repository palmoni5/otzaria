import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import 'package:otzaria/plugins/services/plugin_crash_guard.dart';
import 'package:otzaria/widgets/controls/action_buttons.dart';

/// תצוגה שמופיעה במקום WebView כשהתוסף הקריס את האפליקציה בהפעלה הקודמת
/// (נשאר ב-PluginCrashGuard). מספקת למשתמש כפתור "נסה שוב" שמסיר את
/// ה-quarantine ומבקש מהאפליקציה לטעון מחדש.
class PluginCrashedView extends StatefulWidget {
  final String pluginId;
  final String? pluginName;

  /// נקרא אחרי שהמשתמש לחץ "נסה שוב" — האחראי על rebuild של הטאב כך
  /// שניסיון טעינה חדש יתבצע.
  final VoidCallback onRetry;

  const PluginCrashedView({
    super.key,
    required this.pluginId,
    required this.onRetry,
    this.pluginName,
  });

  @override
  State<PluginCrashedView> createState() => _PluginCrashedViewState();
}

class _PluginCrashedViewState extends State<PluginCrashedView> {
  bool _retrying = false;

  Future<void> _handleRetry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await PluginCrashGuard.retry(widget.pluginId);
    } finally {
      if (mounted) {
        setState(() => _retrying = false);
        widget.onRetry();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final pluginLabel = widget.pluginName ?? widget.pluginId;

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
                'plugins.crashed.title'.tr(namedArgs: {'name': pluginLabel}),
                style: tt.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'plugins.crashed.explanation'.tr(),
                style: tt.bodyMedium,
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
                      'plugins.crashed.what_to_do'.tr(),
                      style: tt.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'plugins.crashed.instructions'.tr(),
                      style: tt.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  RecommendedActionButton(
                    text: 'plugins.crashed.retry'.tr(),
                    icon: FluentIcons.arrow_clockwise_24_regular,
                    isLoading: _retrying,
                    onPressed: _handleRetry,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
