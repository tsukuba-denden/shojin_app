import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

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
  }

  // Enhanced download with streaming progress (ReVanced Manager inspired)
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
    
    _updateProgress(UpdateProgress(
      progress: 0.0,
      status: 'ダウンロードを開始しています...',
    ));

    final httpClient = http.Client();
    try {
      final Uri downloadUri = Uri.parse(releaseInfo.downloadUrl!);
      final request = http.Request('GET', downloadUri);
      final http.StreamedResponse response = await httpClient.send(request);

      if (response.statusCode != 200) {
        _updateProgress(UpdateProgress(
          progress: 0.0,
          status: 'ダウンロードエラー: ${response.statusCode}',
          errorMessage: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        ));
        return null;
      }

      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = releaseInfo.assetName ?? Uri.parse(releaseInfo.downloadUrl!).pathSegments.last;
      final String localFilePath = '${tempDir.path}${Platform.pathSeparator}$fileName';
      final File file = File(localFilePath);
      final IOSink sink = file.openWrite();

      int bytesReceived = 0;
      final int? totalLength = response.contentLength ?? releaseInfo.fileSize;

      _updateProgress(UpdateProgress(
        progress: 0.0,
        status: 'ダウンロード中...',
        bytesDownloaded: 0,
        totalBytes: totalLength,
      ));

      await response.stream.listen((List<int> chunk) {
        sink.add(chunk);
        bytesReceived += chunk.length;
        
        if (totalLength != null && totalLength > 0) {
          double currentProgress = bytesReceived / totalLength;
          _updateProgress(UpdateProgress(
            progress: currentProgress,
            status: 'ダウンロード中...',
            bytesDownloaded: bytesReceived,
            totalBytes: totalLength,
          ));
        } else {
          _updateProgress(UpdateProgress(
            progress: -1, // Indeterminate progress
            status: 'ダウンロード中...',
            bytesDownloaded: bytesReceived,
            totalBytes: null,
          ));
        }
      }).asFuture();

      await sink.flush();
      await sink.close();
      
      _updateProgress(UpdateProgress(
        progress: 1.0,
        status: 'ダウンロード完了',
        bytesDownloaded: bytesReceived,
        totalBytes: totalLength,
        isCompleted: true,
      ));

      debugPrint('Update downloaded to: $localFilePath');
      return localFilePath;

    } catch (e) {
      _updateProgress(UpdateProgress(
        progress: 0.0,
        status: 'ダウンロードエラー',
        errorMessage: e.toString(),
      ));
      debugPrint('Error during download update: $e');
      return null;
    } finally {
      httpClient.close();
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

  // Request storage permission
  Future<bool> requestStoragePermission() async {
    if (Platform.isIOS) {
      return true;
    }

    if (Platform.isAndroid) {
      PermissionStatus status = await Permission.storage.status;
      debugPrint('Current storage permission status: $status');
      if (status.isGranted) {
        return true;
      } else {
        status = await Permission.storage.request();
        debugPrint('Storage permission status after request: $status');
        return status.isGranted;
      }
    }
    return true;
  }
}
