import 'package:bilimusic/feature/metadata/domain/metadata.dart';
import 'package:bilimusic/feature/player/domain/playable_item.dart';

String? resolveDisplayCoverUrl({
  required PlayableItem? item,
  required Metadata? metadata,
}) {
  final String metadataCoverUrl = metadata?.albumArtUrl?.trim() ?? '';
  if (metadataCoverUrl.isNotEmpty) {
    return metadataCoverUrl;
  }

  final String itemCoverUrl = item?.coverUrl.trim() ?? '';
  if (itemCoverUrl.isNotEmpty) {
    return itemCoverUrl;
  }

  return null;
}

String? resolveDisplayLyrics(Metadata? metadata) {
  final String lyrics = metadata?.lyrics?.trim() ?? '';
  return lyrics.isEmpty ? null : lyrics;
}

int resolveDisplayLyricOffsetMs(Metadata? metadata) {
  return metadata?.lyricOffsetMs ?? 0;
}
