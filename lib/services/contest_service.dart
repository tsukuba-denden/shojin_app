import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';
import 'package:shojin_app/models/contest.dart';

class ContestService {
  final String _url =
      'https://github.com/tsukuba-denden/atcoder-contest-info/raw/refs/heads/main/contests.yaml';

  Future<List<Contest>> fetchContests() async {
    try {
      final response = await http.get(Uri.parse(_url));
      if (response.statusCode == 200) {
        final yamlString = response.body;
        final dynamic yamlData = loadYaml(yamlString);
        // Check if yamlData is a List and its elements are YamlMap
        if (yamlData is YamlList && yamlData.every((item) => item is YamlMap)) {
          final contests = yamlData
              .map((dynamic item) => Contest.fromYaml(item as YamlMap))
              .toList();
          // Sort contests by start time in ascending order
          contests.sort((a, b) => a.startTime.compareTo(b.startTime));
          return contests;
        } else {
          throw Exception('コンテストデータの形式が正しくありません。');
        }
      } else {
        throw Exception('コンテスト情報の取得に失敗しました: ${response.statusCode}');
      }
    } catch (e) {
      // Log the error or handle it as needed
      print('Error fetching contests: $e');
      rethrow; // Rethrow the exception to be caught by the caller
    }
  }
}
