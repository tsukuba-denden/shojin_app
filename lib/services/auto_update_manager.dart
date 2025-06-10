import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/enhanced_update_service.dart';
import '../widgets/update_dialogs.dart';

// Auto Update Manager (ReVanced Manager inspired)
class AutoUpdateManager {
  static const String _autoUpdateKey = 'autoUpdateCheckEnabled';
  static const String _lastUpdateCheckKey = 'lastUpdateCheck';
  static const String _skippedVersionKey = 'skippedVersion';
  
  final EnhancedUpdateService _updateService = EnhancedUpdateService();
  
  // Check if auto update is enabled
  Future<bool> isAutoUpdateEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoUpdateKey) ?? true;
  }
  
  // Set auto update preference
  Future<void> setAutoUpdateEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoUpdateKey, enabled);
  }
  
  // Get last update check timestamp
  Future<DateTime?> getLastUpdateCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastUpdateCheckKey);
    return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
  }
  
  // Set last update check timestamp
  Future<void> setLastUpdateCheck(DateTime dateTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastUpdateCheckKey, dateTime.millisecondsSinceEpoch);
  }
  
  // Get skipped version
  Future<String?> getSkippedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_skippedVersionKey);
  }
  
  // Set skipped version
  Future<void> setSkippedVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skippedVersionKey, version);
  }
  
  // Check if should check for updates (based on time interval)
  Future<bool> shouldCheckForUpdates() async {
    if (!await isAutoUpdateEnabled()) return false;
    
    final lastCheck = await getLastUpdateCheck();
    if (lastCheck == null) return true;
    
    // Check every 24 hours
    const checkInterval = Duration(hours: 24);
    return DateTime.now().difference(lastCheck) >= checkInterval;
  }
    // Perform startup update check
  Future<void> checkForUpdatesOnStartup(BuildContext context, {
    String owner = 'tsukuba-denden',
    String repo = 'Shojin_App',
  }) async {
    if (!await shouldCheckForUpdates()) {
      debugPrint('=== スタートアップアップデートチェック ===');
      debugPrint('チェックをスキップ（設定またはタイミング）');
      debugPrint('=====================================');
      return;
    }
    
    try {
      debugPrint('=== スタートアップアップデートチェック開始 ===');
      debugPrint('Repository: $owner/$repo');
      
      final currentVersion = await _updateService.getCurrentAppVersion();
      debugPrint('スタートアップ - 現在のバージョン: "$currentVersion"');
      
      final updateInfo = await _updateService.checkForUpdateOnStartup(
        currentVersion,
        owner,
        repo,
      );
      
      // Update last check timestamp
      await setLastUpdateCheck(DateTime.now());
      
      if (updateInfo != null && context.mounted) {
        final skippedVersion = await getSkippedVersion();
        debugPrint('スタートアップ - 最新バージョン: "${updateInfo.version}"');
        debugPrint('スタートアップ - スキップ済みバージョン: "$skippedVersion"');
        
        // Don't show update if user has skipped this version
        if (skippedVersion != updateInfo.version) {
          debugPrint('スタートアップ - アップデート通知を表示');
          _showUpdateNotification(context, updateInfo);
        } else {
          debugPrint('スタートアップ - アップデートはスキップ済み');
        }
      } else {
        debugPrint('スタートアップ - アップデート不要またはコンテキスト無効');
      }
      debugPrint('=========================================');
    } catch (e) {
      debugPrint('Auto update check failed: $e');
    }
  }
  
  // Show update notification with ReVanced Manager style
  void _showUpdateNotification(BuildContext context, EnhancedAppUpdateInfo updateInfo) {
    if (!context.mounted) return;
    
    // Show as a SnackBar first, then dialog on tap
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.system_update_alt, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text('新しいバージョン ${updateInfo.version} が利用可能です'),
            ),
          ],
        ),
        action: SnackBarAction(
          label: '表示',
          onPressed: () => _showUpdateDialog(context, updateInfo),
        ),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  // Show detailed update dialog
  void _showUpdateDialog(BuildContext context, EnhancedAppUpdateInfo updateInfo) {
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => EnhancedUpdateDialog(
        updateInfo: updateInfo,
        onUpdatePressed: () => _startUpdateProcess(context, updateInfo),
        onLaterPressed: () {
          // Do nothing, just close dialog
        },
        onSkipPressed: () async {
          await setSkippedVersion(updateInfo.version);
        },
      ),
    );
  }
  
  // Start update process with progress dialog
  void _startUpdateProcess(BuildContext context, EnhancedAppUpdateInfo updateInfo) {
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpdateProgressDialog(
        updateInfo: updateInfo,
        onCompleted: () {
          // Show completion message
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('アップデートのインストールが完了しました'),
                  ],
                ),
                duration: Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        onCancelled: () {
          // User cancelled update
        },
      ),
    );
  }
    // Manual update check (for settings screen)
  Future<EnhancedAppUpdateInfo?> checkForUpdatesManually({
    String owner = 'tsukuba-denden',
    String repo = 'Shojin_App',
  }) async {
    try {
      debugPrint('=== 手動アップデートチェック開始 ===');
      debugPrint('Repository: $owner/$repo');
      
      final currentVersion = await _updateService.getCurrentAppVersion();
      debugPrint('手動チェック - 現在のバージョン: "$currentVersion"');
      
      final updateInfo = await _updateService.getLatestReleaseInfo(owner, repo);
      debugPrint('手動チェック - 取得した最新情報: ${updateInfo?.version}');
      
      // Update last check timestamp
      await setLastUpdateCheck(DateTime.now());
      
      if (updateInfo != null && _updateService.isUpdateAvailable(currentVersion, updateInfo.version)) {
        debugPrint('手動チェック - アップデート利用可能');
        return updateInfo;
      } else {
        debugPrint('手動チェック - アップデート不要');
        return null;
      }
    } catch (e) {
      debugPrint('Manual update check failed: $e');
      rethrow;
    }
  }
  
  // Show manual update dialog
  void showManualUpdateDialog(BuildContext context, EnhancedAppUpdateInfo updateInfo) {
    _showUpdateDialog(context, updateInfo);
  }
}

// App Lifecycle Update Checker
class UpdateLifecycleManager extends WidgetsBindingObserver {
  final AutoUpdateManager _autoUpdateManager = AutoUpdateManager();
  final BuildContext context;
  
  UpdateLifecycleManager(this.context);
  
  void startListening() {
    WidgetsBinding.instance.addObserver(this);
  }
  
  void stopListening() {
    WidgetsBinding.instance.removeObserver(this);
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Check for updates when app becomes active
    if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(seconds: 2), () {
        _autoUpdateManager.checkForUpdatesOnStartup(context);
      });
    }
  }
}
