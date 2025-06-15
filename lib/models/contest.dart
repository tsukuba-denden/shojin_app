import 'package:yaml/yaml.dart';

class Contest {
  final String title;
  final DateTime startTime;
  final String url;

  Contest({
    required this.title,
    required this.startTime,
    required this.url,
  });

  factory Contest.fromYaml(YamlMap yaml) {
    // Use 'name_en' or 'name_ja' for title, and 'start_time' for startTime.
    final titleEn = yaml['name_en'] as String?;
    final titleJa = yaml['name_ja'] as String?;
    final title = titleEn ?? titleJa; // Prioritize English title

    final startTimeStr = yaml['start_time'] as String?; // Corrected key
    final url = yaml['url'] as String?;

    if (title == null || startTimeStr == null || url == null) {
      // Or handle more gracefully, e.g., by returning a Contest object with default/error values
      throw FormatException('コンテストデータの必須フィールド(title, start_time, url)が不足しています: $yaml');
    }

    return Contest(
      title: title,
      startTime: DateTime.parse(startTimeStr),
      url: url,
    );
  }
}
