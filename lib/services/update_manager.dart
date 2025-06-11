import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart'; // Corrected import path

class UpdateManager {
  Future<void> applyUpdate(String filePath, String? assetName) async {
    String fileName = assetName ?? filePath.split(Platform.pathSeparator).last;
    String fileExtension = fileName.split('.').last.toLowerCase();

    print('Attempting to apply update for file: $filePath with extension: .$fileExtension');    if (Platform.isAndroid) {
      if (fileExtension == 'apk') {
        try {
          print('Starting APK installation process for: $filePath');
          
          // Android 8.0+ (API 26+) での "不明なアプリのインストール" 権限チェック
          // この権限はユーザーが設定画面で手動で有効にする必要がある
          
          // 方法1: 直接的なAPKインストール用のIntentを作成
          // これによりシステムのパッケージインストーラーが起動される
          final Uri fileUri = Uri.file(filePath);
          
          // まずOpenFileを使用（最も互換性が高い）
          final result = await OpenFile.open(
            filePath, 
            type: 'application/vnd.android.package-archive'
          );
          
          print('OpenFile result: ${result.type} - ${result.message}');
          
          if (result.type == ResultType.done) {
            print('APK installation initiated successfully via OpenFile');
            return;
          } 
          
          // OpenFileが失敗した場合、システムのファイルマネージャーを開く
          print('OpenFile failed, trying system file manager approach...');
          
          // 方法2: ファイルマネージャーでファイルを表示
          // ユーザーが手動でタップしてインストールできる
          try {
            // ファイルの親ディレクトリを開く
            final directory = filePath.substring(0, filePath.lastIndexOf('/'));
            final directoryUri = Uri.parse('content://com.android.externalstorage.documents/document/primary:Android%2Fdata%2Fcom.example.shojin_app%2Ffiles%2Ftemp_install');
            
            if (await launchUrl(directoryUri, mode: LaunchMode.externalApplication)) {
              print('Successfully opened file directory - user can manually install APK');
              return;
            }
          } catch (e) {
            print('Directory opening failed: $e');
          }
          
          // 方法3: 一般的なファイルビューワーで開く
          try {
            // ACTION_VIEW IntentでAPKファイルを開く
            if (await launchUrl(fileUri, mode: LaunchMode.externalApplication)) {
              print('APK opened via general file viewer');
              return;
            }
          } catch (e) {
            print('File viewer approach failed: $e');
          }
          
          // 最終手段: ユーザーに手動インストールの指示を表示
          throw Exception(
            'APKのインストールには追加の権限が必要です。\n\n'
            '手動でインストールするには:\n'
            '1. ファイルマネージャーを開く\n'
            '2. 以下のパスに移動:\n'
            '   Android/data/com.example.shojin_app/files/temp_install/\n'
            '3. ${fileName}をタップしてインストール\n\n'
            'または、設定 > アプリ > Shojin App > 詳細設定 > 不明なアプリのインストール を有効にしてください。'
          );
            } catch (e) {
          print('Exception during APK installation: $e');
          if (e is Exception) {
            rethrow; // 既に適切にフォーマットされた例外はそのまま投げる
          }
          throw Exception('APKインストール中にエラーが発生しました: $e');
        }
      } else {
        print('Error: Android update file is not an APK. Path: $filePath');
        // Consider launching a file explorer to the directory for other file types
        // For now, just log.
      }
    } else if (Platform.isIOS) {
      print('Direct update application is not supported on iOS from within the app.');
      print('Please distribute updates via TestFlight or the App Store.');
      // Example: Launching a URL to the App Store or release page
      // if (releaseUrl != null) {
      //   if (await canLaunchUrl(Uri.parse(releaseUrl))) {
      //     await launchUrl(Uri.parse(releaseUrl));
      //   }
      // }
    } else if (Platform.isWindows) {
      if (fileExtension == 'exe' || fileExtension == 'msi') {
        try {
          print('Attempting to launch Windows installer: $filePath');
          // Using url_launcher for .exe and .msi is generally safer and more user-friendly
          // as it leverages the OS's default file handling.
          if (!await launchUrl(Uri.file(filePath))) {
            print('Failed to launch Windows installer using url_launcher. Attempting Process.run...');
            // Fallback to Process.run if url_launcher fails, though this has limitations.
            ProcessResult result = await Process.run(filePath, [], runInShell: true);
            print('Windows installer launch result: exitCode=${result.exitCode}, stdout=${result.stdout}, stderr=${result.stderr}');
          } else {
            print('Windows installer launched successfully via url_launcher.');
          }
        } catch (e) {
          print('Error launching Windows installer: $e');
        }
      } else if (fileExtension == 'zip') {
        print('Update (ZIP) downloaded to $filePath. Please extract and apply manually.');
      } else {
        print('Downloaded $filePath. Manual installation required for this file type on Windows.');
      }
    } else if (Platform.isMacOS) {
      if (fileExtension == 'dmg') {
        try {
          print('Attempting to open macOS DMG: $filePath');
          if (!await launchUrl(Uri.file(filePath))) {
            print('Failed to open DMG using url_launcher.');
          } else {
            print('DMG opened successfully via url_launcher.');
          }
        } catch (e) {
          print('Error opening DMG: $e');
        }
      } else if (fileExtension == 'zip' || fileExtension == 'app') { // .app might be inside a .zip
        print('Update ($fileName) downloaded to $filePath. Please extract (if zipped) and apply manually.');
      } else {
        print('Downloaded $filePath. Manual installation required for this file type on macOS.');
      }
    } else if (Platform.isLinux) {
      if (fileExtension == 'appimage') {
        print('AppImage downloaded to $filePath. Please make it executable (chmod +x $filePath) and run.');
      } else if (fileExtension == 'deb') {
        print('Debian package downloaded to $filePath. Please install using your package manager (e.g., sudo dpkg -i $filePath or via a GUI installer).');
      } else if (fileExtension == 'tar.gz' || fileExtension == 'zip') {
        print('Archive ($fileName) downloaded to $filePath. Please extract and apply manually.');
      } else {
        print('Downloaded $filePath. Manual installation required for this file type on Linux.');
      }
    } else {
      print('Update downloaded to $filePath. Platform not explicitly handled, please manage manually.');
    }
  }
}
