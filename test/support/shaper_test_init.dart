import 'dart:convert';
import 'dart:io';

Directory? resolvedTestPackageRoot(String packageName) {
  final configFile = File('.dart_tool/package_config.json');
  if (!configFile.existsSync()) return null;
  final config =
      jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
  final packages = config['packages'] as List<dynamic>;
  for (final package in packages) {
    if (package['name'] != packageName) continue;
    final rootUri = Uri.parse(package['rootUri'] as String);
    return Directory.fromUri(
      configFile.absolute.parent.uri.resolveUri(rootUri),
    );
  }
  return null;
}
