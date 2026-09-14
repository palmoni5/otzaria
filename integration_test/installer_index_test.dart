// בונה את אינדקס החיפוש לספרייה של installer_screenshots_test, באותו קוד של
// `otzaria build-release-index` — כך ה-workflow לא צריך בניית release בשבילו.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:otzaria/indexing/services/release_index_builder_cli.dart';
import 'package:path/path.dart' as p;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('בניית אינדקס החיפוש לצילומי המתקין', timeout: Timeout.none, () async {
    final root = Platform.environment['OTZARIA_SHOTS_LIBRARY'];
    if (root == null || root.isEmpty) {
      fail('חסר משתנה הסביבה OTZARIA_SHOTS_LIBRARY');
    }
    final log = StringBuffer();
    final exitCode = await ReleaseIndexBuilderCli.run(
      [
        '--library',
        p.join(root, 'books'),
        '--index',
        p.join(root, 'index'),
        '--data',
        p.join(root, '_index_data'),
      ],
      out: log,
      err: log,
    );
    expect(
      exitCode,
      ReleaseIndexBuilderCliExitCode.success,
      reason: log.toString(),
    );
  });
}
