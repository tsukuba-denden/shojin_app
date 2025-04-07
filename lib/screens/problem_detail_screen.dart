import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'dart:developer' as developer;
import '../models/problem.dart';
import '../services/atcoder_service.dart';

class ProblemDetailScreen extends StatefulWidget {
  final String? initialUrl;
  
  const ProblemDetailScreen({Key? key, this.initialUrl}) : super(key: key);

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
    } catch (e) {
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
                  _buildTeXTitle(problem.title),
                  const Divider(),
                  _buildTeXSection('問題文', problem.statement),
                  _buildTeXSection('制約', problem.constraints),
                  _buildTeXSection('入力', problem.inputFormat),
                  _buildTeXSection('出力', problem.outputFormat),
                  ...problem.samples.map((sample) => _buildSampleIO(sample)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // タイトルをTeXとして表示
  Widget _buildTeXTitle(String title) {
    try {
      return Math.tex(
        title,
        textStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        onErrorFallback: (error) {
          return Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          );
        },
      );
    } catch (e) {
      return Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      );
    }
  }

  // セクションをTeXとして表示（コードブロック処理を含む）
  Widget _buildTeXSection(String title, String content) {
    if (content.isEmpty) return const SizedBox.shrink();
    
    // デバッグ情報
    developer.log('セクション[$title]の内容: $content');
    
    // 入力形式のフォーマット処理
    List<Widget> contentWidgets = [];
    
    // コードブロックと通常テキストを分離
    final parts = content.split(RegExp(r'```'));
    
    // パートが複数ある場合（コードブロックが含まれている場合）
    if (parts.length > 1) {
      for (int i = 0; i < parts.length; i++) {
        if (parts[i].trim().isEmpty) continue;
        
        if (i % 2 == 0) {
          // 通常テキスト部分 - TeXとして表示
          contentWidgets.add(_renderTeXWithParagraphSupport(parts[i].trim()));
        } else {
          // コードブロック部分 - そのまま表示
          contentWidgets.add(
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
              ),
              child: SelectableText(
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
      // コードブロックがない場合は全体をTeXとして処理
      contentWidgets.add(_renderTeXWithParagraphSupport(content));
    }
    
    // セクション全体の構築
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        // セクションタイトルには通常テキストを使用
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

  // 段落ごとにTeXレンダリングを行う（改行を保持）
  Widget _renderTeXWithParagraphSupport(String text) {
    // 段落で分割
    final paragraphs = text.split(RegExp(r'\n\s*\n'));
    List<Widget> paragraphWidgets = [];
    
    for (var paragraph in paragraphs) {
      if (paragraph.trim().isEmpty) continue;
      
      // 段落内の各行を取得（単一改行を処理）
      final lines = paragraph.split('\n');
      List<Widget> lineWidgets = [];
      
      for (var line in lines) {
        if (line.trim().isEmpty) {
          lineWidgets.add(const SizedBox(height: 4));
          continue;
        }
        
        // 行内の数式記号を検出
        final hasMathMarkers = line.contains(r'$') || 
                              line.contains(r'\begin{') || 
                              line.contains(r'\end{') ||
                              line.contains(r'\frac') ||
                              line.contains(r'\sum');
        
        try {
          if (hasMathMarkers) {
            // 行内に数式記号がある場合はTeX処理
            lineWidgets.add(
              Container(
                width: double.infinity,
                alignment: Alignment.centerLeft,
                margin: const EdgeInsets.only(bottom: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Math.tex(
                    line.trim(),
                    textStyle: const TextStyle(fontSize: 16),
                    onErrorFallback: (error) {
                      return Text(line.trim());
                    },
                    overflow: TextOverflow.visible,
                    mathStyle: MathStyle.text,
                  ),
                ),
              )
            );
          } else {
            // 数式記号がない場合は通常のテキストとして処理
            lineWidgets.add(
              Container(
                width: double.infinity,
                alignment: Alignment.centerLeft,
                margin: const EdgeInsets.only(bottom: 4),
                child: Text(
                  line.trim(),
                  style: const TextStyle(fontSize: 16),
                  overflow: TextOverflow.clip,
                ),
              )
            );
          }
        } catch (e) {
          // パースエラーのフォールバック
          lineWidgets.add(
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 4),
              child: Text(line.trim()),
            )
          );
        }
      }
      
      // 段落全体をグループ化
      paragraphWidgets.add(
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lineWidgets,
          ),
        )
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphWidgets,
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
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(4),
          ),
          child: SelectableText(
            sample.input, 
            style: const TextStyle(fontFamily: 'monospace'),
          ),
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
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(4),
          ),
          child: SelectableText(
            sample.output, 
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }
}