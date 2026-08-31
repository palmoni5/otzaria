// כרטיס ביוגרפיה של רב:
//  • כותרת: שם מלא + תאריכי פטירה/לידה
//  • תקציר תמידי; לחיצה מרחיבה לביוגרפיה המלאה
//  • SelectionArea דרך ToolResultCardShell → העתקה חופשית

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/theme/theme_exports.dart';
import 'package:otzaria/tools/biographies/models/biography.dart';
import 'package:otzaria/widgets/controls/action_buttons.dart';
import 'package:otzaria/widgets/layout/tool_result_card_shell.dart';

class BiographyCard extends StatefulWidget {
  final Biography biography;

  const BiographyCard({super.key, required this.biography});

  @override
  State<BiographyCard> createState() => _BiographyCardState();
}

class _BiographyCardState extends State<BiographyCard> {
  /// רוחב הכפתור ב-[SecondaryIconButton] — משמש לשמירת המקום גם בלי כפתור.
  static const double _toggleSlotWidth = 36;

  /// מספר השורות שמוצגות לפני הרחבה.
  static const int _collapsedLines = 2;

  bool _expanded = false;

  Biography get _bio => widget.biography;

  String? get _datesLine {
    final parts = <String>[
      if (_bio.birthHebrew != null) 'נולד: ${_bio.birthHebrew!.display}',
      if (_bio.deathHebrew != null) 'נפטר: ${_bio.deathHebrew!.display}',
    ];
    return parts.isEmpty ? null : parts.join('  •  ');
  }

  void _copy() {
    final text = [
      _bio.name,
      _datesLine,
      _visibleText,
      if (_expanded) _expandableText,
    ].whereType<String>().join('\n');
    Clipboard.setData(ClipboardData(text: text));
    UiSnack.show(UiSnack.textCopied);
  }

  /// הטקסט הגלוי תמיד. בהיעדר תקציר מוצגת הביוגרפיה עצמה, אחרת הכרטיס
  /// היה נראה ריק לגמרי עד להרחבה.
  String? get _visibleText => _bio.summary ?? _bio.biographyShort;

  /// טקסט נוסף שנחשף בהרחבה — רק כשהוא באמת שונה מהגלוי.
  String? get _expandableText {
    final body = _bio.biographyShort;
    if (body == null || body == _visibleText) return null;
    return body;
  }

  /// האם [text] חורג מ-[maxLines] ברוחב הנתון — קובע אם צריך כפתור הרחבה.
  bool _overflows(String text, TextStyle style, double width, int maxLines) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: maxLines,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: width);
    return painter.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final expandable = _expandableText;
    final visible = _visibleText;
    final bodyStyle = TextStyle(
      fontSize: AppTokens.fontMD,
      color: cs.onSurface,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // רוחב הטקסט בפועל: רוחב הכרטיס פחות הריפוד האופקי של המעטפת.
        final textWidth = constraints.maxWidth - AppTokens.spaceMD * 2;
        final clamped =
            visible != null &&
            _overflows(visible, bodyStyle, textWidth, _collapsedLines);
        final hasBody = expandable != null || clamped;
        return _buildCard(cs, bodyStyle, visible, expandable, hasBody);
      },
    );
  }

  Widget _buildCard(
    ColorScheme cs,
    TextStyle bodyStyle,
    String? visible,
    String? expandable,
    bool hasBody,
  ) {
    return ToolResultCardShell(
      onTap: hasBody ? () => setState(() => _expanded = !_expanded) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _bio.name,
                  style: TextStyle(
                    fontSize: AppTokens.fontLG,
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.spaceXS),
              // המקום נשמר תמיד, אחרת כפתור ההעתקה זז בין כרטיס לכרטיס.
              SizedBox(
                width: _toggleSlotWidth,
                child: hasBody
                    ? SecondaryIconButton(
                        icon: _expanded
                            ? FluentIcons.chevron_up_24_regular
                            : FluentIcons.chevron_down_24_regular,
                        tooltip: _expanded ? 'הסתר' : 'הרחב',
                        onPressed: () => setState(() => _expanded = !_expanded),
                      )
                    : null,
              ),
              const SizedBox(width: AppTokens.spaceXS),
              SecondaryIconButton(
                icon: FluentIcons.copy_24_regular,
                tooltip: 'העתק',
                onPressed: _copy,
              ),
            ],
          ),
          if (_datesLine != null || _bio.generation != null)
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.spaceXS),
              child: Text(
                [?_bio.generation, ?_datesLine].join('  •  '),
                style: TextStyle(
                  fontSize: AppTokens.fontSM,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          if (visible != null)
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.spaceSM),
              child: Text(
                visible,
                style: bodyStyle,
                maxLines: _expanded ? null : _collapsedLines,
                overflow: _expanded ? null : TextOverflow.ellipsis,
              ),
            ),
          if (_expanded && expandable != null)
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.spaceSM),
              child: Text(expandable, style: bodyStyle),
            ),
        ],
      ),
    );
  }
}
