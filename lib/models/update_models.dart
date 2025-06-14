// Enhanced AppUpdateInfo with more details
class EnhancedAppUpdateInfo {
  final String version;
  final String? releaseNotes;
  final String? downloadUrl;
  final DateTime? releaseDate;
  final String? assetName;
  final int? fileSize;
  final String? releaseTag;

  EnhancedAppUpdateInfo({
    required this.version,
    this.releaseNotes,
    this.downloadUrl,
    this.releaseDate,
    this.assetName,
    this.fileSize,
    this.releaseTag,
  });
}

// Progress information class
class UpdateProgress {
  final double progress;
  final String status;
  final int? bytesDownloaded;
  final int? totalBytes;
  final bool isCompleted;
  final String? errorMessage;

  UpdateProgress({
    required this.progress,
    required this.status,
    this.bytesDownloaded,
    this.totalBytes,
    this.isCompleted = false,
    this.errorMessage,
  });

  String get formattedProgress {
    if (totalBytes != null && bytesDownloaded != null) {
      return '${(bytesDownloaded! / 1024 / 1024).toStringAsFixed(1)} MB / ${(totalBytes! / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(progress * 100).toStringAsFixed(0)}%';
  }
}
