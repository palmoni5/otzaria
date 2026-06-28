import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/models/links.dart';
import 'package:otzaria/tabs/models/text_tab.dart';
import 'package:otzaria/text_book/bloc/text_book_bloc.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/utils/text/text_manipulation.dart' as utils;
import 'package:otzaria/utils/text/copy_utils.dart';
import 'package:otzaria/settings/settings_exports.dart';
import 'package:otzaria/settings/services/nikud_display_service.dart';
import 'package:otzaria/widgets/misc/app_menu_exports.dart';
import 'package:otzaria/text_book/view/selection/selected_text_copy.dart';

/// פונקציות עזר לתפריטי הקשר במפרשים
class ContextMenuUtils {
  static TextBook _targetBookFromLink(Link link) {
    return TextBook(
      title: utils.getTitleFromPath(link.path2),
      categoryId: link.targetCategoryId,
      fileType: link.targetFileType,
    );
  }

  /// בניית רשימת פריטי תפריט הקשר למפרש ספציפי.
  ///
  /// מחזיר [List<AppContextMenuEntry>] לשימוש עם [AppContextMenuRegion].
  ///
  /// דוגמה:
  /// ```dart
  /// AppContextMenuRegion(
  ///   menuBuilder: (ctx) => ContextMenuUtils.buildCommentaryContextMenu(
  ///     context: ctx,
  ///     link: link,
  ///     openBookCallback: ...,
  ///     fontSize: fontSize,
  ///     savedSelectedText: _savedText,
  ///     onCopySelected: _copy,
  ///   ),
  ///   child: myCommentaryWidget,
  /// )
  /// ```
  static List<AppContextMenuEntry> buildCommentaryContextMenu({
    required BuildContext context,
    required Link link,
    required Function(TextBookTab) openBookCallback,
    required double fontSize,
    String? savedSelectedText,
    required VoidCallback onCopySelected,
  }) {
    return [
      AppContextMenuEntry(
        label: 'utils.menu_copy'.tr(),
        icon: FluentIcons.copy_24_regular,
        enabled:
            savedSelectedText != null && savedSelectedText.trim().isNotEmpty,
        onTap: onCopySelected,
      ),
      AppContextMenuEntry(
        label: 'utils.menu_copy_paragraph'.tr(),
        icon: FluentIcons.document_copy_24_regular,
        onTap: () => copyCommentaryParagraph(
          context: context,
          link: link,
          fontSize: fontSize,
        ),
      ),
      const AppContextMenuEntry.divider(),
      AppContextMenuEntry(
        label: 'utils.menu_open_in_new_window'.tr(),
        icon: FluentIcons.open_24_regular,
        onTap: () {
          openBookCallback(TextBookTab(
            book: TextBook(title: utils.getTitleFromPath(link.path2)),
            index: link.index2 - 1,
            openLeftPane: (Settings.getValue<bool>('key-pin-sidebar') ??
                    false) ||
                (Settings.getValue<bool>('key-default-sidebar-open') ?? false),
          ));
        },
      ),
    ];
  }

  /// העתקת פסקה שלמה של מפרש
  static Future<void> copyCommentaryParagraph({
    required BuildContext context,
    required Link link,
    required double fontSize,
  }) async {
    try {
      final settingsState = context.read<SettingsBloc>().state;

      final content = await link.content;
      if (content.trim().isEmpty) {
        UiSnack.show('utils.no_content_to_copy'.tr());
        return;
      }

      final removeNikud = await resolveRemoveNikudForBook(
        title: utils.getTitleFromPath(link.path2),
        defaultRemoveNikud: settingsState.defaultRemoveNikud,
        removeNikudFromTanach: settingsState.removeNikudFromTanach,
        categoryId: link.targetCategoryId,
        fileType: link.targetFileType,
      );

      final processedContent =
          removeNikud ? utils.removeVolwels(content) : content;
      final plainText = utils.stripHtmlIfNeeded(processedContent);

      String finalText = plainText;
      String finalHtmlText = processedContent;

      if (settingsState.copyWithHeaders != 'none') {
        final targetBook = _targetBookFromLink(link);
        final bookName = CopyUtils.extractBookName(targetBook);
        final currentPath = await CopyUtils.extractCurrentPath(
          targetBook,
          link.index2 - 1,
        );

        finalText = CopyUtils.formatTextWithHeaders(
          originalText: plainText,
          copyWithHeaders: settingsState.copyWithHeaders,
          copyHeaderFormat: settingsState.copyHeaderFormat,
          bookName: bookName,
          currentPath: currentPath,
        );

        finalHtmlText = CopyUtils.formatTextWithHeaders(
          originalText: processedContent,
          copyWithHeaders: settingsState.copyWithHeaders,
          copyHeaderFormat: settingsState.copyHeaderFormat,
          bookName: bookName,
          currentPath: currentPath,
        );
      }

      final copyContent = CopyUtils.applyCopyPreferencesForClipboard(
        plainText: finalText,
        htmlText: finalHtmlText,
        replaceHolyNames: settingsState.replaceHolyNames,
      );

      final htmlText = CopyUtils.buildStyledHtml(
        htmlText: copyContent.htmlText,
        fontFamily: settingsState.commentatorsFontFamily,
        fontSize: fontSize,
      );

      final clipboard = SystemClipboard.instance;
      if (clipboard != null) {
        final item = DataWriterItem();
        item.add(Formats.plainText(copyContent.plainText));
        item.add(Formats.htmlText(htmlText));
        await clipboard.write([item]);
        UiSnack.show('utils.paragraph_copied'.tr());
      }
    } catch (e) {
      debugPrint('Error copying commentary paragraph: $e');
      UiSnack.showError('utils.paragraph_copy_error'.tr());
    }
  }

  /// העתקת טקסט מעוצב (HTML) ללוח
  static Future<void> copyFormattedText({
    required BuildContext context,
    required String? savedSelectedText,
    required double fontSize,
    Link? link,
  }) async {
    final plainText = savedSelectedText;

    if (plainText == null || plainText.trim().isEmpty) {
      UiSnack.show('snack.no_text_selected'.tr());
      return;
    }

    try {
      final clipboard = SystemClipboard.instance;
      if (clipboard != null) {
        final settingsState = context.read<SettingsBloc>().state;
        if (link != null && settingsState.copyWithHeaders != 'none') {
          final textBookState = context.read<TextBookBloc>().state;
          if (textBookState is! TextBookLoaded) return;

          await copySelectedTextForBook(
            plainText: plainText,
            selectedIndex: link.index2 - 1,
            sourceContent: [plainText],
            textBookState: textBookState,
            settingsState: settingsState,
            fontFamily: settingsState.commentatorsFontFamily,
            fontSize: fontSize,
            headerBookOverride: _targetBookFromLink(link),
          );
          return;
        }

        final finalPlainText = CopyUtils.applyCopyPreferences(
          text: plainText,
          replaceHolyNames: settingsState.replaceHolyNames,
        );

        final htmlText = CopyUtils.buildStyledHtml(
          htmlText: finalPlainText,
          fontFamily: settingsState.commentatorsFontFamily,
          fontSize: fontSize,
        );

        final item = DataWriterItem();
        item.add(Formats.plainText(finalPlainText));
        item.add(Formats.htmlText(htmlText));

        await clipboard.write([item]);
        UiSnack.show('snack.text_copied'.tr());
      }
    } catch (e) {
      debugPrint('Error copying text: $e');
      UiSnack.showError('utils.text_copy_error'.tr());
    }
  }
}
