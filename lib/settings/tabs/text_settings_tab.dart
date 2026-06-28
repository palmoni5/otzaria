import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/settings/engine/settings_engine_exports.dart';
import 'package:otzaria/settings/search/settings_anchor.dart';
import 'package:otzaria/settings/search/settings_search_models.dart';
import 'package:otzaria/settings/services/per_book_settings_service.dart';
import 'package:otzaria/settings/widgets/settings_widgets_exports.dart';
import 'package:otzaria/settings/view/settings_screen.dart';
import 'package:otzaria/theme/theme_exports.dart';
import 'package:otzaria/widgets/misc/app_menu_exports.dart';
import 'package:otzaria/widgets/misc/rtl_icon.dart';
import 'package:otzaria/widgets/widgets_exports.dart';
import 'package:otzaria/core/ui_snack.dart';

/// טאב הגדרות תצוגת ספרים
/// ניתן להשתמש בו גם כתוכן בתוך דיאלוג וגם כטאב במסך הגדרות
class TextSettingsTab extends StatelessWidget {
  /// האם להציג כדיאלוג (עם כפתור סגירה) או כטאב (ללא)
  final bool isDialog;

  /// כאשר true, מוסתר סליידר "גודל גופן מפרשים". משמש במצב צורת הדף, שבו
  /// גודל גופן המפרשים נשלט על-ידי הגדרה ייעודית נפרדת בדיאלוג צורת הדף.
  final bool hideCommentaryFontSize;

  const TextSettingsTab({
    super.key,
    this.isDialog = false,
    this.hideCommentaryFontSize = false,
  });

  /// פריטי חיפוש בהגדרות. נסרק על-ידי tool/generate_search_index.dart.
  static const List<SettingsSearchEntry> searchEntries = [
    SettingsSearchEntry(
      id: 'text.font.book_size',
      title: 'settings.text.book_font_size',
      subtitle: 'settings.search.text_font_book_size_sub',
      tab: SettingsTab.text,
      cardId: 'text.font',
      keywords: ['settings.search.text_font_book_size_kw'],
    ),
    SettingsSearchEntry(
      id: 'text.font.book_family',
      title: 'settings.text.text_font',
      subtitle: 'settings.search.text_font_book_family_sub',
      tab: SettingsTab.text,
      cardId: 'text.font',
      keywords: ['settings.search.text_font_book_family_kw'],
    ),
    SettingsSearchEntry(
      id: 'text.font.commentators_size',
      title: 'settings.text.commentators_font_size',
      subtitle: 'settings.search.text_font_commentators_size_sub',
      tab: SettingsTab.text,
      cardId: 'text.font',
      keywords: ['settings.search.text_font_commentators_size_kw'],
    ),
    SettingsSearchEntry(
      id: 'text.font.commentators_family',
      title: 'settings.text.commentators_font',
      subtitle: 'settings.search.text_font_commentators_family_sub',
      tab: SettingsTab.text,
      cardId: 'text.font',
      keywords: ['settings.search.text_font_commentators_family_kw'],
    ),
    SettingsSearchEntry(
      id: 'text.font.line_height',
      title: 'settings.text.line_height',
      subtitle: 'settings.search.text_font_line_height_sub',
      tab: SettingsTab.text,
      cardId: 'text.font',
      keywords: ['settings.search.text_font_line_height_kw'],
    ),
    SettingsSearchEntry(
      id: 'text.font.text_width',
      title: 'settings.text.text_width',
      subtitle: 'settings.search.text_font_text_width_sub',
      tab: SettingsTab.text,
      cardId: 'text.font',
      keywords: ['settings.search.text_font_text_width_kw'],
    ),
    SettingsSearchEntry(
      id: 'text.nikud.display_mode',
      title: 'settings.text.nikud_title',
      subtitle: 'settings.search.text_nikud_display_mode_sub',
      tab: SettingsTab.text,
      cardId: 'text.nikud',
      keywords: ['settings.search.text_nikud_display_mode_kw'],
    ),
    SettingsSearchEntry(
      id: 'text.nikud.holy_names',
      title: 'settings.text.holy_names_title',
      subtitle: 'settings.search.text_nikud_holy_names_sub',
      tab: SettingsTab.text,
      cardId: 'text.nikud',
      keywords: ['settings.search.text_nikud_holy_names_kw'],
    ),
    SettingsSearchEntry(
      id: 'text.nikud.teamim',
      title: 'settings.text.teamim_title',
      subtitle: 'settings.search.text_nikud_teamim_sub',
      tab: SettingsTab.text,
      cardId: 'text.nikud',
      keywords: ['settings.search.text_nikud_teamim_kw'],
    ),
    SettingsSearchEntry(
      id: 'text.copy.with_headers',
      title: 'settings.text.copy_title',
      subtitle: 'settings.search.text_copy_with_headers_sub',
      tab: SettingsTab.text,
      cardId: 'text.copy',
      keywords: ['settings.search.text_copy_with_headers_kw'],
    ),
    SettingsSearchEntry(
      id: 'text.copy.format',
      title: 'settings.text.format_title',
      subtitle: 'settings.search.text_copy_format_sub',
      tab: SettingsTab.text,
      cardId: 'text.copy',
      keywords: ['settings.search.text_copy_format_kw'],
    ),
    SettingsSearchEntry(
      id: 'text.per_book.enable',
      title: 'settings.text.per_book_title',
      subtitle: 'settings.search.text_per_book_enable_sub',
      tab: SettingsTab.text,
      cardId: 'text.per_book',
      keywords: ['settings.search.text_per_book_enable_kw'],
    ),
    SettingsSearchEntry(
      id: 'text.per_book.reset',
      title: 'settings.search.text_per_book_reset_title',
      subtitle: 'settings.search.text_per_book_reset_sub',
      tab: SettingsTab.text,
      cardId: 'text.per_book',
      keywords: ['settings.search.text_per_book_reset_kw'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        final content = SingleChildScrollView(
          primary: true,
          padding: const EdgeInsets.all(16.0),
          child: ToolPanelWrapper(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsAnchor(
                  cardId: 'text.font',
                  child: _buildFontSection(context, settingsState),
                ),
                kSettingsCardSpacing,
                SettingsAnchor(
                  cardId: 'text.nikud',
                  child: _buildNikudSection(context, settingsState),
                ),
                kSettingsCardSpacing,
                SettingsAnchor(
                  cardId: 'text.copy',
                  child: _buildCopySection(context, settingsState),
                ),
                kSettingsCardSpacing,
                SettingsAnchor(
                  cardId: 'text.per_book',
                  child: _buildPerBookSection(context, settingsState),
                ),
              ],
            ),
          ),
        );

        return content;
      },
    );
  }

  Widget _buildFontSection(BuildContext context, SettingsState state) {
    return SettingsCard(
      title: 'settings.text.font_section'.tr(),
      children: [
        // שורה 1: גודל גופן הספר + גופן טקסט
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < LayoutBreakpoints.compact;
            if (isNarrow) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FontSizeSlider(
                      icon: FluentIcons.text_font_size_24_regular,
                      label: 'settings.text.book_font_size'.tr(),
                      value: state.fontSize.clamp(15, 60),
                      min: 15,
                      max: 60,
                      onChanged: (value) {
                        context.read<SettingsBloc>().add(UpdateFontSize(value));
                      },
                    ),
                    const SizedBox(height: 16),
                    _FontDropdown(
                      icon: FluentIcons.text_font_24_regular,
                      label: 'settings.text.text_font'.tr(),
                      value: state.fontFamily,
                      onChanged: (value) {
                        if (value != null) {
                          context
                              .read<SettingsBloc>()
                              .add(UpdateFontFamily(value));
                        }
                      },
                      bold: state.fontBold,
                      onBoldChanged: (value) {
                        context.read<SettingsBloc>().add(UpdateFontBold(value));
                      },
                    ),
                  ],
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _FontSizeSlider(
                      icon: FluentIcons.text_font_size_24_regular,
                      label: 'settings.text.book_font_size'.tr(),
                      value: state.fontSize.clamp(15, 60),
                      min: 15,
                      max: 60,
                      onChanged: (value) {
                        context.read<SettingsBloc>().add(UpdateFontSize(value));
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _FontDropdown(
                      icon: FluentIcons.text_font_24_regular,
                      label: 'settings.text.text_font'.tr(),
                      value: state.fontFamily,
                      onChanged: (value) {
                        if (value != null) {
                          context
                              .read<SettingsBloc>()
                              .add(UpdateFontFamily(value));
                        }
                      },
                      bold: state.fontBold,
                      onBoldChanged: (value) {
                        context.read<SettingsBloc>().add(UpdateFontBold(value));
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // שורה 2: גודל גופן מפרשים + גופן מפרשים
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < LayoutBreakpoints.compact;
            if (isNarrow) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!hideCommentaryFontSize) ...[
                      _FontSizeSlider(
                        icon: FluentIcons.text_font_size_24_regular,
                        label: 'settings.text.commentators_font_size'.tr(),
                        value: state.commentatorsFontSize.clamp(10, 40),
                        min: 10,
                        max: 40,
                        onChanged: (value) {
                          context
                              .read<SettingsBloc>()
                              .add(UpdateCommentatorsFontSize(value));
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    _FontDropdown(
                      icon: FluentIcons.book_24_regular,
                      label: 'settings.text.commentators_font'.tr(),
                      value: state.commentatorsFontFamily,
                      onChanged: (value) {
                        if (value != null) {
                          context
                              .read<SettingsBloc>()
                              .add(UpdateCommentatorsFontFamily(value));
                        }
                      },
                      bold: state.commentatorsFontBold,
                      onBoldChanged: (value) {
                        context
                            .read<SettingsBloc>()
                            .add(UpdateCommentatorsFontBold(value));
                      },
                    ),
                  ],
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!hideCommentaryFontSize) ...[
                    Expanded(
                      child: _FontSizeSlider(
                        icon: FluentIcons.text_font_size_24_regular,
                        label: 'settings.text.commentators_font_size'.tr(),
                        value: state.commentatorsFontSize.clamp(10, 40),
                        min: 10,
                        max: 40,
                        onChanged: (value) {
                          context
                              .read<SettingsBloc>()
                              .add(UpdateCommentatorsFontSize(value));
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: _FontDropdown(
                      icon: FluentIcons.book_24_regular,
                      label: 'settings.text.commentators_font'.tr(),
                      value: state.commentatorsFontFamily,
                      onChanged: (value) {
                        if (value != null) {
                          context
                              .read<SettingsBloc>()
                              .add(UpdateCommentatorsFontFamily(value));
                        }
                      },
                      bold: state.commentatorsFontBold,
                      onBoldChanged: (value) {
                        context
                            .read<SettingsBloc>()
                            .add(UpdateCommentatorsFontBold(value));
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // שורה 3: מרווח בין שורות
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < LayoutBreakpoints.compact;
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: isNarrow
                  ? _FontSizeSlider(
                      icon: FluentIcons
                          .text_align_distributed_vertical_24_regular,
                      label: 'settings.text.line_height'.tr(),
                      value: state.lineHeight.clamp(1.0, 3.0),
                      min: 1.0,
                      max: 3.0,
                      divisions: 20,
                      onChanged: (value) {
                        context
                            .read<SettingsBloc>()
                            .add(UpdateLineHeight(value));
                      },
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _FontSizeSlider(
                            icon: FluentIcons
                                .text_align_distributed_vertical_24_regular,
                            label: 'settings.text.line_height'.tr(),
                            value: state.lineHeight.clamp(1.0, 3.0),
                            min: 1.0,
                            max: 3.0,
                            divisions: 20,
                            onChanged: (value) {
                              context
                                  .read<SettingsBloc>()
                                  .add(UpdateLineHeight(value));
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
            );
          },
        ),

        _TextWidthSlider(state: state),
      ],
    );
  }

  Widget _buildNikudSection(BuildContext context, SettingsState state) {
    // קביעת הערך הנוכחי של הניקוד
    String nikudValue;
    if (!state.defaultRemoveNikud) {
      nikudValue = 'show_always';
    } else if (state.removeNikudFromTanach) {
      nikudValue = 'hide_all';
    } else {
      nikudValue = 'show_tanach_only';
    }

    // קביעת ה-subtitle בהתאם למצב
    String nikudSubtitle;
    switch (nikudValue) {
      case 'show_always':
        nikudSubtitle = 'settings.text.nikud_show_always_subtitle'.tr();
        break;
      case 'show_tanach_only':
        nikudSubtitle = 'settings.text.nikud_show_tanach_only_subtitle'.tr();
        break;
      case 'hide_all':
        nikudSubtitle = 'settings.text.nikud_hide_all_subtitle'.tr();
        break;
      default:
        nikudSubtitle = '';
    }

    return SettingsCard(
      title: 'settings.text.nikud_section'.tr(),
      children: [
        SegmentedSettingsTile<String>(
          icon: const RtlIcon(FluentIcons.text_font_info_24_regular),
          title: 'settings.text.nikud_title'.tr(),
          subtitle: nikudSubtitle,
          options: [
            SegmentOption(
                value: 'show_always',
                label: 'settings.text.nikud_show_always'.tr()),
            SegmentOption(
                value: 'show_tanach_only',
                label: 'settings.text.nikud_show_tanach_only'.tr()),
            SegmentOption(
                value: 'hide_all',
                label: 'settings.text.nikud_hide_all'.tr()),
          ],
          currentValue: nikudValue,
          onChanged: (value) {
            switch (value) {
              case 'show_always':
                context
                    .read<SettingsBloc>()
                    .add(const UpdateDefaultRemoveNikud(false));
                break;
              case 'show_tanach_only':
                context
                    .read<SettingsBloc>()
                    .add(const UpdateDefaultRemoveNikud(true));
                context
                    .read<SettingsBloc>()
                    .add(const UpdateRemoveNikudFromTanach(false));
                break;
              case 'hide_all':
                context
                    .read<SettingsBloc>()
                    .add(const UpdateDefaultRemoveNikud(true));
                context
                    .read<SettingsBloc>()
                    .add(const UpdateRemoveNikudFromTanach(true));
                break;
            }
          },
        ),
        SwitchSettingsTile.text(
          icon: FluentIcons.shield_keyhole_24_regular,
          title: 'settings.text.holy_names_title'.tr(),
          subtitle: !state.replaceHolyNames
              ? 'settings.text.holy_names_show'.tr()
              : 'settings.text.holy_names_hide'.tr(),
          value: !state.replaceHolyNames,
          onChanged: (value) {
            context.read<SettingsBloc>().add(UpdateReplaceHolyNames(!value));
          },
        ),
        SwitchSettingsTile.text(
          icon: FluentIcons.text_more_24_regular,
          title: 'settings.text.teamim_title'.tr(),
          subtitle: state.showTeamim
              ? 'settings.text.teamim_on'.tr()
              : 'settings.text.teamim_off'.tr(),
          value: state.showTeamim,
          onChanged: (value) {
            context.read<SettingsBloc>().add(UpdateShowTeamim(value));
          },
        ),
      ],
    );
  }

  Widget _buildCopySection(BuildContext context, SettingsState state) {
    // קביעת ה-subtitle בהתאם למצב העתקת הכותרת
    String copySubtitle;
    switch (state.copyWithHeaders) {
      case 'none':
        copySubtitle = 'settings.text.copy_none_subtitle'.tr();
        break;
      case 'book_name':
        copySubtitle = 'settings.text.copy_book_name_subtitle'.tr();
        break;
      case 'book_and_path':
        copySubtitle = 'settings.text.copy_book_and_path_subtitle'.tr();
        break;
      default:
        copySubtitle = '';
    }

    // קביעת ה-subtitle בהתאם לעיצוב ההעתקה
    String formatSubtitle;
    switch (state.copyHeaderFormat) {
      case 'same_line_after_brackets':
        formatSubtitle =
            'settings.text.format_same_line_after_brackets_subtitle'.tr();
        break;
      case 'same_line_after_no_brackets':
        formatSubtitle =
            'settings.text.format_same_line_after_no_brackets_subtitle'.tr();
        break;
      case 'same_line_before_brackets':
        formatSubtitle =
            'settings.text.format_same_line_before_brackets_subtitle'.tr();
        break;
      case 'same_line_before_no_brackets':
        formatSubtitle =
            'settings.text.format_same_line_before_no_brackets_subtitle'.tr();
        break;
      case 'separate_line_after':
        formatSubtitle =
            'settings.text.format_separate_line_after_subtitle'.tr();
        break;
      case 'separate_line_before':
        formatSubtitle =
            'settings.text.format_separate_line_before_subtitle'.tr();
        break;
      default:
        formatSubtitle = '';
    }

    return SettingsCard(
      title: 'settings.text.copy_section'.tr(),
      children: [
        SegmentedSettingsTile<String>(
          icon: const RtlIcon(FluentIcons.copy_24_regular),
          title: 'settings.text.copy_title'.tr(),
          subtitle: copySubtitle,
          options: [
            SegmentOption(
                value: 'none', label: 'settings.text.copy_none'.tr()),
            SegmentOption(
                value: 'book_name',
                label: 'settings.text.copy_book_name'.tr()),
            SegmentOption(
                value: 'book_and_path',
                label: 'settings.text.copy_book_and_path'.tr()),
          ],
          currentValue: state.copyWithHeaders,
          onChanged: (value) {
            context.read<SettingsBloc>().add(UpdateCopyWithHeaders(value));
          },
        ),
        if (state.copyWithHeaders != 'none')
          DropdownSettingsTile<String>(
            icon: const RtlIcon(FluentIcons.text_align_right_24_regular),
            title: 'settings.text.format_title'.tr(),
            subtitle: formatSubtitle,
            value: state.copyHeaderFormat,
            minFieldWidth: 220,
            maxFieldWidth: 320,
            entries: [
              AppMenuEntry(
                value: 'same_line_after_brackets',
                label: 'settings.text.format_same_line_after_brackets'.tr(),
              ),
              AppMenuEntry(
                value: 'same_line_after_no_brackets',
                label: 'settings.text.format_same_line_after_no_brackets'.tr(),
              ),
              AppMenuEntry(
                value: 'same_line_before_brackets',
                label: 'settings.text.format_same_line_before_brackets'.tr(),
              ),
              AppMenuEntry(
                value: 'same_line_before_no_brackets',
                label:
                    'settings.text.format_same_line_before_no_brackets'.tr(),
              ),
              AppMenuEntry(
                value: 'separate_line_after',
                label: 'settings.text.format_separate_line_after'.tr(),
              ),
              AppMenuEntry(
                value: 'separate_line_before',
                label: 'settings.text.format_separate_line_before'.tr(),
              ),
            ],
            onSelected: (value) {
              if (value != null) {
                context.read<SettingsBloc>().add(UpdateCopyHeaderFormat(value));
              }
            },
          ),
      ],
    );
  }

  Widget _buildPerBookSection(BuildContext context, SettingsState state) {
    return SettingsCard(
      title: 'settings.text.per_book_section'.tr(),
      children: [
        SwitchSettingsTile.text(
          icon: FluentIcons.book_open_24_regular,
          title: 'settings.text.per_book_title'.tr(),
          subtitle: state.enablePerBookSettings
              ? 'settings.text.per_book_on'.tr()
              : 'settings.text.per_book_off'.tr(),
          value: state.enablePerBookSettings,
          onChanged: (value) {
            context
                .read<SettingsBloc>()
                .add(UpdateEnablePerBookSettings(value));
          },
        ),
        if (state.enablePerBookSettings)
          SettingsActionTile.text(
            icon: FluentIcons.delete_24_regular,
            title: 'settings.text.per_book_reset_title_tile'.tr(),
            subtitle: 'settings.text.per_book_reset_subtitle_tile'.tr(),
            actions: [
              NeutralActionButton(
                onPressed: () => _resetPerBookSettings(context),
                text: 'settings.text.per_book_reset_button'.tr(),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _resetPerBookSettings(BuildContext context) async {
    final confirm = await showWarningDialog(
      context: context,
      title: 'settings.text.per_book_reset_title'.tr(),
      content: 'settings.text.per_book_reset_content'.tr(),
      subtitle: 'settings.text.per_book_reset_subtitle'.tr(),
      cancelText: 'common.cancel'.tr(),
      confirmText: 'settings.text.per_book_reset_confirm'.tr(),
    );

    if (confirm == true && context.mounted) {
      await PerBookSettings.deleteAllSettings();
      UiSnack.show('settings.text.per_book_reset_success'.tr());
    }
  }
}

// Widget עזר לסליידר גודל גופן
class _FontSizeSlider extends StatefulWidget {
  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;

  const _FontSizeSlider({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.onChanged,
  });

  @override
  State<_FontSizeSlider> createState() => _FontSizeSliderState();
}

class _FontSizeSliderState extends State<_FontSizeSlider> {
  late double _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
  }

  @override
  void didUpdateWidget(_FontSizeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _currentValue = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            RtlIcon(widget.icon),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.label,
                style: kSettingsTitleStyle,
              ),
            ),
            Text(
              widget.divisions != null
                  ? _currentValue.toStringAsFixed(1)
                  : _currentValue.toStringAsFixed(0),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: _currentValue,
          min: widget.min,
          max: widget.max,
          divisions: widget.divisions ?? (widget.max - widget.min).toInt(),
          label: widget.divisions != null
              ? _currentValue.toStringAsFixed(1)
              : _currentValue.toStringAsFixed(0),
          onChanged: (value) {
            setState(() => _currentValue = value);
            widget.onChanged(value);
          },
        ),
      ],
    );
  }
}

/// מחרוזת הדוגמה המוצגת בכל גופן ברשימה (כמו תצוגת גופנים בוורד).
const String _kFontSampleText = 'אבגד הוזח';

/// אייקון המבחין בין גופן עם תגיות (serif) לגופן חלק (sans-serif).
IconData? _fontCategoryIcon(FontCategory category) {
  switch (category) {
    case FontCategory.serif:
      return FluentIcons.text_font_24_regular;
    case FontCategory.sansSerif:
      return FluentIcons.text_t_24_regular;
    case FontCategory.unknown:
      return null;
  }
}

// Widget עזר לדרופדאון גופן
class _FontDropdown extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ValueChanged<String?> onChanged;

  /// האם הגופן מוצג כעת במשקל מודגש (בולד).
  final bool bold;
  final ValueChanged<bool> onBoldChanged;

  const _FontDropdown({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.bold,
    required this.onBoldChanged,
  });

  @override
  Widget build(BuildContext context) {
    final all = AppFonts.availableFonts;

    // O(n) lookup במקום O(n²) — מחושב פעם אחת לכל build.
    final serifValues = {
      for (final f in all)
        if (f.category == FontCategory.serif) f.value,
    };
    final sansValues = {
      for (final f in all)
        if (f.category == FontCategory.sansSerif) f.value,
    };

    final fontEntries = all
        .map(
          (font) => AppMenuEntry<String>(
            value: font.value,
            label: font.label,
            icon: _fontCategoryIcon(font.category),
            reserveTrailingGap: true,
            trailingReservedWidth: 72,
            labelWidget: _FontPreviewText(
              fontFamily: font.value,
              name: font.label,
              isBundled: AppFonts.fontPaths.containsKey(font.value),
            ),
            trailing: SizedBox(
              width: 72,
              child: Opacity(
                opacity: 0.6,
                child: _FontPreviewText(
                  fontFamily: font.value,
                  name: _kFontSampleText,
                  isBundled: AppFonts.fontPaths.containsKey(font.value),
                ),
              ),
            ),
          ),
        )
        .toList();

    // גופן נבחר שאינו מותקן כלל במחשב — מסומן בתווית מיוחדת.
    final hasSelectedFont =
        value.isEmpty || fontEntries.any((entry) => entry.value == value);
    if (!hasSelectedFont) {
      fontEntries.insert(
        0,
        AppMenuEntry(
            value: value,
            label: 'settings.text.font_unavailable'
                .tr(namedArgs: {'font': value})),
      );
    }

    return Row(
      children: [
        RtlIcon(icon),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: kSettingsTitleStyle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppDropdownField<String>(
            value: value,
            enableSearch: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            entries: fontEntries,
            filterLabels: const ['הכל', 'Serif', 'Sans'],
            filterPredicates: [
              null,
              (e) => serifValues.contains(e.value),
              (e) => sansValues.contains(e.value),
            ],
            menuMinWidth: 260,
            selectedBuilder: (context, selectedValue) {
              final v = selectedValue ?? '';
              final matchingFont = all.firstWhere(
                (font) => font.value == v,
                orElse: () => FontInfo(value: v, label: v),
              );
              // בשדה הסגור מציגים את שם הגופן (מרונדר בגופן עצמו לזיהוי).
              return _FontPreviewText(
                fontFamily: v,
                name: matchingFont.label,
                isBundled: AppFonts.fontPaths.containsKey(v),
              );
            },
            onSelected: onChanged,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: bold ? 'הצגה במשקל רגיל' : 'הדגשת הגופן (בולד)',
          isSelected: bold,
          onPressed: () => onBoldChanged(!bold),
          icon: const RtlIcon(FluentIcons.text_bold_24_regular),
          selectedIcon: const RtlIcon(FluentIcons.text_bold_24_filled),
        ),
      ],
    );
  }
}

/// מציג את שם הגופן (ובאופן אופציונלי מחרוזת דוגמה) מרונדרים בגופן עצמו.
/// עבור גופני מערכת טוען את הגופן ל-engine ברקע, ומציג ברירת-מחדל עד הטעינה.
class _FontPreviewText extends StatefulWidget {
  final String fontFamily;
  final String name;
  final bool isBundled;

  const _FontPreviewText({
    required this.fontFamily,
    required this.name,
    required this.isBundled,
  });

  @override
  State<_FontPreviewText> createState() => _FontPreviewTextState();
}

class _FontPreviewTextState extends State<_FontPreviewText> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _resolveFont();
  }

  @override
  void didUpdateWidget(covariant _FontPreviewText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fontFamily != widget.fontFamily ||
        oldWidget.isBundled != widget.isBundled) {
      _resolveFont();
    }
  }

  void _resolveFont() {
    if (widget.isBundled) {
      _loaded = true;
      return;
    }
    _loaded = false;
    final family = widget.fontFamily;
    AppFonts.ensureFontLoaded(family).then((_) {
      if (mounted && widget.fontFamily == family) {
        setState(() => _loaded = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final family = _loaded ? widget.fontFamily : null;
    return Text(
      widget.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontFamily: family),
    );
  }
}

// Widget עזר לסליידר רוחב טקסט
class _TextWidthSlider extends StatefulWidget {
  final SettingsState state;

  const _TextWidthSlider({required this.state});

  @override
  State<_TextWidthSlider> createState() => _TextWidthSliderState();
}

class _TextWidthSliderState extends State<_TextWidthSlider> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final currentMaxWidth = widget.state.textMaxWidth;

    int currentLevel;
    if (currentMaxWidth < 0) {
      currentLevel = (-currentMaxWidth).toInt();
    } else if (currentMaxWidth == 0) {
      currentLevel = 0;
    } else {
      final ratio = currentMaxWidth / screenWidth;
      currentLevel = ((1.0 - ratio) / 0.05).round().clamp(0, 14);
    }

    String getLevelDescription(int level) {
      if (level == 0) return 'settings.text.text_width_full'.tr();
      final percent = 100 - (level * 5);
      return '$percent%';
    }

    return Column(
      children: [
        ListTile(
          leading: const RtlIcon(FluentIcons.text_align_distributed_24_regular),
          title: Text('settings.text.text_width'.tr(),
              style: kSettingsTitleStyle),
          subtitle: Text(
            currentLevel == 0
                ? 'settings.text.text_width_full_subtitle'.tr()
                : 'settings.text.text_width_narrow_subtitle'.tr(),
            style: kSettingsSubtitleStyle,
          ),
          trailing: Text(
            getLevelDescription(currentLevel),
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Slider(
            value: currentLevel.toDouble(),
            min: 0,
            max: 14,
            divisions: 14,
            label: getLevelDescription(currentLevel),
            onChanged: (value) {
              setState(() {});
              final level = value.toInt();
              double newMaxWidth;
              if (level == 0) {
                newMaxWidth = 0;
              } else {
                final widthPercent = 1.0 - (level * 0.05);
                newMaxWidth = screenWidth * widthPercent;
              }
              context.read<SettingsBloc>().add(UpdateTextMaxWidth(newMaxWidth));
            },
          ),
        ),
      ],
    );
  }
}
