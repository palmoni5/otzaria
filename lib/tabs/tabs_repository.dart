import 'dart:async';
import 'package:hive_ce/hive.dart';
import 'package:otzaria/tabs/models/tab.dart';
import 'package:otzaria/tabs/models/commentators_tab.dart';
import 'package:otzaria/tabs/models/pdf_commentators_tab.dart';
import 'package:otzaria/tabs/bloc/tabs_state.dart';
import 'package:otzaria/utils/file/hive_utils.dart';
import 'package:flutter/foundation.dart';

class TabsRepository {
  static const String _tabsBoxKey = 'key-tabs';
  static const String _currentTabKey = 'key-current-tab';
  static const String _sideBySideModeKey = 'key-side-by-side-mode';

  bool _isPersistableTab(OpenedTab tab) => tab is! PdfCommentatorsTab;

  int _resolvePersistedCurrentTabIndex(
    Map<int, int> persistedIndexByOriginalIndex,
    int currentTabIndex,
    int originalTabsCount,
  ) {
    if (persistedIndexByOriginalIndex.isEmpty) return 0;

    final directMatch = persistedIndexByOriginalIndex[currentTabIndex];
    if (directMatch != null) return directMatch;

    for (var i = currentTabIndex - 1; i >= 0; i--) {
      final previousMatch = persistedIndexByOriginalIndex[i];
      if (previousMatch != null) return previousMatch;
    }

    for (var i = currentTabIndex + 1; i < originalTabsCount; i++) {
      final nextMatch = persistedIndexByOriginalIndex[i];
      if (nextMatch != null) return nextMatch;
    }

    return 0;
  }

  SideBySideMode? _resolvePersistedSideBySideMode(
    SideBySideMode? sideBySideMode,
    Map<int, int> persistedIndexByOriginalIndex,
  ) {
    if (sideBySideMode == null) return null;

    final persistedLeft =
        persistedIndexByOriginalIndex[sideBySideMode.leftTabIndex];
    final persistedRight =
        persistedIndexByOriginalIndex[sideBySideMode.rightTabIndex];

    if (persistedLeft == null ||
        persistedRight == null ||
        persistedLeft == persistedRight) {
      return null;
    }

    return SideBySideMode(
      leftTabIndex: persistedLeft,
      rightTabIndex: persistedRight,
      splitRatio: sideBySideMode.splitRatio,
    );
  }

  List<OpenedTab> loadTabs() {
    try {
      final box = Hive.box('tabs');
      final rawTabs = box.get(_tabsBoxKey, defaultValue: []) as List;
      final tabs = <OpenedTab>[];
      for (final e in rawTabs) {
        try {
          final tab = _tabFromJson(castMap(e));
          if (tab != null) tabs.add(tab);
        } catch (tabError) {
          debugPrint('⚠️ Skipping tab that failed to restore: $tabError');
        }
      }
      return tabs;
    } catch (e) {
      debugPrint('⚠️ Error loading tabs from disk: $e');
      return [];
    }
  }

  /// כמו OpenedTab.fromJson אבל תומך גם ב-CommentatorsTab.
  /// PdfCommentatorsTab לא אמור להגיע לכאן כי הוא לא נשמר מלכתחילה.
  OpenedTab? _tabFromJson(Map<String, dynamic> json) {
    if (json['type'] == 'PdfCommentatorsTab') return null;
    if (json['type'] == 'CommentatorsTab') {
      return CommentatorsTab.fromJson(json);
    }
    return OpenedTab.fromJson(json);
  }

  int loadCurrentTabIndex() {
    return Hive.box('tabs').get(_currentTabKey, defaultValue: 0);
  }

  SideBySideMode? loadSideBySideMode() {
    try {
      final box = Hive.box('tabs');
      final rawMode = box.get(_sideBySideModeKey);
      if (rawMode == null) return null;
      return SideBySideMode.fromJson(castMap(rawMode));
    } catch (e) {
      debugPrint('Error loading side-by-side mode from disk: $e');
      return null;
    }
  }

  Future<void> saveTabs(List<OpenedTab> tabs, int currentTabIndex,
      [SideBySideMode? sideBySideMode]) async {
    final box = Hive.box('tabs');
    final persistedTabs = <OpenedTab>[];
    final persistedIndexByOriginalIndex = <int, int>{};

    for (var i = 0; i < tabs.length; i++) {
      final tab = tabs[i];
      if (!_isPersistableTab(tab)) continue;
      persistedIndexByOriginalIndex[i] = persistedTabs.length;
      persistedTabs.add(tab);
    }

    final persistedCurrentIndex = _resolvePersistedCurrentTabIndex(
      persistedIndexByOriginalIndex,
      currentTabIndex,
      tabs.length,
    );
    final persistedSideBySideMode = _resolvePersistedSideBySideMode(
      sideBySideMode,
      persistedIndexByOriginalIndex,
    );

    await box.put(
      _tabsBoxKey,
      persistedTabs.map((tab) => tab.toJson()).toList(),
    );
    await box.put(_currentTabKey, persistedCurrentIndex);
    if (persistedSideBySideMode != null) {
      await box.put(_sideBySideModeKey, persistedSideBySideMode.toJson());
    } else {
      await box.delete(_sideBySideModeKey);
    }
  }
}
