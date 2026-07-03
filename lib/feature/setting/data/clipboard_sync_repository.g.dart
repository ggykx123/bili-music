// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clipboard_sync_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(clipboardSyncRepository)
final clipboardSyncRepositoryProvider = ClipboardSyncRepositoryProvider._();

final class ClipboardSyncRepositoryProvider
    extends
        $FunctionalProvider<
          ClipboardSyncRepository,
          ClipboardSyncRepository,
          ClipboardSyncRepository
        >
    with $Provider<ClipboardSyncRepository> {
  ClipboardSyncRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clipboardSyncRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clipboardSyncRepositoryHash();

  @$internal
  @override
  $ProviderElement<ClipboardSyncRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ClipboardSyncRepository create(Ref ref) {
    return clipboardSyncRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ClipboardSyncRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ClipboardSyncRepository>(value),
    );
  }
}

String _$clipboardSyncRepositoryHash() =>
    r'585029885f142008c7ed0c851c8ba6f24ea99396';
