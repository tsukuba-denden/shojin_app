import 'dart:io';
import 'package:flutter/services.dart'; // Added for MethodChannel
import 'package:url_launcher/url_launcher.dart';

class UpdateManager {
  static const MethodChannel _platform = MethodChannel('com.example.shojin_app/patcher'); // Define MethodChannel

  Future<void> applyUpdate(String filePath, String? assetName) async {
    String fileName = assetName ?? filePath.split(Platform.pathSeparator).last;
    String fileExtension = fileName.split('.').last.toLowerCase();

    print('Attempting to apply update for file: $filePath with extension: .$fileExtension');
    if (Platform.isAndroid) {
      if (fileExtension == 'apk') {
        try {
          print('Starting APK installation process via MethodChannel for: $filePath');
          
          final result = await _platform.invokeMethod('installApk', {'apkPath': filePath});

          print('MethodChannel installApk result: $result');

          if (result is Map) {
            final status = result['status'];
            final message = result['message'] ?? 'No message from installer.';

            if (status == 0) { // STATUS_SUCCESS from native side
              print('APK installation successful: $message');
              // Potentially, clean up the APK file if it's no longer needed and was copied to a temp location for install
              // await _cleanupApkFile(filePath); // Example cleanup call
              return;
            } else if (status == 3) { // STATUS_FAILURE_ABORTED (User Cancelled) from native side
              print('APK installation cancelled by user: $message');
              throw Exception('インストールがユーザーによってキャンセルされました。');
            } else {
              // Other failure statuses from PackageInstaller
              print('APK installation failed with status $status: $message');
              throw Exception('APKのインストールに失敗しました: $message (ステータス: $status)');
            }
          } else {
            // Should not happen if native side is correctly implemented
            print('APK installation failed: Unexpected result format from MethodChannel.');
            throw Exception('APKのインストールに失敗しました: 予期しない応答です。');
          }
        } on PlatformException catch (e) {
          print('PlatformException during APK installation: ${e.code} - ${e.message} - ${e.details}');
          // Map common error codes from native side if needed
          if (e.code == "FILE_NOT_FOUND") {
            throw Exception('APKファイルが見つかりません: ${e.message}');
          } else if (e.code == "INSTALL_FAILED" || e.code.startsWith("INSTALL_FAILURE_")) {
             throw Exception('APKのインストールに失敗しました: ${e.message}');
          } else if (e.code == "INSTALL_BLOCKED") {
            throw Exception('APKのインストールがブロックされました: ${e.message}');
          } else if (e.code == "INSTALL_INVALID_APK") {
            throw Exception('無効なAPKファイルです: ${e.message}');
          }
          // Fallback to a generic message, or attempt old method
          // For now, rethrow a user-friendly version of the platform exception
          throw Exception('APKインストール中にプラットフォームエラーが発生しました: ${e.message}');
        } catch (e) {
          print('Exception during APK installation: $e');
          if (e is Exception && e.toString().contains("APKのインストール")) { // Avoid re-wrapping our specific exceptions
            rethrow;
          }
          throw Exception('APKインストール中に予期しないエラーが発生しました: $e');
        }
      } else {
        print('Error: Android update file is not an APK. Path: $filePath');
        throw Exception('Androidの更新ファイルはAPKではありません。');
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

  // Example placeholder for APK cleanup logic if needed after successful install
  // Future<void> _cleanupApkFile(String filePath) async {
  //   try {
  //     final file = File(filePath);
  //     if (await file.exists()) {
  //       // Be careful with this. Ensure this is the correct file to delete.
  //       // This might be the original cached file or a temporary copy.
  //       // The current native implementation reads directly from the provided path.
  //       // If EnhancedUpdateService copies it to a specific "install" location,
  //       // then that specific copy could be targeted for cleanup.
  //       // For now, let's assume the file at `filePath` might still be the cached version
  //       // or a user-accessible copy, so automatic deletion might not be desired without more context.
  //       print('Hypothetical cleanup of APK at: $filePath');
  //       // await file.delete();
  //     }
  //   } catch (e) {
  //     print('Error cleaning up APK file: $e');
  //   }
  // }
}
