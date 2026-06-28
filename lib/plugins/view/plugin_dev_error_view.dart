import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:otzaria/plugins/bloc/plugin_system_bloc.dart';
import 'package:otzaria/plugins/bloc/plugin_system_event.dart';
import 'package:otzaria/navigation/bloc/navigation_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_event.dart';
import 'package:otzaria/navigation/bloc/navigation_state.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/view/plugin_settings_screen.dart';
import 'package:otzaria/widgets/controls/action_buttons.dart';

class PluginDevErrorView extends StatelessWidget {
  final InstalledPlugin plugin;
  final String errorMessage;

  const PluginDevErrorView({
    super.key,
    required this.plugin,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FluentIcons.warning_24_filled,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'plugins.dev_error.title'.tr(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'plugins.dev_error.path'
                  .tr(namedArgs: {'path': plugin.resolvedRootPath}),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                errorMessage,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer),
                textDirection: TextDirection.ltr,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RecommendedActionButton(
                  text: 'plugins.dev_error.reload'.tr(),
                  onPressed: () {
                    context
                        .read<PluginSystemBloc>()
                        .add(ReloadDevelopmentPluginRequested(plugin.pluginId));
                  },
                ),
                const SizedBox(width: 16),
                NeutralActionButton(
                  text: 'plugins.dev_error.settings'.tr(),
                  onPressed: () async {
                    final result = await showDialog<bool>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => BlocProvider<PluginSystemBloc>.value(
                        value: context.read<PluginSystemBloc>(),
                        child: PluginSettingsScreen(plugin: plugin),
                      ),
                    );
                    if (result == true && context.mounted) {
                      context
                          .read<NavigationBloc>()
                          .add(const NavigateToScreen(Screen.more));
                    }
                  },
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
