import 'package:flutter/foundation.dart';
import '../models/contest.dart';
import '../services/contest_service.dart';

class ContestProvider with ChangeNotifier {
  final ContestService _contestService = ContestService();
  
  Contest? _nextABC;
  List<Contest> _upcomingABCs = [];
  List<Contest> _upcomingContests = [];
  bool _isLoading = false;
  String? _error;

  Contest? get nextABC => _nextABC;
  List<Contest> get upcomingABCs => _upcomingABCs;
  List<Contest> get upcomingContests => _upcomingContests;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 次回のABCを取得
  Future<void> fetchNextABC() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _nextABC = await _contestService.getNextABC();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 今後のABCを取得
  Future<void> fetchUpcomingABCs() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _upcomingABCs = await _contestService.getUpcomingABCs();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// すべての今後のコンテストを取得
  Future<void> fetchUpcomingContests() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _upcomingContests = await _contestService.getUpcomingContests();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// すべてのデータをリフレッシュ
  Future<void> refreshAll() async {
    await Future.wait([
      fetchNextABC(),
      fetchUpcomingABCs(),
      fetchUpcomingContests(),
    ]);
  }
}
