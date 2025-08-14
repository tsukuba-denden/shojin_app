import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  String? _savedUsername; // 設定済みユーザー名

  @override
  void initState() {
    super.initState();
    _loadSavedUsername();
  }

  Future<void> _loadSavedUsername() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('atcoder_username');
      if (!mounted) return;
      setState(() {
        _savedUsername = (saved != null && saved.isNotEmpty) ? saved : null;
        if (_savedUsername != null) {
          _usernameController.text = _savedUsername!;
        }
      });
      // ユーザー名が既に設定されている場合は自動で推薦を取得
      if (mounted && _savedUsername != null && _savedUsername!.isNotEmpty) {
        // 少し遅延してビルド完了後に実行（安全策）
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isLoading && _recommendedProblems.isEmpty) {
            _getRecommendations();
          }
        });
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _getRecommendations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _recommendedProblems = [];
    });

    try {
      // 事前に設定済みのユーザー名を優先
      final username = (_savedUsername != null && _savedUsername!.isNotEmpty)
          ? _savedUsername!
          : _usernameController.text;
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
        title: const Text('おすすめ問題'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_savedUsername == null) ...[
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'AtCoderユーザー名',
                  border: OutlineInputBorder(),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'AtCoderユーザー名: $_savedUsername',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('atcoder_username');
                      if (!mounted) return;
                      setState(() {
                        _savedUsername = null;
                        _usernameController.clear();
                      });
                    },
                    child: const Text('変更'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            if (_savedUsername == null)
              ElevatedButton(
                onPressed: _isLoading ? null : _getRecommendations,
                child: const Text('おすすめを取得'),
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
