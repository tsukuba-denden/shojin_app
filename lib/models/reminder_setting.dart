enum ContestType {
  abc,
  arc,
  agc,
  ahc,
  other, // 今後の拡張性を考慮
}

class ReminderSetting {
  final ContestType contestType;
  List<int> minutesBefore; // 何分前に通知するか (複数指定可能)
  bool isEnabled; // このリマインダーが有効か

  ReminderSetting({
    required this.contestType,
    required this.minutesBefore,
    this.isEnabled = true,
  });

  // shared_preferences に保存・読み込みするための toJson/fromJson メソッド
  Map<String, dynamic> toJson() => {
        'contestType': contestType.toString(),
        'minutesBefore': minutesBefore, // List<int> をそのまま保存
        'isEnabled': isEnabled,
      };

  factory ReminderSetting.fromJson(Map<String, dynamic> json) {
    // minutesBefore が List<dynamic> としてデコードされる可能性があるので、List<int> に変換
    List<int> minutesList = [];
    if (json['minutesBefore'] is List) {
      for (var item in json['minutesBefore'] as List) {
        if (item is int) {
          minutesList.add(item);
        } else if (item is String) {
          minutesList.add(int.tryParse(item) ?? 0); // パース失敗時は0など、適切なデフォルト値
        }
      }
    } else if (json['minutesBefore'] is int) { // 以前の単一int型データとの互換性のため
      minutesList.add(json['minutesBefore'] as int);
    }

    return ReminderSetting(
      contestType: ContestType.values.firstWhere(
          (e) => e.toString() == json['contestType'],
          orElse: () => ContestType.other),
      minutesBefore: minutesList.isNotEmpty ? minutesList : [15], // デフォルト値
      isEnabled: json['isEnabled'] as bool,
    );
  }
}
