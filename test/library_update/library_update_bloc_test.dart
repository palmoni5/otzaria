import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/library_update/bloc/library_update_bloc.dart';
import 'package:otzaria/library_update/repository/library_update_repository.dart';
import 'package:seforim_library_updater/seforim_library_updater.dart';

class _FakeService implements LibraryUpdateService {
  final LibraryUpdatePlan plan;
  final bool throwOnCheck;
  final bool throwOnApply;
  bool applyCalled = false;
  bool fullCalled = false;

  _FakeService(this.plan,
      {this.throwOnCheck = false, this.throwOnApply = false});

  @override
  Future<RecoveryResult> recoverIfNeeded() async =>
      const RecoveryResult(RecoveryAction.none);

  @override
  Future<LibraryUpdatePlan> checkForUpdate(
      {required bool allowPrerelease}) async {
    if (throwOnCheck) throw Exception('check failed');
    return plan;
  }

  @override
  Future<void> applyDeltaPlan(
    LibraryUpdatePlan plan, {
    LibraryUpdateProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    applyCalled = true;
    if (throwOnApply) throw Exception('apply failed');
  }

  @override
  Future<void> applyFullDownload(
    LibraryUpdatePlan plan, {
    LibraryUpdateProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    fullCalled = true;
    if (throwOnApply) throw Exception('full failed');
  }
}

/// שירות שמדווח על שלב applying ואז נחסם — לבדיקת חסימת ביטול אחרי כתיבת DB.
class _GatedAtApplyService implements LibraryUpdateService {
  final LibraryUpdatePlan plan;
  final Completer<void> gate;
  _GatedAtApplyService(this.plan, this.gate);

  @override
  Future<RecoveryResult> recoverIfNeeded() async =>
      const RecoveryResult(RecoveryAction.none);

  @override
  Future<LibraryUpdatePlan> checkForUpdate(
          {required bool allowPrerelease}) async =>
      plan;

  @override
  Future<void> applyDeltaPlan(
    LibraryUpdatePlan plan, {
    LibraryUpdateProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    onProgress
        ?.call(const LibraryUpdateProgress(phase: LibraryUpdatePhase.applying));
    await gate
        .future; // מדמה apply ארוך; אחריו ה-DB עודכן — מתעלמים מ-isCancelled
  }

  @override
  Future<void> applyFullDownload(
    LibraryUpdatePlan plan, {
    LibraryUpdateProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {}
}

/// שירות שמדמה רצף apply אמיתי: מדידת אימות ואז תת-שלב בלי מדידה — לבדיקת
/// ניקוי applyProgress שאריתי.
class _VerifyThenCommitService implements LibraryUpdateService {
  final LibraryUpdatePlan plan;
  _VerifyThenCommitService(this.plan);

  @override
  Future<RecoveryResult> recoverIfNeeded() async =>
      const RecoveryResult(RecoveryAction.none);

  @override
  Future<LibraryUpdatePlan> checkForUpdate(
          {required bool allowPrerelease}) async =>
      plan;

  @override
  Future<void> applyDeltaPlan(
    LibraryUpdatePlan plan, {
    LibraryUpdateProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    onProgress?.call(const LibraryUpdateProgress(
      phase: LibraryUpdatePhase.applying,
      stage: 'verifyToHash',
      applyProgress: 0.5,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    onProgress?.call(const LibraryUpdateProgress(
      phase: LibraryUpdatePhase.applying,
      stage: 'commit',
    ));
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }

  @override
  Future<void> applyFullDownload(
    LibraryUpdatePlan plan, {
    LibraryUpdateProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {}
}

/// שירות שבו applyDeltaPlan נחסם עד שמשחררים את ה-gate — לבדיקת race של ביטול.
class _GatedService implements LibraryUpdateService {
  final LibraryUpdatePlan plan;
  final Completer<void> gate;
  _GatedService(this.plan, this.gate);

  @override
  Future<RecoveryResult> recoverIfNeeded() async =>
      const RecoveryResult(RecoveryAction.none);

  @override
  Future<LibraryUpdatePlan> checkForUpdate(
          {required bool allowPrerelease}) async =>
      plan;

  @override
  Future<void> applyDeltaPlan(
    LibraryUpdatePlan plan, {
    LibraryUpdateProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    await gate.future; // נחסם עד שהבדיקה משחררת
  }

  @override
  Future<void> applyFullDownload(
    LibraryUpdatePlan plan, {
    LibraryUpdateProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {}
}

LibraryUpdateBloc _bloc(
  LibraryUpdateService service, {
  bool offline = false,
  bool updatesEnabled = true,
  bool prerelease = false,
}) =>
    LibraryUpdateBloc(
      repository: service,
      isOfflineMode: () => offline,
      areUpdatesEnabled: () => updatesEnabled,
      allowPrerelease: () => prerelease,
    );

void main() {
  final nonePlan = LibraryUpdatePlan.none(localVersion: 3, targetVersion: 3);
  final deltaPlan = LibraryUpdatePlan.delta(
      localVersion: 1, targetVersion: 3, steps: const []);
  final fullPlan = LibraryUpdatePlan.fullDownload(
    localVersion: 1,
    targetVersion: 3,
    asset: const ReleaseAsset(
        name: 'seforim.db.zst', downloadUrl: 'https://x', size: 1200000000),
    releaseTag: 'v3',
  );
  final blockedPlan = LibraryUpdatePlan.blocked(
      localVersion: 1, targetVersion: 3, reason: 'schema לא תואם');

  group('LibraryUpdateBloc', () {
    blocTest<LibraryUpdateBloc, LibraryUpdateState>(
      'מצב לא מקוון → idle עם הודעה, לא בודק',
      build: () => _bloc(_FakeService(nonePlan), offline: true),
      act: (b) => b.add(const StartLibraryUpdate()),
      expect: () => [
        isA<LibraryUpdateState>()
            .having((s) => s.status, 'status', LibraryUpdateStatus.idle)
      ],
    );

    blocTest<LibraryUpdateBloc, LibraryUpdateState>(
      'עדכונים מושבתים → idle',
      build: () => _bloc(_FakeService(nonePlan), updatesEnabled: false),
      act: (b) => b.add(const StartLibraryUpdate()),
      expect: () => [
        isA<LibraryUpdateState>()
            .having((s) => s.status, 'status', LibraryUpdateStatus.idle)
      ],
    );

    blocTest<LibraryUpdateBloc, LibraryUpdateState>(
      'plan none → completed בלי hasUpdate',
      build: () => _bloc(_FakeService(nonePlan)),
      act: (b) => b.add(const StartLibraryUpdate()),
      expect: () => [
        isA<LibraryUpdateState>()
            .having((s) => s.status, 'status', LibraryUpdateStatus.checking),
        isA<LibraryUpdateState>()
            .having((s) => s.status, 'status', LibraryUpdateStatus.completed)
            .having((s) => s.hasUpdate, 'hasUpdate', false),
      ],
    );

    blocTest<LibraryUpdateBloc, LibraryUpdateState>(
      'plan delta → מבצע apply ומסיים עם hasUpdate',
      build: () => _bloc(_FakeService(deltaPlan)),
      act: (b) => b.add(const StartLibraryUpdate()),
      verify: (b) => expect((b.repository as _FakeService).applyCalled, isTrue),
      expect: () => [
        isA<LibraryUpdateState>()
            .having((s) => s.status, 'status', LibraryUpdateStatus.checking),
        isA<LibraryUpdateState>()
            .having((s) => s.status, 'status', LibraryUpdateStatus.completed)
            .having((s) => s.hasUpdate, 'hasUpdate', true),
      ],
    );

    blocTest<LibraryUpdateBloc, LibraryUpdateState>(
      'plan fullDownload → needsFullConfirmation עם plan',
      build: () => _bloc(_FakeService(fullPlan)),
      act: (b) => b.add(const StartLibraryUpdate()),
      verify: (b) =>
          expect((b.repository as _FakeService).applyCalled, isFalse),
      expect: () => [
        isA<LibraryUpdateState>()
            .having((s) => s.status, 'status', LibraryUpdateStatus.checking),
        isA<LibraryUpdateState>()
            .having((s) => s.status, 'status',
                LibraryUpdateStatus.needsFullConfirmation)
            .having((s) => s.plan, 'plan', isNotNull),
      ],
    );

    blocTest<LibraryUpdateBloc, LibraryUpdateState>(
      'plan blocked → blocked',
      build: () => _bloc(_FakeService(blockedPlan)),
      act: (b) => b.add(const StartLibraryUpdate()),
      expect: () => [
        isA<LibraryUpdateState>()
            .having((s) => s.status, 'status', LibraryUpdateStatus.checking),
        isA<LibraryUpdateState>()
            .having((s) => s.status, 'status', LibraryUpdateStatus.blocked),
      ],
    );

    blocTest<LibraryUpdateBloc, LibraryUpdateState>(
      'שגיאה בבדיקה → error',
      build: () => _bloc(_FakeService(nonePlan, throwOnCheck: true)),
      act: (b) => b.add(const StartLibraryUpdate()),
      expect: () => [
        isA<LibraryUpdateState>()
            .having((s) => s.status, 'status', LibraryUpdateStatus.checking),
        isA<LibraryUpdateState>()
            .having((s) => s.status, 'status', LibraryUpdateStatus.error),
      ],
    );

    blocTest<LibraryUpdateBloc, LibraryUpdateState>(
      'שגיאה ב-apply → error',
      build: () => _bloc(_FakeService(deltaPlan, throwOnApply: true)),
      act: (b) => b.add(const StartLibraryUpdate()),
      expect: () => [
        isA<LibraryUpdateState>()
            .having((s) => s.status, 'status', LibraryUpdateStatus.checking),
        isA<LibraryUpdateState>()
            .having((s) => s.status, 'status', LibraryUpdateStatus.error),
      ],
    );

    blocTest<LibraryUpdateBloc, LibraryUpdateState>(
      'ConfirmFullDownload → מבצע הורדה מלאה ומסיים עם hasUpdate',
      build: () => _bloc(_FakeService(fullPlan)),
      seed: () => LibraryUpdateState(
          status: LibraryUpdateStatus.needsFullConfirmation, plan: fullPlan),
      act: (b) => b.add(const ConfirmFullDownload()),
      verify: (b) => expect((b.repository as _FakeService).fullCalled, isTrue),
      expect: () => [
        isA<LibraryUpdateState>()
            .having((s) => s.status, 'status', LibraryUpdateStatus.downloading),
        isA<LibraryUpdateState>()
            .having((s) => s.status, 'status', LibraryUpdateStatus.completed)
            .having((s) => s.hasUpdate, 'hasUpdate', true),
      ],
    );

    test('ביטול במהלך עדכון → ריצה ישנה לא פולטת completed (operation token)',
        () async {
      final gate = Completer<void>();
      final bloc = _bloc(_GatedService(deltaPlan, gate));
      final seen = <LibraryUpdateStatus>[];
      final sub = bloc.stream.listen((s) => seen.add(s.status));

      bloc.add(const StartLibraryUpdate());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // הריצה תקועה ב-applyDeltaPlan (gate). מבטלים ומתחילים מחדש מושגית.
      bloc.add(const CancelLibraryUpdate());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.status, LibraryUpdateStatus.idle);

      gate.complete(); // הריצה הישנה ממשיכה — אך opId כבר התיישן
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(seen.contains(LibraryUpdateStatus.completed), isFalse,
          reason: 'ריצה שבוטלה לא אמורה לפלוט completed');
      expect(bloc.state.status, LibraryUpdateStatus.idle);
      await sub.cancel();
      await bloc.close();
    });

    test('ביטול בשלב applying (דלתא) נחסם — ה-DB עודכן ולכן פולט completed',
        () async {
      final gate = Completer<void>();
      final bloc = _bloc(_GatedAtApplyService(deltaPlan, gate));
      final seen = <LibraryUpdateStatus>[];
      final sub = bloc.stream.listen((s) => seen.add(s.status));

      bloc.add(const StartLibraryUpdate());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.status, LibraryUpdateStatus.applying);

      // ניסיון ביטול אחרי שהחלה ל-DB התחילה — חייב להיחסם.
      bloc.add(const CancelLibraryUpdate());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.status, LibraryUpdateStatus.applying,
          reason: 'ביטול בשלב applying אמור להיחסם');

      gate.complete(); // ה-apply מסתיים, ה-DB עודכן
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(bloc.state.status, LibraryUpdateStatus.completed);
      expect(bloc.state.hasUpdate, isTrue,
          reason: 'עדכון שהושלם חייב להפעיל ריענון ספרייה/אינדוקס');
      expect(seen.contains(LibraryUpdateStatus.idle), isFalse,
          reason: 'ביטול שנחסם לא אמור להחזיר ל-idle');
      await sub.cancel();
      await bloc.close();
    });

    test('אירוע stage בלי מדידה מנקה applyProgress שאריתי מהאימות', () async {
      final bloc = _bloc(_VerifyThenCommitService(deltaPlan));
      final seen = <LibraryUpdateState>[];
      final sub = bloc.stream.listen(seen.add);

      bloc.add(const StartLibraryUpdate());
      await Future<void>.delayed(const Duration(milliseconds: 60));

      final applying =
          seen.where((s) => s.status == LibraryUpdateStatus.applying).toList();
      expect(applying, hasLength(2));
      expect(applying[0].applyProgress, 0.5);
      expect(applying[1].applyProgress, isNull,
          reason: 'commit ללא מדידה חייב לנקות את אחוז האימות הקודם, '
              'אחרת המד מציג ערך שאריתי');
      await sub.cancel();
      await bloc.close();
    });

    blocTest<LibraryUpdateBloc, LibraryUpdateState>(
      'StartLibraryUpdate בזמן busy → מתעלם (guard נגד עדכון כפול)',
      build: () => _bloc(_FakeService(deltaPlan)),
      seed: () =>
          const LibraryUpdateState(status: LibraryUpdateStatus.checking),
      act: (b) => b.add(const StartLibraryUpdate()),
      verify: (b) =>
          expect((b.repository as _FakeService).applyCalled, isFalse),
      expect: () => const <LibraryUpdateState>[],
    );

    blocTest<LibraryUpdateBloc, LibraryUpdateState>(
      'DeclineFullDownload → ממשיך עם הנוכחי, בלי הורדה',
      build: () => _bloc(_FakeService(fullPlan)),
      seed: () => LibraryUpdateState(
          status: LibraryUpdateStatus.needsFullConfirmation, plan: fullPlan),
      act: (b) => b.add(const DeclineFullDownload()),
      verify: (b) => expect((b.repository as _FakeService).fullCalled, isFalse),
      expect: () => [
        isA<LibraryUpdateState>()
            .having((s) => s.status, 'status', LibraryUpdateStatus.completed)
            .having((s) => s.hasUpdate, 'hasUpdate', false),
      ],
    );
  });
}
