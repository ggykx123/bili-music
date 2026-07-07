import 'dart:async';

import 'package:bilimusic/core/bili/session/bili_session.dart';
import 'package:bilimusic/core/bili/session/bili_session_controller.dart';
import 'package:bilimusic/core/settings/app_settings_store.dart';
import 'package:bilimusic/core/theme/theme_logic.dart';
import 'package:bilimusic/feature/favorites/data/favorites_local_repository.dart';
import 'package:bilimusic/feature/favorites/domain/favorite_collection.dart';
import 'package:bilimusic/feature/favorites/domain/favorite_entry.dart';
import 'package:bilimusic/feature/favorites/domain/favorite_membership.dart';
import 'package:bilimusic/feature/favorites/domain/favorites_state.dart';
import 'package:bilimusic/feature/player/logic/desktop_lyrics_settings_controller.dart';
import 'package:bilimusic/feature/favorites/logic/favorites_controller.dart';
import 'package:bilimusic/feature/player/logic/player_audio_quality_preference_logic.dart';
import 'package:bilimusic/feature/player/logic/player_blacklist_controller.dart';
import 'package:bilimusic/feature/player/logic/player_lyric_font_preference_logic.dart';
import 'package:bilimusic/feature/player/logic/player_lyric_font_size_preference_logic.dart';
import 'package:bilimusic/feature/player/logic/player_multi_part_queue_preference_logic.dart';
import 'package:bilimusic/feature/player/logic/player_settings_logic.dart';
import 'package:bilimusic/feature/setting/data/app_transfer_repository.dart';
import 'package:bilimusic/feature/setting/data/clipboard_sync_repository.dart';
import 'package:bilimusic/feature/setting/domain/clipboard_sync_payload.dart';
import 'package:bilimusic/feature/setting/logic/appearance_setting_logic.dart';
import 'package:bilimusic/feature/setting/logic/hotkey_settings_logic.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'clipboard_sync_controller.g.dart';

const Duration clipboardSyncAutoUploadDelay = Duration(seconds: 10);
const String _clipboardSyncLocalUpdatedAtPrefix =
    'clipboard_sync.local_updated_at.';
const String _clipboardSyncRemoteUpdatedAtPrefix =
    'clipboard_sync.remote_updated_at.';

enum ClipboardSyncPhase {
  idle,
  scheduled,
  uploading,
  syncing,
  success,
  failure,
}

class ClipboardSyncState {
  const ClipboardSyncState({
    this.phase = ClipboardSyncPhase.idle,
    this.clipboardName,
    this.lastUploadedAt,
    this.lastSyncedAt,
    this.message,
  });

  final ClipboardSyncPhase phase;
  final String? clipboardName;
  final DateTime? lastUploadedAt;
  final DateTime? lastSyncedAt;
  final String? message;

  bool get isBusy =>
      phase == ClipboardSyncPhase.uploading ||
      phase == ClipboardSyncPhase.syncing;

  bool get isScheduled => phase == ClipboardSyncPhase.scheduled;

  ClipboardSyncState copyWith({
    ClipboardSyncPhase? phase,
    String? clipboardName,
    DateTime? lastUploadedAt,
    DateTime? lastSyncedAt,
    String? message,
    bool clearMessage = false,
  }) {
    return ClipboardSyncState(
      phase: phase ?? this.phase,
      clipboardName: clipboardName ?? this.clipboardName,
      lastUploadedAt: lastUploadedAt ?? this.lastUploadedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

@Riverpod(keepAlive: true)
class ClipboardSyncController extends _$ClipboardSyncController {
  Timer? _autoUploadTimer;
  String? _lastSnapshotFingerprint;
  bool _isInitialized = false;
  bool _isApplyingRemoteSnapshot = false;
  String? _activeUserId;
  String? _autoSyncedLoginUserId;

  @override
  ClipboardSyncState build() {
    ref.onDispose(() {
      _autoUploadTimer?.cancel();
    });

    _listenForLocalChanges();
    return ClipboardSyncState(clipboardName: _clipboardNameOrNull());
  }

  void activate() {
    _isInitialized = true;
    _activeUserId = _userIdOrNull();
    final String? clipboardName = _clipboardNameForUserId(_activeUserId);
    _lastSnapshotFingerprint = clipboardName == null
        ? null
        : _buildLocalFingerprint();
    state = ClipboardSyncState(
      clipboardName: clipboardName,
      message: clipboardName == null ? '登录后可使用网络剪贴板同步' : null,
    );
    if (_activeUserId != null) {
      _autoSyncedLoginUserId = _activeUserId;
      unawaited(syncNow());
    }
  }

  Future<void> uploadNow() async {
    _autoUploadTimer?.cancel();
    await _uploadCurrentSnapshot(isAutomatic: false, force: false);
  }

  Future<void> forceUploadNow() async {
    _autoUploadTimer?.cancel();
    await _uploadCurrentSnapshot(isAutomatic: false, force: true);
  }

  Future<void> forcePullNow() async {
    _autoUploadTimer?.cancel();
    final String? clipboardName = _clipboardNameOrNull();
    final String? userId = _activeUserId ?? _userIdOrNull();
    if (clipboardName == null || userId == null) {
      state = const ClipboardSyncState(message: '登录后才能使用网络剪贴板同步。');
      return;
    }
    state = state.copyWith(
      phase: ClipboardSyncPhase.syncing,
      clipboardName: clipboardName,
      clearMessage: true,
    );

    try {
      final String? remoteContent = await ref
          .read(clipboardSyncRepositoryProvider)
          .loadContent(clipboardName);
      final ClipboardSyncPayload? remotePayload = _parseRemotePayload(
        remoteContent,
      );
      if (remotePayload == null) {
        state = state.copyWith(
          phase: ClipboardSyncPhase.failure,
          clipboardName: clipboardName,
          message: '强制拉取失败：远端没有可用数据。',
        );
        return;
      }

      await _applyRemoteSnapshot(userId: userId, remotePayload: remotePayload);
      state = state.copyWith(
        phase: ClipboardSyncPhase.success,
        clipboardName: clipboardName,
        lastSyncedAt: DateTime.now(),
        message: '已强制拉取远端数据',
      );
    } on Object catch (error) {
      state = state.copyWith(
        phase: ClipboardSyncPhase.failure,
        clipboardName: clipboardName,
        message: '强制拉取失败：$error',
      );
    }
  }

  Future<void> syncNow() async {
    _autoUploadTimer?.cancel();
    final String? clipboardName = _clipboardNameOrNull();
    final String? userId = _activeUserId ?? _userIdOrNull();
    if (clipboardName == null || userId == null) {
      state = const ClipboardSyncState(message: '登录后才能使用网络剪贴板同步。');
      return;
    }
    state = state.copyWith(
      phase: ClipboardSyncPhase.syncing,
      clipboardName: clipboardName,
      clearMessage: true,
    );

    try {
      final ClipboardSyncPayload localPayload = await _buildLocalPayloadForSync(
        userId,
      );
      final String? remoteContent = await ref
          .read(clipboardSyncRepositoryProvider)
          .loadContent(clipboardName);
      final ClipboardSyncPayload? remotePayload = _parseRemotePayload(
        remoteContent,
      );

      final DateTime now = DateTime.now();
      if (remotePayload == null) {
        final ClipboardSyncPayload uploadedPayload =
            await _saveLocalPayloadToRemote(
              userId: userId,
              clipboardName: clipboardName,
              localPayload: localPayload,
            );
        state = state.copyWith(
          phase: ClipboardSyncPhase.success,
          clipboardName: clipboardName,
          lastUploadedAt: now,
          lastSyncedAt: now,
          message: uploadedPayload.favoritesState.memberships.isEmpty
              ? '远端为空，已上传本地数据'
              : '远端为空，已上传本地快照',
        );
        return;
      }

      final int remoteUpdatedAt = remotePayload.updatedAtEpochMs;
      final int localUpdatedAt = localPayload.updatedAtEpochMs;
      if (remoteUpdatedAt <= 0 && localUpdatedAt <= 0) {
        await _applyRemoteSnapshot(
          userId: userId,
          remotePayload: remotePayload,
        );
        state = state.copyWith(
          phase: ClipboardSyncPhase.success,
          clipboardName: clipboardName,
          lastSyncedAt: now,
          message: '已拉取远端数据',
        );
        return;
      }

      if (remoteUpdatedAt > localUpdatedAt) {
        await _applyRemoteSnapshot(
          userId: userId,
          remotePayload: remotePayload,
        );
        state = state.copyWith(
          phase: ClipboardSyncPhase.success,
          clipboardName: clipboardName,
          lastSyncedAt: now,
          message: '远端数据较新，已拉取同步',
        );
        return;
      }

      if (localUpdatedAt > remoteUpdatedAt) {
        await _saveLocalPayloadToRemote(
          userId: userId,
          clipboardName: clipboardName,
          localPayload: localPayload,
        );
        state = state.copyWith(
          phase: ClipboardSyncPhase.success,
          clipboardName: clipboardName,
          lastUploadedAt: now,
          lastSyncedAt: now,
          message: '本地数据较新，已上传同步',
        );
        return;
      }

      if (_payloadFingerprint(localPayload) !=
          _payloadFingerprint(remotePayload)) {
        state = state.copyWith(
          phase: ClipboardSyncPhase.failure,
          clipboardName: clipboardName,
          message: '同步冲突：本地与远端时间一致但内容不同，请使用强制上传或强制拉取。',
        );
        return;
      }

      await _rememberRemoteUpdatedAt(userId, remoteUpdatedAt);
      _lastSnapshotFingerprint = _buildLocalFingerprint();
      state = state.copyWith(
        phase: ClipboardSyncPhase.success,
        clipboardName: clipboardName,
        lastSyncedAt: now,
        message: '本地与远端已一致',
      );
    } on Object catch (error) {
      state = state.copyWith(
        phase: ClipboardSyncPhase.failure,
        clipboardName: clipboardName,
        message: '同步失败：$error',
      );
    }
  }

  void _listenForLocalChanges() {
    ref.listen<BiliSession?>(
      biliSessionControllerProvider,
      (_, BiliSession? next) => _handleSessionChanged(next),
    );
    ref.listen<FavoritesState>(
      favoritesControllerProvider,
      (_, _) => _handleLocalChanged(),
    );
    ref.listen<Object?>(
      playerBlacklistControllerProvider,
      (_, _) => _handleLocalChanged(),
    );
    ref.listen<Object?>(themeLogicProvider, (_, _) => _handleLocalChanged());
    ref.listen<Object?>(
      appearanceSettingLogicProvider,
      (_, _) => _handleLocalChanged(),
    );
    ref.listen<Object?>(
      playerSettingsLogicProvider,
      (_, _) => _handleLocalChanged(),
    );
    ref.listen<Object?>(
      playerAudioQualityPreferenceLogicProvider,
      (_, _) => _handleLocalChanged(),
    );
    ref.listen<Object?>(
      playerMultiPartQueuePreferenceLogicProvider,
      (_, _) => _handleLocalChanged(),
    );
    ref.listen<Object?>(
      playerMultiPartTipShownLogicProvider,
      (_, _) => _handleLocalChanged(),
    );
    ref.listen<Object?>(
      playerLyricFontPreferenceLogicProvider,
      (_, _) => _handleLocalChanged(),
    );
    ref.listen<Object?>(
      playerLyricFontSizePreferenceLogicProvider,
      (_, _) => _handleLocalChanged(),
    );
    ref.listen<Object?>(
      desktopLyricsSettingsControllerProvider,
      (_, _) => _handleLocalChanged(),
    );
    ref.listen<Object?>(
      hotkeySettingsLogicProvider,
      (_, _) => _handleLocalChanged(),
    );
  }

  void _handleLocalChanged() {
    if (!_isInitialized || _isApplyingRemoteSnapshot) {
      return;
    }
    final String? clipboardName = _clipboardNameForUserId(_activeUserId);
    if (clipboardName == null) {
      _autoUploadTimer?.cancel();
      _lastSnapshotFingerprint = null;
      state = const ClipboardSyncState(
        phase: ClipboardSyncPhase.idle,
        message: '登录后可使用网络剪贴板同步',
      );
      return;
    }

    final String fingerprint = _buildLocalFingerprint();
    if (fingerprint == _lastSnapshotFingerprint) {
      return;
    }
    _lastSnapshotFingerprint = fingerprint;
    unawaited(_markLocalUpdated(_requireActiveUserId()));
    _autoUploadTimer?.cancel();
    _autoUploadTimer = Timer(clipboardSyncAutoUploadDelay, () {
      unawaited(_uploadCurrentSnapshot(isAutomatic: true, force: false));
    });
    state = state.copyWith(
      phase: ClipboardSyncPhase.scheduled,
      clipboardName: clipboardName,
      message: '检测到变更，10 秒后自动上传',
    );
  }

  Future<void> _uploadCurrentSnapshot({
    required bool isAutomatic,
    required bool force,
  }) async {
    final String? userId = _activeUserId ?? _userIdOrNull();
    final String? clipboardName = _clipboardNameForUserId(userId);
    if (clipboardName == null || userId == null) {
      state = const ClipboardSyncState(message: '登录后才能使用网络剪贴板同步。');
      return;
    }
    state = state.copyWith(
      phase: ClipboardSyncPhase.uploading,
      clipboardName: clipboardName,
      clearMessage: true,
    );

    try {
      final ClipboardSyncPayload localPayload =
          await _buildLocalPayloadForUpload(
            userId,
            forceRefreshTimestamp: force,
          );
      if (!force) {
        final String? remoteContent = await ref
            .read(clipboardSyncRepositoryProvider)
            .loadContent(clipboardName);
        final ClipboardSyncPayload? remotePayload = _parseRemotePayload(
          remoteContent,
        );
        final int remoteUpdatedAt = remotePayload?.updatedAtEpochMs ?? 0;
        if (remoteUpdatedAt > localPayload.updatedAtEpochMs) {
          state = state.copyWith(
            phase: ClipboardSyncPhase.failure,
            clipboardName: clipboardName,
            message: '上传已取消：远端数据更新，请先同步后再上传，或使用强制上传覆盖远端。',
          );
          return;
        }
      }
      await _saveLocalPayloadToRemote(
        userId: userId,
        clipboardName: clipboardName,
        localPayload: localPayload,
      );
      state = state.copyWith(
        phase: ClipboardSyncPhase.success,
        clipboardName: clipboardName,
        lastUploadedAt: DateTime.now(),
        message: isAutomatic
            ? '已自动上传'
            : force
            ? '已强制上传并覆盖远端'
            : '上传完成',
      );
    } on Object catch (error) {
      state = state.copyWith(
        phase: ClipboardSyncPhase.failure,
        clipboardName: clipboardName,
        message: '上传失败：$error',
      );
    }
  }

  Future<ClipboardSyncPayload> _saveLocalPayloadToRemote({
    required String userId,
    required String clipboardName,
    required ClipboardSyncPayload localPayload,
  }) async {
    ClipboardSyncPayload payload = localPayload;
    if (payload.updatedAtEpochMs <= 0) {
      final int updatedAt = DateTime.now().millisecondsSinceEpoch;
      await _writeLocalUpdatedAt(userId, updatedAt);
      payload = _buildLocalPayloadWithTimestamp(updatedAtEpochMs: updatedAt);
    }
    await ref
        .read(clipboardSyncRepositoryProvider)
        .saveContent(
          clipboardName: clipboardName,
          content: payload.toJsonString(),
        );
    await _rememberRemoteUpdatedAt(userId, payload.updatedAtEpochMs);
    _lastSnapshotFingerprint = _buildLocalFingerprint();
    return payload;
  }

  Future<void> _applyRemoteSnapshot({
    required String userId,
    required ClipboardSyncPayload remotePayload,
  }) async {
    _isApplyingRemoteSnapshot = true;
    try {
      await ref
          .read(favoritesLocalRepositoryProvider)
          .replaceAll(remotePayload.favoritesState);
      if (remotePayload.settings.isNotEmpty) {
        await ref
            .read(appTransferRepositoryProvider)
            .importSettingsSnapshot(remotePayload.settings);
      }
      await ref.read(favoritesControllerProvider.notifier).reload();
      _refreshImportedSettings();

      final int remoteUpdatedAt = remotePayload.updatedAtEpochMs > 0
          ? remotePayload.updatedAtEpochMs
          : DateTime.now().millisecondsSinceEpoch;
      await _writeLocalUpdatedAt(userId, remoteUpdatedAt);
      await _rememberRemoteUpdatedAt(userId, remoteUpdatedAt);
      _lastSnapshotFingerprint = _buildLocalFingerprint();
    } finally {
      _isApplyingRemoteSnapshot = false;
    }
  }

  ClipboardSyncPayload? _parseRemotePayload(String? content) {
    final String trimmed = content?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    return ClipboardSyncPayload.fromJsonString(trimmed);
  }

  String _buildLocalFingerprint() {
    return _buildLocalPayloadWithTimestamp(updatedAtEpochMs: 0).toJsonString();
  }

  String _payloadFingerprint(ClipboardSyncPayload payload) {
    return ClipboardSyncPayload(
      userId: payload.userId,
      updatedAtEpochMs: 0,
      favoritesState: payload.favoritesState,
      settings: payload.settings,
    ).toJsonString();
  }

  Future<ClipboardSyncPayload> _buildLocalPayloadForSync(String userId) async {
    final int updatedAt = await _localUpdatedAtForCurrentSnapshot(userId);
    return _buildLocalPayloadWithTimestamp(updatedAtEpochMs: updatedAt);
  }

  Future<ClipboardSyncPayload> _buildLocalPayloadForUpload(
    String userId, {
    required bool forceRefreshTimestamp,
  }) async {
    int updatedAt = await _localUpdatedAtForCurrentSnapshot(userId);
    if (forceRefreshTimestamp || updatedAt <= 0) {
      updatedAt = DateTime.now().millisecondsSinceEpoch;
      await _writeLocalUpdatedAt(userId, updatedAt);
    }
    return _buildLocalPayloadWithTimestamp(updatedAtEpochMs: updatedAt);
  }

  Future<int> _localUpdatedAtForCurrentSnapshot(String userId) async {
    final String fingerprint = _buildLocalFingerprint();
    if (_lastSnapshotFingerprint != null &&
        fingerprint != _lastSnapshotFingerprint) {
      final int updatedAt = DateTime.now().millisecondsSinceEpoch;
      await _writeLocalUpdatedAt(userId, updatedAt);
      _lastSnapshotFingerprint = fingerprint;
      return updatedAt;
    }

    final int stored = _readLocalUpdatedAt(userId);
    if (stored > 0) {
      return stored;
    }
    final int inferred = _inferFavoritesUpdatedAtEpochMs(
      ref.read(favoritesControllerProvider),
    );
    return inferred;
  }

  ClipboardSyncPayload _buildLocalPayloadWithTimestamp({
    required int updatedAtEpochMs,
  }) {
    final String userId = _requireActiveUserId();
    return ClipboardSyncPayload(
      userId: userId,
      updatedAtEpochMs: updatedAtEpochMs,
      favoritesState: ref.read(favoritesControllerProvider),
      settings: ref.read(appTransferRepositoryProvider).buildSettingsSnapshot(),
    );
  }

  int _inferFavoritesUpdatedAtEpochMs(FavoritesState favoritesState) {
    int updatedAt = 0;
    for (final FavoriteCollection collection in favoritesState.collections) {
      if (collection.isLikedCollection) {
        continue;
      }
      updatedAt = _maxEpochMs(updatedAt, collection.updatedAt);
    }
    for (final FavoriteEntry entry in favoritesState.entries) {
      updatedAt = _maxEpochMs(updatedAt, entry.updatedAt);
    }
    for (final FavoriteMembership membership in favoritesState.memberships) {
      updatedAt = _maxEpochMs(updatedAt, membership.addedAt);
    }
    return updatedAt;
  }

  int _maxEpochMs(int current, DateTime value) {
    final int epochMs = value.millisecondsSinceEpoch;
    return epochMs > current ? epochMs : current;
  }

  Future<void> _markLocalUpdated(String userId) {
    return _writeLocalUpdatedAt(userId, DateTime.now().millisecondsSinceEpoch);
  }

  int _readLocalUpdatedAt(String userId) {
    return int.tryParse(
          ref
              .read(appSettingsStoreProvider)
              .readString(_localUpdatedAtKey(userId), defaultValue: '0'),
        ) ??
        0;
  }

  Future<void> _writeLocalUpdatedAt(String userId, int updatedAtEpochMs) {
    return ref
        .read(appSettingsStoreProvider)
        .writeString(_localUpdatedAtKey(userId), updatedAtEpochMs.toString());
  }

  Future<void> _rememberRemoteUpdatedAt(String userId, int updatedAtEpochMs) {
    return ref
        .read(appSettingsStoreProvider)
        .writeString(_remoteUpdatedAtKey(userId), updatedAtEpochMs.toString());
  }

  String _localUpdatedAtKey(String userId) {
    return '$_clipboardSyncLocalUpdatedAtPrefix$userId';
  }

  String _remoteUpdatedAtKey(String userId) {
    return '$_clipboardSyncRemoteUpdatedAtPrefix$userId';
  }

  void _refreshImportedSettings() {
    ref.invalidate(playerBlacklistControllerProvider);
    ref.invalidate(themeLogicProvider);
    ref.invalidate(appearanceSettingLogicProvider);
    ref.invalidate(playerSettingsLogicProvider);
    ref.invalidate(playerAudioQualityPreferenceLogicProvider);
    ref.invalidate(playerMultiPartQueuePreferenceLogicProvider);
    ref.invalidate(playerMultiPartTipShownLogicProvider);
    ref.invalidate(playerLyricFontPreferenceLogicProvider);
    ref.invalidate(playerLyricFontSizePreferenceLogicProvider);
    ref.invalidate(desktopLyricsSettingsControllerProvider);
    ref.invalidate(hotkeySettingsLogicProvider);
  }

  void _handleSessionChanged(BiliSession? session) {
    if (!_isInitialized || _isApplyingRemoteSnapshot) {
      return;
    }

    final String? nextUserId = _userIdFromSession(session);
    if (nextUserId == null) {
      _activeUserId = null;
      _autoSyncedLoginUserId = null;
      _autoUploadTimer?.cancel();
      _lastSnapshotFingerprint = null;
      state = const ClipboardSyncState(
        phase: ClipboardSyncPhase.idle,
        message: '登录后可使用网络剪贴板同步',
      );
      return;
    }

    final bool isLoginTransition = _activeUserId == null;
    final bool isDifferentUser =
        _activeUserId != null && _activeUserId != nextUserId;
    _activeUserId = nextUserId;
    state = state.copyWith(clipboardName: _clipboardNameForUserId(nextUserId));

    if ((isLoginTransition || isDifferentUser) &&
        _autoSyncedLoginUserId != nextUserId) {
      _autoSyncedLoginUserId = nextUserId;
      _autoUploadTimer?.cancel();
      unawaited(syncNow());
      return;
    }

    _handleLocalChanged();
  }

  String _requireActiveUserId() {
    final String? userId = _activeUserId ?? _userIdOrNull();
    if (userId == null) {
      throw const ClipboardSyncException('缺少 B 站用户 ID。');
    }
    return userId;
  }

  String? _userIdOrNull() {
    return _userIdFromSession(ref.read(biliSessionControllerProvider));
  }

  String? _userIdFromSession(BiliSession? session) {
    final String? userId =
        session?.mid?.toString() ??
        (session?.dedeUserId.trim().isNotEmpty == true
            ? session!.dedeUserId.trim()
            : null);
    final String? trimmed = userId?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String? _clipboardNameOrNull() {
    return _clipboardNameForUserId(_activeUserId ?? _userIdOrNull());
  }

  String? _clipboardNameForUserId(String? userId) {
    return userId == null ? null : '${userId}bilimusic';
  }
}
