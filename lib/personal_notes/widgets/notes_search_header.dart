import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:otzaria/personal_notes/bloc/personal_notes_bloc.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_event.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_state.dart';
import 'package:otzaria/widgets/text/otzaria_search_field.dart';

class NotesSearchHeader extends StatefulWidget {
  final String bookId;
  final int? categoryId;
  final bool isPdf;

  const NotesSearchHeader({
    super.key,
    required this.bookId,
    this.categoryId,
    this.isPdf = false,
  });

  @override
  State<NotesSearchHeader> createState() => _NotesSearchHeaderState();
}

class _NotesSearchHeaderState extends State<NotesSearchHeader> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void didUpdateWidget(covariant NotesSearchHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    // איפוס החיפוש כשעוברים לספר אחר (כולל אותו שם בקטגוריה שונה)
    if (oldWidget.bookId != widget.bookId ||
        oldWidget.categoryId != widget.categoryId) {
      _searchController.clear();
      // ה-BLoC כבר מתאפס ב-Sidebar, אז לא צריך לשלוח אירוע כאן
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PersonalNotesBloc, PersonalNotesState>(
      builder: (context, state) {
        final totalNotes =
            state.locatedNotes.length + state.missingNotes.length;
        final visibleNotes = state.filteredLocatedNotes.length +
            state.filteredMissingNotes.length;

        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OtzariaSearchField(
                      controller: _searchController,
                      hintText: 'personal_notes.search_hint'.tr(),
                      onChanged: (value) {
                        context
                            .read<PersonalNotesBloc>()
                            .add(UpdateSearchQuery(value));
                      },
                      onClear: () {
                        context
                            .read<PersonalNotesBloc>()
                            .add(const UpdateSearchQuery(''));
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'personal_notes.refresh'.tr(),
                    onPressed: () {
                      context.read<PersonalNotesBloc>().add(
                            LoadPersonalNotes(
                              widget.bookId,
                              categoryId: state.categoryId,
                            ),
                          );
                    },
                    icon: const Icon(FluentIcons.arrow_clockwise_24_regular),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        context
                            .read<PersonalNotesBloc>()
                            .add(const ToggleShowOnlyVisible());
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              state.showOnlyVisible
                                  ? FluentIcons.checkbox_checked_24_regular
                                  : FluentIcons.checkbox_unchecked_24_regular,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.isPdf
                                    ? 'personal_notes.show_only_pdf'.tr()
                                    : 'personal_notes.show_only_text'.tr(),
                                style: Theme.of(context).textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Text(
                    '$visibleNotes/$totalNotes',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
