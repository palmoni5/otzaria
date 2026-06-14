import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:otzaria/tools/calendar/utils/calendar_cubit.dart';
import 'package:otzaria/widgets/controls/action_buttons.dart';
import 'package:otzaria/widgets/misc/keyboard_dialog_navigation.dart';

/// דיאלוג לקביעת טווח ההדפסה של לוח השנה.
class CalendarPrintDialog extends StatefulWidget {
  final CalendarView calendarView;
  final ShortcutActivator? closeShortcut;

  const CalendarPrintDialog({
    super.key,
    required this.calendarView,
    this.closeShortcut,
  });

  @override
  State<CalendarPrintDialog> createState() => _CalendarPrintDialogState();
}

class _CalendarPrintDialogState extends State<CalendarPrintDialog>
    with DialogNavigationMixin {
  int _count = 1;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (String periodName, String periodNamePlural, int maxCount) =
        switch (widget.calendarView) {
      CalendarView.month => (
          'calendar.print_period_month'.tr(),
          'calendar.print_period_month_plural'.tr(),
          12
        ),
      CalendarView.week => (
          'calendar.print_period_week'.tr(),
          'calendar.print_period_week_plural'.tr(),
          52
        ),
      CalendarView.day => (
          'calendar.print_period_day'.tr(),
          'calendar.print_period_day_plural'.tr(),
          30
        ),
    };

    final dialog = AlertDialog(
      backgroundColor: cs.surfaceContainerHigh,
      title: Text('calendar.print_settings'.tr()),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('calendar.print_count_question'
                .tr(namedArgs: {'periodPlural': periodNamePlural})),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    autofocus: true,
                    value: _count.toDouble(),
                    min: 1,
                    max: maxCount.toDouble(),
                    divisions: maxCount - 1,
                    label: _count.toString(),
                    onChanged: (v) => setState(() => _count = v.round()),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 100,
                  child: Text(
                    _count == 1
                        ? '$_count $periodName'
                        : '$_count $periodNamePlural',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'calendar.print_range'.tr(namedArgs: {
                'range': _count == 1 ? periodName : '$_count $periodNamePlural'
              }),
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        NeutralActionButton(
          text: 'calendar.cancel'.tr(),
          onPressed: () => Navigator.of(context).pop(),
        ),
        RecommendedActionButton(
          text: 'calendar.print_action'.tr(),
          onPressed: () => Navigator.of(context).pop(_count),
        ),
      ],
    );

    Widget result = dialog;
    if (widget.closeShortcut != null) {
      result = CallbackShortcuts(
        bindings: {
          widget.closeShortcut!: () => Navigator.of(context).pop(),
        },
        child: result,
      );
    }

    return buildKeyboardNavigator(
      onConfirm: () => Navigator.of(context).pop(_count),
      onCancel: () => Navigator.of(context).pop(),
      child: result,
    );
  }
}

/// מציג את דיאלוג ההדפסה ומחזיר את כמות היחידות להדפסה.
Future<int?> showCalendarPrintDialog({
  required BuildContext context,
  required CalendarView calendarView,
  ShortcutActivator? closeShortcut,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => CalendarPrintDialog(
      calendarView: calendarView,
      closeShortcut: closeShortcut,
    ),
  );
}
