import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:updat/updat.dart';
import 'package:otzaria/settings/settings_exports.dart';
import 'package:url_launcher/url_launcher.dart';

/// עוטף את צ'יפ העדכון ברקע קל עם גבול עדין, כדי שיהיה ניכר מעל טקסט
/// התוכן שמאחוריו (הצ'יפ צף מעל מסך התוכן).
Widget _updateChipSurface(BuildContext context, Widget child) {
  final colorScheme = Theme.of(context).colorScheme;
  return Material(
    color: colorScheme.surfaceContainerHighest,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: colorScheme.outlineVariant),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

/// רכיב לחיצה (chip) בעברית - דומה ל-flatChip המקורי
Widget hebrewFlatChip({
  required BuildContext context,
  required String? latestVersion,
  required String appVersion,
  required UpdatStatus status,
  required void Function() checkForUpdate,
  required void Function() openDialog,
  required void Function() startUpdate,
  required Future<void> Function() launchInstaller,
  required void Function() dismissUpdate,
}) {
  if (UpdatStatus.available == status ||
      UpdatStatus.availableWithChangelog == status) {
    // בדוק אם הדיאלוג כבר הוצג לגרסה זו
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final shownKey = 'update_dialog_shown_$latestVersion';
      final alreadyShown = Settings.getValue<bool>(shownKey) ?? false;

      if (!alreadyShown && context.mounted) {
        // סמן שהדיאלוג הוצג לגרסה זו
        await Settings.setValue<bool>(shownKey, true);
        openDialog();
      }
    });
    return Tooltip(
      message: 'update.update_to_version'
          .tr(namedArgs: {'version': latestVersion!.toString()}),
      child: _updateChipSurface(
        context,
        TextButton.icon(
          onPressed: openDialog,
          icon: const Icon(FluentIcons.arrow_download_24_regular),
          label: Text('update.update_available_short'.tr()),
        ),
      ),
    );
  }

  if (UpdatStatus.downloading == status) {
    return Tooltip(
      message: 'update.please_wait'.tr(),
      child: _updateChipSurface(
        context,
        TextButton.icon(
          onPressed: () {},
          icon: const SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
          label: Text('update.downloading'.tr()),
        ),
      ),
    );
  }

  if (UpdatStatus.readyToInstall == status) {
    // ב-Windows העדכון מותקן ברקע (מתקין שקט) והתוכנה נפתחת מחדש לבד —
    return Tooltip(
      message: Platform.isWindows ? 'לחץ לעדכון' : 'לחץ להתקנה',
      child: _updateChipSurface(
        context,
        TextButton.icon(
          onPressed: launchInstaller,
          icon: const Icon(FluentIcons.checkmark_circle_24_regular),
          label: Text('update.ready_to_install'.tr()),
        ),
      ),
    );
  }

  if (UpdatStatus.error == status) {
    // לא להציג הודעת שגיאה במצב אופליין
    final isOfflineMode =
        Settings.getValue<bool>(SettingsRepository.keyOfflineMode) ?? false;
    if (isOfflineMode) {
      return Container();
    }
    return Tooltip(
      message: 'update.update_error_message'.tr(),
      child: _updateChipSurface(
        context,
        TextButton.icon(
          onPressed: checkForUpdate,
          icon: const Icon(FluentIcons.warning_24_regular),
          label: Text('update.network_error_check'.tr()),
        ),
      ),
    );
  }

  return Container();
}

/// רכיב לחיצה מורחב בעברית עם הורדה שקטה - דומה ל-floatingExtendedChipWithSilentDownload
Widget hebrewFloatingExtendedChipWithSilentDownload({
  required BuildContext context,
  required String? latestVersion,
  required String appVersion,
  required UpdatStatus status,
  required void Function() checkForUpdate,
  required void Function() openDialog,
  required void Function() startUpdate,
  required Future<void> Function() launchInstaller,
  required void Function() dismissUpdate,
}) {
  if (UpdatStatus.available == status ||
      UpdatStatus.availableWithChangelog == status) {
    startUpdate();
  }

  if (UpdatStatus.downloading == status) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'update.downloading_update'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'update.downloading_version'
                  .tr(namedArgs: {'version': latestVersion.toString()}),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text('update.please_wait'.tr()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  if (UpdatStatus.readyToInstall == status) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'update.update_ready_title'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'update.version_ready_to_install'
                  .tr(namedArgs: {'version': latestVersion.toString()}),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'update.current_version_label'
                  .tr(namedArgs: {'version': appVersion}),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'update.update_now_for_features'.tr(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: dismissUpdate,
                  child: Text('update.later'.tr()),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: startUpdate,
                  icon: const Icon(FluentIcons.desktop_arrow_down_24_regular),
                  label: Text('update.install_now'.tr()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  return Container();
}

/// דיאלוג ברירת מחדל בעברית - דומה ל-defaultDialog
void hebrewDefaultDialog({
  required BuildContext context,
  required String? latestVersion,
  required String appVersion,
  required UpdatStatus status,
  required String? changelog,
  required void Function() checkForUpdate,
  required void Function() openDialog,
  required void Function() startUpdate,
  required Future<void> Function() launchInstaller,
  required void Function() dismissUpdate,
}) {
  final changelogText = changelog?.trim() ?? '';

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: Flex(
        direction:
            Theme.of(context).useMaterial3 ? Axis.vertical : Axis.horizontal,
        children: [
          const Icon(FluentIcons.arrow_sync_24_regular),
          Text('update.update_available_long'.tr()),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('update.new_version_available'.tr()),
          const SizedBox(width: 10),
          Text('update.new_version_label'
              .tr(namedArgs: {'version': latestVersion!.toString()})),
          const SizedBox(height: 10),
          if (status == UpdatStatus.availableWithChangelog) ...[
            Text(
              'update.changelog_label'.tr(),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: changelogText.isEmpty
                  ? Text('update.no_changelog_for_update'.tr())
                  : MarkdownBody(
                      data: changelogText,
                      onTapLink: (text, href, title) {
                        if (href != null) launchUrl(Uri.parse(href));
                      },
                    ),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          child: Text('update.later'.tr()),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            startUpdate();
          },
          child: Text('update.update_now'.tr()),
        ),
      ],
    ),
  );
}

/// פונקציה שעוטפת את _flatChipAutoHideError אבל עם הרכיב העברי
Widget hebrewFlatChipAutoHideError({
  required BuildContext context,
  required String? latestVersion,
  required String appVersion,
  required UpdatStatus status,
  required void Function() checkForUpdate,
  required void Function() openDialog,
  required void Function() startUpdate,
  required Future<void> Function() launchInstaller,
  required void Function() dismissUpdate,
}) {
  if (status == UpdatStatus.error) {
    Future.delayed(const Duration(seconds: 3), dismissUpdate);
  }
  return hebrewFlatChip(
    context: context,
    latestVersion: latestVersion,
    appVersion: appVersion,
    status: status,
    checkForUpdate: checkForUpdate,
    openDialog: openDialog,
    startUpdate: startUpdate,
    launchInstaller: launchInstaller,
    dismissUpdate: dismissUpdate,
  );
}
