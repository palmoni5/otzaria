import 'web_window_manager.dart';
import 'window_manager_service.dart';

/// יוצר instance של WindowManagerService לפלטפורמת Web
WindowManagerService createWindowManager() {
  return WebWindowManager();
}
