import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/update/my_update_widget.dart';
import 'package:path/path.dart' as p;

/// הורדת העדכון נכשלת רק על חיבור שלא נענה או על זרם שנתקע — לא על משך
/// כולל. רשת איטית שמתקדמת חייבת להשלים הורדה גם כשהיא ארוכה מכל חסם כולל.
///
/// השרת כאן הוא ServerSocket גולמי ולא HttpServer: HttpResponse של Dart
/// מאגד את הכתיבות (גם אחרי flush) ולכן אינו מדמה זרם איטי באמת, וגם אינו
/// מזהה ניתוק של הלקוח בזמן שהתגובה פתוחה.
void main() {
  late ServerSocket server;
  late Directory tempDir;

  setUp(() async {
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    tempDir = await Directory.systemTemp.createTemp('otzaria_update_dl_');
  });

  tearDown(() async {
    await server.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  String url() => 'http://127.0.0.1:${server.port}/otzaria-test.bin';

  String headers(int contentLength) =>
      'HTTP/1.1 200 OK\r\n'
      'Content-Type: application/octet-stream\r\n'
      'Content-Length: $contentLength\r\n\r\n';

  /// מגיש בקשה אחת: [onRequest] נקרא כשהבקשה התקבלה; מחזיר Future שמושלם
  /// כשהלקוח סגר את החיבור (סוף זרם הקריאה בצד השרת).
  Future<void> serveOnce(Future<void> Function(Socket socket) onRequest) {
    final clientClosed = Completer<void>();
    server.listen((socket) {
      var requestSeen = false;
      socket.listen(
        (_) {
          if (requestSeen) return;
          requestSeen = true;
          onRequest(socket);
        },
        onDone: clientClosed.complete,
        onError: (_) => clientClosed.complete(),
      );
    });
    return clientClosed.future;
  }

  test('הורדה איטית אך מתקדמת מצליחה — אין חסם על המשך הכולל', () async {
    const chunkCount = 15;
    const chunkGap = Duration(milliseconds: 100);
    final chunk = List<int>.filled(1024, 7);

    serveOnce((socket) async {
      socket.write(headers(chunk.length * chunkCount));
      await socket.flush();
      for (var i = 0; i < chunkCount; i++) {
        await Future<void>.delayed(chunkGap);
        socket.add(chunk);
        await socket.flush();
      }
      await socket.close();
    });

    final file = File(p.join(tempDir.path, 'otzaria-test.bin'));
    final stopwatch = Stopwatch()..start();
    // ההורדה כולה (~1.5 שניות) ארוכה בהרבה מה-stall (500ms) — ולמרות זאת
    // מצליחה, כי כל chunk מגיע בתוך חלון ה-stall.
    await downloadReleaseFile(
      file,
      url(),
      'otzaria',
      connectTimeout: const Duration(seconds: 5),
      stallTimeout: const Duration(milliseconds: 500),
    );
    stopwatch.stop();

    expect(file.lengthSync(), chunk.length * chunkCount);
    expect(
      stopwatch.elapsed,
      greaterThan(chunkGap * (chunkCount - 1)),
      reason: 'השרת אמור להזרים לאט; אם ההורדה הייתה מהירה הטסט אינו מוכיח דבר',
    );
  });

  test('זרם שנתקע אחרי ה-headers נכשל אחרי ה-stall והחיבור נסגר', () async {
    final clientClosed = serveOnce((socket) async {
      socket.write(headers(4096));
      socket.add(List<int>.filled(16, 1));
      await socket.flush();
      // לא שולחים יותר דבר — החיבור נשאר פתוח עד שהלקוח ינתק.
    });

    final file = File(p.join(tempDir.path, 'otzaria-stuck.bin'));
    final stopwatch = Stopwatch()..start();
    await expectLater(
      downloadReleaseFile(
        file,
        url(),
        'otzaria',
        connectTimeout: const Duration(seconds: 5),
        stallTimeout: const Duration(milliseconds: 300),
      ),
      throwsA(isA<TimeoutException>()),
    );
    stopwatch.stop();
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));

    // הלקוח סגר את החיבור בפועל — השרת רואה את סוף הזרם, ולא נשאר חיבור תלוי.
    await expectLater(
      clientClosed.timeout(const Duration(seconds: 3)),
      completes,
    );
  });

  test('שרת שלא עונה כלל נכשל על ה-connect timeout והחיבור נסגר', () async {
    // לא מחזירים headers — הבקשה נשארת פתוחה.
    final clientClosed = serveOnce((_) async {});

    final file = File(p.join(tempDir.path, 'otzaria-noanswer.bin'));
    await expectLater(
      downloadReleaseFile(
        file,
        url(),
        'otzaria',
        connectTimeout: const Duration(milliseconds: 300),
        stallTimeout: const Duration(seconds: 5),
      ),
      throwsA(isA<TimeoutException>()),
    );
    await expectLater(
      clientClosed.timeout(const Duration(seconds: 3)),
      completes,
    );
  });

  group('הורדה אטומית', () {
    test('גודל שאינו תואם ל-release נדחה, והיעד אינו נוצר', () async {
      final payload = List<int>.filled(100, 3);
      serveOnce((socket) async {
        socket.write(headers(payload.length));
        socket.add(payload);
        await socket.flush();
        await socket.close();
      });

      final file = File(p.join(tempDir.path, 'otzaria-short.bin'));
      await expectLater(
        downloadReleaseFile(
          file,
          url(),
          'otzaria',
          connectTimeout: const Duration(seconds: 5),
          stallTimeout: const Duration(seconds: 5),
          expectedSize: 200,
        ),
        throwsA(isA<Exception>()),
      );

      expect(file.existsSync(), isFalse);
      expect(File('${file.path}.part').existsSync(), isFalse);
    });

    test('הורדה שנתקעה אינה דורסת קובץ קיים', () async {
      final file = File(p.join(tempDir.path, 'otzaria-existing.bin'))
        ..writeAsStringSync('the previous download');

      serveOnce((socket) async {
        socket.write(headers(4096));
        socket.add(List<int>.filled(16, 1));
        await socket.flush();
      });

      await expectLater(
        downloadReleaseFile(
          file,
          url(),
          'otzaria',
          connectTimeout: const Duration(seconds: 5),
          stallTimeout: const Duration(milliseconds: 300),
        ),
        throwsA(isA<TimeoutException>()),
      );

      expect(file.readAsStringSync(), 'the previous download');
      expect(File('${file.path}.part').existsSync(), isFalse);
    });

    test('גודל תואם — הקובץ מוחלף בשמו הסופי', () async {
      final payload = List<int>.filled(512, 9);
      serveOnce((socket) async {
        socket.write(headers(payload.length));
        socket.add(payload);
        await socket.flush();
        await socket.close();
      });

      final file = File(p.join(tempDir.path, 'otzaria-ok.bin'));
      await downloadReleaseFile(
        file,
        url(),
        'otzaria',
        connectTimeout: const Duration(seconds: 5),
        stallTimeout: const Duration(seconds: 5),
        expectedSize: payload.length,
      );

      expect(file.lengthSync(), payload.length);
      expect(File('${file.path}.part').existsSync(), isFalse);
    });
  });
}
