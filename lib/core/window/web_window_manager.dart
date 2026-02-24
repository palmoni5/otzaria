import 'package:web/web.dart' as web;
import 'window_manager_service.dart';

/// מימוש WindowManagerService לפלטפורמת Web
/// משתמש ב-Fullscreen API של הדפדפן
class WebWindowManager implements WindowManagerService {
  bool _isFullScreen = false;

  @override
  Future<void> setFullScreen(bool fullscreen) async {
    if (fullscreen) {
      web.document.documentElement?.requestFullscreen();
      _isFullScreen = true;
    } else {
      web.document.exitFullscreen();
      _isFullScreen = false;
    }
  }

  @override
  Future<bool> isFullScreen() async {
    return _isFullScreen;
  }

  @override
  Future<void> minimize() async {
    // לא נתמך בווב
  }

  @override
  Future<void> close() async {
    // ניסיון לסגור את החלון - עשוי להיחסם על ידי הדפדפן
    web.window.close();
  }

  @override
  Future<void> maximize() async {
    // לא נתמך בווב - נשתמש ב-fullscreen במקום
    await setFullScreen(true);
  }

  @override
  Future<void> unmaximize() async {
    // לא נתמך בווב
    await setFullScreen(false);
  }

  @override
  Future<bool> isMaximized() async {
    return _isFullScreen;
  }

  @override
  Future<void> setSize(double width, double height) async {
    // לא נתמך בווב
  }

  @override
  Future<Map<String, double>> getSize() async {
    return {
      'width': web.window.innerWidth.toDouble(),
      'height': web.window.innerHeight.toDouble(),
    };
  }

  @override
  Future<void> setPosition(double x, double y) async {
    // לא נתמך בווב
  }

  @override
  Future<Map<String, double>> getPosition() async {
    return {'x': 0, 'y': 0};
  }

  @override
  Future<void> setTitle(String title) async {
    web.document.title = title;
  }

  @override
  Future<void> show() async {
    // תמיד גלוי בווב
  }

  @override
  Future<void> hide() async {
    // לא נתמך בווב
  }

  @override
  Future<bool> isVisible() async {
    return true;
  }

  @override
  Future<void> setAlwaysOnTop(bool alwaysOnTop) async {
    // לא נתמך בווב
  }

  @override
  Future<bool> isAlwaysOnTop() async {
    return false;
  }
}
