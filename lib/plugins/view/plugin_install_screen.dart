import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/plugins/bloc/plugin_system_bloc.dart';
import 'package:otzaria/plugins/bloc/plugin_system_event.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:otzaria/plugins/models/plugin_permission_labels.dart';
import 'package:otzaria/plugins/models/plugin_valid_permissions.dart';
import 'package:otzaria/widgets/controls/action_buttons.dart';
import 'package:otzaria/settings/widgets/settings_card.dart';

/// מסך אישור התקנת/עדכון תוסף — מאפשר למשתמש לבחור אילו הרשאות להעניק
class PluginInstallScreen extends StatefulWidget {
  final PluginManifest manifest;
  final String tempDirPath;

  /// גרסה מותקנת קודמת — null אם זו התקנה ראשונה.
  final String? previousVersion;

  /// בחירה קודמת של המשתמש לגבי הקדמת התוסף לפני כלים מובנים.
  /// `null` = אין החלטה קודמת (התקנה ראשונה או תוסף ישן לפני הפיצ'ר).
  final bool? previousAllowOrderBeforeBuiltInsGranted;

  const PluginInstallScreen({
    super.key,
    required this.manifest,
    required this.tempDirPath,
    this.previousVersion,
    this.previousAllowOrderBeforeBuiltInsGranted,
  });

  bool get isUpdate => previousVersion != null;

  @override
  State<PluginInstallScreen> createState() => _PluginInstallScreenState();
}

class _PluginInstallScreenState extends State<PluginInstallScreen> {
  /// מצב toggle לכל הרשאה — ברירת מחדל: הכל מופעל, פרט להרשאות רגישות
  /// (למשל [pluginRunOnStartupPermission]) שמתחילות כבויות.
  late Map<String, bool> _permissionToggles;
  late bool _allowOrderBeforeBuiltInsGranted;

  @override
  void initState() {
    super.initState();
    _permissionToggles = {
      for (final p in widget.manifest.permissions)
        p: p != pluginRunOnStartupPermission,
    };
    _allowOrderBeforeBuiltInsGranted =
        widget.previousAllowOrderBeforeBuiltInsGranted ??
            widget.manifest.allowOrderBeforeBuiltIns;
  }

  bool get _requestsRunOnStartup =>
      widget.manifest.permissions.contains(pluginRunOnStartupPermission);

  bool get _requestsOrderBeforeBuiltIns =>
      widget.manifest.allowOrderBeforeBuiltIns;

  void _onInstall() {
    context.read<PluginSystemBloc>().add(
          ConfirmPluginInstall(
            widget.tempDirPath,
            widget.manifest,
            Map.unmodifiable(_permissionToggles),
            _allowOrderBeforeBuiltInsGranted,
          ),
        );
    Navigator.of(context).pop();
  }

  void _onCancel() {
    context
        .read<PluginSystemBloc>()
        .add(CancelPluginInstall(widget.tempDirPath));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hasPermissions = widget.manifest.permissions.isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;
    final isUpdate = widget.isUpdate;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      clipBehavior: Clip.antiAlias,
      child: PopScope(
        // מניעת יציאה בלי ניקוי — Back של מערכת מטופל ידנית
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _onCancel();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              isUpdate
                  ? 'plugins.install_screen.title_update'.tr()
                  : 'plugins.install_screen.title_install'.tr(),
            ),
            leading: IconButton(
              icon: const Icon(FluentIcons.dismiss_24_regular),
              tooltip: 'plugins.install_screen.cancel_tooltip'.tr(),
              onPressed: _onCancel,
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ===== כרטיס פרטי התוסף =====
              SettingsCard(
                title: widget.manifest.name,
                subtitle: widget.manifest.description.isNotEmpty
                    ? widget.manifest.description
                    : null,
                children: [
                  if (widget.manifest.author.isNotEmpty)
                    ListTile(
                      leading: const Icon(FluentIcons.person_24_regular),
                      title: Text(
                        'plugins.install_screen.author_label'.tr(),
                      ),
                      subtitle: Text(
                        widget.manifest.author,
                      ),
                      hoverColor: Colors.transparent,
                    ),
                  if (isUpdate)
                    ListTile(
                      leading:
                          const Icon(FluentIcons.arrow_circle_up_24_regular),
                      title: Text(
                        'plugins.install_screen.version_update_label'.tr(),
                      ),
                      subtitle: Text(
                        '${widget.previousVersion}  →  ${widget.manifest.version}',
                      ),
                      hoverColor: Colors.transparent,
                    )
                  else
                    ListTile(
                      leading: const Icon(FluentIcons.tag_24_regular),
                      title: Text(
                        'plugins.install_screen.version_label'.tr(),
                      ),
                      subtitle: Text(
                        widget.manifest.version,
                      ),
                      hoverColor: Colors.transparent,
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // ===== באנר בולט: בקשת טעינה אוטומטית עם עליית האפליקציה =====
              if (_requestsRunOnStartup) ...[
                _RunOnStartupBanner(colorScheme: colorScheme),
                const SizedBox(height: 16),
              ],

              if (_requestsOrderBeforeBuiltIns) ...[
                SettingsCard(
                  title: 'מיקום במסך כלים',
                  subtitle: 'התוסף מבקש להופיע לפני הכלים המובנים במסך "כלים".',
                  children: [
                    SwitchListTile(
                      secondary: Icon(
                        _allowOrderBeforeBuiltInsGranted
                            ? FluentIcons.arrow_sort_up_24_regular
                            : FluentIcons.arrow_sort_24_regular,
                        color: _allowOrderBeforeBuiltInsGranted
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      title: const Text(
                        'אפשר לתוסף להופיע לפני הכלים המובנים',
                      ),
                      subtitle: const Text(
                        'אם תכבה את האפשרות, התוסף עדיין יותקן כרגיל, אבל '
                        'יופיע רק אחרי הכלים המובנים גם אם המניפסט שלו ביקש אחרת.',
                      ),
                      value: _allowOrderBeforeBuiltInsGranted,
                      onChanged: (value) {
                        setState(() {
                          _allowOrderBeforeBuiltInsGranted = value;
                        });
                      },
                      hoverColor: Colors.transparent,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // ===== הרשאות =====
              if (!hasPermissions)
                SettingsCard(
                  title: 'plugins.install_screen.permissions_section'.tr(),
                  children: [
                    ListTile(
                      leading: Icon(
                        FluentIcons.shield_checkmark_24_regular,
                        color: colorScheme.primary,
                      ),
                      title: Text(
                        'plugins.install_screen.no_permissions_required'.tr(),
                      ),
                      subtitle: Text(
                        'plugins.install_screen.no_permissions_subtitle'.tr(),
                      ),
                      hoverColor: Colors.transparent,
                    ),
                  ],
                )
              else ...[
                SettingsCard(
                  title: 'plugins.install_screen.permissions_required_section'
                      .tr(),
                  subtitle:
                      'plugins.install_screen.permissions_required_subtitle'
                          .tr(),
                  children: widget.manifest.permissions.map((permission) {
                    final info = getPermissionInfo(permission);
                    final isGranted = _permissionToggles[permission] ?? true;
                    final isSensitive =
                        permission == pluginRunOnStartupPermission;
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
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: isSensitive ? colorScheme.tertiary : null,
                        ),
                      ),
                      subtitle: Text(
                        info.description,
                      ),
                      value: isGranted,
                      onChanged: (val) {
                        setState(() {
                          _permissionToggles[permission] = val;
                        });
                      },
                      hoverColor: Colors.transparent,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                // הסבר שניתן לשנות אחרי ההתקנה
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      Icon(
                        FluentIcons.info_24_regular,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'plugins.install_screen.permissions_changeable_note'
                              .tr(),
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // ===== כפתורי פעולה =====
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  NeutralActionButton(
                    text: 'plugins.install_screen.cancel_button'.tr(),
                    onPressed: _onCancel,
                  ),
                  const SizedBox(width: 12),
                  RecommendedActionButton(
                    text: isUpdate
                        ? 'plugins.install_screen.update_button'.tr()
                        : 'plugins.install_screen.install_button'.tr(),
                    onPressed: _onInstall,
                  ),
                ],
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// באנר בולט שמודיע למשתמש שהתוסף מבקש לרוץ ברקע עם עליית האפליקציה.
///
/// ההרשאה כבויה ברירת מחדל; הבאנר מסביר מה ההשלכות ומנחה להפעיל
/// רק תוספים מהימנים.
class _RunOnStartupBanner extends StatelessWidget {
  final ColorScheme colorScheme;

  const _RunOnStartupBanner({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.tertiary,
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            FluentIcons.warning_24_filled,
            color: colorScheme.tertiary,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'plugins.install_screen.startup_permission_title'.tr(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: colorScheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'plugins.install_screen.startup_permission_description'.tr(),
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onTertiaryContainer,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
