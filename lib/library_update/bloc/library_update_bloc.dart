import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:otzaria/core/error_log_file.dart';
import 'package:otzaria/library_update/services/companion_assets_service.dart';
import 'package:seforim_library_updater/seforim_library_updater.dart';

import '../repository/library_update_repository.dart';

part 'library_update_event.dart';
part 'library_update_state.dart';

/// מנהל את תהליך עדכון ספריית הספרים החדש (מחליף את `FileSyncBloc`).
///
/// בודק זמינות עדכון, מחיל מסלול דלתא אוטומטית, ומבקש אישור להורדה מלאה.
/// אינו מפעיל אינדוקס/ריענון ספרייה ישירות — ה-UI מאזין ל-state ומפעיל
/// `RefreshLibrary` + `StartIndexing` כש-[LibraryUpdateState.hasUpdate].
class LibraryUpdateBloc extends Bloc<LibraryUpdateEvent, LibraryUpdateState> {
  final LibraryUpdateService repository;

  /// אימות ועדכון הקבצים הנלווים (תלמוד, קטלוגים, מילון) בסוף כל עדכון.
  /// null (בבדיקות) — מדלגים.
  final CompanionAssetsService? companionAssets;

  /// קוראים את ההגדרות הרלוונטיות — ניתנים להזרקה לבדיקות.
  final bool Function() isOfflineMode;
  final bool Function() areUpdatesEnabled;
  final bool Function() allowPrerelease;

  // מזהה הריצה הפעילה. כל התחלה/ביטול/איפוס מגדילים אותו, כך שריצה ישנה
  // (Future שעדיין לא הסתיים) מזוהה כמבוטלת ולא פולטת state או מחליפה DB.
  int _operationId = 0;

  bool _isStale(int opId) => opId != _operationId;

  LibraryUpdateBloc({
    required this.repository,
    required this.isOfflineMode,
    required this.areUpdatesEnabled,
    required this.allowPrerelease,
    this.companionAssets,
  }) : super(const LibraryUpdateState()) {
    on<StartLibraryUpdate>(_onStart);
    on<ConfirmFullDownload>(_onConfirmFull);
    on<DeclineFullDownload>(_onDeclineFull);
    on<CancelLibraryUpdate>(_onCancel);
    on<ResetLibraryUpdate>(_onReset);
    on<_LibraryUpdateProgressed>(_onProgressed);
  }

  Future<void> _onStart(
    StartLibraryUpdate event,
    Emitter<LibraryUpdateState> emit,
  ) async {
    // מונע עדכון כפול: התעלם מבקשה חדשה כשעדכון כבר רץ (auto + לחיצה ידנית).
    if (state.isBusy) return;
    if (isOfflineMode()) {
      emit(const LibraryUpdateState(message: 'מצב לא מקוון — עדכון מושבת'));
      return;
    }
    if (!areUpdatesEnabled()) {
      emit(const LibraryUpdateState(message: 'עדכוני ספרים מושבתים'));
      return;
    }

    final opId = ++_operationId;
    emit(const LibraryUpdateState(
      status: LibraryUpdateStatus.checking,
      message: 'בודק עדכוני ספרייה',
    ));

    try {
      final plan =
          await repository.checkForUpdate(allowPrerelease: allowPrerelease());
      // אם המשתמש ביטל/התחיל ריצה חדשה במהלך הבדיקה — לא להמשיך.
      if (_isStale(opId)) return;
      switch (plan.kind) {
        case LibraryUpdatePlanKind.none:
          await _runCompanionAssets(emit, opId);
          if (_isStale(opId)) return;
          emit(const LibraryUpdateState(
            status: LibraryUpdateStatus.completed,
            message: 'הספרייה מעודכנת',
            hasUpdate: false,
          ));
        case LibraryUpdatePlanKind.delta:
          await _runDelta(plan, emit, opId);
        case LibraryUpdatePlanKind.fullDownload:
          emit(LibraryUpdateState(
            status: LibraryUpdateStatus.needsFullConfirmation,
            message:
                'נדרשת הורדה מלאה (${_formatSize(plan.totalDownloadSize)})',
            plan: plan,
          ));
        case LibraryUpdatePlanKind.blocked:
          emit(LibraryUpdateState(
            status: LibraryUpdateStatus.blocked,
            message: plan.reason ?? 'העדכון חסום',
            errorMessage: plan.reason,
          ));
      }
    } catch (e, st) {
      // אם בוטל/הוחלף במהלך הבדיקה — לא לדרוס state של ריצה חדשה בשגיאה.
      if (_isStale(opId)) return;
      _logUpdateError('checkForUpdate', e, st);
      emit(LibraryUpdateState(
        status: LibraryUpdateStatus.error,
        message: 'שגיאה בבדיקת עדכונים',
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _runDelta(
    LibraryUpdatePlan plan,
    Emitter<LibraryUpdateState> emit,
    int opId,
  ) async {
    try {
      await repository.applyDeltaPlan(
        plan,
        isCancelled: () => _isStale(opId),
        onProgress: (progress) => add(_LibraryUpdateProgressed(progress, opId)),
      );
      // הגענו לכאן ⇒ ה-apply וה-ריענון הצליחו וה-DB עודכן. אם בוטל/הוחלף
      // בינתיים — לא נדרוס את ה-state של הריצה החדשה (ה-DB כבר רוענן ממילא).
      if (_isStale(opId)) return;
      await _runCompanionAssets(emit, opId);
      if (_isStale(opId)) return;
      emit(state.copyWith(
        status: LibraryUpdateStatus.completed,
        message: 'הספרייה עודכנה לגרסה ${plan.targetVersion}',
        hasUpdate: true,
      ));
    } on PatchDownloadCancelled {
      // ביטול לפני apply — לא שגיאה; _onCancel כבר העביר ל-idle.
    } catch (e, st) {
      if (_isStale(opId)) return;
      _logUpdateError('applyDeltaPlan', e, st);
      emit(LibraryUpdateState(
        status: LibraryUpdateStatus.error,
        message: 'שגיאה בהחלת העדכון',
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onConfirmFull(
    ConfirmFullDownload event,
    Emitter<LibraryUpdateState> emit,
  ) async {
    if (state.isBusy) return; // הורדה כבר רצה — מתעלמים מאישור כפול.
    final plan = state.plan;
    if (plan == null || plan.kind != LibraryUpdatePlanKind.fullDownload) {
      emit(const LibraryUpdateState());
      return;
    }
    final opId = ++_operationId;
    emit(state.copyWith(
      status: LibraryUpdateStatus.downloading,
      message: 'מוריד ספרייה מלאה',
    ));
    try {
      await repository.applyFullDownload(
        plan,
        isCancelled: () => _isStale(opId),
        onProgress: (progress) => add(_LibraryUpdateProgressed(progress, opId)),
      );
      if (_isStale(opId)) return;
      await _runCompanionAssets(emit, opId);
      if (_isStale(opId)) return;
      emit(state.copyWith(
        status: LibraryUpdateStatus.completed,
        message: 'הספרייה הותקנה מחדש לגרסה ${plan.targetVersion}',
        hasUpdate: true,
      ));
    } on PatchDownloadCancelled {
      // ביטול — _onCancel כבר העביר ל-idle.
    } catch (e, st) {
      if (_isStale(opId)) return;
      _logUpdateError('applyFullDownload', e, st);
      emit(LibraryUpdateState(
        status: LibraryUpdateStatus.error,
        message: 'שגיאה בהורדה המלאה',
        errorMessage: e.toString(),
      ));
    }
  }

  /// מוודא שהקבצים הנלווים (תלמוד, קטלוגים, מילון) קיימים ומעודכנים, בסוף
  /// כל בדיקת/החלת עדכון. best-effort — כשל לא הופך את העדכון לשגיאה.
  Future<void> _runCompanionAssets(
    Emitter<LibraryUpdateState> emit,
    int opId,
  ) async {
    final service = companionAssets;
    if (service == null) return;
    try {
      await service.verifyAndUpdate(
        isCancelled: () => _isStale(opId),
        onStatus: (message) {
          if (_isStale(opId)) return;
          emit(state.copyWith(
            status: LibraryUpdateStatus.checking,
            message: message,
          ));
        },
        onDownloadProgress: (received, total) {
          if (_isStale(opId)) return;
          emit(state.copyWith(
            status: LibraryUpdateStatus.downloading,
            bytesDownloaded: received,
            // total לא ידוע ⇒ 0, כדי לא לרשת bytesTotal ישן מהורדת ה-DB.
            bytesTotal: total ?? 0,
          ));
        },
      );
    } catch (e, st) {
      _logUpdateError('companionAssets', e, st);
    }
  }

  void _onDeclineFull(
    DeclineFullDownload event,
    Emitter<LibraryUpdateState> emit,
  ) {
    // המשתמש בחר להישאר עם הגרסה הנוכחית — לא מורידים כלום.
    emit(const LibraryUpdateState(
      status: LibraryUpdateStatus.completed,
      message: 'ממשיך עם הגרסה הנוכחית',
      hasUpdate: false,
    ));
  }

  void _onCancel(
    CancelLibraryUpdate event,
    Emitter<LibraryUpdateState> emit,
  ) {
    // משלב כתיבת ה-DB ואילך ביטול אסור: ה-DB מתעדכן אטומית והריענון כבר בדרך,
    // וביטול כאן היה משאיר קטלוג ואינדקס ישנים עד restart.
    if (!_canCancel(state)) return;
    _operationId++; // מבטל את הריצה הפעילה — ה-Future הישן יזהה זאת.
    emit(const LibraryUpdateState(message: 'העדכון בוטל'));
  }

  /// ביטול אפשרי עד שמתחילים לכתוב ל-DB. בדלתא נקודת האל-חזור היא שלב ה-applying
  /// (החלת ה-patch); בהורדה מלאה רק שלב ה-refreshing — שם ה-applying הוא חילוץ
  /// הארכיב, שעדיין ניתן לבטל לפני ההחלפה האטומית.
  bool _canCancel(LibraryUpdateState state) {
    switch (state.status) {
      case LibraryUpdateStatus.refreshing:
        return false;
      case LibraryUpdateStatus.applying:
        return state.plan?.kind == LibraryUpdatePlanKind.fullDownload;
      default:
        return true;
    }
  }

  void _onReset(
    ResetLibraryUpdate event,
    Emitter<LibraryUpdateState> emit,
  ) {
    _operationId++;
    emit(const LibraryUpdateState());
  }

  void _onProgressed(
    _LibraryUpdateProgressed event,
    Emitter<LibraryUpdateState> emit,
  ) {
    // התקדמות מריצה שבוטלה/הוחלפה — מתעלמים כדי לא לדרוס state חדש.
    if (_isStale(event.opId)) return;
    final p = event.progress;
    // phase=done הוא רגע לפני שה-completed נפלט מ-_runDelta; ה-event מגיע בתור
    // אחרי ה-completed, אז emit כאן ידרוס אותו וה-UI ייתקע ב'מסיים'.
    if (p.phase == LibraryUpdatePhase.done) return;
    final message = switch (p.phase) {
      LibraryUpdatePhase.checking => 'בודק עדכוני ספרייה',
      LibraryUpdatePhase.downloading => 'מוריד עדכון ספרייה'
          '${p.totalSteps > 1 ? ' (${p.stepIndex + 1}/${p.totalSteps})' : ''}',
      LibraryUpdatePhase.verifying => 'מאמת קובץ עדכון',
      LibraryUpdatePhase.applying => _applyStageMessage(p.stage),
      LibraryUpdatePhase.refreshing => 'מרענן ספרייה',
      LibraryUpdatePhase.done => 'מסיים',
    };
    final status = switch (p.phase) {
      LibraryUpdatePhase.downloading => LibraryUpdateStatus.downloading,
      LibraryUpdatePhase.applying => LibraryUpdateStatus.applying,
      LibraryUpdatePhase.refreshing => LibraryUpdateStatus.refreshing,
      _ => LibraryUpdateStatus.checking,
    };
    emit(state.copyWith(
      status: status,
      message: message,
      stepIndex: p.stepIndex,
      totalSteps: p.totalSteps,
      bytesDownloaded: p.bytesDownloaded,
      bytesTotal: p.bytesTotal,
      applyProgress: p.applyProgress,
    ));
  }

  // ממפה את תת-שלבי ה-apply (מ-PatchApplier.onStage) להודעות קריאות למשתמש.
  String _applyStageMessage(String? stage) => switch (stage) {
        'preflight' => 'בודק תאימות גרסה',
        'verifyFromHash' => 'מאמת את הספרייה הנוכחית',
        'attach' => 'מכין את העדכון',
        'migrations' => 'מעדכן מבנה נתונים',
        'upserts' => 'מוסיף ומעדכן רשומות',
        'deletes' => 'מסיר רשומות שהוסרו',
        'verifyToHash' => 'מאמת את הספרייה המעודכנת',
        'commit' => 'שומר שינויים',
        _ => 'מחיל עדכון',
      };

  String _formatSize(int bytes) {
    if (bytes >= 1 << 30) {
      return '${(bytes / (1 << 30)).toStringAsFixed(1)}GB';
    }
    if (bytes >= 1 << 20) {
      return '${(bytes / (1 << 20)).toStringAsFixed(0)}MB';
    }
    return '${(bytes / (1 << 10)).toStringAsFixed(0)}KB';
  }

  // ה-UI מציג שגיאת עדכון גנרית בלבד; שומרים את הפרטים ל-errors.txt לאבחון.
  void _logUpdateError(String stage, Object e, StackTrace st) {
    debugPrint('[LibraryUpdate] ERROR in $stage: $e\n$st');
    try {
      ErrorLogFile.append(
        title: 'Library Update Error ($stage)',
        error: e,
        stackTrace: st,
      );
    } catch (_) {}
  }
}
