import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/services/book_details_service.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:url_launcher/url_launcher.dart';

// ביטוי רגולרי להסרת תווים מפרידים (מקפים, קווים תחתונים, רווחים)
final _sourceNormalizationRegex = RegExp(r'[-_\s]');

// מיפוי שמות המקורות לטקסט בעברית וקישורים (ללא כפילויות)
const _sourceMappings = {
  'sefaria': (text: 'ספריא', url: 'https://www.sefaria.org/texts'),
  'benyehuda': (text: 'פרוייקט בן-יהודה', url: 'https://benyehuda.org/'),
  'dicta': (text: 'ספריית דיקטה', url: 'https://library.dicta.org.il/'),
  'onyourway': (text: 'ובלכתך בדרך', url: 'https://mobile.tora.ws/'),
  'orayta': (
    text: 'אורייתא',
    url: 'https://github.com/MosheWagner/Orayta-Books'
  ),
  'tashma': (text: 'תא שמע', url: 'https://tashma.co.il/'),
  'pninim': (text: 'פנינים', url: 'https://pninim.org/'),
  'wikisource': (text: 'ויקיטקסט', url: 'https://he.wikisource.org/wiki'),
  'wikijewishbooks': (
    text: 'אוצר הספרים היהודי השיתופי',
    url: 'https://wiki.jewishbooks.org.il/'
  ),
  'morebooks': (text: 'ספרים פרטיים או מקורות נוספים', url: ''),
  'tootzaria': (text: 'מקורות שהועברו לאוצריא', url: ''),
  'toratemet': (
    text: 'תורת אמת',
    url: 'http://www.toratemetfreeware.com/index.html?downloads;1;'
  ),
  'unknown': (text: 'מקור לא ידוע', url: ''),
};

/// המרת שם המקור לטקסט מתאים עם קישור
/// תומך בשמות המקורות כפי שהם מאוחסנים ב-DB (case-insensitive)
({String text, String url}) getSourceDisplayInfo(String source) {
  // נרמול המחרוזת: הסרת רווחים, המרה לאותיות קטנות והסרת תווים מפרידים
  final normalized =
      source.toLowerCase().replaceAll(_sourceNormalizationRegex, '');

  var key = normalized;

  // טיפול מיוחד ב-ToratEmet (בגלל בעיה עם תווים)
  if (key.contains('toratemet')) {
    key = 'toratemet';
  }
  // טיפול בסיומת 'tootzaria' שנוספה לחלק מהמקורות ב-DB
  else if (key.endsWith('tootzaria') && key != 'tootzaria') {
    key = key.substring(0, key.length - 'tootzaria'.length);
  }

  // חיפוש במיפוי, אם לא נמצא - מחזירים את המקור המקורי
  return _sourceMappings[key] ?? (text: source, url: '');
}

/// קישור הבית של "תא שמע"
const _tashmaUrl = 'https://tashma.co.il/';

/// בודק האם מקור הספר הוא "תא שמע".
/// הזיהוי מבוסס על תיקיית המקור, בדומה ל-error_report_dialog.dart, אך משתמש
/// באותו נרמול כמו getSourceDisplayInfo (הסרת רווחים/מקפים/קווים תחתונים) כדי
/// שכל הווריאנטים שמזוהים כ"תא שמע" בתצוגה יקבלו גם את נוסח הזכויות.
bool isTashmaSource(String? sourceFolder) {
  final normalized = (sourceFolder ?? '')
      .toLowerCase()
      .replaceAll(_sourceNormalizationRegex, '');
  return normalized.contains('tashma');
}

/// הצגת דיאלוג אודות הספר
Future<void> showBookSourceDialog(
  BuildContext context,
  TextBookLoaded state,
) async {
  try {
    debugPrint('Opening book source dialog for: "${state.book.title}"');

    final bookDetails = await BookDetailsService().getBookDetails(state.book);
    final bookSource = bookDetails['תיקיית המקור'] ??
        'book_source_dialog.no_source_found'.tr();

    // קבלת מידע התצוגה עבור המקור
    final sourceInfo = getSourceDisplayInfo(bookSource);
    final displayText = sourceInfo.text;
    final url = sourceInfo.url;
    final isTashma = isTashmaSource(bookSource);

    debugPrint('Book details received: $bookDetails');
    debugPrint('Book source: $bookSource');
    debugPrint('Display text: $displayText, URL: $url');

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'book_source_dialog.title'.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'book_source_dialog.disabled_temporarily'.tr(),
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(fontSize: 14),
                ),

                const Divider(height: 24),

                // מקור הספר
                Text(
                  'book_source_dialog.book_source'.tr(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                // ספרי "תא שמע" מציגים נוסח זכויות יוצרים עם קישור.
                // שאר המקורות מציגים קישור/טקסט רגיל.
                if (isTashma)
                  const _TashmaCopyrightNotice()
                else if (url.isNotEmpty)
                  InkWell(
                    onTap: () async {
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                    child: Text(
                      displayText,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  )
                else
                  SelectableText(
                    displayText,
                    style: const TextStyle(fontSize: 14),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('common.close'.tr()),
          ),
        ],
      ),
    );
  } catch (e) {
    debugPrint('Error showing book source dialog: $e');
    if (context.mounted) {
      UiSnack.showError('book_source_dialog.load_error'
          .tr(namedArgs: {'error': e.toString()}));
    }
  }
}

/// נוסח זכויות היוצרים עבור ספרי "תא שמע".
/// המילים "תא שמע" מוצגות כקישור לאתר תא שמע.
class _TashmaCopyrightNotice extends StatefulWidget {
  const _TashmaCopyrightNotice();

  @override
  State<_TashmaCopyrightNotice> createState() => _TashmaCopyrightNoticeState();
}

class _TashmaCopyrightNoticeState extends State<_TashmaCopyrightNotice> {
  late final TapGestureRecognizer _recognizer;

  @override
  void initState() {
    super.initState();
    _recognizer = TapGestureRecognizer()
      ..onTap = () async {
        final uri = Uri.parse(_tashmaUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      };
  }

  @override
  void dispose() {
    _recognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 14),
        children: [
          const TextSpan(text: 'כל הזכויות שמורות ל'),
          TextSpan(
            text: 'תא שמע',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
            recognizer: _recognizer,
          ),
          const TextSpan(
            text: '. השימוש מותר במסגרת תוכנת אוצריא בלבד. '
                'אין לבצע שימוש אחר ללא אישור.',
          ),
        ],
      ),
      textDirection: TextDirection.rtl,
    );
  }
}
