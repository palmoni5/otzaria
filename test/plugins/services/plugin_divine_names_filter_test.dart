import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/divine_names/models/divine_name_spans.dart';
import 'package:otzaria/divine_names/repository/divine_names_repository.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/plugins/services/plugin_divine_names_filter.dart';
import 'package:otzaria/settings/engine/app_settings_store.dart';
import 'package:otzaria/settings/engine/settings_repository.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/text_display/text_display_exports.dart';

import '../../helpers/memory_settings_cache.dart';

const _line = 'ויאמר אלהים יהוה';

final _spans =
    (DivineNameSpansBuilder()
          ..add(0, 6, 11, DivineNameKind.elohim)
          ..add(0, 12, 16, DivineNameKind.hvyh))
        .build();

PluginDivineNamesDisplay _names(
  HolyNameDisplay holyName, {
  bool substitute = false,
}) => PluginDivineNamesDisplay(
  holyName: holyName,
  otherNames: substitute
      ? DivineNamesDisplay.substitute
      : DivineNamesDisplay.asIs,
);

Future<void> _savePolicy({
  HolyNameDisplay? holyName,
  DivineNamesDisplay? divineNames,
  HolyNameDisplay? tanachHolyName,
}) => Settings.setValue<String>(
  SettingsRepository.keyTextDisplayPolicy,
  jsonEncode(
    TextDisplayPolicy(
      general: TextDisplayLayer({
        TextDisplaySlot.root: TextDisplayPatch(
          holyName: holyName,
          divineNames: divineNames,
        ),
      }),
      tanach: tanachHolyName == null
          ? TextDisplayLayer.empty
          : TextDisplayLayer({
              TextDisplaySlot.root: TextDisplayPatch(holyName: tanachHolyName),
            }),
    ).toJson(),
  ),
);

void main() {
  setUpAll(() async {
    await Settings.init(cacheProvider: MemorySettingsCache());
  });

  tearDown(() async {
    PluginDivineNamesFilter.debugIsTanach = null;
    DivineNamesRepository.instance
      ..debugLoader = null
      ..debugIsDatabaseBook = null
      ..clear();
    await Settings.setValue<String>(
      SettingsRepository.keyTextDisplayPolicy,
      '',
    );
  });

  group('filterPluginDivineNamesLine', () {
    test('כל סגנון של שם הוי"ה, ושאר השמות לפי המופעים', () {
      String filter(HolyNameDisplay holyName, {bool substitute = false}) =>
          filterPluginDivineNamesLine(
            _line,
            0,
            _spans,
            _names(holyName, substitute: substitute),
          );

      expect(filter(HolyNameDisplay.kufKuf), 'ויאמר אלהים יקוק');
      expect(
        filter(HolyNameDisplay.kufKuf, substitute: true),
        'ויאמר אלקים יקוק',
      );
      expect(filter(HolyNameDisplay.daletDalet), 'ויאמר אלהים ידוד');
      expect(filter(HolyNameDisplay.hehApostrophe), "ויאמר אלהים ה'");
      expect(filter(HolyNameDisplay.doubleYod), 'ויאמר אלהים יי');
      expect(
        filter(HolyNameDisplay.asIs, substitute: true),
        'ויאמר אלקים יהוה',
      );
      expect(filter(HolyNameDisplay.asIs), _line);
    });

    test('raw — השורה כפי שנשמרה', () {
      expect(
        filterPluginDivineNamesLine(
          _line,
          0,
          _spans,
          PluginDivineNamesDisplay.raw,
        ),
        _line,
      );
    });

    test('שם הוי"ה בלי מופע במסד מוחלף ב-regex; מופע של שורה אחרת לא חל', () {
      expect(
        filterPluginDivineNamesLine(
          _line,
          1,
          _spans,
          _names(HolyNameDisplay.kufKuf, substitute: true),
        ),
        'ויאמר אלהים יקוק',
      );
    });

    test('מחברי המילים של הצורות מוסרים', () {
      final spans =
          (DivineNameSpansBuilder()..add(0, 3, 6, DivineNameKind.shaddai))
              .build();
      final result = filterPluginDivineNamesLine(
        'אל שדי',
        0,
        spans,
        _names(HolyNameDisplay.kufKuf, substitute: true),
      );
      expect(result, 'אל ש-די');
      expect(result, isNot(contains('⁠')));
    });
  });

  test('טקסט נגזר — רק שם הוי"ה מוחלף', () {
    expect(
      filterPluginDivineNamesText(
        _line,
        _names(HolyNameDisplay.kufKuf, substitute: true),
      ),
      'ויאמר אלהים יקוק',
    );
    expect(
      filterPluginDivineNamesText(_line, PluginDivineNamesDisplay.raw),
      _line,
    );
  });

  test('ספר שלם עם פרופיל תצוגה: השמות על השורה הגולמית ואחריהם הפרופיל', () {
    final result = filterPluginBookContent((
      rawText: 'אָמַר אֱלֹהִים\nשׁוּב יהוה',
      spans: (DivineNameSpansBuilder()..add(0, 6, 14, DivineNameKind.elohim))
          .build(),
      names: _names(HolyNameDisplay.daletDalet, substitute: true),
      displayProfile: const TextDisplayProfile(nikud: MarkVisibility.hide),
    ));
    expect(result, 'אמר אלקים\nשוב ידוד');
  });

  group('הגדרת המשתמש נקראת ברגע הקריאה', () {
    test('בלי ספר — השכבה הכללית, ושינוי נכנס לתוקף מיד', () async {
      await _savePolicy(holyName: HolyNameDisplay.asIs);
      expect(
        await PluginDivineNamesFilter.resolve(),
        _names(HolyNameDisplay.asIs),
      );
      await _savePolicy(
        holyName: HolyNameDisplay.daletDalet,
        divineNames: DivineNamesDisplay.substitute,
      );
      expect(
        await PluginDivineNamesFilter.resolve(),
        _names(HolyNameDisplay.daletDalet, substitute: true),
      );
      expect(
        await PluginDivineNamesFilter.resolve(raw: true),
        PluginDivineNamesDisplay.raw,
      );
    });

    test('כרטיסייה פתוחה: המדיניות העדכנית מתחת לעקיפות הכרטיסייה', () async {
      final book = TextBook(title: 'ספר', categoryId: 1);
      final state = TextBookLoaded.initial(
        book: book,
        index: 0,
        showLeftPane: false,
        splitView: false,
      );
      await _savePolicy(holyName: HolyNameDisplay.daletDalet);
      expect(
        await PluginDivineNamesFilter.resolve(book: book, readerState: state),
        _names(HolyNameDisplay.daletDalet),
      );
      await _savePolicy(holyName: HolyNameDisplay.asIs);
      expect(
        await PluginDivineNamesFilter.resolve(book: book, readerState: state),
        _names(HolyNameDisplay.asIs),
      );

      final overridden = state.copyWith(
        displayOverrides: TextDisplayLayer({
          TextDisplaySlot.root: const TextDisplayPatch(
            holyName: HolyNameDisplay.hehApostrophe,
          ),
        }),
      );
      expect(
        await PluginDivineNamesFilter.resolve(
          book: book,
          readerState: overridden,
        ),
        _names(HolyNameDisplay.hehApostrophe),
      );
    });

    test('ספר שאינו פתוח מקבל את שכבת התנ"ך לפי סוגו', () async {
      await _savePolicy(
        holyName: HolyNameDisplay.kufKuf,
        tanachHolyName: HolyNameDisplay.asIs,
      );
      PluginDivineNamesFilter.debugIsTanach = (book) async =>
          book.title == 'בראשית';
      expect(
        await PluginDivineNamesFilter.resolve(book: TextBook(title: 'בראשית')),
        _names(HolyNameDisplay.asIs),
      );
      expect(
        await PluginDivineNamesFilter.resolve(book: TextBook(title: 'רמב"ם')),
        _names(HolyNameDisplay.kufKuf),
      );
    });

    test('בלי שכבת תנ"ך שונה — אין שאילתה על סוג הספר', () async {
      await _savePolicy(holyName: HolyNameDisplay.kufKuf);
      PluginDivineNamesFilter.debugIsTanach = (_) =>
          fail('isTanach should not be queried');
      expect(
        await PluginDivineNamesFilter.resolve(book: TextBook(title: 'בראשית')),
        _names(HolyNameDisplay.kufKuf),
      );
    });
  });

  test('המופעים: של הכרטיסייה כשנטענו, אחרת מהמאגר', () async {
    final repository = DivineNamesRepository.instance;
    final loaded = (DivineNameSpansBuilder()..add(0, 0, 4, DivineNameKind.hvyh))
        .build();
    repository.debugLoader = (title, {categoryId, required source}) async =>
        loaded;
    final book = TextBook(title: 'ספר', categoryId: 3);
    expect(await PluginDivineNamesFilter.spansFor(book), same(loaded));

    final state = TextBookLoaded.initial(
      book: book,
      index: 0,
      showLeftPane: false,
      splitView: false,
    ).copyWith(divineNames: _spans);
    expect(
      await PluginDivineNamesFilter.spansFor(book, readerState: state),
      same(_spans),
    );
  });

  test('toJson מתאר את ההגדרה ואת צורת שם הוי"ה', () {
    expect(_names(HolyNameDisplay.kufKuf, substitute: true).toJson(), {
      'holyName': 'kufKuf',
      'otherNames': 'substitute',
      'filtered': true,
      'holyNameSample': 'יקוק',
    });
    expect(PluginDivineNamesDisplay.raw.toJson(), {
      'holyName': 'asIs',
      'otherNames': 'asIs',
      'filtered': false,
      'holyNameSample': 'יהוה',
    });
    expect(
      _names(HolyNameDisplay.hehApostrophe).toJson()['holyNameSample'],
      "ה'",
    );
  });
}
