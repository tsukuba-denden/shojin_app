enum ContestType {
  abc,
  arc,
  agc,
  ahc,
  other, // 今後の拡張性を考慮
}

class ReminderSetting {
  final ContestType contestType;
  int minutesBefore; // 何分前に通知するか
  bool isEnabled; // このリマインダーが有効か

  ReminderSetting({
    required this.contestType,
    required this.minutesBefore,
    this.isEnabled = true,
  });

  // shared_preferences に保存・読み込みするための toJson/fromJson メソッド (例)
  Map<String, dynamic> toJson() => {
        'contestType': contestType.toString(),
        'minutesBefore': minutesBefore,
        'isEnabled': isEnabled,
      };

  factory ReminderSetting.fromJson(Map<String, dynamic> json) {
    return ReminderSetting(
      contestType: ContestType.values.firstWhere(
          (e) => e.toString() == json['contestType'],
          orElse: () => ContestType.other), // 不明な場合は other
      minutesBefore: json['minutesBefore'] as int,
      isEnabled: json['isEnabled'] as bool,
    );
  }
}
