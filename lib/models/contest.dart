class Contest {
  final String nameJa;
  final String nameEn;
  final String url;
  final DateTime startTime;
  final int durationMin;
  final String? ratedRange;
  final String status;

  Contest({
    required this.nameJa,
    required this.nameEn,
    required this.url,
    required this.startTime,
    required this.durationMin,
    this.ratedRange,
    required this.status,
  });

  factory Contest.fromMap(Map<String, dynamic> map) {
    return Contest(
      nameJa: map['name_ja']?.toString() ?? '',
      nameEn: map['name_en']?.toString() ?? '',
      url: map['url']?.toString() ?? '',
      startTime: DateTime.parse(map['start_time']),
      durationMin: map['duration_min'] ?? 0,
      ratedRange: map['rated_range']?.toString(),
      status: map['status']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name_ja': nameJa,
      'name_en': nameEn,
      'url': url,
      'start_time': startTime.toIso8601String(),
      'duration_min': durationMin,
      'rated_range': ratedRange,
      'status': status,
    };
  }

  // ABCかどうかを判定
  bool get isABC {
    return nameJa.contains('AtCoder Beginner Contest') || 
           nameEn.contains('AtCoder Beginner Contest');
  }

  // 次回開催かどうかを判定
  bool get isUpcoming {
    return status == 'Upcoming';
  }
  // 開始時刻の日本語表示（端末のタイムゾーンで表示）
  String get startTimeJapanese {
    final localTime = startTime.toLocal();
    return '${localTime.year}年${localTime.month}月${localTime.day}日 ${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
  }
  // 開始時刻の詳細な日本語表示（曜日付き）
  String get startTimeWithWeekday {
    final localTime = startTime.toLocal();
    final weekdays = ['日', '月', '火', '水', '木', '金', '土'];
    final weekday = weekdays[localTime.weekday % 7];
    return '${localTime.year}年${localTime.month}月${localTime.day}日（$weekday） ${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
  }

  // 時間の表示（例：1時間40分）
  String get durationString {
    final hours = durationMin ~/ 60;
    final minutes = durationMin % 60;
      if (hours == 0) {
      return '${minutes}分';
    } else if (minutes == 0) {
      return '${hours}時間';
    } else {
      return '${hours}時間${minutes}分';
    }
  }
}
