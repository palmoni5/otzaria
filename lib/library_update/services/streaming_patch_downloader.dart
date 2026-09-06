import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:seforim_library_updater/seforim_library_updater.dart';

import 'package:otzaria/utils/file/zstd_stream_extractor.dart';

/// פונקציית חילוץ `.zst` מקובץ לקובץ בזרימה (ללא טעינה ל-RAM).
typedef StreamingZstdExtractor =
    Future<void> Function(String archivePath, String outputPath);

/// [PatchDownloader] שמוריד ומחלץ קובצי patch **בזרימה לדיסק**, במקום דרך
/// הזיכרון.
///
/// המימוש המקורי טוען את ה-patch הדחוס ל-RAM ופורס אותו עם `Zstandard().decompress`.
/// כש-patch של ~560MB נדחס בזרימה בלי שדה גודל בכותרת ה-frame, הספרייה מקצה
/// "גודל דחוס × 20" בבלוק אחד — כ-11GB — והמשתמש רואה
/// `Could not allocate 11694234840 bytes`. גם עם שדה גודל, patch של כמה GB
/// פרוסים לא צריך לשבת בזיכרון.
///
/// הזרימה: [downloadToFile] (עם resume ואימות sha256 של הדחוס) → חילוץ זורם
/// ([ZstdStreamExtractor], אותו מנוע שמשמש להורדה המלאה) → אימות גודל ו-sha256
/// של הקובץ המחולץ מהדיסק. הקובץ הדחוס נמחק בסיום; בכשל נמחקים שניהם.
class StreamingPatchDownloader extends PatchDownloader {
  StreamingPatchDownloader({
    StreamingZstdExtractor? extractor,
    super.httpClient,
    super.connectTimeout,
    super.stallTimeout,
  }) : _extractor = extractor ?? ZstdStreamExtractor.extractToFile,
       // decompress בזיכרון אינו בשימוש במסלול הזה, אך המחלקה הבסיסית דורשת אותו.
       super(decompress: (_) async => null);

  final StreamingZstdExtractor _extractor;

  @override
  Future<String> downloadAndExtract({
    required PatchFileEntry patchFile,
    required String downloadUrl,
    required Directory destDir,
    void Function(int downloaded, int? total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (!destDir.existsSync()) destDir.createSync(recursive: true);

    final compressedPath = p.join(destDir.path, patchFile.file);
    // שם הקובץ המחולץ — זהה למימוש הבסיסי: הסרת סיומת .zst
    final extractedName = patchFile.file.endsWith('.zst')
        ? patchFile.file.substring(0, patchFile.file.length - 4)
        : '${patchFile.file}.db';
    final extractedPath = p.join(destDir.path, extractedName);

    try {
      // ה-sha256 של הדחוס הוא זהות יציבה של הנכס — מאפשר המשך הורדה שנקטעה.
      await downloadToFile(
        url: downloadUrl,
        destPath: compressedPath,
        expectedSize: patchFile.size,
        expectedSha256: patchFile.sha256,
        resumeToken: patchFile.sha256,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );

      if (isCancelled != null && isCancelled()) {
        throw const PatchDownloadCancelled();
      }

      _deleteQuietly(extractedPath);
      await _extractor(compressedPath, extractedPath);

      final extracted = File(extractedPath);
      if (!extracted.existsSync()) {
        throw const PatchDownloadException('חילוץ ה-patch נכשל או החזיר ריק');
      }
      final actualSize = extracted.lengthSync();
      if (actualSize != patchFile.uncompressedSize) {
        throw PatchDownloadException(
          'גודל הקובץ המחולץ אינו תואם (צפוי ${patchFile.uncompressedSize}, '
          'בפועל $actualSize)',
        );
      }

      final actualHash = await Isolate.run(() => _sha256OfFile(extractedPath));
      if (actualHash != patchFile.uncompressedSha256.toLowerCase()) {
        throw const PatchDownloadException('sha256 של הקובץ המחולץ אינו תואם');
      }

      // הדחוס מילא את תפקידו; יחד איתו נמחק קובץ הצד של ה-resume.
      _deleteQuietly(compressedPath);
      _deleteQuietly(PatchDownloader.resumeSidecarPath(compressedPath));
      return extractedPath;
    } catch (e) {
      _deleteQuietly(extractedPath);
      // ביטול/כשל רשת משאירים את הדחוס להמשך הורדה (downloadToFile מנהל זאת);
      // כשל אימות של המחולץ מעיד על נכס פגום — מוחקים כדי לא להמשיך זבל.
      if (e is PatchDownloadException) {
        _deleteQuietly(compressedPath);
        _deleteQuietly(PatchDownloader.resumeSidecarPath(compressedPath));
      }
      rethrow;
    }
  }

  static void _deleteQuietly(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }
}

/// sha256 של קובץ בזרימה — רץ ב-isolate כדי לא לחסום את ה-UI על קבצים גדולים.
Future<String> _sha256OfFile(String path) async {
  final digest = await sha256.bind(File(path).openRead()).first;
  return digest.toString();
}
