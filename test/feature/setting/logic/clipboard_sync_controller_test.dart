import 'dart:io';

import 'package:bilimusic/core/bili/session/bili_session.dart';
import 'package:bilimusic/core/bili/session/bili_session_controller.dart';
import 'package:bilimusic/core/hive/hive_adapters.dart';
import 'package:bilimusic/core/hive/hive_keys.dart';
import 'package:bilimusic/feature/favorites/data/favorites_local_repository.dart';
import 'package:bilimusic/feature/favorites/data/favorites_remote_cache_repository.dart';
import 'package:bilimusic/feature/favorites/domain/favorite_collection.dart';
import 'package:bilimusic/feature/favorites/domain/favorite_entry.dart';
import 'package:bilimusic/feature/favorites/domain/favorite_membership.dart';
import 'package:bilimusic/feature/favorites/domain/favorites_state.dart';
import 'package:bilimusic/feature/favorites/logic/favorites_controller.dart';
import 'package:bilimusic/feature/setting/data/clipboard_sync_repository.dart';
import 'package:bilimusic/feature/setting/domain/clipboard_sync_payload.dart';
import 'package:bilimusic/feature/setting/logic/clipboard_sync_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory tempDirectory;
  late _FakeClipboardSyncRepository clipboardRepository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'clipboard-sync-controller-test-',
    );
    Hive.init(tempDirectory.path);
    _registerHiveAdapters();
    await Hive.openBox<FavoriteCollection>(favoriteCollectionsBoxName);
    await Hive.openBox<FavoriteEntry>(favoriteEntriesBoxName);
    await Hive.openBox<FavoriteMembership>(favoriteMembershipsBoxName);
    await Hive.openBox<FavoriteCollection>(remoteFavoriteCollectionsBoxName);
    await Hive.openBox<FavoriteEntry>(remoteFavoriteEntriesBoxName);
    await Hive.openBox<FavoriteMembership>(remoteFavoriteMembershipsBoxName);
    await Hive.openBox<String>(HiveBoxNames.prefs);
    clipboardRepository = _FakeClipboardSyncRepository();
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('syncs once after a user logs in', () async {
    final DateTime now = DateTime(2026, 7, 3, 12);
    final FavoriteEntry remoteEntry = _entry(
      itemId: 'bvid:BVremote:cid:22',
      title: '远端歌曲',
      now: now,
    );
    final FavoritesState remoteState = FavoritesState(
      collections: <FavoriteCollection>[FavoriteCollection.liked(now: now)],
      entries: <FavoriteEntry>[remoteEntry],
      memberships: <FavoriteMembership>[
        FavoriteMembership.create(
          collectionId: FavoriteCollection.likedCollectionId,
          itemId: remoteEntry.itemId,
          addedAt: now,
        ),
      ],
    );
    clipboardRepository.remoteContent = ClipboardSyncPayload(
      userId: '123',
      updatedAtEpochMs: now.millisecondsSinceEpoch,
      favoritesState: remoteState,
      settings: const <String, String>{},
    ).toJsonString();

    final ProviderContainer container = ProviderContainer(
      overrides: [
        clipboardSyncRepositoryProvider.overrideWithValue(clipboardRepository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(favoritesControllerProvider.notifier).initialize();
    container.read(clipboardSyncControllerProvider.notifier).activate();

    await container
        .read(biliSessionControllerProvider.notifier)
        .setSession(
          const BiliSession(
            sessData: 'sess',
            biliJct: 'jct',
            dedeUserId: '123',
            refreshToken: 'refresh',
            cookie: 'SESSDATA=sess; DedeUserID=123',
            mid: 123,
          ),
        );
    await _waitForPhase(container, ClipboardSyncPhase.success);
    await Future<void>.delayed(Duration.zero);

    expect(clipboardRepository.loadedNames, <String>['123bilimusic']);
    expect(clipboardRepository.savedNames, isEmpty);
    expect(
      container
          .read(favoritesControllerProvider)
          .entries
          .map((FavoriteEntry entry) => entry.itemId),
      contains(remoteEntry.itemId),
    );
    expect(
      container.read(clipboardSyncControllerProvider).phase,
      ClipboardSyncPhase.success,
    );
  });

  test('syncs once on activate when session already exists', () async {
    final DateTime now = DateTime(2026, 7, 3, 13);
    final FavoriteEntry remoteEntry = _entry(
      itemId: 'bvid:BVstartup:cid:33',
      title: '启动同步歌曲',
      now: now,
    );
    clipboardRepository.remoteContent = ClipboardSyncPayload(
      userId: '456',
      updatedAtEpochMs: now.millisecondsSinceEpoch,
      favoritesState: FavoritesState(
        collections: <FavoriteCollection>[FavoriteCollection.liked(now: now)],
        entries: <FavoriteEntry>[remoteEntry],
        memberships: <FavoriteMembership>[
          FavoriteMembership.create(
            collectionId: FavoriteCollection.likedCollectionId,
            itemId: remoteEntry.itemId,
            addedAt: now,
          ),
        ],
      ),
      settings: const <String, String>{},
    ).toJsonString();

    final ProviderContainer container = ProviderContainer(
      overrides: [
        clipboardSyncRepositoryProvider.overrideWithValue(clipboardRepository),
        biliSessionControllerProvider.overrideWithValue(
          const BiliSession(
            sessData: 'sess',
            biliJct: 'jct',
            dedeUserId: '456',
            refreshToken: 'refresh',
            cookie: 'SESSDATA=sess; DedeUserID=456',
            mid: 456,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(favoritesControllerProvider.notifier).initialize();
    container.read(clipboardSyncControllerProvider.notifier).activate();
    await _waitForPhase(container, ClipboardSyncPhase.success);
    await Future<void>.delayed(Duration.zero);

    expect(clipboardRepository.loadedNames, <String>['456bilimusic']);
    expect(clipboardRepository.savedNames, isEmpty);
    expect(
      container
          .read(favoritesControllerProvider)
          .entries
          .map((FavoriteEntry entry) => entry.itemId),
      contains(remoteEntry.itemId),
    );
    expect(
      container.read(clipboardSyncControllerProvider).phase,
      ClipboardSyncPhase.success,
    );
  });

  test('rejects upload when remote snapshot is newer than last sync', () async {
    final DateTime now = DateTime(2026, 7, 3, 14);
    clipboardRepository.remoteContent = ClipboardSyncPayload(
      userId: '789',
      updatedAtEpochMs: now.millisecondsSinceEpoch,
      favoritesState: FavoritesState(
        collections: <FavoriteCollection>[FavoriteCollection.liked(now: now)],
        entries: <FavoriteEntry>[
          _entry(itemId: 'bvid:BVbase:cid:11', title: '初始远端歌曲', now: now),
        ],
        memberships: <FavoriteMembership>[
          FavoriteMembership.create(
            collectionId: FavoriteCollection.likedCollectionId,
            itemId: 'bvid:BVbase:cid:11',
            addedAt: now,
          ),
        ],
      ),
      settings: const <String, String>{},
    ).toJsonString();

    final ProviderContainer container = ProviderContainer(
      overrides: [
        clipboardSyncRepositoryProvider.overrideWithValue(clipboardRepository),
        biliSessionControllerProvider.overrideWithValue(
          const BiliSession(
            sessData: 'sess',
            biliJct: 'jct',
            dedeUserId: '789',
            refreshToken: 'refresh',
            cookie: 'SESSDATA=sess; DedeUserID=789',
            mid: 789,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(favoritesControllerProvider.notifier).initialize();
    container.read(clipboardSyncControllerProvider.notifier).activate();
    await _waitForPhase(container, ClipboardSyncPhase.success);
    clipboardRepository.remoteContent = ClipboardSyncPayload(
      userId: '789',
      updatedAtEpochMs: now.millisecondsSinceEpoch + 1000,
      favoritesState: FavoritesState(
        collections: <FavoriteCollection>[FavoriteCollection.liked(now: now)],
        entries: <FavoriteEntry>[
          _entry(itemId: 'bvid:BVnewer:cid:22', title: '更新远端歌曲', now: now),
        ],
        memberships: <FavoriteMembership>[
          FavoriteMembership.create(
            collectionId: FavoriteCollection.likedCollectionId,
            itemId: 'bvid:BVnewer:cid:22',
            addedAt: now,
          ),
        ],
      ),
      settings: const <String, String>{},
    ).toJsonString();

    await container.read(clipboardSyncControllerProvider.notifier).uploadNow();

    expect(clipboardRepository.savedContents, isEmpty);
    expect(
      container.read(clipboardSyncControllerProvider).phase,
      ClipboardSyncPhase.failure,
    );
    expect(
      container.read(clipboardSyncControllerProvider).message,
      contains('远端数据更新'),
    );
  });

  test(
    'remote newer snapshot replaces local data and removes stale items',
    () async {
      final DateTime now = DateTime(2026, 7, 3, 15);
      final FavoriteEntry localEntry = _entry(
        itemId: 'bvid:BVlocal:cid:11',
        title: '本地旧歌曲',
        now: now,
      );
      final FavoriteEntry remoteEntry = _entry(
        itemId: 'bvid:BVremote:cid:22',
        title: '远端新歌曲',
        now: now.add(const Duration(minutes: 1)),
      );
      clipboardRepository.remoteContent = ClipboardSyncPayload(
        userId: '100',
        updatedAtEpochMs: now
            .add(const Duration(minutes: 1))
            .millisecondsSinceEpoch,
        favoritesState: _likedState(remoteEntry, now),
        settings: const <String, String>{},
      ).toJsonString();

      final ProviderContainer container = ProviderContainer(
        overrides: [
          clipboardSyncRepositoryProvider.overrideWithValue(
            clipboardRepository,
          ),
          biliSessionControllerProvider.overrideWithValue(
            const BiliSession(
              sessData: 'sess',
              biliJct: 'jct',
              dedeUserId: '100',
              refreshToken: 'refresh',
              cookie: 'SESSDATA=sess; DedeUserID=100',
              mid: 100,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(favoritesControllerProvider.notifier).initialize();
      await container
          .read(favoritesLocalRepositoryProvider)
          .replaceAll(_likedState(localEntry, now));
      await container.read(favoritesControllerProvider.notifier).reload();

      await container.read(clipboardSyncControllerProvider.notifier).syncNow();

      final List<String> itemIds = container
          .read(favoritesControllerProvider)
          .entries
          .map((FavoriteEntry entry) => entry.itemId)
          .toList(growable: false);
      expect(itemIds, <String>[remoteEntry.itemId]);
      expect(clipboardRepository.savedContents, isEmpty);
    },
  );

  test(
    'local newer snapshot uploads instead of pulling stale remote',
    () async {
      final DateTime now = DateTime(2026, 7, 3, 16);
      final FavoriteEntry localEntry = _entry(
        itemId: 'bvid:BVlocalnew:cid:11',
        title: '本地新歌曲',
        now: now.add(const Duration(minutes: 1)),
      );
      final FavoriteEntry remoteEntry = _entry(
        itemId: 'bvid:BVremoteold:cid:22',
        title: '远端旧歌曲',
        now: now,
      );
      clipboardRepository.remoteContent = ClipboardSyncPayload(
        userId: '101',
        updatedAtEpochMs: now.millisecondsSinceEpoch,
        favoritesState: _likedState(remoteEntry, now),
        settings: const <String, String>{},
      ).toJsonString();

      final ProviderContainer container = ProviderContainer(
        overrides: [
          clipboardSyncRepositoryProvider.overrideWithValue(
            clipboardRepository,
          ),
          biliSessionControllerProvider.overrideWithValue(
            const BiliSession(
              sessData: 'sess',
              biliJct: 'jct',
              dedeUserId: '101',
              refreshToken: 'refresh',
              cookie: 'SESSDATA=sess; DedeUserID=101',
              mid: 101,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(favoritesControllerProvider.notifier).initialize();
      await container
          .read(favoritesLocalRepositoryProvider)
          .replaceAll(
            _likedState(localEntry, now.add(const Duration(minutes: 1))),
          );
      await container.read(favoritesControllerProvider.notifier).reload();

      await container.read(clipboardSyncControllerProvider.notifier).syncNow();

      expect(clipboardRepository.savedNames, <String>['101bilimusic']);
      final ClipboardSyncPayload savedPayload =
          ClipboardSyncPayload.fromJsonString(
            clipboardRepository.savedContents.single,
          );
      expect(
        savedPayload.favoritesState.entries.map(
          (FavoriteEntry entry) => entry.itemId,
        ),
        contains(localEntry.itemId),
      );
    },
  );

  test('force pull overwrites newer local data', () async {
    final DateTime now = DateTime(2026, 7, 3, 17);
    final FavoriteEntry localEntry = _entry(
      itemId: 'bvid:BVforceLocal:cid:11',
      title: '本地歌曲',
      now: now.add(const Duration(minutes: 1)),
    );
    final FavoriteEntry remoteEntry = _entry(
      itemId: 'bvid:BVforceRemote:cid:22',
      title: '远端歌曲',
      now: now,
    );
    clipboardRepository.remoteContent = ClipboardSyncPayload(
      userId: '102',
      updatedAtEpochMs: now.millisecondsSinceEpoch,
      favoritesState: _likedState(remoteEntry, now),
      settings: const <String, String>{},
    ).toJsonString();

    final ProviderContainer container = ProviderContainer(
      overrides: [
        clipboardSyncRepositoryProvider.overrideWithValue(clipboardRepository),
        biliSessionControllerProvider.overrideWithValue(
          const BiliSession(
            sessData: 'sess',
            biliJct: 'jct',
            dedeUserId: '102',
            refreshToken: 'refresh',
            cookie: 'SESSDATA=sess; DedeUserID=102',
            mid: 102,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(favoritesControllerProvider.notifier).initialize();
    await container
        .read(favoritesLocalRepositoryProvider)
        .replaceAll(
          _likedState(localEntry, now.add(const Duration(minutes: 1))),
        );
    await container.read(favoritesControllerProvider.notifier).reload();

    await container
        .read(clipboardSyncControllerProvider.notifier)
        .forcePullNow();

    expect(
      container
          .read(favoritesControllerProvider)
          .entries
          .map((FavoriteEntry entry) => entry.itemId),
      <String>[remoteEntry.itemId],
    );
    expect(clipboardRepository.savedContents, isEmpty);
  });

  test('force upload overwrites newer remote data', () async {
    final DateTime now = DateTime(2026, 7, 3, 18);
    final FavoriteEntry localEntry = _entry(
      itemId: 'bvid:BVforceUpload:cid:11',
      title: '本地歌曲',
      now: now,
    );
    final FavoriteEntry remoteEntry = _entry(
      itemId: 'bvid:BVnewRemote:cid:22',
      title: '远端新歌曲',
      now: now.add(const Duration(minutes: 1)),
    );
    clipboardRepository.remoteContent = ClipboardSyncPayload(
      userId: '103',
      updatedAtEpochMs: now
          .add(const Duration(minutes: 1))
          .millisecondsSinceEpoch,
      favoritesState: _likedState(
        remoteEntry,
        now.add(const Duration(minutes: 1)),
      ),
      settings: const <String, String>{},
    ).toJsonString();

    final ProviderContainer container = ProviderContainer(
      overrides: [
        clipboardSyncRepositoryProvider.overrideWithValue(clipboardRepository),
        biliSessionControllerProvider.overrideWithValue(
          const BiliSession(
            sessData: 'sess',
            biliJct: 'jct',
            dedeUserId: '103',
            refreshToken: 'refresh',
            cookie: 'SESSDATA=sess; DedeUserID=103',
            mid: 103,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(favoritesControllerProvider.notifier).initialize();
    await container
        .read(favoritesLocalRepositoryProvider)
        .replaceAll(_likedState(localEntry, now));
    await container.read(favoritesControllerProvider.notifier).reload();

    await container
        .read(clipboardSyncControllerProvider.notifier)
        .forceUploadNow();

    expect(clipboardRepository.savedNames, <String>['103bilimusic']);
    final ClipboardSyncPayload savedPayload =
        ClipboardSyncPayload.fromJsonString(
          clipboardRepository.savedContents.single,
        );
    expect(
      savedPayload.favoritesState.entries.map(
        (FavoriteEntry entry) => entry.itemId,
      ),
      contains(localEntry.itemId),
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

FavoriteEntry _entry({
  required String itemId,
  required String title,
  required DateTime now,
}) {
  return FavoriteEntry(
    itemId: itemId,
    aid: 1,
    bvid: 'BVremote',
    title: title,
    author: '作者',
    coverUrl: 'cover',
    cid: 22,
    page: 1,
    pageTitle: '分段',
    createdAt: now,
    updatedAt: now,
  );
}

FavoritesState _likedState(FavoriteEntry entry, DateTime now) {
  return FavoritesState(
    collections: <FavoriteCollection>[FavoriteCollection.liked(now: now)],
    entries: <FavoriteEntry>[entry],
    memberships: <FavoriteMembership>[
      FavoriteMembership.create(
        collectionId: FavoriteCollection.likedCollectionId,
        itemId: entry.itemId,
        addedAt: now,
      ),
    ],
  );
}

Future<void> _waitForPhase(
  ProviderContainer container,
  ClipboardSyncPhase phase,
) async {
  for (int attempt = 0; attempt < 100; attempt += 1) {
    if (container.read(clipboardSyncControllerProvider).phase == phase) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail(
    'Timed out waiting for $phase, current: '
    '${container.read(clipboardSyncControllerProvider).phase}',
  );
}

class _FakeClipboardSyncRepository extends ClipboardSyncRepository {
  _FakeClipboardSyncRepository() : super();

  String? remoteContent;
  final List<String> loadedNames = <String>[];
  final List<String> savedNames = <String>[];
  final List<String> savedContents = <String>[];

  @override
  Future<String?> loadContent(String clipboardName) async {
    loadedNames.add(clipboardName);
    return remoteContent;
  }

  @override
  Future<void> saveContent({
    required String clipboardName,
    required String content,
  }) async {
    savedNames.add(clipboardName);
    savedContents.add(content);
  }
}
