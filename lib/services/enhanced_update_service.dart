import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cached_download_service.dart'; // キャッシュ機能付きダウンロードサービスをインポート
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

// Enhanced AppUpdateInfo with more details
class EnhancedAppUpdateInfo {
  final String version;
  final String? releaseNotes;
  final String? downloadUrl;
  final DateTime? releaseDate;
  final String? assetName;
  final int? fileSize;
  final String? releaseTag;

  EnhancedAppUpdateInfo({
    required this.version,
    this.releaseNotes,
    this.downloadUrl,
    this.releaseDate,
    this.assetName,
    this.fileSize,
    this.releaseTag,
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
  
  // キャッシュ機能付きダウンロードサービス
  final CachedDownloadService _cachedDownloadService = CachedDownloadService();
  
  Stream<UpdateProgress>? get progressStream => _progressController?.stream;
  
  // Create progress stream
  void _initializeProgressStream() {
    _progressController = StreamController<UpdateProgress>.broadcast();
  }
  
  // Update progress
  void _updateProgress(UpdateProgress progress) {
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
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
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
        debugPrint('==========================');

        return EnhancedAppUpdateInfo(
          version: cleanVersion,
          releaseNotes: jsonResponse['body'],
          releaseDate: releaseDateTime,
          downloadUrl: assetDownloadUrl,
          assetName: foundAssetName,
          fileSize: fileSize,
          releaseTag: rawTagName,
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

    // Initialize progress stream
    _initializeProgressStream();
    
    try {
      // キャッシュ機能付きダウンロードサービスを使用（権限不要）
      // プログレスの同期を設定
      late StreamSubscription progressSubscription;
      progressSubscription = _cachedDownloadService.progressStream?.listen((progress) {
        _updateProgress(progress);
      }) ?? const Stream.empty().listen((_) {});
      
      debugPrint('Starting cache-based download for: ${releaseInfo.downloadUrl}');
      final String? result = await _cachedDownloadService.downloadUpdateWithCache(releaseInfo);
      
      // プログレス監視を停止
      progressSubscription.cancel();
      
      if (result != null) {
        debugPrint('Update downloaded successfully to cache: $result');
        _updateProgress(UpdateProgress(
          progress: 1.0,
          status: 'ダウンロード完了（キャッシュ使用）',
          isCompleted: true,
        ));
      }
      
      return result;
    } catch (e) {
      debugPrint('Error during cache-based download: $e');
      _updateProgress(UpdateProgress(
        progress: 0.0,
        status: 'ダウンロードエラー',
        errorMessage: e.toString(),
      ));
      return null;
    } finally {
      _cachedDownloadService.disposeProgressStream();
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
    return await _cachedDownloadService.saveToExternalStorage(cachedFilePath, fileName);
  }

  // キャッシュ管理機能
  Future<void> clearCache() async {
    await _cachedDownloadService.clearCache();
    debugPrint('Update cache cleared');
  }

  Future<void> clearExpiredCache() async {
    await _cachedDownloadService.clearExpiredCache();
    debugPrint('Expired update cache cleared');
  }

  Future<Map<String, dynamic>> getCacheStats() async {
    return await _cachedDownloadService.getCacheStats();
  }

  // APKインストール用の一時ファイル処理
  Future<String?> prepareForInstallation(String cachedFilePath, String fileName) async {
    return await _cachedDownloadService.copyToInstallableLocation(cachedFilePath, fileName);
  }

  // インストール後のクリーンアップ
  Future<void> cleanupAfterInstallation() async {
    await _cachedDownloadService.cleanupInstallFiles();
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
      // ダウンロードしたAPKファイルを開く
      final OpenResult openResult = await OpenFile.open(apkPath);

      if (openResult.type != ResultType.done) {
        // エラー処理: ファイルを開けなかった場合
        print('Error opening APK file: ${openResult.message}');
        // 必要に応じてユーザーにエラーを通知
        return; // または適切なエラーハンドリング
      }

      // インストールが開始されたことをユーザーに通知（任意）
      print('APK installation process started.');

    } catch (e) {
      debugPrint('Error during installation: $e');
    }
  }

  Future<void> applyUpdate(String apkPath, BuildContext context) async {
    _initializeProgressStream();
    try {
      _updateProgress(UpdateProgress(progress: 0.0, status: 'インストールの準備中...'));

      // REQUEST_INSTALL_PACKAGES 権限の確認と要求
      var status = await Permission.requestInstallPackages.status;
      if (status.isDenied) {
        // 権限が拒否されている場合は要求する
        status = await Permission.requestInstallPackages.request();
        if (status.isDenied) {
          _updateProgress(UpdateProgress(
            progress: 1.0,
            status: 'インストール権限がありません。設定から許可してください。',
            isCompleted: true,
            errorMessage: 'インストール権限が拒否されました。',
          ));
          // ユーザーに設定画面を開くよう促すなどの対応
          // 例: openAppSettings();
          return;
        }
      }
      
      if (!await File(apkPath).exists()) {
        _updateProgress(UpdateProgress(
          progress: 1.0,
          status: 'エラー: APKファイルが見つかりません。',
          isCompleted: true,
          errorMessage: 'APKファイルが見つかりません: $apkPath',
        ));
        return;
      }

      _updateProgress(UpdateProgress(progress: 1.0, status: 'インストーラーを起動しています...'));

      debugPrint('Attempting to open APK at path: $apkPath');
      final OpenResult openResult = await OpenFile.open(apkPath);

      debugPrint('OpenFile result type: ${openResult.type}');
      debugPrint('OpenFile result message: ${openResult.message}');

      if (openResult.type == ResultType.done) {
        _updateProgress(UpdateProgress(
          progress: 1.0,
          status: 'インストール処理を開始しました。',
          isCompleted: true,
        ));
      } else if (openResult.type == ResultType.noAppToOpen) {
        // APKファイルを開けるアプリがない場合 (通常Androidでは発生しにくい)
         _updateProgress(UpdateProgress(
          progress: 1.0,
          status: 'エラー: APKファイルを開けるアプリが見つかりません。',
          isCompleted: true,
          errorMessage: 'No app to open APK: ${openResult.message}',
        ));
      } else {
        _updateProgress(UpdateProgress(
          progress: 1.0,
          status: 'インストール開始失敗: ${openResult.message}',
          isCompleted: true,
          errorMessage: openResult.message,
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
