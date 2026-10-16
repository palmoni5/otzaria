import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:otzaria/widgets/navigation/responsive_action_bar.dart';

/// בונה את רצף כפתורי הניווט המשותף למסכי הקריאה.
List<ActionButtonData> buildBookViewNavigationActions({
  required ActionButtonData firstAction,
  required ActionButtonData previousAction,
  ActionButtonData? middleAction,
  required ActionButtonData nextAction,
  required ActionButtonData lastAction,
}) {
  return [
    firstAction,
    previousAction,
    ?middleAction,
    nextAction,
    lastAction,
  ];
}

/// כפתור "לתחילת הספר".
ActionButtonData buildBookViewFirstNavigationAction({
  required Widget widget,
  required String tooltip,
  required VoidCallback onPressed,
}) {
  return ActionButtonData(
    widget: widget,
    icon: FluentIcons.arrow_previous_24_filled,
    tooltip: tooltip,
    onPressed: onPressed,
  );
}

/// כפתור "הדף/פרק הקודם".
ActionButtonData buildBookViewPreviousTocNavigationAction({
  required Widget widget,
  required String tooltip,
  required VoidCallback onPressed,
}) {
  return ActionButtonData(
    widget: widget,
    icon: FluentIcons.chevron_double_left_20_regular,
    tooltip: tooltip,
    onPressed: onPressed,
  );
}

/// כפתור "הקודם".
ActionButtonData buildBookViewPreviousNavigationAction({
  required Widget widget,
  required String tooltip,
  required VoidCallback onPressed,
}) {
  return ActionButtonData(
    widget: widget,
    icon: FluentIcons.chevron_left_24_regular,
    tooltip: tooltip,
    onPressed: onPressed,
  );
}

/// כפתור "הבא".
ActionButtonData buildBookViewNextNavigationAction({
  required Widget widget,
  required String tooltip,
  required VoidCallback onPressed,
}) {
  return ActionButtonData(
    widget: widget,
    icon: FluentIcons.chevron_right_24_regular,
    tooltip: tooltip,
    onPressed: onPressed,
  );
}

/// כפתור "הדף/פרק הבא".
ActionButtonData buildBookViewNextTocNavigationAction({
  required Widget widget,
  required String tooltip,
  required VoidCallback onPressed,
}) {
  return ActionButtonData(
    widget: widget,
    icon: FluentIcons.chevron_double_right_20_regular,
    tooltip: tooltip,
    onPressed: onPressed,
  );
}

/// כפתור "לסוף הספר".
ActionButtonData buildBookViewLastNavigationAction({
  required Widget widget,
  required String tooltip,
  required VoidCallback onPressed,
}) {
  return ActionButtonData(
    widget: widget,
    icon: FluentIcons.arrow_next_24_filled,
    tooltip: tooltip,
    onPressed: onPressed,
  );
}
