// לתחזוקת טיפים חיים ראו: docs/guided_tour_developer_guide.md

import 'package:equatable/equatable.dart';
import 'package:otzaria/tour/models/tour_step.dart';

enum LiveTipId {
  sideBySideSuggestion,
  dictionaryContextMenuHint,
  commentaryHint,
}

class LiveTipStorage {
  static const String resolvedTipsKey = 'live_tips_resolved';

  static String encode(Set<LiveTipId> tips) {
    final names = tips.map((tip) => tip.name).toList()..sort();
    return names.join(',');
  }

  static Set<LiveTipId> decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return <LiveTipId>{};
    }
    final result = <LiveTipId>{};
    for (final name in raw.split(',')) {
      final trimmed = name.trim();
      if (trimmed.isEmpty) continue;
      for (final tip in LiveTipId.values) {
        if (tip.name == trimmed) {
          result.add(tip);
          break;
        }
      }
    }
    return result;
  }
}

enum TourInteractionType {
  currentTabChanged,
  openedTextBook,
  readerPositionChanged,
  sideBySideEnabled,
  textSelected,
  dictionaryUsed,
  commentaryAvailable,
  commentaryUsed,
}

class TourInteraction extends Equatable {
  final TourInteractionType type;
  final DateTime timestamp;
  final String? primaryValue;

  TourInteraction({
    required this.type,
    DateTime? timestamp,
    this.primaryValue,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  List<Object?> get props => [
        type,
        timestamp.millisecondsSinceEpoch,
        primaryValue,
      ];
}

class LiveTipSpec extends Equatable {
  final LiveTipId id;
  final TourSpotlightArea area;
  final String title;
  final String description;

  const LiveTipSpec({
    required this.id,
    required this.area,
    required this.title,
    required this.description,
  });

  @override
  List<Object?> get props => [id, area, title, description];
}

const List<LiveTipSpec> liveTipSpecs = [
  LiveTipSpec(
    id: LiveTipId.sideBySideSuggestion,
    area: TourSpotlightArea.tabs,
    title: 'tour.compare_books_title',
    description: 'tour.compare_books_body',
  ),
  LiveTipSpec(
    id: LiveTipId.dictionaryContextMenuHint,
    area: TourSpotlightArea.reading,
    title: 'tour.word_meaning_title',
    description: 'tour.word_meaning_body',
  ),
  LiveTipSpec(
    id: LiveTipId.commentaryHint,
    area: TourSpotlightArea.commentators,
    title: 'tour.open_commentaries_title',
    description: 'tour.open_commentaries_body',
  ),
];

LiveTipSpec liveTipSpecById(LiveTipId id) {
  return liveTipSpecs.firstWhere((tip) => tip.id == id);
}
