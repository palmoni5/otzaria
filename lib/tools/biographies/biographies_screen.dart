import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/core/messages/tools_messages.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/settings/settings_exports.dart';
import 'package:otzaria/shortcuts/shortcut_helper.dart';
import 'package:otzaria/shortcuts/shortcut_validator.dart';
import 'package:otzaria/theme/theme_exports.dart';
import 'package:otzaria/tools/biographies/models/biography.dart';
import 'package:otzaria/tools/biographies/repository/biographies_repository.dart';
import 'package:otzaria/tools/biographies/widgets/biography_card.dart';
import 'package:otzaria/widgets/navigation/app_top_bar.dart';
import 'package:otzaria/widgets/text/otzaria_search_field.dart';
import 'package:otzaria/widgets/feedback/tool_empty_state.dart';
import 'package:otzaria/widgets/misc/tool_ui_helpers.dart';
import 'package:otzaria_icons/otzaria_icons.dart';

class BiographiesScreen extends StatefulWidget {
  const BiographiesScreen({super.key, this.repository});

  final BiographiesRepository? repository;

  @override
  State<BiographiesScreen> createState() => _BiographiesScreenState();
}

class _BiographiesScreenState extends State<BiographiesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late final BiographiesRepository _repository =
      widget.repository ?? BiographiesRepository.instance;
  List<Biography> _allBiographies = [];
  List<Biography> _filteredResults = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBiographies();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _searchFocusNode.requestFocus(),
    );
  }

  void requestKeyboardFocus() {
    if (!mounted || !_searchFocusNode.canRequestFocus) return;
    _searchFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadBiographies() async {
    try {
      final entries = await _repository.loadAll();
      if (!mounted) return;
      setState(() {
        _allBiographies = entries;
        _filteredResults = entries;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      UiSnack.showError(ToolsMessages.biographiesLoadError(e));
    }
  }

  void _performSearch(String query) {
    query = query.trim();
    setState(() {
      if (query.isEmpty) {
        _filteredResults = _allBiographies;
        return;
      }
      _filteredResults =
          _allBiographies.where((bio) {
            return bio.name.contains(query) ||
                bio.appelations.any((a) => a.contains(query));
          }).toList()..sort((a, b) {
            final rankCompare = _matchRank(
              a.name,
              query,
            ).compareTo(_matchRank(b.name, query));
            if (rankCompare != 0) return rankCompare;
            return a.name.compareTo(b.name);
          });
    });
  }

  /// דירוג התאמת שם לשאילתה: נמוך = דומה יותר.
  /// מדויק < מתחיל ב- < מילה שלמה < מכיל < רק בכינוי.
  int _matchRank(String name, String query) {
    if (name == query) return 0;
    if (name.startsWith(query)) return 1;
    if (RegExp('(^|\\s)${RegExp.escape(query)}(\$|\\s)').hasMatch(name)) {
      return 2;
    }
    if (name.contains(query)) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final searchShortcutSetting = context.select(
      (SettingsBloc bloc) =>
          bloc.state.shortcuts['key-shortcut-search-current-window'] ??
          ShortcutValidator
              .defaultShortcuts['key-shortcut-search-current-window'] ??
          'ctrl+f',
    );

    return CallbackShortcuts(
      bindings: {
        ShortcutHelper.activatorFromShortcut(searchShortcutSetting) ??
            const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          _searchFocusNode.requestFocus();
        },
      },
      child: Column(
        children: [
          AppTopBar(
            center: OtzariaSearchField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              hintText: 'חפש רב לפי שם או כינוי...',
              autofocus: true,
              onChanged: _performSearch,
              onClear: () => setState(() => _filteredResults = _allBiographies),
            ),
          ),
          Expanded(
            child: ToolPanelWrapper(child: _buildResultsList()),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    if (_allBiographies.isEmpty) {
      return const ToolEmptyState(
        icon: OtzariaIcons.search_24_regular,
        message: 'נתוני הביוגרפיות אינם זמינים',
      );
    }

    if (_filteredResults.isEmpty) {
      return const ToolEmptyState(
        icon: OtzariaIcons.search_24_regular,
        message: 'לא נמצאו תוצאות',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTokens.spaceMD),
      itemCount: _filteredResults.length,
      itemBuilder: (context, index) {
        final bio = _filteredResults[index];
        return BiographyCard(key: ValueKey(bio.id), biography: bio);
      },
    );
  }
}
