import 'web_storage_provider.dart';
import 'storage_provider.dart';

/// יוצר instance של StorageProvider לפלטפורמת Web
StorageProvider createStorageProvider() {
  return WebStorageProvider();
}
