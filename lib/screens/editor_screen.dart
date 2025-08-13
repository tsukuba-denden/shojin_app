import 'dart:async'; // TimeoutExceptionのために追加
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboardのために追加
import 'package:share_plus/share_plus.dart'; // コード共有用
import 'package.flutter_code_editor/flutter_code_editor.dart';
// ハイライト言語のインポートを修正
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/cpp.dart'; // clike.dart から cpp.dart に修正
import 'package:highlight/languages/rust.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/dart.dart'; // デフォルト用
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:http/http.dart' as http; // HTTPリクエスト用
import 'package:provider/provider.dart';
import '../models/problem.dart';
import '../models/test_result.dart';
import '../services/atcoder_service.dart';
import '../providers/theme_provider.dart';
import '../utils/text_style_helper.dart';
import 'dart:developer' as developer; // developerログのために追加
import 'submit_screen.dart'; // 提出画面を表示するWebViewスクリーン
import '../services/code_history_service.dart';
import 'code_history_screen.dart';

// 3点メニュー用のアクション列挙体（トップレベルに定義）
enum _ToolbarAction { runTests, save, history, restore, reset, share }

class EditorScreen extends StatefulWidget {
  final String problemId; // 問題IDを追加

  const EditorScreen({
    super.key,
    required this.problemId, // コンストラクタで受け取る
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  // コードエディタのコントローラー
  late final CodeController _codeController; // late final のまま
  // 標準入力用コントローラー
  final TextEditingController _stdinController = TextEditingController();
  // 実行結果表示用
  String _output = '';
  String _error = '';
  bool _isRunning = false; // 実行中フラグ
  bool _isTesting = false; // テスト実行中フラグ
  List<TestResult> _testResults = []; // テスト結果リスト
  Problem? _currentProblem; // 現在の問題データ
  final AtCoderService _atcoderService = AtCoderService(); // AtCoderServiceインスタンス
  final CodeHistoryService _codeHistoryService = CodeHistoryService();
  Timer? _debounce;
  // ダイアログの状態更新用 GlobalKey (StatefulBuilder を使う場合)
  final GlobalKey<State> _testResultsDialogKey = GlobalKey<State>();

  // 言語選択用
  String _selectedLanguage = 'Python';
  // C#をリストから削除
  final List<String> _languages = ['Python', 'C++', 'Rust', 'Java'];

  // ダークモードか確認するための変数
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  bool _isLoadingCode = true; // コード読み込み中フラグ

  @override
  void initState() {
    super.initState();
    // CodeController を初期化する際に、選択されている言語のハイライトを設定
    _codeController = CodeController(
      language: _getHighlightLanguage(_selectedLanguage), // 修正
      text: '// Loading code...',
    );
    _loadSavedCode();
    _loadProblemData(); // 問題データを読み込む
    _codeController.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    _codeController.removeListener(_onCodeChanged);
    _debounce?.cancel();
    _codeController.dispose();
    _stdinController.dispose();
    super.dispose();
  }

  void _onCodeChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      _saveHistory();
    });
  }

  Future<void> _saveHistory() async {
    if (widget.problemId.isEmpty || widget.problemId == 'default_problem') {
      return;
    }
    await _codeHistoryService.saveHistory(widget.problemId, _codeController.text);
  }

  Future<String> _getFilePath() async {
    if (_currentProblem == null) {
      // 問題がロードされていない場合はデフォルトのパスを返す
      return '';
    }
    final directory = await getApplicationDocumentsDirectory();
    final contestId = _currentProblem!.contestId;
    // 問題タイトルからファイル名として不適切な文字を削除・置換
    final problemTitle = _currentProblem!.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final extension = _getExtension(_selectedLanguage);
    final path = '${directory.path}/$contestId/$problemTitle/main.$extension';
    return path;
  }

  String _getExtension(String language) {
    switch (language) {
      case 'Python':
        return 'py';
      case 'C++':
        return 'cpp';
      case 'Rust':
        return 'rs';
      case 'Java':
        return 'java';
      default:
        return 'txt';
    }
  }

  // 保存されたコードを読み込む関数
  Future<void> _loadSavedCode() async {
    setState(() {
      _isLoadingCode = true;
    });
    try {
      final filePath = await _getFilePath();
      if (filePath.isEmpty) {
        _codeController.text = _getTemplateForLanguage(_selectedLanguage);
        return;
      }
      final file = File(filePath);
      if (await file.exists()) {
        final savedCode = await file.readAsString();
        _codeController.text = savedCode;
      } else {
        _codeController.text = _getTemplateForLanguage(_selectedLanguage);
      }
    } catch (e) {
      developer.log("コードの読み込みに失敗しました: $e", name: 'EditorScreen');
      // エラー時もテンプレートを設定
      _codeController.text = _getTemplateForLanguage(_selectedLanguage);
    } finally {
      if(mounted) {
        setState(() {
          _isLoadingCode = false;
        });
      }
    }
  }

  // 現在のコードを保存する関数
  Future<void> _saveCode() async {
    try {
      final filePath = await _getFilePath();
      if (filePath.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('問題がロードされていないため保存できません')),
        );
        return;
      }
      final file = File(filePath);
      // ディレクトリが存在しない場合は作成
      await file.parent.create(recursive: true);
      await file.writeAsString(_codeController.text);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('コードを $filePath に保存しました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('コードの保存に失敗しました: $e')),
      );
    }
  }

  // 言語名から highlight パッケージの言語オブジェクトを取得するヘルパー関数
  dynamic _getHighlightLanguage(String language) {
    switch (language) {
      case 'Python':
        return python;
      case 'C++':
        return cpp; // clike を cpp として使用
      case 'Rust':
        return rust;
      case 'Java':
        return java;
      default:
        return dart; // 不明な場合は dart または plaintext
    }
  }

  // 言語が変更されたときの処理
  void _onLanguageChanged(String? newLanguage) {
    if (newLanguage != null && newLanguage != _selectedLanguage) {
      // コードを保存するかユーザーに確認するなどの処理を追加しても良い
      setState(() {
        _selectedLanguage = newLanguage;
        // CodeController の言語も更新
        _codeController.language = _getHighlightLanguage(_selectedLanguage);
        developer.log('Language changed to: $_selectedLanguage, loading code...', name: 'EditorScreen');
        _loadSavedCode(); // 新しい言語に対応するコードを読み込む
      });
    }
  }

  // 選択した言語に基づいてコードのテンプレートを取得
  String _getTemplateForLanguage(String language) {
    switch (language) {
      case 'C++':
        return '''#include <iostream>
using namespace std;

int main() {
    int n;
    cin >> n;
    cout << "Hello World!" << endl;
    return 0;
}''';
      case 'Python':
        return '''n = int(input())
print("Hello World!")''';
      case 'Rust':
        return '''use std::io;
fn main() {
   let mut input = String::new();
   io::stdin().read_line(&mut input).expect("Failed to read line");
   println!("Hello World!");
}''';
      case 'Java':
        return '''import java.util.Scanner;
public class Main {
   public static void main(String[] args) {
       Scanner sc = new Scanner(System.in);
       int n = sc.nextInt();
       System.out.println("Hello World!");
   }
}''';
      default:
        return '// ここにコードを書いてください';
    }
  }

  // Wandbox APIが要求する言語名を取得
  String _getWandboxLanguageName(String language) {
    switch (language) {
      case 'C++':
        return 'gcc-13.2.0'; // 例: 最新のGCC
      case 'Python':
        return 'cpython-3.12.7'; // 例: Python 3.12
      case 'Rust':
        return 'rust-1.70.0'; // 例: Rust 1.70
      case 'Java':
        return 'openjdk-jdk-22+36'; // 例: OpenJDK jdk-22+36
      default:
        // デフォルトもバージョン指定にしてみる
        return 'cpython-3.11.0';
    }
  }

  // Wandbox APIを使用してコードを実行する関数
  Future<void> _runCode() async {
    if (_isRunning) return; // 実行中なら何もしない

    setState(() {
      _isRunning = true;
      _output = '実行中...';
      _error = '';
    });

    final url = Uri.parse('https://wandbox.org/api/compile.json');
    final wandboxLanguage = _getWandboxLanguageName(_selectedLanguage);
    final code = _codeController.text;
    final stdin = _stdinController.text;

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'code': code,
          'compiler': wandboxLanguage,
          'stdin': stdin,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        setState(() {
          _output = result['program_output'] ?? '';
          _error = result['program_error'] ?? '';
          // コンパイルエラーなどもerrorに含まれる場合がある
          final compilerError = result['compiler_error'];
          if (compilerError != null && compilerError.isNotEmpty) {
             // 文字列補間を使って安全に結合
             _error += "\n--- Compiler Error ---\n$compilerError";
          }
        });
      } else {
        setState(() {
          // 文字列補間を使って安全に結合
          _error = 'APIエラー: ${response.statusCode}\n${response.body}';
          _output = '';
        });
      }
    } catch (e) {
      setState(() {
        // 文字列補間を使って安全に結合
        _error = '通信エラー: $e';
        _output = '';
      });
    } finally {
      if(mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  // 現在のコードを復元する関数
  Future<void> _restoreCode() async {
    try {
      final filePath = await _getFilePath();
      if (filePath.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('問題がロードされていないため復元できません')),
        );
        return;
      }
      final file = File(filePath);
      if (await file.exists()) {
        final savedCode = await file.readAsString();
        setState(() {
          _codeController.text = savedCode;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$_selectedLanguage のコードを復元しました')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存されたコードが見つかりません')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('コードの復元に失敗しました: $e')),
      );
    }
  }

  // 問題データを読み込む関数
  Future<void> _loadProblemData() async {
    if (widget.problemId == 'default_problem') {
      developer.log("Default problem ID detected, skipping problem data load.", name: 'EditorScreen');
      if (mounted) {
        setState(() {
          _isLoadingCode = false;
        });
      }
      return;
    }
    if (_currentProblem != null) return;

    try {
      String url = widget.problemId;
      if (!url.startsWith('http')) {
        final parts = widget.problemId.split('_');
        if (parts.isEmpty) {
          developer.log("Invalid problem ID format: ${widget.problemId}", name: 'EditorScreen');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('無効な問題ID形式です: ${widget.problemId}')),
            );
          }
          return;
        }
        final contestId = parts[0];
        url = 'https://atcoder.jp/contests/$contestId/tasks/${widget.problemId}';
      }

      final problem = await _atcoderService.fetchProblem(url);
      if (mounted) {
        setState(() {
          _currentProblem = problem;
        });
      }
    } catch (e) {
      developer.log("Failed to load problem data for testing: $e", name: 'EditorScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('テストケースの読み込みに失敗しました: $e')),
        );
      }
    }
  }
  
  // Wandbox APIを使用して単一のテストケースを実行する内部関数
  Future<TestResult> _runSingleTest(TestResult testCase, String code, String wandboxLanguage, Function(VoidCallback) setDialogState) async {
    setDialogState(() {
      testCase.status = JudgeStatus.running;
    });

    final url = Uri.parse('https://wandbox.org/api/compile.json');
    try {
      final requestBody = {
        'code': code,
        'compiler': wandboxLanguage,
        'stdin': testCase.input,
        'save': false,
      };
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        testCase.actualOutput = result['program_output'] ?? '';
        testCase.errorOutput = result['program_error'] ?? '';
        final compilerError = result['compiler_error'];
        testCase.exitCode = int.tryParse(result['status']?.toString() ?? '');
        testCase.signal = result['signal']?.toString();

        if (compilerError != null && compilerError.isNotEmpty) {
          testCase.status = JudgeStatus.ce;
          testCase.errorOutput += "\n--- Compiler Error ---\n$compilerError";
        } else if (testCase.signal != null && (testCase.signal!.contains('TLE') || testCase.signal!.contains('Killed') || testCase.signal!.contains('Terminated'))) {
           testCase.status = JudgeStatus.tle;
        } else if (testCase.exitCode != 0) {
          testCase.status = JudgeStatus.re;
        } else if (testCase.errorOutput.isNotEmpty && !testCase.errorOutput.contains("Permission denied")) {
           testCase.status = JudgeStatus.re;
        } else {
          final expected = testCase.expectedOutput.trim().replaceAll('\r\n', '\n');
          final actual = testCase.actualOutput.trim().replaceAll('\r\n', '\n');
          if (expected == actual) {
            testCase.status = JudgeStatus.ac;
          } else {
            testCase.status = JudgeStatus.wa;
          }
        }
      } else {
        testCase.status = JudgeStatus.ie;
        testCase.errorOutput = 'APIエラー: ${response.statusCode}\n${response.body}';
      }
    } on TimeoutException {
       testCase.status = JudgeStatus.tle;
       testCase.errorOutput = '実行リクエストがタイムアウトしました (30秒)。';
    } catch (e) {
      testCase.status = JudgeStatus.ie;
      testCase.errorOutput = 'テスト実行中にエラーが発生しました: $e';
    }

    setDialogState(() {});
    return testCase;
  }

  // 複数のテストケースを実行する関数
  Future<void> _runTests() async {
    if (_isTesting) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('テスト実行中です')),
      );
      return;
    }
    if (_currentProblem == null || _currentProblem!.samples.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(_currentProblem == null ? '問題データがありません' : 'テストケースが見つかりません')),
       );
       return;
    }

    setState(() {
      _isTesting = true;
      _testResults = _currentProblem!.samples.map((sample) => TestResult(
        index: sample.index,
        input: sample.input,
        expectedOutput: sample.output,
      )).toList();
    });

    final code = _codeController.text;
    final wandboxLanguage = _getWandboxLanguageName(_selectedLanguage);
    bool testsStarted = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          key: _testResultsDialogKey,
          builder: (context, setDialogState) {
            if (!testsStarted) {
              testsStarted = true;
              Future.microtask(() async {
                for (int i = 0; i < _testResults.length; i++) {
                  if (_testResultsDialogKey.currentContext == null) {
                     break;
                  }
                  final result = await _runSingleTest(_testResults[i], code, wandboxLanguage, setDialogState);
                  if (result.status == JudgeStatus.ce || result.status == JudgeStatus.re || result.status == JudgeStatus.ie) {
                    break;
                  }
                }
                if (mounted) {
                  setState(() {
                    _isTesting = false;
                  });
                }
                if (_testResultsDialogKey.currentContext != null) {
                   setDialogState(() {});
                }
              });
            }

            return AlertDialog(
              title: Text('テスト実行結果 (${_currentProblem?.title ?? ""})'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _testResults.length,
                  itemBuilder: (context, index) {
                    final result = _testResults[index];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 15,
                        backgroundColor: _getStatusColor(result.status),
                        child: result.status == JudgeStatus.running || result.status == JudgeStatus.pending
                            ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(result.index.toString(), style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                      title: Text('ケース ${result.index}'),
                      subtitle: Text(result.statusLabel),
                      trailing: result.status != JudgeStatus.running && result.status != JudgeStatus.pending
                          ? const Icon(Icons.chevron_right)
                          : null,
                      onTap: result.status == JudgeStatus.running || result.status == JudgeStatus.pending
                          ? null
                          : () => _showResultDetailDialog(result),
                    );
                  },
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: _isTesting ? null : () => Navigator.of(context).pop(),
                  child: const Text('閉じる'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // テスト結果詳細ダイアログ
  void _showResultDetailDialog(TestResult result) {
     showDialog(
        context: context,
        builder: (context) => AlertDialog(
           title: Text('ケース ${result.index} - ${result.statusLabel}'),
           content: SingleChildScrollView(
              child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 mainAxisSize: MainAxisSize.min,
                 children: [
                    _buildDetailSection('入力 (stdin)', result.input),
                    _buildDetailSection('期待される出力 (Expected)', result.expectedOutput),
                    _buildDetailSection('実際の出力 (stdout)', result.actualOutput),
                    if (result.errorOutput.isNotEmpty)
                       _buildDetailSection('エラー出力 (stderr)', result.errorOutput, isError: true),
                    if (result.exitCode != null)
                       Text('終了コード: ${result.exitCode}'),
                    if (result.signal != null)
                       Text('シグナル: ${result.signal}'),
                 ],
              ),
           ),
           actions: [
              TextButton(
                 child: const Text('コピー (入力)'),
                 onPressed: () {
                    Clipboard.setData(ClipboardData(text: result.input));
                    ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('入力をコピーしました')),
                    );
                 },
              ),
              TextButton(
                 child: const Text('閉じる'),
                 onPressed: () => Navigator.of(context).pop(),
              ),
           ],
        ),
     );
  }

  Widget _buildDetailSection(String title, String content, {bool isError = false}) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(8),
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 150),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                content.isEmpty ? '(空)' : content,
                style: getMonospaceTextStyle(
                  themeProvider.codeFontFamily,
                  fontSize: 13,
                  color: isError ? Colors.red : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(JudgeStatus status) {
    switch (status) {
      case JudgeStatus.ac: return Colors.green.shade600;
      case JudgeStatus.wa: return Colors.orange.shade700;
      case JudgeStatus.re:
      case JudgeStatus.tle:
      case JudgeStatus.ce:
      case JudgeStatus.ie: return Colors.red.shade600;
      case JudgeStatus.running: return Colors.blue.shade600;
      case JudgeStatus.pending: return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final codeFontFamily = themeProvider.codeFontFamily;
        final bool isLoadingProblem = _isLoadingCode || (widget.problemId != 'default_problem' && _currentProblem == null);
        final bool isButtonDisabled = isLoadingProblem || _isTesting || _currentProblem == null || (_currentProblem?.samples.isEmpty ?? true);

        final double systemBottomInset = MediaQuery.of(context).padding.bottom;
        final bool isM3 = Theme.of(context).useMaterial3;
        final double navBarHeight = isM3 ? 0.0 : kBottomNavigationBarHeight;

        return Padding(
          padding: EdgeInsets.only(bottom: systemBottomInset + navBarHeight + 8),
          child: Column(
          children: [
            if (_currentProblem != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.assignment, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_currentProblem!.contestName} · ${_currentProblem!.title}',
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('言語: ', style: TextStyle(fontSize: 14)),
                      DropdownButton<String>(
                        value: _selectedLanguage,
                        isDense: true,
                        underline: Container(height: 1, color: Colors.grey),
                        onChanged: _onLanguageChanged,
                        items: _languages.map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value, style: const TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  PopupMenuButton<_ToolbarAction>(
                    icon: const Icon(Icons.more_vert),
                    tooltip: 'その他',
                    onSelected: (action) async {
                      switch (action) {
                        case _ToolbarAction.runTests:
                          if (!isButtonDisabled) {
                            _runTests();
                          }
                          break;
                        case _ToolbarAction.save:
                          _saveCode();
                          break;
                        case _ToolbarAction.history:
                          if (widget.problemId.isEmpty || widget.problemId == 'default_problem') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No problem selected.')),
                            );
                            break;
                          }
                          final restoredCode = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CodeHistoryScreen(problemId: widget.problemId),
                            ),
                          );
                          if (restoredCode != null && restoredCode is String) {
                            setState(() {
                              _codeController.text = restoredCode;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Code restored from history.')),
                            );
                          }
                          break;
                        case _ToolbarAction.restore:
                          _restoreCode();
                          break;
                        case _ToolbarAction.reset:
                          _codeController.text = _getTemplateForLanguage(_selectedLanguage);
                          _stdinController.clear();
                          setState(() {
                            _output = '';
                            _error = '';
                          });
                          break;
                        case _ToolbarAction.share:
                          final code = _codeController.text;
                          if (code.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('共有するコードがありません')),
                            );
                            break;
                          }
                          String textToShare = code;
                          if (_currentProblem != null) {
                            textToShare = '${_currentProblem!.title} ($_selectedLanguage)\n\n$code';
                          }
                          SharePlus.instance.share(
                            ShareParams(text: textToShare),
                          );
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<_ToolbarAction>(
                        value: _ToolbarAction.runTests,
                        enabled: !isButtonDisabled,
                        child: Row(
                          children: [
                            const Icon(Icons.checklist_rtl),
                            const SizedBox(width: 8),
                            Text(_isTesting ? 'テスト実行中…' : 'テスト実行 (サンプルケース)'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem<_ToolbarAction>(
                        value: _ToolbarAction.save,
                        child: Row(
                          children: const [Icon(Icons.save_alt), SizedBox(width: 8), Text('保存')],
                        ),
                      ),
                      PopupMenuItem<_ToolbarAction>(
                        value: _ToolbarAction.history,
                        child: Row(
                          children: const [Icon(Icons.history), SizedBox(width: 8), Text('コード履歴')],
                        ),
                      ),
                      PopupMenuItem<_ToolbarAction>(
                        value: _ToolbarAction.restore,
                        child: Row(
                          children: const [Icon(Icons.settings_backup_restore), SizedBox(width: 8), Text('復元')],
                        ),
                      ),
                      PopupMenuItem<_ToolbarAction>(
                        value: _ToolbarAction.reset,
                        child: Row(
                          children: const [Icon(Icons.replay), SizedBox(width: 8), Text('リセット')],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem<_ToolbarAction>(
                        value: _ToolbarAction.share,
                        child: Row(
                          children: const [Icon(Icons.share), SizedBox(width: 8), Text('コード共有')],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (isLoadingProblem)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                flex: 3,
                child: Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4.0),
                    child: CodeTheme(
                      data: CodeThemeData(
                        styles: _isDarkMode ? monokaiSublimeTheme : githubTheme,
                      ),
                      child: SingleChildScrollView(
                        child: CodeField(
                          controller: _codeController,
                          textStyle: getMonospaceTextStyle(codeFontFamily),
                          gutterStyle: const GutterStyle(
                            width: 32,
                            textAlign: TextAlign.right,
                          ),
                          lineNumberStyle: LineNumberStyle(
                            textStyle: TextStyle(
                              color: _isDarkMode ? Colors.grey : Colors.grey.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            if (!isLoadingProblem) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: _isRunning
                            ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
                            : const Icon(Icons.play_arrow),
                        label: const Text('実行'),
                        onPressed: _isRunning ? null : _runCode,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          textStyle: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: _isTesting
                            ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
                            : const Icon(Icons.checklist_rtl),
                        label: Text(_isTesting ? 'テスト中…' : 'サンプル'),
                        onPressed: isButtonDisabled ? null : _runTests,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          textStyle: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('提出'),
                        onPressed: () {
                          final parts = widget.problemId.split('_');
                          final contestId = parts.isNotEmpty ? parts[0] : widget.problemId;
                          final url = 'https://atcoder.jp/contests/$contestId/submit?taskScreenName=${widget.problemId}';
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SubmitScreen(
                                url: url,
                                initialCode: _codeController.text,
                                initialLanguage: _selectedLanguage,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          textStyle: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Expanded(
                      child: Card(
                        elevation: 1,
                        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('標準入力 (stdin)', style: Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: TextField(
                                    controller: _stdinController,
                                    expands: true,
                                    maxLines: null,
                                    decoration: const InputDecoration(
                                      hintText: 'プログラムへの入力をここに入力します',
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                    style: getMonospaceTextStyle(codeFontFamily, fontSize: 13),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Card(
                        elevation: 1,
                        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('標準出力 (stdout)', style: Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: Scrollbar(
                                    thumbVisibility: true,
                                    child: SingleChildScrollView(
                                      child: SelectableText(
                                        _output.isEmpty && _error.isEmpty && !_isRunning
                                          ? '実行ボタンを押すと、ここに結果が表示されます。'
                                          : (_output.isEmpty ? '(空)' : _output),
                                        style: getMonospaceTextStyle(codeFontFamily, fontSize: 13),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_error.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text('エラー出力 (stderr)', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.red)),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: Scrollbar(
                                    thumbVisibility: true,
                                    child: SingleChildScrollView(
                                      child: SelectableText(
                                        _error,
                                        style: getMonospaceTextStyle(codeFontFamily, fontSize: 13, color: Colors.red),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        )
        );
      },
    );
  }
}