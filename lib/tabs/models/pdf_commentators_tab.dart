import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:otzaria/tabs/models/tab.dart';
import 'package:otzaria/tabs/models/pdf_tab.dart';

/// Tab שמציג מפרשים של ספר PDF בכרטסייה עצמאית.
///
/// בעת פתיחה רגילה (מהספר החי) חולק את ה-state עם [sourceTab] הפעיל.
/// בעת שחזור מהפעלה קודמת נבנה [sourceTab] חדש מתוך הנתונים השמורים
/// (נתיב + עמוד + מפרשים פעילים), והמסך טוען בעצמו את ה-headings/links
/// החסרים. במצב זה הטאב הוא הבעלים של ה-sourceTab ומשחרר אותו ב-dispose.
class PdfCommentatorsTab extends OpenedTab {
  final PdfBookTab sourceTab;
  final bool _disposeSourceTabOnDispose;

  PdfCommentatorsTab({
    required this.sourceTab,
    bool disposeSourceTabOnDispose = false,
  })  : _disposeSourceTabOnDispose = disposeSourceTabOnDispose,
        super('tabs.commentators_prefix'
            .tr(namedArgs: {'source': sourceTab.title}));

  /// שחזור מ-JSON — בונה sourceTab חדש מהנתונים השמורים.
  factory PdfCommentatorsTab.fromJson(Map<String, dynamic> json) {
    final rawSourceTab = json['sourceTab'];
    final Map<String, dynamic> sourceJson = rawSourceTab is Map
        ? Map<String, dynamic>.from(rawSourceTab)
        : <String, dynamic>{};

    final sourceTab = PdfBookTab.fromJson(sourceJson);
    final active = (json['activeCommentators'] as List?)?.cast<String>();
    if (active != null) {
      sourceTab.activeCommentators = active.toSet();
    }

    return PdfCommentatorsTab(
      sourceTab: sourceTab,
      disposeSourceTabOnDispose: true,
    )..isPinned = json['isPinned'] ?? false;
  }

  @override
  OpenedTab clone() =>
      PdfCommentatorsTab(sourceTab: sourceTab)..isPinned = isPinned;

  @override
  void dispose() {
    if (_disposeSourceTabOnDispose) {
      sourceTab.dispose();
    }
    super.dispose();
  }

  @override
  Map<String, dynamic> toJson() => {
        'title': title,
        'type': 'PdfCommentatorsTab',
        'isPinned': isPinned,
        'sourceTab': sourceTab.toJson(),
        'activeCommentators': sourceTab.activeCommentators.toList(),
      };
}
