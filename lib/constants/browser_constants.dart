import 'package:flutter/material.dart';
import '../services/browser_site_service.dart';

/// ブラウザ画面で使用する定数
class BrowserConstants {
  // デフォルトサイト
  static const List<DefaultSite> defaultSites = [
    DefaultSite(
      title: 'NoviSteps',
      url: 'https://atcoder-novisteps.vercel.app/problems',
      faviconUrl: 'https://raw.githubusercontent.com/AtCoder-NoviSteps/AtCoderNoviSteps/staging/static/favicon.png',
      colorHex: '#48955D',
    ),
    DefaultSite(
      title: 'Problems',
      url: 'https://kenkoooo.com/atcoder/#/table/',
      faviconUrl: 'https://github.com/kenkoooo/AtCoderProblems/raw/refs/heads/master/atcoder-problems-frontend/public/favicon.ico',
      colorHex: '#66C84D',
    ),
  ];

  // UI関連の定数
  static const double siteButtonHeight = 60.0;
  static const double buttonPadding = 4.0;
  static const double buttonVerticalPadding = 8.0;
  static const double buttonInternalPadding = 12.0;
  static const double buttonInternalVerticalPadding = 8.0;
  static const double buttonBorderRadius = 16.0;
  static const double buttonElevation = 1.0;
  
  static const double faviconSize = 20.0;
  static const double faviconBorderWidth = 1.0;
  static const double iconSize = 18.0;
  static const double iconSpacing = 8.0;
  
  static const double progressIndicatorStrokeWidth = 2.0;
  static const double horizontalPadding = 8.0;

  // AtCoder関連
  static const String atcoderHost = 'atcoder.jp';
  static const List<String> atcoderProblemPathSegments = ['contests', 'tasks'];
  static const int atcoderProblemPathLength = 4;
  static const int atcoderContestIndex = 0;
  static const int atcoderTasksIndex = 2;
  static const int atcoderProblemIndex = 3;

  // エラーメッセージ
  static const String errorPageLoadFailed = 'ページを読み込めませんでした';
  static const String buttonRetry = '再試行';
  static const String dialogAddSite = 'サイトを追加';
  static const String dialogEditSite = 'サイトを編集';
  static const String dialogRemoveSite = 'サイトを削除';
  static const String labelTitle = 'タイトル';
  static const String labelUrl = 'URL';
  static const String buttonCancel = 'キャンセル';
  static const String buttonAdd = '追加';
  static const String buttonUpdate = '更新';
  static const String buttonDelete = '削除';
  
  static const String errorTitleUrlRequired = 'タイトルとURLを入力してください。';
  static const String errorInvalidUrl = '有効なURLを入力してください (例: https://example.com)';
  static const String errorSiteAlreadyExists = 'は既に追加されています。';
  static const String errorFetchingMetadata = 'サイトメタデータの取得に失敗しました: ';
  
  static const String confirmRemoveSite = 'を削除しますか？';
}

/// カラーユーティリティ
class BrowserColorUtils {
  /// 背景色に基づいてテキスト色を決定
  static Color getTextColorForBackground(Color backgroundColor) {
    return ThemeData.estimateBrightnessForColor(backgroundColor) == Brightness.dark
        ? Colors.white
        : Colors.black;
  }

  /// 16進数カラーコードを解析
  static Color? parseColorHex(String? colorHex) {
    if (colorHex == null) return null;
    
    try {
      String hex = colorHex.replaceFirst('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      if (hex.length == 8) {
        return Color(int.parse('0x$hex'));
      } else {
        throw const FormatException("Invalid hex color format");
      }
    } catch (e) {
      return null;
    }
  }
}
