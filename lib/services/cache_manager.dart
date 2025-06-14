import 'dart:io';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

/// キャッシュ管理サービス
/// アプリ内部ストレージを使用することで、外部ストレージ権限を不要にする
class CacheManager {
  static const String _cacheDir = 'app_cache';
  static const String _metadataFile = 'cache_metadata.json';
  static const int _maxCacheAgeHours = 24; // キャッシュの有効期限（時間）
  
  /// アプリ内部のキャッシュディレクトリを取得
  /// 権限不要で使用可能
  Future<Directory> _getCacheDirectory() async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final Directory cacheDir = Directory('${appDir.path}/$_cacheDir');
    
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    
    return cacheDir;
  }
  
  /// キャッシュメタデータファイルのパスを取得
  Future<File> _getMetadataFile() async {
    final Directory cacheDir = await _getCacheDirectory();
    return File('${cacheDir.path}/$_metadataFile');
  }
  
  /// キャッシュメタデータを読み込む
  Future<Map<String, dynamic>> _loadMetadata() async {
    try {
      final File metadataFile = await _getMetadataFile();
      if (await metadataFile.exists()) {
        final String content = await metadataFile.readAsString();
        return Map<String, dynamic>.from(jsonDecode(content));
      }
    } catch (e) {
      developer.log('Error loading cache metadata: $e', name: 'CacheManager');
    }
    return {};
  }
  
  /// キャッシュメタデータを保存
  Future<void> _saveMetadata(Map<String, dynamic> metadata) async {
    try {
      final File metadataFile = await _getMetadataFile();
      await metadataFile.writeAsString(jsonEncode(metadata));
    } catch (e) {
      developer.log('Error saving cache metadata: $e', name: 'CacheManager');
    }
  }
  
  /// URLからキャッシュキーを生成
  String _generateCacheKey(String url) {
    final bytes = utf8.encode(url);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// ファイルがキャッシュに存在するかチェック
  Future<File?> getCachedFile(String url) async {
    try {
      final String cacheKey = _generateCacheKey(url);
      final Directory cacheDir = await _getCacheDirectory();
      final File cachedFile = File('${cacheDir.path}/$cacheKey');
      
      if (await cachedFile.exists()) {
        // キャッシュの有効期限をチェック
        final Map<String, dynamic> metadata = await _loadMetadata();
        final Map<String, dynamic>? fileMetadata = metadata[cacheKey];
        
        if (fileMetadata != null) {
          final DateTime cachedAt = DateTime.parse(fileMetadata['cachedAt']);
          final DateTime expireAt = cachedAt.add(Duration(hours: _maxCacheAgeHours));
          
          if (DateTime.now().isBefore(expireAt)) {
            developer.log('Cache hit for URL: $url', name: 'CacheManager');
            return cachedFile;
          } else {
            // 期限切れのキャッシュを削除
            await _deleteCachedFile(cacheKey);
            developer.log('Cache expired for URL: $url', name: 'CacheManager');
          }
        }
      }
      
      developer.log('Cache miss for URL: $url', name: 'CacheManager');
      return null;
    } catch (e) {
      developer.log('Error checking cache for URL $url: $e', name: 'CacheManager');
      return null;
    }
  }
  
  /// ファイルをキャッシュに保存
  Future<File?> cacheFile(String url, List<int> data, {String? originalFileName}) async {
    try {
      final String cacheKey = _generateCacheKey(url);
      final Directory cacheDir = await _getCacheDirectory();
      final File cachedFile = File('${cacheDir.path}/$cacheKey');
      
      // ファイルを保存
      await cachedFile.writeAsBytes(data);
      
      // メタデータを更新
      final Map<String, dynamic> metadata = await _loadMetadata();
      metadata[cacheKey] = {
        'url': url,
        'cachedAt': DateTime.now().toIso8601String(),
        'originalFileName': originalFileName,
        'fileSize': data.length,
      };
      await _saveMetadata(metadata);
      
      developer.log('File cached successfully: $url', name: 'CacheManager');
      return cachedFile;
    } catch (e) {
      developer.log('Error caching file for URL $url: $e', name: 'CacheManager');
      return null;
    }
  }
  
  /// 特定のキャッシュファイルを削除
  Future<void> _deleteCachedFile(String cacheKey) async {
    try {
      final Directory cacheDir = await _getCacheDirectory();
      final File cachedFile = File('${cacheDir.path}/$cacheKey');
      
      if (await cachedFile.exists()) {
        await cachedFile.delete();
      }
      
      // メタデータからも削除
      final Map<String, dynamic> metadata = await _loadMetadata();
      metadata.remove(cacheKey);
      await _saveMetadata(metadata);
    } catch (e) {
      developer.log('Error deleting cached file $cacheKey: $e', name: 'CacheManager');
    }
  }
  
  /// 期限切れのキャッシュをクリア
  Future<void> clearExpiredCache() async {
    try {
      final Map<String, dynamic> metadata = await _loadMetadata();
      final DateTime now = DateTime.now();
      final List<String> expiredKeys = [];
      
      for (final String key in metadata.keys) {
        final Map<String, dynamic>? fileMetadata = metadata[key];
        if (fileMetadata != null) {
          final DateTime cachedAt = DateTime.parse(fileMetadata['cachedAt']);
          final DateTime expireAt = cachedAt.add(Duration(hours: _maxCacheAgeHours));
          
          if (now.isAfter(expireAt)) {
            expiredKeys.add(key);
          }
        }
      }
      
      // 期限切れのファイルを削除
      for (final String key in expiredKeys) {
        await _deleteCachedFile(key);
      }
      
      developer.log('Cleared ${expiredKeys.length} expired cache files', name: 'CacheManager');
    } catch (e) {
      developer.log('Error clearing expired cache: $e', name: 'CacheManager');
    }
  }
  
  /// 全キャッシュをクリア
  Future<void> clearAllCache() async {
    try {
      final Directory cacheDir = await _getCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
      developer.log('All cache cleared', name: 'CacheManager');
    } catch (e) {
      developer.log('Error clearing all cache: $e', name: 'CacheManager');
    }
  }
  
  /// キャッシュサイズを取得
  Future<int> getCacheSize() async {
    try {
      final Directory cacheDir = await _getCacheDirectory();
      if (!await cacheDir.exists()) {
        return 0;
      }
      
      int totalSize = 0;
      await for (final FileSystemEntity entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          final int fileSize = await entity.length();
          totalSize += fileSize;
        }
      }
      
      return totalSize;
    } catch (e) {
      developer.log('Error calculating cache size: $e', name: 'CacheManager');
      return 0;
    }
  }
  
  /// キャッシュ統計を取得
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final Map<String, dynamic> metadata = await _loadMetadata();
      final int cacheSize = await getCacheSize();
      final int fileCount = metadata.length;
      
      return {
        'fileCount': fileCount,
        'totalSize': cacheSize,
        'totalSizeMB': (cacheSize / (1024 * 1024)).toStringAsFixed(2),
      };
    } catch (e) {
      developer.log('Error getting cache stats: $e', name: 'CacheManager');
      return {
        'fileCount': 0,
        'totalSize': 0,
        'totalSizeMB': '0.00',
      };
    }
  }
}
