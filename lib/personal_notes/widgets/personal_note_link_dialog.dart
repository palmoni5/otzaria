import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:otzaria/personal_notes/models/personal_note.dart';
import 'package:otzaria/widgets/buttons/action_buttons.dart';
import 'package:otzaria/widgets/text/rtl_text_field.dart';

class PersonalNoteLinkTarget {
  final String label;
  final String url;

  const PersonalNoteLinkTarget({required this.label, required this.url});
}

class PersonalNoteLinkDialog extends StatefulWidget {
  final String? bookId;
  final List<PersonalNote> notes;

  const PersonalNoteLinkDialog({
    super.key,
    required this.notes,
    this.bookId,
  });

  @override
  State<PersonalNoteLinkDialog> createState() => _PersonalNoteLinkDialogState();
}

class _PersonalNoteLinkDialogState extends State<PersonalNoteLinkDialog> {
  final TextEditingController _lineController = TextEditingController();
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  int _selectedTab = 0;
  PersonalNote? _selectedNote;

  @override
  void dispose() {
    _lineController.dispose();
    _labelController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_selectedTab == 0) {
      final lineNumber = int.tryParse(_lineController.text.trim());
      if (lineNumber == null || lineNumber <= 0) return;
      final bookId = widget.bookId ?? '';
      final label = _labelController.text.trim().isEmpty
          ? 'personal_notes.link_line'.tr(namedArgs: {'line': '$lineNumber'})
          : _labelController.text.trim();
      final url = 'otzaria://book?bookId=$bookId&line=$lineNumber';
      Navigator.of(context).pop(
        PersonalNoteLinkTarget(label: label, url: url),
      );
      return;
    }

    final note = _selectedNote;
    if (note == null) return;
    final label = _labelController.text.trim().isEmpty
        ? (note.displayTitle?.trim().isNotEmpty == true
            ? note.displayTitle!.trim()
            : 'personal_notes.link_note_label'.tr())
        : _labelController.text.trim();
    final url = 'otzaria://note?id=${note.id}';
    Navigator.of(context).pop(PersonalNoteLinkTarget(label: label, url: url));
  }

  @override
  Widget build(BuildContext context) {
    final filteredNotes = widget.notes.where((note) {
      final query = _searchController.text.trim().toLowerCase();
      if (query.isEmpty) return true;
      return note.contentPlain.toLowerCase().contains(query) ||
          (note.displayTitle?.toLowerCase().contains(query) ?? false) ||
          note.id.toLowerCase().contains(query);
    }).toList();

    return AlertDialog(
      title: Text('personal_notes.link_add_title'.tr()),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ToggleButtons(
              isSelected: [_selectedTab == 0, _selectedTab == 1],
              onPressed: (index) {
                setState(() {
                  _selectedTab = index;
                  _labelController.clear();
                });
              },
              borderRadius: BorderRadius.circular(6),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('personal_notes.link_to_book'.tr()),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('personal_notes.link_to_note'.tr()),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedTab == 0)
              Column(
                children: [
                  RtlTextField(
                    controller: _lineController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'personal_notes.link_line_number'.tr(),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  RtlTextField(
                    controller: _labelController,
                    decoration: InputDecoration(
                      labelText: 'personal_notes.link_text_optional'.tr(),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  RtlTextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'personal_notes.link_search_note'.tr(),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 220,
                    child: ListView.builder(
                      itemCount: filteredNotes.length,
                      itemBuilder: (context, index) {
                        final note = filteredNotes[index];
                        final selected = note.id == _selectedNote?.id;
                        return ListTile(
                          title: Text(
                            note.displayTitle?.trim().isNotEmpty == true
                                ? note.displayTitle!
                                : note.contentPlain,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            note.contentPlain,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          selected: selected,
                          onTap: () => setState(() => _selectedNote = note),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  RtlTextField(
                    controller: _labelController,
                    decoration: InputDecoration(
                      labelText: 'personal_notes.link_text_optional'.tr(),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        NeutralActionButton(
          text: 'common.cancel'.tr(),
          onPressed: () => Navigator.of(context).pop(),
        ),
        RecommendedActionButton(
          text: 'personal_notes.link_add_button'.tr(),
          onPressed: _submit,
        ),
      ],
    );
  }
}
