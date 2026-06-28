import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:path/path.dart' as p;
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:otzaria/plugins/models/plugin_valid_permissions.dart';
import 'package:otzaria/plugins/utils/plugin_version_utils.dart';

class PluginManifestValidator {
  static Future<void> validateManifest({
    required PluginManifest manifest,
    required String directoryPath,
    String? currentAppVersion,
    bool skipAppVersionValidation = false,
    bool skipFileValidation = false,
  }) async {
    if (manifest.schemaVersion != 1) {
      throw Exception(
          'plugins.manifest_validator.schema_version_unsupported'.tr(
              namedArgs: {'version': manifest.schemaVersion.toString()}));
    }

    if (!RegExp(r'^[a-z0-9_.-]+$').hasMatch(manifest.id)) {
      throw Exception('plugins.manifest_validator.invalid_id'.tr());
    }

    if (!RegExp(r'^\d+\.\d+\.\d+(?:\+.*)?$').hasMatch(manifest.version)) {
      throw Exception('plugins.manifest_validator.invalid_version'.tr());
    }

    int compareVersionsStrict(String v1, String v2) {
      return PluginVersionUtils.compareCoreVersions(v1, v2);
    }

    if (!skipAppVersionValidation) {
      if (currentAppVersion == null) {
        throw Exception(
            'currentAppVersion is required when skipAppVersionValidation is false');
      }
      if (compareVersionsStrict(currentAppVersion, manifest.minAppVersion) <
          0) {
        throw Exception(
            'plugins.manifest_validator.min_app_version_required'.tr(
                namedArgs: {
              'min': manifest.minAppVersion,
              'current': currentAppVersion
            }));
      }
      if (manifest.maxAppVersion != null &&
          compareVersionsStrict(currentAppVersion, manifest.maxAppVersion!) >
              0) {
        throw Exception(
            'plugins.manifest_validator.max_app_version_required'.tr(
                namedArgs: {
              'max': manifest.maxAppVersion!,
              'current': currentAppVersion
            }));
      }
    }

    for (final perm in manifest.permissions) {
      if (!pluginValidPermissions.contains(perm)) {
        final hint = apiCallToPermissionHint[perm];
        if (hint != null) {
          throw Exception(
              'plugins.manifest_validator.invalid_permission_with_hint'
                  .tr(namedArgs: {'perm': perm, 'hint': hint}));
        }
        throw Exception('plugins.manifest_validator.invalid_permission'
            .tr(namedArgs: {'perm': perm}));
      }
    }

    if (manifest.databaseSources.isNotEmpty &&
        !manifest.permissions.contains('database.read')) {
      throw Exception(
          'plugins.manifest_validator.database_read_missing'.tr());
    }

    for (final source in manifest.databaseSources) {
      final id = source['id'];
      final label = source['label'];
      final required = source['required'];

      if (id is! String || id.isEmpty) {
        throw Exception(
            'plugins.manifest_validator.db_source_id_required'.tr());
      }
      if (!RegExp(r'^[a-z0-9_.-]+$').hasMatch(id)) {
        throw Exception('plugins.manifest_validator.db_source_id_invalid'
            .tr(namedArgs: {'id': id}));
      }
      if (label != null && label is! String) {
        throw Exception(
            'plugins.manifest_validator.db_source_label_invalid'.tr());
      }
      if (required != null && required is! bool) {
        throw Exception(
            'plugins.manifest_validator.db_source_required_invalid'.tr());
      }
    }

    final iconName = manifest.toolTabIconName;
    if (iconName != null &&
        !PluginManifest.toolTabIconNamePattern.hasMatch(iconName)) {
      throw Exception(
          'toolTab.iconName must be a valid FluentUI 24px icon name '
          '(e.g. "book_24_regular" or "calendar_24_filled")');
    }

    if (!skipFileValidation) {
      final entrypointPath =
          p.normalize(p.join(directoryPath, manifest.entrypoint));
      if (!p.isWithin(directoryPath, entrypointPath)) {
        throw Exception('plugins.manifest_validator.entrypoint_outside_dir'
            .tr(namedArgs: {'path': manifest.entrypoint}));
      }
      if (!File(entrypointPath).existsSync()) {
        throw Exception('plugins.manifest_validator.entrypoint_not_found'
            .tr(namedArgs: {'path': manifest.entrypoint}));
      }
    }
  }
}
