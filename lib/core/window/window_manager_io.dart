import 'desktop_window_manager.dart';
import 'window_manager_service.dart';

/// יוצר instance של WindowManagerService לפלטפורמות Desktop
WindowManagerService createWindowManager() {
  return DesktopWindowManager();
}
