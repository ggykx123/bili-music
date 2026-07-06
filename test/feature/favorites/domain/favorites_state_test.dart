import 'package:bilimusic/feature/favorites/domain/favorite_collection.dart';
import 'package:bilimusic/feature/favorites/domain/favorite_entry.dart';
import 'package:bilimusic/feature/favorites/domain/favorite_membership.dart';
import 'package:bilimusic/feature/favorites/domain/favorites_state.dart';
import 'package:bilimusic/feature/player/domain/playable_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'matches liked multipart entries by cid without marking sibling parts',
    () {
      final DateTime now = DateTime(2026);
      const String likedItemId = 'bvid:BV1multi:cid:101';
      final FavoritesState state = FavoritesState(
        collections: <FavoriteCollection>[FavoriteCollection.liked(now: now)],
        entries: <FavoriteEntry>[
          FavoriteEntry(
            itemId: likedItemId,
            aid: 0,
            bvid: 'BV1multi',
            title: '1multi#101',
            author: '',
            coverUrl: '',
            cid: 101,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        memberships: <FavoriteMembership>[
          FavoriteMembership.create(
            collectionId: FavoriteCollection.likedCollectionId,
            itemId: likedItemId,
            addedAt: now,
          ),
        ],
      );

      expect(
        state.isLiked(
          const PlayableItem(
            aid: 123,
            bvid: 'BV1multi',
            title: '投稿',
            author: '作者',
            coverUrl: '',
            cid: 101,
            page: 2,
            pageTitle: '已喜欢分段',
          ),
        ),
        isTrue,
      );
      expect(
        state
            .membershipsForItemInCollection(
              collectionId: FavoriteCollection.likedCollectionId,
              item: const PlayableItem(
                aid: 123,
                bvid: 'BV1multi',
                title: '投稿',
                author: '作者',
                coverUrl: '',
                cid: 101,
                page: 2,
                pageTitle: '已喜欢分段',
              ),
            )
            .single
            .itemId,
        likedItemId,
      );
      expect(
        state.isLiked(
          const PlayableItem(
            aid: 123,
            bvid: 'BV1multi',
            title: '投稿',
            author: '作者',
            coverUrl: '',
            cid: 102,
            page: 3,
            pageTitle: '未喜欢分段',
          ),
        ),
        isFalse,
      );
    },
  );
}
