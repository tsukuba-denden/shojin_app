import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:favicon/favicon.dart';
import '../models/browser_site.dart';
import 'image_color_extractor.dart';

/// ブラウザサイトの管理を行うサービス
class BrowserSiteService {
  static const String _storageKey = 'homeSites';

  /// サイトリストを読み込み
  static Future<List<BrowserSite>> loadSites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sitesJson = prefs.getStringList(_storageKey) ?? [];
      
      return sitesJson.map((jsonString) {
        final map = Map<String, String?>.from(jsonDecode(jsonString));
        return BrowserSite.fromLegacyMap(map);
      }).toList();
    } catch (e) {
      developer.log('Error loading sites: $e', name: 'BrowserSiteService');
      return [];
    }
  }

  /// サイトリストを保存
  static Future<void> saveSites(List<BrowserSite> sites) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sitesJson = sites.map((site) => jsonEncode(site.toJson())).toList();
      await prefs.setStringList(_storageKey, sitesJson);
    } catch (e) {
      developer.log('Error saving sites: $e', name: 'BrowserSiteService');
      rethrow;
    }
  }

  /// サイトのメタデータ（ファビコンと支配的な色）を取得
  static Future<SiteMetadata> fetchSiteMetadata(String url) async {
    String? faviconUrl;
    String? colorHex;

    try {
      // ファビコンを取得
      final icons = await FaviconFinder.getAll(url);
      if (icons.isNotEmpty) {
        faviconUrl = icons.first.url;
        developer.log('Favicon found for $url: $faviconUrl', name: 'BrowserSiteService');

        // 支配的な色を抽出
        final dominantColor = await ImageColorExtractor.extractDominantColor(faviconUrl);
        if (dominantColor != null) {
          colorHex = '#${dominantColor.value.toRadixString(16).padLeft(8, '0')}';
          developer.log('Dominant color found for $faviconUrl: $colorHex', name: 'BrowserSiteService');
        }
      } else {
        developer.log('No favicon found for $url', name: 'BrowserSiteService');
      }
    } catch (e) {
      developer.log('Error fetching metadata for $url: $e', name: 'BrowserSiteService');
    }

    return SiteMetadata(faviconUrl: faviconUrl, colorHex: colorHex);
  }

  /// URLの妥当性を検証
  static bool isValidUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }

  /// デフォルトサイトかどうかを判定
  static bool isDefaultSite(String url, List<String> defaultUrls) {
    return defaultUrls.contains(url);
  }

  /// 既存サイトとの重複をチェック
  static bool isDuplicateSite(String title, String url, List<BrowserSite> existingSites, List<DefaultSite> defaultSites) {
    // デフォルトサイトとの重複チェック
    for (final defaultSite in defaultSites) {
      if (title == defaultSite.title && url == defaultSite.url) {
        return true;
      }
    }

    // 既存サイトとの重複チェック
    for (final site in existingSites) {
      if (site.title == title && site.url == url) {
        return true;
      }
    }

    return false;
  }
}

/// サイトメタデータ
class SiteMetadata {
  final String? faviconUrl;
  final String? colorHex;

  const SiteMetadata({
    this.faviconUrl,
    this.colorHex,
  });
}

/// デフォルトサイト情報
class DefaultSite {
  final String title;
  final String url;
  final String faviconUrl;
  final String colorHex;

  const DefaultSite({
    required this.title,
    required this.url,
    required this.faviconUrl,
    required this.colorHex,
  });
}
