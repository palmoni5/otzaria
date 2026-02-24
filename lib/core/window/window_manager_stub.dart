import 'window_manager_service.dart';

/// Stub implementation - לא אמור להיקרא
class StubWindowManager implements WindowManagerService {
  @override
  Future<void> setFullScreen(bool fullscreen) async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<bool> isFullScreen() async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<void> minimize() async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<void> close() async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<void> maximize() async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<void> unmaximize() async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<bool> isMaximized() async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<void> setSize(double width, double height) async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<Map<String, double>> getSize() async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<void> setPosition(double x, double y) async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<Map<String, double>> getPosition() async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<void> setTitle(String title) async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<void> show() async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<void> hide() async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<bool> isVisible() async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<void> setAlwaysOnTop(bool alwaysOnTop) async {
    throw UnsupportedError('Platform not supported');
  }

  @override
  Future<bool> isAlwaysOnTop() async {
    throw UnsupportedError('Platform not supported');
  }
}

/// יוצר instance של WindowManagerService
WindowManagerService createWindowManager() {
  return StubWindowManager();
}
