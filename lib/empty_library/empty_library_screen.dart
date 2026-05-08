import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/empty_library/bloc/empty_library_bloc.dart';
import 'package:otzaria/empty_library/bloc/empty_library_event.dart';
import 'package:otzaria/empty_library/bloc/empty_library_state.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/widgets/dialogs/dialogs_exports.dart';

class EmptyLibraryScreen extends StatelessWidget {
  final Future<void> Function() onLibraryLoaded;
  final EmptyLibraryBloc? bloc;

  const EmptyLibraryScreen({
    super.key,
    required this.onLibraryLoaded,
    this.bloc,
  });

  @override
  Widget build(BuildContext context) {
    if (bloc != null) {
      return BlocProvider.value(
        value: bloc!,
        child: _EmptyLibraryView(onLibraryLoaded: onLibraryLoaded),
      );
    }
    return BlocProvider(
      create: (context) => EmptyLibraryBloc(),
      child: _EmptyLibraryView(onLibraryLoaded: onLibraryLoaded),
    );
  }
}

class _EmptyLibraryView extends StatefulWidget {
  final Future<void> Function() onLibraryLoaded;

  const _EmptyLibraryView({required this.onLibraryLoaded});

  @override
  State<_EmptyLibraryView> createState() => _EmptyLibraryViewState();
}

class _EmptyLibraryViewState extends State<_EmptyLibraryView> {
  Future<void> _handleLibraryLoaded() async {
    try {
      await widget.onLibraryLoaded();
    } catch (error) {
      UiSnack.showError('empty_library.library_load_error'.tr());
      debugPrint('Failed to refresh library after selection: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<EmptyLibraryBloc, EmptyLibraryState>(
        listener: (context, state) {
          if (state is EmptyLibraryDirectorySelected) {
            unawaited(_handleLibraryLoaded());
          }
          if (state is EmptyLibraryZipExtracted) {
            UiSnack.showSuccess(
              'empty_library.zip_extracted_success'
                  .tr(namedArgs: {'name': state.extractedFileName}),
            );
          }
          if (state is EmptyLibraryError && state.errorMessage != null) {
            if (state.zipFiles != null && state.zipFiles!.isNotEmpty) {
              _showMultipleZipFilesDialog(context, state.zipFiles!);
            } else {
              UiSnack.showError(state.errorMessage!);
            }
          }
          if (state is EmptyLibraryAskingDeleteZip) {
            _showDeleteZipDialog(context, state);
          }
          if (state is EmptyLibraryAskingDbCopy) {
            if (state.errorMessage != null) {
              UiSnack.showError(state.errorMessage!);
            }
            _showDbCopyDialog(context, state);
          }
        },
        builder: (context, state) {
          return Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(16),
              child: _buildContent(context, state),
            ),
          );
        },
      ),
    );
  }

  /// מציג דיאלוג המסביר למשתמש את מגבלת Android Scoped Storage.
  /// המשתמש בוחר בין העתקה (שמירת מקור) להעברה (מחיקת מקור לפנית מקום).
  void _showDbCopyDialog(BuildContext context, EmptyLibraryAskingDbCopy state) {
    final sizeText = state.dbSizeBytes > 0
        ? '${(state.dbSizeBytes / 1024 / 1024).toStringAsFixed(1)} MB'
        : 'empty_library.size_unknown'.tr();

    showDbCopyRequiredDialog(
      context: context,
      sizeText: sizeText,
    ).then((shouldMove) {
      if (shouldMove == null) {
        return;
      }

      if (!context.mounted) {
        return;
      }

      BlocProvider.of<EmptyLibraryBloc>(context).add(
        PickDbFileRequested(
          libraryPath: state.libraryPath,
          internalDbPath: state.internalDbPath,
          externalDbPath: state.externalDbPath,
          shouldMove: shouldMove,
        ),
      );
    });
  }

  void _showDeleteZipDialog(
      BuildContext context, EmptyLibraryAskingDeleteZip state) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text('empty_library.delete_zip_title'.tr()),
        content: Text(
          'empty_library.delete_zip_content'.tr(),
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              BlocProvider.of<EmptyLibraryBloc>(context).add(
                DeleteZipAnswered(
                  shouldDelete: false,
                  zipPath: state.zipPath,
                  extractedPath: state.extractedPath,
                ),
              );
            },
            child: Text('empty_library.keep_zip'.tr()),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              BlocProvider.of<EmptyLibraryBloc>(context).add(
                DeleteZipAnswered(
                  shouldDelete: true,
                  zipPath: state.zipPath,
                  extractedPath: state.extractedPath,
                ),
              );
            },
            child: Text('empty_library.delete_zip'.tr()),
          ),
        ],
      ),
    );
  }

  void _showMultipleZipFilesDialog(
      BuildContext context, List<String> zipFiles) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('empty_library.multiple_zips_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('empty_library.multiple_zips_intro'.tr()),
            const SizedBox(height: 8),
            ...zipFiles.map((file) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('• $file'),
                )),
            const SizedBox(height: 16),
            Text(
              'empty_library.multiple_zips_instruction'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('empty_library.multiple_zips_understood'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, EmptyLibraryState state) {
    // אם בתהליך הורדה או חילוץ, נציג את ההתקדמות
    if (state is EmptyLibraryDownloading) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FluentIcons.arrow_download_24_regular,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'empty_library.downloading_title'.tr(),
            style:
                const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 300,
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: state.progress > 0 ? state.progress : null,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 16),
                Text(
                  state.message,
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                if (state.progress > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${(state.progress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    if (state is EmptyLibraryExtracting) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FluentIcons.folder_zip_24_regular,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'empty_library.extracting_title'.tr(),
            style:
                const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 300,
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: state.progress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 16),
                Text(
                  state.message,
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '${(state.progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // המסך הרגיל
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          FluentIcons.library_24_regular,
          size: 64,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 24),
        Text(
          'empty_library.no_library_found'.tr(),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 16),
        Text(
          'empty_library.no_library_description'.tr(),
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        if (state.selectedPath != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                state.selectedPath!,
                style: const TextStyle(fontSize: 14),
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: state.isLoading ? null : () => _pickDirectory(context),
              icon: const Icon(FluentIcons.folder_open_24_regular),
              label: Text('empty_library.pick_directory'.tr()),
            ),
            ElevatedButton.icon(
              onPressed:
                  state.isLoading ? null : () => _pickArchiveFile(context),
              icon: const Icon(FluentIcons.folder_zip_24_regular),
              label: Text('empty_library.extract_from_zip'.tr()),
            ),
          ],
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: state.isLoading || state.downloadDisabledReason != null
              ? null
              : () {
                  BlocProvider.of<EmptyLibraryBloc>(context)
                      .add(DownloadLibraryRequested());
                },
          icon: const Icon(FluentIcons.arrow_download_24_regular),
          label: Text(
            'empty_library.download_prompt'.tr(),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
          ),
        ),
        if (state.downloadDisabledReason != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              textDirection: TextDirection.rtl,
              children: [
                Icon(
                  FluentIcons.warning_24_regular,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.downloadDisabledReason!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (state.isLoading && state is EmptyLibraryLoading) ...[
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
          const SizedBox(height: 8),
          Text('empty_library.checking_directory'.tr()),
        ],
      ],
    );
  }

  Future<void> _pickDirectory(BuildContext context) async {
    BlocProvider.of<EmptyLibraryBloc>(context).add(PickDirectoryRequested());
  }

  Future<void> _pickArchiveFile(BuildContext context) async {
    BlocProvider.of<EmptyLibraryBloc>(context).add(PickArchiveFileRequested());
  }
}
