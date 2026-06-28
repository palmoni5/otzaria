import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/data/repository/data_repository.dart';
import 'package:otzaria/external_catalog/repository/external_catalog_repository.dart';
import 'package:otzaria/settings/settings_exports.dart';
import 'package:otzaria/widgets/dialogs/dialogs_exports.dart';

class ExternalCatalogSettingsHelper {
  static bool _isAutoSyncInProgress = false;

  static Future<void> updateExternalBooks(
    BuildContext context,
    bool enabled,
  ) async {
    final settingsBloc = context.read<SettingsBloc>();
    if (enabled && !await _ensureCatalogDatabaseAvailable(context)) {
      return;
    }

    settingsBloc.add(UpdateShowExternalBooks(enabled));
    settingsBloc.add(UpdateShowHebrewBooks(enabled));
    settingsBloc.add(UpdateShowOtzarHachochma(enabled));
    settingsBloc.add(UpdateAutoSyncCatalogs(enabled));
  }

  static Future<void> updateOtzarBooks(
    BuildContext context,
    bool enabled,
  ) async {
    final settingsBloc = context.read<SettingsBloc>();
    if (enabled && !await _ensureCatalogDatabaseAvailable(context)) {
      return;
    }

    if (enabled) {
      settingsBloc.add(const UpdateShowExternalBooks(true));
    }
    settingsBloc.add(UpdateShowOtzarHachochma(enabled));
  }

  static Future<void> updateHebrewBooks(
    BuildContext context,
    bool enabled,
  ) async {
    final settingsBloc = context.read<SettingsBloc>();
    if (enabled && !await _ensureCatalogDatabaseAvailable(context)) {
      return;
    }

    if (enabled) {
      settingsBloc.add(const UpdateShowExternalBooks(true));
    }
    settingsBloc.add(UpdateShowHebrewBooks(enabled));
  }

  static Future<bool> _ensureCatalogDatabaseAvailable(
    BuildContext context,
  ) async {
    final repository = ExternalCatalogRepository.instance;
    if (await repository.databaseExists()) {
      return true;
    }
    if (!context.mounted) {
      return false;
    }

    final settingsState = context.read<SettingsBloc>().state;
    if (settingsState.isOfflineMode ||
        !settingsState.softwareAndBookUpdatesEnabled) {
      await showSingleActionDialog(
        context: context,
        title: 'external_catalog.catalog_missing_title'.tr(),
        content: settingsState.isOfflineMode
            ? 'external_catalog.catalog_missing_offline'.tr()
            : 'external_catalog.catalog_missing_updates_disabled'.tr(),
        confirmText: 'external_catalog.catalog_missing_understood'.tr(),
      );
      return false;
    }

    final shouldDownload = await showTwoActionsDialog(
      context: context,
      title: 'external_catalog.catalog_missing_title'.tr(),
      content: 'external_catalog.catalog_download_prompt'.tr(),
      cancelText: 'external_catalog.catalog_download_later'.tr(),
      confirmText: 'external_catalog.catalog_download_now'.tr(),
    );

    if (shouldDownload != true) {
      UiSnack.show('external_catalog.catalog_skipped'.tr());
      return false;
    }
    if (!context.mounted) {
      return false;
    }

    try {
      UiSnack.show('external_catalog.catalog_downloading'.tr());
      await repository.downloadLatestDatabase();
      DataRepository.instance.invalidateExternalBooksCache();
      UiSnack.showSuccess('external_catalog.catalog_download_success'.tr());
      return true;
    } catch (e) {
      UiSnack.showError('external_catalog.catalog_download_error'
          .tr(namedArgs: {'error': '$e'}));
      return false;
    }
  }

  static Future<void> maybeAutoSyncCatalogs(
    SettingsState settingsState, {
    ExternalCatalogRepository? repository,
    VoidCallback? invalidateExternalBooksCache,
  }) async {
    if (!settingsState.showExternalBooks ||
        !settingsState.autoSyncCatalogs ||
        !settingsState.canUseSoftwareAndBookUpdates ||
        _isAutoSyncInProgress) {
      return;
    }

    final catalogsRepository = repository ?? ExternalCatalogRepository.instance;
    if (!await catalogsRepository.databaseExists()) {
      return;
    }

    _isAutoSyncInProgress = true;
    try {
      final updated = await catalogsRepository.updateDatabaseIfNeeded();
      if (updated) {
        (invalidateExternalBooksCache ??
            DataRepository.instance.invalidateExternalBooksCache)();
      }
    } catch (e) {
      debugPrint('Auto-sync external catalogs failed: $e');
    } finally {
      _isAutoSyncInProgress = false;
    }
  }
}
