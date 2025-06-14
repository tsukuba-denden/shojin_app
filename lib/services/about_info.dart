import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';

class AboutInfo {
  static Future<Map<String, dynamic>> getInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    
    Map<String, dynamic> info = {
      'version': packageInfo.version,
      'buildNumber': packageInfo.buildNumber,
      'appName': packageInfo.appName,
      'packageName': packageInfo.packageName,
      'flavor': kReleaseMode ? 'release' : 'debug',
    };

    // プラットフォーム固有の情報を取得
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      info.addAll({
        'platform': 'Android',
        'model': androidInfo.model,
        'brand': androidInfo.brand,
        'manufacturer': androidInfo.manufacturer,
        'androidVersion': androidInfo.version.release,
        'sdkInt': androidInfo.version.sdkInt,
        'supportedArch': androidInfo.supportedAbis,
      });
    } else if (Platform.isIOS) {
      final iosInfo = await DeviceInfoPlugin().iosInfo;
      info.addAll({
        'platform': 'iOS',
        'model': iosInfo.model,
        'name': iosInfo.name,
        'systemName': iosInfo.systemName,
        'systemVersion': iosInfo.systemVersion,
        'identifierForVendor': iosInfo.identifierForVendor,
      });
    } else if (Platform.isWindows) {
      final windowsInfo = await DeviceInfoPlugin().windowsInfo;
      info.addAll({
        'platform': 'Windows',
        'computerName': windowsInfo.computerName,
        'majorVersion': windowsInfo.majorVersion,
        'minorVersion': windowsInfo.minorVersion,
        'buildNumber': windowsInfo.buildNumber,
      });
    } else if (Platform.isLinux) {
      final linuxInfo = await DeviceInfoPlugin().linuxInfo;
      info.addAll({
        'platform': 'Linux',
        'name': linuxInfo.name,
        'version': linuxInfo.version,
        'id': linuxInfo.id,
        'prettyName': linuxInfo.prettyName,
      });
    } else if (Platform.isMacOS) {
      final macOSInfo = await DeviceInfoPlugin().macOsInfo;
      info.addAll({
        'platform': 'macOS',
        'computerName': macOSInfo.computerName,
        'hostName': macOSInfo.hostName,
        'osRelease': macOSInfo.osRelease,
        'kernelVersion': macOSInfo.kernelVersion,
      });
    } else {
      info['platform'] = 'Unknown';
    }

    return info;
  }
}
