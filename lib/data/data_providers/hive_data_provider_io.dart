import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

/// אתחול Hive לפלטפורמות native (Desktop/Mobile)
Future<void> initHive() async {
  final dir = await getApplicationSupportDirectory();
  Hive.defaultDirectory = dir.path;
}
