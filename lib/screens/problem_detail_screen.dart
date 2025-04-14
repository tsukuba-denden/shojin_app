import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;
// import 'package:latext/latext.dart'; // latext パッケージは削除
import '../models/problem.dart';
import '../services/atcoder_service.dart';

class ProblemDetailScreen extends StatefulWidget {
  final String? initialUrl;
  final Function(String) onProblemChanged; // コールバック関数を追加

  const ProblemDetailScreen({
    super.key,
    this.initialUrl,
    required this.onProblemChanged, // コンストラクタで必須にする
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

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl != null) {
      _urlController.text = widget.initialUrl!;
      _fetchProblem();
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _fetchProblem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final problem = await _atCoderService.fetchProblem(_urlController.text);
      setState(() {
        _problem = problem;
        _isLoading = false;
      });
      // 問題取得成功時にコールバックを呼び出す
      if (_problem != null) {
         developer.log('Problem fetched successfully: ${_problem!.url}', name: 'ProblemDetailScreen'); // id を url に変更
         widget.onProblemChanged(_problem!.url); // id を url に変更
      }
    } catch (e) {
      developer.log('Failed to fetch problem: $e', name: 'ProblemDetailScreen', error: e);
      setState(() {
        _errorMessage = '問題の取得に失敗しました: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Form(
            key: _formKey,
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      labelText: 'AtCoder 問題URL',
                      hintText: 'https://atcoder.jp/contests/コンテスト名/tasks/問題名',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
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
                  onPressed: _isLoading ? null : _fetchProblem,
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
                          SizedBox(width: 8),
                          Text(
                            'エラーが発生しました',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.red[700],
                            ),
                          ),
                          Spacer(),
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
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.all(8),
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
                      SizedBox(height: 8),
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
          if (_problem != null) _buildProblemView(_problem!),
        ],
      ),
    );
  }

  Widget _buildProblemView(Problem problem) {
    return Expanded(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    problem.title,
                    style: const TextStyle(
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
          // 通常テキスト部分 (通常のTextウィジェットに戻す)
          contentWidgets.add(Text(
            _replaceTexCommands(parts[i].trim()), // TeXコマンドを置換
            style: Theme.of(context).textTheme.bodyMedium,
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
      // コードブロックがない場合は通常のTextウィジェットに戻す
      contentWidgets.add(Text(
        _replaceTexCommands(content), // TeXコマンドを置換
        style: Theme.of(context).textTheme.bodyMedium,
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
           ),
           // サンプル出力は通常のTextで表示 (LaTeXとして解釈させない)
           child: Text(sample.output, style: const TextStyle(fontFamily: 'monospace')),
        ),
      ],
    );
  }

  // TeXコマンドを対応するUnicode文字に置換するヘルパーメソッド
  String _replaceTexCommands(String input) {
    return input
        .replaceAll(r'\leq', '≤')
        .replaceAll(r'\geq', '≥')
        .replaceAll(r'\times', '×')
        .replaceAll(r'\dots', '…')
        // 必要に応じて他の置換ルールを追加
        ;
  }
}