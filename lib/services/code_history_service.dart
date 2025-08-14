import 'dart:io';

import 'package:path_provider/path_provider.dart';
import '../models/code_history.dart';

class CodeHistoryService {
  Future<String> _getHistoryDirectoryPath(String problemId) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/code_history/$problemId';
  }

  Future<void> saveHistory(String problemId, String code) async {
    if (code.trim().isEmpty) {
      return;
    }

    final historyDirectoryPath = await _getHistoryDirectoryPath(problemId);
    final historyDirectory = Directory(historyDirectoryPath);
    if (!await historyDirectory.exists()) {
      await historyDirectory.create(recursive: true);
    }

    final timestamp = DateTime.now();
    final id = timestamp.millisecondsSinceEpoch.toString();
    final historyFile = File('$historyDirectoryPath/$id.txt');

    // To avoid saving too many identical versions, check the latest history
    final history = await getHistory(problemId);
    if (history.isNotEmpty) {
      final latestHistory = history.first;
      if (latestHistory.content.trim() == code.trim()) {
        return; // Don't save if the content is the same as the latest
      }
    }

    await historyFile.writeAsString(code);
  }

  Future<List<CodeHistory>> getHistory(String problemId) async {
    final historyDirectoryPath = await _getHistoryDirectoryPath(problemId);
    final historyDirectory = Directory(historyDirectoryPath);

    if (!await historyDirectory.exists()) {
      return [];
    }

    final files = await historyDirectory.list().toList();
    final historyList = <CodeHistory>[];

    for (var fileEntity in files) {
      if (fileEntity is File) {
        final id = fileEntity.uri.pathSegments.last.split('.').first;
        final timestamp = DateTime.fromMillisecondsSinceEpoch(int.parse(id));
        final content = await fileEntity.readAsString();

        historyList.add(CodeHistory(
          id: id,
          content: content,
          timestamp: timestamp,
        ));
      }
    }

    historyList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return historyList;
  }

  Future<void> clearHistory(String problemId) async {
    final historyDirectoryPath = await _getHistoryDirectoryPath(problemId);
    final historyDirectory = Directory(historyDirectoryPath);

    if (await historyDirectory.exists()) {
      await historyDirectory.delete(recursive: true);
    }
  }
}
