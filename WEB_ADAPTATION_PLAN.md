# תוכנית התאמת אוצריא לפלטפורמת Web

## סקירה כללית

פרויקט אוצריא הוא אפליקציית Flutter לספרייה יהודית דיגיטלית. כרגע הפרויקט תומך ב-Windows, Linux, Android, iOS ו-macOS.
המטרה: להתאים את האפליקציה לפלטפורמת Web תוך שמירה על תאימות לפלטפורמות הקיימות.

## עקרונות מנחים

1. **שכבת הפשטה (Abstraction Layer)** - יצירת ממשקים שיאפשרו החלפת מימושים בין פלטפורמות
2. **Conditional Imports** - שימוש ב-`dart:io` רק בפלטפורמות שתומכות בו
3. **Feature Detection** - בדיקת תמיכה בפיצ'רים במקום בדיקת פלטפורמה
4. **Progressive Enhancement** - פונקציונליות בסיסית לכולם, פיצ'רים מתקדמים לפי יכולת
5. **שמירה על תאימות אחורה** - כל שינוי חייב לעבוד גם על הפלטפורמות הקיימות

## סיכום מצב נוכחי

### ✅ תומך בווב כרגע
- מבנה UI בסיסי (Flutter widgets)
- BLoC pattern לניהול state
- RTL support
- רוב ה-widgets המותאמים אישית

### ❌ לא תומך בווב - דורש התאמה
- אחסון מקומי (Isar, SQLite)
- גישה למערכת קבצים
- ניהול חלונות
- פונטים של המערכת
- תצוגת PDF (pdfrx)
- העלאה/הורדה של קבצים


---

## חלק 1: אחסון נתונים (Storage Layer)

### 1.1 מצב נוכחי

#### Isar Database
**קבצים מושפעים:**
- `lib/models/isar_collections/ref.dart`
- `lib/models/isar_collections/line.dart`
- `lib/utils/ref_helper.dart`
- `lib/data/repository/data_repository.dart`

**בעיה:** Isar לא תומך בווב באופן רשמי.

**פתרון:**
1. Hive תומך בווב דרך IndexedDB - כבר בשימוש חלקי בפרויקט
2. יצירת שכבת הפשטה `DatabaseProvider` עם מימושים שונים:
   - `IsarDatabaseProvider` - לדסקטופ/מובייל
   - `HiveDatabaseProvider` - לווב

**שלבי ביצוע:**
- [ ] יצירת ממשק `DatabaseProvider` abstract
- [ ] מימוש `HiveDatabaseProvider` לווב
- [ ] המרת מודלים מ-Isar ל-Hive (TypeAdapter)
- [ ] עדכון `data_repository.dart` לעבוד עם שכבת ההפשטה
- [ ] בדיקות יחידה למימושים השונים

#### SQLite Database
**קבצים מושפעים:**
- `lib/personal_notes/storage/personal_notes_database.dart`
- `lib/migration/dao/daos/database.dart`
- כל הקבצים ב-`lib/migration/dao/`
- `lib/tools/gematria/gematria_search.dart`
- `lib/find_ref/find_ref_repository.dart`

**בעיה:** SQLite לא זמין בווב (sqflite_common_ffi לא עובד בדפדפן).

**פתרון:**
1. שימוש ב-`sql.js` דרך `package:sqlite3_web`
2. או מעבר ל-Hive/IndexedDB לפתרון אחיד
3. יצירת `SqlProvider` abstract עם מימושים:
   - `NativeSqlProvider` - sqflite לדסקטופ/מובייל
   - `WebSqlProvider` - sqlite3_web לווב

**שלבי ביצוע:**
- [x] הוספת `sqlite3_web` ל-pubspec.yaml ✅ הושלם
- [x] יצירת ממשק `SqlProvider` ✅ הושלם
- [x] מימוש `WebSqlProvider` ✅ הושלם
- [ ] עדכון `PersonalNotesDatabase` לעבוד עם שכבת ההפשטה
- [ ] עדכון `MyDatabase` במיגרציה
- [ ] בדיקות תאימות

#### Hive (כבר תומך בווב!)
**קבצים:**
- `lib/data/data_providers/hive_data_provider.dart`
- `lib/main.dart` (initHive)

**מצב:** ✅ כבר תומך בווב דרך IndexedDB

**התאמות נדרשות:**
- [x] הסרת תלות ב-`path_provider` בווב (Hive.defaultDirectory) ✅ הושלם
- [x] שימוש ב-conditional import ✅ הושלם

```dart
// lib/data/data_providers/hive_data_provider_io.dart
import 'package:path_provider/path_provider.dart';

Future<void> initHive() async {
  final dir = await getApplicationSupportDirectory();
  Hive.defaultDirectory = dir.path;
}

// lib/data/data_providers/hive_data_provider_web.dart
Future<void> initHive() async {
  // Hive uses IndexedDB automatically on web
  // No directory needed
}

// lib/data/data_providers/hive_data_provider.dart
export 'hive_data_provider_stub.dart'
    if (dart.library.io) 'hive_data_provider_io.dart'
    if (dart.library.html) 'hive_data_provider_web.dart';
```

### 1.2 אסטרטגיית מעבר

**שלב א: הכנה**
1. יצירת ממשקים מופשטים לכל סוגי האחסון
2. עטיפה של הקוד הקיים במימושים ספציפיים לפלטפורמה

**שלב ב: מימוש Web**
1. מימוש providers לווב
2. בדיקות יחידה

**שלב ג: אינטגרציה**
1. עדכון כל הקוד שמשתמש באחסון
2. בדיקות אינטגרציה
3. בדיקות על כל הפלטפורמות

---

## חלק 2: מערכת קבצים (File System)

### 2.1 מצב נוכחי

#### path_provider
**קבצים מושפעים (18 קבצים):**
- `lib/core/app_paths.dart` ⚠️ קריטי
- `lib/main.dart`
- `lib/data/data_providers/hive_data_provider.dart`
- `lib/settings/per_book_settings.dart`
- `lib/text_book/editing/repository/local_overrides_repository.dart`
- `lib/library/view/book_preview_panel.dart`
- `lib/daf_yomi/daf_yomi_helper.dart`
- `lib/update/linux_installer.dart`
- `lib/pdf_book/pdf_book_screen.dart`

**בעיה:** אין מערכת קבצים מקומית בווב.

**פתרון:**
1. **לקריאה:** העלאת ספרים דרך File API או fetch מ-CDN/Server
2. **לכתיבה:** שימוש ב-IndexedDB/LocalStorage
3. **לשיתוף:** File System Access API (Chrome/Edge בלבד)

**אסטרטגיה:**

```dart
// lib/core/storage/storage_provider.dart
abstract class StorageProvider {
  Future<String> readBook(String bookId);
  Future<void> writeUserData(String key, String data);
  Future<List<String>> listBooks();
  Future<bool> bookExists(String bookId);
}

// lib/core/storage/file_storage_provider.dart (Desktop/Mobile)
class FileStorageProvider implements StorageProvider {
  // Uses dart:io File, Directory
}

// lib/core/storage/web_storage_provider.dart (Web)
class WebStorageProvider implements StorageProvider {
  // Uses IndexedDB for data
  // Uses fetch/FileReader for books
}
```

**שלבי ביצוע:**
- [x] יצירת `StorageProvider` abstract ✅ הושלם
- [x] מימוש `FileStorageProvider` (עטיפה של הקוד הקיים) ✅ הושלם
- [x] מימוש `WebStorageProvider` ✅ הושלם (מימוש בסיסי עם cache בזיכרון)
- [ ] עדכון `app_paths.dart` לעבוד עם שכבת ההפשטה
- [ ] עדכון כל הקוד שקורא/כותב קבצים
- [ ] מנגנון העלאה/הורדה של ספרים בווב

#### גישה ישירה לקבצים
**קבצים מושפעים:**
- `lib/data/repository/books_repository.dart`
- `lib/text_book/text_book_repository.dart`
- `lib/utils/extraction.dart`
- `lib/utils/zip_extractor_service.dart`
- `lib/utils/docx_to_otzaria.dart`

**בעיה:** שימוש ישיר ב-`dart:io` (File, Directory).

**פתרון:**
- Conditional imports
- שכבת הפשטה `FileSystemService`

```dart
// lib/utils/file_system_service.dart
export 'file_system_service_stub.dart'
    if (dart.library.io) 'file_system_service_io.dart'
    if (dart.library.html) 'file_system_service_web.dart';

abstract class FileSystemService {
  Future<String> readAsString(String path);
  Future<List<int>> readAsBytes(String path);
  Future<void> writeAsString(String path, String content);
  Future<bool> exists(String path);
  Stream<String> listFiles(String directory);
}
```

### 2.2 ניהול ספרייה בווב

**אתגר:** בווב אין גישה לספרייה מקומית של ספרים.

**פתרונות אפשריים:**

**אופציה 1: CDN/Server**
- ספרים מאוחסנים בשרת
- האפליקציה מורידה לפי דרישה
- שימוש ב-Service Worker לקאשינג
- ✅ פשוט למשתמש
- ❌ דורש שרת ורוחב פס

**אופציה 2: File Upload**
- משתמש מעלה ספרים דרך file picker
- שמירה ב-IndexedDB
- ✅ פרטיות מלאה
- ❌ משתמש צריך להעלות כל פעם

**אופציה 3: Hybrid**
- ספרייה בסיסית מהשרת
- אפשרות להעלות ספרים נוספים
- ✅ איזון בין נוחות לפרטיות
- ⚠️ מורכב יותר

**המלצה:** התחלה עם אופציה 3

**שלבי ביצוע:**
- [ ] יצירת API לשרת ספרים (אופציונלי)
- [ ] מנגנון העלאה של ספרים בווב
- [ ] שמירת ספרים ב-IndexedDB
- [ ] Service Worker לקאשינג
- [ ] UI לניהול ספרים בווב

---

## חלק 3: ניהול חלונות (Window Management)

### 3.1 מצב נוכחי

**קבצים מושפעים:**
- `lib/core/window_listener.dart`
- `lib/core/window_persistence.dart`
- `lib/navigation/main_window_screen.dart`
- `lib/navigation/custom_title_bar.dart`
- `lib/widgets/window_controls.dart`
- `lib/utils/fullscreen_helper.dart`
- `lib/settings/tabs/advanced_settings_tab.dart`
- `lib/settings/tabs/backup_settings_tab.dart`
- `lib/update/hebrew_updat_examples.dart`
- `lib/update/my_updat_widget.dart`
- `lib/main.dart`

**בעיה:** `window_manager` לא עובד בווב.

**פתרון:**
1. Conditional imports
2. הסתרת פיצ'רים ספציפיים לדסקטופ בווב
3. שימוש ב-Fullscreen API של הדפדפן

**שלבי ביצוע:**

```dart
// lib/core/window/window_manager_service.dart
export 'window_manager_stub.dart'
    if (dart.library.io) 'window_manager_io.dart'
    if (dart.library.html) 'window_manager_web.dart';

abstract class WindowManagerService {
  Future<void> setFullScreen(bool fullscreen);
  Future<bool> isFullScreen();
  Future<void> minimize();
  Future<void> close();
  // ... other methods
}

// lib/core/window/window_manager_web.dart
import 'dart:html' as html;

class WindowManagerService {
  Future<void> setFullScreen(bool fullscreen) async {
    if (fullscreen) {
      html.document.documentElement?.requestFullscreen();
    } else {
      html.document.exitFullscreen();
    }
  }
  
  Future<void> minimize() async {
    // Not supported in web
  }
  
  Future<void> close() async {
    html.window.close(); // May not work due to browser restrictions
  }
}
```

**רשימת משימות:**
- [x] יצירת `WindowManagerService` abstract ✅ הושלם
- [x] מימוש לדסקטופ (עטיפה של window_manager) ✅ הושלם
- [x] מימוש לווב (Fullscreen API) ✅ הושלם
- [ ] עדכון כל הקוד שמשתמש ב-windowManager
- [ ] הסתרת כפתורי חלון בווב
- [ ] התאמת CustomTitleBar לווב

### 3.2 UI Adjustments

**שינויים נדרשים:**
- הסתרת window controls בווב
- התאמת title bar
- הסרת אפשרויות minimize/maximize
- שמירת רק fullscreen (דרך Fullscreen API)

---

## חלק 4: תצוגת PDF

### 4.1 מצב נוכחי

**חבילה:** `pdfrx: ^2.2.24`

**קבצים מושפעים:**
- `lib/pdf_book/pdf_book_screen.dart`
- `lib/pdf_book/pdf_commentary_panel.dart`
- `lib/pdf_book/pdf_outlines_screen.dart`
- `lib/pdf_book/pdf_thumbnails_screen.dart`
- `lib/library/view/book_preview_panel.dart`
- `lib/daf_yomi/daf_yomi_helper.dart`

**בדיקה נדרשת:** האם pdfrx תומך בווב?

✅ **pdfrx תומך בווב!** החבילה תומכת ב-Android, iOS, Windows, macOS, Linux, ו-Web (WASM).

**שלבי ביצוע:**
- [x] בדיקת תמיכת pdfrx בווב ✅ תומך!
- [ ] אם לא תומך: מציאת חלופה (לא נדרש - pdfrx תומך)
- [ ] יצירת `PdfViewerService` abstract (לא נדרש - pdfrx עובד על כל הפלטפורמות)
- [ ] מימושים שונים לפלטפורמות (לא נדרש)
- [ ] עדכון כל מסכי ה-PDF (לא נדרש - pdfrx כבר עובד)

---

## חלק 5: פונטים

### 5.1 מצב נוכחי

**קבצים:**
- `lib/constants/fonts.dart`
- `pubspec.yaml` (fonts section)

**בעיה:** שימוש ב-`system_fonts` package שלא תומך בווב.

**פתרון:**
1. בווב: שימוש בפונטים המוגדרים ב-pubspec.yaml בלבד
2. Conditional import

```dart
// lib/constants/fonts_io.dart
import 'package:system_fonts/system_fonts.dart';

Future<List<String>> getSystemFonts() async {
  return await SystemFonts.getFonts();
}

// lib/constants/fonts_web.dart
Future<List<String>> getSystemFonts() async {
  return []; // No system fonts on web
}

// lib/constants/fonts.dart
export 'fonts_stub.dart'
    if (dart.library.io) 'fonts_io.dart'
    if (dart.library.html) 'fonts_web.dart';
```

**שלבי ביצוע:**
- [x] יצירת conditional imports לפונטים ✅ הושלם
- [x] עדכון `fonts.dart` ✅ הושלם
- [x] וידוא שכל הפונטים הנדרשים ב-pubspec.yaml ✅ הושלם
- [ ] בדיקת תצוגה בווב


---

## חלק 6: חבילות ותלויות נוספות

### 6.1 חבילות שלא תומכות בווב

#### file_picker
**מצב:** תומך בווב! ✅
**שימוש:** בחירת קבצים להעלאה
**התאמה נדרשת:** אין

#### flutter_document_picker
**מצב:** לא תומך בווב ❌
**פתרון:** שימוש ב-file_picker במקום (שכבר בשימוש)

#### archive (zip/unzip)
**מצב:** תומך בווב! ✅
**שימוש:** חילוץ קבצי ZIP
**התאמה נדרשת:** אין

#### printing
**מצב:** תומך בווב! ✅
**שימוש:** הדפסה
**התאמה נדרשת:** אין

#### flutter_single_instance
**מצב:** לא תומך בווב ❌
**פתרון:** לא רלוונטי בווב (כל טאב הוא instance נפרד)
**שלבי ביצוע:**
- [ ] Conditional import
- [ ] דילוג על האתחול בווב

#### super_clipboard
**מצב:** תומך בווב! ✅
**שימוש:** העתקה ללוח
**התאמה נדרשת:** אין

#### url_launcher
**מצב:** תומך בווב! ✅
**שימוש:** פתיחת קישורים
**התאמה נדרשת:** אין

### 6.2 סיכום תלויות

| חבילה | תמיכה בווב | פעולה נדרשת |
|-------|------------|-------------|
| `isar` | ❌ | החלפה ב-Hive |
| `sqflite` | ❌ | שימוש ב-sqlite3_web |
| `path_provider` | ❌ | Conditional imports |
| `window_manager` | ❌ | Conditional imports + Fullscreen API |
| `system_fonts` | ❌ | Conditional imports |
| `pdfrx` | ❓ | בדיקה נדרשת |
| `flutter_single_instance` | ❌ | דילוג בווב |
| `hive` | ✅ | אין |
| `file_picker` | ✅ | אין |
| `archive` | ✅ | אין |
| `printing` | ✅ | אין |
| `super_clipboard` | ✅ | אין |
| `url_launcher` | ✅ | אין |

---

## חלק 7: פיצ'רים ספציפיים

### 7.1 חיפוש (Search)

**קבצים:**
- `lib/search/search_repository.dart`
- `lib/search/bloc/`
- `search_engine` package

**מצב:** תלוי באחסון

**התאמות נדרשות:**
- [ ] עדכון לעבוד עם שכבת האחסון החדשה
- [ ] בדיקת ביצועים בווב
- [ ] שיקולים לאינדקס חיפוש (IndexedDB)

### 7.2 הערות אישיות (Personal Notes)

**קבצים:**
- `lib/personal_notes/storage/personal_notes_database.dart`
- `lib/personal_notes/repository/personal_notes_repository.dart`
- `lib/personal_notes/migration/file_to_db_migrator.dart`

**בעיה:** תלוי ב-SQLite

**פתרון:**
- [ ] מעבר ל-Hive או sqlite3_web
- [ ] עדכון migration logic
- [ ] בדיקות

### 7.3 סימניות (Bookmarks)

**קבצים:**
- `lib/bookmarks/repository/bookmark_repository.dart`

**מצב:** תלוי באחסון

**התאמות נדרשות:**
- [ ] עדכון לעבוד עם שכבת האחסון החדשה

### 7.4 היסטוריה (History)

**קבצים:**
- `lib/history/history_repository.dart`

**מצב:** תלוי באחסון

**התאמות נדרשות:**
- [ ] עדכון לעבוד עם שכבת האחסון החדשה

### 7.5 סנכרון קבצים (File Sync)

**קבצים:**
- `lib/file_sync/file_sync_repository.dart`
- `lib/file_sync/file_sync_widget.dart`

**בעיה:** תלוי במערכת קבצים מקומית

**פתרון:**
- [ ] בווב: סנכרון עם שרת או Google Drive
- [ ] שימוש ב-Google Drive API (כבר קיים בפרויקט)
- [ ] עדכון UI להתאים לווב

### 7.6 עדכונים (Updates)

**קבצים:**
- `lib/update/my_updat_widget.dart`
- `lib/update/linux_installer.dart`

**בעיה:** לא רלוונטי בווב

**פתרון:**
- [ ] הסתרת פיצ'ר עדכונים בווב
- [ ] הצגת הודעה על גרסה חדשה (אופציונלי)

### 7.7 כלים (Tools)

#### גימטריה
**קבצים:** `lib/tools/gematria/`
**מצב:** תלוי באחסון
**התאמה:** עדכון לעבוד עם שכבת האחסון

#### מילונים
**קבצים:** `lib/tools/dictionary/`, `lib/tools/aramaic_dictionary/`
**מצב:** תלוי בקבצי JSON
**התאמה:** טעינה מ-assets או fetch מהשרת

#### שמור וזכור
**קבצים:** `lib/tools/shamor_zachor/`
**מצב:** תלוי באחסון ו-PDF
**התאמה:** עדכון לעבוד עם שכבות ההפשטה

---

## חלק 8: תהליך העבודה המומלץ

### שלב 1: תשתית בסיסית (2-3 שבועות)

**מטרה:** יצירת שכבות הפשטה בסיסיות

1. **אחסון**
   - [ ] יצירת `StorageProvider` abstract
   - [ ] מימוש `FileStorageProvider` (עטיפה)
   - [ ] מימוש `WebStorageProvider`
   - [ ] בדיקות יחידה

2. **מסד נתונים**
   - [ ] יצירת `DatabaseProvider` abstract
   - [ ] מימוש `HiveDatabaseProvider`
   - [ ] המרת מודלים
   - [ ] בדיקות יחידה

3. **ניהול חלונות**
   - [ ] יצירת `WindowManagerService` abstract
   - [ ] מימוש לדסקטופ (עטיפה)
   - [ ] מימוש לווב
   - [ ] בדיקות יחידה

### שלב 2: אינטגרציה (3-4 שבועות)

**מטרה:** עדכון כל הקוד הקיים לעבוד עם שכבות ההפשטה

1. **Core**
   - [ ] עדכון `app_paths.dart`
   - [ ] עדכון `main.dart`
   - [ ] עדכון data providers

2. **Repositories**
   - [ ] עדכון `books_repository.dart`
   - [ ] עדכון `text_book_repository.dart`
   - [ ] עדכון כל ה-repositories

3. **UI**
   - [ ] עדכון `custom_title_bar.dart`
   - [ ] עדכון `window_controls.dart`
   - [ ] הסתרת פיצ'רים לא רלוונטיים

### שלב 3: פיצ'רים ספציפיים (2-3 שבועות)

1. **PDF**
   - [ ] בדיקת pdfrx
   - [ ] מציאת חלופה אם נדרש
   - [ ] עדכון כל מסכי PDF

2. **חיפוש**
   - [ ] עדכון search engine
   - [ ] אופטימיזציה לווב

3. **כלים**
   - [ ] עדכון גימטריה
   - [ ] עדכון מילונים
   - [ ] עדכון שמור וזכור

### שלב 4: ניהול ספרים בווב (2-3 שבועות)

1. **העלאה**
   - [ ] UI להעלאת ספרים
   - [ ] שמירה ב-IndexedDB
   - [ ] ניהול מטא-דאטה

2. **הורדה מהשרת (אופציונלי)**
   - [ ] API לשרת ספרים
   - [ ] Service Worker לקאשינג
   - [ ] UI לניהול

### שלב 5: בדיקות ואופטימיזציה (2-3 שבועות)

1. **בדיקות**
   - [ ] בדיקות יחידה לכל המימושים
   - [ ] בדיקות אינטגרציה
   - [ ] בדיקות על כל הפלטפורמות
   - [ ] בדיקות ביצועים בווב

2. **אופטימיזציה**
   - [ ] אופטימיזציית גודל bundle
   - [ ] lazy loading
   - [ ] Service Worker
   - [ ] PWA features

3. **תיעוד**
   - [ ] עדכון README
   - [ ] מדריך למפתחים
   - [ ] מדריך למשתמשים

---

## חלק 9: אתגרים צפויים ופתרונות

### 9.1 ביצועים

**אתגר:** ווב איטי יותר מאפליקציה native

**פתרונות:**
- Web Workers לעיבוד כבד
- Lazy loading של ספרים
- Service Worker לקאשינג
- Code splitting
- Tree shaking

### 9.2 גודל האפליקציה

**אתגר:** Flutter web יוצר bundle גדול

**פתרונות:**
- `--split-debug-info`
- `--obfuscate`
- Deferred loading
- הסרת תלויות מיותרות
- Compression (gzip/brotli)

### 9.3 תאימות דפדפנים

**אתגר:** לא כל הדפדפנים תומכים בכל הפיצ'רים

**פתרונות:**
- Feature detection
- Polyfills
- Graceful degradation
- הודעות למשתמש

### 9.4 אבטחה

**אתגר:** ווב פחות מאובטח

**פתרונות:**
- HTTPS חובה
- Content Security Policy
- הצפנת נתונים רגישים
- Secure cookies
- CORS configuration

### 9.5 אחסון מוגבל

**אתגר:** IndexedDB מוגבל בגודל

**פתרונות:**
- דחיסת נתונים
- ניקוי cache ישן
- בקשת quota נוסף
- הורדה לפי דרישה

---

## חלק 10: קבצים קריטיים לעדכון

### עדיפות גבוהה (חובה)

1. **lib/main.dart**
   - אתחול conditional
   - הסרת window_manager בווב
   - הסרת sqflite_ffi בווב

2. **lib/core/app_paths.dart**
   - שכבת הפשטה למסלולים
   - conditional imports

3. **lib/data/data_providers/**
   - עדכון כל ה-providers
   - תמיכה בווב

4. **lib/data/repository/books_repository.dart**
   - שימוש בשכבת ההפשטה
   - תמיכה בווב

5. **lib/models/isar_collections/**
   - המרה ל-Hive או שכבת הפשטה

### עדיפות בינונית

6. **lib/navigation/custom_title_bar.dart**
   - הסתרת window controls בווב

7. **lib/pdf_book/**
   - תמיכה ב-PDF בווב

8. **lib/search/**
   - אופטימיזציה לווב

9. **lib/personal_notes/**
   - מעבר מ-SQLite

10. **lib/settings/**
    - הסתרת הגדרות לא רלוונטיות

### עדיפות נמוכה

11. **lib/tools/**
    - עדכון כלים
    - אופטימיזציה

12. **lib/update/**
    - הסתרה בווב

13. **lib/printing/**
    - בדיקת תאימות

---

## חלק 11: תצורת Build

### pubspec.yaml

**תוספות נדרשות:**

```yaml
dependencies:
  # Web support
  sqlite3_web: ^0.1.0  # אם משתמשים ב-SQLite בווב
  
  # אופציונלי - PWA
  flutter_pwa: ^0.1.0

dependency_overrides:
  # אם יש בעיות תאימות
```

### web/index.html

**עדכונים נדרשים:**

```html
<!DOCTYPE html>
<html dir="rtl" lang="he">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="description" content="אוצריא - ספרייה יהודית דיגיטלית">
  
  <!-- PWA -->
  <link rel="manifest" href="manifest.json">
  <meta name="theme-color" content="#0175C2">
  
  <!-- Icons -->
  <link rel="icon" type="image/png" href="favicon.png"/>
  <link rel="apple-touch-icon" href="icons/Icon-192.png">
  
  <title>אוצריא</title>
</head>
<body>
  <script src="flutter.js" defer></script>
  
  <!-- Loading indicator -->
  <div id="loading">
    <div class="spinner"></div>
    <p>טוען את אוצריא...</p>
  </div>
  
  <script>
    window.addEventListener('load', function(ev) {
      _flutter.loader.loadEntrypoint({
        serviceWorker: {
          serviceWorkerVersion: serviceWorkerVersion,
        },
        onEntrypointLoaded: function(engineInitializer) {
          engineInitializer.initializeEngine().then(function(appRunner) {
            // Hide loading
            document.getElementById('loading').style.display = 'none';
            appRunner.runApp();
          });
        }
      });
    });
  </script>
</body>
</html>
```

### web/manifest.json

**עדכון:**

```json
{
  "name": "אוצריא - ספרייה יהודית דיגיטלית",
  "short_name": "אוצריא",
  "start_url": ".",
  "display": "standalone",
  "background_color": "#FFFFFF",
  "theme_color": "#0175C2",
  "description": "ספרייה יהודית דיגיטלית עם אפשרויות חיפוש חכם",
  "orientation": "any",
  "dir": "rtl",
  "lang": "he",
  "icons": [
    {
      "src": "icons/Icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "icons/Icon-512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ]
}
```

---

## חלק 12: פקודות Build

### Development

```bash
# Build לווב (development)
flutter build web --web-renderer canvaskit --source-maps

# Run בדפדפן
flutter run -d chrome --web-renderer canvaskit
```

### Production

```bash
# Build לווב (production)
flutter build web \
  --release \
  --web-renderer canvaskit \
  --base-href "/" \
  --pwa-strategy offline-first

# עם אופטימיזציות
flutter build web \
  --release \
  --web-renderer canvaskit \
  --split-debug-info=build/web \
  --obfuscate \
  --tree-shake-icons
```

### בדיקות

```bash
# בדיקות על כל הפלטפורמות
flutter test

# בדיקות ספציפיות לווב
flutter test --platform chrome

# ניתוח
flutter analyze

# פורמט
dart format lib/
```

---

## חלק 13: סיכום והמלצות

### מה כן אפשרי

✅ אפליקציה מלאה בווב עם רוב הפיצ'רים
✅ חיפוש מתקדם
✅ קריאת ספרים (טקסט)
✅ הערות אישיות
✅ סימניות והיסטוריה
✅ כלים (גימטריה, מילונים)
✅ RTL מלא
✅ PWA עם offline support

### מה דורש עבודה

⚠️ תצוגת PDF (תלוי ב-pdfrx או חלופה)
⚠️ ביצועים (דורש אופטימיזציה)
⚠️ ניהול ספרים (דורש UI חדש)
⚠️ אחסון מוגבל (דורש ניהול)

### מה לא אפשרי/לא רלוונטי

❌ ניהול חלונות מלא
❌ עדכונים אוטומטיים
❌ גישה חופשית למערכת קבצים
❌ פונטים של המערכת

### זמן משוער

- **מינימום (פונקציונליות בסיסית):** 6-8 שבועות
- **מלא (כל הפיצ'רים):** 10-14 שבועות
- **עם אופטימיזציה ובדיקות:** 12-16 שבועות

### המלצה סופית

הפרויקט **ניתן להתאמה לווב** אבל דורש עבודה משמעותית. מומלץ:

1. להתחיל עם MVP - פונקציונליות בסיסית
2. לבנות בהדרגה
3. לשמור על תאימות אחורה
4. לבדוק ביצועים בכל שלב
5. לתעדף פיצ'רים לפי חשיבות

**הצלחה! 🚀**

