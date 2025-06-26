
# Geminiのためのプロジェクトガイド: shojin_app

このドキュメントは、AIアシスタントであるGeminiがこのプロジェクトの構造と規約を理解し、効果的に開発を支援するためのガイドです。

## 1. プロジェクト概要

**shojin_app**は、競技プログラミング（特にAtCoder）の学習と参加を支援するために設計されたFlutter製のモバイルアプリケーションです。ユーザーは今後のコンテスト情報を確認したり、問題を閲覧したり、リマインダーを設定したりすることができます。

- **主要言語:** Dart
- **フレームワーク:** Flutter
- **状態管理:** Provider
- **主な機能:**
    - AtCoderのコンテスト情報の取得と表示
    - コンテストのリマインダー通知機能
    - 問題詳細の表示
    - アプリ内ブラウザでの問題閲覧
    - コードテンプレートの管理

## 2. プロジェクト構造と主要ファイル

プロジェクトの主要なロジックは`lib/`ディレクトリに格納されています。

```
lib/
├── main.dart                # アプリケーションのエントリーポイント
├── constants/               # 定数を管理
├── l10n/                    # 多言語対応（l10n）関連
├── models/                  # データモデル（Contest, Problemなど）
├── providers/               # 状態管理のためのProviderクラス
├── screens/                 # 各画面のUI
├── services/                # ビジネスロジック（API連携、通知など）
└── widgets/                 # 共通で利用されるUIウィジェット
```

- **`lib/services/atcoder_service.dart`**: AtCoderのウェブサイトから情報を取得するための主要なロジックが含まれています。
- **`lib/providers/contest_provider.dart`**: コンテストの状態を管理します。
- **`lib/screens/home_screen_new.dart`**: アプリのメイン画面です。
- **`lib/screens/upcoming_contests_screen.dart`**: 今後のコンテスト一覧を表示する画面です。
- **`pubspec.yaml`**: プロジェクトの依存関係とメタデータを定義しています。

## 3. 開発ワークフロー

### 依存関係のインストール

```bash
flutter pub get
```

### アプリケーションの実行

```bash
flutter run
```

### テストの実行

```bash
flutter test
```

### コード生成（多言語対応など）

`build_runner`を使用してコードを生成する必要がある場合があります。

```bash
flutter pub run build_runner build
```

## 4. コーディング規約

- **静的解析:** `analysis_options.yaml` に定義されたルールに従います。コードを追加・変更する際は、`flutter analyze` を実行して警告が出ないことを確認してください。
- **フォーマット:** `dart format .` を実行して、コードベース全体のフォーマットを統一してください。
- **命名規則:**
    - ファイル名、クラス名: `UpperCamelCase` (例: `ContestProvider`)
    - 変数名、メソッド名: `lowerCamelCase` (例: `fetchContests`)
- **UI:** Material Design 3をベースに、`lib/providers/theme_provider.dart`で定義されたテーマを使用してください。

## 5. その他

- **バージョン管理:** このプロジェクトはGitで管理されています。コミットメッセージは、変更内容が明確にわかるように記述してください。
- **多言語対応:** テキストは`l10n/`以下の`.arb`ファイルで管理されています。UIに新しいテキストを追加する場合は、各言語のファイルに追記し、コード生成を実行してください。

