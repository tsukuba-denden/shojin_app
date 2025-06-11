import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/enhanced_update_service.dart';
import '../services/update_manager.dart';

class UpdateProgressDialog extends StatefulWidget {
  final EnhancedAppUpdateInfo updateInfo;
  final VoidCallback? onCompleted;
  final VoidCallback? onCancelled;

  const UpdateProgressDialog({
    super.key,
    required this.updateInfo,
    this.onCompleted,
    this.onCancelled,
  });

  @override
  State<UpdateProgressDialog> createState() => _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends State<UpdateProgressDialog> {
  final EnhancedUpdateService _updateService = EnhancedUpdateService();
  final UpdateManager _updateManager = UpdateManager();
  StreamSubscription<UpdateProgress>? _progressSubscription;
  
  UpdateProgress? _currentProgress;
  bool _isDownloading = false;
  bool _isCompleted = false;
  bool _hasError = false;
  bool _isInitialized = false; // 初期化フラグを追加
  String? _downloadedFilePath;
  @override
  void initState() {
    super.initState();
    // Theme.of(context)を使用する処理はdidChangeDependenciesに移動
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 初回実行時のみアップデートチェックを開始
    if (!_isInitialized && !_isDownloading && !_isCompleted && !_hasError) {
      _isInitialized = true;
      _startDownload();
    }
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _updateService.disposeProgressStream();
    super.dispose();
  }  void _startDownload() async {
    setState(() {
      _isDownloading = true;
      _hasError = false;
    });

    // キャッシュを使用するため権限チェックは不要
    // アプリ内部ストレージを使用するため、Androidでも権限は必要ない
    debugPrint('Starting download using cache (no permissions required)');

    // Listen to progress stream
    _progressSubscription = _updateService.progressStream?.listen(
      (progress) {
        if (mounted) {
          setState(() {
            _currentProgress = progress;
            if (progress.isCompleted) {
              _isCompleted = true;
              _isDownloading = false;
            }
            if (progress.errorMessage != null) {
              _hasError = true;
              _isDownloading = false;
            }
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _isDownloading = false;
            _currentProgress = UpdateProgress(
              progress: 0.0,
              status: 'エラーが発生しました',
              errorMessage: error.toString(),
            );
          });
        }
      },
    );

    // Start download
    try {
      _downloadedFilePath = await _updateService.downloadUpdateWithProgress(widget.updateInfo);
        if (_downloadedFilePath != null && mounted) {
        // インストール前にファイルを適切な場所に準備
        setState(() {
          _currentProgress = UpdateProgress(
            progress: 1.0,
            status: 'インストール準備中...',
            isCompleted: false,
          );
        });
        
        try {
          await Future.delayed(const Duration(milliseconds: 500));
          
          // APKインストール用にファイルを準備
          final String fileName = widget.updateInfo.assetName ?? 'update.apk';
          final String? installFilePath = await _updateService.prepareForInstallation(
            _downloadedFilePath!, 
            fileName
          );
          
          if (installFilePath != null) {
            debugPrint('Installing from prepared path: $installFilePath');
            await _updateManager.applyUpdate(installFilePath, widget.updateInfo.assetName);
            
            // インストール後のクリーンアップ
            await _updateService.cleanupAfterInstallation();
            
            if (mounted) {
              setState(() {
                _currentProgress = UpdateProgress(
                  progress: 1.0,
                  status: 'インストールを開始しました',
                  isCompleted: true,
                );
              });
            }
          } else {
            throw Exception('インストール用ファイルの準備に失敗しました');
          }        } catch (e) {
          debugPrint('Installation preparation error: $e');
          if (mounted) {
            setState(() {
              _hasError = true;
              _currentProgress = UpdateProgress(
                progress: 1.0,
                status: 'インストール準備エラー',
                errorMessage: e.toString(),
              );
            });
            
            // 手動インストールガイダンスを表示
            _showManualInstallDialog(e.toString());
          }
          return; // エラー時は早期リターン
        }
        
        // Close dialog after successful installation
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop();
          widget.onCompleted?.call();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isDownloading = false;
          _currentProgress = UpdateProgress(
            progress: 0.0,
            status: 'ダウンロードエラー',
            errorMessage: e.toString(),
          );
        });
      }
    }
  }
  void _retryDownload() {
    _updateService.disposeProgressStream();
    setState(() {
      _hasError = false;
      _isCompleted = false;
      _currentProgress = null;
    });
    _startDownload();
  }
  void _cancelDownload() {
    _updateService.disposeProgressStream();
    Navigator.of(context).pop();
    widget.onCancelled?.call();
  }

  // 手動インストールガイダンスダイアログを表示
  void _showManualInstallDialog(String errorMessage) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text('手動インストールが必要です'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'アップデートファイルのダウンロードは完了しましたが、自動インストールが実行できませんでした。',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '手動インストール手順:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '1. ファイルマネージャーアプリを開く\n'
                        '2. 以下のフォルダーに移動:\n'
                        '   Android → data → com.example.shojin_app → files → temp_install\n'
                        '3. app-arm64-v8a-release.apk をタップ\n'
                        '4. 「インストール」をタップ',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '権限設定が必要な場合:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '設定 → アプリ → Shojin App → 詳細設定 → 不明なアプリのインストール → 許可',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                if (errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'エラー詳細:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 80),
                    child: SingleChildScrollView(
                      child: Text(
                        errorMessage,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // ガイダンスダイアログを閉じる
                Navigator.of(context).pop(); // アップデートダイアログも閉じる
                widget.onCancelled?.call();
              },
              child: const Text('閉じる'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop(); // ガイダンスダイアログを閉じる
                // ファイルマネージャーを開く試み
                try {
                  final Uri directoryUri = Uri.parse('content://com.android.externalstorage.documents/document/primary:Android%2Fdata%2Fcom.example.shojin_app%2Ffiles%2Ftemp_install');
                  await launchUrl(directoryUri, mode: LaunchMode.externalApplication);
                } catch (e) {
                  debugPrint('Failed to open file manager: $e');
                }
              },
              child: const Text('ファイルマネージャーを開く'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevent dialog dismissal during download
        return !_isDownloading;
      },
      child: AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.download, color: Colors.blue),
            const SizedBox(width: 8),
            const Text('アップデートダウンロード'),
          ],
        ),        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.6, // 画面の60%の高さに制限
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Version info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'バージョン ${widget.updateInfo.version}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.updateInfo.fileSize != null)
                        Text(
                          'ファイルサイズ: ${(widget.updateInfo.fileSize! / 1024 / 1024).toStringAsFixed(1)} MB',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Progress section
                if (_currentProgress != null) ...[
                  Text(
                    _currentProgress!.status,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  
                  // Progress bar
                  if (_currentProgress!.progress >= 0)
                    LinearProgressIndicator(
                      value: _currentProgress!.progress,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    )
                  else
                    const LinearProgressIndicator(), // Indeterminate
                  
                  const SizedBox(height: 8),
                  
                  // Progress text
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _currentProgress!.formattedProgress,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (_currentProgress!.progress >= 0)
                        Text(
                          '${(_currentProgress!.progress * 100).toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ],
                
                // Error message - 表示を制限
                if (_hasError && _currentProgress?.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Theme.of(context).colorScheme.onErrorContainer,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'エラーが発生しました',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 100), // エラーメッセージの高さを制限
                          child: SingleChildScrollView(
                            child: Text(
                              _currentProgress!.errorMessage!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Success message
                if (_isCompleted && !_hasError) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ダウンロード完了！インストールを開始します。',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          // Cancel button (only show when not downloading)
          if (!_isDownloading && !_isCompleted)
            TextButton(
              onPressed: _cancelDownload,
              child: const Text('キャンセル'),
            ),
          
          // Retry button (only show on error)
          if (_hasError)
            TextButton(
              onPressed: _retryDownload,
              child: const Text('再試行'),
            ),
          
          // Close button (only show when completed or error)
          if ((_isCompleted && !_isDownloading) || _hasError)
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (_isCompleted) {
                  widget.onCompleted?.call();
                }
              },
              child: const Text('閉じる'),
            ),
        ],
      ),
    );
  }
}

// Enhanced Update Notification Dialog (like ReVanced Manager)
class EnhancedUpdateDialog extends StatelessWidget {
  final EnhancedAppUpdateInfo updateInfo;
  final VoidCallback? onUpdatePressed;
  final VoidCallback? onLaterPressed;
  final VoidCallback? onSkipPressed;

  const EnhancedUpdateDialog({
    super.key,
    required this.updateInfo,
    this.onUpdatePressed,
    this.onLaterPressed,
    this.onSkipPressed,
  });
  @override
  Widget build(BuildContext context) {
    // Ensure version string has 'v' prefix for URL
    String versionTag = updateInfo.releaseTag ?? updateInfo.version;
    if (!versionTag.startsWith('v')) {
      versionTag = 'v$versionTag';
    }

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.system_update_alt,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          const Text("アップデート利用可能"),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Version info card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "新しいバージョン",
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    "v${updateInfo.version}",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (updateInfo.releaseDate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      "リリース日: ${updateInfo.releaseDate!.year}/${updateInfo.releaseDate!.month}/${updateInfo.releaseDate!.day}",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                  if (updateInfo.fileSize != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      "ファイルサイズ: ${(updateInfo.fileSize! / 1024 / 1024).toStringAsFixed(1)} MB",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Release notes
            if (updateInfo.releaseNotes != null && updateInfo.releaseNotes!.isNotEmpty) ...[
              Text(
                "リリースノート",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Text(
                    updateInfo.releaseNotes!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ] else ...[
              Text(
                "リリースノート",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "リリースノートはありません。",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        // Later button
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onLaterPressed?.call();
          },
          child: const Text('後で'),
        ),
          // View on GitHub button
        TextButton(
          onPressed: () async {
            Navigator.of(context).pop();
            final String releaseUrl = "https://github.com/tsukuba-denden/Shojin_App/releases/tag/$versionTag";
            // You can use url_launcher here if available
            // await launchUrl(Uri.parse(releaseUrl));
            debugPrint('GitHub URL: $releaseUrl');
          },
          child: const Text('GitHubで見る'),
        ),
        
        // Update button
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            onUpdatePressed?.call();
          },
          child: const Text('アップデート'),
        ),
      ],
    );
  }
}
