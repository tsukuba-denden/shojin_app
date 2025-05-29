import 'dart:convert';
import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// 1. AppUpdateInfo Class
class AppUpdateInfo {
  String version;
  String? releaseNotes;
  String? downloadUrl;
  DateTime? releaseDate;
  String? assetName; // To store the name of the downloaded asset

  AppUpdateInfo({
    required this.version,
    this.releaseNotes,
    this.downloadUrl,
    this.releaseDate,
    this.assetName,
  });
}

// 2. UpdateService Class
class UpdateService {
  // getCurrentAppVersion() method
  Future<String> getCurrentAppVersion() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      // print('Error getting app version: $e'); // Less verbose for startup
      return '0.0.0'; // Default or error version
    }
  }

  // isUpdateAvailable() method
  bool isUpdateAvailable(String currentVersionStr, String latestVersionStr) {
    try {
      Version currentVersion = Version.parse(currentVersionStr.replaceAll('v', ''));
      Version latestVersion = Version.parse(latestVersionStr.replaceAll('v', ''));
      return latestVersion > currentVersion;
    } catch (e) {
      // print('Error parsing version strings: $e'); // Less verbose for startup
      return false;
    }
  }

  // getLatestReleaseInfo() method
  Future<AppUpdateInfo?> getLatestReleaseInfo(String owner, String repo, {bool silent = false}) async {
    final url = Uri.parse('https://api.github.com/repos/$owner/$repo/releases/latest');
    try {
      final response = await http.get(url, headers: {'Accept': 'application/vnd.github.v3+json'});

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        DateTime? releaseDateTime;
        if (jsonResponse['published_at'] != null) {
          releaseDateTime = DateTime.tryParse(jsonResponse['published_at']);
        }

        String? assetDownloadUrl;
        String? foundAssetName;
        if (jsonResponse['assets'] != null && jsonResponse['assets'] is List) {
          Map<String, String?>? assetDetails = _getPlatformSpecificAssetUrl(jsonResponse['assets']);
          if (assetDetails != null) {
            assetDownloadUrl = assetDetails['url'];
            foundAssetName = assetDetails['name'];
          }
        }

        return AppUpdateInfo(
          version: jsonResponse['tag_name']?.replaceAll('v', '') ?? '0.0.0',
          releaseNotes: jsonResponse['body'],
          releaseDate: releaseDateTime,
          downloadUrl: assetDownloadUrl,
          assetName: foundAssetName,
        );
      } else {
        if (!silent) {
          print('Failed to get latest release info: ${response.statusCode} ${response.body}');
        }
        return null;
      }
    } catch (e) {
      if (!silent) {
        print('Error fetching latest release info: $e');
      }
      return null;
    }
  }

  // New method for startup check
  Future<AppUpdateInfo?> checkForUpdateOnStartup(String currentVersion, String owner, String repo) async {
    try {
      AppUpdateInfo? releaseInfo = await getLatestReleaseInfo(owner, repo, silent: true);
      if (releaseInfo != null && isUpdateAvailable(currentVersion, releaseInfo.version)) {
        return releaseInfo;
      }
      return null;
    } catch (e) {
      // Silently fail on startup, or log to a specific startup log if necessary
      // print('Error during startup update check: $e');
      return null;
    }
  }


  // _getPlatformSpecificAssetUrl() method
  Map<String, String?>? _getPlatformSpecificAssetUrl(List<dynamic> assets) {
    String os = Platform.operatingSystem;
    List<String> prioritizedPatterns = [];

    if (os == 'android') {
      prioritizedPatterns = ['.apk'];
    } else if (os == 'windows') {
      prioritizedPatterns = ['.exe', '.msi', '.zip'];
    } else if (os == 'macos') {
      prioritizedPatterns = ['.dmg', '.zip'];
    } else if (os == 'linux') {
      prioritizedPatterns = ['.AppImage', '.deb', '.tar.gz'];
    } else if (os == 'ios') {
      prioritizedPatterns = ['.ipa'];
    }

    for (String pattern in prioritizedPatterns) {
      for (var asset in assets) {
        if (asset is Map && asset.containsKey('name') && asset.containsKey('browser_download_url')) {
          String name = asset['name'].toLowerCase();
          if (name.endsWith(pattern.toLowerCase())) {
            return {'url': asset['browser_download_url'], 'name': asset['name']};
          }
        }
      }
    }
    
    if (os == 'linux') {
        for (var asset in assets) {
            if (asset is Map && asset.containsKey('name') && asset.containsKey('browser_download_url')) {
                String name = asset['name'].toLowerCase();
                if (name.endsWith('.zip') || name.endsWith('.tar.gz')) {
                     return {'url': asset['browser_download_url'], 'name': asset['name']};
                }
            }
        }
    }
    return null;
  }

  Future<String?> downloadUpdate(AppUpdateInfo releaseInfo, Function(double progress) onProgress) async {
    if (releaseInfo.downloadUrl == null || releaseInfo.downloadUrl!.isEmpty) {
      print('Error: Download URL is null or empty.');
      return null;
    }

    final httpClient = http.Client();
    try {
      final Uri downloadUri = Uri.parse(releaseInfo.downloadUrl!);
      final request = http.Request('GET', downloadUri);
      final http.StreamedResponse response = await httpClient.send(request);

      if (response.statusCode != 200) {
        print('Error downloading update: ${response.statusCode} ${response.reasonPhrase}');
        return null;
      }

      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = releaseInfo.assetName ?? Uri.parse(releaseInfo.downloadUrl!).pathSegments.last;
      final String localFilePath = '${tempDir.path}${Platform.pathSeparator}$fileName';
      final File file = File(localFilePath);
      final IOSink sink = file.openWrite();

      int bytesReceived = 0;
      final int? totalLength = response.contentLength;

      await response.stream.listen((List<int> chunk) {
        sink.add(chunk);
        bytesReceived += chunk.length;
        if (totalLength != null && totalLength > 0) {
          double currentProgress = bytesReceived / totalLength;
          onProgress(currentProgress);
        } else {
          onProgress(-1); 
        }
      }).asFuture(); 

      await sink.flush();
      await sink.close();
      print('Update downloaded to: $localFilePath');
      return localFilePath;

    } catch (e) {
      print('Error during download update: $e');
      return null;
    } finally {
      httpClient.close();
    }
  }

  Future<bool> requestStoragePermission() async {
    if (Platform.isIOS) {
      return true;
    }

    if (Platform.isAndroid) {
      PermissionStatus status = await Permission.storage.status;
      print('Current storage permission status: $status');
      if (status.isGranted) {
        return true;
      } else {
        status = await Permission.storage.request();
        print('Storage permission status after request: $status');
        return status.isGranted;
      }
    }
    return true;
  }
}
