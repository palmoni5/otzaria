/// שכבת הפשטה למסד נתונים
/// מאפשרת החלפה בין Isar (Desktop/Mobile) ל-Hive (Web)
abstract class DatabaseProvider {
  /// אתחול מסד הנתונים
  Future<void> initialize();
  
  /// סגירת מסד הנתונים
  Future<void> close();
  
  /// שמירת אובייקט
  Future<void> put<T>(String collection, dynamic key, T value);
  
  /// קריאת אובייקט
  Future<T?> get<T>(String collection, dynamic key);
  
  /// מחיקת אובייקט
  Future<void> delete(String collection, dynamic key);
  
  /// קריאת כל האובייקטים בקולקציה
  Future<List<T>> getAll<T>(String collection);
  
  /// שאילתה עם פילטר
  Future<List<T>> query<T>(
    String collection, {
    Map<String, dynamic>? where,
    int? limit,
    int? offset,
  });
  
  /// ספירת אובייקטים בקולקציה
  Future<int> count(String collection);
  
  /// ניקוי קולקציה
  Future<void> clear(String collection);
}
