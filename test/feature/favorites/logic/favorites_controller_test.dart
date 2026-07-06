import 'dart:io';

import 'package:bilimusic/core/bili/session/bili_session.dart';
import 'package:bilimusic/core/hive/hive_adapters.dart';
import 'package:bilimusic/feature/favorites/data/favorites_local_repository.dart';
import 'package:bilimusic/feature/favorites/data/favorites_remote_cache_repository.dart';
import 'package:bilimusic/feature/favorites/domain/favorite_collection.dart';
import 'package:bilimusic/feature/favorites/domain/favorite_entry.dart';
import 'package:bilimusic/feature/favorites/domain/favorite_membership.dart';
import 'package:bilimusic/feature/favorites/logic/favorites_controller.dart';
import 'package:bilimusic/feature/player/data/bili_player_repository.dart';
import 'package:bilimusic/feature/player/domain/player_audio_quality_preference.dart';
import 'package:bilimusic/feature/player/domain/player_online_audience.dart';
import 'package:bilimusic/feature/player/domain/playable_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory tempDirectory;
  late _FakeBiliPlayerRepository playerRepository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'favorites-controller-test-',
    );
    Hive.init(tempDirectory.path);
    _registerHiveAdapters();
    await Hive.openBox<FavoriteCollection>(favoriteCollectionsBoxName);
    await Hive.openBox<FavoriteEntry>(favoriteEntriesBoxName);
    await Hive.openBox<FavoriteMembership>(favoriteMembershipsBoxName);
    await Hive.openBox<FavoriteCollection>(remoteFavoriteCollectionsBoxName);
    await Hive.openBox<FavoriteEntry>(remoteFavoriteEntriesBoxName);
    await Hive.openBox<FavoriteMembership>(remoteFavoriteMembershipsBoxName);
    playerRepository = _FakeBiliPlayerRepository();
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('does not expand synced cid-only multipart entries', () async {
    final DateTime now = DateTime(2026, 7, 6);
    const String itemId = 'bvid:BV1multi:cid:101';
    final ProviderContainer container = ProviderContainer(
      overrides: [
        biliPlayerRepositoryProvider.overrideWithValue(playerRepository),
      ],
    );
    addTearDown(container.dispose);

    final FavoritesLocalRepository repository = container.read(
      favoritesLocalRepositoryProvider,
    );
    await repository.initialize();
    await repository.saveEntry(
      FavoriteEntry(
        itemId: itemId,
        aid: 0,
        bvid: 'BV1multi',
        title: '1multi#101',
        author: '',
        coverUrl: '',
        cid: 101,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.saveMembership(
      FavoriteMembership.create(
        collectionId: FavoriteCollection.likedCollectionId,
        itemId: itemId,
        addedAt: now,
      ),
    );

    await container.read(favoritesControllerProvider.notifier).initialize();
    final int expandedCount = await container
        .read(favoritesControllerProvider.notifier)
        .expandCollectionMultipartEntries(FavoriteCollection.likedCollectionId);

    expect(expandedCount, 0);
    expect(playerRepository.resolvePlayablePartsCallCount, 0);
    expect(container.read(favoritesControllerProvider).entries, hasLength(1));
    expect(
      container.read(favoritesControllerProvider).memberships,
      hasLength(1),
    );
  });
}

void _registerHiveAdapters() {
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(FavoriteCollectionAdapter());
  }
  if (!Hive.isAdapterRegistered(10)) {
    Hive.registerAdapter(FavoriteCollectionSourceAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(FavoriteEntryAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(FavoriteMembershipAdapter());
  }
}

class _FakeBiliPlayerRepository implements BiliPlayerRepository {
  int resolvePlayablePartsCallCount = 0;

  @override
  Future<List<PlayableItem>> resolvePlayableParts(PlayableItem item) async {
    resolvePlayablePartsCallCount++;
    return <PlayableItem>[
      item.copyWith(cid: 101, page: 1, pageTitle: 'Part 1'),
      item.copyWith(cid: 102, page: 2, pageTitle: 'Part 2'),
    ];
  }

  @override
  Future<PlayerOnlineAudience> fetchOnlineAudience({
    required int cid,
    required int aid,
    required String bvid,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PlayerLoadResult> resolveAudioStream(
    PlayableItem item, {
    required BiliSession? session,
    required PlayerAudioQualityPreference qualityPreference,
    int? preferredQualityId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PlayableItem> resolvePreferredPart(
    PlayableItem item, {
    int preferredPage = 1,
  }) {
    throw UnimplementedError();
  }
}
