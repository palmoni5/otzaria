import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/book_common/selection/commentary_selection.dart';
import 'package:otzaria/book_protection/models/book_protection.dart';
import 'package:otzaria/models/book_source.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/models/links.dart';
import 'package:otzaria/plugins/models/plugin_context_menu_item.dart';
import 'package:otzaria/book_common/utils/commentary_plugin_menu_entries.dart';
import 'package:otzaria/settings/engine/app_settings_store.dart';
import 'package:otzaria/widgets/misc/app_popup_menu.dart';

import '../../helpers/memory_settings_cache.dart';

void main() {
  // הטקסט בלחיצה עובר את הגדרת שמות הקודש של המשתמש.
  setUpAll(() => Settings.init(cacheProvider: MemorySettingsCache()));

  final CommentaryMainBook mainBook = (
    book: TextBook(title: 'בראשית', id: 7),
    currentRef: 'בראשית א, א',
    sectionIndex: 0,
    pageNumber: null,
  );

  final target = (
    book: TextBook(title: 'רש"י על בראשית', id: 42),
    sectionIndex: 3,
    currentRef: 'רש"י על בראשית א, א',
  );

  const save = {
    'type': 'storage.set',
    'args': {
      'key': 'last',
      'value': {r'$selection': 'selectedText'},
    },
  };

  const items = [
    ('legacy', PluginContextMenuItem(id: 'legacy', label: 'על הטקסט')),
    (
      'plugin',
      PluginContextMenuItem(
        id: 'search',
        label: 'חפש',
        contexts: ['reader-commentary-selection'],
        action: save,
      ),
    ),
    (
      'plugin',
      PluginContextMenuItem(
        id: 'locate',
        label: 'אתר',
        contexts: ['reader-commentary'],
        action: save,
      ),
    ),
  ];

  test('המפרש הוא הספר הנוכחי, והספר הנקרא נמסר ב-mainBook', () {
    final payload = buildCommentaryPluginPayload(
      target: target,
      mainBook: mainBook,
      selectedText: 'בראשית',
    );
    expect(payload['id'], 42);
    expect(payload['bookId'], 'רש"י על בראשית');
    expect(payload['currentBook'], 'רש"י על בראשית');
    expect(payload['bookUid'], isNotEmpty);
    expect(payload['sectionIndex'], 3);
    expect(payload['currentIndex'], 3);
    expect(payload['currentRef'], 'רש"י על בראשית א, א');
    expect(payload['text'], 'בראשית');
    expect(payload['start'], isNull);
    expect(payload.containsKey('sourceRange'), isFalse);
    final main = payload['mainBook'] as Map<String, dynamic>;
    expect(main['id'], 7);
    expect(main['bookTitle'], 'בראשית');
    expect(main['currentRef'], 'בראשית א, א');
    expect(main['sectionIndex'], 0);
  });

  test('בלי id של המפרש אין bookUid, ובלי שורה ראשית אין sectionIndex', () {
    final payload = buildCommentaryPluginPayload(
      target: (
        book: TextBook(title: 'מפרש'),
        sectionIndex: 0,
        currentRef: null,
      ),
      mainBook: (
        book: TextBook(title: 'בראשית', id: 7),
        currentRef: null,
        sectionIndex: null,
        pageNumber: null,
      ),
    );
    expect(payload.containsKey('bookUid'), isFalse);
    expect((payload['mainBook'] as Map).containsKey('sectionIndex'), isFalse);
    expect((payload['mainBook'] as Map).containsKey('pageNumber'), isFalse);
  });

  test('פריט ברשימת המפרשים ממופה לשורות מבוססות-0 בשני הספרים', () {
    final target = commentaryTargetForLink(
      Link(
        heRef: 'רש"י על בראשית, ב, ד',
        index1: 5,
        path2: 'רש"י על בראשית.txt',
        index2: 12,
        connectionType: 'commentary',
        targetBookId: 42,
        targetCategoryId: 3,
        targetSource: BookSource.official,
      ),
    );
    expect(target.book.title, 'רש"י על בראשית');
    expect(target.book.id, 42);
    expect(target.sectionIndex, 11);
    expect(target.currentRef, contains('רש"י על בראשית'));
  });

  test('ספר נקרא מסוג PDF נמסר עם מספר העמוד', () {
    final payload = buildCommentaryPluginPayload(
      target: target,
      mainBook: (
        book: PdfBook(title: 'ברכות', path: r'C:\ספרים\ברכות.pdf'),
        currentRef: 'ברכות, דף ב.',
        sectionIndex: 5,
        pageNumber: 5,
      ),
    );
    final main = payload['mainBook'] as Map<String, dynamic>;
    expect(main['type'], 'pdf');
    expect(main['pageNumber'], 5);
    expect(main['sectionIndex'], 5);
    expect(payload['currentIndex'], 3);
  });

  group('limitCommentarySelection', () {
    const protectedBook = BookProtection(level: 1);
    final max = BookProtection.copySegmentLimit;

    test('ספר לא מוגן — הטקסט נשאר שלם', () {
      const guard = (protection: BookProtection.none, segmentCount: 100);
      expect(limitCommentarySelection(guard, 'א\nב'), 'א\nב');
    });

    test('בחירה עם מעברי שורה נחתכת למגבלה', () {
      final lines = [for (var i = 0; i < max + 5; i++) 'שורה $i'];
      final CommentaryCopyGuard guard = (
        protection: protectedBook,
        segmentCount: lines.length,
      );
      final limited = limitCommentarySelection(guard, lines.join('\n'));
      expect(limited.split('\n'), hasLength(max));
    });

    test('בחירה שטוחה מעבר למגבלה אינה נמסרת כלל', () {
      final CommentaryCopyGuard guard = (
        protection: protectedBook,
        segmentCount: max + 1,
      );
      expect(limitCommentarySelection(guard, 'טקסט ארוך בלי מעברי שורה'), '');
    });
  });

  group('buildCommentaryPluginMenuEntries', () {
    late BuildContext menuContext;

    Future<List<AppContextMenuEntry>> entries(
      WidgetTester tester, {
      String? selectedText,
      Future<CommentaryCopyGuard> Function()? copyGuard,
      List<Map<String, dynamic>>? clicks,
      List<(String, PluginContextMenuItem)> records = items,
    }) async {
      await tester.pumpWidget(
        Builder(
          builder: (c) {
            menuContext = c;
            return const SizedBox();
          },
        ),
      );
      return buildCommentaryPluginMenuEntries(
        target: target,
        mainBook: mainBook,
        selectedText: selectedText,
        copyGuard:
            copyGuard ??
            () async => (protection: BookProtection.none, segmentCount: 1),
        menuContext: menuContext,
        records: records,
        selectionActionDispatcher: (pluginId, action, payload) async =>
            clicks?.add(payload),
      );
    }

    List<String> labels(List<AppContextMenuEntry> entries) => [
      for (final e in entries) e.isDivider ? '---' : e.label!,
    ];

    Future<void> click(WidgetTester tester, AppContextMenuEntry entry) =>
        tester.runAsync(() async {
          entry.onTap!();
          await Future<void>.delayed(Duration.zero);
        });

    testWidgets('סימון מציג את פריטי reader-commentary-selection בלבד', (
      tester,
    ) async {
      expect(labels(await entries(tester, selectedText: 'ברא')), [
        '---',
        'חפש',
      ]);
    });

    testWidgets('בלי סימון מוצגים פריטי reader-commentary', (tester) async {
      expect(labels(await entries(tester)), ['---', 'אתר']);
      expect(labels(await entries(tester, selectedText: '  ')), ['---', 'אתר']);
    });

    testWidgets('פריט בלי contexts אינו מופיע במפרשים', (tester) async {
      expect(
        await entries(tester, selectedText: 'ברא', records: [items.first]),
        isEmpty,
      );
    });

    testWidgets('הלחיצה מוסרת את הטקסט ואת זהות המפרש', (tester) async {
      final clicks = <Map<String, dynamic>>[];
      final menu = await entries(tester, selectedText: 'ברא', clicks: clicks);
      await click(tester, menu.last);
      expect(clicks.single['selectedText'], 'ברא');
      expect(clicks.single['currentBook'], 'רש"י על בראשית');
      expect(clicks.single['currentIndex'], 3);
      expect(clicks.single['id'], 42);
    });

    testWidgets('בספר מוגן הטקסט נחתך למגבלת ההעתקה בזמן הלחיצה', (
      tester,
    ) async {
      final clicks = <Map<String, dynamic>>[];
      final lines = [for (var i = 0; i < 45; i++) 'שורה $i'];
      final menu = await entries(
        tester,
        selectedText: lines.join('\n'),
        copyGuard: () async =>
            (protection: const BookProtection(level: 1), segmentCount: 45),
        clicks: clicks,
      );
      await click(tester, menu.last);
      final sent = clicks.single['selectedText'] as String;
      expect(sent.split('\n'), hasLength(BookProtection.copySegmentLimit));
    });

    testWidgets('כשל בקריאת ההגבלה שולח את הלחיצה בלי טקסט', (tester) async {
      final clicks = <Map<String, dynamic>>[];
      final menu = await entries(
        tester,
        selectedText: 'ברא',
        copyGuard: () async => throw StateError('db closed'),
        clicks: clicks,
      );
      await click(tester, menu.last);
      expect(clicks.single['selectedText'], isEmpty);
      expect(clicks.single['currentBook'], 'רש"י על בראשית');
    });
  });
}
