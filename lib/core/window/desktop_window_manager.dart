import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'window_manager_service.dart';

/// מימוש WindowManagerService לפלטפורמות Desktop
/// משתמש ב-window_manager package
class DesktopWindowManager implements WindowManagerService {
  @override
  Future<void> setFullScreen(bool fullscreen) async {
    await windowManager.setFullScreen(fullscreen);
  }

  @override
  Future<bool> isFullScreen() async {
    return await windowManager.isFullScreen();
  }

  @override
  Future<void> minimize() async {
    await windowManager.minimize();
  }

  @override
  Future<void> close() async {
    await windowManager.close();
  }

  @override
  Future<void> maximize() async {
    await windowManager.maximize();
  }

  @override
  Future<void> unmaximize() async {
    await windowManager.unmaximize();
  }

  @override
  Future<bool> isMaximized() async {
    return await windowManager.isMaximized();
  }

  @override
  Future<void> setSize(double width, double height) async {
    await windowManager.setSize(Size(width, height));
  }

  @override
  Future<Map<String, double>> getSize() async {
    final size = await windowManager.getSize();
    return {'width': size.width, 'height': size.height};
  }

  @override
  Future<void> setPosition(double x, double y) async {
    await windowManager.setPosition(Offset(x, y));
  }

  @override
  Future<Map<String, double>> getPosition() async {
    final position = await windowManager.getPosition();
    return {'x': position.dx, 'y': position.dy};
  }

  @override
  Future<void> setTitle(String title) async {
    await windowManager.setTitle(title);
  }

  @override
  Future<void> show() async {
    await windowManager.show();
  }

  @override
  Future<void> hide() async {
    await windowManager.hide();
  }

  @override
  Future<bool> isVisible() async {
    return await windowManager.isVisible();
  }

  @override
  Future<void> setAlwaysOnTop(bool alwaysOnTop) async {
    await windowManager.setAlwaysOnTop(alwaysOnTop);
  }

  @override
  Future<bool> isAlwaysOnTop() async {
    return await windowManager.isAlwaysOnTop();
  }
}
