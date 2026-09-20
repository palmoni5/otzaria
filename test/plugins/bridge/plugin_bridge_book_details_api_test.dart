import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:otzaria/data/repository/data_repository.dart';
import 'package:otzaria/history/bloc/history_bloc.dart';
import 'package:otzaria/library/models/library.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/navigation/bloc/navigation_bloc.dart';
import 'package:otzaria/personal_notes/repository/personal_notes_repository.dart';
import 'package:otzaria/plugins/bridge/plugin_bridge_adapter.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:otzaria/plugins/repository/plugin_registry_repository.dart';
import 'package:otzaria/search/search_repository.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/tabs/bloc/tabs_state.dart';
import 'package:otzaria/tools/calendar/utils/calendar_cubit.dart';
import 'package:otzaria/utils/navigation/book_open_coordinator.dart';
import 'package:otzaria/workspaces/bloc/workspace_bloc.dart';

import '../../test_helpers/memory_cache_provider.dart';

class _MockHistoryBloc extends Mock implements HistoryBloc {}

class _MockNavigationBloc extends Mock implements NavigationBloc {}

class _MockCalendarCubit extends Mock implements CalendarCubit {}

class _MockWorkspaceBloc extends Mock implements WorkspaceBloc {}

class _MockSearchRepository extends Mock implements SearchRepository {}

class _MockPersonalNotesRepository extends Mock
    implements PersonalNotesRepository {}

class _MockBookOpenCoordinator extends Mock implements BookOpenCoordinator {}

class _StubTabsBloc extends Mock implements TabsBloc {
  TabsState currentState = TabsState.initial();

  @override
  TabsState get state => currentState;
}

class _StubPluginRegistryRepository extends PluginRegistryRepository {
  @override
  Future<bool?> getPermission(String pluginId, String permission) async => true;
}

InstalledPlugin _plugin() => InstalledPlugin(
  pluginId: 'test.plugin',
  name: 'Test Plugin',
  version: '1.0.0',
  installPath: '/',
  entrypointPath: 'index.html',
  enabled: true,
  pinned: true,
  manifest: PluginManifest(
    schemaVersion: 1,
    id: 'test.plugin',
    name: 'Test Plugin',
    version: '1.0.0',
    description: '',
    author: '',
    homepage: '',
    entrypoint: 'index.html',
    minAppVersion: '1.0.0',
    sdkVersion: '1.x',
    permissions: const ['library.books.read', 'tools.read'],
    networkEnabled: false,
    networkAllowlist: const [],
    toolTabTitle: 'Test Plugin',
    toolTabOrder: 1,
    defaultPinned: true,
    publishedDataTypes: const [],
  ),
  installedAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Matcher _codedError(String code) => throwsA(
  isA<Exception>().having((e) => e.toString(), 'message', contains(code)),
);

void main() {
  late PluginBridgeAdapter adapter;

  void installLibrary(List<Book> books) {
    final category = Category(
      title: 'הלכה',
      description: '',
      shortDescription: '',
      order: 0,
      subCategories: [],
      books: books,
      parent: null,
    );
    final library = Library(categories: [category]);
    category.parent = library;
    DataRepository.instance.library = Future.value(library);
  }

  setUpAll(() async {
    await Settings.init(cacheProvider: MemoryCacheProvider());
  });

  setUp(() {
    adapter = PluginBridgeAdapter(
      _plugin(),
      dependencies: PluginBridgeDependencies(
        historyBloc: _MockHistoryBloc(),
        tabsBloc: _StubTabsBloc(),
        navigationBloc: _MockNavigationBloc(),
        calendarCubit: _MockCalendarCubit(),
        workspaceBloc: _MockWorkspaceBloc(),
        searchRepository: _MockSearchRepository(),
        personalNotesRepository: _MockPersonalNotesRepository(),
        bookOpenCoordinator: _MockBookOpenCoordinator(),
        themePayloadBuilder: () => <String, dynamic>{},
        showConfirmDialog: ({required title, required content}) async => true,
        showWarningDialog:
            ({required title, required content, required subtitle}) async =>
                true,
      ),
      pluginRepository: _StubPluginRegistryRepository(),
    );
  });

  group('library.getBookDetails', () {
    test('מחזיר את שדות "אודות הספר" ואת הזהות המלאה', () async {
      final book = TextBook(
        title: 'שולחן ערוך אורח חיים',
        categoryId: 7,
        fileType: 'txt',
        author: 'רבי יוסף קארו',
        heEra: 'אחרונים',
        heCategories: 'הלכה',
        compPlaceStringHe: 'צפת',
        pubDateStringHe: 'שס"ו',
        pubPlaceStringHe: 'ונציה',
        heShortDesc: 'ספר הלכה',
        heDesc: 'תיאור מורחב',
      )..filePath = 'אוצריא/הלכה/שולחן ערוך אורח חיים.txt';
      installLibrary([book]);

      final result =
          await adapter.execute('library', 'getBookDetails', {
                'bookId': 'שולחן ערוך אורח חיים',
              })
              as Map<String, dynamic>;

      expect(result['title'], 'שולחן ערוך אורח חיים');
      expect(result['bookUid'], isNotNull);
      expect(result['authors'], ['רבי יוסף קארו']);
      expect(result['era'], 'אחרונים');
      expect(result['categories'], 'הלכה');
      expect(result['compositionPlace'], 'צפת');
      expect(result['publicationDates'], ['שס"ו']);
      expect(result['publicationPlaces'], ['ונציה']);
      expect(result['shortDescription'], 'ספר הלכה');
      expect(result['fullDescription'], 'תיאור מורחב');
      expect(result['libraryPath'], 'הלכה/שולחן ערוך אורח חיים');
    });

    test('נתיב מוחלט של ספר אישי אינו נחשף', () async {
      final book = TextBook(title: 'ספר אישי', isUserBook: true)
        ..filePath = r'C:\Users\Someone\books\ספר אישי.txt';
      installLibrary([book]);

      final result =
          await adapter.execute('library', 'getBookDetails', {
                'bookId': 'ספר אישי',
              })
              as Map<String, dynamic>;

      expect(result['libraryPath'], isNull);
    });

    test('ספר שאינו קיים מחזיר null, וללא זהות נזרקת שגיאת פרמטרים', () async {
      installLibrary([TextBook(title: 'ספר אחר')]);

      expect(
        await adapter.execute('library', 'getBookDetails', {
          'bookId': 'לא קיים',
        }),
        isNull,
      );
      expect(
        () => adapter.execute('library', 'getBookDetails', {}),
        _codedError('error.invalid_params'),
      );
    });
  });

  group('tools.biographies', () {
    test('פרמטרים פסולים נדחים לפני טעינת המאגר', () async {
      expect(
        () => adapter.execute('tools', 'biographies', {'limit': 0}),
        _codedError('error.invalid_params'),
      );
      expect(
        () => adapter.execute('tools', 'biographies', {'limit': 51}),
        _codedError('error.invalid_params'),
      );
      expect(
        () => adapter.execute('tools', 'biographies', {'id': 'abc'}),
        _codedError('error.invalid_params'),
      );
      expect(
        () => adapter.execute('tools', 'biographies', {'query': 'א' * 201}),
        _codedError('error.invalid_params'),
      );
    });
  });
}
