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
  final _lowerDeltaController = TextEditingController();
  final _upperDeltaController = TextEditingController();
  List<MapEntry<String, ProblemDifficulty>> _recommendedProblems = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _savedUsername; // 設定済みユーザー名
  int? _currentRating; // 取得したレート

  // AtCoder カラー判定
  Color _ratingColor(int rating) {
    if (rating >= 2800) return const Color(0xFFFF0000); // 赤
    if (rating >= 2400) return const Color(0xFFFF8000); // 橙
    if (rating >= 2000) return const Color(0xFFC0C000); // 黄
    if (rating >= 1600) return const Color(0xFF0000FF); // 青
    if (rating >= 1200) return const Color(0xFF00C0C0); // 水
    if (rating >= 800) return const Color(0xFF008000);  // 緑
    if (rating >= 400) return const Color(0xFF804000); // 茶
    return const Color(0xFF808080); // 灰
  }

  @override
  void initState() {
    super.initState();
    // 推薦条件のデフォルト（±100）
    _lowerDeltaController.text = '-100';
    _upperDeltaController.text = '100';
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
    _lowerDeltaController.dispose();
    _upperDeltaController.dispose();
    super.dispose();
  }

  Future<void> _getRecommendations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _recommendedProblems = [];
      _currentRating = null;
    });

    try {
      // 条件の取得とバリデーション
      int lowerDelta = int.tryParse(_lowerDeltaController.text.trim()) ?? -100;
      int upperDelta = int.tryParse(_upperDeltaController.text.trim()) ?? 100;
      if (lowerDelta > upperDelta) {
        // 入力が逆の場合は入れ替え
        final tmp = lowerDelta;
        lowerDelta = upperDelta;
        upperDelta = tmp;
      }

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

      // レートを保存してUIに表示
      if (mounted) {
        setState(() {
          _currentRating = rating;
        });
      }

      final allProblems = await _atcoderService.fetchProblemDifficulties();

      final recommended = allProblems.entries.where((entry) {
        final difficulty = entry.value.difficulty;
        return difficulty != null &&
            difficulty >= rating + lowerDelta &&
            difficulty <= rating + upperDelta;
      }).toList();

      // 自分のレートに近い順に並べ替え（差の絶対値の昇順）
      recommended.sort((a, b) {
        final da = (a.value.difficulty! - rating).abs();
        final db = (b.value.difficulty! - rating).abs();
        final cmp = da.compareTo(db);
        if (cmp != 0) return cmp;
        // 差が同じ場合は難易度の昇順で安定化
        return a.value.difficulty!.compareTo(b.value.difficulty!);
      });

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
                        _currentRating = null;
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
            const SizedBox(height: 8),
            if (_currentRating != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '現在のレート: $_currentRating',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _ratingColor(_currentRating!),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            // 推薦条件入力（レートとの差分の下限/上限）
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _lowerDeltaController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '下限差 (例: -100)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _upperDeltaController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '上限差 (例: 100)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _getRecommendations,
                  child: const Text('条件で再取得'),
                ),
              ],
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
