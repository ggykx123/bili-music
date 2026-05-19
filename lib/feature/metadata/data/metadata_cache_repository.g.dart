// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'metadata_cache_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(metadataCacheRepository)
final metadataCacheRepositoryProvider = MetadataCacheRepositoryProvider._();

final class MetadataCacheRepositoryProvider
    extends
        $FunctionalProvider<
          MetadataCacheRepository,
          MetadataCacheRepository,
          MetadataCacheRepository
        >
    with $Provider<MetadataCacheRepository> {
  MetadataCacheRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'metadataCacheRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$metadataCacheRepositoryHash();

  @$internal
  @override
  $ProviderElement<MetadataCacheRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MetadataCacheRepository create(Ref ref) {
    return metadataCacheRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MetadataCacheRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MetadataCacheRepository>(value),
    );
  }
}

String _$metadataCacheRepositoryHash() =>
    r'0d21a0b3a6417bb62561dfc2f5ae5cb26ea0d044';
