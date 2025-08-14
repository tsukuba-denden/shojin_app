import 'package:flutter/material.dart';
import '../models/problem_difficulty.dart';
import '../services/atcoder_service.dart';

class RecommendScreen extends StatefulWidget {
  const RecommendScreen({super.key});

  @override
  State<RecommendScreen> createState() => _RecommendScreenState();
}

class _RecommendScreenState extends State<RecommendScreen> {
  final _atcoderService = AtCoderService();
  final _usernameController = TextEditingController();
  List<MapEntry<String, ProblemDifficulty>> _recommendedProblems = [];
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _getRecommendations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _recommendedProblems = [];
    });

    try {
      final username = _usernameController.text;
      if (username.isEmpty) {
        throw Exception('ユーザー名を入力してください');
      }

      final rating = await _atcoderService.fetchAtCoderRate(username);
      if (rating == null) {
        throw Exception('ユーザーが見つからないか、レーティングがありません');
      }

      final allProblems = await _atcoderService.fetchProblemDifficulties();

      final recommended = allProblems.entries.where((entry) {
        final difficulty = entry.value.difficulty;
        return difficulty != null &&
            difficulty >= rating - 100 &&
            difficulty <= rating + 100;
      }).toList();

      recommended
          .sort((a, b) => a.value.difficulty!.compareTo(b.value.difficulty!));

      setState(() {
        _recommendedProblems = recommended;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('問題推薦'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'AtCoderユーザー名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _getRecommendations,
              child: const Text('推薦を取得'),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _recommendedProblems.length,
                  itemBuilder: (context, index) {
                    final problem = _recommendedProblems[index];
                    return ListTile(
                      title: Text(problem.key),
                      subtitle: Text(
                          '難易度: ${problem.value.difficulty ?? "なし"}'),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
