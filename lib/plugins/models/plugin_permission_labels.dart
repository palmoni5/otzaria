import 'package:easy_localization/easy_localization.dart';

/// מידע תצוגה עבור הרשאת תוסף — שם ותיאור קצר
class PluginPermissionInfo {
  /// שם קצר (מוצג כותרת)
  final String label;

  /// תיאור מה ההרשאה מאפשרת (מוצג כsubtitle)
  final String description;

  const PluginPermissionInfo({required this.label, required this.description});
}

/// מחזיר מידע תצוגה עבור הרשאה בשמה הטכני.
/// אם ההרשאה אינה מוכרת, מחזיר את שמה הטכני עם תיאור גנרי.
PluginPermissionInfo getPermissionInfo(String permissionKey) {
  return _permissionLabels[permissionKey] ??
      PluginPermissionInfo(
        label: permissionKey,
        description: 'plugins.permissions.generic_description'
            .tr(namedArgs: {'key': permissionKey}),
      );
}

/// מיפוי מלא של כל ההרשאות התקפות לשם ותיאור
Map<String, PluginPermissionInfo> get _permissionLabels => {
      // ===== מידע על האפליקציה =====
      'app.info.read': PluginPermissionInfo(
        label: 'plugins.permissions.app_info_read_label'.tr(),
        description: 'plugins.permissions.app_info_read_description'.tr(),
      ),
      'app.user_email.read': PluginPermissionInfo(
        label: 'plugins.permissions.app_user_email_read_label'.tr(),
        description: 'plugins.permissions.app_user_email_read_description'.tr(),
      ),
      'app.run_on_startup': PluginPermissionInfo(
        label: 'plugins.permissions.app_run_on_startup_label'.tr(),
        description: 'plugins.permissions.app_run_on_startup_description'.tr(),
      ),

      // ===== ספרייה =====
      'library.books.read': PluginPermissionInfo(
        label: 'plugins.permissions.library_books_read_label'.tr(),
        description: 'plugins.permissions.library_books_read_description'.tr(),
      ),
      'library.content.read': PluginPermissionInfo(
        label: 'plugins.permissions.library_content_read_label'.tr(),
        description:
            'plugins.permissions.library_content_read_description'.tr(),
      ),

      // ===== חיפוש =====
      'search.fulltext.read': PluginPermissionInfo(
        label: 'plugins.permissions.search_fulltext_read_label'.tr(),
        description:
            'plugins.permissions.search_fulltext_read_description'.tr(),
      ),

      // ===== קורא =====
      'reader.open': PluginPermissionInfo(
        label: 'plugins.permissions.reader_open_label'.tr(),
        description: 'plugins.permissions.reader_open_description'.tr(),
      ),

      // ===== ניווט =====
      'navigation.write': PluginPermissionInfo(
        label: 'plugins.permissions.navigation_write_label'.tr(),
        description: 'plugins.permissions.navigation_write_description'.tr(),
      ),

      // ===== הערות אישיות =====
      'notes.read': PluginPermissionInfo(
        label: 'plugins.permissions.notes_read_label'.tr(),
        description: 'plugins.permissions.notes_read_description'.tr(),
      ),
      'notes.write': PluginPermissionInfo(
        label: 'plugins.permissions.notes_write_label'.tr(),
        description: 'plugins.permissions.notes_write_description'.tr(),
      ),

      // ===== לוח שנה =====
      'calendar.read': PluginPermissionInfo(
        label: 'plugins.permissions.calendar_read_label'.tr(),
        description: 'plugins.permissions.calendar_read_description'.tr(),
      ),

      // ===== הגדרות =====
      'settings.read': PluginPermissionInfo(
        label: 'plugins.permissions.settings_read_label'.tr(),
        description: 'plugins.permissions.settings_read_description'.tr(),
      ),

      // ===== ממשק משתמש =====
      'ui.feedback': PluginPermissionInfo(
        label: 'plugins.permissions.ui_feedback_label'.tr(),
        description: 'plugins.permissions.ui_feedback_description'.tr(),
      ),
      'ui.create_shortcut': PluginPermissionInfo(
        label: 'plugins.permissions.ui_create_shortcut_label'.tr(),
        description: 'plugins.permissions.ui_create_shortcut_description'.tr(),
      ),

      // ===== אחסון תוסף =====
      'plugin.storage.read': PluginPermissionInfo(
        label: 'plugins.permissions.plugin_storage_read_label'.tr(),
        description:
            'plugins.permissions.plugin_storage_read_description'.tr(),
      ),
      'plugin.storage.write': PluginPermissionInfo(
        label: 'plugins.permissions.plugin_storage_write_label'.tr(),
        description:
            'plugins.permissions.plugin_storage_write_description'.tr(),
      ),

      // ===== פרסום נתונים =====
      'published_data.write': PluginPermissionInfo(
        label: 'plugins.permissions.published_data_write_label'.tr(),
        description:
            'plugins.permissions.published_data_write_description'.tr(),
      ),

      // ===== רשת =====
      'network.access': PluginPermissionInfo(
        label: 'plugins.permissions.network_access_label'.tr(),
        description: 'plugins.permissions.network_access_description'.tr(),
      ),
      'network.localhost': PluginPermissionInfo(
        label: 'plugins.permissions.network_localhost_label'.tr(),
        description: 'plugins.permissions.network_localhost_description'.tr(),
      ),

      // ===== משוב ומיילים =====
      'feedback.send_email': PluginPermissionInfo(
        label: 'plugins.permissions.feedback_send_email_label'.tr(),
        description:
            'plugins.permissions.feedback_send_email_description'.tr(),
      ),

      // ===== היסטוריית קריאה =====
      'history.read': PluginPermissionInfo(
        label: 'plugins.permissions.history_read_label'.tr(),
        description: 'plugins.permissions.history_read_description'.tr(),
      ),
      'history.write': PluginPermissionInfo(
        label: 'plugins.permissions.history_write_label'.tr(),
        description: 'plugins.permissions.history_write_description'.tr(),
      ),

      // ===== מסד נתונים =====
      'database.read': PluginPermissionInfo(
        label: 'plugins.permissions.database_read_label'.tr(),
        description: 'plugins.permissions.database_read_description'.tr(),
      ),

      // ===== התראות =====
      'notifications.send': PluginPermissionInfo(
        label: 'plugins.permissions.notifications_send_label'.tr(),
        description:
            'plugins.permissions.notifications_send_description'.tr(),
      ),
      'notifications.system': PluginPermissionInfo(
        label: 'plugins.permissions.notifications_system_label'.tr(),
        description:
            'plugins.permissions.notifications_system_description'.tr(),
      ),

      // ===== אירועים =====
      'events.subscribe:navigation.changed': PluginPermissionInfo(
        label: 'plugins.permissions.events_navigation_changed_label'.tr(),
        description:
            'plugins.permissions.events_navigation_changed_description'.tr(),
      ),
      'events.subscribe:reader.current_book_changed': PluginPermissionInfo(
        label: 'plugins.permissions.events_reader_current_book_changed_label'
            .tr(),
        description:
            'plugins.permissions.events_reader_current_book_changed_description'
                .tr(),
      ),
      'events.subscribe:reader.current_ref_changed': PluginPermissionInfo(
        label: 'plugins.permissions.events_reader_current_ref_changed_label'
            .tr(),
        description:
            'plugins.permissions.events_reader_current_ref_changed_description'
                .tr(),
      ),
      'events.subscribe:theme.changed': PluginPermissionInfo(
        label: 'plugins.permissions.events_theme_changed_label'.tr(),
        description:
            'plugins.permissions.events_theme_changed_description'.tr(),
      ),
      'events.subscribe:settings.changed': PluginPermissionInfo(
        label: 'plugins.permissions.events_settings_changed_label'.tr(),
        description:
            'plugins.permissions.events_settings_changed_description'.tr(),
      ),
      'events.subscribe:calendar.date_changed': PluginPermissionInfo(
        label: 'plugins.permissions.events_calendar_date_changed_label'.tr(),
        description:
            'plugins.permissions.events_calendar_date_changed_description'
                .tr(),
      ),
      'events.subscribe:workspace.changed': PluginPermissionInfo(
        label: 'plugins.permissions.events_workspace_changed_label'.tr(),
        description:
            'plugins.permissions.events_workspace_changed_description'.tr(),
      ),
      'events.subscribe:plugin.permissions_changed': PluginPermissionInfo(
        label: 'plugins.permissions.events_plugin_permissions_changed_label'
            .tr(),
        description:
            'plugins.permissions.events_plugin_permissions_changed_description'
                .tr(),
      ),
    };
