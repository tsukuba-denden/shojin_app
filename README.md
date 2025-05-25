# Shojin_App
# Shojin_App (AtCoder Practice App)

[![Latest release](https://img.shields.io/github/v/release/tsukuba-denden/Shojin_App?include_prereleases)](https://github.com/tsukuba-denden/Shojin_App/releases)
[![License](https://img.shields.io/github/license/tsukuba-denden/Shojin_App)](https://github.com/tsukuba-denden/shojin_app/tree/main?tab=MIT-1-ov-file)
[![Downloads](https://img.shields.io/github/downloads/tsukuba-denden/Shojin_App/total)](https://github.com/tsukuba-denden/Shojin_App/releases)

[<img src="https://github.com/machiav3lli/oandbackupx/blob/034b226cea5c1b30eb4f6a6f313e4dadcbb0ece4/badge_github.png"
    alt="Get it on GitHub"
    height="80">](https://github.com/tsukuba-denden/shojin_app/releases)

AtCoderの精進をスマホでも。

This app allows users to practice for AtCoder, a popular competitive programming platform from Japan. Browse contests and problems, write your solutions directly within the app using the built-in code editor, and stay engaged with your AtCoder training even on the go. Perfect for AtCoder enthusiasts who want a mobile-friendly way to hone their skills.

## 機能

*   AtCoderのコンテストや問題を閲覧。
*   アプリ内で問題文を表示（HTML/Markdown対応）。
*   シンタックスハイライト付きのアプリ内コードエディタで解答を作成。
*   問題固有情報（AtCoderのファビコン等）の取得と表示。
*   ユーザー設定の保存。
*   共有機能。
*   WebViewでのコンテンツ表示。
*   （確認中：AtCoderへ直接解答を提出）。

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

## 使用方法

1.  **アプリの起動:**
    *   インストール後、アプリアイコンをタップしてShojin_Appを起動します。

2.  **問題の検索と選択:**
    *   アプリのメイン画面（または「コンテスト一覧」画面）から参加したいコンテストを選択します。
    *   コンテスト内の問題リストから挑戦したい問題を選び、タップして問題詳細を表示します。
    *   （もし検索機能があれば）キーワードで問題を検索することも可能です。

3.  **コードの作成と編集:**
    *   問題詳細画面にある「解答する」や「エディタを開く」などのボタンをタップして、内蔵コードエディタを起動します。
    *   エディタ画面で、解答コードを入力・編集します。
    *   （もし言語選択機能があれば）使用するプログラミング言語を選択します（例：C++, Python, Javaなど）。
    *   コード作成後、保存ボタンや提出ボタン（もしあれば）をタップします。

4.  **設定の変更:**
    *   アプリ内の「設定」メニュー（通常は歯車アイコンやドロワーメニュー内にあります）から、各種設定を変更できます。
    *   例えば、エディタのテーマ、フォントサイズ、通知設定などが変更できる場合があります。

5.  **結果の確認:**
    *   （もしアプリ内で提出・採点機能がある場合）提出した解答の採点結果は、「提出履歴」画面や各問題のページで確認できる場合があります。
    *   AtCoderのウェブサイトと連携している場合、結果はウェブサイト上で確認する必要があるかもしれません。

詳細な操作方法や特定の機能については、アプリ内のヘルプやチュートリアル（もしあれば）も合わせてご確認ください。

## コントリビューション

このプロジェクトへの貢献を歓迎します！バグ報告、機能提案、プルリクエストなど、どのような形でも結構です。

### バグ報告や機能要望

*   バグ報告や機能要望は、GitHubの[Issuesページ](https://github.com/tsukuba-denden/Shojin_App/issues)を利用して報告してください。
*   報告の際は、できるだけ詳細な情報（再現手順、期待される動作、実際の動作、スクリーンショットなど）を提供していただけると助かります。

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
    変更が完了したら、フォークしたリポジトリから本リポジトリの`main`ブランチ（または適切なブランチ）に対してプルリクエストを作成します。
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
