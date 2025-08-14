class AtCoderUserHistory {
  final bool isRated;
  final int place;
  final int oldRating;
  final int newRating;
  final String contestScreenName;
  final String contestName;
  final String contestNameEn;
  final DateTime endTime;

  AtCoderUserHistory({
    required this.isRated,
    required this.place,
    required this.oldRating,
    required this.newRating,
    required this.contestScreenName,
    required this.contestName,
    required this.contestNameEn,
    required this.endTime,
  });

  factory AtCoderUserHistory.fromJson(Map<String, dynamic> json) {
    return AtCoderUserHistory(
      isRated: json['IsRated'],
      place: json['Place'],
      oldRating: json['OldRating'],
      newRating: json['NewRating'],
      contestScreenName: json['ContestScreenName'],
      contestName: json['ContestName'],
      contestNameEn: json['ContestNameEn'],
      endTime: DateTime.parse(json['EndTime']),
    );
  }
}
