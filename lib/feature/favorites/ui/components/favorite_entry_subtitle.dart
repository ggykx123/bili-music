import 'package:bilimusic/feature/favorites/domain/favorite_entry.dart';
import 'package:bilimusic/feature/player/domain/playable_item.dart';
import 'package:bilimusic/feature/player/ui/components/player_display_metadata.dart';

String buildFavoriteEntryTitle(FavoriteEntry item) {
  return resolveDisplayTitle(item: item.toPlayableItem(), metadata: null);
}

String buildFavoriteEntrySubtitle(FavoriteEntry item) {
  final PlayableItem playableItem = item.toPlayableItem();
  final List<String> segments = <String>[
    resolveDisplaySubtitle(item: playableItem, metadata: null),
  ];
  final String durationText = item.durationText?.trim() ?? '';

  if (durationText.isNotEmpty) {
    segments.add(durationText);
  }

  return segments.join(' · ');
}
