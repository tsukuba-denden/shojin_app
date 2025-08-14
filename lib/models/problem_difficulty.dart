class ProblemDifficulty {
  final double? slope;
  final double? intercept;
  final double? variance;
  final int? difficulty;
  final double? discrimination;
  final double? irtLoglikelihood;
  final int? irtUsers;
  final bool isExperimental;

  ProblemDifficulty({
    this.slope,
    this.intercept,
    this.variance,
    this.difficulty,
    this.discrimination,
    this.irtLoglikelihood,
    this.irtUsers,
    required this.isExperimental,
  });

  factory ProblemDifficulty.fromJson(Map<String, dynamic> json) {
    return ProblemDifficulty(
      slope: json['slope']?.toDouble(),
      intercept: json['intercept']?.toDouble(),
      variance: json['variance']?.toDouble(),
      difficulty: json['difficulty'],
      discrimination: json['discrimination']?.toDouble(),
      irtLoglikelihood: json['irt_loglikelihood']?.toDouble(),
      irtUsers: json['irt_users'],
      // Some entries may omit this flag. Default to false when null.
      isExperimental: (json['is_experimental'] as bool?) ?? false,
    );
  }
}
