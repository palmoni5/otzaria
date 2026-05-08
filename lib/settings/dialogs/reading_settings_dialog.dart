import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/settings/engine/settings_engine_exports.dart';
import 'package:otzaria/settings/panels/reading_settings_panel.dart';

/// פונקציה גלובלית להצגת דיאלוג הגדרות תצוגת הספרים
/// ניתן לקרוא לה מכל מקום באפליקציה (למשל ממסך העיון)
void showReadingSettingsDialog(BuildContext context) {
  final dialogContext = navigatorKey.currentContext;
  if (dialogContext == null) {
    return;
  }

  showDialog(
    context: dialogContext,
    builder: (context) => BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
          title: Text(
            'settings.reading_dialog.title'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: SizedBox(
            width: 650,
            height: MediaQuery.of(context).size.height * 0.7,
            child: const ReadingSettingsBody(),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('common.close'.tr()),
            ),
          ],
        );
      },
    ),
  );
}
