import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart'; // Corrected import path

class UpdateManager {
  Future<void> applyUpdate(String filePath, String? assetName) async {
    String fileName = assetName ?? filePath.split(Platform.pathSeparator).last;
    String fileExtension = fileName.split('.').last.toLowerCase();

    print('Attempting to apply update for file: $filePath with extension: .$fileExtension');

    if (Platform.isAndroid) {
      if (fileExtension == 'apk') {
        try {
          final result = await OpenFile.open(filePath, type: 'application/vnd.android.package-archive');
          print('OpenFile result: ${result.type} - ${result.message}');
          if (result.type != ResultType.done) {
            print('Error opening APK: ${result.message}');
            // Optionally, try to launch the file URI if OpenFile fails
            // This might sometimes work if OpenFile lacks specific permissions or handlers
            if (!await launchUrl(Uri.file(filePath))) {
                 print('Fallback: Could not launch APK using url_launcher either.');
            } else {
                print('Fallback: Launched APK using url_launcher.');
            }
          }
        } catch (e) {
          print('Exception opening APK with OpenFile: $e');
           if (!await launchUrl(Uri.file(filePath))) {
               print('Fallback exception: Could not launch APK using url_launcher either: $e');
           } else {
                print('Fallback exception: Launched APK using url_launcher.');
           }
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
