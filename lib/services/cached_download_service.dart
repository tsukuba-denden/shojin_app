import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/enhanced_update_service.dart'; // For UpdateProgress and EnhancedAppUpdateInfo types

/// キャッシュ機能付きダウンロードサービス
class CachedDownloadService {
  static const String _downloadAttemptsKey = 'download_attempts';
  static const String _lastDownloadTimeKey = 'last_download_time';
  
  /// アップデートファイルをダウンロード（キャッシュ機能付き）
  static Future<String?> downloadWithProgress(
    String downloadUrl,
    String fileName,
    Function(double progress) onProgress,
  ) async {
    if (downloadUrl.isEmpty) {
      developer.log('Error: Download URL is empty', name: 'CachedDownloadService');
      return null;
    }

    final httpClient = http.Client();
    try {
      developer.log('Starting download: $downloadUrl', name: 'CachedDownloadService');
      
      // Create download request
      final Uri downloadUri = Uri.parse(downloadUrl);
      final request = http.Request('GET', downloadUri);
      final http.StreamedResponse response = await httpClient.send(request);

      if (response.statusCode != 200) {
        developer.log('Download failed: ${response.statusCode} ${response.reasonPhrase}', 
                      name: 'CachedDownloadService');
        return null;
      }

      // Get cache file path
      final File cacheFile = await _getCacheFile(fileName);
      developer.log('Downloading to cache: ${cacheFile.path}', name: 'CachedDownloadService');

      // Ensure parent directory exists
      await cacheFile.parent.create(recursive: true);

      // Start download with progress tracking
      final IOSink sink = cacheFile.openWrite();
      int bytesReceived = 0;
      final int? totalLength = response.contentLength;

      // Report initial progress (0%)
      onProgress(0.0);

      try {
        await response.stream.listen((List<int> chunk) {
          sink.add(chunk);
          bytesReceived += chunk.length;
          
          // Calculate and report progress
          if (totalLength != null && totalLength > 0) {
            double currentProgress = bytesReceived / totalLength;
            // Ensure progress doesn't exceed 0.99 until file is fully written
            onProgress(currentProgress.clamp(0.0, 0.99));
          } else {
            // For unknown content length, report intermediate progress
            onProgress(-1);
          }
        }).asFuture();

        // Ensure all data is written to disk
        await sink.flush();
        await sink.close();

        // Verify file exists and has expected size
        if (await cacheFile.exists()) {
          final fileSize = await cacheFile.length();
          developer.log('Download completed. File size: $fileSize bytes', 
                        name: 'CachedDownloadService');
          
          // Only now report 100% completion
          onProgress(1.0);
          
          // Record successful download
          await _recordDownloadSuccess();
          
          return cacheFile.path;
        } else {
          throw Exception('Downloaded file does not exist');
        }

      } catch (e) {
        // Clean up on error
        await sink.close();
        if (await cacheFile.exists()) {
          await cacheFile.delete();
        }
        rethrow;
      }

    } catch (e) {
      developer.log('Download error: $e', name: 'CachedDownloadService');
      await _recordDownloadFailure();
      return null;
    } finally {
      httpClient.close();
    }
  }

  /// キャッシュされたファイルの取得
  static Future<String?> getCachedFile(String fileName) async {
    try {
      final File cacheFile = await _getCacheFile(fileName);
      if (await cacheFile.exists()) {
        developer.log('Found cached file: ${cacheFile.path}', name: 'CachedDownloadService');
        return cacheFile.path;
      }
      return null;
    } catch (e) {
      developer.log('Error checking cache: $e', name: 'CachedDownloadService');
      return null;
    }
  }

  /// キャッシュファイルのパスを取得
  static Future<File> _getCacheFile(String fileName) async {
    final Directory tempDir = await getTemporaryDirectory();
    return File('${tempDir.path}/$fileName');
  }

  /// ダウンロード成功を記録
  static Future<void> _recordDownloadSuccess() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastDownloadTimeKey, DateTime.now().millisecondsSinceEpoch);
      developer.log('Download success recorded', name: 'CachedDownloadService');
    } catch (e) {
      developer.log('Error recording download success: $e', name: 'CachedDownloadService');
    }
  }

  /// ダウンロード失敗を記録
  static Future<void> _recordDownloadFailure() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final attempts = prefs.getInt(_downloadAttemptsKey) ?? 0;
      await prefs.setInt(_downloadAttemptsKey, attempts + 1);
      developer.log('Download failure recorded. Total attempts: ${attempts + 1}', 
                    name: 'CachedDownloadService');
    } catch (e) {
      developer.log('Error recording download failure: $e', name: 'CachedDownloadService');
    }
  }

  /// ダウンロード試行回数の取得
  static Future<int> getDownloadAttempts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_downloadAttemptsKey) ?? 0;
    } catch (e) {
      developer.log('Error getting download attempts: $e', name: 'CachedDownloadService');
      return 0;
    }
  }

  /// 最後のダウンロード時刻の取得
  static Future<DateTime?> getLastDownloadTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_lastDownloadTimeKey);
      return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
    } catch (e) {
      developer.log('Error getting last download time: $e', name: 'CachedDownloadService');
      return null;
    }
  }

  /// 統計情報のリセット
  static Future<void> resetDownloadStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_downloadAttemptsKey);
      await prefs.remove(_lastDownloadTimeKey);
      developer.log('Download stats reset', name: 'CachedDownloadService');
    } catch (e) {
      developer.log('Error resetting download stats: $e', name: 'CachedDownloadService');
    }
  }
  /// アップデートファイルをダウンロード（EnhancedAppUpdateInfo対応）
  static Future<String?> downloadUpdateWithCache(
    EnhancedAppUpdateInfo updateInfo,
    Function(UpdateProgress progress) onProgress,
  ) async {
    final String? downloadUrl = updateInfo.downloadUrl;
    final String fileName = updateInfo.fileName;

    if (downloadUrl == null || downloadUrl.isEmpty) {
      developer.log('Error: Download URL is empty or null', name: 'CachedDownloadService');
      return null;
    }

    final httpClient = http.Client();
    try {
      developer.log('Starting update download: $downloadUrl', name: 'CachedDownloadService');
      
      // Create download request
      final Uri downloadUri = Uri.parse(downloadUrl);
      final request = http.Request('GET', downloadUri);
      final http.StreamedResponse response = await httpClient.send(request);

      if (response.statusCode != 200) {
        developer.log('Update download failed: ${response.statusCode} ${response.reasonPhrase}', 
                      name: 'CachedDownloadService');
        return null;
      }

      // Get cache file path
      final File cacheFile = await _getCacheFile(fileName);
      developer.log('Downloading update to cache: ${cacheFile.path}', name: 'CachedDownloadService');

      // Ensure parent directory exists
      await cacheFile.parent.create(recursive: true);

      // Start download with progress tracking
      final IOSink sink = cacheFile.openWrite();
      int bytesReceived = 0;
      final int? totalLength = response.contentLength;      // Report initial progress
      onProgress(UpdateProgress(progress: 0.0, status: 'ダウンロード開始中'));

      try {
        await response.stream.listen((List<int> chunk) {
          sink.add(chunk);
          bytesReceived += chunk.length;
          
          // Calculate and report progress
          if (totalLength != null && totalLength > 0) {
            double currentProgress = bytesReceived / totalLength;
            // Ensure progress doesn't exceed 0.99 until file is fully written
            onProgress(UpdateProgress(
              progress: currentProgress.clamp(0.0, 0.99), 
              status: 'ダウンロード中', 
              bytesDownloaded: bytesReceived,
              totalBytes: totalLength
            ));
          } else {
            // For unknown content length, report intermediate progress
            onProgress(UpdateProgress(
              progress: 0.5, 
              status: 'ダウンロード中', 
              bytesDownloaded: bytesReceived
            ));
          }
        }).asFuture();

        // Ensure all data is written to disk
        await sink.flush();
        await sink.close();

        // Verify file exists and has expected size
        if (await cacheFile.exists()) {
          final fileSize = await cacheFile.length();
          developer.log('Update download completed. File size: $fileSize bytes', 
                        name: 'CachedDownloadService');
          
          // Only now report 100% completion
          onProgress(UpdateProgress(
            progress: 1.0, 
            status: 'ダウンロード完了', 
            bytesDownloaded: fileSize,
            totalBytes: totalLength ?? fileSize,
            isCompleted: true
          ));
          
          // Record successful download
          await _recordDownloadSuccess();
          
          return cacheFile.path;
        } else {
          throw Exception('Downloaded update file does not exist');
        }

      } catch (e) {
        // Clean up on error
        await sink.close();
        if (await cacheFile.exists()) {
          await cacheFile.delete();
        }
        rethrow;
      }

    } catch (e) {
      developer.log('Update download error: $e', name: 'CachedDownloadService');
      await _recordDownloadFailure();
      return null;
    } finally {
      httpClient.close();
    }
  }
}
