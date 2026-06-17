import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as audio;

class PlayerAudioEngine {
  PlayerAudioEngine()
    : _audioPlayer = audio.AudioPlayer(
        androidApplyAudioAttributes: false,
        handleInterruptions: false,
        useProxyForRequestHeaders: !_shouldDisableRequestHeadersProxy,
      );

  final audio.AudioPlayer _audioPlayer;

  static bool get _shouldDisableRequestHeadersProxy {
    if (kIsWeb) {
      return true;
    }
    // return switch (defaultTargetPlatform) {
    //   TargetPlatform.windows => true,
    //   TargetPlatform.linux => true,
    //   _ => false,
    // };
    return false;
  }

  bool get playing => _audioPlayer.playing;
  double get volume => _audioPlayer.volume;
  Duration get position => _audioPlayer.position;
  PlayerEngineProcessingState get processingState =>
      _audioPlayer.processingState.toPlayerEngineProcessingState();

  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  Stream<Duration> get bufferedPositionStream =>
      _audioPlayer.bufferedPositionStream;
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;
  Stream<PlayerEngineException> get errorStream =>
      _audioPlayer.errorStream.map(PlayerEngineException.fromJustAudio);
  Stream<double> get volumeStream => _audioPlayer.volumeStream;
  Stream<PlayerEngineState> get playerStateStream =>
      _audioPlayer.playerStateStream.map(PlayerEngineState.fromJustAudio);

  Future<Duration?> setRemoteSource({
    required Uri uri,
    Map<String, String>? headers,
    dynamic tag,
    Duration? initialPosition,
  }) {
    return _audioPlayer.setAudioSource(
      audio.AudioSource.uri(uri, headers: headers, tag: tag),
      initialPosition: initialPosition,
    );
  }

  Future<Duration?> setFileSource({
    required String filePath,
    dynamic tag,
    Duration? initialPosition,
  }) {
    return _audioPlayer.setAudioSource(
      audio.AudioSource.file(filePath, tag: tag),
      initialPosition: initialPosition,
    );
  }

  Future<void> play() {
    return _audioPlayer.play();
  }

  Future<void> pause() {
    return _audioPlayer.pause();
  }

  Future<void> stop() {
    return _audioPlayer.stop();
  }

  Future<void> seek(Duration position) {
    return _audioPlayer.seek(position);
  }

  Future<void> setVolume(double volume) {
    return _audioPlayer.setVolume(volume);
  }

  Future<void> dispose() {
    return _audioPlayer.dispose();
  }
}

class PlayerEngineState {
  const PlayerEngineState({
    required this.playing,
    required this.processingState,
  });

  factory PlayerEngineState.fromJustAudio(audio.PlayerState state) {
    return PlayerEngineState(
      playing: state.playing,
      processingState: state.processingState.toPlayerEngineProcessingState(),
    );
  }

  final bool playing;
  final PlayerEngineProcessingState processingState;
}

class PlayerEngineException implements Exception {
  const PlayerEngineException(this.message, {this.code});

  factory PlayerEngineException.fromJustAudio(audio.PlayerException error) {
    return PlayerEngineException(
      error.message ?? error.toString(),
      code: error.code,
    );
  }

  final String message;
  final Object? code;

  @override
  String toString() {
    if (code == null) {
      return message;
    }
    return '$message (code: $code)';
  }
}

enum PlayerEngineProcessingState { idle, loading, buffering, ready, completed }

extension PlayerEngineProcessingStateX on PlayerEngineProcessingState {
  bool get isBuffering {
    return this == PlayerEngineProcessingState.loading ||
        this == PlayerEngineProcessingState.buffering;
  }

  bool get isReady {
    return this != PlayerEngineProcessingState.idle &&
        this != PlayerEngineProcessingState.loading;
  }
}

extension on audio.ProcessingState {
  PlayerEngineProcessingState toPlayerEngineProcessingState() {
    return switch (this) {
      audio.ProcessingState.idle => PlayerEngineProcessingState.idle,
      audio.ProcessingState.loading => PlayerEngineProcessingState.loading,
      audio.ProcessingState.buffering => PlayerEngineProcessingState.buffering,
      audio.ProcessingState.ready => PlayerEngineProcessingState.ready,
      audio.ProcessingState.completed => PlayerEngineProcessingState.completed,
    };
  }
}
