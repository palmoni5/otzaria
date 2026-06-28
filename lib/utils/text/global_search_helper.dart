import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/history/bloc/history_bloc.dart';
import 'package:otzaria/history/bloc/history_event.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/tabs/bloc/tabs_event.dart';
import 'package:otzaria/tabs/models/searching_tab.dart';

String previewForLabel(String text, {int maxLen = 25}) {
  final cleaned = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (cleaned.length <= maxLen) {
    return cleaned;
  }
  return '${cleaned.substring(0, maxLen)}…';
}

/// בונה תווית "חפש '<טקסט>' <סיומת>" שבה רק הטקסט שבתוך המרכאות
/// ייחתך עם `…` אם אין מספיק מקום, בעוד הקידומת "חפש '" והסיומת
/// (לדוגמה "' בספר זה") נשארות תמיד גלויות במלואן.
Widget buildSearchMenuLabel({
  required String selectedText,
  required String suffix,
}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('utils.search_menu_prefix'.tr()),
      Flexible(
        child: Text(
          selectedText,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          maxLines: 1,
        ),
      ),
      Text('utils.search_menu_suffix'.tr(namedArgs: {'suffix': suffix})),
    ],
  );
}

void openGlobalSearch(
  BuildContext context,
  String? selectedText, {
  bool insertAdjacent = true,
}) {
  final query = selectedText?.trim() ?? '';
  if (query.isEmpty) {
    UiSnack.show('utils.no_text_to_search'.tr());
    return;
  }

  final tab = SearchingTab(SearchingTab.titleForQuery(query), query);
  context.read<HistoryBloc>().add(AddHistory(tab));
  context.read<TabsBloc>().add(AddTab(tab, insertAdjacent: insertAdjacent));
}
