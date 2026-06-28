import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/services.dart';
import 'package:otzaria/core/ui_snack.dart';

export 'package:otzaria/utils/book_link_builder.dart';

/// העתקת קישור ללוח והצגת הודעה. משתמש ב‑[Clipboard.setData] של Flutter במקום
/// ב‑super_clipboard כי הקישור הוא טקסט בלבד וכך נמנעים מבעיית
/// `SystemClipboard.instance == null` שעלולה לגרום להודעת "הועתק" שקרית.
Future<void> copyLinkToClipboard(String url) async {
  await Clipboard.setData(ClipboardData(text: url));
  UiSnack.show('utils.link_copied'.tr());
}
