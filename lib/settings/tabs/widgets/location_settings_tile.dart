import 'package:flutter/material.dart';
import 'package:otzaria/theme/layout_tokens.dart';
import 'package:otzaria/widgets/widgets_exports.dart';

/// שורת הגדרה למיקום (אייקון + כותרת + תת-כותרת + כפתורי פעולה).
///
/// במסך רחב הכפתורים מוצגים ב-`trailing` של [ListTile]. במסך צר
/// (`<LayoutBreakpoints.compact`) הם עוברים לשורה תחת ה-subtitle כדי
/// שטקסט הנתיב לא יקרוס לתו-לשורה.
class LocationSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> actions;

  const LocationSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < LayoutBreakpoints.compact;
        final titleWidget = Text(title, style: kSettingsTitleStyle);
        final subtitleWidget = Text(
          subtitle,
          style: kSettingsSubtitleStyle,
          textDirection: TextDirection.rtl,
        );
        final actionsRow = Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: actions,
        );

        if (!isNarrow) {
          return ListTile(
            // השורה עוטפת כפתורי פעולה ב-trailing — מבטלים את ה-hover של
            // ה-ListTile כדי שה-hover יופיע רק על הכפתורים, בלי double-hover.
            hoverColor: Colors.transparent,
            leading: Icon(icon),
            title: titleWidget,
            subtitle: subtitleWidget,
            trailing: actionsRow,
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2, left: 16),
                    child: Icon(icon),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleWidget,
                        const SizedBox(height: 4),
                        subtitleWidget,
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: actionsRow,
              ),
            ],
          ),
        );
      },
    );
  }
}
