import 'package:adaptive_palette/adaptive_palette.dart';
import 'package:bilimusic/core/cache/cache_util.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'player_cover_color_provider.g.dart';

const int _paletteCacheExtent = 96;
const int _maxColorCacheEntries = 160;

final Map<String, Color> _coverColorCache = <String, Color>{};

@Riverpod(keepAlive: true)
Future<Color?> playerCoverColor(Ref ref, String? coverUrl) async {
  final String resolvedUrl = coverUrl?.trim() ?? '';
  if (resolvedUrl.isEmpty) {
    return null;
  }

  final Color? cachedColor = _coverColorCache[resolvedUrl];
  if (cachedColor != null) {
    return cachedColor;
  }

  final List<Color> colors = await FluidPaletteExtractor.extractColors(
    CachedNetworkImageProvider(
      resolvedUrl,
      cacheManager: CacheUtil.imageCacheManager,
      maxWidth: _paletteCacheExtent,
      maxHeight: _paletteCacheExtent,
    ),
    count: 5,
  );
  final Color extractedColor = colors.first;
  _rememberCoverColor(resolvedUrl, extractedColor);
  return extractedColor;
}

void _rememberCoverColor(String url, Color color) {
  _coverColorCache[url] = color;
  if (_coverColorCache.length <= _maxColorCacheEntries) {
    return;
  }

  _coverColorCache.remove(_coverColorCache.keys.first);
}
