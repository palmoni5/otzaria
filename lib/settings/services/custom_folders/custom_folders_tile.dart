import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import 'package:otzaria/data/data_providers/database_library_provider.dart';
import 'package:otzaria/settings/services/custom_folders/custom_folder.dart';
import 'package:otzaria/settings/services/custom_folders/bloc/custom_folders_bloc.dart';
import 'package:otzaria/widgets/dialogs/confirmation_dialog.dart';
import 'package:otzaria/widgets/widgets_exports.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/widgets/dialogs/zip_extraction_progress_dialog.dart';

/// Widget להוספה וניהול תיקיות מותאמות אישית
class CustomFoldersTile extends StatefulWidget {
  const CustomFoldersTile({super.key});

  @override
  State<CustomFoldersTile> createState() => _CustomFoldersTileState();
}

class _CustomFoldersTileState extends State<CustomFoldersTile> {
  bool _isExpanded = false;

  // מאזין לתור הגלובלי כדי שהכפתורים ייחסמו גם כשמסלול אחר (כגון file_sync)
  // כותב ל-DB באמצעות אותו תור.
  void _onQueueBusyChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    DatabaseLibraryProvider.operationQueue.busyCount
        .addListener(_onQueueBusyChanged);
  }

  @override
  void dispose() {
    DatabaseLibraryProvider.operationQueue.busyCount
        .removeListener(_onQueueBusyChanged);
    super.dispose();
  }

  Future<void> _addFolder() async {
    final bloc = context.read<CustomFoldersBloc>();
    final path = await FilePicker.getDirectoryPath(lockParentWindow: true);
    if (path == null) return;

    final dir = Directory(path);
    if (!await dir.exists()) {
      if (!mounted) return;
      UiSnack.showError('settings.custom_folders.folder_not_found'.tr());
      return;
    }

    bool zipExtracted = false;
    String? extractedFileName;

    final zipFiles = dir
        .listSync()
        .where((entity) =>
            entity is File && entity.path.toLowerCase().endsWith('.zip'))
        .cast<File>()
        .toList();

    if (zipFiles.isNotEmpty) {
      if (!mounted) return;
      await ZipExtractionProgressDialog.showAndExtract(
        context: context,
        path: path,
        onSuccess: (result) {
          if (result.successfullyExtracted) {
            zipExtracted = true;
            extractedFileName = result.extractedFileName;
          }
        },
        onError: (msg) => UiSnack.showError(msg),
      );
    }

    bloc.add(AddCustomFolder(path));

    String msg = 'settings.custom_folders.folder_added'.tr(
        namedArgs: {'name': path.split(Platform.pathSeparator).last});
    if (zipExtracted && extractedFileName != null) {
      msg += 'settings.custom_folders.extracted_added'
          .tr(namedArgs: {'file': extractedFileName!});
    }
    UiSnack.show(msg, duration: const Duration(seconds: 9));
  }

  Future<void> _removeFolder(CustomFolder folder) async {
    final bloc = context.read<CustomFoldersBloc>();
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'settings.custom_folders.remove_title'.tr(),
      content: 'settings.custom_folders.remove_content'
          .tr(namedArgs: {'name': folder.name}),
      isDangerous: false,
    );
    if (confirmed != true || !mounted) return;

    final deleteFromDb = await showTwoActionsDialog(
      context: context,
      title: 'settings.custom_folders.delete_db_title'.tr(),
      content: 'settings.custom_folders.delete_db_content'.tr(),
      cancelText: 'settings.custom_folders.keep_in_db'.tr(),
      confirmText: 'settings.custom_folders.delete_from_db'.tr(),
    );

    if (!mounted) return;
    bloc.add(RemoveCustomFolder(folder, deleteFromDb: deleteFromDb == true));
  }

  Future<void> _toggleAddToDatabase(CustomFolder folder, bool value) async {
    final bloc = context.read<CustomFoldersBloc>();
    if (value) {
      final confirmed = await showConfirmationDialog(
        context: context,
        title: 'settings.custom_folders.add_to_db_title'.tr(),
        content: 'settings.custom_folders.add_to_db_content'.tr(),
        isDangerous: false,
      );
      if (confirmed != true || !mounted) return;
    }
    bloc.add(ToggleAddToDatabase(folder, value));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CustomFoldersBloc, CustomFoldersState>(
      listenWhen: (prev, curr) =>
          (curr.message != null && curr.message != prev.message) ||
          (curr.error != null && curr.error != prev.error),
      listener: (context, state) {
        if (state.message != null) UiSnack.show(state.message!);
        if (state.error != null) UiSnack.showError(state.error!);
      },
      builder: (context, state) {
        final folders = state.folders;
        final isSyncing =
            state.isSyncing || DatabaseLibraryProvider.operationQueue.isBusy;
        return Column(
          children: [
            ListTile(
              leading: const Icon(FluentIcons.folder_add_24_regular),
              title: Text('settings.custom_folders.add_folder_title'.tr()),
              subtitle: Text(
                folders.isEmpty
                    ? 'settings.custom_folders.no_folders_subtitle'.tr()
                    : 'settings.custom_folders.folders_count'.tr(
                        namedArgs: {'count': folders.length.toString()}),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              hoverColor: Colors.transparent,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (folders.isNotEmpty)
                    IconButton(
                      icon: isSyncing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(FluentIcons.arrow_clockwise_24_regular),
                      onPressed: isSyncing
                          ? null
                          : () => context
                              .read<CustomFoldersBloc>()
                              .add(const RescanCustomFolders()),
                      tooltip: 'settings.custom_folders.rescan_tooltip'.tr(),
                    ),
                  RecommendedActionButton(
                    text: 'settings.custom_folders.add_folder_button'.tr(),
                    icon: FluentIcons.folder_add_24_regular,
                    onPressed: _addFolder,
                    isLoading: isSyncing,
                  ),
                  if (folders.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        _isExpanded
                            ? FluentIcons.chevron_up_24_regular
                            : FluentIcons.chevron_down_24_regular,
                      ),
                      onPressed: () =>
                          setState(() => _isExpanded = !_isExpanded),
                      tooltip: _isExpanded
                          ? 'settings.custom_folders.hide_tooltip'.tr()
                          : 'settings.custom_folders.show_tooltip'.tr(),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          FluentIcons.info_24_regular,
                          size: 18,
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'settings.custom_folders.reload_notice'.tr(),
                          textDirection: TextDirection.rtl,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSecondaryContainer,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isExpanded && folders.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(right: 16, left: 16, bottom: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: folders.map((folder) {
                    return _buildFolderItem(folder, isSyncing);
                  }).toList(),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFolderItem(CustomFolder folder, bool isSyncing) {
    return ListTile(
      dense: true,
      leading: Icon(
        FluentIcons.folder_24_filled,
        color: Theme.of(context).colorScheme.primary,
        size: 20,
      ),
      title: Text(folder.name, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        folder.path,
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: 'settings.custom_folders.add_to_db_tooltip'.tr(),
            child: isSyncing && folder.addToDatabase
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Switch(
                    value: folder.addToDatabase,
                    onChanged: isSyncing
                        ? null
                        : (value) => _toggleAddToDatabase(folder, value),
                  ),
          ),
          IconButton(
            icon: const Icon(FluentIcons.delete_24_regular, size: 18),
            onPressed: isSyncing ? null : () => _removeFolder(folder),
            tooltip: 'settings.custom_folders.remove_folder_tooltip'.tr(),
          ),
        ],
      ),
    );
  }
}
