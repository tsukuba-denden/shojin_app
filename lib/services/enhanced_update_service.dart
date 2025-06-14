import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart' as pip; // エイリアスを設定
import 'package:pub_semver/pub_semver.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cached_download_service.dart'; // キャッシュ機能付きダウンロードサービスをインポート
// TODO: Remove OpenFile if android_package_installer works well
// import 'package:open_file/open_file.dart';
import 'package:android_package_installer/android_package_installer.dart';
// import 'package:android_package_manager/android_package_manager.dart'; // 今回は未使用のためコメントアウト

// Enhanced AppUpdateInfo with more details
class EnhancedAppUpdateInfo {
  final String version;
  final String? releaseNotes;
  final String? downloadUrl;
  final DateTime? releaseDate;
  final String? assetName;
  final int? fileSize;
  final String? releaseTag;
  final String fileName; // ファイル名を追加

  EnhancedAppUpdateInfo({
    required this.version,
    this.releaseNotes,
    this.downloadUrl,
    this.releaseDate,
    this.assetName,
    this.fileSize,
    this.releaseTag,
    required this.fileName, // 必須パラメータとして追加
  });
}

// Progress information class
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
      return '${(bytesDownloaded! / 1024 / 1024).toStringAsFixed(1)} MB / ${(totalBytes! / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(progress * 100).toStringAsFixed(0)}%';
  }
}

// Enhanced Update Service with ReVanced Manager inspired features
class EnhancedUpdateService {
  // StreamController for progress management (like ReVanced Manager)
  StreamController<UpdateProgress>? _progressController;
  
  Stream<UpdateProgress>? get progressStream => _progressController?.stream;
  
  // Create progress stream
  void _initializeProgressStream() {
    _progressController = StreamController<UpdateProgress>.broadcast();
  }
  
  // Update progress
  void _updateProgress(UpdateProgress progress) {
    debugPrint('[EnhancedUpdateService] _updateProgress: status=${progress.status}, progress=${progress.progress}, formatted=${progress.formattedProgress}, completed=${progress.isCompleted}, error=${progress.errorMessage}');
    _progressController?.add(progress);
  }
  
  // Dispose progress stream
  void disposeProgressStream() {
    _progressController?.close();
    _progressController = null;
  }
  // Get current app version
  Future<String> getCurrentAppVersion() async {
    try {
      pip.PackageInfo packageInfo = await pip.PackageInfo.fromPlatform(); // エイリアスを使用
      String version = packageInfo.version;
      debugPrint('=== 現在のアプリバージョン取得 ===');
      debugPrint('PackageInfo.version: "$version"');
      debugPrint('PackageInfo.buildNumber: "${packageInfo.buildNumber}"');
      debugPrint('PackageInfo.appName: "${packageInfo.appName}"');
      debugPrint('PackageInfo.packageName: "${packageInfo.packageName}"');
      debugPrint('==============================');
      return version;
    } catch (e) {
      debugPrint('Error getting app version: $e');
      return '0.0.0';
    }
  }
  // Check if update is available
  bool isUpdateAvailable(String currentVersionStr, String latestVersionStr) {
    try {
      // Clean version strings by removing 'v' prefix
      String cleanCurrentVersion = currentVersionStr.replaceAll('v', '');
      String cleanLatestVersion = latestVersionStr.replaceAll('v', '');
      
      Version currentVersion = Version.parse(cleanCurrentVersion);
      Version latestVersion = Version.parse(cleanLatestVersion);
      
      bool updateAvailable = latestVersion > currentVersion;
      
      // Debug output
      debugPrint('=== バージョン比較デバッグ ===');
      debugPrint('現在のバージョン（元）: "$currentVersionStr"');
      debugPrint('現在のバージョン（処理後）: "$cleanCurrentVersion"');
      debugPrint('最新バージョン（元）: "$latestVersionStr"');
      debugPrint('最新バージョン（処理後）: "$cleanLatestVersion"');
      debugPrint('パース後 - 現在: $currentVersion');
      debugPrint('パース後 - 最新: $latestVersion');
      debugPrint('アップデート利用可能: $updateAvailable');
      debugPrint('===========================');
      
      return updateAvailable;
    } catch (e) {
      debugPrint('Error parsing version strings: $e');
      debugPrint('Current version string: "$currentVersionStr"');
      debugPrint('Latest version string: "$latestVersionStr"');
      return false;
    }
  }

  // Get latest release info with enhanced details
  Future<EnhancedAppUpdateInfo?> getLatestReleaseInfo(String owner, String repo, {bool silent = false}) async {
    final url = Uri.parse('https://api.github.com/repos/$owner/$repo/releases/latest');
    
    try {
      final response = await http.get(url, headers: {'Accept': 'application/vnd.github.v3+json'});      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        DateTime? releaseDateTime;

        if (jsonResponse['published_at'] != null) {
          releaseDateTime = DateTime.tryParse(jsonResponse['published_at']);
        }

        String? assetDownloadUrl;
        String? foundAssetName;
        int? fileSize;
        
        if (jsonResponse['assets'] != null && jsonResponse['assets'] is List) {
          Map<String, dynamic>? assetDetails = _getPlatformSpecificAssetUrl(jsonResponse['assets']);
          if (assetDetails != null) {
            assetDownloadUrl = assetDetails['url'];
            foundAssetName = assetDetails['name'];
            fileSize = assetDetails['size'];
          }
        }

        String rawTagName = jsonResponse['tag_name'] ?? '0.0.0';
        String cleanVersion = rawTagName.replaceAll('v', '');
        
        debugPrint('=== GitHub API レスポンス ===');
        debugPrint('tag_name（元）: "$rawTagName"');
        debugPrint('version（処理後）: "$cleanVersion"');
        debugPrint('published_at: "${jsonResponse['published_at']}"');
        debugPrint('assets count: ${jsonResponse['assets']?.length ?? 0}');
        debugPrint('download URL: $assetDownloadUrl');
        debugPrint('asset name: $foundAssetName');
        debugPrint('==========================');        return EnhancedAppUpdateInfo(
          version: cleanVersion,
          releaseNotes: jsonResponse['body'],
          releaseDate: releaseDateTime,
          downloadUrl: assetDownloadUrl,
          assetName: foundAssetName,
          fileSize: fileSize,
          releaseTag: rawTagName,
          fileName: foundAssetName ?? 'app-release.apk', // ファイル名を設定
        );
      } else {
        if (!silent) {
          debugPrint('Failed to get latest release info: ${response.statusCode} ${response.body}');
        }
        return null;
      }
    } catch (e) {
      if (!silent) {
        debugPrint('Error fetching latest release info: $e');
      }
      return null;
    }
  }

  // Enhanced platform-specific asset detection
  Map<String, dynamic>? _getPlatformSpecificAssetUrl(List<dynamic> assets) {
    String os = Platform.operatingSystem;
    List<String> prioritizedPatterns = [];

    if (os == 'android') {
      prioritizedPatterns = ['.apk'];
    } else if (os == 'windows') {
      prioritizedPatterns = ['.exe', '.msi', '.zip'];
    } else if (os == 'macos') {
      prioritizedPatterns = ['.dmg', '.zip'];
    } else if (os == 'linux') {
      prioritizedPatterns = ['.AppImage', '.deb', '.tar.gz'];
    } else if (os == 'ios') {
      prioritizedPatterns = ['.ipa'];
    }

    for (String pattern in prioritizedPatterns) {
      for (var asset in assets) {
        if (asset is Map && asset.containsKey('name') && asset.containsKey('browser_download_url')) {
          String name = asset['name'].toLowerCase();
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

    // Fallback for Linux
    if (os == 'linux') {
      for (var asset in assets) {
        if (asset is Map && asset.containsKey('name') && asset.containsKey('browser_download_url')) {
          String name = asset['name'].toLowerCase();
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
  }  // Enhanced download with streaming progress (ReVanced Manager inspired)
  // キャッシュ機能付きでダウンロード（権限不要）
  Future<String?> downloadUpdateWithProgress(EnhancedAppUpdateInfo releaseInfo) async {
    if (releaseInfo.downloadUrl == null || releaseInfo.downloadUrl!.isEmpty) {
      _updateProgress(UpdateProgress(
        progress: 0.0,
        status: 'エラー: ダウンロードURLが無効です',
        errorMessage: 'Download URL is null or empty',
      ));
      return null;
    }

    // Initialize progress stream if needed
    if (_progressController == null || _progressController!.isClosed) {
      _initializeProgressStream();
    }
      try {
      // CachedDownloadService の静的メソッドを正しく呼び出す
      final String? result = await CachedDownloadService.downloadUpdateWithCache(
        releaseInfo,
        (UpdateProgress progress) {
          // EnhancedUpdateService のストリームに進捗を中継
          debugPrint('[EnhancedUpdateService] Progress relay: ${progress.status} (${(progress.progress * 100).toStringAsFixed(1)}%)');
          _updateProgress(progress);
        },
      );
      
      if (result != null) {
        debugPrint('[EnhancedUpdateService] Update downloaded successfully to cache: $result');
      } else {
        debugPrint('[EnhancedUpdateService] Download failed, result is null');
        // エラー情報が既に onProgress で通知されていない場合のフォールバック
        if (_progressController != null && !_progressController!.isClosed) {
          _updateProgress(UpdateProgress(
            progress: 0.0,
            status: 'ダウンロードが完了しませんでした',
            errorMessage: 'Download returned null without specific error',
          ));
        }
      }
      
      return result;
    } catch (e) {
      debugPrint('[EnhancedUpdateService] Error during cache-based download: $e');
      _updateProgress(UpdateProgress(
        progress: 0.0,
        status: 'ダウンロードエラー',
        errorMessage: e.toString(),
      ));
      return null;
    }
  }

  // Startup update check (silent)
  Future<EnhancedAppUpdateInfo?> checkForUpdateOnStartup(String currentVersion, String owner, String repo) async {
    try {
      EnhancedAppUpdateInfo? releaseInfo = await getLatestReleaseInfo(owner, repo, silent: true);
      if (releaseInfo != null && isUpdateAvailable(currentVersion, releaseInfo.version)) {
        return releaseInfo;
      }
      return null;
    } catch (e) {
      // Silently fail on startup
      return null;
    }
  }
  // Request storage permission (キャッシュ使用により基本的に不要)
  // 外部ストレージに明示的に保存する場合のみ使用
  Future<bool> requestStoragePermission() async {
    // iOSでは権限不要
    if (Platform.isIOS) {
      return true;
    }

    // Androidでもアプリ内部ストレージ（キャッシュ）使用時は権限不要
    // 外部ストレージに保存する場合のみ権限が必要
    if (Platform.isAndroid) {
      // API 30+ (Android 11+) では MANAGE_EXTERNAL_STORAGE が推奨
      // しかし、アプリ内部ストレージを使用することで回避可能
      debugPrint('Storage permission check skipped - using internal app storage');
      return true; // アプリ内部ストレージを使用するため常にtrue
    }
    return true;
  }
  // 外部ストレージへの明示的な保存（ユーザーが要求した場合のみ）
  Future<String?> saveToExternalStorage(String cachedFilePath, String fileName) async {
    // この機能は現在実装されていません
    debugPrint('External storage save not implemented yet');
    return cachedFilePath; // キャッシュファイルのパスをそのまま返す
  }

  // キャッシュ管理機能
  Future<void> clearCache() async {
    // この機能は現在実装されていません
    debugPrint('Cache clear not implemented yet');
  }

  Future<void> clearExpiredCache() async {
    // この機能は現在実装されていません
    debugPrint('Expired cache clear not implemented yet');
  }

  Future<Map<String, dynamic>> getCacheStats() async {
    // この機能は現在実装されていません
    return {
      'totalSize': 0,
      'fileCount': 0,
      'lastCleanup': DateTime.now().toIso8601String(),
    };
  }

  // APKインストール用の一時ファイル処理
  Future<String?> prepareForInstallation(String cachedFilePath, String fileName) async {
    // この機能は現在実装されていません - キャッシュファイルをそのまま使用
    debugPrint('Prepare for installation: using cached file directly');
    return cachedFilePath;
  }

  // インストール後のクリーンアップ
  Future<void> cleanupAfterInstallation() async {
    // この機能は現在実装されていません
    debugPrint('Cleanup after installation not implemented yet');
  }

  // アップデート成功確認とユーザー通知機能
  
  /// アップデート試行を記録（ダウンロード開始時）
  Future<void> markUpdateAttempt(String targetVersion) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_update_version', targetVersion);
    await prefs.setInt('update_attempt_timestamp', DateTime.now().millisecondsSinceEpoch);
    debugPrint('Marked update attempt for version: $targetVersion');
  }
  
  /// アップデート完了を記録（手動インストール後の次回起動時）
  Future<void> markUpdateCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_update_version');
    await prefs.remove('update_attempt_timestamp');
    await prefs.setString('last_completed_update', await getCurrentAppVersion());
    await prefs.setInt('last_update_timestamp', DateTime.now().millisecondsSinceEpoch);
    debugPrint('Marked update as completed');
  }
  
  /// アップデート成功の確認と通知
  Future<bool> checkAndNotifyUpdateSuccess() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingVersion = prefs.getString('pending_update_version');
      final currentVersion = await getCurrentAppVersion();
      
      if (pendingVersion != null && pendingVersion == currentVersion) {
        // アップデートが成功している
        await markUpdateCompleted();
        debugPrint('Update successful: $pendingVersion → $currentVersion');
        return true;
      }
      
      // 古いpending updateが残っている場合はクリア（24時間以上経過）
      final attemptTimestamp = prefs.getInt('update_attempt_timestamp');
      if (attemptTimestamp != null) {
        final attemptTime = DateTime.fromMillisecondsSinceEpoch(attemptTimestamp);
        final elapsed = DateTime.now().difference(attemptTime);
        
        if (elapsed.inHours > 24) {
          await prefs.remove('pending_update_version');
          await prefs.remove('update_attempt_timestamp');
          debugPrint('Cleared old pending update: $pendingVersion (${elapsed.inHours} hours ago)');
        }
      }
      
      return false;
    } catch (e) {
      debugPrint('Error checking update success: $e');
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
      debugPrint('Error getting last update info: $e');
      return null;
    }
  }
  
  // インストール処理
  Future<void> installUpdate(String apkPath) async {
    try {
      final int? statusCode = await AndroidPackageInstaller.installApk(apkFilePath: apkPath);
      debugPrint('Installation status code: $statusCode');

      if (statusCode == null) {
        debugPrint('Error installing APK: status code was null');
        // 必要に応じてエラーをユーザーに通知する処理を追加できます
        return;
      }

      if (statusCode == -1) { // Androidネイティブの STATUS_PENDING_USER_ACTION
        debugPrint('APK installation pending user action. Please confirm the installation on your device.');
        // ユーザーに確認を促す通知を表示することを検討
        return;
      }

      PackageInstallerStatus installationStatus = PackageInstallerStatus.byCode(statusCode);
      debugPrint('Installation status enum: ${installationStatus.name}');

      if (installationStatus == PackageInstallerStatus.success) {
        debugPrint('APK installation process started or completed successfully.');
        // ここでユーザーに成功を通知する処理などを追加できます
      } else {
        debugPrint('Error installing APK: ${installationStatus.name} (code: $statusCode)');
        // 詳細なエラーメッセージをユーザーに表示することを検討
      }

    } catch (e) {
      debugPrint('Error during installation: $e');
      // 例外発生時のエラーハンドリング
    }
  }

  Future<void> applyUpdate(String apkPath, BuildContext context) async {
    _initializeProgressStream();
    try {
      _updateProgress(UpdateProgress(progress: 0.0, status: 'インストールの準備中...'));
      
      if (!await File(apkPath).exists()) {
        _updateProgress(UpdateProgress(
          progress: 1.0,
          status: 'エラー: APKファイルが見つかりません。',
          isCompleted: true,
          errorMessage: 'APKファイルが見つかりません: $apkPath',
        ));
        return;
      }

      _updateProgress(UpdateProgress(progress: 0.5, status: 'インストーラーを起動しています...'));

      debugPrint('Attempting to install APK at path: $apkPath');
      final int? statusCode = await AndroidPackageInstaller.installApk(apkFilePath: apkPath);

      debugPrint('Installation status code: $statusCode');

      if (statusCode == null) {
        _updateProgress(UpdateProgress(
          progress: 1.0,
          status: 'インストール状態不明',
          isCompleted: true,
          errorMessage: 'Installation status code was null.',
        ));
        return;
      }

      if (statusCode == -1) { // Androidネイティブの STATUS_PENDING_USER_ACTION
         _updateProgress(UpdateProgress(
          progress: 1.0, 
          status: 'ユーザーの操作待機中です。インストールを許可してください。',
          isCompleted: true, 
        ));
        return;
      }
      
      PackageInstallerStatus installationStatus = PackageInstallerStatus.byCode(statusCode);
      debugPrint('Installation status enum: ${installationStatus.name}');

      if (installationStatus == PackageInstallerStatus.success) {
        _updateProgress(UpdateProgress(
          progress: 1.0,
          status: 'インストール処理をシステムに委譲しました。',
          isCompleted: true,
        ));
      } else {
        String errorMessage = 'インストール開始失敗';
        // PackageInstallerStatus enum に基づいてエラーメッセージを設定
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
          case PackageInstallerStatus.unknown: // -1 は上で処理済みのため、ここは主に -2 やその他の未定義コード
            errorMessage = '不明なインストールエラーが発生しました (コード: $statusCode)';
            break;
          default: // success は上で処理済み
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
      debugPrint('Error applying update: $e');
      _updateProgress(UpdateProgress(
        progress: 1.0,
        status: 'アップデート適用中にエラーが発生しました。',
        isCompleted: true,
        errorMessage: e.toString(),
      ));
    }
  }
}
