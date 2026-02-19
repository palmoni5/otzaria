# מערכת מסד נתונים SQLite לאוצריא

## סקירה כללית

תיקייה זו מכילה את התשתית המלאה למעבר ממערכת קבצים למסד נתונים SQLite.
המערכת מאפשרת אחסון יעיל של ספרים, שורות, תוכן עניינים, וקישורים במסד נתונים.

## מבנה התיקייה

```
migration/
├── adapters/           # מתאמים בין מודלים קיימים למודלים חדשים
│   └── model_adapters.dart
├── core/              # מודלים ו-extensions
│   ├── models/        # מודלי נתונים (Book, Line, TocEntry, וכו')
│   └── extentions/    # הרחבות עזר
├── dao/               # שכבת גישה לנתונים
│   ├── drift/         # DAOs לטבלאות שונות
│   ├── repository/    # Repository pattern
│   └── sqflite/       # שאילתות SQL
└── generator/         # כלים ליצירת מסד נתונים מקבצים
```

## רכיבים עיקריים

### 1. SqliteDataProvider
ממוקם ב-`lib/data/data_providers/sqlite_data_provider.dart`

מספק ממשק לגישה למסד הנתונים:
- בדיקה אם ספר קיים במסד הנתונים
- קריאת תוכן ספר מהמסד
- קריאת תוכן עניינים
- ייצוא וייבוא של מסד הנתונים
- סטטיסטיקות על המסד

### 2. SeforimRepository
ממוקם ב-`lib/migration/dao/repository/seforim_repository.dart`

מספק פעולות CRUD מלאות:
- ניהול ספרים, קטגוריות, שורות
- ניהול תוכן עניינים (TOC)
- ניהול קישורים בין ספרים
- חיפוש מתקדם
- אופטימיזציות לביצועים

### 3. Model Adapters
ממוקם ב-`lib/migration/adapters/model_adapters.dart`

ממירים בין:
- `migration_models.Book` ↔ `otzaria_models.TextBook`
- `migration_models.TocEntry` ↔ `otzaria_models.TocEntry`
- `migration_models.Category` ↔ `otzaria_lib.Category`

### 4. DatabaseGenerator
ממוקם ב-`lib/migration/generator/generator.dart`

כלי להמרת קבצים למסד נתונים:
- קריאת metadata.json
- עיבוד תיקיות וקבצים
- יצירת מבנה קטגוריות
- פירסור תוכן עניינים
- יבוא קישורים

## סכימת מסד הנתונים

### טבלאות עיקריות:
- `book` - ספרים
- `line` - שורות טקסט
- `tocEntry` - ערכי תוכן עניינים
- `category` - קטגוריות
- `link` - קישורים בין ספרים
- `author`, `topic`, `pub_place`, `pub_date` - מטא-דאטה

### טבלאות עזר:
- `category_closure` - עץ קטגוריות (ancestor-descendant)
- `line_toc` - מיפוי שורות לתוכן עניינים
- `book_has_links` - אינדיקטורים לקישורים
- `connection_type` - סוגי קישורים

## שימוש בסיסי

### אתחול
```dart
final sqliteProvider = SqliteDataProvider.instance;
await sqliteProvider.initialize();
```

### בדיקה אם ספר במסד נתונים
```dart
final isInDb = await sqliteProvider.isBookInDatabase('שם הספר');
```

### קריאת תוכן ספר
```dart
final text = await sqliteProvider.getBookTextFromDb('שם הספר');
```

### קריאת תוכן עניינים
```dart
final toc = await sqliteProvider.getBookTocFromDb('שם הספר');
```

## תלויות נדרשות

כל התלויות הנדרשות כבר קיימות ב-`pubspec.yaml`:
- `sqflite: ^2.4.2`
- `sqflite_common_ffi: ^2.3.0`
- `logging: ^1.3.0`
- `path: ^1.9.0`

## שלבים הבאים

1. ✅ **שלב 1 הושלם**: העתקת תשתית מסד הנתונים
2. 🔄 **שלב 2**: יצירת Data Provider משולב (DB + קבצים)
3. 🔄 **שלב 3**: הרחבת מנגנון הסנכרון
4. 🔄 **שלב 4**: סימון מקור הנתונים בUI
5. 🔄 **שלב 5**: תמיכה בקבצים אישיים
6. 🔄 **שלב 6**: יכולות ייצוא/ייבוא

## הערות חשובות

- מסד הנתונים נוצר ב-`{library_path}/ספרייה/otzaria.db`
- המערכת תומכת בתאימות לאחור - ספרים שלא במסד ייקראו מקבצים
- כל הפעולות מבוצעות בצורה אסינכרונית
- יש תמיכה מלאה ב-transactions לביצועים מיטביים

## מנגנון קטגוריות - תיאור מעמיק

### הקמה ראשונית של מסד הנתונים

בעת יצירת ה-DB לראשונה, המערכת מקבלת כקלט את **הנתיב הראשי לתיקיית אוצריא**.

#### בניית היררכיית הקטגוריות:
1. **קטגוריות ראשיות** - כל התיקיות תחת תיקיית אוצריא הן קטגוריות ראשיות (parentId = null)
2. **קטגוריות משנה** - נבנות לפי ההיררכיה של התיקיות במערכת הקבצים
3. **מזהי קטגוריות** - מספר רץ (auto-increment) המוקצה לכל קטגוריה חדשה

#### מבנה טבלת `category`:
| עמודה | תיאור |
|--------|--------|
| `id` | מזהה ייחודי (מספר רץ) |
| `parentId` | מזהה קטגוריית האב (null לקטגוריות ראשיות) |
| `name` | שם הקטגוריה |

#### דוגמה למבנה:
```
אוצריא/
├── לימוד יומי/         → category(id=1, parentId=null, name="לימוד יומי")
│   └── חוק לישראל/     → category(id=2, parentId=1, name="חוק לישראל")

```

### ניקוי לאחר בניית ה-DB

לאחר סיום בניית מסד הנתונים:
- ✅ **קבצי TXT** - נמחקים (התוכן כבר במסד)
- ✅ **תיקיות ריקות** - נמחקות
- ❌ **קבצי PDF** - נשארים במקומם תחת ההיררכיה המקורית

### זיהוי שינויים ועדכונים

כאשר המערכת מזהה קובץ TXT חדש תחת תיקיית אוצריא, היא מבצעת:

#### שלב 1: בדיקת קיום הקטגוריה
המערכת בודקת האם קיימת קטגוריה מתאימה לפי **שרשרת ההיררכיה המלאה**.

**דוגמה:**
```
נתיב קובץ: אוצריא\לימוד יומי\חוק לישראל\חק לישראל - בראשית.txt
```

המערכת מחפשת:
1. האם קיימת קטגוריה "חוק לישראל"?
2. האם הקטגוריה הזו נמצאת תחת "לימוד יומי"?

#### שלב 2: החלטה - עדכון או הוספה

| מצב | פעולה |
|-----|-------|
| **קטגוריה קיימת + ספר קיים** | עדכון תוכן הספר והכותרות |
| **קטגוריה קיימת + ספר חדש** | הוספת הספר לקטגוריה הקיימת |
| **קטגוריה לא קיימת** | יצירת קטגוריה חדשה + הוספת הספר |

#### שלב 3: הוספת קטגוריה חדשה

אם נדרשת קטגוריה חדשה:

```dart
// 1. שליפת המזהה הגבוה ביותר הקיים
final maxId = await db.rawQuery('SELECT MAX(id) FROM category');

// 2. יצירת מזהה חדש
final newId = maxId + 1;

// 3. הוספת הקטגוריה עם הפניה לקטגוריית האב
await db.insert('category', {
  'id': newId,
  'parentId': parentCategoryId,
  'name': categoryName
});
```

### אלגוריתם מלא לזיהוי קטגוריה

```dart
Future<int> findOrCreateCategory(List<String> pathParts) async {
  int? currentParentId = null;
  
  for (final part in pathParts) {
    // חיפוש קטגוריה קיימת עם אותו שם ואב
    final existing = await db.query('category',
      where: 'name = ? AND parentId ${currentParentId == null ? 'IS NULL' : '= ?'}',
      whereArgs: currentParentId == null ? [part] : [part, currentParentId]
    );
    
    if (existing.isNotEmpty) {
      // קטגוריה קיימת - המשך לרמה הבאה
      currentParentId = existing.first['id'] as int;
    } else {
      // קטגוריה לא קיימת - צור חדשה
      final maxId = await getMaxCategoryId();
      final newId = maxId + 1;
      
      await db.insert('category', {
        'id': newId,
        'parentId': currentParentId,
        'name': part
      });
      
      currentParentId = newId;
    }
  }
  
  return currentParentId!;
}
```

## תיעוד נוסף

לתיעוד מפורט יותר, ראה:
- `generator/README.md` - תיעוד על תהליך ההמרה
- `dao/repository/seforim_repository.dart` - תיעוד API מלא
- `CATEGORY_SYNC_PLAN.md` - תכנון מפורט למימוש סנכרון קטגוריות
