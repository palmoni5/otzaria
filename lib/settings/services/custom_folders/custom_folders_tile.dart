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

/// סיווג הרכב הקבצים בתיקייה מותאמת אישית — קובע אילו אפשרויות אחסון
/// רלוונטיות ואילו הסברים להציג למשתמש.
enum _FolderContentKind {
  /// אין קבצים נתמכים בתיקייה.
  empty,

  /// רק קבצי טקסט (TXT) — ניתן לשמור כעותק עצמאי בתוכנה.
  textOnly,

  /// רק קבצי PDF/Word — נקראים תמיד ישירות מהקבצים.
  binaryOnly,

  /// גם טקסט וגם PDF/Word — רק הטקסט יישמר כעותק עצמאי.
  mixed,
}

/// Widget להוספה וניהול תיקיות מותאמות אישית
class CustomFoldersTile extends StatefulWidget {
  const CustomFoldersTile({super.key});

  @override
  State<CustomFoldersTile> createState() => _CustomFoldersTileState();
}

class _CustomFoldersTileState extends State<CustomFoldersTile> {
  bool _isExpanded = false;

  /// תוצאות סיווג הרכב הקבצים לכל תיקייה (לפי נתיב). מתמלא בעצלתיים
  /// כשהרשימה נפתחת, כדי לא לסרוק תיקיות שאינן מוצגות.
  final Map<String, _FolderContentKind> _folderKinds = {};
  final Set<String> _scanningFolders = {};

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

  /// סורק את התיקייה (רק לפי סיומות, לא קורא תוכן) ומסווג את הרכב הקבצים.
  /// הסריקה אסינכרונית ולא חוסמת את ה-UI, ועוצרת מוקדם ברגע שהתגלה גם
  /// טקסט וגם קובץ בינארי (כלומר "מעורב").
  Future<_FolderContentKind> _classifyFolder(String path) async {
    var hasText = false;
    var hasBinary = false;
    try {
      final dir = Directory(path);
      if (!await dir.exists()) return _FolderContentKind.empty;
      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final lower = entity.path.toLowerCase();
        if (lower.endsWith('.txt')) {
          hasText = true;
        } else if (lower.endsWith('.pdf') || lower.endsWith('.docx')) {
          hasBinary = true;
        }
        if (hasText && hasBinary) break;
      }
    } catch (_) {
      return _FolderContentKind.empty;
    }
    if (hasText && hasBinary) return _FolderContentKind.mixed;
    if (hasText) return _FolderContentKind.textOnly;
    if (hasBinary) return _FolderContentKind.binaryOnly;
    return _FolderContentKind.empty;
  }

  /// מתחיל סריקת סיווג לתיקייה אם טרם נסרקה. בטוח לקריאה חוזרת.
  void _ensureFolderClassified(String path) {
    if (_folderKinds.containsKey(path) || _scanningFolders.contains(path)) {
      return;
    }
    _scanningFolders.add(path);
    _classifyFolder(path).then((kind) {
      if (!mounted) return;
      setState(() {
        _folderKinds[path] = kind;
        _scanningFolders.remove(path);
      });
    });
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
    // אין צורך לאפס כאן את הסיווג — ה-listener מאפס את כל הקאש בסיום
    // הסריקה (כולל חילוץ ZIP ששינה את הרכב הקבצים).

    String msg = 'settings.custom_folders.folder_added'.tr(namedArgs: {
      'name': path.split(Platform.pathSeparator).last,
    });
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

    // הסרת תיקייה תמיד מוחקת את ספריה מהתוכנה — גם אם תוכנם נשמר כעותק
    // עצמאי וגם אם הם מוגדרים לקריאה ישירה מהקבצים. ה-prune שרץ ברענון
    // ימחק אותם בכל מקרה, ולכן אין משמעות ל"השארה" שלהם ב-DB.
    bloc.add(RemoveCustomFolder(folder, deleteFromDb: true));
  }

  /// מחליף את מצב האחסון של התיקייה: עותק עצמאי בתוכנה (true) או קריאה
  /// ישירה מהקבצים (false).
  Future<void> _setStorageMode(CustomFolder folder, bool toDatabase) async {
    final bloc = context.read<CustomFoldersBloc>();
    if (toDatabase) {
      final confirmed = await showConfirmationDialog(
        context: context,
        title: 'settings.custom_folders.add_to_db_title'.tr(),
        content: 'settings.custom_folders.add_to_db_content'.tr(),
        isDangerous: false,
      );
      if (confirmed != true || !mounted) return;
    }
    bloc.add(ToggleAddToDatabase(folder, toDatabase));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CustomFoldersBloc, CustomFoldersState>(
      listenWhen: (prev, curr) =>
          (curr.message != null && curr.message != prev.message) ||
          (curr.error != null && curr.error != prev.error) ||
          (prev.isSyncing && !curr.isSyncing),
      listener: (context, state) {
        if (state.message != null) UiSnack.show(state.message!);
        if (state.error != null) UiSnack.showError(state.error!);
        if (!state.isSyncing) {
          // סריקה/סנכרון הסתיימו — ייתכן שתוכן התיקיות בדיסק השתנה (נוספו
          // או הוסרו קבצים). מאפסים את קאש סיווג סוגי הקבצים כדי שיחושב
          // מחדש, אחרת ה-UI עלול להציג מצב אחסון או הסבר מיושן.
          _folderKinds.clear();
          _scanningFolders.clear();
        }
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
                  children: [
                    _buildStorageLegend(),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    ...folders.map(
                      (folder) => _buildFolderItem(
                        folder,
                        isSyncing,
                        state.activePath,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFolderItem(
      CustomFolder folder, bool isSyncing, String? activePath) {
    // הספינר על תיקייה בודדת מוצג כשהפעולה נוגעת בה:
    // • כשזו התיקייה הפעילה (הוספה / החלפת מצב) — תמיד, גם אם היא מוגדרת
    //   לקריאה מהקבצים (תיקייה חדשה נוצרת עם addToDatabase=false אך עדיין
    //   נסרקת).
    // • כשהפעולה גלובלית (activePath == null, כגון סריקה מחדש או כתיבה דרך
    //   התור המשותף) — רק על תיקיות שנשמרות כעותק עצמאי, שהן אלו שנכתבות.
    final showFolderSpinner = isSyncing &&
        (activePath == folder.path ||
            (activePath == null && folder.addToDatabase));
    // מתחיל סיווג עצלן של הרכב הקבצים (פעם אחת לכל תיקייה).
    _ensureFolderClassified(folder.path);
    final kind = _folderKinds[folder.path];
    final cs = Theme.of(context).colorScheme;

    // קבצי PDF/Word נקראים תמיד מהקבצים — אין משמעות ל"עותק עצמאי".
    final binaryOnly = kind == _FolderContentKind.binaryOnly;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                FluentIcons.folder_24_filled,
                color: cs.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      folder.name,
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      folder.path,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (showFolderSpinner)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              IconButton(
                icon: const Icon(FluentIcons.delete_24_regular, size: 18),
                onPressed: isSyncing ? null : () => _removeFolder(folder),
                tooltip: 'settings.custom_folders.remove_folder_tooltip'.tr(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // בחירת מצב אחסון. כשהתיקייה מכילה רק PDF/Word אין בחירה (הם
          // תמיד נקראים מהקבצים), ולכן מוצגת תווית במקום הפקד.
          if (!binaryOnly)
            Align(
              alignment: Alignment.centerRight,
              child: Opacity(
                opacity: isSyncing ? 0.5 : 1.0,
                child: IgnorePointer(
                  ignoring: isSyncing,
                  child: AppSegmentedControl<bool>(
                    currentValue: folder.addToDatabase,
                    onChanged: (value) => _setStorageMode(folder, value),
                    options: [
                      SegmentOption(
                        value: false,
                        label: 'settings.custom_folders.storage_read_label'.tr(),
                        icon: FluentIcons.document_24_regular,
                      ),
                      SegmentOption(
                        value: true,
                        label: 'settings.custom_folders.storage_db_label'.tr(),
                        icon: FluentIcons.database_24_regular,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'settings.custom_folders.pdf_word_label'.tr(),
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// מקרא המסביר את ההבדל בין מצבי האחסון. מוצג פעם אחת מעל רשימת
  /// התיקיות, במקום הסבר/אזהרה חוזרים תחת כל תיקייה.
  Widget _buildStorageLegend() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _legendRow(
            FluentIcons.document_24_regular,
            'settings.custom_folders.legend_read'.tr(),
          ),
          const SizedBox(height: 8),
          _legendRow(
            FluentIcons.database_24_regular,
            'settings.custom_folders.legend_db'.tr(),
          ),
          const SizedBox(height: 8),
          _legendRow(
            FluentIcons.info_24_regular,
            'settings.custom_folders.legend_pdf'.tr(),
          ),
        ],
      ),
    );
  }

  Widget _legendRow(IconData icon, String text) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: cs.primary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
