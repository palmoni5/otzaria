import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/window_persistence.dart';
import 'package:otzaria/core/windowing/app_window_controller.dart';
import 'package:otzaria/core/windowing/app_window_id.dart';
import 'package:window_manager/window_manager.dart' show TitleBarStyle;

void main() {
  // מסך ראשי 1920x1080 ומסך משני משמאלו, בפיקסלים פיזיים.
  const primary = Rect.fromLTWH(0, 0, 1920, 1040);
  const secondary = Rect.fromLTWH(-1920, 0, 1920, 1040);
  const strip = 32.0;

  bool reachable(Rect bounds, List<Rect> displays, {double extent = strip}) =>
      WindowPersistence.titleStripReachableOnAnyDisplay(
        bounds,
        displays,
        extent,
      );

  group('WindowPersistence.titleStripReachableOnAnyDisplay', () {
    test('חלון בתוך המסך הראשי — נגיש', () {
      const bounds = Rect.fromLTWH(100, 100, 1280, 720);
      expect(reachable(bounds, [primary]), isTrue);
    });

    test('גבולות חניה של חלון ממוזער (-32000) — לא נגישים', () {
      const bounds = Rect.fromLTWH(-32000, -32000, 420, 400);
      expect(reachable(bounds, [primary, secondary]), isFalse);
    });

    test('חלון על מסך משני שנותק — לא נגיש', () {
      const bounds = Rect.fromLTWH(-1800, 200, 1280, 720);
      expect(reachable(bounds, [primary]), isFalse);
      expect(reachable(bounds, [primary, secondary]), isTrue);
    });

    test('רק פינת החלון התחתונה על המסך — פס הכותרת בחוץ, לא נגיש', () {
      const bounds = Rect.fromLTWH(1888, -688, 1280, 720);
      expect(reachable(bounds, [primary]), isFalse);
    });

    test('פס הכותרת על המסך גם כשרוב החלון בחוץ — נגיש', () {
      const bounds = Rect.fromLTWH(1888, 1000, 1280, 720);
      expect(reachable(bounds, [primary]), isTrue);
    });

    test('פס הכותרת מעל קצה המסך העליון — לא ניתן לאחיזה, לא נגיש', () {
      const bounds = Rect.fromLTWH(100, -20, 1280, 720);
      expect(reachable(bounds, [primary]), isFalse);
    });

    test('חפיפה אופקית צרה מרצועת האחיזה — לא נגיש', () {
      const bounds = Rect.fromLTWH(1910, 100, 1280, 720);
      expect(reachable(bounds, [primary]), isFalse);
    });

    test('רצועה בקנה מידה פיזי (DPR 1.5) נבדקת לפי ההיקף שסופק', () {
      const bounds = Rect.fromLTWH(1876, 100, 1280, 720);
      expect(reachable(bounds, [primary], extent: strip * 1.5), isFalse);
      expect(reachable(bounds, [primary], extent: strip), isTrue);
    });

    test('רשימת מסכים ריקה — לא נגיש', () {
      const bounds = Rect.fromLTWH(100, 100, 1280, 720);
      expect(reachable(bounds, const []), isFalse);
    });
  });

  group('WindowPersistence.applyRestoredBounds', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    Future<_RecordingWindow> apply({required bool visible}) async {
      final window = _RecordingWindow(visible: visible);
      WindowPersistence.bindWindow(controller: window, geometry: window);
      await WindowPersistence.applyRestoredBounds();
      return window;
    }

    test('חלון מוסתר (עלייה רגילה) — הגבולות מוחלים', () async {
      final window = await apply(visible: false);
      expect(window.calls, isNotEmpty);
    });

    // hot restart: setBounds על חלון ממוקסם השאיר WS_MAXIMIZE עם מלבן קטן.
    test('חלון גלוי (main רץ שוב על חלון חי) — לא נוגעים בגבולות', () async {
      final window = await apply(visible: true);
      expect(window.calls, isEmpty);
    });
  });
}

class _RecordingWindow implements AppWindowController, AppWindowGeometry {
  _RecordingWindow({required this.visible});

  final bool visible;
  final List<String> calls = [];

  @override
  AppWindowId get id => AppWindowId.primary;
  @override
  Future<bool> isVisible() async => visible;
  @override
  Future<void> center() async => calls.add('center');
  @override
  Future<void> setBounds(Rect bounds) async => calls.add('setBounds');
  @override
  Future<void> setSize(Size size) async => calls.add('setSize');

  @override
  Future<void> close() async {}
  @override
  Future<void> quitApplication() async {}
  @override
  Future<void> focus() async {}
  @override
  Future<Rect> getBounds() async => Rect.zero;
  @override
  Future<bool> isFullScreen() async => false;
  @override
  Future<bool> isMaximized() async => false;
  @override
  Future<bool> isMinimized() async => false;
  @override
  Future<void> maximize() async {}
  @override
  Future<void> minimize() async {}
  @override
  Future<void> setFullScreen(bool value) async {}
  @override
  Future<void> setMinimumSize(Size size) async {}
  @override
  Future<void> setTitleBarStyle(
    TitleBarStyle style, {
    required bool windowButtonVisibility,
  }) async {}
  @override
  Future<void> show() async {}
  @override
  Future<void> startDragging() async {}
  @override
  Future<void> unmaximize() async {}
}
