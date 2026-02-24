import 'file_storage_provider.dart';
import 'storage_provider.dart';

/// יוצר instance של StorageProvider לפלטפורמות Native
StorageProvider createStorageProvider() {
  return FileStorageProvider();
}
