// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clipboard_sync_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ClipboardSyncController)
final clipboardSyncControllerProvider = ClipboardSyncControllerProvider._();

final class ClipboardSyncControllerProvider
    extends $NotifierProvider<ClipboardSyncController, ClipboardSyncState> {
  ClipboardSyncControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clipboardSyncControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clipboardSyncControllerHash();

  @$internal
  @override
  ClipboardSyncController create() => ClipboardSyncController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ClipboardSyncState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ClipboardSyncState>(value),
    );
  }
}

String _$clipboardSyncControllerHash() =>
    r'11e82c6c3835a67fded13384538ce9bc5a6cef09';

abstract class _$ClipboardSyncController extends $Notifier<ClipboardSyncState> {
  ClipboardSyncState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ClipboardSyncState, ClipboardSyncState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ClipboardSyncState, ClipboardSyncState>,
              ClipboardSyncState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
