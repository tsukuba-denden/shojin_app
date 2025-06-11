import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'cache_manager.dart';
import 'enhanced_update_service.dart';

/// キャッシュ機能付きダウンロードサービス
/// 外部ストレージ権限が不要なダウンロード機能を提供
class CachedDownloadService {
  final CacheManager _cacheManager = CacheManager();
  
  // プログレス通知用のストリーム
  StreamController<UpdateProgress>? _progressController;
  Stream<UpdateProgress>? get progressStream => _progressController?.stream;

  void _initializeProgressStream() {
    _progressController = StreamController<UpdateProgress>.broadcast();
  }

  void _updateProgress(UpdateProgress progress) {
    _progressController?.add(progress);
  }

  void disposeProgressStream() {
    _progressController?.close();
    _progressController = null;
  }

  /// ファイルをダウンロード（キャッシュファーストアプローチ）
  /// 1. まずキャッシュをチェック
  /// 2. キャッシュにない場合のみダウンロード
  /// 3. アプリ内部ストレージを使用（権限不要）
  Future<String?> downloadWithCache(
    String url, {
    String? fileName,
    bool forceDownload = false,
    Function(UpdateProgress)? onProgress,
  }) async {
    try {
      _initializeProgressStream();
      
      // 強制ダウンロードでない場合、まずキャッシュをチェック
      if (!forceDownload) {
        final File? cachedFile = await _cacheManager.getCachedFile(url);
        if (cachedFile != null) {
          developer.log('Using cached file for URL: $url', name: 'CachedDownloadService');
          
          _updateProgress(UpdateProgress(
            progress: 1.0,
            status: 'キャッシュから取得完了',
            isCompleted: true,
          ));
          
          return cachedFile.path;
        }
      }

      // キャッシュにない場合、新規ダウンロード
      return await _downloadAndCache(url, fileName: fileName, onProgress: onProgress);
      
    } catch (e) {
      developer.log('Error in downloadWithCache: $e', name: 'CachedDownloadService');
      _updateProgress(UpdateProgress(
        progress: 0.0,
        status: 'ダウンロードエラー',
        errorMessage: e.toString(),
      ));
      return null;
    }
  }

  /// ファイルをダウンロードしてキャッシュに保存
  Future<String?> _downloadAndCache(
    String url, {
    String? fileName,
    Function(UpdateProgress)? onProgress,
  }) async {
    final httpClient = http.Client();
    
    try {
      _updateProgress(UpdateProgress(
        progress: 0.0,
        status: 'ダウンロード開始...',
      ));

      final Uri downloadUri = Uri.parse(url);
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

      // ファイル名を決定
      final String actualFileName = fileName ?? 
          Uri.parse(url).pathSegments.last.split('?').first;

      final List<int> bytes = [];
      int bytesReceived = 0;
      final int? totalLength = response.contentLength;

      _updateProgress(UpdateProgress(
        progress: 0.0,
        status: 'ダウンロード中...',
        bytesDownloaded: 0,
        totalBytes: totalLength,
      ));

      // データを受信
      await response.stream.listen((List<int> chunk) {
        bytes.addAll(chunk);
        bytesReceived += chunk.length;
        
        if (totalLength != null && totalLength > 0) {
          final double currentProgress = bytesReceived / totalLength;
          final UpdateProgress progress = UpdateProgress(
            progress: currentProgress,
            status: 'ダウンロード中...',
            bytesDownloaded: bytesReceived,
            totalBytes: totalLength,
          );
          
          _updateProgress(progress);
          onProgress?.call(progress);
        } else {
          final UpdateProgress progress = UpdateProgress(
            progress: -1, // 不定プログレス
            status: 'ダウンロード中...',
            bytesDownloaded: bytesReceived,
            totalBytes: null,
          );
          
          _updateProgress(progress);
          onProgress?.call(progress);
        }
      }).asFuture();

      // キャッシュに保存
      final File? cachedFile = await _cacheManager.cacheFile(
        url, 
        bytes, 
        originalFileName: actualFileName,
      );

      if (cachedFile != null) {
        _updateProgress(UpdateProgress(
          progress: 1.0,
          status: 'ダウンロード完了',
          bytesDownloaded: bytesReceived,
          totalBytes: totalLength,
          isCompleted: true,
        ));

        developer.log('File downloaded and cached: ${cachedFile.path}', name: 'CachedDownloadService');
        return cachedFile.path;
      } else {
        throw Exception('Failed to cache downloaded file');
      }

    } catch (e) {
      _updateProgress(UpdateProgress(
        progress: 0.0,
        status: 'ダウンロードエラー',
        errorMessage: e.toString(),
      ));
      developer.log('Error during download: $e', name: 'CachedDownloadService');
      return null;
    } finally {
      httpClient.close();
    }
  }

  /// アップデート用の特別なダウンロードメソッド
  /// 既存のEnhancedUpdateServiceとの互換性を保つ
  Future<String?> downloadUpdateWithCache(EnhancedAppUpdateInfo updateInfo) async {
    if (updateInfo.downloadUrl == null || updateInfo.downloadUrl!.isEmpty) {
      _updateProgress(UpdateProgress(
        progress: 0.0,
        status: 'エラー: ダウンロードURLが無効です',
        errorMessage: 'Download URL is null or empty',
      ));
      return null;
    }

    return await downloadWithCache(
      updateInfo.downloadUrl!,
      fileName: updateInfo.assetName,
      forceDownload: true, // アップデートは常に最新版をダウンロード
    );
  }

  /// 外部ストレージへの保存（ユーザーが明示的に要求した場合のみ）
  Future<String?> saveToExternalStorage(String cachedFilePath, String fileName) async {
    try {
      // Androidでのみ権限チェック
      if (Platform.isAndroid) {
        final PermissionStatus permission = await Permission.storage.request();
        if (!permission.isGranted) {
          throw Exception('外部ストレージへの書き込み権限が必要です');
        }
      }

      // 外部ストレージのDownloadsフォルダに保存
      Directory? downloadsDir;
      
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
      } else if (Platform.isIOS) {
        downloadsDir = await getApplicationDocumentsDirectory();
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir == null || !await downloadsDir.exists()) {
        throw Exception('ダウンロードディレクトリが見つかりません');
      }

      final File cachedFile = File(cachedFilePath);
      final File externalFile = File('${downloadsDir.path}/$fileName');
      
      await cachedFile.copy(externalFile.path);
      
      developer.log('File saved to external storage: ${externalFile.path}', name: 'CachedDownloadService');
      return externalFile.path;
      
    } catch (e) {
      developer.log('Error saving to external storage: $e', name: 'CachedDownloadService');
      throw e;
    }
  }

  /// APKインストール用に一時的に外部ストレージにコピー
  /// Android 7.0+ (API 24+) でのFileUriExposedExceptionを回避
  Future<String?> copyToInstallableLocation(String cachedFilePath, String fileName) async {
    try {
      if (!Platform.isAndroid) {
        // Android以外はキャッシュファイルをそのまま返す
        return cachedFilePath;
      }

      // Android では /storage/emulated/0/Android/data/[package_name]/files/ に一時コピー
      // この場所は権限不要でアクセス可能
      final Directory? externalDir = await getExternalStorageDirectory();
      
      if (externalDir == null) {
        developer.log('External storage directory not available', name: 'CachedDownloadService');
        throw Exception('外部ストレージディレクトリが利用できません');
      }

      final Directory tempInstallDir = Directory('${externalDir.path}/temp_install');
      if (!await tempInstallDir.exists()) {
        await tempInstallDir.create(recursive: true);
      }

      final File cachedFile = File(cachedFilePath);
      final File installFile = File('${tempInstallDir.path}/$fileName');
      
      // 既存のファイルがあれば削除
      if (await installFile.exists()) {
        await installFile.delete();
      }
      
      // キャッシュファイルをコピー
      await cachedFile.copy(installFile.path);
      
      developer.log('File copied for installation: ${installFile.path}', name: 'CachedDownloadService');
      return installFile.path;
      
    } catch (e) {
      developer.log('Error copying file to installable location: $e', name: 'CachedDownloadService');
      throw e;
    }
  }

  /// インストール後の一時ファイルをクリーンアップ
  Future<void> cleanupInstallFiles() async {
    try {
      if (!Platform.isAndroid) return;
      
      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir == null) return;
      
      final Directory tempInstallDir = Directory('${externalDir.path}/temp_install');
      if (await tempInstallDir.exists()) {
        await tempInstallDir.delete(recursive: true);
        developer.log('Install temp files cleaned up', name: 'CachedDownloadService');
      }
    } catch (e) {
      developer.log('Error cleaning up install files: $e', name: 'CachedDownloadService');
    }
  }

  /// キャッシュクリア機能
  Future<void> clearCache() async {
    await _cacheManager.clearAllCache();
  }

  /// 期限切れキャッシュのクリア
  Future<void> clearExpiredCache() async {
    await _cacheManager.clearExpiredCache();
  }

  /// キャッシュ統計の取得
  Future<Map<String, dynamic>> getCacheStats() async {
    return await _cacheManager.getCacheStats();
  }
}
