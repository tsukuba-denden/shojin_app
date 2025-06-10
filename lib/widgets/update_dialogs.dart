import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/enhanced_update_service.dart';
import '../services/update_manager.dart';

class UpdateProgressDialog extends StatefulWidget {
  final EnhancedAppUpdateInfo updateInfo;
  final VoidCallback? onCompleted;
  final VoidCallback? onCancelled;

  const UpdateProgressDialog({
    Key? key,
    required this.updateInfo,
    this.onCompleted,
    this.onCancelled,
  }) : super(key: key);

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

    // Check permissions for Android
    try {
      // Use Platform.isAndroid instead of Theme.of(context).platform
      if (Platform.isAndroid) {
        bool permissionGranted = await _requestStoragePermissionWithDialog();
        if (!permissionGranted) {
          setState(() {
            _hasError = true;
            _currentProgress = UpdateProgress(
              progress: 0.0,
              status: 'ストレージ権限が必要です',
              errorMessage: 'Storage permission denied',
            );
            _isDownloading = false;
          });
          return;
        }
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _currentProgress = UpdateProgress(
          progress: 0.0,
          status: '権限チェックエラー',
          errorMessage: e.toString(),
        );
        _isDownloading = false;
      });
      return;
    }

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
        // Auto-install after download completion
        await Future.delayed(const Duration(milliseconds: 500));
        await _updateManager.applyUpdate(_downloadedFilePath!, widget.updateInfo.assetName);
        
        if (mounted) {
          setState(() {
            _currentProgress = UpdateProgress(
              progress: 1.0,
              status: 'インストールを開始しました',
              isCompleted: true,
            );
          });
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

  // ストレージ権限の要求（ダイアログ付き）
  Future<bool> _requestStoragePermissionWithDialog() async {
    // まず現在の権限状態をチェック
    bool hasPermission = await _updateService.requestStoragePermission();
    
    if (hasPermission) {
      return true;
    }

    // 権限が無い場合、ユーザーに説明ダイアログを表示
    if (!mounted) return false;
    
    bool? userWantsToGrant = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.folder_open, color: Colors.orange),
              SizedBox(width: 8),
              Text('ストレージ権限が必要です'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'アップデートファイルをダウンロードするために、ストレージへのアクセス権限が必要です。',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Text(
                '• ファイルのダウンロードと保存\n• 一時的なファイルの作成',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('権限を許可'),
            ),
          ],
        );
      },
    );

    if (userWantsToGrant != true) {
      return false;
    }

    // ユーザーが同意した場合、再度権限を要求
    hasPermission = await _updateService.requestStoragePermission();
    
    if (!hasPermission && mounted) {
      // まだ権限が取得できない場合、設定画面への案内を表示
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.settings, color: Colors.blue),
                SizedBox(width: 8),
                Text('設定で権限を有効にしてください'),
              ],
            ),
            content: const Text(
              'ストレージ権限が拒否されました。\n\n'
              'アプリの設定画面で手動で権限を有効にしてから、再度お試しください。\n\n'
              '設定 > アプリ > Shojin App > 権限 > ストレージ',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }

    return hasPermission;
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
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Version info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
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
                    backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
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
              
              // Error message
              if (_hasError && _currentProgress?.errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _currentProgress!.errorMessage!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onErrorContainer,
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
    Key? key,
    required this.updateInfo,
    this.onUpdatePressed,
    this.onLaterPressed,
    this.onSkipPressed,
  }) : super(key: key);
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
