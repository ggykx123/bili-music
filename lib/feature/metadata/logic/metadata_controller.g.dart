// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'metadata_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MetadataController)
final metadataControllerProvider = MetadataControllerProvider._();

final class MetadataControllerProvider
    extends $NotifierProvider<MetadataController, MetadataState> {
  MetadataControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'metadataControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$metadataControllerHash();

  @$internal
  @override
  MetadataController create() => MetadataController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MetadataState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MetadataState>(value),
    );
  }
}

String _$metadataControllerHash() =>
    r'47973a12441612ad9bdbdce6f7d2ef3bd8536b1c';

abstract class _$MetadataController extends $Notifier<MetadataState> {
  MetadataState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<MetadataState, MetadataState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MetadataState, MetadataState>,
              MetadataState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
