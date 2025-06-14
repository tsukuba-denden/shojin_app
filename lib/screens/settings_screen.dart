import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; // For haptic feedback
import 'package:google_fonts/google_fonts.dart'; // Add Google Fonts
import 'package:shared_preferences/shared_preferences.dart'; // For settings persistence
import 'package:url_launcher/url_launcher.dart'; // For launching URLs
import '../providers/theme_provider.dart';
import '../providers/template_provider.dart';
import 'template_edit_screen.dart';
import '../services/enhanced_update_service.dart'; // Use enhanced service
import '../services/auto_update_manager.dart'; // Import auto update manager
import '../services/about_info.dart'; // Import AboutInfo
import '../widgets/shared/custom_sliver_app_bar.dart'; // Import CustomSliverAppBar

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _currentVersion = "読み込み中...";
  bool _isLoadingUpdate = false;
  String _updateCheckResult = "";
  final EnhancedUpdateService _updateService = EnhancedUpdateService();
  final AutoUpdateManager _autoUpdateManager = AutoUpdateManager();
  bool _autoUpdateCheckEnabled = true;
  bool _showUpdateDialog = true; // アップデート通知の表示設定
  Map<String, dynamic>? _aboutInfo;
  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
    _loadAutoUpdatePreference(); // Load preference
    _loadShowUpdateDialogPreference(); // Load show update dialog preference
    _loadAboutInfo(); // Load about info
  }

  Future<void> _loadCurrentVersion() async {
    try {
      String version = await _updateService.getCurrentAppVersion();
      if (mounted) {
        setState(() {
          _currentVersion = version;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentVersion = "取得エラー";
        });
      }
      print('Failed to load current version: $e');
    }
  }
  // Method to load auto update preference
  Future<void> _loadAutoUpdatePreference() async {
    bool enabled = await _autoUpdateManager.isAutoUpdateEnabled();
    if (mounted) {
      setState(() {
        _autoUpdateCheckEnabled = enabled;
      });
    }
  }
  // Method to save auto update preference
  Future<void> _setAutoUpdatePreference(bool value) async {
    await _autoUpdateManager.setAutoUpdateEnabled(value);
    if (mounted) {
      setState(() {
        _autoUpdateCheckEnabled = value;
      });
    }
  }

  // Method to load show update dialog preference
  Future<void> _loadShowUpdateDialogPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedShowUpdateDialog = prefs.getBool('show_update_dialog');
      if (mounted) {
        setState(() {
          _showUpdateDialog = savedShowUpdateDialog ?? true; // デフォルトはtrue
        });
      }
    } catch (e) {
      print('Failed to load show update dialog preference: $e');
    }
  }

  // Method to set show update dialog preference
  Future<void> _setShowUpdateDialog(bool value) async {
    // SharedPreferencesを使って設定を保存
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('show_update_dialog', value);
      if (mounted) {
        setState(() {
          _showUpdateDialog = value;
        });
      }
    } catch (e) {
      print('Failed to save show update dialog preference: $e');
    }
  }

  Future<void> _loadAboutInfo() async {
    try {
      final info = await AboutInfo.getInfo();
      if (mounted) {
        setState(() {
          _aboutInfo = info;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aboutInfo = {'error': 'アプリ情報の取得に失敗しました'};
        });
      }
    }
  }
  Future<void> _checkForUpdates() async {
    if (!mounted) return;
    setState(() {
      _isLoadingUpdate = true;
      _updateCheckResult = "";
    });

    try {
      EnhancedAppUpdateInfo? releaseInfo = await _autoUpdateManager.checkForUpdatesManually();
      if (!mounted) return;

      if (releaseInfo != null) {        setState(() {
          _updateCheckResult = "新しいバージョンがあります: ${releaseInfo.version}";
        });
        _showUpdateDialogMethod(releaseInfo);
      } else {
        setState(() {
          _updateCheckResult = "お使いのバージョンは最新です。";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _updateCheckResult = "更新チェック中にエラーが発生しました: $e";
        });
      }
      print('Error checking for updates: $e');
    } finally {
      if (mounted) {        setState(() {
          _isLoadingUpdate = false;
        });
      }
    }
  }

  void _showUpdateDialogMethod(EnhancedAppUpdateInfo releaseInfo) {
    if (!mounted) return;
    _autoUpdateManager.showManualUpdateDialog(context, releaseInfo);
  }

  /// キャッシュ管理ダイアログを表示
  Future<void> _showCacheManagementDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.storage),
                  SizedBox(width: 8),
                  Text('キャッシュ管理'),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: _updateService.getCacheInfo(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      if (snapshot.hasError || snapshot.data?['error'] != null) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error, color: Colors.red, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              'キャッシュ情報の取得に失敗しました',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              snapshot.data?['error'] ?? snapshot.error.toString(),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        );
                      }

                      final cacheInfo = snapshot.data!;
                      final updateFiles = cacheInfo['updateFiles'] as int? ?? 0;
                      final updateSize = cacheInfo['updateSize'] as int? ?? 0;
                      final updateFileNames = cacheInfo['updateFileNames'] as List<String>? ?? [];

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // キャッシュ情報表示
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'アップデート関連ファイル',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('ファイル数:'),
                                    Text('$updateFiles個'),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('使用容量:'),
                                    Text('${(updateSize / 1024 / 1024).toStringAsFixed(2)} MB'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          // ファイル一覧
                          if (updateFileNames.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              'ファイル一覧',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 150),
                              child: SingleChildScrollView(
                                child: Column(
                                  children: updateFileNames.map((fileName) {
                                    return ListTile(
                                      dense: true,
                                      leading: const Icon(Icons.file_present, size: 16),
                                      title: Text(
                                        fileName,
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 16),
                            const Center(
                              child: Text('削除可能なキャッシュファイルはありません'),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('閉じる'),
                ),
                FutureBuilder<Map<String, dynamic>>(
                  future: _updateService.getCacheInfo(),
                  builder: (context, snapshot) {
                    final cacheInfo = snapshot.data;
                    final updateFiles = cacheInfo?['updateFiles'] as int? ?? 0;
                    final hasFiles = updateFiles > 0;
                    
                    return FilledButton.icon(
                      onPressed: hasFiles ? () => _clearCache(context) : null,
                      icon: const Icon(Icons.delete_sweep),
                      label: const Text('キャッシュをクリア'),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// キャッシュをクリアする
  Future<void> _clearCache(BuildContext dialogContext) async {
    // 確認ダイアログを表示
    final confirmed = await showDialog<bool>(
      context: dialogContext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('確認'),
          content: const Text('本当にキャッシュファイルを削除しますか？\n\nこの操作は元に戻せません。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('削除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      // プログレスダイアログを表示
      showDialog(
        context: dialogContext,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('キャッシュを削除中...'),
              ],
            ),
          );
        },
      );

      // キャッシュを削除
      final result = await _updateService.clearUpdateCache();
      
      // プログレスダイアログを閉じる
      Navigator.of(dialogContext).pop();
      
      // 結果を表示
      final success = result['success'] as bool? ?? false;
      final message = result['message'] as String? ?? '';
      
      showDialog(
        context: dialogContext,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.error,
                  color: success ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(success ? '完了' : 'エラー'),
              ],
            ),
            content: Text(message),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop(); // 結果ダイアログを閉じる
                  Navigator.of(dialogContext).pop(); // キャッシュ管理ダイアログを閉じる
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      
    } catch (e) {
      // プログレスダイアログを閉じる（エラー時）
      Navigator.of(dialogContext).pop();
      
      // エラーダイアログを表示
      showDialog(
        context: dialogContext,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('エラー'),
              ],
            ),
            content: Text('キャッシュの削除中にエラーが発生しました:\n$e'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }
}
