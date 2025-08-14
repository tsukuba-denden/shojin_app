import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/problem_difficulty.dart';
import '../services/atcoder_service.dart';
import 'problem_detail_screen.dart';
import '../utils/atcoder_colors.dart';
import '../utils/rating_utils.dart';

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
  int? _currentRating; // 取得したレート（表示用: 最新レート）

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

  // レート表示用バッジ
  Widget _ratingBadge(int rating) {
    final color = _ratingColor(rating);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            rating.toString(),
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // Difficulty 表示用バッジ（補正後diffで表示。色も補正後ベース）
  Widget _difficultyBadge(int? difficulty) {
    int? mappedInt;
    if (difficulty != null) {
      final mapped = difficulty <= 400
          ? RatingUtils.mapRating(difficulty)
          : difficulty.toDouble();
      mappedInt = mapped.round();
    }
    final color = (mappedInt != null)
        ? atcoderRatingToColor(mappedInt)
        : const Color(0xFF808080);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            mappedInt?.toString() ?? 'N/A',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
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
      
      final ratingInfo = await _atcoderService.fetchAtcoderRatingInfo(username);
      if (ratingInfo == null) {
        throw Exception('ユーザーが見つからないか、レーティングがありません');
      }

      // レートを保存してUIに表示
      if (mounted) {
        setState(() {
          _currentRating = ratingInfo.latestRating;
        });
      }

      final allProblems = await _atcoderService.fetchProblemDifficulties();
      // TrueRating を計算（数式(10)）
      final trueRating = RatingUtils.trueRating(
        rating: ratingInfo.latestRating,
        contests: ratingInfo.contestCount,
      );

      final recommended = allProblems.entries.where((entry) {
        final difficulty = entry.value.difficulty;
        if (difficulty == null) return false;
        // 400 以下の diff は mapRating で補正（比較用のみ）
        final mappedDiff = difficulty <= 400
            ? RatingUtils.mapRating(difficulty)
            : difficulty.toDouble();
        return mappedDiff >= trueRating + lowerDelta &&
            mappedDiff <= trueRating + upperDelta;
      }).toList();

      // 自分のレートに近い順に並べ替え（差の絶対値の昇順）
      recommended.sort((a, b) {
        final ad = a.value.difficulty!;
        final bd = b.value.difficulty!;
        final mad = ad <= 400 ? RatingUtils.mapRating(ad) : ad.toDouble();
        final mbd = bd <= 400 ? RatingUtils.mapRating(bd) : bd.toDouble();
        final da = (mad - trueRating).abs();
        final db = (mbd - trueRating).abs();
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
                  if (_currentRating != null) ...[
                    _ratingBadge(_currentRating!),
                    const SizedBox(width: 8),
                  ],
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
            const SizedBox(height: 12),
            if (_savedUsername == null)
              ElevatedButton(
                onPressed: _isLoading ? null : _getRecommendations,
                child: const Text('おすすめを取得'),
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
                    final diff = problem.value.difficulty;
                    return ListTile(
                      title: Text(problem.key),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _difficultyBadge(diff),
                          const SizedBox(width: 8),
                          const Icon(Icons.open_in_new),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProblemDetailScreen(
                              problemIdToLoad: problem.key,
                              onProblemChanged: (_) {},
                            ),
                          ),
                        );
                      },
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
