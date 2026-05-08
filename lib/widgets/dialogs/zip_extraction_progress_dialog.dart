import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:otzaria/utils/file/zip_extractor_service.dart';

/// ווידג'ט לטיפול בהצגת דיאלוג התקדמות חילוץ ZIP
class ZipExtractionProgressDialog {
  /// מציג דיאלוג התקדמות ומבצע חילוץ ZIP אם נדרש
  ///
  /// [context] - הקונטקסט של המסך
  /// [path] - נתיב התיקייה לבדיקה
  /// [onSuccess] - פונקציה שתופעל בהצלחה (מקבלת את תוצאת החילוץ)
  /// [onError] - פונקציה שתופעל בשגיאה (מקבלת הודעת שגיאה)
  static Future<void> showAndExtract({
    required BuildContext context,
    required String path,
    required Function(ZipExtractionResult) onSuccess,
    required Function(String) onError,
  }) async {
    final progressNotifier = ValueNotifier<double>(0.0);
    final messageNotifier =
        ValueNotifier<String>('dialogs.zip_extraction.checking_folder'.tr());
    final isExtractingNotifier = ValueNotifier<bool>(false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text('dialogs.zip_extraction.processing_folder'.tr()),
        content: ValueListenableBuilder<bool>(
          valueListenable: isExtractingNotifier,
          builder: (context, isExtracting, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isExtracting) ...[
                  SizedBox(
                    width: 250,
                    child: ValueListenableBuilder<double>(
                      valueListenable: progressNotifier,
                      builder: (context, progress, _) {
                        return LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<String>(
                    valueListenable: messageNotifier,
                    builder: (context, message, _) {
                      return Text(message, textAlign: TextAlign.center);
                    },
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<double>(
                    valueListenable: progressNotifier,
                    builder: (context, progress, _) {
                      return Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      );
                    },
                  ),
                ] else ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<String>(
                    valueListenable: messageNotifier,
                    builder: (context, message, _) {
                      return Text(message);
                    },
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );

    try {
      final extractionResult =
          await ZipExtractorService.checkAndExtractZipIfNeeded(
        path,
        onProgress: (p, m) {
          progressNotifier.value = p;
          messageNotifier.value = m;
          isExtractingNotifier.value = true;
        },
        onAskDeleteZip: () async {
          // סגירת דיאלוג ההתקדמות
          if (context.mounted) {
            Navigator.of(context).pop();
          }

          // שאלת המשתמש
          final shouldDelete = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text('dialogs.zip_extraction.delete_zip_title'.tr()),
              content: Text(
                'dialogs.zip_extraction.delete_zip_content'.tr(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text('dialogs.zip_extraction.keep_file'.tr()),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text('dialogs.zip_extraction.delete_file'.tr()),
                ),
              ],
            ),
          );

          // פתיחה מחדש של דיאלוג ההתקדמות
          if (context.mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (dialogContext) => AlertDialog(
                title: Text('dialogs.zip_extraction.completing'.tr()),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('dialogs.zip_extraction.completing_extraction'.tr()),
                  ],
                ),
              ),
            );
          }

          return shouldDelete ?? false;
        },
      );

      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (!extractionResult.success) {
        onError(extractionResult.errorMessage ??
            'dialogs.zip_extraction.unknown_error'.tr());
      } else {
        onSuccess(extractionResult);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      onError(e.toString());
    } finally {
      progressNotifier.dispose();
      messageNotifier.dispose();
      isExtractingNotifier.dispose();
    }
  }
}
