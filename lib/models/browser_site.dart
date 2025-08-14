// filepath: d:\GitHub_yuubinnkyoku\shojin_app\lib\models\browser_site.dart

/// ブラウザで表示するサイトの情報を保持するモデル
class BrowserSite {
  final String title;
  final String url;
  final String? faviconUrl;
  final String? colorHex;

  const BrowserSite({
    required this.title,
    required this.url,
    this.faviconUrl,
    this.colorHex,
  });

  /// JSONからBrowserSiteを作成
  factory BrowserSite.fromJson(Map<String, dynamic> json) {
    return BrowserSite(
      title: json['title'] as String,
      url: json['url'] as String,
      faviconUrl: json['faviconUrl'] as String?,
      colorHex: json['colorHex'] as String?,
    );
  }

  /// BrowserSiteをJSONに変換
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'url': url,
      'faviconUrl': faviconUrl,
      'colorHex': colorHex,
    };
  }

  /// 古い形式のMapからBrowserSiteを作成
  factory BrowserSite.fromLegacyMap(Map<String, String?> map) {
    return BrowserSite(
      title: map['title'] ?? '',
      url: map['url'] ?? '',
      faviconUrl: map['faviconUrl'],
      colorHex: map['colorHex'],
    );
  }

  /// メタデータを更新した新しいインスタンスを作成
  BrowserSite copyWithMetadata({String? faviconUrl, String? colorHex}) {
    return BrowserSite(
      title: title,
      url: url,
      faviconUrl: faviconUrl ?? this.faviconUrl,
      colorHex: colorHex ?? this.colorHex,
    );
  }

  /// 全フィールドを更新可能なcopyWithメソッド
  BrowserSite copyWith({
    String? title,
    String? url,
    String? faviconUrl,
    String? colorHex,
  }) {
    return BrowserSite(
      title: title ?? this.title,
      url: url ?? this.url,
      faviconUrl: faviconUrl ?? this.faviconUrl,
      colorHex: colorHex ?? this.colorHex,
    );
  }

  /// メタデータが不足しているかどうか
  bool get needsMetadata => faviconUrl == null || colorHex == null;

  /// URLのベースを取得
  String? get baseUrl {
    final uri = Uri.tryParse(url);
    return uri?.origin;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BrowserSite &&
        other.title == title &&
        other.url == url &&
        other.faviconUrl == faviconUrl &&
        other.colorHex == colorHex;
  }

  @override
  int get hashCode {
    return Object.hash(title, url, faviconUrl, colorHex);
  }

  @override
  String toString() {
    return 'BrowserSite(title: $title, url: $url, faviconUrl: $faviconUrl, colorHex: $colorHex)';
  }
}
