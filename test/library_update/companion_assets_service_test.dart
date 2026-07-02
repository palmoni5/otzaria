import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:otzaria/data/constants/database_constants.dart';
import 'package:otzaria/external_catalog/repository/external_catalog_repository.dart';
import 'package:otzaria/library_update/services/companion_assets_service.dart';
import 'package:otzaria/search/magic_dictionary_downloader.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('companion_assets_test');
  });

  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  const tag = 'v2.0.0';
  const assetUrl = 'https://x/talmud_bavli_latest.tar.zst';

  MockClient releaseClient({List<Uri>? requested}) {
    return MockClient((request) async {
      requested?.add(request.url);
      if (request.url.path.contains('releases/latest')) {
        return http.Response(
          jsonEncode({
            'tag_name': tag,
            'assets': [
              {
                'name': DatabaseConstants.talmudBavliArchiveFileName,
                'browser_download_url': assetUrl,
              }
            ],
          }),
          200,
        );
      }
      if (request.url.toString() == assetUrl) {
        return http.Response.bytes([1, 2, 3], 200);
      }
      return http.Response('not found', 404);
    });
  }

  CompanionAssetsService service({
    http.Client? client,
    _FakeCatalogRepository? catalog,
    _FakeDictionaryDownloader? dictionary,
    List<({String archive, String outputDir})>? extractions,
    List<String>? talmudDirs,
    void Function()? invalidate,
  }) {
    return CompanionAssetsService(
      clientFactory: () => client ?? releaseClient(),
      catalogRepository: () => catalog ?? _FakeCatalogRepository(exists: true),
      dictionaryFactory: () => dictionary ?? _FakeDictionaryDownloader(),
      extractTarArchive: (archive, outputDir, onProgress) async {
        extractions?.add((archive: archive, outputDir: outputDir));
        onProgress?.call(0.5);
        onProgress?.call(1.0);
        Directory(p.join(outputDir, DatabaseConstants.talmudBavliFolderName))
            .createSync(recursive: true);
      },
      talmudDirsProvider: () =>
          talmudDirs ??
          [p.join(tmp.path, DatabaseConstants.talmudBavliFolderName)],
      invalidateExternalBooksCache: invalidate ?? () {},
    );
  }

  String talmudDir() =>
      p.join(tmp.path, DatabaseConstants.talmudBavliFolderName);

  void createTalmudDir({String? markerTag}) {
    final dir = Directory(talmudDir())..createSync(recursive: true);
    File(p.join(dir.path, 'ברכות.pdf')).writeAsStringSync('pdf');
    if (markerTag != null) {
      File(p.join(dir.path, CompanionAssetsService.talmudVersionFileName))
          .writeAsStringSync(markerTag);
    }
  }

  String? readMarker() {
    final f =
        File(p.join(talmudDir(), CompanionAssetsService.talmudVersionFileName));
    return f.existsSync() ? f.readAsStringSync().trim() : null;
  }

  group('תלמוד בבלי', () {
    test('תיקייה חסרה → מוריד, מחלץ לתיקיית האב, וכותב סימון גרסה', () async {
      final extractions = <({String archive, String outputDir})>[];
      final statuses = <String>[];
      final progress = <int>[];
      await service(extractions: extractions).verifyAndUpdate(
        onStatus: statuses.add,
        onDownloadProgress: (done, total) => progress.add(done),
      );

      expect(extractions, hasLength(1));
      expect(extractions.single.outputDir, tmp.path);
      expect(readMarker(), tag);
      // מד בזמן החילוץ (שלב ה-zst), ומעבר לספינר בשלב פריסת ה-tar.
      expect(statuses, contains('מחלץ את התלמוד הבבלי'));
      expect(statuses, contains('פורס את קבצי התלמוד'));
      expect(progress, contains(5000));
    });

    test('תיקייה קיימת ללא סימון → מחתים את התג בלי להוריד', () async {
      createTalmudDir();
      final requested = <Uri>[];
      final extractions = <({String archive, String outputDir})>[];
      await service(
        client: releaseClient(requested: requested),
        extractions: extractions,
      ).verifyAndUpdate();

      expect(readMarker(), tag);
      expect(extractions, isEmpty);
      expect(requested.map((u) => u.toString()), isNot(contains(assetUrl)));
    });

    test('סימון תואם לתג → לא מוריד ולא נוגע', () async {
      createTalmudDir(markerTag: tag);
      final extractions = <({String archive, String outputDir})>[];
      await service(extractions: extractions).verifyAndUpdate();
      expect(extractions, isEmpty);
    });

    test('סימון ישן → מוריד ומעדכן את הסימון', () async {
      createTalmudDir(markerTag: 'v1.0.0');
      final extractions = <({String archive, String outputDir})>[];
      await service(extractions: extractions).verifyAndUpdate();

      expect(extractions, hasLength(1));
      expect(readMarker(), tag);
    });

    test('כשל ב-API של התלמוד לא עוצר את הקטלוג והמילון', () async {
      final catalog = _FakeCatalogRepository(exists: true);
      final dictionary = _FakeDictionaryDownloader();
      final failing = MockClient((_) async => http.Response('boom', 500));
      await service(client: failing, catalog: catalog, dictionary: dictionary)
          .verifyAndUpdate();

      expect(catalog.updateCalled, isTrue);
      expect(dictionary.ensureCalled, isTrue);
    });

    test('ביטול אחרי התלמוד מדלג על השאר', () async {
      createTalmudDir(markerTag: tag);
      final catalog = _FakeCatalogRepository(exists: true);
      await service(catalog: catalog).verifyAndUpdate(
        isCancelled: () => true,
      );
      expect(catalog.updateCalled, isFalse);
    });
  });

  group('קטלוג otzar-HB', () {
    test('קיים → בודק עדכון; עדכון בפועל מרענן את הקאש', () async {
      final catalog = _FakeCatalogRepository(exists: true, updateResult: true);
      var invalidated = 0;
      createTalmudDir(markerTag: tag);
      await service(catalog: catalog, invalidate: () => invalidated++)
          .verifyAndUpdate();

      expect(catalog.updateCalled, isTrue);
      expect(catalog.downloadCalled, isFalse);
      expect(invalidated, 1);
    });

    test('חסר → מוריד', () async {
      final catalog = _FakeCatalogRepository(exists: false);
      createTalmudDir(markerTag: tag);
      await service(catalog: catalog).verifyAndUpdate();
      expect(catalog.downloadCalled, isTrue);
    });
  });

  test('המילון: ensureLatest נקרא ו-dispose משוחרר', () async {
    final dictionary = _FakeDictionaryDownloader();
    createTalmudDir(markerTag: tag);
    await service(dictionary: dictionary).verifyAndUpdate();
    expect(dictionary.ensureCalled, isTrue);
    expect(dictionary.disposed, isTrue);
  });
}

class _FakeCatalogRepository extends ExternalCatalogRepository {
  _FakeCatalogRepository({required this.exists, this.updateResult = false})
      : super(httpClient: MockClient((_) async => http.Response('', 404)));

  final bool exists;
  final bool updateResult;
  bool updateCalled = false;
  bool downloadCalled = false;

  @override
  Future<bool> databaseExists() async => exists;

  @override
  Future<bool> updateDatabaseIfNeeded() async {
    updateCalled = true;
    return updateResult;
  }

  @override
  Future<void> downloadLatestDatabase() async {
    downloadCalled = true;
  }
}

class _FakeDictionaryDownloader extends MagicDictionaryDownloader {
  _FakeDictionaryDownloader()
      : super(client: MockClient((_) async => http.Response('', 404)));

  bool ensureCalled = false;
  bool disposed = false;

  @override
  Future<bool> ensureLatest({
    void Function(double progress)? onProgress,
    bool force = false,
  }) async {
    ensureCalled = true;
    return true;
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}
