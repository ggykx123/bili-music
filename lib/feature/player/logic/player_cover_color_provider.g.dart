// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_cover_color_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(playerCoverColor)
final playerCoverColorProvider = PlayerCoverColorFamily._();

final class PlayerCoverColorProvider
    extends $FunctionalProvider<AsyncValue<Color?>, Color?, FutureOr<Color?>>
    with $FutureModifier<Color?>, $FutureProvider<Color?> {
  PlayerCoverColorProvider._({
    required PlayerCoverColorFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'playerCoverColorProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$playerCoverColorHash();

  @override
  String toString() {
    return r'playerCoverColorProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Color?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Color?> create(Ref ref) {
    final argument = this.argument as String?;
    return playerCoverColor(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PlayerCoverColorProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$playerCoverColorHash() => r'603725bf2e39ccb38772da41cac378c287c1dde8';

final class PlayerCoverColorFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Color?>, String?> {
  PlayerCoverColorFamily._()
    : super(
        retry: null,
        name: r'playerCoverColorProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  PlayerCoverColorProvider call(String? coverUrl) =>
      PlayerCoverColorProvider._(argument: coverUrl, from: this);

  @override
  String toString() => r'playerCoverColorProvider';
}
