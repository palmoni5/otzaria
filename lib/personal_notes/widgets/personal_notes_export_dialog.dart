import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:otzaria/personal_notes/models/personal_note.dart';
import 'package:otzaria/widgets/misc/app_menu_exports.dart';
import 'package:otzaria/widgets/widgets_exports.dart';
import 'package:otzaria/widgets/text/rtl_text_field.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

enum NotesExportMode {
  all,
  byBook,
  byDateRange,
  manual,
}

class NotesExportSelection {
  final List<PersonalNote> notes;
  final String description;

  const NotesExportSelection({required this.notes, required this.description});
}

class PersonalNotesExportDialog extends StatefulWidget {
  final List<PersonalNote> allNotes;

  const PersonalNotesExportDialog({
    super.key,
    required this.allNotes,
  });

  @override
  State<PersonalNotesExportDialog> createState() =>
      _PersonalNotesExportDialogState();
}

class _PersonalNotesExportDialogState extends State<PersonalNotesExportDialog> {
  NotesExportMode _mode = NotesExportMode.all;
  String? _selectedBookId;
  DateTimeRange? _dateRange;
  final TextEditingController _searchController = TextEditingController();
  final Map<String, bool> _manualSelection = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _submit() {
    final selection = _buildSelection();
    Navigator.of(context).pop(selection);
  }

  NotesExportSelection _buildSelection() {
    final notes = widget.allNotes;
    List<PersonalNote> result = notes;
    String description = 'personal_notes.export_all'.tr();

    if (_mode == NotesExportMode.byBook && _selectedBookId != null) {
      result = notes.where((note) => note.bookId == _selectedBookId).toList();
      description = 'personal_notes.export_by_book'.tr(namedArgs: {'book': _selectedBookId!});
    } else if (_mode == NotesExportMode.byDateRange && _dateRange != null) {
      final start = DateUtils.dateOnly(_dateRange!.start);
      final endExclusive = DateUtils.dateOnly(
        _dateRange!.end,
      ).add(const Duration(days: 1));
      result = notes
          .where((note) =>
              !note.updatedAt.isBefore(start) &&
              note.updatedAt.isBefore(endExclusive))
          .toList();
      description = 'personal_notes.export_by_date'.tr(namedArgs: {
        'start': _dateRange!.start.toIso8601String(),
        'end': _dateRange!.end.toIso8601String(),
      });
    } else if (_mode == NotesExportMode.manual) {
      result =
          notes.where((note) => _manualSelection[note.id] == true).toList();
      description = 'personal_notes.export_manual'.tr(namedArgs: {'count': '${result.length}'});
    }

    return NotesExportSelection(notes: result, description: description);
  }

  @override
  Widget build(BuildContext context) {
    final books = widget.allNotes.map((note) => note.bookId).toSet().toList()
      ..sort();

    final filteredNotes = widget.allNotes.where((note) {
      final query = _searchController.text.trim().toLowerCase();
      if (query.isEmpty) return true;
      return note.contentPlain.toLowerCase().contains(query) ||
          note.bookId.toLowerCase().contains(query) ||
          (note.displayTitle?.toLowerCase().contains(query) ?? false);
    }).toList();

    return AlertDialog(
      title: Text('personal_notes.export_dialog_title'.tr()),
      content: SizedBox(
        width: 540,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: NotesExportMode.values.map((mode) {
                return ChoiceChip(
                  label: Text(_labelForMode(mode)),
                  selected: _mode == mode,
                  onSelected: (_) => setState(() => _mode = mode),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            if (_mode == NotesExportMode.byBook)
              AppDropdownField<String>(
                value: _selectedBookId,
                entries: books
                    .map(
                      (bookId) => AppMenuEntry(
                        value: bookId,
                        label: bookId,
                      ),
                    )
                    .toList(),
                onSelected: (value) => setState(() => _selectedBookId = value),
                decoration: InputDecoration(
                  labelText: 'personal_notes.select_book'.tr(),
                  border: const OutlineInputBorder(),
                ),
              ),
            if (_mode == NotesExportMode.byDateRange)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_dateRange == null
                    ? 'personal_notes.select_date_range'.tr()
                    : '${_dateRange!.start.toString().split(' ').first} - ${_dateRange!.end.toString().split(' ').first}'),
                trailing: const Icon(FluentIcons.calendar_24_regular),
                onTap: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => _dateRange = picked);
                  }
                },
              ),
            if (_mode == NotesExportMode.manual) ...[
              RtlTextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'personal_notes.search_notes_hint'.tr(),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 240,
                child: ListView.builder(
                  itemCount: filteredNotes.length,
                  itemBuilder: (context, index) {
                    final note = filteredNotes[index];
                    final selected = _manualSelection[note.id] ?? false;
                    return CheckboxListTile(
                      value: selected,
                      title: Text(note.displayTitle?.isNotEmpty == true
                          ? note.displayTitle!
                          : note.bookId),
                      subtitle: Text(
                        note.contentPlain,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onChanged: (value) {
                        setState(
                            () => _manualSelection[note.id] = value ?? false);
                      },
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        NeutralActionButton(
          onPressed: () => Navigator.of(context).pop(),
          text: 'common.cancel'.tr(),
        ),
        RecommendedActionButton(
          onPressed: _submit,
          text: 'personal_notes.export_action'.tr(),
        ),
      ],
    );
  }

  String _labelForMode(NotesExportMode mode) {
    switch (mode) {
      case NotesExportMode.all:
        return 'personal_notes.export_tab_all'.tr();
      case NotesExportMode.byBook:
        return 'personal_notes.export_tab_by_book'.tr();
      case NotesExportMode.byDateRange:
        return 'personal_notes.export_tab_time_range'.tr();
      case NotesExportMode.manual:
        return 'personal_notes.export_tab_manual'.tr();
    }
  }
}
