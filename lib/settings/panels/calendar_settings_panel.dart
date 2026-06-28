import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/search/settings_anchor.dart';
import 'package:otzaria/settings/search/settings_search_models.dart';
import 'package:otzaria/settings/view/settings_screen.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/widgets/text/otzaria_search_field.dart';
import 'package:otzaria/tools/calendar/utils/calendar_cubit.dart';
import 'package:otzaria/settings/widgets/settings_widgets_exports.dart';
import 'package:otzaria/widgets/widgets_exports.dart';
import 'package:otzaria/theme/theme_exports.dart';
import 'package:otzaria/widgets/misc/app_menu_exports.dart';

/// טאב הגדרות לוח שנה
class CalendarSettingsTab extends StatefulWidget {
  const CalendarSettingsTab({super.key});

  /// פריטי חיפוש בהגדרות. נסרק על-ידי tool/generate_search_index.dart.
  static const List<SettingsSearchEntry> searchEntries = [
    SettingsSearchEntry(
      id: 'tools.calendar.location',
      title: 'settings.search.tools_calendar_location_title',
      subtitle: 'settings.search.tools_calendar_location_sub',
      tab: SettingsTab.tools,
      cardId: 'tools.calendar',
      keywords: ['settings.search.tools_calendar_location_kw'],
    ),
    SettingsSearchEntry(
      id: 'tools.calendar.type',
      title: 'settings.search.tools_calendar_type_title',
      subtitle: 'settings.search.tools_calendar_type_sub',
      tab: SettingsTab.tools,
      cardId: 'tools.calendar',
      keywords: ['settings.search.tools_calendar_type_kw'],
    ),
    SettingsSearchEntry(
      id: 'tools.calendar.times',
      title: 'settings.search.tools_calendar_times_title',
      subtitle: 'settings.search.tools_calendar_times_sub',
      tab: SettingsTab.tools,
      cardId: 'tools.calendar',
      keywords: ['settings.search.tools_calendar_times_kw'],
    ),
    SettingsSearchEntry(
      id: 'tools.calendar.day_change',
      title: 'settings.search.tools_calendar_day_change_title',
      subtitle: 'settings.search.tools_calendar_day_change_sub',
      tab: SettingsTab.tools,
      cardId: 'tools.calendar',
      keywords: ['settings.search.tools_calendar_day_change_kw'],
    ),
    SettingsSearchEntry(
      id: 'tools.calendar.candle_minutes',
      title: 'settings.search.tools_calendar_candle_minutes_title',
      subtitle: 'settings.search.tools_calendar_candle_minutes_sub',
      tab: SettingsTab.tools,
      cardId: 'tools.calendar',
      keywords: ['settings.search.tools_calendar_candle_minutes_kw'],
    ),
    SettingsSearchEntry(
      id: 'tools.calendar.notifications',
      title: 'settings.search.tools_calendar_notifications_title',
      subtitle: 'settings.search.tools_calendar_notifications_sub',
      tab: SettingsTab.tools,
      cardId: 'tools.calendar',
      keywords: ['settings.search.tools_calendar_notifications_kw'],
    ),
    SettingsSearchEntry(
      id: 'tools.calendar.notification_sound',
      title: 'settings.search.tools_calendar_notification_sound_title',
      subtitle: 'settings.search.tools_calendar_notification_sound_sub',
      tab: SettingsTab.tools,
      cardId: 'tools.calendar',
      keywords: ['settings.search.tools_calendar_notification_sound_kw'],
    ),
    SettingsSearchEntry(
      id: 'tools.calendar.reminder_offset',
      title: 'settings.search.tools_calendar_reminder_offset_title',
      subtitle: 'settings.search.tools_calendar_reminder_offset_sub',
      tab: SettingsTab.tools,
      cardId: 'tools.calendar',
      keywords: ['settings.search.tools_calendar_reminder_offset_kw'],
    ),
    SettingsSearchEntry(
      id: 'tools.calendar.google_calendar',
      title: 'settings.search.tools_calendar_google_calendar_title',
      subtitle: 'settings.search.tools_calendar_google_calendar_sub',
      tab: SettingsTab.tools,
      cardId: 'tools.calendar',
      keywords: ['settings.search.tools_calendar_google_calendar_kw'],
    ),
  ];

  @override
  State<CalendarSettingsTab> createState() => _CalendarSettingsTabState();
}

class _CalendarSettingsTabState extends State<CalendarSettingsTab> {
  final List<String> _cityNames =
      cityCoordinates.values.expand((cities) => cities.keys).toList()..sort();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CalendarCubit, CalendarState>(
      builder: (context, state) {
        final isOfflineMode = context.watch<SettingsBloc>().state.isOfflineMode;
        // [הוסר] SingleChildScrollView — ToolsSettingsTab גולל את כולם
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── לוח שנה: סוג לוח + עיר באותו מקטע ──
            SettingsAnchor(
              cardId: 'tools.calendar',
              child: SettingsCard(
                title: 'settings.calendar.section'.tr(),
                children: [
                  // סוג לוח
                  SegmentedSettingsTile<CalendarType>(
                    icon: const Icon(FluentIcons.calendar_24_regular),
                    title: 'settings.calendar.type_title'.tr(),
                    subtitle: state.calendarType == CalendarType.hebrew
                        ? 'settings.calendar.type_hebrew_subtitle'.tr()
                        : state.calendarType == CalendarType.gregorian
                            ? 'settings.calendar.type_gregorian_subtitle'.tr()
                            : 'settings.calendar.type_combined_subtitle'.tr(),
                    options: [
                      SegmentOption(
                          value: CalendarType.hebrew,
                          label: 'settings.calendar.type_hebrew'.tr()),
                      SegmentOption(
                          value: CalendarType.combined,
                          label: 'settings.calendar.type_combined'.tr()),
                      SegmentOption(
                          value: CalendarType.gregorian,
                          label: 'settings.calendar.type_gregorian'.tr()),
                    ],
                    currentValue: state.calendarType,
                    onChanged: (value) {
                      context.read<CalendarCubit>().changeCalendarType(value);
                    },
                  ),
                  DropdownSettingsTile<CalendarDayTransition>(
                    icon: const Icon(FluentIcons.weather_sunny_low_24_regular),
                    title: 'settings.calendar.day_transition_title'.tr(),
                    subtitle:
                        _calendarDayTransitionSubtitle(state.dayTransition),
                    value: state.dayTransition,
                    entries: [
                      AppMenuEntry(
                        value: CalendarDayTransition.sunset,
                        label: 'settings.calendar.day_transition_sunset'.tr(),
                      ),
                      AppMenuEntry(
                        value: CalendarDayTransition.tzais,
                        label: 'settings.calendar.day_transition_tzais'.tr(),
                      ),
                      AppMenuEntry(
                        value: CalendarDayTransition.rabbeinuTam,
                        label: 'settings.calendar.day_transition_rabbeinu_tam'
                            .tr(),
                      ),
                      AppMenuEntry(
                        value: CalendarDayTransition.midnight,
                        label: 'settings.calendar.day_transition_midnight'.tr(),
                      ),
                    ],
                    onSelected: (value) {
                      if (value != null) {
                        context
                            .read<CalendarCubit>()
                            .changeCalendarDayTransition(value);
                      }
                    },
                  ),
                  // עיר
                  DropdownSettingsTile<String>(
                    icon: const Icon(FluentIcons.location_24_regular),
                    title: 'settings.calendar.city_title'.tr(),
                    subtitle: 'settings.calendar.city_subtitle'.tr(),
                    value: state.selectedCity,
                    minFieldWidth: 220,
                    maxFieldWidth: 320,
                    enableSearch: true,
                    entries: _cityNames
                        .map(
                          (city) =>
                              AppMenuEntry<String>(value: city, label: city),
                        )
                        .toList(),
                    onSelected: (city) {
                      if (city == null || city == state.selectedCity) return;
                      context.read<CalendarCubit>().changeCity(city);
                    },
                  ),
                ],
              ),
            ),

            kSettingsCardSpacing,

            // ── אירועים ותזכורות: התראות + Google Calendar ──
            SettingsCard(
              title: 'settings.calendar.events_section'.tr(),
              children: [
                // הפעל התראות
                SwitchSettingsTile.text(
                  icon: FluentIcons.alert_24_regular,
                  title: 'settings.calendar.notifications_enable'.tr(),
                  value: state.calendarNotificationsEnabled,
                  onChanged: (value) {
                    context
                        .read<CalendarCubit>()
                        .changeCalendarNotificationsEnabled(value);
                  },
                ),
                if (state.calendarNotificationsEnabled) ...[
                  SwitchSettingsTile.text(
                    icon: FluentIcons.speaker_2_24_regular,
                    title: 'settings.calendar.notifications_sound'.tr(),
                    value: state.calendarNotificationSound,
                    onChanged: (value) {
                      context
                          .read<CalendarCubit>()
                          .changeCalendarNotificationSound(value);
                    },
                  ),
                  DropdownSettingsTile<int>(
                    icon: const Icon(FluentIcons.alert_snooze_24_regular),
                    title: 'settings.calendar.notification_time_title'.tr(),
                    subtitle:
                        'settings.calendar.notification_time_subtitle'.tr(),
                    value: state.calendarNotificationTime,
                    minFieldWidth: 180,
                    maxFieldWidth: 240,
                    entries: [
                      AppMenuEntry(
                          value: 60,
                          label: 'settings.calendar.duration_hour'.tr()),
                      AppMenuEntry(
                          value: 720,
                          label: 'settings.calendar.duration_12_hours'.tr()),
                      AppMenuEntry(
                          value: 1440,
                          label: 'settings.calendar.duration_day'.tr()),
                      AppMenuEntry(
                          value: 2880,
                          label: 'settings.calendar.duration_two_days'.tr()),
                    ],
                    onSelected: (value) {
                      if (value != null) {
                        context
                            .read<CalendarCubit>()
                            .changeCalendarNotificationTime(value);
                      }
                    },
                  ),
                ],

                // ── לוח שנה גוגל ──
                SwitchSettingsTile.text(
                  icon: FluentIcons.arrow_sync_24_regular,
                  title: 'settings.calendar.google_title'.tr(),
                  subtitle: isOfflineMode
                      ? 'settings.calendar.google_offline_subtitle'.tr()
                      : 'settings.calendar.google_online_subtitle'.tr(),
                  value: state.googleCalendarEnabled,
                  enabled: !isOfflineMode,
                  onChanged: (value) {
                    context
                        .read<CalendarCubit>()
                        .setGoogleCalendarEnabled(value);
                  },
                ),

                if (state.googleCalendarEnabled && !isOfflineMode) ...[
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // כפתור "התחברות לחשבון" / מצב מחובר
                        if (!state.googleCalendarConnected) ...[
                          SizedBox(
                            width: double.infinity,
                            child: RecommendedActionButton(
                              text: 'settings.calendar.google_connect'.tr(),
                              icon: FluentIcons.person_accounts_24_regular,
                              isLoading: state.googleCalendarSyncInProgress,
                              onPressed: () async {
                                final cubit = context.read<CalendarCubit>();
                                final success =
                                    await cubit.connectGoogleCalendar();
                                if (!context.mounted) return;
                                if (success) {
                                  final calendars =
                                      await cubit.getAvailableCalendars();
                                  if (!context.mounted) return;
                                  final selected =
                                      await _showCalendarMultiSelectionDialog<
                                          String>(
                                    context: context,
                                    title:
                                        'settings.calendar.google_select_calendars_title'
                                            .tr(),
                                    items: calendars
                                        .map((cal) =>
                                            _CalendarMultiSelectionItem<String>(
                                              label: cal.name,
                                              value: cal.id,
                                              subtitle: cal.isPrimary
                                                  ? 'settings.calendar.google_primary_calendar'
                                                      .tr()
                                                  : null,
                                            ))
                                        .toList(),
                                    initialSelectedValues:
                                        state.googleCalendarSelectedIds,
                                    searchHint:
                                        'settings.calendar.google_search_hint'
                                            .tr(),
                                    emptyMessage:
                                        'settings.calendar.google_no_calendars'
                                            .tr(),
                                  );
                                  if (selected != null && selected.isNotEmpty) {
                                    cubit.updateGoogleCalendarSelectedIds(
                                        selected);
                                  }
                                }
                              },
                            ),
                          ),
                        ] else ...[
                          // מחובר — הצג אפשרויות
                          Row(
                            children: [
                              Expanded(
                                child: NeutralActionButton(
                                  text:
                                      'settings.calendar.google_calendars_label'
                                          .tr(namedArgs: {
                                    'count': state
                                        .googleCalendarSelectedIds.length
                                        .toString()
                                  }),
                                  icon: FluentIcons.calendar_24_regular,
                                  onPressed: () async {
                                    final cubit = context.read<CalendarCubit>();
                                    final calendars =
                                        await cubit.getAvailableCalendars();
                                    if (!context.mounted) return;
                                    if (calendars.isEmpty) {
                                      UiSnack.show(
                                          'settings.calendar.google_no_calendars_retry'
                                              .tr());
                                      return;
                                    }
                                    final selected =
                                        await _showCalendarMultiSelectionDialog<
                                            String>(
                                      context: context,
                                      title:
                                          'settings.calendar.google_select_calendars_title'
                                              .tr(),
                                      items: calendars
                                          .map((cal) =>
                                              _CalendarMultiSelectionItem<
                                                  String>(
                                                label: cal.name,
                                                value: cal.id,
                                                subtitle: cal.isPrimary
                                                    ? 'settings.calendar.google_primary_calendar'
                                                        .tr()
                                                    : null,
                                              ))
                                          .toList(),
                                      initialSelectedValues:
                                          state.googleCalendarSelectedIds,
                                      searchHint:
                                          'settings.calendar.google_search_hint'
                                              .tr(),
                                      emptyMessage:
                                          'settings.calendar.google_no_calendars'
                                              .tr(),
                                    );
                                    if (selected != null &&
                                        selected.isNotEmpty) {
                                      cubit.updateGoogleCalendarSelectedIds(
                                          selected);
                                      cubit.syncGoogleCalendar(
                                          interactive: false);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              RecommendedActionButton(
                                text: 'settings.calendar.google_sync'.tr(),
                                icon: FluentIcons.arrow_sync_24_regular,
                                isLoading: state.googleCalendarSyncInProgress,
                                onPressed: () => context
                                    .read<CalendarCubit>()
                                    .syncGoogleCalendar(interactive: true),
                              ),
                              const SizedBox(width: 8),
                              NeutralActionButton(
                                text:
                                    'settings.calendar.google_disconnect'.tr(),
                                onPressed: () => context
                                    .read<CalendarCubit>()
                                    .disconnectGoogleCalendar(),
                              ),
                            ],
                          ),
                        ],

                        // מידע נוסף
                        if (state.googleCalendarLastSync != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'settings.calendar.google_last_sync'
                                  .tr(namedArgs: {
                                'time': state.googleCalendarLastSync.toString()
                              }),
                              style: TextStyle(
                                fontSize: AppTokens.fontSM,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                        if (state.googleCalendarSyncError != null &&
                            state.googleCalendarSyncError!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              state.googleCalendarSyncError!,
                              style: TextStyle(
                                fontSize: AppTokens.fontSM,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

String _calendarDayTransitionSubtitle(CalendarDayTransition transition) {
  switch (transition) {
    case CalendarDayTransition.sunset:
      return 'settings.calendar.day_transition_sunset_subtitle'.tr();
    case CalendarDayTransition.tzais:
      return 'settings.calendar.day_transition_tzais_subtitle'.tr();
    case CalendarDayTransition.rabbeinuTam:
      return 'settings.calendar.day_transition_rabbeinu_tam_subtitle'.tr();
    case CalendarDayTransition.midnight:
      return 'settings.calendar.day_transition_midnight_subtitle'.tr();
  }
}

Future<List<T>?> _showCalendarMultiSelectionDialog<T>({
  required BuildContext context,
  required String title,
  required List<_CalendarMultiSelectionItem<T>> items,
  List<T> initialSelectedValues = const [],
  String? searchHint,
  String? emptyMessage,
  bool barrierDismissible = true,
}) {
  return showDialog<List<T>>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (context) => _CalendarMultiSelectionDialog<T>(
      title: title,
      items: items,
      initialSelectedValues: initialSelectedValues,
      searchHint: searchHint,
      emptyMessage: emptyMessage,
    ),
  );
}

class _CalendarMultiSelectionDialog<T> extends StatefulWidget {
  final String title;
  final List<_CalendarMultiSelectionItem<T>> items;
  final List<T> initialSelectedValues;
  final String? searchHint;
  final String? emptyMessage;

  const _CalendarMultiSelectionDialog({
    required this.title,
    required this.items,
    this.initialSelectedValues = const [],
    this.searchHint,
    this.emptyMessage,
  });

  @override
  State<_CalendarMultiSelectionDialog<T>> createState() =>
      _CalendarMultiSelectionDialogState<T>();
}

class _CalendarMultiSelectionDialogState<T>
    extends State<_CalendarMultiSelectionDialog<T>> {
  late List<_CalendarMultiSelectionItem<T>> filteredItems;
  late Set<T> selectedValues;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    filteredItems = widget.items;
    selectedValues = Set.from(widget.initialSelectedValues);
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredItems = widget.items;
      } else {
        filteredItems = widget.items.where((item) {
          return item.label.toLowerCase().contains(query) ||
              item.searchValue.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: cs.surfaceContainerHigh,
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            OtzariaSearchField(
              controller: _searchController,
              hintText: widget.searchHint ??
                  'settings.calendar.dialog_search_hint'.tr(),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: widget.items.isEmpty
                  ? Center(
                      child: Text(
                        widget.emptyMessage ??
                            'settings.calendar.dialog_no_items'.tr(),
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    )
                  : filteredItems.isEmpty
                      ? Center(
                          child: Text(
                            'settings.calendar.dialog_no_results'.tr(),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final isSelected =
                                selectedValues.contains(item.value);

                            return CheckboxListTile(
                              title: Text(
                                item.label,
                              ),
                              subtitle: item.subtitle != null
                                  ? Text(
                                      item.subtitle!,
                                    )
                                  : null,
                              value: isSelected,
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    selectedValues.add(item.value);
                                  } else {
                                    selectedValues.remove(item.value);
                                  }
                                });
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        NeutralActionButton(
          text: 'common.cancel'.tr(),
          onPressed: () => Navigator.of(context).pop(),
        ),
        RecommendedActionButton(
          text: 'common.ok'.tr(),
          onPressed: selectedValues.isEmpty
              ? () {}
              : () => Navigator.of(context).pop(selectedValues.toList()),
          isLoading: false,
        ),
      ],
    );
  }
}

class _CalendarMultiSelectionItem<T> {
  final String label;
  final String searchValue;
  final T value;
  final String? subtitle;

  const _CalendarMultiSelectionItem({
    required this.label,
    required this.value,
    String? searchValue,
    this.subtitle,
  }) : searchValue = searchValue ?? label;
}
