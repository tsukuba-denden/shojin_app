import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shojin_app/services/contest_service.dart';
import 'package:shojin_app/models/contest.dart';
import 'package:url_launcher/url_launcher.dart';

class NextContestCard extends StatefulWidget {
  const NextContestCard({super.key});

  @override
  State<NextContestCard> createState() => _NextContestCardState();
}

class _NextContestCardState extends State<NextContestCard> {
  final ContestService _contestService = ContestService();
  Contest? _nextAbcContest;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchNextAbcContest();
  }

  Future<void> _fetchNextAbcContest() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final contests = await _contestService.fetchContests();
      // Find the next ABC contest
      try {
        _nextAbcContest = contests.firstWhere(
          (contest) =>
              contest.title.startsWith('AtCoder Beginner Contest') &&
              contest.startTime.isAfter(DateTime.now()),
        );
      } catch (e) {
        // Handles StateError if no matching contest is found
        _nextAbcContest = null;
      }
    } catch (e) {
      _errorMessage = 'コンテスト情報の取得に失敗しました: $e';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showContestDetails() async {
    // Navigate to a new screen or show a dialog with all contest info
    // For now, let's just print to console or show a simple dialog
    if (_nextAbcContest != null) {
      // ignore: deprecated_member_use
      if (await canLaunch(_nextAbcContest!.url)) {
        // ignore: deprecated_member_use
        await launch(_nextAbcContest!.url);
      } else {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('URLを開けませんでした: ${_nextAbcContest!.url}')),
        );
      }
    } else {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('表示するコンテスト情報がありません。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: InkWell(
        onTap: _showContestDetails,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                  : _nextAbcContest != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nextAbcContest!.title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8.0),
                            Text(
                              '開催日時: ${_nextAbcContest!.startTime.toLocal()}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8.0),
                            Text(
                              'タップして詳細を表示',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                            ),
                          ],
                        )
                      : Center(
                          child: Text(
                            '次回のABCの情報は見つかりませんでした。',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
        ),
      ),
    );
  }
}
