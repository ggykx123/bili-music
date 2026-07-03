import 'dart:typed_data';

import 'package:bilimusic/common/util/format_util.dart';
import 'package:bilimusic/common/util/toast_util.dart';
import 'package:bilimusic/common/components/url_text_input.dart';
import 'package:bilimusic/core/theme/theme_logic.dart';
import 'package:bilimusic/feature/favorites/logic/favorites_controller.dart';
import 'package:bilimusic/feature/player/logic/player_audio_quality_preference_logic.dart';
import 'package:bilimusic/feature/player/logic/player_settings_logic.dart';
import 'package:bilimusic/feature/setting/data/webdav_repository.dart';
import 'package:bilimusic/feature/setting/domain/app_import_preview.dart';
import 'package:bilimusic/feature/setting/domain/webdav_config.dart';
import 'package:bilimusic/feature/setting/logic/appearance_setting_logic.dart';
import 'package:bilimusic/feature/setting/logic/app_transfer_controller.dart';
import 'package:bilimusic/feature/setting/logic/clipboard_sync_controller.dart';
import 'package:bilimusic/feature/setting/logic/webdav_logic.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppTransferPage extends ConsumerStatefulWidget {
  const AppTransferPage({super.key});

  @override
  ConsumerState<AppTransferPage> createState() => _AppTransferPageState();
}

class _AppTransferPageState extends ConsumerState<AppTransferPage> {
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isTestingWebDav = false;
  bool _isSavingWebDav = false;
  bool _isUploadingWebDav = false;
  bool _isImportingWebDav = false;
  String _webDavBaseUrlValue = '';
  final TextEditingController _webDavUsernameController =
      TextEditingController();
  final TextEditingController _webDavPasswordController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWebDavConfig();
  }

  @override
  void dispose() {
    _webDavUsernameController.dispose();
    _webDavPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ClipboardSyncState clipboardSyncState = ref.watch(
      clipboardSyncControllerProvider,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('数据导入导出')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          ExpansionTile(
            initiallyExpanded: true,
            title: const Text('网络剪贴板同步'),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '通过 jq.torgw.com 同步我喜欢、自建歌单、黑名单和设置项。',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    _InfoLine(
                      label: '剪贴板名称',
                      value: clipboardSyncState.clipboardName ?? '登录后生成',
                    ),
                    _InfoLine(
                      label: '状态',
                      value: _clipboardSyncStatusText(clipboardSyncState),
                    ),
                    _InfoLine(
                      label: '最近上传',
                      value: _formatNullableDateTime(
                        clipboardSyncState.lastUploadedAt,
                      ),
                    ),
                    _InfoLine(
                      label: '最近同步',
                      value: _formatNullableDateTime(
                        clipboardSyncState.lastSyncedAt,
                      ),
                    ),
                    if (clipboardSyncState.message?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(
                        clipboardSyncState.message!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              clipboardSyncState.phase ==
                                  ClipboardSyncPhase.failure
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FilledButton.icon(
                            onPressed:
                                clipboardSyncState.clipboardName == null ||
                                    clipboardSyncState.isBusy
                                ? null
                                : _handleClipboardUploadPressed,
                            icon:
                                clipboardSyncState.phase ==
                                    ClipboardSyncPhase.uploading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.cloud_upload_rounded),
                            label: const Text('立即上传'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                clipboardSyncState.clipboardName == null ||
                                    clipboardSyncState.isBusy
                                ? null
                                : _handleClipboardSyncPressed,
                            icon:
                                clipboardSyncState.phase ==
                                    ClipboardSyncPhase.syncing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.sync_rounded),
                            label: const Text('手动同步'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: const Text('WebDAV 配置'),
            children: [
              Container(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '用于收藏的远程导入导出，云端内容与当前登录账号无关。',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      UrlTextInput(
                        labelText: '服务器地址',
                        hintText: 'dav.example.com/dav',
                        value: _webDavBaseUrlValue,
                        enabled:
                            !_isSavingWebDav &&
                            !_isTestingWebDav &&
                            !_isUploadingWebDav &&
                            !_isImportingWebDav,
                        onChanged: (String value) {
                          _webDavBaseUrlValue = value;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _webDavUsernameController,
                        decoration: const InputDecoration(labelText: '用户名'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _webDavPasswordController,
                        decoration: const InputDecoration(labelText: '密码'),
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: <Widget>[
                          FilledButton.icon(
                            onPressed: _isSavingWebDav
                                ? null
                                : _handleSaveWebDav,
                            icon: _isSavingWebDav
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_rounded),
                            label: Text(_isSavingWebDav ? '保存中...' : '保存配置'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _isTestingWebDav
                                ? null
                                : _handleTestWebDav,
                            icon: _isTestingWebDav
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.wifi_tethering_rounded),
                            label: Text(_isTestingWebDav ? '测试中...' : '测试连接'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('导出数据', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    '导出范围包括收藏、主题、播放器与歌词服务设置，可导出为本地 JSON 或上传到 WebDAV。',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: _isExporting ? null : _handleExportPressed,
                        icon: _isExporting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.download_rounded),
                        label: Text(_isExporting ? '导出中...' : '导出为 JSON'),
                      ),
                      FilledButton.icon(
                        onPressed: _isUploadingWebDav
                            ? null
                            : _handleUploadToWebDav,
                        icon: _isUploadingWebDav
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.cloud_upload_rounded),
                        label: Text(_isUploadingWebDav ? '导出中...' : '远程导出'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('导入数据', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    '支持按歌单导入收藏。新备份可选择是否同时导入应用设置。',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: _isImporting ? null : _handleImportPressed,
                        icon: _isImporting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.upload_file_rounded),
                        label: Text(_isImporting ? '处理中...' : '选择文件导入'),
                      ),
                      FilledButton.icon(
                        onPressed: _isImportingWebDav
                            ? null
                            : _handleRemoteImportPressed,
                        icon: _isImportingWebDav
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.cloud_download_rounded),
                        label: Text(_isImportingWebDav ? '处理中...' : '远程导入'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _loadWebDavConfig() {
    final WebDavConfig config = ref.read(webDavLogicProvider).loadConfig();
    _webDavBaseUrlValue = config.baseUrl;
    _webDavUsernameController.text = config.username;
    _webDavPasswordController.text = config.password;
  }

  Future<void> _handleExportPressed() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final String? directoryPath = await FilePicker.getDirectoryPath(
        dialogTitle: '选择导出目录',
      );
      if (directoryPath == null) {
        return;
      }

      final AppTransferController controller = ref.read(
        appTransferControllerProvider,
      );
      final String json = await controller.buildExportJson();
      final String fileName = _buildExportFileName();
      final String exportPath = '$directoryPath/$fileName';
      await controller.saveExportToPath(json: json, path: exportPath);

      if (!mounted) {
        return;
      }
      ToastUtil.show('已导出到 $exportPath');
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ToastUtil.show('导出失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _handleImportPressed() async {
    setState(() {
      _isImporting = true;
    });

    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['json'],
      );
      if (result == null || result.files.isEmpty) {
        return;
      }

      final PlatformFile file = result.files.first;
      final Uint8List bytes = await file.readAsBytes();

      final AppTransferController controller = ref.read(
        appTransferControllerProvider,
      );
      final AppImportPreview preview = await controller.previewImport(bytes);
      if (!mounted) {
        return;
      }

      final _ImportDecision? decision = await showDialog<_ImportDecision>(
        context: context,
        builder: (BuildContext context) {
          return _ImportConfigDialog(preview: preview);
        },
      );
      if (decision == null) {
        return;
      }

      await controller.importBytes(
        bytes: bytes,
        importLikedCollection: decision.importLikedCollection,
        selectedCollectionIds: decision.selectedCollectionIds,
        importSettings: decision.importSettings,
      );

      await ref.read(favoritesControllerProvider.notifier).reload();
      _refreshImportedSettings(decision);

      if (!mounted) {
        return;
      }
      ToastUtil.show('数据导入完成');
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ToastUtil.show('导入失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<void> _handleClipboardUploadPressed() async {
    await ref.read(clipboardSyncControllerProvider.notifier).uploadNow();
    if (!mounted) {
      return;
    }
    final ClipboardSyncState state = ref.read(clipboardSyncControllerProvider);
    ToastUtil.show(state.message ?? '上传完成');
  }

  Future<void> _handleClipboardSyncPressed() async {
    await ref.read(clipboardSyncControllerProvider.notifier).syncNow();
    if (!mounted) {
      return;
    }
    final ClipboardSyncState state = ref.read(clipboardSyncControllerProvider);
    ToastUtil.show(state.message ?? '同步完成');
  }

  Future<void> _handleSaveWebDav() async {
    final WebDavConfig config = _buildWebDavConfig();
    if (config.baseUrl.isNotEmpty && !isValidHttpUrl(config.baseUrl)) {
      ToastUtil.show('请输入有效的 http 或 https WebDAV 地址');
      return;
    }

    setState(() {
      _isSavingWebDav = true;
    });

    try {
      await ref.read(webDavLogicProvider).saveConfig(config);
      if (!mounted) {
        return;
      }
      setState(() {
        _webDavBaseUrlValue = normalizeHttpUrl(config.baseUrl);
      });
      ToastUtil.show('WebDAV 配置已保存');
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ToastUtil.show('保存 WebDAV 配置失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingWebDav = false;
        });
      }
    }
  }

  Future<void> _handleTestWebDav() async {
    final WebDavConfig config = _buildWebDavConfig();
    if (config.baseUrl.isNotEmpty && !isValidHttpUrl(config.baseUrl)) {
      ToastUtil.show('请输入有效的 http 或 https WebDAV 地址');
      return;
    }

    setState(() {
      _isTestingWebDav = true;
    });

    try {
      await ref.read(webDavLogicProvider).saveConfig(config);
      await ref.read(webDavLogicProvider).testConnection();
      if (!mounted) {
        return;
      }
      setState(() {
        _webDavBaseUrlValue = normalizeHttpUrl(config.baseUrl);
      });
      ToastUtil.show('WebDAV 连接成功');
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ToastUtil.show('WebDAV 连接失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isTestingWebDav = false;
        });
      }
    }
  }

  Future<void> _handleUploadToWebDav() async {
    final WebDavConfig config = _buildWebDavConfig();
    if (config.baseUrl.isNotEmpty && !isValidHttpUrl(config.baseUrl)) {
      ToastUtil.show('请输入有效的 http 或 https WebDAV 地址');
      return;
    }

    setState(() {
      _isUploadingWebDav = true;
    });

    try {
      await ref.read(webDavLogicProvider).saveConfig(config);
      await ref.read(webDavLogicProvider).uploadCurrentFavoritesBackup();
      if (!mounted) {
        return;
      }
      setState(() {
        _webDavBaseUrlValue = normalizeHttpUrl(config.baseUrl);
      });
      ToastUtil.show('已上传当前收藏到 WebDAV');
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ToastUtil.show('上传 WebDAV 备份失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingWebDav = false;
        });
      }
    }
  }

  Future<void> _handleRemoteImportPressed() async {
    try {
      final WebDavConfig config = _buildWebDavConfig();
      if (config.baseUrl.isNotEmpty && !isValidHttpUrl(config.baseUrl)) {
        ToastUtil.show('请输入有效的 http 或 https WebDAV 地址');
        return;
      }

      await ref.read(webDavLogicProvider).saveConfig(config);
      if (!mounted) {
        return;
      }

      setState(() {
        _webDavBaseUrlValue = normalizeHttpUrl(config.baseUrl);
      });

      final WebDavBackupItem? selected = await showDialog<WebDavBackupItem>(
        context: context,
        builder: (BuildContext context) {
          return const _RemoteImportDialog();
        },
      );
      if (selected == null) {
        return;
      }

      await _handleImportFromWebDav(selected);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ToastUtil.show('读取远程备份失败：$error');
    }
  }

  Future<void> _handleImportFromWebDav(WebDavBackupItem item) async {
    setState(() {
      _isImportingWebDav = true;
    });

    try {
      final AppImportPreview preview = await ref
          .read(webDavLogicProvider)
          .downloadBackupPreview(item.remotePath);
      if (!mounted) {
        return;
      }

      final _ImportDecision? decision = await showDialog<_ImportDecision>(
        context: context,
        builder: (BuildContext context) {
          return _ImportConfigDialog(preview: preview);
        },
      );
      if (decision == null) {
        return;
      }

      await ref
          .read(webDavLogicProvider)
          .importBackup(
            remotePath: item.remotePath,
            importLikedCollection: decision.importLikedCollection,
            selectedCollectionIds: decision.selectedCollectionIds,
            importSettings: decision.importSettings,
          );

      if (!mounted) {
        return;
      }
      _refreshImportedSettings(decision);
      ToastUtil.show('WebDAV 数据导入完成');
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ToastUtil.show('WebDAV 导入失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isImportingWebDav = false;
        });
      }
    }
  }

  WebDavConfig _buildWebDavConfig() {
    return WebDavConfig(
      baseUrl: normalizeHttpUrl(_webDavBaseUrlValue),
      username: _webDavUsernameController.text,
      password: _webDavPasswordController.text,
    );
  }

  String _buildExportFileName() {
    final DateTime now = DateTime.now();
    final String yyyy = now.year.toString().padLeft(4, '0');
    final String mm = now.month.toString().padLeft(2, '0');
    final String dd = now.day.toString().padLeft(2, '0');
    final String hh = now.hour.toString().padLeft(2, '0');
    final String min = now.minute.toString().padLeft(2, '0');
    final String ss = now.second.toString().padLeft(2, '0');
    return 'bilimusic-backup-$yyyy$mm$dd-$hh$min$ss.json';
  }

  void _refreshImportedSettings(_ImportDecision decision) {
    if (!decision.importSettings) {
      return;
    }
    ref.invalidate(themeLogicProvider);
    ref.invalidate(appearanceSettingLogicProvider);
    ref.invalidate(playerSettingsLogicProvider);
    ref.invalidate(playerAudioQualityPreferenceLogicProvider);
  }

  String _clipboardSyncStatusText(ClipboardSyncState state) {
    return switch (state.phase) {
      ClipboardSyncPhase.idle => '待同步',
      ClipboardSyncPhase.scheduled => '等待自动上传',
      ClipboardSyncPhase.uploading => '正在上传',
      ClipboardSyncPhase.syncing => '正在同步',
      ClipboardSyncPhase.success => '已完成',
      ClipboardSyncPhase.failure => '失败',
    };
  }

  String _formatNullableDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final String yyyy = value.year.toString().padLeft(4, '0');
    final String mm = value.month.toString().padLeft(2, '0');
    final String dd = value.day.toString().padLeft(2, '0');
    final String hh = value.hour.toString().padLeft(2, '0');
    final String min = value.minute.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd $hh:$min';
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _RemoteImportDialog extends ConsumerStatefulWidget {
  const _RemoteImportDialog();

  @override
  ConsumerState<_RemoteImportDialog> createState() =>
      _RemoteImportDialogState();
}

class _RemoteImportDialogState extends ConsumerState<_RemoteImportDialog> {
  bool _isLoading = true;
  String? _deletingRemotePath;
  List<WebDavBackupItem> _items = const <WebDavBackupItem>[];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AlertDialog(
      title: const Text('远程导入'),
      content: SizedBox(width: 480, child: _buildContent(theme)),
      actions: <Widget>[
        TextButton(
          onPressed: _isLoading ? null : _loadItems,
          child: const Text('刷新'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_isLoading) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text(_errorMessage!, style: theme.textTheme.bodyMedium),
        ),
      );
    }

    if (_items.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(child: Text('暂无远程备份', style: theme.textTheme.bodyMedium)),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 360),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _items.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (BuildContext context, int index) {
          final WebDavBackupItem item = _items[index];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cloud_done_rounded),
            title: Text(item.name),
            subtitle: Text(
              '${_formatRemoteTime(item.modifiedAt)} · ${formatBytes(item.size)}',
              style: theme.textTheme.bodySmall,
            ),
            trailing: IconButton(
              tooltip: '删除',
              onPressed: _deletingRemotePath == item.remotePath
                  ? null
                  : () => _handleDelete(item),
              icon: _deletingRemotePath == item.remotePath
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline_rounded),
            ),
            onTap: () => Navigator.of(context).pop(item),
          );
        },
      ),
    );
  }

  String _formatRemoteTime(DateTime? value) {
    if (value == null) {
      return '未知时间';
    }

    final DateTime local = value.toLocal();
    final String yyyy = local.year.toString().padLeft(4, '0');
    final String mm = local.month.toString().padLeft(2, '0');
    final String dd = local.day.toString().padLeft(2, '0');
    final String hh = local.hour.toString().padLeft(2, '0');
    final String min = local.minute.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd $hh:$min';
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<WebDavBackupItem> items = await ref
          .read(webDavLogicProvider)
          .listBackups();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleDelete(WebDavBackupItem item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('删除远程备份'),
          content: Text('确认删除 ${item.name} 吗？'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    setState(() {
      _deletingRemotePath = item.remotePath;
    });

    try {
      await ref.read(webDavLogicProvider).deleteBackup(item.remotePath);
      if (!mounted) {
        return;
      }
      setState(() {
        _items = _items
            .where(
              (WebDavBackupItem current) =>
                  current.remotePath != item.remotePath,
            )
            .toList(growable: false);
      });
      ToastUtil.show('已删除远程备份');
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ToastUtil.show('删除远程备份失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _deletingRemotePath = null;
        });
      }
    }
  }
}

class _ImportConfigDialog extends StatefulWidget {
  const _ImportConfigDialog({required this.preview});

  final AppImportPreview preview;

  @override
  State<_ImportConfigDialog> createState() => _ImportConfigDialogState();
}

class _ImportConfigDialogState extends State<_ImportConfigDialog> {
  late bool _importLikedCollection;
  late bool _importSettings;
  late Set<String> _selectedCollectionIds;

  @override
  void initState() {
    super.initState();
    _importLikedCollection = widget.preview.likedItemCount > 0;
    _importSettings = widget.preview.hasSettings;
    _selectedCollectionIds = widget.preview.collections
        .where(
          (AppImportCollectionPreview collection) =>
              !collection.isLikedCollection,
        )
        .map(
          (AppImportCollectionPreview collection) =>
              collection.sourceCollectionId,
        )
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AlertDialog(
      title: const Text('导入数据'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '我喜欢 ${widget.preview.likedItemCount} 首，自建歌单 ${widget.preview.customCollectionCount} 个，歌曲 ${widget.preview.totalEntryCount} 首。',
                style: theme.textTheme.bodyMedium,
              ),
              if (widget
                  .preview
                  .conflictingCollectionNames
                  .isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  '检测到同名歌单：${widget.preview.conflictingCollectionNames.join('、')}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (widget.preview.hasSettings) ...<Widget>[
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _importSettings,
                  title: const Text('导入应用设置'),
                  subtitle: const Text('主题、外观、播放器与歌词服务设置'),
                  onChanged: (bool? value) {
                    setState(() {
                      _importSettings = value ?? false;
                    });
                  },
                ),
                const SizedBox(height: 12),
              ],
              if (widget.preview.likedItemCount > 0) ...<Widget>[
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _importLikedCollection,
                  title: const Text('导入“我喜欢”'),
                  subtitle: Text(
                    '会合并 ${widget.preview.likedItemCount} 首歌曲到当前我喜欢',
                  ),
                  onChanged: (bool? value) {
                    setState(() {
                      _importLikedCollection = value ?? false;
                    });
                  },
                ),
              ],
              const SizedBox(height: 12),
              Text('选择歌单', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              ...widget.preview.collections
                  .where(
                    (AppImportCollectionPreview collection) =>
                        !collection.isLikedCollection,
                  )
                  .map((AppImportCollectionPreview collection) {
                    final bool selected = _selectedCollectionIds.contains(
                      collection.sourceCollectionId,
                    );
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: selected,
                      title: Text(collection.name),
                      subtitle: Text(
                        '${collection.itemCount} 首${collection.hasNameConflict ? ' · 导入时会自动创建副本' : ''}',
                      ),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedCollectionIds.add(
                              collection.sourceCollectionId,
                            );
                          } else {
                            _selectedCollectionIds.remove(
                              collection.sourceCollectionId,
                            );
                          }
                        });
                      },
                    );
                  }),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _canSubmit
              ? () {
                  Navigator.of(context).pop(
                    _ImportDecision(
                      importLikedCollection: _importLikedCollection,
                      selectedCollectionIds: _selectedCollectionIds,
                      importSettings: _importSettings,
                    ),
                  );
                }
              : null,
          child: const Text('开始导入'),
        ),
      ],
    );
  }

  bool get _canSubmit {
    if (_importLikedCollection) {
      return true;
    }
    return _selectedCollectionIds.isNotEmpty || _importSettings;
  }
}

class _ImportDecision {
  const _ImportDecision({
    required this.importLikedCollection,
    required this.selectedCollectionIds,
    required this.importSettings,
  });

  final bool importLikedCollection;
  final Set<String> selectedCollectionIds;
  final bool importSettings;
}
