import 'package:bilimusic/feature/favorites/domain/favorite_collection.dart';
import 'package:bilimusic/feature/favorites/domain/favorite_entry.dart';
import 'package:bilimusic/feature/favorites/domain/favorite_membership.dart';
import 'package:bilimusic/feature/favorites/domain/favorites_state.dart';
import 'package:hive_ce/hive.dart';

const String remoteFavoriteCollectionsBoxName = 'remote_favorite_collections';
const String remoteFavoriteEntriesBoxName = 'remote_favorite_entries';
const String remoteFavoriteMembershipsBoxName = 'remote_favorite_memberships';

class FavoritesRemoteCacheRepository {
  FavoritesRemoteCacheRepository({
    required this.collectionsBox,
    required this.entriesBox,
    required this.membershipsBox,
  });

  final Box<FavoriteCollection> collectionsBox;
  final Box<FavoriteEntry> entriesBox;
  final Box<FavoriteMembership> membershipsBox;

  FavoritesState loadState() {
    final List<FavoriteCollection> collections =
        collectionsBox.values
            .where((FavoriteCollection collection) => collection.isManagedByApp)
            .toList()
          ..sort(
            (FavoriteCollection a, FavoriteCollection b) =>
                b.updatedAt.compareTo(a.updatedAt),
          );
    return FavoritesState(
      collections: collections,
      entries: entriesBox.values.toList(growable: false),
      memberships: membershipsBox.values.toList(growable: false),
    );
  }

  Future<void> bindCollection(FavoriteCollection collection) {
    return collectionsBox.put(
      collection.id,
      collection.copyWith(
        source: FavoriteCollectionSource.remote,
        isManagedByApp: true,
        lastSyncedAt: DateTime.now(),
      ),
    );
  }

  Future<void> upsertCollection(FavoriteCollection collection) async {
    final FavoriteCollection? existing = collectionsBox.get(collection.id);
    await collectionsBox.put(
      collection.id,
      collection.copyWith(
        source: FavoriteCollectionSource.remote,
        isManagedByApp: existing?.isManagedByApp ?? collection.isManagedByApp,
        lastSyncedAt: DateTime.now(),
      ),
    );
  }

  Future<void> replaceCollectionItems({
    required FavoriteCollection collection,
    required Iterable<FavoriteEntry> items,
  }) async {
    final DateTime now = DateTime.now();
    final FavoriteCollection? existing = collectionsBox.get(collection.id);
    await collectionsBox.put(
      collection.id,
      collection.copyWith(
        source: FavoriteCollectionSource.remote,
        isManagedByApp: existing?.isManagedByApp ?? collection.isManagedByApp,
        itemCount: collection.itemCount,
        lastSyncedAt: now,
      ),
    );

    final List<String> oldMembershipIds = membershipsBox.values
        .where(
          (FavoriteMembership membership) =>
              membership.collectionId == collection.id,
        )
        .map((FavoriteMembership membership) => membership.id)
        .toList(growable: false);
    if (oldMembershipIds.isNotEmpty) {
      await membershipsBox.deleteAll(oldMembershipIds);
    }

    final Map<String, FavoriteEntry> entryMap = <String, FavoriteEntry>{};
    final Map<String, FavoriteMembership> membershipMap =
        <String, FavoriteMembership>{};
    for (final FavoriteEntry entry in items) {
      entryMap[entry.itemId] = entry;
      final FavoriteMembership membership = FavoriteMembership.create(
        collectionId: collection.id,
        itemId: entry.itemId,
        addedAt: entry.createdAt,
      );
      membershipMap[membership.id] = membership;
    }
    await Future.wait(<Future<void>>[
      entriesBox.putAll(entryMap),
      membershipsBox.putAll(membershipMap),
    ]);
    await pruneOrphanEntries();
  }

  Future<void> appendCollectionItems({
    required FavoriteCollection collection,
    required Iterable<FavoriteEntry> items,
  }) async {
    final DateTime now = DateTime.now();
    final FavoriteCollection? existing = collectionsBox.get(collection.id);
    await collectionsBox.put(
      collection.id,
      collection.copyWith(
        source: FavoriteCollectionSource.remote,
        isManagedByApp: existing?.isManagedByApp ?? collection.isManagedByApp,
        itemCount: collection.itemCount,
        lastSyncedAt: now,
      ),
    );

    final Map<String, FavoriteEntry> entryMap = <String, FavoriteEntry>{};
    final Map<String, FavoriteMembership> membershipMap =
        <String, FavoriteMembership>{};
    for (final FavoriteEntry entry in items) {
      entryMap[entry.itemId] = entry;
      final FavoriteMembership membership = FavoriteMembership.create(
        collectionId: collection.id,
        itemId: entry.itemId,
        addedAt: entry.createdAt,
      );
      membershipMap[membership.id] = membership;
    }
    await Future.wait(<Future<void>>[
      entriesBox.putAll(entryMap),
      membershipsBox.putAll(membershipMap),
    ]);
  }

  Future<void> saveEntryToCollection({
    required String collectionId,
    required FavoriteEntry entry,
    required DateTime addedAt,
  }) async {
    await entriesBox.put(entry.itemId, entry);
    final FavoriteMembership membership = FavoriteMembership.create(
      collectionId: collectionId,
      itemId: entry.itemId,
      addedAt: addedAt,
    );
    await membershipsBox.put(membership.id, membership);
    final FavoriteCollection? collection = collectionsBox.get(collectionId);
    if (collection != null) {
      await collectionsBox.put(
        collectionId,
        collection.copyWith(
          itemCount: collection.itemCount + 1,
          updatedAt: addedAt,
          lastSyncedAt: DateTime.now(),
        ),
      );
    }
  }

  Future<void> removeEntryFromCollection({
    required String collectionId,
    required String itemId,
  }) async {
    await membershipsBox.delete(
      FavoriteMembership.membershipId(
        collectionId: collectionId,
        itemId: itemId,
      ),
    );
    final FavoriteCollection? collection = collectionsBox.get(collectionId);
    if (collection != null) {
      await collectionsBox.put(
        collectionId,
        collection.copyWith(
          itemCount: collection.itemCount > 0 ? collection.itemCount - 1 : 0,
          updatedAt: DateTime.now(),
          lastSyncedAt: DateTime.now(),
        ),
      );
    }
    await pruneOrphanEntries();
  }

  Future<void> deleteCollection(String collectionId) async {
    await collectionsBox.delete(collectionId);
    final List<String> membershipIds = membershipsBox.values
        .where(
          (FavoriteMembership membership) =>
              membership.collectionId == collectionId,
        )
        .map((FavoriteMembership membership) => membership.id)
        .toList(growable: false);
    if (membershipIds.isNotEmpty) {
      await membershipsBox.deleteAll(membershipIds);
    }
    await pruneOrphanEntries();
  }

  Future<void> pruneOrphanEntries() async {
    final Set<String> referencedIds = membershipsBox.values
        .map((FavoriteMembership membership) => membership.itemId)
        .toSet();
    final List<String> orphanIds = entriesBox.keys
        .whereType<String>()
        .where((String itemId) => !referencedIds.contains(itemId))
        .toList(growable: false);
    if (orphanIds.isNotEmpty) {
      await entriesBox.deleteAll(orphanIds);
    }
  }
}
