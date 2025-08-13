# コード用フォント(TTF)の追加

このガイドでは、コードブロック（エディタ、サンプルIOなど）で使用する独自のTTFフォントを追加する方法を説明します。アプリはコード内で定義されたフォントファミリーの静的リストを読み込みます。アプリ内でのフォント登録UIはありません。

## 手順

1) **TTFファイルを配置する**
   - `.ttf` ファイルを `assets/fonts/` ディレクトリ配下に配置します（フォルダが存在しない場合は作成してください）。例：
     - `assets/fonts/MyCodeFont-Regular.ttf`

2) **pubspec.yamlでフォントを宣言する**
   - `pubspec.yaml` を開き、 `flutter:` セクションに `fonts` エントリを追加します。`family` の値が、アプリ内で選択するフォント名になります。
   ```yaml
   flutter:
     uses-material-design: true
     assets:
       - assets/icon/twitter_logo.svg
       - assets/icon/youtube_logo.svg
       - assets/icon/github_logo.svg
     fonts:
       - family: MyCodeFont
         fonts:
           - asset: assets/fonts/MyCodeFont-Regular.ttf
             weight: 400
           # 他のウェイトやスタイルがあれば追加
           # - asset: assets/fonts/MyCodeFont-Bold.ttf
           #   weight: 700
   ```

3) **アプリの選択可能リストにファミリー名を追加する**
   - `lib/providers/theme_provider.dart` を開きます。
   - `assetCodeFontFamilies` を見つけ、フォントのファミリー名を追加します（`pubspec.yaml`の`family`と一致させる必要があります）。
   ```dart
   const List<String> assetCodeFontFamilies = [
     'MyCodeFont',
     // 他のファミリーをここに追加
   ];
   ```

4) **依存関係を取得し、リビルドする**
   - 以下を実行します:
   ```
   flutter pub get
   ```
   - アプリをリビルドします。新しいフォントが `設定 > コードブロックのフォント` に表示されるはずです。

## 注意事項
- 表示には `lib/utils/text_style_helper.dart` の `getMonospaceTextStyle()` が使用されます。
  - フォント名がGoogleフォントと一致する場合、Google Fontsが使用されます。
  - それ以外の場合は `TextStyle(fontFamily: ...)` にフォールバックし、アセット/システムのフォントが使用されます。
- 設定はSharedPreferences (`code_font_family`) を介して永続化されます。

## トラブルシューティング
- **フォントがドロップダウンに表示されない場合**:
  - `theme_provider.dart` の `assetCodeFontFamilies` にファミリー名が追加されていることを確認してください。
  - `pubspec.yaml` の `family` 名が完全に一致していること（大文字と小文字を区別）を確認してください。
  - `flutter pub get` がエラーなく完了したことを確認してください。
  - アセットパスが正しく、プロジェクトに含まれていることを確認してください。
- **テキストが指定したフォントでレンダリングされない場合**:
  - `pubspec.yaml` と `assetCodeFontFamilies` リストの両方で `family` 名を再確認してください。
  - TTFファイルが有効で、表示しようとしている文字（例：日本語のグリフ）をサポートしていることを確認してください。

## 例: "SFMono"を追加する
1. `SFMono-Regular.ttf` を `assets/fonts/` にコピーします。
2. `pubspec.yaml` に以下を追記します:
   ```yaml
   flutter:
     fonts:
       - family: SFMono
         fonts:
           - asset: assets/fonts/SFMono-Regular.ttf
             weight: 400
   ```
3. `lib/providers/theme_provider.dart` に以下を追記します:
   ```dart
   const List<String> assetCodeFontFamilies = [
     'SFMono',
   ];
   ```
4. `flutter pub get` を実行し、リビルドします。
