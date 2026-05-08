import 'dart:io';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:window_manager/window_manager.dart';
import 'package:otzaria/navigation/bloc/navigation_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_state.dart';
import 'package:otzaria/theme/app_surfaces.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/tabs/bloc/tabs_state.dart';
import 'package:otzaria/tabs/bloc/tabs_event.dart';
import 'package:otzaria/tabs/models/commentators_tab.dart';
import 'package:otzaria/tabs/models/pdf_commentators_tab.dart';
import 'package:otzaria/tabs/models/pdf_tab.dart';
import 'package:otzaria/tabs/models/text_tab.dart';
import 'package:otzaria/tabs/models/combined_tab.dart';
import 'package:otzaria/tabs/models/searching_tab.dart';
import 'package:otzaria/widgets/navigation/scrollable_tab_bar.dart';
import 'package:otzaria/tabs/models/tab.dart';
import 'package:otzaria/history/view/history_screen.dart';
import 'package:otzaria/widgets/misc/app_menu_exports.dart';
import 'package:otzaria/bookmarks/view/bookmark_screen.dart';
import 'package:otzaria/workspaces/view/workspace_switcher_dialog.dart';
import 'package:otzaria/utils/ui/fullscreen_helper.dart';
import 'package:otzaria/utils/text/text_manipulation.dart';
import 'package:otzaria/history/bloc/history_bloc.dart';
import 'package:otzaria/history/bloc/history_event.dart';
import 'package:otzaria/library/bloc/library_bloc.dart';
import 'package:otzaria/library/bloc/library_state.dart';
import 'package:otzaria/workspaces/bloc/workspace_bloc.dart';
import 'package:otzaria/workspaces/bloc/workspace_event.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/settings/settings_exports.dart';
import 'package:otzaria/tour/tour_target_keys.dart';

class CustomTitleBar extends StatefulWidget {
  final VoidCallback? onReadingSettingsPressed;
  final bool isReadingSettingsPanelOpen;

  const CustomTitleBar({
    super.key,
    this.onReadingSettingsPressed,
    this.isReadingSettingsPanelOpen = false,
  });

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

const double _kAppBarControlsWidth = 105.0;
const double _kWindowCaptionButtonsWidth = 138.0;
const double _kWindowCaptionButtonWidth = 46.0;

/// סגנון משותף לכפתורי האייקון בשורת הכותרת
final ButtonStyle _kIconButtonStyle = IconButton.styleFrom(
  minimumSize: const Size(32, 32),
  padding: EdgeInsets.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8),
  ),
);

class _CustomTitleBarState extends State<CustomTitleBar>
    with TickerProviderStateMixin {
  bool _tabsOverflow = false;
  TabController? _tabController;

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _handleReadingTabControllerChange() {
    final controller = _tabController;
    if (controller == null) return;
    final tabsState = context.read<TabsBloc>().state;
    if (!tabsState.hasOpenTabs) return;

    if (controller.indexIsChanging &&
        controller.index != tabsState.currentTabIndex) {
      context.read<TabsBloc>().add(SetCurrentTab(controller.index));
    }
  }

  void _ensureReadingTabController(TabsState state) {
    if (!state.hasOpenTabs) return;

    final validIndex = state.currentTabIndex.clamp(0, state.tabs.length - 1);
    if (_tabController == null || _tabController!.length != state.tabs.length) {
      _tabController?.dispose();
      _tabController = TabController(
        length: state.tabs.length,
        vsync: this,
        initialIndex: validIndex,
      )..addListener(_handleReadingTabControllerChange);
      return;
    }

    if (_tabController!.index != validIndex &&
        !_tabController!.indexIsChanging) {
      _tabController!.animateTo(validIndex);
    }
  }

  bool _useStackedTabs(BuildContext context, NavigationState navState) {
    final isReading = navState.currentScreen == Screen.reading ||
        navState.currentScreen == Screen.search;
    if (!isReading) return false;
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NavigationBloc, NavigationState>(
      builder: (context, navState) {
        return BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, settingsState) {
            final stackedTabs = _useStackedTabs(context, navState);
            final topBar = SizedBox(
              height: 40,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    clipBehavior: Clip.none,
                    decoration: BoxDecoration(
                      color: (navState.currentScreen == Screen.reading ||
                              navState.currentScreen == Screen.search)
                          ? Theme.of(context).colorScheme.surface
                          : AppSurfaces.solidPanelBackground(context),
                      border: (navState.currentScreen == Screen.reading ||
                              navState.currentScreen == Screen.search)
                          ? null
                          : Border(
                              bottom: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant
                                    .withValues(alpha: 0.6),
                                width: 1,
                              ),
                            ),
                    ),
                    child: Row(
                      children: [
                        // כפתורי פעולה (היסטוריה וכו') - תמיד מוצגים
                        SizedBox(
                          height: 40,
                          child: Stack(
                            children: [
                              Center(
                                child: _buildActionButtons(context),
                              ),
                              if (navState.currentScreen == Screen.reading ||
                                  navState.currentScreen == Screen.search)
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Align(
                                    alignment: AlignmentDirectional.bottomStart,
                                    child: Container(
                                      width: 74,
                                      height: 1,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outlineVariant
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // תוכן הכותרת (טאבים או כותרת רגילה)
                        Expanded(
                          child: _buildContent(context, navState),
                        ),

                        // כפתורי חלון (רק בדסקטופ)
                        if (!kIsWeb &&
                            (Platform.isWindows ||
                                Platform.isLinux ||
                                Platform.isMacOS))
                          SizedBox(
                            height: 50,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildFullscreenCaptionButton(
                                    context, settingsState),
                                if (settingsState.isFullscreen)
                                  _CaptionActionButton(
                                    brightness: Theme.of(context).brightness,
                                    tooltip:
                                        'navigation.title_bar.minimize'.tr(),
                                    icon: FluentIcons.subtract_24_regular,
                                    onPressed: () async {
                                      await FullscreenHelper.toggleFullscreen(
                                          context, false);
                                      await windowManager.minimize();
                                    },
                                  ),
                                if (settingsState.isFullscreen)
                                  _CaptionActionButton(
                                    brightness: Theme.of(context).brightness,
                                    tooltip: 'navigation.title_bar.close'.tr(),
                                    icon: FluentIcons.dismiss_24_regular,
                                    onPressed: () => windowManager.close(),
                                  ),
                                if (!settingsState.isFullscreen)
                                  SizedBox(
                                    width: _kWindowCaptionButtonsWidth,
                                    height: 50,
                                    child: WindowCaption(
                                      brightness: Theme.of(context).brightness,
                                      backgroundColor: Colors.transparent,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );

            if (!stackedTabs) return topBar;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                topBar,
                _buildNarrowTabsRow(context),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final historyShortcut =
        Settings.getValue<String>('key-shortcut-open-history') ?? 'ctrl+h';
    final bookmarksShortcut =
        Settings.getValue<String>('key-shortcut-open-bookmarks') ??
            'ctrl+shift+b';
    final workspaceShortcut =
        Settings.getValue<String>('key-shortcut-switch-workspace') ?? 'ctrl+k';

    return SizedBox(
      width: _kAppBarControlsWidth,
      child: Stack(
        children: [
          const DragToMoveArea(
            child: SizedBox.expand(),
          ),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: tourTitleBarHistoryButtonTargetKey,
                  icon: const Icon(FluentIcons.history_24_regular, size: 18),
                  tooltip: 'navigation.title_bar.show_history'.tr(
                      namedArgs: {'shortcut': historyShortcut.toUpperCase()}),
                  onPressed: () => _showHistoryDialog(context),
                  style: _kIconButtonStyle,
                ),
                IconButton(
                  key: tourTitleBarBookmarkButtonTargetKey,
                  icon: const Icon(FluentIcons.bookmark_24_regular, size: 18),
                  tooltip: 'navigation.title_bar.show_bookmarks'.tr(
                      namedArgs: {'shortcut': bookmarksShortcut.toUpperCase()}),
                  onPressed: () => _showBookmarksDialog(context),
                  style: _kIconButtonStyle,
                ),
                IconButton(
                  icon: const Icon(FluentIcons.add_square_24_regular, size: 18),
                  tooltip: 'navigation.title_bar.switch_workspace'.tr(
                      namedArgs: {'shortcut': workspaceShortcut.toUpperCase()}),
                  onPressed: () => _showSaveWorkspaceDialog(context),
                  style: _kIconButtonStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, NavigationState navState) {
    if (navState.currentScreen == Screen.reading ||
        navState.currentScreen == Screen.search) {
      if (_useStackedTabs(context, navState)) {
        return Row(
          children: [
            const Expanded(child: DragToMoveArea(child: SizedBox.expand())),
            _buildReadingSettingsButton(context),
          ],
        );
      }
      return _buildReadingTabs(context);
    } else if (navState.currentScreen == Screen.library) {
      return _buildLibraryTitle(context);
    } else {
      return _buildStandardTitle(context, navState);
    }
  }

  Widget _buildLibraryTitle(BuildContext context) {
    return BlocBuilder<LibraryBloc, LibraryState>(
      buildWhen: (previous, current) =>
          previous.currentCategory != current.currentCategory,
      builder: (context, libraryState) {
        final category = libraryState.currentCategory;
        // בתקייה הראשית (הספרייה עצמה) מוצג רק "ספריה" ללא שם קטגוריה;
        // בתקיות פנימיות מתווסף שם הקטגוריה ככותרת משנה.
        final isRoot =
            category == null || identical(category, libraryState.library);
        return _buildPanelTitle(
          context,
          'navigation.library'.tr(),
          subtitle: isRoot ? null : category.title,
        );
      },
    );
  }

  Widget _buildStandardTitle(BuildContext context, NavigationState navState) {
    final title = switch (navState.currentScreen) {
      Screen.settings => 'navigation.settings'.tr(),
      Screen.more => 'navigation.tools'.tr(),
      Screen.find => 'navigation.find'.tr(),
      Screen.search => 'navigation.search'.tr(),
      _ => 'app.title'.tr(),
    };
    return _buildPanelTitle(context, title);
  }

  Widget _buildPanelTitle(BuildContext context, String title,
      {String? subtitle}) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final textStyle = TextStyle(
      color: color,
      fontSize: 16,
      fontWeight: FontWeight.bold,
    );
    return Row(
      children: [
        Expanded(
          child: DragToMoveArea(
            child: Center(
              child: Text(
                subtitle != null ? '$title: $subtitle' : title,
                style: textStyle,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadingTabs(BuildContext context) {
    return BlocBuilder<TabsBloc, TabsState>(
      builder: (context, state) {
        if (!state.hasOpenTabs) {
          return DragToMoveArea(
            child: Center(
              child: Text(
                'navigation.reading'.tr(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          );
        }

        _ensureReadingTabController(state);

        return Row(
          children: [
            Expanded(child: _buildScrollableTabsArea(state)),
            const SizedBox(width: 36),
            _buildReadingSettingsButton(context),
          ],
        );
      },
    );
  }

  Widget _buildScrollableTabsArea(TabsState state) {
    return DragTarget<OpenedTab>(
      onWillAcceptWithDetails: (details) => state.tabs.length > 1,
      onAcceptWithDetails: (details) {
        final renderBox = context.findRenderObject() as RenderBox;
        final localOffset = renderBox.globalToLocal(details.offset);
        final isLeftHalf = localOffset.dx < (renderBox.size.width / 2);
        final isRtl = Directionality.of(context) == TextDirection.rtl;

        final newIndex = isRtl
            ? (isLeftHalf ? state.tabs.length - 1 : 0)
            : (isLeftHalf ? 0 : state.tabs.length - 1);

        final draggedTab = details.data;
        final currentIndex = state.tabs.indexOf(draggedTab);
        if (currentIndex != -1 && currentIndex != newIndex) {
          context.read<TabsBloc>().add(MoveTab(draggedTab, newIndex));
        }
      },
      builder: (context, candidateData, rejectedData) {
        return DragToMoveArea(
          child: KeyedSubtree(
            key: tourReadingTabsTargetKey,
            child: ScrollableTabBarWithArrows(
              controller: _tabController!,
              tabAlignment: TabAlignment.start,
              hideArrowsWhenNotScrollable: true,
              onOverflowChanged: (overflow) {
                if (mounted && _tabsOverflow != overflow) {
                  setState(() => _tabsOverflow = overflow);
                }
              },
              tabs: state.tabs
                  .map((tab) => _buildTab(context, tab, state))
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReadingSettingsButton(BuildContext context) {
    return DragToMoveArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: IconButton(
          key: tourReadingSettingsButtonTargetKey,
          icon: Icon(
            widget.isReadingSettingsPanelOpen
                ? FluentIcons.settings_24_filled
                : FluentIcons.settings_24_regular,
            size: 18,
          ),
          tooltip: 'navigation.title_bar.reading_settings'.tr(),
          onPressed: widget.onReadingSettingsPressed ??
              () => showReadingSettingsDialog(context),
          style: _kIconButtonStyle,
        ),
      ),
    );
  }

  Widget _buildNarrowTabsRow(BuildContext context) {
    return BlocBuilder<TabsBloc, TabsState>(
      builder: (context, state) {
        if (!state.hasOpenTabs) return const SizedBox.shrink();
        _ensureReadingTabController(state);
        return Container(
          color: Theme.of(context).colorScheme.surface,
          height: 40,
          child: _buildScrollableTabsArea(state),
        );
      },
    );
  }

  // --- Helper Methods ---

  void _showHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const HistoryDialog(),
    );
  }

  void _showBookmarksDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const BookmarksDialog(),
    );
  }

  void _showSaveWorkspaceDialog(BuildContext context) {
    context.read<HistoryBloc>().add(FlushHistory());
    showDialog(
      context: context,
      builder: (context) => const WorkspaceSwitcherDialog(),
    );
  }

  Widget _buildFullscreenCaptionButton(
      BuildContext context, SettingsState settingsState) {
    return _CaptionActionButton(
      brightness: Theme.of(context).brightness,
      tooltip: settingsState.isFullscreen
          ? 'navigation.title_bar.exit_fullscreen'.tr()
          : 'navigation.title_bar.enter_fullscreen'.tr(),
      icon: settingsState.isFullscreen
          ? FluentIcons.full_screen_minimize_24_regular
          : FluentIcons.full_screen_maximize_24_regular,
      onPressed: () async {
        final newFullscreenState = !settingsState.isFullscreen;
        await FullscreenHelper.toggleFullscreen(context, newFullscreenState);
      },
    );
  }

  /// מציג אייקון הצמדה רק כשהכרטיסיה מוצמדת
  Widget _buildPinIconInline(BuildContext context, OpenedTab tab) {
    if (!tab.isPinned) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => context.read<TabsBloc>().add(TogglePinTab(tab)),
      child: Padding(
        padding: const EdgeInsets.only(right: 4.0),
        child: Tooltip(
          message: 'navigation.title_bar.unpin_tab'.tr(),
          child: const Icon(FluentIcons.pin_24_filled, size: 14),
        ),
      ),
    );
  }

  void closeTab(OpenedTab tab, BuildContext context) {
    context.read<HistoryBloc>().add(AddHistory(tab));
    context.read<TabsBloc>().add(RemoveTab(tab));
  }

  void closeAllTabs(TabsState state, BuildContext context) {
    context.read<TabsBloc>().add(CloseAllTabs());
  }

  void closeAllTabsButCurrent(TabsState state, BuildContext context) {
    if (state.currentTab != null) {
      context.read<TabsBloc>().add(CloseOtherTabs(state.currentTab!));
    }
  }

  Widget _buildTab(BuildContext context, OpenedTab tab, TabsState state) {
    final index = state.tabs.indexOf(tab);
    final isSelected = index == state.currentTabIndex;
    final closeTabShortcut =
        Settings.getValue<String>('key-shortcut-close-tab') ?? 'ctrl+w';
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    bool isTabActive(int tabIndex) => tabIndex == state.currentTabIndex;
    bool isTabHovered = false;

    Widget buildTabContent() {
      if (tab is CombinedTab) {
        return Tooltip(
          message: tab.title,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(FluentIcons.panel_left_text_24_regular, size: 16),
              ),
              Text(truncate(tab.title, 20)),
            ],
          ),
        );
      }

      if (tab is SearchingTab) {
        return ValueListenableBuilder<String>(
          valueListenable: tab.titleNotifier,
          builder: (context, title, child) => Tooltip(
            message: title,
            child: Text(truncate(title, 25)),
          ),
        );
      }

      if (tab is PdfBookTab) {
        return ValueListenableBuilder<String>(
          valueListenable: tab.currentTitle,
          builder: (context, currentTitleValue, child) {
            final tooltipMessage = currentTitleValue.isNotEmpty
                ? '${tab.title}, $currentTitleValue'
                : tab.title;
            return Tooltip(
              message: tooltipMessage,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(FluentIcons.document_pdf_24_regular, size: 16),
                  ),
                  Text(truncate(tab.title, 12)),
                ],
              ),
            );
          },
        );
      }

      if (tab is PdfCommentatorsTab) {
        return ValueListenableBuilder<String>(
          valueListenable: tab.sourceTab.currentTitle,
          builder: (context, currentTitleValue, child) {
            final tooltipMessage = currentTitleValue.isNotEmpty
                ? '${tab.title}, $currentTitleValue'
                : tab.title;
            return Tooltip(
              message: tooltipMessage,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(FluentIcons.document_pdf_24_regular, size: 16),
                  ),
                  Text(truncate(tab.title, 12)),
                ],
              ),
            );
          },
        );
      }

      if (tab is CommentatorsTab) {
        return Tooltip(
          message: tab.title,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(FluentIcons.book_24_regular, size: 16),
              ),
              Text(truncate(tab.title, 20)),
            ],
          ),
        );
      }

      final textTab = tab as TextBookTab;
      return ValueListenableBuilder<String>(
        valueListenable: textTab.currentTitle,
        builder: (context, currentTitleValue, child) {
          final tooltipMessage = currentTitleValue.isNotEmpty
              ? '${tab.title}, $currentTitleValue'
              : tab.title;
          return Tooltip(
            message: tooltipMessage,
            child: Text(truncate(tab.title, 12)),
          );
        },
      );
    }

    Widget buildTabAppearance(StateSetter? setState) {
      final showLeadingDivider =
          index > 0 && !isTabActive(index) && !isTabActive(index - 1);
      final colorScheme = Theme.of(context).colorScheme;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLeadingDivider)
            Container(
              width: 1,
              height: 24,
              margin: const EdgeInsets.only(top: 6, bottom: 6),
              color: colorScheme.outlineVariant,
            ),
          Container(
            constraints: const BoxConstraints(maxHeight: 32),
            padding: EdgeInsets.only(
              left: 6,
              right: index == 0 ? 0 : 6,
            ),
            child: CustomPaint(
              painter: isSelected
                  ? _TabBackgroundPainter(colorScheme.surfaceContainer)
                  : null,
              foregroundPainter: isTabHovered && !isSelected
                  ? _TabBackgroundPainter(
                      colorScheme.onSurface.withValues(alpha: 0.08))
                  : null,
              child: Tab(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: DefaultTextStyle(
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (isSelected) const SizedBox(width: 4),
                        _buildPinIconInline(context, tab),
                        buildTabContent(),
                        Tooltip(
                          preferBelow: false,
                          message: closeTabShortcut.toUpperCase(),
                          child: IconButton(
                            constraints: const BoxConstraints(
                              minWidth: 25,
                              minHeight: 25,
                              maxWidth: 25,
                              maxHeight: 25,
                            ),
                            onPressed: () => closeTab(tab, context),
                            icon: const Icon(
                              FluentIcons.dismiss_24_regular,
                              size: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Listener(
      onPointerDown: (PointerDownEvent event) {
        if (event.buttons == 4) {
          closeTab(tab, context);
        }
      },
      child: AppContextMenuRegion(
        key: isSelected ? tourTabContextMenuTargetKey : null,
        menuBuilder: (menuCtx, _) =>
            _buildTabContextMenuEntries(menuCtx, tab, state),
        menuItemKeysByLabel: isSelected
            ? {
                'navigation.title_bar.show_side_by_side'.tr():
                    tourTabSideBySideMenuItemTargetKey
              }
            : null,
        child: Draggable<OpenedTab>(
          axis: Axis.horizontal,
          data: tab,
          childWhenDragging: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 1.0, end: 0.0),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Align(
                alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
                widthFactor: value,
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: buildTabAppearance(null),
          ),
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.85,
              child: buildTabAppearance(null),
            ),
          ),
          child: DragTarget<OpenedTab>(
            onAcceptWithDetails: (draggedTab) {
              if (draggedTab.data == tab) return;
              final newIndex = state.tabs.indexOf(tab);
              context.read<TabsBloc>().add(MoveTab(draggedTab.data, newIndex));
            },
            builder: (context, candidateData, rejectedData) {
              final isHovered =
                  candidateData.isNotEmpty && candidateData.first != tab;

              return StatefulBuilder(
                builder: (context, setState) {
                  return MouseRegion(
                    onEnter: (_) => setState(() => isTabHovered = true),
                    onExit: (_) => setState(() => isTabHovered = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      margin: EdgeInsets.only(
                        right: isHovered && isRtl ? 120.0 : 0.0,
                        left: isHovered && !isRtl ? 120.0 : 0.0,
                      ),
                      child: buildTabAppearance(setState),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  /// בונה פריט תפריט להעברת טאב לשולחן עבודה אחר
  AppContextMenuEntry _buildMoveToWorkspaceMenuEntry(
      BuildContext context, OpenedTab tab) {
    final workspaceState = context.read<WorkspaceBloc>().state;

    final otherWorkspaces = workspaceState.workspaces
        .where((w) => w.id != workspaceState.activeWorkspaceId)
        .toList();

    if (otherWorkspaces.isEmpty) {
      return AppContextMenuEntry(
        label: 'navigation.title_bar.move_to_workspace'.tr(),
        enabled: false,
      );
    }

    return AppContextMenuEntry(
      label: 'navigation.title_bar.move_to_workspace'.tr(),
      children: otherWorkspaces.map((workspace) {
        return AppContextMenuEntry(
          label: workspace.name,
          onTap: () {
            _moveTabToWorkspace(context, tab, workspace.id);
          },
        );
      }).toList(),
    );
  }

  /// מעביר טאב לשולחן עבודה אחר
  void _moveTabToWorkspace(
      BuildContext context, OpenedTab tab, String targetWorkspaceId) {
    final tabsBloc = context.read<TabsBloc>();
    final workspaceBloc = context.read<WorkspaceBloc>();
    final tabsState = tabsBloc.state;
    final workspaceState = workspaceBloc.state;

    final targetWorkspace =
        workspaceState.workspaces.firstWhere((w) => w.id == targetWorkspaceId);

    tabsBloc.add(RemoveTab(tab));

    final currentTabs = tabsState.tabs.where((t) => t != tab).toList();
    final newActiveIndex = currentTabs.isEmpty
        ? 0
        : tabsState.currentTabIndex.clamp(0, currentTabs.length - 1);

    workspaceBloc.add(MoveTabToWorkspace(
      tab: tab,
      targetWorkspaceId: targetWorkspaceId,
      currentTabs: currentTabs,
      currentTabIndex: newActiveIndex,
    ));

    // מציג הודעה למשתמש
    UiSnack.show('navigation.title_bar.tab_moved_to_workspace'
        .tr(namedArgs: {'name': targetWorkspace.name}));
  }

  List<AppContextMenuEntry> _buildTabContextMenuEntries(
    BuildContext menuCtx,
    OpenedTab tab,
    TabsState state,
  ) {
    final entries = <AppContextMenuEntry>[
      AppContextMenuEntry(
        label: tab.isPinned
            ? 'navigation.title_bar.unpin_tab_menu'.tr()
            : 'navigation.title_bar.pin_tab_menu'.tr(),
        onTap: () => context.read<TabsBloc>().add(TogglePinTab(tab)),
      ),
      AppContextMenuEntry(
        label: 'navigation.title_bar.close_menu'.tr(),
        onTap: () => closeTab(tab, context),
      ),
      AppContextMenuEntry(
        label: 'navigation.title_bar.close_all_menu'.tr(),
        onTap: () => closeAllTabs(state, context),
      ),
      AppContextMenuEntry(
        label: 'navigation.title_bar.close_others_menu'.tr(),
        onTap: () => closeAllTabsButCurrent(state, context),
      ),
      AppContextMenuEntry(
        label: 'navigation.title_bar.duplicate_menu'.tr(),
        onTap: () => context.read<TabsBloc>().add(CloneTab(tab)),
      ),
      const AppContextMenuEntry.divider(),
    ];

    if (tab is! CombinedTab) {
      if (state.tabs.length > 1) {
        final otherTabsList =
            state.tabs.where((t) => t != tab && t is! CombinedTab).toList();
        final otherTabs = otherTabsList.asMap().entries.map((mapEntry) {
          final isFirst = mapEntry.key == 0;
          final otherTab = mapEntry.value;
          return AppContextMenuEntry(
            key: isFirst ? tourTabSideBySideFirstItemTargetKey : null,
            label: otherTab.title,
            onTap: () {
              context.read<TabsBloc>().add(
                    EnableSideBySideMode(
                      rightTab: tab,
                      leftTab: otherTab,
                    ),
                  );
            },
          );
        }).toList();
        entries.add(AppContextMenuEntry(
          label: 'navigation.title_bar.show_side_by_side_menu'.tr(),
          children: otherTabs,
        ));
      } else {
        entries.add(AppContextMenuEntry(
          label: 'navigation.title_bar.show_side_by_side_menu'.tr(),
          enabled: false,
        ));
      }
    }

    if (tab is CombinedTab) {
      entries.addAll([
        AppContextMenuEntry(
          label: 'navigation.title_bar.swap_sides'.tr(),
          onTap: () => context.read<TabsBloc>().add(const SwapSideBySideTabs()),
        ),
        AppContextMenuEntry(
          label: 'navigation.title_bar.back_to_normal'.tr(),
          onTap: () => context
              .read<TabsBloc>()
              .add(DisableSideBySideMode(state.tabs.indexOf(tab))),
        ),
      ]);
    }

    entries.addAll([
      const AppContextMenuEntry.divider(),
      AppContextMenuEntry(
        label: 'navigation.title_bar.open_tabs'.tr(),
        // childrenBuilder + stream: הרשימה נבנית מחדש בכל שינוי במצב הכרטיסיות,
        // כך שסגירת כרטיסייה דרך ה-X מסירה את שורתה והתפריט נשאר פתוח.
        childrenBuilder: () =>
            _getOpenTabsMenuEntries(context.read<TabsBloc>().state.tabs),
        childrenRefreshStream: context.read<TabsBloc>().stream,
      ),
      _buildMoveToWorkspaceMenuEntry(context, tab),
    ]);

    return entries;
  }

  List<AppContextMenuEntry> _getOpenTabsMenuEntries(List<OpenedTab> tabs) {
    // ללא מיון — הרשימה משקפת את סדר הכרטיסיות בשורת הכרטיסיות.
    return tabs.map((tab) {
      return AppContextMenuEntry(
        label: tab.title,
        onTap: () {
          final index = tabs.indexOf(tab);
          context.read<TabsBloc>().add(SetCurrentTab(index));
        },
        trailing: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: IconButton(
            tooltip: 'navigation.title_bar.close_menu'.tr(),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: const Icon(FluentIcons.dismiss_24_regular, size: 14),
            // סגירת הכרטיסייה מעדכנת את ה-TabsBloc; ה-childrenRefreshStream
            // יבנה מחדש את הרשימה ושורת הכרטיסייה תיעלם.
            onPressed: () => closeTab(tab, context),
            splashRadius: 16,
          ),
        ),
      );
    }).toList();
  }
}

class _TabBackgroundPainter extends CustomPainter {
  final Color color;

  _TabBackgroundPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    const topRadius = 8.0;
    const bottomRadius = 15.0;
    const bottomOffset = 5.0;

    path.moveTo(-bottomRadius, size.height + bottomOffset);

    path.arcToPoint(
      Offset(0, size.height + bottomOffset - bottomRadius),
      radius: const Radius.circular(bottomRadius),
      clockwise: false,
    );

    path.lineTo(0, topRadius);

    path.arcToPoint(
      const Offset(topRadius, 0),
      radius: const Radius.circular(topRadius),
    );

    path.lineTo(size.width - topRadius, 0);

    path.arcToPoint(
      Offset(size.width, topRadius),
      radius: const Radius.circular(topRadius),
    );

    path.lineTo(size.width, size.height + bottomOffset - bottomRadius);

    path.arcToPoint(
      Offset(size.width + bottomRadius, size.height + bottomOffset),
      radius: const Radius.circular(bottomRadius),
      clockwise: false,
    );

    path.lineTo(-bottomRadius, size.height + bottomOffset);

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TabBackgroundPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _CaptionActionButton extends StatefulWidget {
  const _CaptionActionButton({
    required this.onPressed,
    required this.icon,
    required this.brightness,
    this.tooltip,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final Brightness brightness;
  final String? tooltip;

  @override
  State<_CaptionActionButton> createState() => _CaptionActionButtonState();
}

class _CaptionActionButtonState extends State<_CaptionActionButton> {
  bool _isHovering = false;
  bool _isPressed = false;

  void _onHover(bool hovered) {
    if (_isHovering != hovered) {
      setState(() => _isHovering = hovered);
    }
  }

  void _onPressedState(bool pressed) {
    if (_isPressed != pressed) {
      setState(() => _isPressed = pressed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.brightness == Brightness.dark;

    Color bgColor = Colors.transparent;
    Color iconColor =
        isDark ? Colors.white : Colors.black.withValues(alpha: 0.8956);

    if (_isHovering) {
      bgColor = isDark
          ? Colors.white.withValues(alpha: 0.0605)
          : Colors.black.withValues(alpha: 0.0373);
    }
    if (_isPressed) {
      bgColor = isDark
          ? Colors.white.withValues(alpha: 0.0419)
          : Colors.black.withValues(alpha: 0.0241);
      iconColor = isDark
          ? Colors.white.withValues(alpha: 0.786)
          : Colors.black.withValues(alpha: 0.6063);
    }

    final button = MouseRegion(
      onExit: (_) => _onHover(false),
      onHover: (_) => _onHover(true),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _onPressedState(true),
        onTapCancel: () => _onPressedState(false),
        onTapUp: (_) => _onPressedState(false),
        onTap: widget.onPressed,
        child: Container(
          constraints: const BoxConstraints(
            minWidth: _kWindowCaptionButtonWidth,
            minHeight: 32,
          ),
          decoration: BoxDecoration(color: bgColor),
          child: Center(
            child: Icon(
              widget.icon,
              size: 16,
              color: iconColor,
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip == null) {
      return button;
    }

    return Tooltip(message: widget.tooltip!, child: button);
  }
}
