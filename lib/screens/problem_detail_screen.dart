import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;
import '../models/problem.dart';
import '../services/atcoder_service.dart';
import '../widgets/tex_widget.dart';

class ProblemDetailScreen extends StatefulWidget {
  final String? initialUrl; // Keep for potential direct URL loading
  final String? problemIdToLoad; // New: ID passed from MainScreen via ProblemsScreen
  final Function(String) onProblemChanged;

  const ProblemDetailScreen({
    super.key,
    this.initialUrl,
    this.problemIdToLoad, // Add to constructor
    required this.onProblemChanged,
  });

  @override
  State<ProblemDetailScreen> createState() => _ProblemDetailScreenState();
}

class _ProblemDetailScreenState extends State<ProblemDetailScreen> {
  final _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _atCoderService = AtCoderService();

  Problem? _problem;
  bool _isLoading = false;
  String? _errorMessage;
  String? _lastLoadedProblemId; // Track the last ID loaded via problemIdToLoad

  @override
  void initState() {
    super.initState();
    developer.log('ProblemDetailScreen initState: initialUrl=${widget.initialUrl}, problemIdToLoad=${widget.problemIdToLoad}', name: 'ProblemDetailScreen');
    if (widget.problemIdToLoad != null && widget.problemIdToLoad != 'default_problem') {
       _loadProblemFromId(widget.problemIdToLoad!);
    } else if (widget.initialUrl != null) {
      _urlController.text = widget.initialUrl!;
      _fetchProblem(); // Fetch based on initial URL
    }
  }

  @override
  void didUpdateWidget(ProblemDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    developer.log('ProblemDetailScreen didUpdateWidget: new problemIdToLoad=${widget.problemIdToLoad}, old problemIdToLoad=${oldWidget.problemIdToLoad}, lastLoaded=$_lastLoadedProblemId', name: 'ProblemDetailScreen');
    // Check if problemIdToLoad changed, is not null, not default, and different from the last one loaded this way
    if (widget.problemIdToLoad != null &&
        widget.problemIdToLoad != 'default_problem' &&
        widget.problemIdToLoad != _lastLoadedProblemId) {
       developer.log('Triggering load from problemIdToLoad: ${widget.problemIdToLoad}', name: 'ProblemDetailScreen');
      _loadProblemFromId(widget.problemIdToLoad!);
    }
  }

  // New method to construct URL and fetch based on problemId
  void _loadProblemFromId(String problemId) {
    // Construct the URL (e.g., abc388_a -> https://atcoder.jp/contests/abc388/tasks/abc388_a)
    final parts = problemId.split('_');
    if (parts.length < 2) {
       developer.log('Invalid problemId format: $problemId', name: 'ProblemDetailScreen');
       setState(() {
         _errorMessage = '無効な問題ID形式です: $problemId';
       });
       return;
    }
    // Heuristic: Assume the part before the last underscore is the contest ID
    // This might fail for IDs like 'arc100_a_example'. Needs robust parsing if IDs vary.
    // Let's assume standard format like 'abcXXX_Y' or 'arcXXX_Y'
    final contestId = parts.first; // Simpler assumption: first part is contest ID
    final taskId = problemId; // The full ID is the task ID in the URL
    final url = 'https://atcoder.jp/contests/$contestId/tasks/$taskId';

    developer.log('Constructed URL from ID $problemId: $url', name: 'ProblemDetailScreen');

    // Update the text field and trigger fetch
    _urlController.text = url;
    _lastLoadedProblemId = problemId; // Mark this ID as being loaded
    _fetchProblem(); // Fetch using the updated URL in the controller
  }


  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _fetchProblem() async {
    // Validate using the controller's text, which is now set correctly
    // Use a temporary form key or validate directly if needed without relying on user interaction
    // For automatic fetch, let's bypass the form validation for simplicity,
    // assuming the constructed URL is valid. Add validation if needed.
    // if (!_formKey.currentState!.validate()) return; // Skip form validation for automatic fetch

    final urlToFetch = _urlController.text;
    if (!_atCoderService.isValidAtCoderUrl(urlToFetch)) {
       developer.log('Invalid URL constructed or entered: $urlToFetch', name: 'ProblemDetailScreen');
       setState(() {
         _errorMessage = '無効なAtCoder URLです: $urlToFetch';
         _isLoading = false; // Ensure loading indicator stops
       });
       return;
    }


    setState(() {
      _isLoading = true;
      _errorMessage = null;
      // Clear previous problem when starting fetch? Optional.
      // _problem = null;
    });

    developer.log('Fetching problem from URL: $urlToFetch', name: 'ProblemDetailScreen');

    try {
      final problem = await _atCoderService.fetchProblem(urlToFetch);
      setState(() {
        _problem = problem;
        _isLoading = false;
        // Reset last loaded ID if fetch fails? Or keep it?
      });
      // Problem fetched successfully, call the callback to update EditorScreen
      if (_problem != null) {
         developer.log('Problem fetched successfully: ${_problem!.url}', name: 'ProblemDetailScreen');
         // Pass the *original URL* that was successfully fetched back up
         widget.onProblemChanged(_problem!.url);
      }
    } catch (e) {
      developer.log('Failed to fetch problem: $e', name: 'ProblemDetailScreen', error: e);
      setState(() {
        _errorMessage = '問題の取得に失敗しました: $e\nURL: $urlToFetch'; // Include URL in error
        _isLoading = false;
        // Reset last loaded ID on failure so retry is possible?
        // _lastLoadedProblemId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column( // Consider using ListView for better scrolling if content overflows
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Form(
            key: _formKey, // Keep form key for manual input validation
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _urlController, // Controller is updated automatically now
                    decoration: const InputDecoration(
                      labelText: 'AtCoder 問題URL',
                      hintText: 'https://atcoder.jp/contests/コンテスト名/tasks/問題名',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) { // Validator for manual input
                      if (value == null || value.isEmpty) {
                        return 'URLを入力してください';
                      }
                      if (!_atCoderService.isValidAtCoderUrl(value)) {
                        return '正しいAtCoderの問題URLを入力してください';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  // Trigger manual fetch using the current text in the controller
                  onPressed: _isLoading ? null : () {
                      // Manually trigger fetch only if form is valid
                      if (_formKey.currentState!.validate()) {
                          _lastLoadedProblemId = null; // Reset auto-load tracking for manual fetch
                         _fetchProblem();
                      }
                  },
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('取得'),
                ),
              ],
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red[700]),
                          const SizedBox(width: 8),
                          Text(
                            'エラーが発生しました',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.red[700],
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(Icons.copy, color: Colors.red[700]),
                            tooltip: 'エラーメッセージをコピー',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _errorMessage!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('エラーメッセージをコピーしました'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        width: double.infinity,
                        child: SelectableText(
                          _errorMessage!,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: Colors.red[900],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'URLが正しいことを確認し、もう一度お試しください。',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_isLoading)
            const Expanded( // Use Expanded if inside Column
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_problem != null)
             Expanded( // Use Expanded if inside Column
               child: _buildProblemView(_problem!),
             )
          else if (!_isLoading && _errorMessage == null)
             const Expanded(
               child: Center(child: Text('問題URLを入力またはWebViewから選択してください。')),
             ),
        ],
      ),
    );
  }

  Widget _buildProblemView(Problem problem) {
    // MediaQueryを使用して、下部のナビゲーションバーの高さを取得
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SingleChildScrollView(
      // 下部にパディングを追加して、コンテンツが隠れないようにする
      padding: EdgeInsets.only(bottom: bottomPadding > 0 ? bottomPadding : 16),
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TexWidget(
                  content: problem.title,
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(),
                _buildSection('問題文', problem.statement),
                _buildSection('制約', problem.constraints),
                _buildSection('入力', problem.inputFormat),
                _buildSection('出力', problem.outputFormat),
                ...problem.samples.map((sample) => _buildSampleIO(sample)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    if (content.isEmpty) return const SizedBox.shrink();
    
    // デバッグ情報
    developer.log('セクション[$title]の内容: $content');
    
    // 入力形式のフォーマット処理
    List<Widget> contentWidgets = [];
    final parts = content.split(RegExp(r'```'));
    
    // パートが複数ある場合（コードブロックが含まれている場合） 
    if (parts.length > 1) {
      for (int i = 0; i < parts.length; i++) {
        if (parts[i].trim().isEmpty) continue;
        
        if (i % 2 == 0) {
          // 通常テキスト部分 - TeXレンダリングを使用
          contentWidgets.add(TexWidget(
            content: parts[i].trim(),
            textStyle: Theme.of(context).textTheme.bodyMedium,
          ));
        } else {
          // コードブロック部分
          contentWidgets.add(
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
              ),
              child: Text(
                parts[i].trim(), 
                style: const TextStyle(
                  fontFamily: 'monospace',
                ),
              ),
            )
          );
        }
      }
    } else {
      // コードブロックがない場合もTeXレンダリングを使用
      contentWidgets.add(TexWidget(
        content: content,
        textStyle: Theme.of(context).textTheme.bodyMedium,
      ));
    }
    
    // セクション全体の構築
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...contentWidgets,
      ],
    );
  }

  Widget _buildSampleIO(SampleIO sample) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              '入力例 ${sample.index}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              tooltip: '入力例をコピー',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: sample.input));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('入力例をコピーしました')),
                );
              },
            ),
          ],
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
          ),
          // サンプル入力は通常のTextで表示 (LaTeXとして解釈させない)
          child: Text(sample.input, style: const TextStyle(fontFamily: 'monospace')),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '出力例 ${sample.index}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              tooltip: '出力例をコピー',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: sample.output));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('出力例をコピーしました')),
                );
              },
            ),
          ],
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
          ),
          // サンプル出力は通常のTextで表示 (LaTeXとして解釈させない)
          child: Text(sample.output, style: const TextStyle(fontFamily: 'monospace')),
        ),
      ],
    );
  }
}