# Shojin_App

[![Latest release](https://img.shields.io/github/v/release/tsukuba-denden/Shojin_App?include_prereleases)](https://github.com/tsukuba-denden/Shojin_App/releases)
[![License](https://img.shields.io/github/license/tsukuba-denden/Shojin_App)](https://github.com/tsukuba-denden/shojin_app/tree/main?tab=MIT-1-ov-file)
[![Downloads](https://img.shields.io/github/downloads/tsukuba-denden/Shojin_App/total)](https://github.com/tsukuba-denden/Shojin_App/releases)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/tsukuba-denden/shojin_app)
[![GitHub Stars](https://img.shields.io/github/stars/tsukuba-denden/shojin_app)](https://github.com/tsukuba-denden/shojin_app)
![code-size](https://img.shields.io/github/languages/code-size/yuubinnkyoku/yuubinnkyoku.github.io)


[<img src="https://github.com/machiav3lli/oandbackupx/blob/034b226cea5c1b30eb4f6a6f313e4dadcbb0ece4/badge_github.png"
    alt="Get it on GitHub"
    height="80">](https://github.com/tsukuba-denden/shojin_app/releases)

AtCoderの精進をスマホでも。

## 機能

### 🌐 ブラウザ機能
- **AtCoder問題サイトの閲覧**: NoviSteps、AtCoder Problemsなど、精進に役立つサイトを統合ブラウザで閲覧
- **カスタムサイト追加**: お気に入りの問題集サイトを追加して、ワンタップでアクセス
- **問題へのスムーズな遷移**: AtCoder問題ページから直接エディタ画面に移動

### 📝 コードエディタ
- **シンタックスハイライト**: Python、C++、Rust、Javaに対応した見やすいコードハイライト
- **テンプレート機能**: 言語別のコードテンプレートをカスタマイズ可能
- **自動保存**: 問題ごと・言語ごとにコードを自動保存
- **リアルタイム実行**: Wandbox APIを使用してコードをその場で実行・テスト

### 🧪 テスト機能
- **サンプルケース自動テスト**: AtCoderのサンプル入出力でコードを自動テスト
- **詳細な結果表示**: AC/WA/RE/TLE/CEなど、詳細なジャッジ結果を表示
- **デバッグ支援**: 入力・期待される出力・実際の出力を比較表示

### 📋 問題管理
- **問題詳細表示**: 問題文、制約、入出力形式を見やすく整理
- **URL自動解析**: AtCoder問題URLから問題情報を自動取得
(- **LaTeX記法対応**: 数式表示を含む問題文の適切な表示)

### 🎨 カスタマイズ
- **テーマ選択**: ライト/ダーク/ピュアブラック/システム追従の4つのテーマ
- **Material You対応**: Android 12+の壁紙連動カラーテーマ
- **透明度調整**: ナビゲーションバーの透明度をカスタマイズ可能

### 🚀 提出機能
(- **WebView提出**: AtCoderの提出ページをアプリ内で開き、コードを自動入力)
(- **言語自動選択**: 選択中の言語に応じて提出言語を自動設定)

### 📱 モバイル最適化
- **レスポンシブデザイン**: スマートフォンでの操作に最適化されたUI
- **触覚フィードバック**: ボタン操作時の触覚フィードバック
- **高速起動**: アプリの高速起動とスムーズな画面遷移

## インストール

### GitHubリリーズから

ビルド済みのバイナリ（APKなど）は[GitHubリリーズページ](https://github.com/tsukuba-denden/Shojin_App/releases)からダウンロードできます。これが最も簡単な開始方法です。

### ソースからビルド

自身でアプリをビルドしたい場合や、開発に貢献したい場合は、ソースからビルドできます：

1.  **Flutter開発環境のセットアップ:**
    まず、Flutter開発環境がセットアップされていることを確認してください。まだの場合は、[Flutter公式インストールガイド](https://flutter.dev/docs/get-started/install)に従ってください。
2.  **リポジトリをクローン:**
    ```bash
    git clone https://github.com/tsukuba-denden/Shojin_App.git
    ```
3.  **プロジェクトディレクトリに移動:**
    ```bash
    cd Shojin_App
    ```
4.  **依存関係を取得:**
    ```bash
    flutter pub get
    ```
5.  **アプリをビルドして実行:**
    *   デバッグモードで実行:
        ```bash
        flutter run
        ```
    *   リリースAPKをビルド (Android):
        ```bash
        flutter build apk --release
        ```
    *   その他のプラットフォームやビルドオプションについては、[Flutter公式ビルドドキュメント](https://flutter.dev/docs/deployment)を参照してください。

## コントリビューション

このプロジェクトへの貢献を歓迎します！バグ報告、機能提案、プルリクエストなど、どのような形でも結構です。

### バグ報告や機能要望

*   バグ報告や機能要望は、GitHubの[Issuesページ](https://github.com/tsukuba-denden/Shojin_App/issues)を利用して報告してください。

### 開発への参加

1.  **リポジトリをフォーク:**
    ご自身のGitHubアカウントにこのリポジトリをフォークします。
2.  **ブランチを作成:**
    変更内容に応じたブランチを作成します。
    ```bash
    # 機能追加の場合
    git checkout -b feature/your-feature-name
    # バグ修正の場合
    git checkout -b bugfix/issue-number
    ```
3.  **変更とコミット:**
    コードの変更を行い、分かりやすいコミットメッセージと共にコミットします。
4.  **プルリクエストを作成:**
    変更が完了したら、フォークしたリポジトリから本リポジトリの`dev`ブランチに対してプルリクエストを作成します。
    プルリクエストには、以下の情報を含めてください：
    *   変更内容の概要
    *   変更の理由や目的
    *   関連するIssue番号（もしあれば）

### コーディングスタイル

*   可能な限り、既存のコードスタイルや規約に従ってください。
*   コードを追加・修正した場合は、`flutter analyze` を実行して、静的解析エラーや警告がないことを確認してください。
*   関連するテストコードが存在する場合は更新し、新しい機能にはテストコードを追加することを推奨します。

ご協力ありがとうございます！

## ライセンス

このプロジェクトはMITライセンスのもとで公開されています。詳細については、リポジトリ内の[LICENSE](LICENSE)ファイルをご覧ください。

## 参考にしたリポジトリ
https://github.com/inotia00/revanced-manager

## 免責事項

本プロジェクトおよびその内容は、AtCoder株式会社及びその関連会社とは一切関係がなく、資金提供、承認、支持、またはその他いかなる形での関連もありません。
本プロジェクトで使用されている商標、サービスマーク、商号、またはその他の知的財産権は、それぞれの所有者に帰属します。
