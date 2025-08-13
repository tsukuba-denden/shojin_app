class CodeHistory {
  final String id;
  final String content;
  final DateTime timestamp;

  CodeHistory({
    required this.id,
    required this.content,
    required this.timestamp,
  });

  factory CodeHistory.fromJson(Map<String, dynamic> json) {
    return CodeHistory(
      id: json['id'],
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
