import 'dart:async';

import 'package:bilimusic/core/bili/session/bili_session.dart';
import 'package:bilimusic/core/bili/session/bili_session_controller.dart';
import 'package:bilimusic/core/theme/theme_logic.dart';
import 'package:bilimusic/feature/favorites/data/favorites_local_repository.dart';
import 'package:bilimusic/feature/favorites/domain/favorites_state.dart';
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
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'clipboard_sync_controller.g.dart';

const Duration clipboardSyncAutoUploadDelay = Duration(seconds: 10);

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
  int? _lastKnownRemoteUpdatedAtEpochMs;

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
    await _uploadCurrentSnapshot(isAutomatic: false);
  }

  Future<void> syncNow() async {
    _autoUploadTimer?.cancel();
    final String? clipboardName = _clipboardNameOrNull();
    if (clipboardName == null) {
      state = const ClipboardSyncState(message: '登录后才能使用网络剪贴板同步。');
      return;
    }
    state = state.copyWith(
      phase: ClipboardSyncPhase.syncing,
      clipboardName: clipboardName,
      clearMessage: true,
    );

    try {
      final ClipboardSyncPayload localPayload = _buildLocalPayload();
      final String? remoteContent = await ref
          .read(clipboardSyncRepositoryProvider)
          .loadContent(clipboardName);
      final ClipboardSyncPayload? remotePayload = _parseRemotePayload(
        remoteContent,
      );

      final FavoritesState mergedFavorites = remotePayload == null
          ? localPayload.favoritesState
          : mergeClipboardFavorites(
              localState: localPayload.favoritesState,
              remoteState: remotePayload.favoritesState,
            );
      final Map<String, String> mergedSettings = <String, String>{
        ...localPayload.settings,
        if (remotePayload != null) ...remotePayload.settings,
      };

      _isApplyingRemoteSnapshot = true;
      await ref
          .read(favoritesLocalRepositoryProvider)
          .replaceAll(mergedFavorites);
      await ref
          .read(appTransferRepositoryProvider)
          .importSettingsSnapshot(mergedSettings);
      await ref.read(favoritesControllerProvider.notifier).reload();
      _refreshImportedSettings();

      final ClipboardSyncPayload mergedPayload = _buildLocalPayload();
      final String content = mergedPayload.toJsonString();
      await ref
          .read(clipboardSyncRepositoryProvider)
          .saveContent(clipboardName: clipboardName, content: content);

      final DateTime now = DateTime.now();
      _autoUploadTimer?.cancel();
      _lastKnownRemoteUpdatedAtEpochMs = mergedPayload.updatedAtEpochMs;
      _lastSnapshotFingerprint = _buildLocalFingerprint();
      state = state.copyWith(
        phase: ClipboardSyncPhase.success,
        clipboardName: clipboardName,
        lastUploadedAt: now,
        lastSyncedAt: now,
        message: '同步完成',
      );
    } on Object catch (error) {
      state = state.copyWith(
        phase: ClipboardSyncPhase.failure,
        clipboardName: clipboardName,
        message: '同步失败：$error',
      );
    } finally {
      _isApplyingRemoteSnapshot = false;
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
    _autoUploadTimer?.cancel();
    _autoUploadTimer = Timer(clipboardSyncAutoUploadDelay, () {
      unawaited(_uploadCurrentSnapshot(isAutomatic: true));
    });
    state = state.copyWith(
      phase: ClipboardSyncPhase.scheduled,
      clipboardName: clipboardName,
      message: '检测到变更，10 秒后自动上传',
    );
  }

  Future<void> _uploadCurrentSnapshot({required bool isAutomatic}) async {
    final String? clipboardName = _clipboardNameForUserId(_activeUserId);
    if (clipboardName == null) {
      state = const ClipboardSyncState(message: '登录后才能使用网络剪贴板同步。');
      return;
    }
    state = state.copyWith(
      phase: ClipboardSyncPhase.uploading,
      clipboardName: clipboardName,
      clearMessage: true,
    );

    try {
      final ClipboardSyncPayload localPayload = _buildLocalPayload();
      final String? remoteContent = await ref
          .read(clipboardSyncRepositoryProvider)
          .loadContent(clipboardName);
      final ClipboardSyncPayload? remotePayload = _parseRemotePayload(
        remoteContent,
      );
      if (_isRemoteNewerThanLastKnown(remotePayload)) {
        state = state.copyWith(
          phase: ClipboardSyncPhase.failure,
          clipboardName: clipboardName,
          message: '上传已取消：远端数据更新，请先同步后再上传。',
        );
        return;
      }
      final String content = localPayload.toJsonString();
      await ref
          .read(clipboardSyncRepositoryProvider)
          .saveContent(clipboardName: clipboardName, content: content);
      _lastKnownRemoteUpdatedAtEpochMs = localPayload.updatedAtEpochMs;
      _lastSnapshotFingerprint = _buildLocalFingerprint();
      state = state.copyWith(
        phase: ClipboardSyncPhase.success,
        clipboardName: clipboardName,
        lastUploadedAt: DateTime.now(),
        message: isAutomatic ? '已自动上传' : '上传完成',
      );
    } on Object catch (error) {
      state = state.copyWith(
        phase: ClipboardSyncPhase.failure,
        clipboardName: clipboardName,
        message: '上传失败：$error',
      );
    }
  }

  ClipboardSyncPayload? _parseRemotePayload(String? content) {
    final String trimmed = content?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    return ClipboardSyncPayload.fromJsonString(trimmed);
  }

  bool _isRemoteNewerThanLastKnown(ClipboardSyncPayload? remotePayload) {
    final int remoteUpdatedAt = remotePayload?.updatedAtEpochMs ?? 0;
    if (remoteUpdatedAt <= 0) {
      return false;
    }
    final int lastKnown = _lastKnownRemoteUpdatedAtEpochMs ?? 0;
    return remoteUpdatedAt > lastKnown;
  }

  String _buildLocalFingerprint() {
    return _buildLocalPayloadWithTimestamp(updatedAtEpochMs: 0).toJsonString();
  }

  ClipboardSyncPayload _buildLocalPayload() {
    return _buildLocalPayloadWithTimestamp(
      updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );
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
  }

  void _handleSessionChanged(BiliSession? session) {
    if (!_isInitialized || _isApplyingRemoteSnapshot) {
      return;
    }

    final String? nextUserId = _userIdFromSession(session);
    if (nextUserId == null) {
      _activeUserId = null;
      _autoSyncedLoginUserId = null;
      _lastKnownRemoteUpdatedAtEpochMs = null;
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
    if (isLoginTransition || isDifferentUser) {
      _lastKnownRemoteUpdatedAtEpochMs = null;
    }
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
