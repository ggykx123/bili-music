import 'dart:convert';

import 'package:bilimusic/feature/favorites/domain/favorite_collection.dart';
import 'package:bilimusic/feature/favorites/domain/favorite_entry.dart';
import 'package:bilimusic/feature/favorites/domain/favorite_membership.dart';
import 'package:bilimusic/feature/favorites/domain/favorites_state.dart';
import 'package:bilimusic/feature/setting/domain/clipboard_sync_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encodes and decodes compact favorites and settings payload', () {
    final DateTime now = DateTime.fromMillisecondsSinceEpoch(1710000000000);
    final FavoritesState favoritesState = FavoritesState(
      collections: <FavoriteCollection>[
        FavoriteCollection.liked(now: now),
        FavoriteCollection(
          id: 'custom_1',
          name: '歌单',
          createdAt: now,
          updatedAt: now,
        ),
      ],
      entries: <FavoriteEntry>[_entry('bvid:BV1:cid:11', now)],
      memberships: <FavoriteMembership>[
        FavoriteMembership.create(
          collectionId: FavoriteCollection.likedCollectionId,
          itemId: 'bvid:BV1:cid:11',
          addedAt: now,
        ),
      ],
    );
    final ClipboardSyncPayload payload = ClipboardSyncPayload(
      userId: '123',
      updatedAtEpochMs: now.millisecondsSinceEpoch,
      favoritesState: favoritesState,
      settings: const <String, String>{'player.blacklist_entries': '[]'},
    );

    final ClipboardSyncPayload decoded = ClipboardSyncPayload.fromJsonString(
      payload.toJsonString(),
    );

    expect(decoded.userId, '123');
    expect(decoded.favoritesState.collections, hasLength(2));
    expect(decoded.favoritesState.entries.single.pageTitle, '分段名');
    expect(decoded.favoritesState.memberships.single.addedAt, now);
    expect(decoded.settings['player.blacklist_entries'], '[]');
  });

  test('merge keeps local duplicate entries and imports remote-only items', () {
    final DateTime now = DateTime.fromMillisecondsSinceEpoch(1710000000000);
    final FavoriteEntry localEntry = _entry(
      'bvid:BV1:cid:11',
      now,
    ).copyWith(title: 'local');
    final FavoriteEntry remoteDuplicate = _entry(
      'bvid:BV1:cid:11',
      now,
    ).copyWith(title: 'remote');
    final FavoriteEntry remoteOnly = _entry('bvid:BV2:cid:22', now);

    final FavoritesState merged = mergeClipboardFavorites(
      localState: FavoritesState(
        collections: <FavoriteCollection>[FavoriteCollection.liked(now: now)],
        entries: <FavoriteEntry>[localEntry],
        memberships: <FavoriteMembership>[
          FavoriteMembership.create(
            collectionId: FavoriteCollection.likedCollectionId,
            itemId: localEntry.itemId,
            addedAt: now,
          ),
        ],
      ),
      remoteState: FavoritesState(
        collections: <FavoriteCollection>[FavoriteCollection.liked(now: now)],
        entries: <FavoriteEntry>[remoteDuplicate, remoteOnly],
        memberships: <FavoriteMembership>[
          FavoriteMembership.create(
            collectionId: FavoriteCollection.likedCollectionId,
            itemId: remoteDuplicate.itemId,
            addedAt: now,
          ),
          FavoriteMembership.create(
            collectionId: FavoriteCollection.likedCollectionId,
            itemId: remoteOnly.itemId,
            addedAt: now,
          ),
        ],
      ),
    );

    expect(merged.entries, hasLength(2));
    expect(
      merged.entries
          .firstWhere(
            (FavoriteEntry entry) => entry.itemId == localEntry.itemId,
          )
          .title,
      'local',
    );
    expect(merged.memberships, hasLength(2));
  });

  test('rejects unsupported payload versions', () {
    expect(
      () => ClipboardSyncPayload.fromJsonString(
        jsonEncode(<String, dynamic>{'v': 999}),
      ),
      throwsFormatException,
    );
  });
}

FavoriteEntry _entry(String itemId, DateTime now) {
  return FavoriteEntry(
    itemId: itemId,
    aid: 1,
    bvid: 'BV1',
    title: '投稿',
    author: '作者',
    coverUrl: 'cover',
    ownerMid: 100,
    cid: 11,
    page: 1,
    pageTitle: '分段名',
    durationText: '03:00',
    createdAt: now,
    updatedAt: now,
  );
}
