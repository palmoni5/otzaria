import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:otzaria/library_update/services/streaming_patch_downloader.dart';
import 'package:path/path.dart' as p;
import 'package:seforim_library_updater/seforim_library_updater.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('streaming_dl_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  // "patch" מדומה: הדחוס הוא הבייטים שמוגשים; ה"חילוץ" מעתיק קובץ ומהפך אותו.
  final compressed = Uint8List.fromList(List.generate(4096, (i) => i % 251));
  final uncompressed = Uint8List.fromList(compressed.reversed.toList());

  PatchFileEntry entry({String? uncompressedHash, int? uncompressedSize}) =>
      PatchFileEntry(
        file: 'patch-v1-v2.db.zst',
        compression: 'zstd',
        sha256: sha256.convert(compressed).toString(),
        size: compressed.length,
        uncompressedSha256:
            uncompressedHash ?? sha256.convert(uncompressed).toString(),
        uncompressedSize: uncompressedSize ?? uncompressed.length,
      );

  var extractorCalls = 0;
  Future<void> reversingExtractor(String src, String dst) async {
    extractorCalls++;
    final bytes = File(src).readAsBytesSync();
    File(dst).writeAsBytesSync(bytes.reversed.toList(), flush: true);
  }

  StreamingPatchDownloader build() {
    extractorCalls = 0;
    final mock = MockClient.streaming((request, bodyStream) async {
      return http.StreamedResponse(
        Stream.value(compressed),
        200,
        contentLength: compressed.length,
        headers: {'etag': '"v1"'},
      );
    });
    return StreamingPatchDownloader(
      httpClient: mock,
      extractor: reversingExtractor,
    );
  }

  test('הורדה לדיסק + חילוץ זורם → .db מאומת, הדחוס נמחק', () async {
    final path = await build().downloadAndExtract(
      patchFile: entry(),
      downloadUrl: 'https://x/patch-v1-v2.db.zst',
      destDir: tmp,
    );
    expect(p.basename(path), 'patch-v1-v2.db');
    expect(File(path).readAsBytesSync(), uncompressed);
    expect(extractorCalls, 1);
    expect(File(p.join(tmp.path, 'patch-v1-v2.db.zst')).existsSync(), isFalse);
    expect(
      File(p.join(tmp.path, 'patch-v1-v2.db.zst.resume')).existsSync(),
      isFalse,
    );
  });

  test(
    'sha256 מחולץ שגוי → PatchDownloadException ושום קובץ לא נשאר',
    () async {
      await expectLater(
        build().downloadAndExtract(
          patchFile: entry(uncompressedHash: 'deadbeef'),
          downloadUrl: 'https://x/p.zst',
          destDir: tmp,
        ),
        throwsA(isA<PatchDownloadException>()),
      );
      expect(tmp.listSync(), isEmpty);
    },
  );

  test('גודל מחולץ שגוי → PatchDownloadException', () async {
    await expectLater(
      build().downloadAndExtract(
        patchFile: entry(uncompressedSize: uncompressed.length + 1),
        downloadUrl: 'https://x/p.zst',
        destDir: tmp,
      ),
      throwsA(isA<PatchDownloadException>()),
    );
    expect(File(p.join(tmp.path, 'p')).existsSync(), isFalse);
  });
}
