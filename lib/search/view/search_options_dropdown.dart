import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:otzaria/search/search_query_builder.dart';

String _translateSearchOption(String option) {
  const Map<String, String> optionKeys = {
    'קידומות דקדוקיות': 'search.option_grammatical_prefixes',
    'סיומות דקדוקיות': 'search.option_grammatical_suffixes',
    'קידומות': 'search.option_prefixes',
    'סיומות': 'search.option_suffixes',
    'כתיב מלא/חסר': 'search.option_spelling',
    'חלק ממילה': 'search.option_partial_word',
    'שגיאות כתיב': 'search.option_typo_tolerance',
  };
  final key = optionKeys[option];
  return key != null ? key.tr() : option;
}

class SearchOptionsDropdown extends StatefulWidget {
  final Function(bool)? onToggle;
  final bool isExpanded;

  const SearchOptionsDropdown({
    super.key,
    this.onToggle,
    this.isExpanded = false,
  });

  @override
  State<SearchOptionsDropdown> createState() => _SearchOptionsDropdownState();
}

class _SearchOptionsDropdownState extends State<SearchOptionsDropdown> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded;
  }

  @override
  void didUpdateWidget(SearchOptionsDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      setState(() {
        _isExpanded = widget.isExpanded;
      });
    }
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    widget.onToggle?.call(_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(_isExpanded
          ? FluentIcons.chevron_up_24_regular
          : FluentIcons.chevron_down_24_regular),
      tooltip: 'search.options_tooltip'.tr(),
      onPressed: _toggleExpanded,
    );
  }
}

class SearchOptionsRow extends StatefulWidget {
  final bool isVisible;
  final String? currentWord; // המילה הנוכחית
  final int? wordIndex; // אינדקס המילה
  final Map<String, Map<String, bool>>? wordOptions; // אפשרויות מהטאב
  final VoidCallback? onOptionsChanged; // קולבק לעדכון

  const SearchOptionsRow({
    super.key,
    required this.isVisible,
    this.currentWord,
    this.wordIndex,
    this.wordOptions,
    this.onOptionsChanged,
  });

  @override
  State<SearchOptionsRow> createState() => _SearchOptionsRowState();
}

class _SearchOptionsRowState extends State<SearchOptionsRow> {
  // רשימת האפשרויות הזמינות
  static const List<String> _availableOptions =
      SearchQueryBuilder.availableWordOptionKeys;

  Map<String, bool> _getCurrentWordOptions() {
    final currentWord = widget.currentWord;
    final wordIndex = widget.wordIndex;
    final wordOptions = widget.wordOptions;

    if (currentWord == null ||
        currentWord.isEmpty ||
        wordIndex == null ||
        wordOptions == null) {
      return SearchQueryBuilder.disabledWordOptionsTemplate();
    }

    final key = '${currentWord}_$wordIndex';

    // אם אין אפשרויות למילה הזו, ניצור אותן
    if (!wordOptions.containsKey(key)) {
      wordOptions[key] = SearchQueryBuilder.disabledWordOptionsTemplate();
    }

    return wordOptions[key]!;
  }

  Widget _buildCheckbox(String option) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentOptions = _getCurrentWordOptions();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            final currentWord = widget.currentWord;
            final wordIndex = widget.wordIndex;
            final wordOptions = widget.wordOptions;

            if (currentWord != null &&
                currentWord.isNotEmpty &&
                wordIndex != null &&
                wordOptions != null) {
              final key = '${currentWord}_$wordIndex';

              // וודא שהמפתח קיים
              if (!wordOptions.containsKey(key)) {
                wordOptions[key] =
                    SearchQueryBuilder.disabledWordOptionsTemplate();
              }

              // עדכן את האפשרות
              wordOptions[key]![option] = !wordOptions[key]![option]!;

              // קרא לקולבק
              widget.onOptionsChanged?.call();
            }
          });
        },
        borderRadius: BorderRadius.circular(4),
        canRequestFocus: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IgnorePointer(
                child: Checkbox(
                  value: currentOptions[option]!,
                  onChanged: (_) {},
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: colorScheme.outline),
                ),
              ),
              const SizedBox(width: 6),
              Align(
                alignment: Alignment.center,
                child: Text(
                  _translateSearchOption(option),
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface,
                    height: 1.0, // מבטיח שהטקסט לא יהיה גבוה מדי
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      // הוחלף מ-AnimatedContainer
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: Visibility(
        visible: widget.isVisible,
        maintainState: true, // שומר את המצב של ה-Checkboxes גם כשהמגירה סגורה
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15), // צל מעודן יותר
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border(
              left: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              right: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(
                left: 48.0, right: 16.0, top: 8.0, bottom: 8.0),
            child: Wrap(
              spacing: 16.0, // רווח אופקי בין אלמנטים
              runSpacing: 8.0, // רווח אנכי בין שורות (זה המפתח!)
              children: _availableOptions
                  .map((option) => _buildCheckbox(option))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}
