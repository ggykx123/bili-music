import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bilimusic/core/cache/app_cache_manager.dart';
import 'package:bilimusic/feature/metadata/domain/metadata.dart';
import 'package:bilimusic/feature/metadata/domain/metadata_cache_entry.dart';
import 'package:bilimusic/feature/player/domain/playable_item.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'metadata_cache_repository.g.dart';

@riverpod
MetadataCacheRepository metadataCacheRepository(Ref ref) {
  return MetadataCacheRepository(AppMetadataCacheManager.instance);
}

class MetadataCacheRepository {
  MetadataCacheRepository(this._cacheManager);

  final CacheManager _cacheManager;

  String buildCacheKey({required PlayableItem item}) {
    return 'metadata:${item.stableId}';
  }

  Future<MetadataCacheEntry?> getCachedEntry({
    required PlayableItem item,
  }) async {
    final String key = buildCacheKey(item: item);
    final FileInfo? fileInfo = await _cacheManager.getFileFromCache(key);
    if (fileInfo == null) {
      return null;
    }

    if (!await fileInfo.file.exists()) {
      await _cacheManager.removeFile(key);
      return null;
    }

    try {
      final String content = await fileInfo.file.readAsString();
      final dynamic decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        await _cacheManager.removeFile(key);
        return null;
      }

      final MetadataCacheEntry entry = MetadataCacheEntry.fromJson(decoded);
      if (entry.stableId != item.stableId) {
        await _cacheManager.removeFile(key);
        return null;
      }
      return entry;
    } on FormatException {
      await _cacheManager.removeFile(key);
      return null;
    } on FileSystemException {
      await _cacheManager.removeFile(key);
      return null;
    } on Object {
      await _cacheManager.removeFile(key);
      return null;
    }
  }

  Future<void> putCachedEntry({
    required PlayableItem item,
    required Metadata metadata,
  }) async {
    final MetadataCacheEntry entry = MetadataCacheEntry.fromMetadata(metadata);
    final Uint8List bytes = Uint8List.fromList(
      utf8.encode(jsonEncode(entry.toJson())),
    );
    await _cacheManager.putFile(
      buildCacheKey(item: item),
      bytes,
      fileExtension: 'json',
    );
  }

  Future<void> removeCachedEntry({required PlayableItem item}) {
    return _cacheManager.removeFile(buildCacheKey(item: item));
  }
}
