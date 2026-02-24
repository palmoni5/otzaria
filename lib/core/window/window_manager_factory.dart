// Conditional exports for platform-specific window managers
export 'window_manager_stub.dart'
    if (dart.library.io) 'window_manager_io.dart'
    if (dart.library.html) 'window_manager_web.dart';
