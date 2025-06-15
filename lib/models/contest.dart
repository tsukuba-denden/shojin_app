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
    return Contest(
      title: yaml['title'] as String,
      startTime: DateTime.parse(yaml['startTime'] as String),
      url: yaml['url'] as String,
    );
  }
}
