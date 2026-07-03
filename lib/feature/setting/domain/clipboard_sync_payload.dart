import 'dart:convert';

import 'package:bilimusic/feature/favorites/domain/favorite_collection.dart';
import 'package:bilimusic/feature/favorites/domain/favorite_entry.dart';
import 'package:bilimusic/feature/favorites/domain/favorite_membership.dart';
import 'package:bilimusic/feature/favorites/domain/favorites_state.dart';

const int clipboardSyncPayloadVersion = 1;

class ClipboardSyncPayload {
  const ClipboardSyncPayload({
    required this.userId,
    required this.updatedAtEpochMs,
    required this.favoritesState,
    required this.settings,
  });

  final String userId;
  final int updatedAtEpochMs;
  final FavoritesState favoritesState;
  final Map<String, String> settings;

  factory ClipboardSyncPayload.fromJsonString(String value) {
    final Object? decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Clipboard payload must be an object.');
    }
    if (_readInt(decoded['v']) != clipboardSyncPayloadVersion) {
      throw const FormatException('Unsupported clipboard payload version.');
    }

    return ClipboardSyncPayload(
      userId: _readString(decoded['u']),
      updatedAtEpochMs: _readInt(decoded['t']),
      favoritesState: FavoritesState(
        collections: _readRows(
          decoded['c'],
        ).map(_collectionFromRow).toList(growable: false),
        entries: _readRows(
          decoded['e'],
        ).map(_entryFromRow).toList(growable: false),
        memberships: _readRows(
          decoded['m'],
        ).map(_membershipFromRow).toList(growable: false),
      ),
      settings: _readSettings(decoded['s']),
    );
  }

  String toJsonString() {
    final Map<String, dynamic> payload = <String, dynamic>{
      'v': clipboardSyncPayloadVersion,
      'u': userId,
      't': updatedAtEpochMs,
      'c': favoritesState.collections.map(_collectionToRow).toList(),
      'e': favoritesState.entries.map(_entryToRow).toList(),
      'm': favoritesState.memberships.map(_membershipToRow).toList(),
      's': settings,
    };
    return jsonEncode(payload);
  }
}

FavoritesState mergeClipboardFavorites({
  required FavoritesState localState,
  required FavoritesState remoteState,
}) {
  final Map<String, FavoriteCollection> collections =
      <String, FavoriteCollection>{};
  for (final FavoriteCollection collection in remoteState.collections) {
    collections[collection.id] = collection;
  }
  for (final FavoriteCollection collection in localState.collections) {
    collections[collection.id] = collection;
  }
  collections.putIfAbsent(
    FavoriteCollection.likedCollectionId,
    FavoriteCollection.liked,
  );

  final Map<String, FavoriteEntry> entries = <String, FavoriteEntry>{};
  for (final FavoriteEntry entry in remoteState.entries) {
    entries[entry.itemId] = entry;
  }
  for (final FavoriteEntry entry in localState.entries) {
    entries[entry.itemId] = entry;
  }

  final Map<String, FavoriteMembership> memberships =
      <String, FavoriteMembership>{};
  for (final FavoriteMembership membership in remoteState.memberships) {
    memberships[membership.id] = membership;
  }
  for (final FavoriteMembership membership in localState.memberships) {
    memberships[membership.id] = membership;
  }

  return FavoritesState(
    collections: collections.values.toList(growable: false),
    entries: entries.values.toList(growable: false),
    memberships: memberships.values.toList(growable: false),
  );
}

List<dynamic> _collectionToRow(FavoriteCollection collection) {
  return <dynamic>[
    collection.id,
    collection.name,
    collection.source.name,
    collection.isSystem ? 1 : 0,
    collection.remoteId,
    collection.coverUrl,
    collection.itemCount,
    collection.isManagedByApp ? 1 : 0,
    _epochMs(collection.lastSyncedAt),
    _epochMs(collection.createdAt),
    _epochMs(collection.updatedAt),
  ];
}

FavoriteCollection _collectionFromRow(List<dynamic> row) {
  final DateTime now = DateTime.now();
  return FavoriteCollection(
    id: _readStringAt(row, 0),
    name: _readStringAt(row, 1),
    source: _readCollectionSource(_readStringAt(row, 2)),
    isSystem: _readBoolAt(row, 3),
    remoteId: _readNullableStringAt(row, 4),
    coverUrl: _readNullableStringAt(row, 5),
    itemCount: _readIntAt(row, 6),
    isManagedByApp: _readBoolAt(row, 7),
    lastSyncedAt: _readNullableDateAt(row, 8),
    createdAt: _readNullableDateAt(row, 9) ?? now,
    updatedAt: _readNullableDateAt(row, 10) ?? now,
  );
}

List<dynamic> _entryToRow(FavoriteEntry entry) {
  return <dynamic>[
    entry.itemId,
    entry.aid,
    entry.bvid,
    entry.title,
    entry.author,
    entry.coverUrl,
    entry.ownerMid,
    entry.cid,
    entry.page,
    entry.pageTitle,
    entry.durationText,
    _epochMs(entry.createdAt),
    _epochMs(entry.updatedAt),
  ];
}

FavoriteEntry _entryFromRow(List<dynamic> row) {
  final DateTime now = DateTime.now();
  return FavoriteEntry(
    itemId: _readStringAt(row, 0),
    aid: _readIntAt(row, 1),
    bvid: _readStringAt(row, 2),
    title: _readStringAt(row, 3),
    author: _readStringAt(row, 4),
    coverUrl: _readStringAt(row, 5),
    ownerMid: _readNullableIntAt(row, 6),
    cid: _readNullableIntAt(row, 7),
    page: _readNullableIntAt(row, 8),
    pageTitle: _readNullableStringAt(row, 9),
    durationText: _readNullableStringAt(row, 10),
    createdAt: _readNullableDateAt(row, 11) ?? now,
    updatedAt: _readNullableDateAt(row, 12) ?? now,
  );
}

List<dynamic> _membershipToRow(FavoriteMembership membership) {
  return <dynamic>[
    membership.id,
    membership.collectionId,
    membership.itemId,
    _epochMs(membership.addedAt),
  ];
}

FavoriteMembership _membershipFromRow(List<dynamic> row) {
  final String collectionId = _readStringAt(row, 1);
  final String itemId = _readStringAt(row, 2);
  return FavoriteMembership(
    id: _readStringAt(row, 0).isEmpty
        ? FavoriteMembership.membershipId(
            collectionId: collectionId,
            itemId: itemId,
          )
        : _readStringAt(row, 0),
    collectionId: collectionId,
    itemId: itemId,
    addedAt: _readNullableDateAt(row, 3) ?? DateTime.now(),
  );
}

FavoriteCollectionSource _readCollectionSource(String value) {
  return FavoriteCollectionSource.values.firstWhere(
    (FavoriteCollectionSource source) => source.name == value,
    orElse: () => FavoriteCollectionSource.local,
  );
}

Map<String, String> _readSettings(Object? value) {
  if (value is! Map<String, dynamic>) {
    return const <String, String>{};
  }
  return <String, String>{
    for (final MapEntry<String, dynamic> entry in value.entries)
      if (entry.value is String) entry.key: entry.value as String,
  };
}

List<List<dynamic>> _readRows(Object? value) {
  if (value is! List<dynamic>) {
    return const <List<dynamic>>[];
  }
  return value
      .whereType<List<dynamic>>()
      .map((List<dynamic> row) => row)
      .toList(growable: false);
}

int? _epochMs(DateTime? value) {
  return value?.millisecondsSinceEpoch;
}

DateTime? _readNullableDateAt(List<dynamic> row, int index) {
  final int? value = _readNullableIntAt(row, index);
  if (value == null || value <= 0) {
    return null;
  }
  return DateTime.fromMillisecondsSinceEpoch(value);
}

String _readString(Object? value) {
  return value is String ? value : '';
}

int _readInt(Object? value) {
  return (value as num?)?.toInt() ?? 0;
}

String _readStringAt(List<dynamic> row, int index) {
  if (index < 0 || index >= row.length) {
    return '';
  }
  return _readString(row[index]);
}

String? _readNullableStringAt(List<dynamic> row, int index) {
  final String value = _readStringAt(row, index).trim();
  return value.isEmpty ? null : value;
}

int _readIntAt(List<dynamic> row, int index) {
  if (index < 0 || index >= row.length) {
    return 0;
  }
  return _readInt(row[index]);
}

int? _readNullableIntAt(List<dynamic> row, int index) {
  if (index < 0 || index >= row.length) {
    return null;
  }
  final Object? value = row[index];
  if (value == null) {
    return null;
  }
  return _readInt(value);
}

bool _readBoolAt(List<dynamic> row, int index) {
  if (index < 0 || index >= row.length) {
    return false;
  }
  final Object? value = row[index];
  if (value is bool) {
    return value;
  }
  return _readInt(value) == 1;
}
