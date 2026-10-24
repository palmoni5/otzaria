import 'package:path/path.dart' as p;
import 'package:otzaria/core/app_paths.dart';
import 'package:otzaria/data/constants/database_constants.dart';
import 'plugin_database_registry.dart';
import 'plugin_database_source.dart';

const String pluginExternalCatalogSourceId = 'external_catalog';

/// אתחול מקורות נתונים SQLite לתוספים.
///
/// קוראת לפונקציה זו פעם אחת בזמן אתחול האפליקציה (מ-`initialize()` ב-main.dart).
/// היא רושמת את כל מסדי הנתונים שהאפליקציה מציעה לתוספים.
///
/// מקורות שקובץ ה-DB שלהם לא קיים — נרשמים עם הנתיב אך יסומנו כ-unavailable
/// בתגובה ל-`database.listSources`. אין crash.
Future<void> initPluginDatabaseSources() async {
  final libraryPath = await AppPaths.getLibraryPath();

  _registerTalmudSynopsis(libraryPath);
  PluginDatabaseRegistry.instance.register(
    buildExternalCatalogPluginSource(
      DatabaseConstants.getExternalCatalogDatabasePath(),
    ),
  );
}

PluginDatabaseSource buildExternalCatalogPluginSource(String databasePath) {
  return PluginDatabaseSource(
    sourceId: pluginExternalCatalogSourceId,
    label: 'קטלוגים חיצוניים',
    databasePath: databasePath,
    readOnly: true,
    policy: PluginDatabasePolicy(
      tables: const {'otzaria_hebrew_books', 'hebrew_books', 'otzar_hahochma'},
      columnsByTable: const {
        'otzaria_hebrew_books': {
          'hb_id',
          'otzaria_id',
          'otzaria_title',
          'is_best',
          'confidence',
        },
        'hebrew_books': {
          'id_book',
          'title',
          'author',
          'printing_place',
          'printing_year',
          'pub_date',
          'pages',
          'tags',
        },
        'otzar_hahochma': {
          'book_id',
          'title',
          'authors',
          'places',
          'from_year',
          'to_year',
          'subjects',
          'pages',
        },
      },
      allowedJoins: const [
        PluginJoinRule(
          tableA: 'otzaria_hebrew_books',
          columnA: 'hb_id',
          tableB: 'hebrew_books',
          columnB: 'id_book',
        ),
      ],
      // מכסות bulk-lookup: ספק תוצאות חיצוני ממפה אינדקס של עד ~10K מזהים
      // (hb_id → otzaria_id) בעת סיווג תוצאות לקטגוריות. השאילתות עצמן
      // זולות — IN על עמודה מאונדקסת בטבלת מיפוי — ולכן המגבלה המשמעותית
      // היא מספר המעברים על הגשר: 1000 ערכי IN × 10 שאילתות ב-batch אחד
      // מכסים אינדקס שלם בקריאה אחת במקום מאות.
      maxLimit: 1000,
      maxBatchQueries: 10,
      maxJoins: 1,
      maxColumns: 8,
      maxOffset: 0,
      maxWhereConditions: 8,
      maxInValues: 1000,
      maxParameterBytes: 16 * 1024,
      maxResultBytes: 256 * 1024,
    ),
  );
}

void _registerTalmudSynopsis(String libraryPath) {
  final dbPath = p.join(libraryPath, 'talmud_synopsis_pooled.db');

  // נרשם תמיד — ה-service יבדוק בזמן ריצה אם הקובץ קיים (available: true/false)
  PluginDatabaseRegistry.instance.register(
    PluginDatabaseSource(
      sourceId: 'talmud_synopsis',
      label: 'עדי נוסח בבלי',
      databasePath: dbPath,
      readOnly: true,
      filtersDivineNames: true,
      policy: PluginDatabasePolicy(
        tables: {
          'tractates',
          'pages',
          'witnesses',
          'alignments',
          'readings',
          'strings',
          'page_witnesses',
        },
        columnsByTable: {
          'tractates': {'id', 'sort_order', 'name_text_id'},
          'pages': {'id', 'tractate_id', 'sort_order', 'name_text_id'},
          'witnesses': {'id', 'name_text_id'},
          'alignments': {
            'id',
            'page_id',
            'kind',
            'sequence_number',
            'reference_text_id',
          },
          'readings': {'alignment_id', 'witness_id', 'text_text_id'},
          'strings': {'id', 'value'},
          'page_witnesses': {'page_id', 'kind', 'column_index', 'witness_id'},
        },
        allowedJoins: [
          PluginJoinRule(
            tableA: 'tractates',
            columnA: 'id',
            tableB: 'pages',
            columnB: 'tractate_id',
          ),
          PluginJoinRule(
            tableA: 'tractates',
            columnA: 'name_text_id',
            tableB: 'strings',
            columnB: 'id',
          ),
          PluginJoinRule(
            tableA: 'pages',
            columnA: 'name_text_id',
            tableB: 'strings',
            columnB: 'id',
          ),
          PluginJoinRule(
            tableA: 'pages',
            columnA: 'id',
            tableB: 'alignments',
            columnB: 'page_id',
          ),
          PluginJoinRule(
            tableA: 'alignments',
            columnA: 'reference_text_id',
            tableB: 'strings',
            columnB: 'id',
          ),
          PluginJoinRule(
            tableA: 'alignments',
            columnA: 'id',
            tableB: 'readings',
            columnB: 'alignment_id',
          ),
          PluginJoinRule(
            tableA: 'witnesses',
            columnA: 'id',
            tableB: 'readings',
            columnB: 'witness_id',
          ),
          PluginJoinRule(
            tableA: 'witnesses',
            columnA: 'name_text_id',
            tableB: 'strings',
            columnB: 'id',
          ),
          PluginJoinRule(
            tableA: 'readings',
            columnA: 'text_text_id',
            tableB: 'strings',
            columnB: 'id',
          ),
          PluginJoinRule(
            tableA: 'pages',
            columnA: 'id',
            tableB: 'page_witnesses',
            columnB: 'page_id',
          ),
          PluginJoinRule(
            tableA: 'witnesses',
            columnA: 'id',
            tableB: 'page_witnesses',
            columnB: 'witness_id',
          ),
        ],
        maxJoins: 8,
      ),
    ),
  );
}
