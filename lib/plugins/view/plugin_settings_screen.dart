import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/bloc/plugin_system_bloc.dart';
import 'package:otzaria/plugins/bloc/plugin_system_event.dart';
import 'package:otzaria/plugins/bloc/plugin_system_state.dart';
import 'package:otzaria/plugins/models/plugin_permission_labels.dart';
import 'package:otzaria/plugins/models/plugin_valid_permissions.dart';
import 'package:otzaria/plugins/repository/plugin_registry_repository.dart';
import 'package:otzaria/widgets/buttons/action_buttons.dart';
import 'package:otzaria/widgets/dialogs/dialogs_exports.dart';
import 'package:otzaria/settings/settings_card.dart';

class PluginSettingsScreen extends StatefulWidget {
  final InstalledPlugin plugin;

  const PluginSettingsScreen({super.key, required this.plugin});

  @override
  State<PluginSettingsScreen> createState() => _PluginSettingsScreenState();
}

class _PluginSettingsScreenState extends State<PluginSettingsScreen> {
  final _repo = PluginRegistryRepository();
  Map<String, bool> _permissions = {};

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    Map<String, bool> map = {};
    for (final p in widget.plugin.manifest.permissions) {
      final granted = await _repo.getPermission(widget.plugin.pluginId, p);
      // הרשאות רגישות (כמו טעינה ברקע) ברירת מחדל = false;
      // שאר ההרשאות ברירת מחדל = true כפי שמטופל בגשר.
      final defaultValue = p != pluginRunOnStartupPermission;
      map[p] = granted ?? defaultValue;
    }
    setState(() {
      _permissions = map;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Wrap with BlocBuilder so that we get latest state (e.g. for enabled)
    return BlocBuilder<PluginSystemBloc, PluginSystemState>(
        builder: (context, state) {
      InstalledPlugin currentPlugin = widget.plugin;
      if (state is PluginSystemLoaded) {
        try {
          currentPlugin = state.plugins
              .firstWhere((p) => p.pluginId == widget.plugin.pluginId);
        } catch (_) {
          // plugin uninstalled or not found
        }
      }

      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        clipBehavior: Clip.antiAlias,
        child: Scaffold(
          appBar: AppBar(
              title: Text('plugins.settings_screen.title'
                  .tr(namedArgs: {'name': currentPlugin.name}))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SettingsCard(
                title: 'plugins.settings_screen.general_section'.tr(),
                children: [
                  SwitchListTile(
                    title:
                        Text('plugins.settings_screen.enabled_title'.tr()),
                    subtitle: Text(
                        'plugins.settings_screen.enabled_subtitle'.tr()),
                    value: currentPlugin.enabled,
                    onChanged: (val) {
                      if (val) {
                        context
                            .read<PluginSystemBloc>()
                            .add(EnablePluginRequested(currentPlugin.pluginId));
                      } else {
                        context.read<PluginSystemBloc>().add(
                            DisablePluginRequested(currentPlugin.pluginId));
                      }
                    },
                    hoverColor: Colors.transparent,
                  ),
                  SwitchListTile(
                    title: Text('plugins.settings_screen.pin_title'.tr()),
                    subtitle:
                        Text('plugins.settings_screen.pin_subtitle'.tr()),
                    value: currentPlugin.pinnedToNavRail,
                    onChanged: currentPlugin.enabled
                        ? (val) {
                            if (val) {
                              context.read<PluginSystemBloc>().add(
                                  PinPluginToNavRailRequested(
                                      currentPlugin.pluginId));
                            } else {
                              context.read<PluginSystemBloc>().add(
                                  UnpinPluginFromNavRailRequested(
                                      currentPlugin.pluginId));
                            }
                          }
                        : null,
                    hoverColor: Colors.transparent,
                  ),
                ],
              ),
              if (currentPlugin.manifest.permissions.isNotEmpty) ...[
                const SizedBox(height: 16),
                SettingsCard(
                  title: 'plugins.settings_screen.permissions_section'.tr(),
                  subtitle:
                      'plugins.settings_screen.permissions_subtitle'.tr(),
                  children: currentPlugin.manifest.permissions.map((p) {
                    final info = getPermissionInfo(p);
                    final defaultValue = p != pluginRunOnStartupPermission;
                    final isGranted = _permissions[p] ?? defaultValue;
                    final isSensitive = p == pluginRunOnStartupPermission;
                    final colorScheme = Theme.of(context).colorScheme;
                    final iconData = isSensitive
                        ? (isGranted
                            ? FluentIcons.warning_24_filled
                            : FluentIcons.warning_24_regular)
                        : (isGranted
                            ? FluentIcons.shield_checkmark_24_regular
                            : FluentIcons.shield_error_24_regular);
                    final iconColor = isSensitive
                        ? colorScheme.tertiary
                        : (isGranted ? colorScheme.primary : colorScheme.error);
                    return SwitchListTile(
                      secondary: Icon(iconData, color: iconColor),
                      title: Text(
                        info.label,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: isSensitive ? colorScheme.tertiary : null,
                        ),
                      ),
                      subtitle: Text(
                        info.description,
                        textDirection: TextDirection.rtl,
                      ),
                      value: isGranted,
                      onChanged: (val) async {
                        context
                            .read<PluginSystemBloc>()
                            .add(SetPluginPermissionRequested(
                              pluginId: currentPlugin.pluginId,
                              permission: p,
                              granted: val,
                            ));
                        setState(() {
                          _permissions[p] = val;
                        });
                      },
                      hoverColor: Colors.transparent,
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 32),
              if (currentPlugin.isDevelopment) ...[
                SettingsCard(
                    title: 'plugins.settings_screen.dev_section'.tr(),
                    children: [
                  ListTile(
                    title:
                        Text('plugins.settings_screen.folder_path'.tr()),
                    subtitle: Text(currentPlugin.resolvedRootPath),
                  ),
                  ListTile(
                    title: Text('plugins.settings_screen.reload_now'.tr()),
                    trailing:
                        const Icon(FluentIcons.arrow_clockwise_24_regular),
                    onTap: () {
                      context.read<PluginSystemBloc>().add(
                          ReloadDevelopmentPluginRequested(
                              currentPlugin.pluginId));
                    },
                    hoverColor: Colors.transparent,
                  ),
                  ListTile(
                    title:
                        Text('plugins.settings_screen.reopen_view'.tr()),
                    trailing: const Icon(FluentIcons.window_new_24_regular),
                    onTap: () {
                      context.read<PluginSystemBloc>().add(
                          ReloadDevelopmentPluginRequested(
                              currentPlugin.pluginId));
                      Navigator.of(context).pop(true);
                    },
                    hoverColor: Colors.transparent,
                  ),
                ]),
                const SizedBox(height: 16),
                NeutralActionButton(
                  text:
                      'plugins.settings_screen.disconnect_dev_plugin'.tr(),
                  onPressed: () async {
                    context.read<PluginSystemBloc>().add(
                        DetachDevelopmentPluginRequested(
                            currentPlugin.pluginId));
                    Navigator.of(context).pop();
                  },
                )
              ] else ...[
                NeutralActionButton(
                  text: 'plugins.settings_screen.remove_plugin'.tr(),
                  onPressed: () async {
                    final confirm = await showWarningDialog(
                      context: context,
                      title:
                          'plugins.settings_screen.delete_dialog_title'.tr(),
                      content: 'plugins.settings_screen.delete_dialog_content'
                          .tr(namedArgs: {'name': currentPlugin.name}),
                      subtitle: 'plugins.settings_screen.delete_dialog_subtitle'
                          .tr(),
                      cancelText: 'common.cancel'.tr(),
                      confirmText:
                          'plugins.settings_screen.delete_confirm'.tr(),
                    );
                    if (confirm == true && context.mounted) {
                      context.read<PluginSystemBloc>().add(
                          UninstallPluginRequested(currentPlugin.pluginId));
                      Navigator.of(context).pop();
                    }
                  },
                )
              ]
            ],
          ),
        ),
      );
    });
  }
}
