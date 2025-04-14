import 'dart:async'; // TimeoutExceptionのために追加
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboardのために追加
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/languages/dart.dart'; // CodeControllerの初期化に必要
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http; // HTTPリクエスト用
import 'package:provider/provider.dart'; // Providerのために追加 (もし使うなら)
import 'package:shared_preferences/shared_preferences.dart';
import '../models/problem.dart'; // 追加
import '../models/test_result.dart'; // 追加
import '../services/atcoder_service.dart'; // 追加

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
    _codeController = CodeController(
      language: dart,
      text: '// Loading code...',
    );
    _loadSavedCode();
    _loadProblemData(); // 問題データを読み込む
  }

  @override
  void dispose() {
    _codeController.dispose();
    _stdinController.dispose();
    super.dispose();
  }

  // 保存されたコードを読み込む関数
  Future<void> _loadSavedCode() async {
    setState(() {
      _isLoadingCode = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString('code_${widget.problemId}_$_selectedLanguage');
      // ★★★ ここで _codeController にアクセスする前に初期化されている必要がある ★★★
      if (savedCode != null) {
        _codeController.text = savedCode;
      } else {
        _codeController.text = _getTemplateForLanguage(_selectedLanguage);
      }
    } catch (e) {
      print("コードの読み込みに失敗しました: $e");
      // エラー時もテンプレートを設定
      _codeController.text = _getTemplateForLanguage(_selectedLanguage);
    } finally {
      setState(() {
        _isLoadingCode = false;
      });
    }
  }

  // 現在のコードを保存する関数
  Future<void> _saveCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('code_${widget.problemId}_$_selectedLanguage', _codeController.text);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$_selectedLanguage のコードを保存しました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('コードの保存に失敗しました: $e')),
      );
    }
  }

  // 言語が変更されたときの処理
  void _onLanguageChanged(String? newLanguage) {
    if (newLanguage != null && newLanguage != _selectedLanguage) {
      setState(() {
        _selectedLanguage = newLanguage;
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
      setState(() {
        _isRunning = false;
      });
    }
  }

  // 現在のコードを復元する関数
  Future<void> _restoreCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString('code_${widget.problemId}_$_selectedLanguage');
      if (savedCode != null) {
        setState(() {
          _codeController.text = savedCode;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$_selectedLanguage のコードを復元しました')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存されたコードが見つかりません')),
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
    // problemId が 'default_problem' の場合は何もしない
    if (widget.problemId == 'default_problem') {
      print("Default problem ID detected, skipping problem data load.");
      // 必要なら _isLoadingCode を false にする
      if (mounted) {
        setState(() {
          _isLoadingCode = false; // コード読み込みも完了扱いにする
        });
      }
      return;
    }
    // すでに読み込み済み、または読み込み中なら何もしない (isLoadingCode を流用)
    if (_currentProblem != null || !_isLoadingCode) return;

    // _isLoadingCode は initState で true になっているので、ここでは setState しない

    try {
      // ProblemProvider から contestId を取得するか、適切な方法で contestId を特定する
      // ここでは仮に problemId から contestId を抽出する (例: 'abc349_a' -> 'abc349')
      final parts = widget.problemId.split('_');
      if (parts.isEmpty) {
        print("Invalid problem ID format: ${widget.problemId}");
        if (mounted) {
          setState(() {
            _isLoadingCode = false; // エラーでもローディング終了
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('無効な問題ID形式です: ${widget.problemId}')),
          );
        }
        return;
      }
      final contestId = parts[0];
      final url = 'https://atcoder.jp/contests/$contestId/tasks/${widget.problemId}';
      print("Fetching problem data from: $url"); // デバッグ用ログ
      final problem = await _atcoderService.fetchProblem(url);
      print("Problem data fetched: ${problem.title}"); // デバッグ用ログ
      if (mounted) {
        setState(() {
          _currentProblem = problem;
          // ★★★ デバッグログ追加 ★★★
          print("Problem loaded: ${_currentProblem?.title}");
          print("Samples found: ${_currentProblem?.samples.length ?? 0}");
          // ★★★ デバッグログ追加 ★★★
        });
      }
    } catch (e) {
      print("Failed to load problem data for testing: $e"); // 既存ログ
      if (mounted) {
        // ★★★ デバッグログ追加 ★★★
        print("Error loading problem data. _currentProblem is null.");
        // ★★★ デバッグログ追加 ★★★
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('テストケースの読み込みに失敗しました: $e')),
        );
      }
    } finally {
       // _loadSavedCode と両方終わったことを確認するために
       // _loadSavedCode 側で isLoadingCode を false にする
       // ★★★ デバッグログ追加 ★★★
       print("_loadProblemData finished. isLoadingCode: $_isLoadingCode");
       // ★★★ デバッグログ追加 ★★★
    }
  }

  // Wandbox APIを使用して単一のテストケースを実行する内部関数
  Future<TestResult> _runSingleTest(TestResult testCase, String code, String wandboxLanguage, Function(VoidCallback) setDialogState) async {
    // ダイアログの状態を更新
    setDialogState(() {
      testCase.status = JudgeStatus.running;
    });

    final url = Uri.parse('https://wandbox.org/api/compile.json');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'code': code,
          'compiler': wandboxLanguage,
          'stdin': testCase.input,
          'save': false,
          // 'compiler-option-raw': '-O2\n-Wall', // 必要ならコンパイラオプション
          // 'runtime-option-raw': '', // 必要なら実行時オプション
        }),
      ).timeout(const Duration(seconds: 15)); // 15秒タイムアウト

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        testCase.actualOutput = result['program_output'] ?? '';
        testCase.errorOutput = result['program_error'] ?? '';
        final compilerError = result['compiler_error'];
        // final programMessage = result['program_message']; // TLE判定に使えるか？
        testCase.exitCode = int.tryParse(result['status']?.toString() ?? '');
        testCase.signal = result['signal']?.toString();

        if (compilerError != null && compilerError.isNotEmpty) {
          testCase.status = JudgeStatus.ce;
          testCase.errorOutput += "\n--- Compiler Error ---\n$compilerError";
        } else if (testCase.signal != null && (testCase.signal!.contains('TLE') || testCase.signal!.contains('Killed') || testCase.signal!.contains('Terminated'))) {
           // WandboxのTLEシグナルは環境によるかも。Killed/TerminatedもTLEの可能性
           testCase.status = JudgeStatus.tle;
        } else if (testCase.exitCode != 0) {
          testCase.status = JudgeStatus.re;
        } else if (testCase.errorOutput.isNotEmpty && !testCase.errorOutput.contains("Permission denied")) {
          // 標準エラー出力がある場合REとみなす（Permission deniedは無視）
           testCase.status = JudgeStatus.re;
        } else {
          // 出力を比較 (改行コードや末尾の空白を考慮して比較)
          final expected = testCase.expectedOutput.trim().replaceAll('\r\n', '\n');
          final actual = testCase.actualOutput.trim().replaceAll('\r\n', '\n');
          if (expected == actual) {
            testCase.status = JudgeStatus.ac;
          } else {
            testCase.status = JudgeStatus.wa;
          }
        }
      } else {
        testCase.status = JudgeStatus.ie; // Internal Error
        testCase.errorOutput = 'APIエラー: ${response.statusCode}\n${response.body}';
      }
    } on TimeoutException {
       testCase.status = JudgeStatus.tle; // HTTPリクエストのタイムアウト
       testCase.errorOutput = '実行リクエストがタイムアウトしました (15秒)。';
    } catch (e) {
      testCase.status = JudgeStatus.ie; // Internal Error
      testCase.errorOutput = 'テスト実行中にエラーが発生しました: $e';
    }

    // ダイアログの状態を更新
    setDialogState(() {}); // 結果を反映
    return testCase;
  }

  // 複数のテストケースを実行する関数
  Future<void> _runTests() async {
    if (_isTesting || _currentProblem == null || _currentProblem!.samples.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          _isTesting ? 'テスト実行中です' : (_currentProblem == null ? '問題データがありません' : 'テストケースが見つかりません')
        )),
      );
      return;
    }

    // 外側のStateを更新してボタンを無効化
    setState(() {
      _isTesting = true;
    });

    _testResults = _currentProblem!.samples.map((sample) => TestResult(
      index: sample.index,
      input: sample.input,
      expectedOutput: sample.output,
    )).toList();

    final code = _codeController.text;
    final wandboxLanguage = _getWandboxLanguageName(_selectedLanguage);

    // テスト結果表示用のダイアログを表示し、そのダイアログの setState を取得
    Function(VoidCallback)? setDialogStateProxy;
    await showDialog(
      context: context,
      barrierDismissible: false, // 実行中は閉じさせない
      builder: (BuildContext context) {
        return StatefulBuilder(
          key: _testResultsDialogKey, // Keyを渡す
          builder: (context, setDialogState) {
            // 外側の _runTests 関数にダイアログの setState を渡す
            setDialogStateProxy = setDialogState;

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
                            : Text(
                                result.index.toString(),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                      ),
                      title: Text('ケース ${result.index}'),
                      subtitle: Text(result.statusLabel),
                      trailing: result.status != JudgeStatus.running && result.status != JudgeStatus.pending
                          ? const Icon(Icons.chevron_right)
                          : null,
                      onTap: result.status == JudgeStatus.running || result.status == JudgeStatus.pending
                          ? null // 実行中・待機中はタップ無効
                          : () {
                              // 詳細表示
                              _showResultDetailDialog(result);
                            },
                    );
                  },
                ),
              ),
              actions: <Widget>[
                // 実行中は閉じるボタンを無効化
                TextButton(
                  onPressed: _isTesting ? null : () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('閉じる'),
                ),
              ],
            );
          },
        );
      },
    );

    // ダイアログが表示された後、テストを実行
    if (setDialogStateProxy != null) {
      for (int i = 0; i < _testResults.length; i++) {
        final result = await _runSingleTest(_testResults[i], code, wandboxLanguage, setDialogStateProxy!);
        // コンパイルエラーやREが出たら以降のテストを中断する場合
        if (result.status == JudgeStatus.ce || result.status == JudgeStatus.re || result.status == JudgeStatus.ie) {
           print("Stopping tests due to error in case ${result.index}: ${result.statusLabel}");
           break;
        }
      }
    }

    // 全テスト終了後、外側のStateとダイアログのStateを更新
    if (mounted) {
      setState(() {
        _isTesting = false;
      });
      // ダイアログがまだ表示されていれば更新
      if (_testResultsDialogKey.currentContext != null) {
         setDialogStateProxy?.call(() {});
      }
    }
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
                 constraints: const BoxConstraints(maxHeight: 150), // 高さに制限
                 decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                 ),
                 child: SingleChildScrollView( // 内容が長い場合にスクロール可能に
                    child: SelectableText(
                       content.isEmpty ? '(空)' : content,
                       style: GoogleFonts.sourceCodePro(
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
      case JudgeStatus.pending:
      default: return Colors.grey.shade600;
    }
  }


  @override
  Widget build(BuildContext context) {
    final bool isLoadingProblem = _isLoadingCode || (widget.problemId != 'default_problem' && _currentProblem == null);

    // ★★★ デバッグログ追加 ★★★
    final bool isButtonDisabled = isLoadingProblem || _isTesting || _currentProblem == null || (_currentProblem?.samples.isEmpty ?? true);
    // _currentProblemがnullの場合にsamplesにアクセスしないように修正
    print("--- Test Button State ---");
    print("isLoadingProblem: $isLoadingProblem (_isLoadingCode: $_isLoadingCode, _currentProblem == null: ${_currentProblem == null}) (problemId: ${widget.problemId})");
    print("_isTesting: $_isTesting");
    print("_currentProblem == null: ${_currentProblem == null}");
    print("_currentProblem?.samples.isEmpty: ${_currentProblem?.samples.isEmpty}"); // nullの場合はnullが出力される
    print("Button disabled: $isButtonDisabled");
    print("-------------------------");
    // ★★★ デバッグログ追加 ★★★


    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 言語選択 Dropdown
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
              // ツールバーボタン (実行ボタンは削除)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ... other buttons ...
                  IconButton( // テスト実行ボタン
                    icon: _isTesting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.checklist_rtl),
                    tooltip: 'テスト実行 (サンプルケース)',
                    onPressed: isButtonDisabled
                        ? null
                        : () { // onPressedがnullでない場合の処理
                            print("★★★ Test Button Pressed! ★★★"); // このログが出るか確認
                            _runTests();
                          },
                  ),
                  IconButton( // 提出ボタン
                    icon: const Icon(Icons.cloud_upload),
                    tooltip: '提出',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('提出機能は準備中です')),
                      );
                    },
                  ),
                  IconButton( // 保存ボタン
                    icon: const Icon(Icons.save_alt),
                    tooltip: '保存',
                    onPressed: _saveCode,
                  ),
                  IconButton( // 復元ボタン
                    icon: const Icon(Icons.settings_backup_restore),
                    tooltip: '復元',
                    onPressed: _restoreCode,
                  ),
                  IconButton( // リセットボタン
                    icon: const Icon(Icons.replay),
                    tooltip: 'リセット',
                    onPressed: () {
                      _codeController.text = _getTemplateForLanguage(_selectedLanguage);
                      _stdinController.clear();
                      setState(() {
                         _output = '';
                         _error = '';
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        // ローディング表示 or コードエディタ
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
                      textStyle: GoogleFonts.sourceCodePro(),
                      gutterStyle: GutterStyle(
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

        // 標準入力フィールドと実行ボタン
        if (!isLoadingProblem)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
            child: Row( // RowでTextFieldとButtonを囲む
              crossAxisAlignment: CrossAxisAlignment.end, // ボタンとフィールドの高さを揃える
              children: [
                Expanded( // TextFieldが可能な限り幅を取るように
                  child: TextField(
                    controller: _stdinController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: '標準入力 (stdin)',
                      hintText: 'プログラムへの入力をここに入力します',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: GoogleFonts.sourceCodePro(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8), // フィールドとボタンの間隔
                // 実行ボタン (ElevatedButtonに変更)
                ElevatedButton.icon(
                  icon: _isRunning
                      ? SizedBox( // 実行中はインジケーター
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary, // ボタン色に合わせた色
                          ),
                        )
                      : const Icon(Icons.play_arrow),
                  label: const Text('実行'),
                  onPressed: _isRunning ? null : _runCode, // 実行中は無効
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // 少し大きめに
                    textStyle: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

        // 実行結果表示エリア
        if (!isLoadingProblem)
          Expanded(
            flex: 2,
            child: Card(
              elevation: 1,
              margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Standard Output Display ---
                      if (_output.isNotEmpty)
                        Text(
                          '実行結果 (stdout):',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      if (_output.isNotEmpty)
                        SelectableText(
                          _output,
                          style: GoogleFonts.sourceCodePro(fontSize: 13),
                        ),

                      // --- Error Output Display ---
                      if (_error.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: _output.isNotEmpty ? 8.0 : 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'エラー出力 (stderr):',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.red),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 18),
                                tooltip: 'エラーをコピー',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _error));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('エラー出力をコピーしました')),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      if (_error.isNotEmpty)
                        SelectableText(
                          _error,
                          style: GoogleFonts.sourceCodePro(fontSize: 13, color: Colors.red),
                        ),

                      // --- Placeholder Text ---
                      if (_output.isEmpty && _error.isEmpty && !_isRunning)
                         Text(
                           '実行ボタンを押すと、ここに結果が表示されます。',
                           style: TextStyle(color: Colors.grey),
                         ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ... other methods (_runCode, _runTests, etc.) ...
}
