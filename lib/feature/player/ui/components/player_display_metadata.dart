import 'package:bilimusic/feature/metadata/domain/metadata.dart';
import 'package:bilimusic/common/domain/meta_lyrics.dart';
import 'package:bilimusic/feature/metadata/data/metadata_cache_repository.dart';
import 'package:bilimusic/feature/player/domain/playable_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

String resolveDisplayTitle({
  required PlayableItem? item,
  required Metadata? metadata,
  String fallback = '未选择播放内容',
}) {
  if (item == null) {
    return fallback;
  }

  final Metadata? usableMetadata = _usableMetadataForItem(
    item: item,
    metadata: metadata,
  );
  final String metadataTitle = usableMetadata?.title?.trim() ?? '';
  if (metadataTitle.isNotEmpty) {
    return metadataTitle;
  }

  return item.displayTitle;
}

String resolveDisplaySubtitle({
  required PlayableItem? item,
  required Metadata? metadata,
  String fallback = '',
}) {
  if (item == null) {
    return fallback;
  }

  final Metadata? usableMetadata = _usableMetadataForItem(
    item: item,
    metadata: metadata,
  );
  final String metadataTitle = usableMetadata?.title?.trim() ?? '';
  if (metadataTitle.isNotEmpty) {
    final String videoTitle = item.title.trim();
    return videoTitle.isNotEmpty ? videoTitle : item.author;
  }

  return item.displaySubtitle;
}

String? resolveDisplayCoverUrl({
  required PlayableItem? item,
  required Metadata? metadata,
}) {
  final Metadata? usableMetadata = item == null
      ? null
      : _usableMetadataForItem(item: item, metadata: metadata);
  final String metadataCoverUrl = usableMetadata?.albumArtUrl?.trim() ?? '';
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
  final String lyrics =
      metadata?.metaLyrics?.preferredMainLyric?.trim() ??
      metadata?.lyrics?.trim() ??
      '';
  return lyrics.isEmpty ? null : lyrics;
}

MetaLyrics? resolveDisplayMetaLyrics(Metadata? metadata) {
  return metadata?.metaLyrics;
}

String? resolveDisplayTranslationLyrics(Metadata? metadata) {
  return metadata?.metaLyrics?.preferredTranslationLyric;
}

int resolveDisplayLyricOffsetMs(Metadata? metadata) {
  return metadata?.lyricOffsetMs ?? 0;
}

class CachedPlayableTitleText extends StatelessWidget {
  const CachedPlayableTitleText({
    super.key,
    required this.item,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  final PlayableItem item;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    return _CachedPlayableText(
      item: item,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      resolveText: (Metadata? metadata) =>
          resolveDisplayTitle(item: item, metadata: metadata),
    );
  }
}

class CachedPlayableSubtitleText extends StatelessWidget {
  const CachedPlayableSubtitleText({
    super.key,
    required this.item,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  final PlayableItem item;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    return _CachedPlayableText(
      item: item,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      resolveText: (Metadata? metadata) =>
          resolveDisplaySubtitle(item: item, metadata: metadata),
    );
  }
}

class _CachedPlayableText extends ConsumerStatefulWidget {
  const _CachedPlayableText({
    required this.item,
    required this.resolveText,
    this.style,
    this.maxLines,
    required this.overflow,
  });

  final PlayableItem item;
  final String Function(Metadata? metadata) resolveText;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  ConsumerState<_CachedPlayableText> createState() =>
      _CachedPlayableTextState();
}

class _CachedPlayableTextState extends ConsumerState<_CachedPlayableText> {
  late Future<Metadata?> _metadataFuture;

  @override
  void initState() {
    super.initState();
    _metadataFuture = _loadMetadata();
  }

  @override
  void didUpdateWidget(covariant _CachedPlayableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.stableId != widget.item.stableId) {
      _metadataFuture = _loadMetadata();
    }
  }

  Future<Metadata?> _loadMetadata() {
    return ref
        .read(metadataCacheRepositoryProvider)
        .getCachedMetadata(item: widget.item);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Metadata?>(
      future: _metadataFuture,
      builder: (BuildContext context, AsyncSnapshot<Metadata?> snapshot) {
        return Text(
          widget.resolveText(snapshot.data),
          maxLines: widget.maxLines,
          overflow: widget.overflow,
          style: widget.style,
        );
      },
    );
  }
}

Metadata? _usableMetadataForItem({
  required PlayableItem item,
  required Metadata? metadata,
}) {
  if (metadata == null || metadata.stableId != item.stableId) {
    return null;
  }
  return metadata;
}
