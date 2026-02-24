// אתחול ספציפי לפלטפורמה
// מייצא את המימוש המתאים בהתאם לפלטפורמה
export 'platform_init_stub.dart'
    if (dart.library.io) 'platform_init_io.dart'
    if (dart.library.html) 'platform_init_web.dart';
