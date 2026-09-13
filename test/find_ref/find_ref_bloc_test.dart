import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/find_ref/bloc/find_ref_bloc.dart';
import 'package:otzaria/find_ref/bloc/find_ref_event.dart';
import 'package:otzaria/find_ref/bloc/find_ref_state.dart';
import 'package:otzaria/find_ref/repository/db_reference_result.dart';
import 'package:otzaria/find_ref/repository/find_ref_db_isolate.dart';
import 'package:otzaria/find_ref/repository/find_ref_repository.dart';

// ─── Fake repository ──────────────────────────────────────────────────────────
// implements (לא extends) — אין צורך ב-DataRepository, BLoC קורא רק findRefs

Future<List<DbReferenceResult>> _emptyFindRefs(String _) async => const [];

class _FakeRepository implements FindRefRepository {
  final Future<List<DbReferenceResult>> Function(String) _fn;
  final Exception? _error;

  _FakeRepository({
    Future<List<DbReferenceResult>> Function(String)? fn,
    this._error,
  }) : _fn = fn ?? _emptyFindRefs;

  @override
  Future<List<DbReferenceResult>> findRefs(
    String ref, {
    bool includePersonalBooks = false,
  }) async {
    if (_error != null) throw _error;
    return _fn(ref);
  }

  @override
  void dispose() {}

  @override
  void cancelPendingSearch() {}

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

DbReferenceResult _result({
  String title = 'בראשית',
  String ref = 'בראשית פרק א',
}) => DbReferenceResult(title: title, reference: ref, segment: 1);

FindRefBloc _bloc({
  Future<List<DbReferenceResult>> Function(String)? fn,
  Exception? error,
}) => FindRefBloc(
  findRefRepository: _FakeRepository(fn: fn, error: error),
);

// ─── Tests ────────────────────────────────────────────────────────────────────

// השהיה שמספיקה בנדיבות כדי לעבור את ה-debounce של 250ms בתוך ה-handler.
const _kPastDebounce = Duration(milliseconds: 400);

/// שני מחזורי debounce — למסלול שמריץ ניסיון חוזר אחרי ביטול זר.
const _kTwoDebounces = Duration(milliseconds: 900);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FindRefBloc — זרימת חיפוש', () {
    blocTest<FindRefBloc, FindRefState>(
      'טקסט קצר מדי (תו אחד) מחזיר FindRefSuccess ריק ללא Loading',
      build: _bloc,
      act: (b) => b.add(const SearchRefRequested('א')),
      expect: () => [
        isA<FindRefSuccess>().having((s) => s.refs, 'refs', isEmpty),
      ],
    );

    blocTest<FindRefBloc, FindRefState>(
      'שני תווים — גבול התחתון של החיפוש האמיתי — עובר Loading ואז Success',
      build: () => _bloc(fn: (_) async => [_result()]),
      act: (b) => b.add(const SearchRefRequested('בר')),
      wait: _kPastDebounce,
      expect: () => [
        isA<FindRefLoading>(),
        isA<FindRefSuccess>().having((s) => s.refs, 'refs', hasLength(1)),
      ],
    );

    blocTest<FindRefBloc, FindRefState>(
      'חיפוש תקין מחזיר Loading לפני Success עם תוצאות',
      build: () => _bloc(fn: (_) async => [_result(), _result(title: 'שמות')]),
      act: (b) => b.add(const SearchRefRequested('בראשית')),
      wait: _kPastDebounce,
      expect: () => [
        isA<FindRefLoading>(),
        isA<FindRefSuccess>().having((s) => s.refs, 'refs', hasLength(2)),
      ],
    );

    blocTest<FindRefBloc, FindRefState>(
      'שגיאה במאגר מחזירה FindRefError אחרי Loading',
      build: () => _bloc(error: Exception('DB error')),
      act: (b) => b.add(const SearchRefRequested('בראשית')),
      wait: _kPastDebounce,
      expect: () => [
        isA<FindRefLoading>(),
        isA<FindRefError>().having(
          (s) => s.message,
          'message',
          contains('DB error'),
        ),
      ],
    );
  });

  group('FindRefBloc — ביטול זר (לא מהקלדה חדשה)', () {
    blocTest<FindRefBloc, FindRefState>(
      'ביטול בלי בקשה חדשה אחריו מריץ ניסיון חוזר ולא נתקע ב-Loading',
      build: () {
        var calls = 0;
        return _bloc(
          fn: (_) async {
            if (calls++ == 0) throw const FindRefQueryCancelled();
            return [_result()];
          },
        );
      },
      act: (b) => b.add(const SearchRefRequested('בראשית')),
      wait: _kTwoDebounces,
      // ה-Loading השני זהה לראשון ולכן bloc אינו פולט אותו שוב.
      expect: () => [
        isA<FindRefLoading>(),
        isA<FindRefSuccess>().having((s) => s.refs, 'refs', hasLength(1)),
      ],
    );

    blocTest<FindRefBloc, FindRefState>(
      'ביטול חוזר על אותה שאילתה נעצר בשגיאה ולא בלולאת ניסיונות',
      build: () => _bloc(error: const FindRefQueryCancelled()),
      act: (b) => b.add(const SearchRefRequested('בראשית')),
      wait: _kTwoDebounces,
      expect: () => [isA<FindRefLoading>(), isA<FindRefError>()],
    );
  });

  group('FindRefBloc — ניקוי', () {
    blocTest<FindRefBloc, FindRefState>(
      'ClearSearchRequested מחזיר ל-FindRefInitial',
      build: _bloc,
      seed: () => FindRefSuccess([_result()]),
      act: (b) => b.add(ClearSearchRequested()),
      expect: () => [isA<FindRefInitial>()],
    );

    blocTest<FindRefBloc, FindRefState>(
      'חיפוש אחרי ניקוי עובד — FindRefInitial לא חוסם חיפושים עתידיים',
      build: () => _bloc(fn: (_) async => [_result()]),
      act: (b) async {
        b.add(ClearSearchRequested());
        await Future.delayed(Duration.zero);
        b.add(const SearchRefRequested('בראשית'));
      },
      wait: _kPastDebounce,
      expect: () => [
        isA<FindRefInitial>(),
        isA<FindRefLoading>(),
        isA<FindRefSuccess>().having((s) => s.refs, 'refs', hasLength(1)),
      ],
    );
  });
}
