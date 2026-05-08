// לתחזוקת כרטיסי טיפים חיים ראו: docs/guided_tour_developer_guide.md

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:otzaria/widgets/widgets_exports.dart';

class LiveTipCard extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback onDismiss;

  const LiveTipCard({
    super.key,
    required this.title,
    required this.description,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        elevation: 10,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.8),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      textDirection: TextDirection.rtl,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onDismiss,
                    icon: const Icon(FluentIcons.dismiss_24_regular),
                    tooltip: 'tour.live_tip_close'.tr(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textDirection: TextDirection.rtl,
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: NeutralActionButton(
                  icon: FluentIcons.checkmark_24_regular,
                  text: 'tour.live_tip_got_it'.tr(),
                  onPressed: onDismiss,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
