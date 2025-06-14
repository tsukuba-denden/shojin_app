import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:package_info_plus/package_info_plus.dart' as pip;
import 'package:pub_semver/pub_semver.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:android_package_installer/android_package_installer.dart';

/// アップデート情報クラス
class EnhancedAppUpdateInfo {
  final String version;
  final String? releaseNotes;
  final String? downloadUrl;
  final DateTime? releaseDate;
  final String? assetName;
  final int? fileSize;
  final String? releaseTag;
  final String fileName;

  EnhancedAppUpdateInfo({
    required this.version,
    this.releaseNotes,
    this.downloadUrl,
    this.releaseDate,
    this.assetName,
    this.fileSize,
    this.releaseTag,
    required this.fileName,
  });
}

/// プログレス情報クラス
class UpdateProgress {
  final double progress;
  final String status;
  final int? bytesDownloaded;
  final int? totalBytes;
  final bool isCompleted;
  final String? errorMessage;

  UpdateProgress({
    required this.progress,
    required this.status,
    this.bytesDownloaded,
    this.totalBytes,
    this.isCompleted = false,
    this.errorMessage,
  });

  String get formattedProgress {
    if (totalBytes != null && bytesDownloaded != null) {
      final downloadedMB = (bytesDownloaded! / 1024 / 1024);
      final totalMB = (totalBytes! / 1024 / 1024);
      return '${downloadedMB.toStringAsFixed(1)} MB / ${totalMB.toStringAsFixed(1)} MB';
    }
    return '${(progress * 100).toStringAsFixed(1)}%';
  }
}

/// 高機能アップデートサービス
class EnhancedUpdateService {
  // プログレス用のStreamController
  StreamController<UpdateProgress>? _progressController;
  bool _cancelDownload = false; // ダウンロードキャンセル用フラグ
  int _lastLoggedPercentage = -1; // ログ抑制用
  
  /// プログレスストリームの取得
  Stream<UpdateProgress>? get progressStream => _progressController?.stream;
    /// プログレスストリームの初期化
  void initializeProgressStream() {
    developer.log('Progress stream initializing...', name: 'EnhancedUpdateService');
    // 既存のStreamControllerがあれば閉じる
    if (_progressController != null && !_progressController!.isClosed) {
      _progressController!.close();
    }
    _progressController = StreamController<UpdateProgress>.broadcast();
    developer.log('Progress stream initialized successfully', name: 'EnhancedUpdateService');
  }
    /// プログレス更新
  void _updateProgress(UpdateProgress progress) {
    // developer.log(
    //   'Progress Update: ${progress.status} - ${progress.formattedProgress}',
    //   name: 'EnhancedUpdateService'
    // );
    
    if (_progressController != null && !_progressController!.isClosed) {
      _progressController!.add(progress);
      // developer.log('Progress sent to stream successfully', name: 'EnhancedUpdateService');
    } else {
      developer.log('Warning: Progress controller is null or closed', name: 'EnhancedUpdateService');
      // 緊急時はStreamControllerを再初期化
      if (_progressController == null) {
        initializeProgressStream();
        if (_progressController != null && !_progressController!.isClosed) {
          _progressController!.add(progress);
          // developer.log('Progress sent after emergency re-initialization', name: 'EnhancedUpdateService');
        }
      }
    }
  }
  
  /// プログレスストリームの破棄
  void disposeProgressStream() {
    _progressController?.close();
    _progressController = null;
    developer.log('Progress stream disposed', name: 'EnhancedUpdateService');
  }

  /// プログレスとキャンセル状態をリセット
  void _resetDownloadState() {
    _lastLoggedPercentage = -1;
    _cancelDownload = false;
    developer.log('Download state reset.', name: 'EnhancedUpdateService');
  }

  /// 現在のダウンロードをキャンセル
  void cancelCurrentDownload() {
    developer.log('Download cancellation requested.', name: 'EnhancedUpdateService');
    _cancelDownload = true;
  }
  
  /// 現在のアプリバージョンを取得
  Future<String> getCurrentAppVersion() async {
    try {
      final packageInfo = await pip.PackageInfo.fromPlatform();
      final version = packageInfo.version;
      developer.log('Current app version: $version', name: 'EnhancedUpdateService');
      return version;
    } catch (e) {
      developer.log('Error getting app version: $e', name: 'EnhancedUpdateService');
      return '0.0.0';
    }
  }
  
  /// アップデートが利用可能かチェック
  bool isUpdateAvailable(String currentVersionStr, String latestVersionStr) {
    try {
      final cleanCurrentVersion = currentVersionStr.replaceAll('v', '');
      final cleanLatestVersion = latestVersionStr.replaceAll('v', '');
      
      final currentVersion = Version.parse(cleanCurrentVersion);
      final latestVersion = Version.parse(cleanLatestVersion);
      
      final updateAvailable = latestVersion > currentVersion;
      
      developer.log(
        'Version comparison: $cleanCurrentVersion vs $cleanLatestVersion = $updateAvailable',
        name: 'EnhancedUpdateService'
      );
      
      return updateAvailable;
    } catch (e) {
      developer.log('Error parsing version strings: $e', name: 'EnhancedUpdateService');
      return false;
    }
  }
  
  /// GitHubから最新リリース情報を取得
  Future<EnhancedAppUpdateInfo?> getLatestReleaseInfo(String owner, String repo, {bool silent = false}) async {
    final url = Uri.parse('https://api.github.com/repos/$owner/$repo/releases/latest');
    
    try {
      final response = await http.get(url, headers: {'Accept': 'application/vnd.github.v3+json'});
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        
        DateTime? releaseDateTime;
        if (jsonResponse['published_at'] != null) {
          releaseDateTime = DateTime.tryParse(jsonResponse['published_at']);
        }

        String? assetDownloadUrl;
        String? foundAssetName;
        int? fileSize;
        
        if (jsonResponse['assets'] != null && jsonResponse['assets'] is List) {
          final assetDetails = _getPlatformSpecificAssetUrl(jsonResponse['assets']);
          if (assetDetails != null) {
            assetDownloadUrl = assetDetails['url'];
            foundAssetName = assetDetails['name'];
            fileSize = assetDetails['size'];
          }
        }

        final rawTagName = jsonResponse['tag_name'] ?? '0.0.0';
        final cleanVersion = rawTagName.replaceAll('v', '');
        
        if (!silent) {
          developer.log('GitHub Release: $cleanVersion, Asset: $foundAssetName', name: 'EnhancedUpdateService');
        }
        
        return EnhancedAppUpdateInfo(
          version: cleanVersion,
          releaseNotes: jsonResponse['body'],
          releaseDate: releaseDateTime,
          downloadUrl: assetDownloadUrl,
          assetName: foundAssetName,
          fileSize: fileSize,
          releaseTag: rawTagName,
          fileName: foundAssetName ?? 'app-release.apk',
        );
      } else {
        if (!silent) {
          developer.log('Failed to get latest release info: ${response.statusCode}', name: 'EnhancedUpdateService');
        }
        return null;
      }
    } catch (e) {
      if (!silent) {
        developer.log('Error fetching latest release info: $e', name: 'EnhancedUpdateService');
      }
      return null;
    }
  }
  
  /// プラットフォーム固有のアセットURLを取得
  Map<String, dynamic>? _getPlatformSpecificAssetUrl(List<dynamic> assets) {
    final os = Platform.operatingSystem;
    List<String> prioritizedPatterns = [];

    switch (os) {
      case 'android':
        prioritizedPatterns = ['.apk'];
        break;
      case 'windows':
        prioritizedPatterns = ['.exe', '.msi', '.zip'];
        break;
      case 'macos':
        prioritizedPatterns = ['.dmg', '.zip'];
        break;
      case 'linux':
        prioritizedPatterns = ['.AppImage', '.deb', '.tar.gz'];
        break;
      case 'ios':
        prioritizedPatterns = ['.ipa'];
        break;
    }

    for (final pattern in prioritizedPatterns) {
      for (final asset in assets) {
        if (asset is Map && asset.containsKey('name') && asset.containsKey('browser_download_url')) {
          final name = asset['name'].toString().toLowerCase();
          if (name.endsWith(pattern.toLowerCase())) {
            return {
              'url': asset['browser_download_url'],
              'name': asset['name'],
              'size': asset['size']
            };
          }
        }
      }
    }

    // Linuxのフォールバック
    if (os == 'linux') {
      for (final asset in assets) {
        if (asset is Map && asset.containsKey('name') && asset.containsKey('browser_download_url')) {
          final name = asset['name'].toString().toLowerCase();
          if (name.endsWith('.zip') || name.endsWith('.tar.gz')) {
            return {
              'url': asset['browser_download_url'],
              'name': asset['name'],
              'size': asset['size']
            };
          }
        }
      }
    }
    return null;
  }  
  /// アップデートファイルをダウンロード（プログレス付き）
  Future<String?> downloadUpdateWithProgress(EnhancedAppUpdateInfo releaseInfo) async {
    if (releaseInfo.downloadUrl == null || releaseInfo.downloadUrl!.isEmpty) {
      _updateProgress(UpdateProgress(
        progress: 0.0,
        status: 'エラー: ダウンロードURLが無効です',
        errorMessage: 'Download URL is null or empty',
      ));
      return null;
    }

    if (_progressController == null || _progressController!.isClosed) {
      initializeProgressStream();
    }
    
    _resetDownloadState();

    _updateProgress(UpdateProgress(
      progress: 0.0,
      status: 'ダウンロード準備中...',
    ));

    final client = http.Client();
    String? filePath;

    try {
      final request = http.Request('GET', Uri.parse(releaseInfo.downloadUrl!));
      final http.StreamedResponse response = await client.send(request);

      if (response.statusCode != 200) {
        _updateProgress(UpdateProgress(
          progress: 0.0,
          status: 'ダウンロードエラー: ${response.statusCode}',
          errorMessage: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        ));
        client.close();
        return null;
      }

      final totalBytes = response.contentLength ?? 0;
      int downloadedBytes = 0;

      _updateProgress(UpdateProgress(
        progress: 0.0,
        status: 'ダウンロード開始...',
        bytesDownloaded: 0,
        totalBytes: totalBytes,
      ));
      
      final cacheDir = await getApplicationCacheDirectory();
      final file = File('${cacheDir.path}/${releaseInfo.fileName}');
      await file.parent.create(recursive: true);
      final sink = file.openWrite();
      filePath = file.path;

      await for (final chunk in response.stream) {
        if (_cancelDownload) {
          developer.log('Download cancelled by user.', name: 'EnhancedUpdateService');
          _updateProgress(UpdateProgress(
            progress: totalBytes > 0 ? downloadedBytes / totalBytes : 0.0,
            status: 'ダウンロードがキャンセルされました',
            bytesDownloaded: downloadedBytes,
            totalBytes: totalBytes,
            errorMessage: 'User cancelled download',
          ));
          await sink.close(); 
          if (await file.exists()) {
            await file.delete(); 
          }
          filePath = null; 
          client.close();
          return null;
        }

        sink.add(chunk);
        downloadedBytes += chunk.length;

        final currentProgress = totalBytes > 0 ? downloadedBytes / totalBytes : 0.0;
        
        int currentPercentage = (currentProgress * 100).toInt();
        if (currentPercentage > 100) currentPercentage = 100;

        bool shouldLog = false;
        if (_lastLoggedPercentage == -1 && currentPercentage == 0) {
          shouldLog = true;
        } else if (currentPercentage >= _lastLoggedPercentage + 10 && currentPercentage < 100) {
          shouldLog = true;
        } else if (currentProgress >= 1.0 && currentPercentage == 100 && _lastLoggedPercentage < 100) { 
          shouldLog = true;
        }
        
        if (shouldLog) {
          developer.log('Progress Update: $currentPercentage%', name: 'EnhancedUpdateService');
          _lastLoggedPercentage = currentPercentage;
        }

        _updateProgress(UpdateProgress(
          progress: currentProgress,
          status: 'ダウンロード中...',
          bytesDownloaded: downloadedBytes,
          totalBytes: totalBytes,
        ));
      }

      await sink.flush(); 
      await sink.close();

      if (_cancelDownload) {
        if (filePath != null && await File(filePath).exists()) {
            await File(filePath).delete();
        }
        client.close();
        return null;
      }
      
      if (!await file.exists()){
        developer.log('Error: File does not exist after download attempt (not due to cancellation). Path: ${file.path}', name: 'EnhancedUpdateService');
        _updateProgress(UpdateProgress(
          progress: downloadedBytes / totalBytes,
          status: 'ダウンロードエラー: ファイルが作成されませんでした',
          bytesDownloaded: downloadedBytes,
          totalBytes: totalBytes,
          errorMessage: 'File not created after download.',
          isCompleted: true,
        ));
        client.close();
        return null;
      }

      if (totalBytes == 0 || downloadedBytes == totalBytes) { 
        _updateProgress(UpdateProgress(
          progress: 1.0,
          status: 'ダウンロード完了！インストールを開始します...',
          bytesDownloaded: downloadedBytes,
          totalBytes: totalBytes,
          isCompleted: false, // まだ完了していない（インストールが残っている）
        ));
        developer.log('Download completed: ${file.path}', name: 'EnhancedUpdateService');
        client.close();
        return file.path;
      } else if (downloadedBytes < totalBytes && totalBytes > 0) {
        _updateProgress(UpdateProgress(
          progress: downloadedBytes / totalBytes,
          status: 'ダウンロードが不完全です',
          bytesDownloaded: downloadedBytes,
          totalBytes: totalBytes,
          errorMessage: 'Downloaded size ($downloadedBytes) does not match total size ($totalBytes).',
          isCompleted: true, 
        ));
        if (await file.exists()) { 
            await file.delete(); 
        }
        client.close();
        return null;
      } else {
         _updateProgress(UpdateProgress(
          progress: totalBytes > 0 ? downloadedBytes / totalBytes : 0.0, 
          status: 'ダウンロード中に予期せぬ問題が発生しました',
          bytesDownloaded: downloadedBytes,
          totalBytes: totalBytes,
          errorMessage: 'Unexpected issue during download completion. Downloaded: $downloadedBytes, Total: $totalBytes',
          isCompleted: true,
        ));
        if (await file.exists()) {
            await file.delete();
        }
        client.close();
        return null;
      }

    } catch (e, s) {
      developer.log('Download error: $e\\nStackTrace: $s', name: 'EnhancedUpdateService');
      _updateProgress(UpdateProgress(
        progress: 0.0, 
        status: 'ダウンロードエラー',
        errorMessage: e.toString(),
      ));
      if (filePath != null && await File(filePath).exists()) {
          try {
              await File(filePath).delete();
              developer.log('Deleted incomplete file due to error: $filePath', name: 'EnhancedUpdateService');
          } catch (deleteError) {
              developer.log('Error deleting incomplete file: $deleteError', name: 'EnhancedUpdateService');
          }
      }
      client.close();
      return null;
    }
  }

  /// 起動時のアップデートチェック（サイレント）
  Future<EnhancedAppUpdateInfo?> checkForUpdateOnStartup(String currentVersion, String owner, String repo) async {
    try {
      final releaseInfo = await getLatestReleaseInfo(owner, repo, silent: true);
      if (releaseInfo != null && isUpdateAvailable(currentVersion, releaseInfo.version)) {
        return releaseInfo;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// アップデート試行を記録
  Future<void> markUpdateAttempt(String targetVersion) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_update_version', targetVersion);
    await prefs.setInt('update_attempt_timestamp', DateTime.now().millisecondsSinceEpoch);
    developer.log('Marked update attempt for version: $targetVersion', name: 'EnhancedUpdateService');
  }
  
  /// アップデート完了を記録
  Future<void> markUpdateCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_update_version');
    await prefs.remove('update_attempt_timestamp');
    await prefs.setString('last_completed_update', await getCurrentAppVersion());
    await prefs.setInt('last_update_timestamp', DateTime.now().millisecondsSinceEpoch);
    developer.log('Marked update as completed', name: 'EnhancedUpdateService');
  }
  
  /// アップデート成功の確認と通知
  Future<bool> checkAndNotifyUpdateSuccess() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingVersion = prefs.getString('pending_update_version');
      final currentVersion = await getCurrentAppVersion();
      
      if (pendingVersion != null && pendingVersion == currentVersion) {
        await markUpdateCompleted();
        developer.log('Update successful: $pendingVersion → $currentVersion', name: 'EnhancedUpdateService');
        return true;
      }
      
      // 古いpending updateをクリア（24時間経過）
      final attemptTimestamp = prefs.getInt('update_attempt_timestamp');
      if (attemptTimestamp != null) {
        final attemptTime = DateTime.fromMillisecondsSinceEpoch(attemptTimestamp);
        final elapsed = DateTime.now().difference(attemptTime);
        
        if (elapsed.inHours > 24) {
          await prefs.remove('pending_update_version');
          await prefs.remove('update_attempt_timestamp');
          developer.log('Cleared old pending update: $pendingVersion', name: 'EnhancedUpdateService');
        }
      }
      
      return false;
    } catch (e) {
      developer.log('Error checking update success: $e', name: 'EnhancedUpdateService');
      return false;
    }
  }
  
  /// 最後に完了したアップデート情報を取得
  Future<Map<String, dynamic>?> getLastUpdateInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final version = prefs.getString('last_completed_update');
      final timestamp = prefs.getInt('last_update_timestamp');
      
      if (version != null && timestamp != null) {
        return {
          'version': version,
          'timestamp': DateTime.fromMillisecondsSinceEpoch(timestamp),
          'timeAgo': DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(timestamp)),
        };
      }
      return null;
    } catch (e) {
      developer.log('Error getting last update info: $e', name: 'EnhancedUpdateService');
      return null;
    }
  }  
  /// APKインストール処理
  Future<void> installUpdate(String apkPath) async {
    try {
      developer.log('Installing APK: $apkPath', name: 'EnhancedUpdateService');
      
      final statusCode = await AndroidPackageInstaller.installApk(apkFilePath: apkPath);
      
      if (statusCode == null) {
        developer.log('Installation failed: status code was null', name: 'EnhancedUpdateService');
        return;
      }

      if (statusCode == -1) {
        developer.log('Installation pending user action', name: 'EnhancedUpdateService');
        return;
      }

      final installationStatus = PackageInstallerStatus.byCode(statusCode);
      developer.log('Installation status: ${installationStatus.name}', name: 'EnhancedUpdateService');

      if (installationStatus == PackageInstallerStatus.success) {
        developer.log('Installation process started successfully', name: 'EnhancedUpdateService');
      } else {
        developer.log('Installation failed: ${installationStatus.name}', name: 'EnhancedUpdateService');
      }
    } catch (e) {
      developer.log('Installation error: $e', name: 'EnhancedUpdateService');
    }
  }
  
  /// アップデート適用処理（プログレス付き）
  Future<void> applyUpdate(String apkPath, BuildContext context) async {
    // プログレスストリームの初期化
    if (_progressController == null || _progressController!.isClosed) {
      initializeProgressStream();
    }
    
    // 初期状態を通知
    _updateProgress(UpdateProgress(
      progress: 0.0, 
      status: 'インストール開始...'
    ));
    
    try {
      _updateProgress(UpdateProgress(
        progress: 0.1, 
        status: 'APKファイルを確認中...'
      ));
      
      if (!await File(apkPath).exists()) {
        _updateProgress(UpdateProgress(
          progress: 0.0,
          status: 'エラー: APKファイルが見つかりません',
          isCompleted: true,
          errorMessage: 'APKファイルが見つかりません: $apkPath',
        ));
        return;
      }

      _updateProgress(UpdateProgress(
        progress: 0.3, 
        status: 'インストールの準備中...'
      ));
      
      await Future.delayed(const Duration(milliseconds: 200));
      
      _updateProgress(UpdateProgress(
        progress: 0.5, 
        status: 'インストーラーを起動しています...'
      ));

      developer.log('Attempting to install APK: $apkPath', name: 'EnhancedUpdateService');
      final statusCode = await AndroidPackageInstaller.installApk(apkFilePath: apkPath);

      if (statusCode == null) {
        _updateProgress(UpdateProgress(
          progress: 1.0,
          status: 'インストール状態不明',
          isCompleted: true,
          errorMessage: 'Installation status code was null',
        ));
        return;
      }

      if (statusCode == -1) {
        _updateProgress(UpdateProgress(
          progress: 1.0, 
          status: 'ユーザーの操作待機中です。インストールを許可してください。',
          isCompleted: true, 
        ));
        return;
      }
      
      final installationStatus = PackageInstallerStatus.byCode(statusCode);

      if (installationStatus == PackageInstallerStatus.success) {
        _updateProgress(UpdateProgress(
          progress: 1.0,
          status: 'インストール処理をシステムに委譲しました',
          isCompleted: true,
        ));
      } else {
        String errorMessage = 'インストール開始失敗';
        
        switch (installationStatus) {
          case PackageInstallerStatus.failure:
            errorMessage = 'インストール失敗';
            break;
          case PackageInstallerStatus.failureAborted:
            errorMessage = 'インストールが中止されました';
            break;
          case PackageInstallerStatus.failureBlocked:
            errorMessage = 'インストールがブロックされました';
            break;
          case PackageInstallerStatus.failureConflict:
            errorMessage = '競合が発生したためインストールできませんでした';
            break;
          case PackageInstallerStatus.failureIncompatible:
            errorMessage = '互換性がないためインストールできませんでした';
            break;
          case PackageInstallerStatus.failureInvalid:
            errorMessage = '無効なAPKファイルです';
            break;
          case PackageInstallerStatus.failureStorage:
            errorMessage = 'ストレージ容量不足のためインストールできませんでした';
            break;
          case PackageInstallerStatus.unknown:
            errorMessage = '不明なインストールエラーが発生しました (コード: $statusCode)';
            break;
          default:
            errorMessage = '予期せぬインストール状態です: ${installationStatus.name} (code: $statusCode)';
        }
        
        _updateProgress(UpdateProgress(
          progress: 1.0,
          status: errorMessage,
          isCompleted: true,
          errorMessage: 'Installation failed with status: ${installationStatus.name} (code: $statusCode)',
        ));
      }
    } catch (e) {
      developer.log('Error applying update: $e', name: 'EnhancedUpdateService');
      _updateProgress(UpdateProgress(
        progress: 1.0,
        status: 'アップデート適用中にエラーが発生しました',
        isCompleted: true,
        errorMessage: e.toString(),
      ));
    }
  }

  /// ダウンロードとインストールを連続して実行
  Future<void> downloadAndInstallUpdate(EnhancedAppUpdateInfo releaseInfo, BuildContext context) async {
    try {
      // バージョンを記録
      await markUpdateAttempt(releaseInfo.version);
      
      // ダウンロード実行
      final downloadedPath = await downloadUpdateWithProgress(releaseInfo);
      
      if (downloadedPath != null && !_cancelDownload) {
        // ダウンロード成功後、インストール開始
        await applyUpdate(downloadedPath, context);
      } else if (_cancelDownload) {
        _updateProgress(UpdateProgress(
          progress: 0.0,
          status: 'アップデートがキャンセルされました',
          isCompleted: true,
          errorMessage: 'Update cancelled by user',
        ));
      } else {
        _updateProgress(UpdateProgress(
          progress: 0.0,
          status: 'ダウンロードに失敗しました',
          isCompleted: true,
          errorMessage: 'Download failed',
        ));
      }
    } catch (e) {
      developer.log('Error in downloadAndInstallUpdate: $e', name: 'EnhancedUpdateService');
      _updateProgress(UpdateProgress(
        progress: 0.0,
        status: 'アップデート処理中にエラーが発生しました',
        isCompleted: true,
        errorMessage: e.toString(),
      ));
    }
  }
}
