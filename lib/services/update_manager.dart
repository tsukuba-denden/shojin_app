import 'dart:io';
import 'package:flutter/material.dart';
import 'package:android_package_installer/android_package_installer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart'; // Import url_launcher

class UpdateManager extends ChangeNotifier {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _statusMessage = '';

  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  String get statusMessage => _statusMessage;

  Future<void> applyUpdate(String filePath, String? assetName) async {
    String fileName = assetName ?? filePath.split(Platform.pathSeparator).last;
    String fileExtension = fileName.split('.').last.toLowerCase();

    print('Attempting to apply update for file: $filePath with extension: .$fileExtension');
    if (Platform.isAndroid) {
      if (fileExtension == 'apk') {
        try {
          print('Starting APK installation process for: $filePath');
          await _installApk(filePath); // Added await here
        } catch (e) {
          print('Exception during APK installation: $e');
          _statusMessage = 'APKのインストール中にエラーが発生しました: $e';
          notifyListeners(); // Notify listeners on error
        }
      } else {
        print('Error: Android update file is not an APK. Path: $filePath');
        _statusMessage = 'Androidの更新ファイルはAPKではありません。'; // Set status message
        notifyListeners(); // Notify listeners
        // throw Exception('Androidの更新ファイルはAPKではありません。'); // Consider if throwing is still desired
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
          if (!await launchUrl(Uri.file(filePath))) { // launchUrl is from url_launcher
            print('Failed to launch Windows installer using url_launcher. Attempting Process.run...');
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
          if (!await launchUrl(Uri.file(filePath))) { // launchUrl is from url_launcher
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

  Future<void> _installApk(String filePath) async {
    _statusMessage = 'APKのインストールプロセスを開始しています: $filePath';
    notifyListeners();
    debugPrint(_statusMessage);

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        _statusMessage = 'エラー: APKファイルが見つかりません: $filePath';
        notifyListeners();
        debugPrint(_statusMessage);
        return;
      }

      final installResult = await AndroidPackageInstaller.installApk(
        apkFilePath: filePath,
      );

      String statusResultString;
      switch (installResult) {
        case 0: // PackageInstallerStatus.success
          statusResultString = '成功';
          _statusMessage = 'APKのインストールに成功しました。';
          break;
        case 1: // PackageInstallerStatus.pending
          statusResultString = 'ユーザー操作保留中';
          _statusMessage = 'インストールのためにユーザーの操作が必要です。';
          break;
        case -1: // PackageInstallerStatus.failure
          statusResultString = '失敗';
          _statusMessage = 'APKのインストールに失敗しました: 一般的な失敗';
          break;
        case -2: // PackageInstallerStatus.failureAborted
          statusResultString = '失敗 (中断)';
          _statusMessage = 'APKのインストールに失敗しました: ユーザーによって中断されました';
          break;
        case -3: // PackageInstallerStatus.failureBlocked
          statusResultString = '失敗 (ブロック)';
          _statusMessage = 'APKのインストールに失敗しました: インストールはブロックされました';
          break;
        case -4: // PackageInstallerStatus.failureConflict
          statusResultString = '失敗 (競合)';
          _statusMessage = 'APKのインストールに失敗しました: 既存のパッケージと競合しています';
          break;
        case -5: // PackageInstallerStatus.failureIncompatible
          statusResultString = '失敗 (非互換)';
          _statusMessage = 'APKのインストールに失敗しました: パッケージは互換性がありません';
          break;
        case -6: // PackageInstallerStatus.failureInvalid
          statusResultString = '失敗 (無効)';
          _statusMessage = 'APKのインストールに失敗しました: 無効なAPKファイルです';
          break;
        case -7: // PackageInstallerStatus.failureStorage
          statusResultString = '失敗 (ストレージ)';
          _statusMessage = 'APKのインストールに失敗しました: ストレージの問題';
          break;
        default:
          statusResultString = '不明 ($installResult)';
          _statusMessage = 'APKのインストールに失敗しました: 不明なステータス ($installResult)';
          break;
      }

      notifyListeners();
      debugPrint('APK installation result: $statusResultString');

    } catch (e) {
      _statusMessage = 'APKのインストール中にエラーが発生しました: $e';
      debugPrint('Error during APK installation: $e');
    }
    notifyListeners();
  }

  Future<void> downloadAndInstallUpdate(String downloadUrl, String fileName) async {
    if (_isDownloading) return;

    _isDownloading = true;
    _downloadProgress = 0.0;
    _statusMessage = 'アップデートのダウンロードを開始しています...';
    notifyListeners();

    // final permissionGranted = await _checkAndRequestPermissions();
    // if (!permissionGranted) {
    //   _statusMessage = 'ストレージのアクセス許可が必要です。';
    //   _isDownloading = false;
    //   notifyListeners();
    //   return;
    // }

    try {
      final directory = await getTemporaryDirectory(); // Or getExternalStorageDirectory()
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
        debugPrint('既存のAPKファイルを削除しました: $filePath');
      }

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(downloadUrl));
      final response = await request.close();

      if (response.statusCode == 200) {
        final totalBytes = response.contentLength;
        var receivedBytes = 0;

        await response.listen((List<int> data) {
          file.writeAsBytesSync(data, mode: FileMode.append);
          receivedBytes += data.length;
          if (totalBytes != -1) {
            _downloadProgress = receivedBytes / totalBytes;
            _statusMessage = 'ダウンロード中: ${(_downloadProgress * 100).toStringAsFixed(0)}%';
            notifyListeners();
          }
        }).asFuture();

        _statusMessage = 'ダウンロードが完了しました。インストールを開始します...';
        _isDownloading = false;
        notifyListeners();
        debugPrint('APK downloaded to: $filePath');
        await _installApk(filePath);
      } else {
        _statusMessage = 'ダウンロードに失敗しました: ${response.statusCode}';
        _isDownloading = false;
        notifyListeners();
      }
    } catch (e) {
      _statusMessage = 'アップデートのダウンロードまたはインストール中にエラーが発生しました: $e';
      _isDownloading = false;
      notifyListeners();
      debugPrint('Error in downloadAndInstallUpdate: $e');
    }
  }
}
