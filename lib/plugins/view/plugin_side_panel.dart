import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/plugins/bloc/plugin_system_bloc.dart';
import 'package:otzaria/plugins/bloc/plugin_system_event.dart';
import 'package:otzaria/plugins/bloc/plugin_system_state.dart';
import 'package:otzaria/navigation/bloc/navigation_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_event.dart';
import 'package:otzaria/navigation/bloc/navigation_state.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/utils/fluent_icon_resolver.dart';
import 'package:otzaria/plugins/view/plugin_settings_screen.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/widgets/dialogs/dialogs_exports.dart';
import 'package:otzaria/widgets/misc/rtl_icon.dart';

class PluginSidePanel extends StatelessWidget {
  final Function(InstalledPlugin)? onPluginSelected;
  final bool showDevTools;
  final VoidCallback? onClose;

  const PluginSidePanel({
    super.key,
    this.onPluginSelected,
    this.showDevTools = kDebugMode,
    this.onClose,
  });

  Future<void> _installPlugin(BuildContext context) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['otzplugin'],
      lockParentWindow: true,
    );
    if (result != null && result.files.single.path != null) {
      if (context.mounted) {
        context
            .read<PluginSystemBloc>()
            .add(InstallPluginRequested(result.files.single.path!));
      }
    }
  }

  Future<void> _loadDevPlugin(BuildContext context) async {
    final rootPath = await FilePicker.getDirectoryPath(lockParentWindow: true);
    if (rootPath != null) {
      if (context.mounted) {
        context
            .read<PluginSystemBloc>()
            .add(LoadDevelopmentPluginRequested(rootPath));
      }
    }
  }

  Future<void> _loadLocalhostPlugin(BuildContext context) async {
    final bloc = context.read<PluginSystemBloc>();
    final url = await showInputDialog(
      context: context,
      title: 'טעינת תוסף מ-localhost',
      labelText: 'Base URL',
      hintText: 'http://localhost:3000',
      initialValue: 'http://localhost:3000',
      cancelText: 'ביטול',
      confirmText: 'טען',
    );
    if (url != null && url.isNotEmpty) {
      bloc.add(LoadLocalhostPluginRequested(url));
    }
  }

  void _handleReorder({
    required BuildContext context,
    required List<InstalledPlugin> allPlugins,
    required String sourcePluginId,
    required String targetPluginId,
  }) {
    if (sourcePluginId == targetPluginId) return;
    // עובדים על *כל* התוספים, לא רק על המסוננים לתצוגה. במצב מנותק חלק
    // מהתוספים מוסתרים — אם נשלח רק את הסדר של המוצגים, ה-DB יקבל
    // user_order חדש רק לחלק מהרשומות, ולתוספים המוסתרים יישאר user_order
    // ישן (או null). אחרי חזרה למצב מקוון זה גורם לערכי סדר כפולים ולמיון
    // לא דטרמיניסטי. עבודה על הרשימה המלאה משמרת את המיקום היחסי של
    // המוסתרים סביב התוספים המוצגים.
    final sourceIdx =
        allPlugins.indexWhere((p) => p.pluginId == sourcePluginId);
    final targetIdx =
        allPlugins.indexWhere((p) => p.pluginId == targetPluginId);
    if (sourceIdx < 0 || targetIdx < 0) return;

    // semantics: גרירה קדימה (sourceIdx<targetIdx) ⇒ source נכנס *אחרי*
    // target; גרירה אחורה (sourceIdx>targetIdx) ⇒ source נכנס *לפני* target.
    // הנוסחה `insert(targetIdx, src)` אחרי `removeAt(sourceIdx)` מטפלת
    // בשני המקרים: ב-forward, removeAt דוחק את כל מי שאחרי source לאחור,
    // אז targetIdx הקודם מצביע עכשיו על המיקום שאחרי target.
    final reordered = List.of(allPlugins);
    final src = reordered.removeAt(sourceIdx);
    reordered.insert(targetIdx, src);

    context.read<PluginSystemBloc>().add(
          ReorderPluginsRequested(
            reordered.map((p) => p.pluginId).toList(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              if (onClose != null)
                IconButton(
                  icon: const Icon(FluentIcons.dismiss_24_regular),
                  tooltip: 'plugins.side_panel.close_tooltip'.tr(),
                  onPressed: onClose,
                  iconSize: 20,
                ),
              Expanded(
                child: Text(
                  'plugins.side_panel.title'.tr(),
                  style:
                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              IconButton(
                icon: const Icon(FluentIcons.add_24_regular),
                tooltip: 'plugins.side_panel.install_tooltip'.tr(),
                onPressed: () => _installPlugin(context),
              ),
              if (showDevTools)
                IconButton(
                  icon: const Icon(FluentIcons.folder_add_24_regular),
                  tooltip: 'plugins.side_panel.load_folder_tooltip'.tr(),
                  onPressed: () => _loadDevPlugin(context),
                ),
              if (showDevTools)
                IconButton(
                  icon: const Icon(FluentIcons.globe_add_24_regular),
                  tooltip: 'plugins.side_panel.load_localhost_tooltip'.tr(),
                  onPressed: () => _loadLocalhostPlugin(context),
                ),
              if (showDevTools)
                IconButton(
                  icon: const Icon(FluentIcons.arrow_sync_24_regular),
                  tooltip: 'plugins.side_panel.refresh_tooltip'.tr(),
                  onPressed: () =>
                      context.read<PluginSystemBloc>().add(RefreshPlugins()),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: BlocBuilder<PluginSystemBloc, PluginSystemState>(
            builder: (context, state) {
              if (state is PluginSystemLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is PluginSystemError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('plugins.side_panel.error_message'
                        .tr(namedArgs: {'message': state.message})),
                  ),
                );
              }
              if (state is PluginSystemLoaded) {
                final isOfflineMode = context
                    .select<SettingsBloc, bool>((b) => b.state.isOfflineMode);
                // visiblePlugins מסנן תוספים שהמשתמש סימן כ"מוסתר" במסך
                // ההגדרות (`hiddenFromTools`); אחריו מסננים גם offline.
                final plugins =
                    state.visiblePlugins.filterForOfflineMode(isOfflineMode);
                if (plugins.isEmpty) {
                  // ההודעה משתנה לפי הסיבה: אם יש תוספים שמוסתרים ידנית,
                  // נציין זאת. אחרת — נציין offline או "לא הותקנו".
                  final allHiddenManually = state.plugins.isNotEmpty &&
                      state.plugins.every((p) => p.hiddenFromTools);
                  return Center(
                    child: Text(
                      allHiddenManually
                          ? 'plugins.side_panel.all_hidden'.tr()
                          : (isOfflineMode && state.plugins.isNotEmpty
                              ? 'plugins.side_panel.all_require_network'.tr()
                              : 'plugins.side_panel.no_plugins_installed'
                                  .tr()),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                // יישום ידני של גרירה במקום ReorderableListView:
                // ReorderableListView משתמש ב-OverlayPortal פנימי שגורם
                // לקריסות כשהפאנל יושב בתוך LayoutBuilder (FloatingPanel/
                // ContextOverlayPanel) — או mutation של LayoutBuilder תוך
                // performLayout, או _retakeInactiveElement כשה-state
                // הפנימי של Reorderable לא מסונכרן עם ה-Overlay החיצוני.
                // Draggable + DragTarget משתמשים ב-OverlayEntry פשוט יותר
                // ולא דורשים סנכרון state מורכב.
                return ListView.builder(
                  itemCount: plugins.length,
                  itemBuilder: (context, index) {
                    final plugin = plugins[index];
                    return _DraggablePluginRow(
                      key: ValueKey(plugin.pluginId),
                      plugin: plugin,
                      onAcceptSource: (sourceId) {
                        _handleReorder(
                          context: context,
                          allPlugins: state.plugins,
                          sourcePluginId: sourceId,
                          targetPluginId: plugin.pluginId,
                        );
                      },
                      onPluginSelected: onPluginSelected,
                    );
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }
}

/// שורת תוסף בודדת עם תמיכה בגרירה: כל השורה היא [DragTarget] שמקבל id
/// של תוסף אחר, וה-handle מימין הוא [Draggable] שמתחיל גרירה.
class _DraggablePluginRow extends StatelessWidget {
  final InstalledPlugin plugin;
  final ValueChanged<String> onAcceptSource;
  final Function(InstalledPlugin)? onPluginSelected;

  const _DraggablePluginRow({
    super.key,
    required this.plugin,
    required this.onAcceptSource,
    required this.onPluginSelected,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != plugin.pluginId,
      onAcceptWithDetails: (details) => onAcceptSource(details.data),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        final cs = Theme.of(context).colorScheme;
        return Container(
          decoration: isHovering
              ? BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  border: Border(
                    top: BorderSide(color: cs.primary, width: 2),
                  ),
                )
              : null,
          child: Material(
            color: Colors.transparent,
            child: _PluginListTile(
              plugin: plugin,
              onPluginSelected: onPluginSelected,
            ),
          ),
        );
      },
    );
  }
}

class _PluginListTile extends StatelessWidget {
  final InstalledPlugin plugin;
  final Function(InstalledPlugin)? onPluginSelected;

  const _PluginListTile({
    required this.plugin,
    required this.onPluginSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          RtlIcon(fluentIconFromName(plugin.manifest.toolTabIconName) ??
              FluentIcons.puzzle_piece_24_regular),
          if (plugin.isDevelopment)
            Positioned(
              right: -8,
              top: -8,
              child: Tooltip(
                message: 'plugins.side_panel.dev_plugin_tooltip'.tr(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'DEV',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onTertiary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(plugin.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(plugin.version),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(FluentIcons.settings_24_regular),
            tooltip: 'plugins.side_panel.settings_tooltip'.tr(),
            onPressed: () async {
              final result = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) => BlocProvider<PluginSystemBloc>.value(
                  value: context.read<PluginSystemBloc>(),
                  child: PluginSettingsScreen(plugin: plugin),
                ),
              );
              if (result == true && onPluginSelected != null) {
                if (context.mounted) {
                  context
                      .read<NavigationBloc>()
                      .add(const NavigateToScreen(Screen.more));
                  onPluginSelected!(plugin);
                }
              }
            },
          ),
          IconButton(
            icon: RtlIcon(
              plugin.pinned
                  ? FluentIcons.pin_24_filled
                  : FluentIcons.pin_24_regular,
            ),
            tooltip: plugin.pinned
                ? 'plugins.side_panel.unpin_tooltip'.tr()
                : 'plugins.side_panel.pin_tooltip'.tr(),
            onPressed: () {
              if (plugin.pinned) {
                context
                    .read<PluginSystemBloc>()
                    .add(UnpinPluginRequested(plugin.pluginId));
              } else {
                context
                    .read<PluginSystemBloc>()
                    .add(PinPluginRequested(plugin.pluginId));
              }
            },
          ),
          // ה-Draggable יושב רק על האייקון כדי שגרירה תתחיל ממנו ולא
          // מכל מקום ברצי (ככה Tap לפתוח את התוסף עדיין עובד טוב).
          Draggable<String>(
            data: plugin.pluginId,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            feedback: _DragFeedback(plugin: plugin),
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Tooltip(
                message: 'plugins.side_panel.drag_to_reorder'.tr(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0),
                  child: Icon(FluentIcons.re_order_dots_vertical_24_regular),
                ),
              ),
            ),
          ),
        ],
      ),
      onTap: () {
        if (onPluginSelected != null) {
          onPluginSelected!(plugin);
        }
      },
    );
  }
}

/// ה-widget שצף מתחת לסמן בזמן הגרירה. מוצג מעל Overlay של ה-Navigator
/// (לא OverlayPortal) ולכן אין חששות לקונפליקטים עם LayoutBuilders.
class _DragFeedback extends StatelessWidget {
  final InstalledPlugin plugin;

  const _DragFeedback({required this.plugin});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RtlIcon(FluentIcons.puzzle_piece_24_regular),
            const SizedBox(width: 8),
            Text(
              plugin.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
