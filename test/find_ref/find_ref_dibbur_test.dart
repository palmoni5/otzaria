import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:otzaria/data/repository/data_repository.dart';
import 'package:otzaria/find_ref/repository/find_ref_repository.dart';
import 'package:otzaria/find_ref/repository/reference_books_cache.dart';

class MockDataRepository extends Mock implements DataRepository {}

/// איתור דיבור-מתחיל: "תוספות ברכות ד"ה מאימתי" (issue #1415).
void main() {
  /// דיבורי-המתחיל המדומים: bookId → dhText מנורמל → (שורה, תצוגה).
  const dibburimByBook = {
    1927: {
      'מאימתי קורין וכו': (3, 'מאימתי קורין וכו\''),
      'ואמר רבי יוחנן': (40, 'ואמר רבי יוחנן'),
    },
    2151: {
      'מאימתי קורין את שמע': (7, 'מאימתי קורין את שמע'),
    },
  };

  final titles = {
    1927: 'תוספות על ברכות',
    2151: 'תוספות הרא"ש על ברכות',
    70: 'ברכות',
  };

  late List<({List<int> bookIds, String prefix, List<int> containsBookIds})>
  lookups;

  FindRefRepository buildRepo({bool withDibburim = true}) {
    lookups = [];
    return FindRefRepository(
      dataRepository: MockDataRepository(),
      isReferenceBooksCacheLoaded: () => true,
      warmUpReferenceBooksCache: () async {},
      searchReferenceBooks: (query, {int limit = 50}) => [
        for (final entry in titles.entries)
          if (entry.value.contains(query))
            ReferenceBookHit(
              bookId: entry.key,
              title: entry.value,
              normalizedTitle: entry.value.replaceAll('"', ''),
              filePath: '',
              fileType: 'txt',
              matchRank: entry.value.startsWith(query) ? 0 : 2,
              matchedTerm: query,
              orderIndex: entry.key.toDouble(),
            ),
      ],
      getTocEntriesForReference: (bookId, bookTitle, {queryTokens}) async =>
          const [],
      resolveDibburim: !withDibburim
          ? null
          : (bookIds, prefix, {containsBookIds = const []}) async {
              lookups.add((
                bookIds: bookIds,
                prefix: prefix,
                containsBookIds: containsBookIds,
              ));
              return [
                for (final bookId in bookIds)
                  for (final dibbur
                      in (dibburimByBook[bookId] ?? const {}).entries)
                    if (dibbur.key.startsWith(prefix))
                      {
                        'bookId': bookId,
                        'lineIndex': dibbur.value.$1,
                        'lineId': 10000 + dibbur.value.$1,
                        'display': dibbur.value.$2,
                      },
              ];
            },
    );
  }

  test('"תוספות ברכות ד"ה מאימתי" מגיע לשורת הדיבור', () async {
    final results = await buildRepo().findRefs('תוספות ברכות ד"ה מאימתי');

    expect(results.first.isSourceLine, isTrue);
    expect(results.first.segment, 3);
    expect(results.first.sourceLineId, 10003);
    expect(results.first.title, 'תוספות על ברכות');
    expect(results.first.reference, 'תוספות על ברכות ד"ה מאימתי קורין וכו\'');
  });

  test('הדיבור מדורג מעל תוצאת הספר עצמו', () async {
    final results = await buildRepo().findRefs('תוספות ברכות ד"ה מאימתי');

    final bookOnly = results.indexWhere((r) => !r.isSourceLine);
    expect(bookOnly, greaterThan(0));
  });

  test('אותו דיבור נמצא בכל ספר מועמד', () async {
    final results = await buildRepo().findRefs('תוספות ברכות ד"ה מאימתי');
    final segments = {
      for (final r in results)
        if (r.isSourceLine) (r.bookId, r.segment),
    };

    expect(segments, containsAll([(1927, 3), (2151, 7)]));
  });

  test('שאילתה מאוגדת אחת לכל הספרים המועמדים', () async {
    final repo = buildRepo();
    await repo.findRefs('תוספות ברכות ד"ה מאימתי');

    expect(lookups, hasLength(1));
    expect(lookups.single.prefix, 'מאימתי');
    expect(lookups.single.bookIds.length, greaterThan(1));
    expect(
      lookups.single.containsBookIds.length,
      lessThanOrEqualTo(lookups.single.bookIds.length),
    );
  });

  test('שם ספר לבד אחרי הסמן ("ברכות ד"ה") אינו שאילתת דיבור', () async {
    final repo = buildRepo();
    await repo.findRefs('ברכות ד"ה');

    expect(lookups, isEmpty);
  });

  test('בלי סמן ד"ה לא נעשית שאילתת דיבורים', () async {
    final repo = buildRepo();
    await repo.findRefs('תוספות ברכות מאימתי');

    expect(lookups, isEmpty);
  });

  test('מסד בלי הטבלה מחזיר את הספר בלבד, בלי לשבור את האיתור', () async {
    final results = await buildRepo(
      withDibburim: false,
    ).findRefs('תוספות ברכות ד"ה מאימתי');

    expect(results, isNotEmpty);
    expect(results.every((r) => !r.isSourceLine), isTrue);
  });

  group('זיהוי הסמן', () {
    ({List<String> headTokens, String prefix})? detect(String tokens) =>
        FindRefRepository.detectDibburQueryForTesting(tokens.split(' '));

    test('ד"ה אחרי נרמול הגרשיים', () {
      expect(detect('ברכות דה מאימתי')?.prefix, 'מאימתי');
      expect(detect('ברכות דה מאימתי')?.headTokens, ['ברכות']);
    });

    test('"דיבור המתחיל" ו"דבור המתחיל"', () {
      expect(detect('ברכות דיבור המתחיל מאימתי')?.prefix, 'מאימתי');
      expect(detect('ברכות דבור המתחיל מאימתי')?.prefix, 'מאימתי');
      expect(detect('ברכות דבור המתחיל מאימתי')?.headTokens, ['ברכות']);
    });

    test('ציון פנימי נשאר בראש השאילתה', () {
      final detected = detect('תוספות ברכות ב דה מאימתי');
      expect(detected?.headTokens, ['תוספות', 'ברכות', 'ב']);
      expect(detected?.prefix, 'מאימתי');
    });

    test('כמה מילים בדיבור', () {
      expect(detect('ברכות דה מאימתי קורין')?.prefix, 'מאימתי קורין');
    });

    test('סמן בלי טקסט אחריו, או בלי שם ספר לפניו', () {
      expect(detect('ברכות דה'), isNull);
      expect(detect('דה מאימתי'), isNull);
    });

    test('שאילתה רגילה אינה מזוהה כדיבור', () {
      expect(detect('ישעיהו לב יא'), isNull);
    });
  });
}
